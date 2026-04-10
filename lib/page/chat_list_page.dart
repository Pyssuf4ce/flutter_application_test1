import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'chat_room_page.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  // 🚀 ความลับระดับโปร: สร้างตัวแปร Global ไว้ให้หน้าอื่นสั่งรีเฟรชหน้านี้ได้ทันที
  static final ValueNotifier<int> globalRefresh = ValueNotifier<int>(0);

  @override
  State<ChatListPage> createState() => ChatListPageState();
}

class ChatListPageState extends State<ChatListPage> {
  final _supabase = Supabase.instance.client;
  String _myUserId = ''; 
  bool _isLoading = true;
  List<Map<String, dynamic>> _myRooms = [];
  RealtimeChannel? _chatChannel; 

  @override
  void initState() {
    super.initState();
    _initializeChatList();
    
    // 💡 ดักฟังคำสั่งรีเฟรชจากหน้า Chat Room
    ChatListPage.globalRefresh.addListener(_silentFetchRooms);
  }

  @override
  void dispose() {
    ChatListPage.globalRefresh.removeListener(_silentFetchRooms);
    if (_chatChannel != null) _supabase.removeChannel(_chatChannel!);
    super.dispose();
  }

  Future<void> _initializeChatList() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      _myUserId = user.id;
      await _fetchChatRooms(); 

      // 💡 ฟังการเปลี่ยนแปลงจาก Database (เผื่ออีกฝ่ายส่งมาตอนเราอยู่หน้า Inbox)
      _chatChannel = _supabase.channel('public:chat_rooms')
        .onPostgresChanges(
          event: PostgresChangeEvent.all, 
          schema: 'public',
          table: 'chat_rooms',
          callback: (_) => _silentFetchRooms() // รีเฟรชเงียบๆ ไม่ให้หน้าจอกระตุก
        ).subscribe();
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // โหลดแบบมี Loading (ใช้ตอนเข้าหน้าครั้งแรก)
  Future<void> _fetchChatRooms() async {
    try {
      final data = await _supabase.from('chat_list_view')
          .select()
          .or('buyer_id.eq.$_myUserId,seller_id.eq.$_myUserId') 
          .order('last_message_time', ascending: false);

      if (mounted) {
        setState(() {
          _myRooms = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // โหลดแบบไม่มี Loading (ใช้ตอนมีข้อความใหม่ ให้ UI เปลี่ยนทันทีแบบเนียนๆ)
  Future<void> _silentFetchRooms() async {
    try {
      final data = await _supabase.from('chat_list_view')
          .select()
          .or('buyer_id.eq.$_myUserId,seller_id.eq.$_myUserId') 
          .order('last_message_time', ascending: false);
      if (mounted) setState(() => _myRooms = List<Map<String, dynamic>>.from(data));
    } catch (_) {}
  }

  void scrollToTopAndRefresh() {
    setState(() => _isLoading = true);
    _fetchChatRooms();
  }

  String _formatTime(String? timeStr) {
    if (timeStr == null) return '';
    final date = DateTime.parse(timeStr).toLocal();
    final now = DateTime.now();
    if (date.day == now.day && date.month == now.month && date.year == now.year) {
      return DateFormat('HH:mm').format(date);
    }
    return DateFormat('dd/MM').format(date);
  }

  @override
  Widget build(BuildContext context) {
    if (_myUserId.isEmpty) return const Scaffold(backgroundColor: Color(0xFFF8F9FA), body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        title: Text("INBOX", style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2, color: const Color(0xFF35408B))),
        centerTitle: true,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF35408B)))
        : _myRooms.isEmpty
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.chat_bubble_outline_rounded, size: 64, color: Colors.grey.withOpacity(0.3)), const SizedBox(height: 16), Text("ไม่มีข้อความในขณะนี้", style: GoogleFonts.manrope(color: Colors.grey))]))
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _myRooms.length,
                itemBuilder: (context, index) {
                  final room = _myRooms[index];
                  final bool isBuyer = room['buyer_id'] == _myUserId;
                  final otherName = isBuyer ? room['seller_name'] : room['buyer_name'];
                  final otherAvatar = isBuyer ? room['seller_avatar'] : room['buyer_avatar'];
                  final otherId = isBuyer ? room['seller_id'] : room['buyer_id'];
                  final lastMsg = room['last_message'] ?? '';
                  final time = _formatTime(room['last_message_time']);

                  return InkWell(
                    onTap: () {
                      // 🚀 ไปหน้าแชทแบบ Clean ไม่ต้องรอ then() 
                      Navigator.push(
                        context, 
                        MaterialPageRoute(
                          builder: (context) => ChatRoomPage(
                            roomId: room['room_id'],
                            targetSellerId: otherId,
                            peerName: otherName,   
                            peerAvatar: otherAvatar, 
                          )
                        )
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF1F3F4)))),
                      child: Row(
                        children: [
                          CircleAvatar(radius: 28, backgroundColor: const Color(0xFFE2E9EC), backgroundImage: otherAvatar != null ? NetworkImage(otherAvatar) : null, child: otherAvatar == null ? const Icon(Icons.person, color: Colors.grey) : null),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(otherName ?? 'Unknown', style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(height: 4),
                                Text(lastMsg, style: GoogleFonts.manrope(fontSize: 14, color: Colors.grey[600]), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(time, style: GoogleFonts.manrope(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                  );
                },
              ),
    );
  }
}