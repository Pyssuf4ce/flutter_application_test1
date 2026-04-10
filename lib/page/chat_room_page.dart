import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/message_model.dart'; 
import 'chat_list_page.dart'; // 💡 Import เพื่อใช้ globalRefresh สะกิดหน้า Inbox

class ChatRoomPage extends StatefulWidget {
  final Map<String, dynamic>? product; 
  final String? roomId; 
  final String? targetSellerId; 
  final String? peerName;    
  final String? peerAvatar;  
  
  const ChatRoomPage({
    super.key, 
    this.product, 
    this.roomId, 
    this.targetSellerId, 
    this.peerName, 
    this.peerAvatar
  });

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  final _messageController = TextEditingController();
  final _supabase = Supabase.instance.client;
  final Box<LocalMessage> _messageBox = Hive.box<LocalMessage>('messages');
  
  String? _roomId;
  late String _otherUserName = widget.peerName ?? 'VAULT User'; 
  late String _otherUserAvatar = widget.peerAvatar ?? '';         
  bool _isLoadingRoom = true;
  List<Map<String, dynamic>> _displayMessages = [];
  late final String _myUserId;

  @override
  void initState() {
    super.initState();
    _myUserId = _supabase.auth.currentUser!.id;
    _initializeRoom();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _initializeRoom() async {
    try {
      String? roomId = widget.roomId;
      final peerId = widget.product?['seller_id'] ?? widget.targetSellerId;

      if (roomId == null) {
        final existingRoom = await _supabase.from('chat_rooms')
            .select()
            .or('and(buyer_id.eq.$_myUserId,seller_id.eq.$peerId),and(buyer_id.eq.$peerId,seller_id.eq.$_myUserId)')
            .maybeSingle();
            
        if (existingRoom != null) {
          roomId = existingRoom['id'];
        } else {
          final newRoom = await _supabase.from('chat_rooms').insert({
            'buyer_id': _myUserId, 
            'seller_id': peerId
          }).select().single();
          roomId = newRoom['id'];
        }
      }

      if (roomId != null) {
        _roomId = roomId;
        _loadLocalMessages();
        _setupMessageStream(roomId);
        _fetchOtherUserProfileSilently(roomId);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingRoom = false);
    }
  }

  void _loadLocalMessages() {
    final localMsgs = _messageBox.values
        .where((msg) => msg.roomId == _roomId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
    setState(() {
      _displayMessages = localMsgs.map((m) => {
        'id': m.id, 
        'room_id': m.roomId, 
        'sender_id': m.senderId, 
        'content': m.content, 
        'created_at': m.createdAt.toIso8601String(), 
        'status': m.status
      }).toList();
      _isLoadingRoom = false;
    });
  }

  Future<void> _fetchOtherUserProfileSilently(String rId) async {
    final room = await _supabase.from('chat_rooms').select('buyer_id, seller_id').eq('id', rId).single();
    final otherId = (room['buyer_id'] == _myUserId) ? room['seller_id'] : room['buyer_id'];
    final profile = await _supabase.from('profiles').select('username, avatar_url').eq('id', otherId).single();
    
    if (mounted && (profile['username'] != _otherUserName || profile['avatar_url'] != _otherUserAvatar)) {
      setState(() {
        _otherUserName = profile['username'] ?? 'VAULT User';
        _otherUserAvatar = profile['avatar_url'] ?? '';
      });
    }
  }

  void _setupMessageStream(String rId) {
    _supabase.from('messages')
        .stream(primaryKey: ['id'])
        .eq('room_id', rId)
        .order('created_at', ascending: false)
        .listen((data) {
          for (var msg in data) {
            _messageBox.put(msg['id'], LocalMessage(
              id: msg['id'], 
              roomId: msg['room_id'], 
              senderId: msg['sender_id'], 
              content: msg['content'], 
              createdAt: DateTime.parse(msg['created_at']), 
              status: 'sent'
            ));
          }
          if (mounted) _loadLocalMessages();
        });
  }

  // 🚀 ฟังก์ชันส่งข้อความแบบลบตัวปลอมเพื่อแก้ข้อความเบิ้ล
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _roomId == null) return;

    final tempId = 'temp-${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now();
    _messageController.clear();

    // 1. Optimistic Update ลงจอและเครื่องทันที (สร้างตัวปลอม)
    final newMessage = LocalMessage(
      id: tempId, 
      roomId: _roomId!, 
      senderId: _myUserId, 
      content: text, 
      createdAt: now, 
      status: 'sending'
    );
    await _messageBox.put(tempId, newMessage);
    _loadLocalMessages(); 

    try {
      // 2. ส่งขึ้นเซิร์ฟเวอร์ และดึง ID จริงกลับมา
      final response = await _supabase.from('messages').insert({
        'room_id': _roomId, 
        'sender_id': _myUserId, 
        'content': text
      }).select().single();
      
      final realId = response['id'];

      // 3. 💡 ลบตัวปลอมทิ้งทันที เพื่อกันการโชว์เบิ้ล
      await _messageBox.delete(tempId);

      // 4. ใส่ของจริงที่มี ID ถูกต้องลงไปแทน
      await _messageBox.put(realId, LocalMessage(
        id: realId, 
        roomId: _roomId!, 
        senderId: _myUserId, 
        content: text, 
        createdAt: DateTime.parse(response['created_at']), 
        status: 'sent'
      ));

      _loadLocalMessages();
      
      // อัปเดตห้องแชทล่าสุด
      await _supabase.from('chat_rooms').update({
        'last_message': text, 
        'last_message_time': now.toIso8601String()
      }).eq('id', _roomId!);
      
      // 🚀 5. สั่งสะกิดหน้า Inbox ให้อัปเดต
      ChatListPage.globalRefresh.value++; 
      
    } catch (e) {
      debugPrint("Offline mode: Stored locally as temp.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white, 
        elevation: 1, 
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF191C1D), size: 20), 
          onPressed: () => Navigator.pop(context)
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18, 
              backgroundColor: const Color(0xFFE2E9EC), 
              backgroundImage: _otherUserAvatar.isNotEmpty ? NetworkImage(_otherUserAvatar) : null, 
              child: _otherUserAvatar.isEmpty ? const Icon(Icons.person, size: 20, color: Colors.grey) : null
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _otherUserName, 
                style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF191C1D))
              )
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (widget.product != null) _buildContextCard(),
          Expanded(
            child: _isLoadingRoom && _displayMessages.isEmpty
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF35408B)))
                : ListView.builder(
                    reverse: true, 
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _displayMessages.length,
                    itemBuilder: (context, index) {
                      final msg = _displayMessages[index];
                      final isMe = msg['sender_id'] == _myUserId;
                      final showAvatar = !isMe && (index == _displayMessages.length - 1 || _displayMessages[index + 1]['sender_id'] != msg['sender_id']);
                      
                      return _buildMessageBubble(msg['content'], isMe, showAvatar, msg['status'] ?? 'sent');
                    },
                  ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  // --- UI Components ---

  Widget _buildMessageBubble(String text, bool isMe, bool showAvatar, String status) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (showAvatar) 
            Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 8), 
              child: CircleAvatar(
                radius: 12, 
                backgroundColor: const Color(0xFFE2E9EC), 
                backgroundImage: _otherUserAvatar.isNotEmpty ? NetworkImage(_otherUserAvatar) : null, 
                child: _otherUserAvatar.isEmpty ? const Icon(Icons.person, size: 14, color: Colors.grey) : null
              )
            ),
          if (!isMe && !showAvatar) const SizedBox(width: 32),
          Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 2), 
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), 
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.70),
                decoration: BoxDecoration(
                  color: isMe ? const Color(0xFF35408B) : Colors.white, 
                  borderRadius: BorderRadius.circular(20).copyWith(
                    bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(20), 
                    bottomLeft: isMe ? const Radius.circular(20) : const Radius.circular(4)
                  ), 
                  border: isMe ? null : Border.all(color: Colors.grey.withOpacity(0.1))
                ),
                child: Text(
                  text, 
                  style: GoogleFonts.manrope(fontSize: 15, color: isMe ? Colors.white : const Color(0xFF191C1D))
                ),
              ),
              if (isMe && status == 'sending') 
                Padding(
                  padding: const EdgeInsets.only(right: 4, bottom: 4), 
                  child: Text("กำลังส่ง...", style: GoogleFonts.manrope(fontSize: 9, color: Colors.grey))
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContextCard() {
    return Container(
      margin: const EdgeInsets.all(16), 
      padding: const EdgeInsets.all(12), 
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(16), 
        border: Border.all(color: const Color(0xFF35408B).withOpacity(0.1))
      ), 
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8), 
            child: Image.network(widget.product!['image_url'] ?? '', width: 44, height: 44, fit: BoxFit.cover)
          ), 
          const SizedBox(width: 12), 
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, 
              children: [
                Text("สนใจสินค้า:", style: GoogleFonts.manrope(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)), 
                Text(widget.product!['name'] ?? 'Product', style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.bold), maxLines: 1)
              ]
            )
          )
        ]
      )
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), 
      decoration: BoxDecoration(
        color: Colors.white, 
        border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.1)))
      ), 
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController, 
                style: GoogleFonts.manrope(), 
                decoration: InputDecoration(
                  hintText: "พิมพ์ข้อความ...", 
                  filled: true, 
                  fillColor: const Color(0xFFF5F7FA), 
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none), 
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)
                )
              )
            ), 
            const SizedBox(width: 12), 
            GestureDetector(
              onTap: _sendMessage, 
              child: Container(
                padding: const EdgeInsets.all(12), 
                decoration: const BoxDecoration(color: Color(0xFF35408B), shape: BoxShape.circle), 
                child: const Icon(Icons.send_rounded, color: Colors.white, size: 18)
              )
            )
          ]
        )
      )
    );
  }
}