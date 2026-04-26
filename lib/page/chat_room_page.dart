import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/message_model.dart';
import 'chat_events.dart';

// ─────────────────────────────────────────────
// CONSTANTS
// ─────────────────────────────────────────────
const _kPageSize = 30;
const _kAccent = Color(0xFF35408B);
const _kBg = Color(0xFFF8F9FA);

// ─────────────────────────────────────────────
// Thai Input Formatter — ป้องกันวรรณยุกต์/สระลอยซ้อนกัน
// (มาตรฐานเดียวกับ LINE, WhatsApp)
// ─────────────────────────────────────────────
class _ThaiInputFormatter extends TextInputFormatter {
  /// ตรวจว่าเป็นอักขระประสม (สระบน/ล่าง, วรรณยุกต์, ทัณฑฆาต ฯลฯ) หรือไม่
  static bool _isCombining(int c) =>
      (c >= 0x0E31 && c <= 0x0E3A) || // ั ิ ี ึ ื ุ ู
      (c >= 0x0E47 && c <= 0x0E4E); // ็ ่ ้ ๊ ๋ ์ ํ ๎

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;

    final buf = StringBuffer();
    int combiningCount = 0;

    for (int i = 0; i < text.length; i++) {
      final c = text.codeUnitAt(i);
      if (_isCombining(c)) {
        combiningCount++;
        if (combiningCount <= 2)
          buf.writeCharCode(c); // อนุญาตสูงสุด 2 ตัว (เช่น กิ้)
      } else {
        combiningCount = 0;
        buf.writeCharCode(c);
      }
    }

    final cleaned = buf.toString();
    if (cleaned == text) return newValue;

    // ปรับตำแหน่ง cursor ให้ถูกต้อง
    final diff = text.length - cleaned.length;
    final newOffset = (newValue.selection.baseOffset - diff).clamp(
      0,
      cleaned.length,
    );
    return TextEditingValue(
      text: cleaned,
      selection: TextSelection.collapsed(offset: newOffset),
    );
  }
}

// ─────────────────────────────────────────────
// PEER MODEL
// ─────────────────────────────────────────────
class _Peer {
  final String id;
  final String name;
  final String avatarUrl;
  const _Peer({required this.id, required this.name, required this.avatarUrl});

  _Peer copyWith({String? name, String? avatarUrl}) => _Peer(
    id: id,
    name: name ?? this.name,
    avatarUrl: avatarUrl ?? this.avatarUrl,
  );
}

// ─────────────────────────────────────────────
// PAGE
// ─────────────────────────────────────────────
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
    this.peerAvatar,
  });

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  // ── deps ──────────────────────────────────────
  final _supabase = Supabase.instance.client;
  late final Box<LocalMessage> _box;
  late final String _myId;

  // ── state ─────────────────────────────────────
  String? _selectedMessageId; // id ของข้อความที่กดอยู่
  String? _roomId;
  _Peer _peer = const _Peer(id: '', name: 'VAULT User', avatarUrl: '');

  bool _isInitializing = true;
  String? _initError;

  List<Map<String, dynamic>> _messages = [];
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _oldestCursor; // created_at ของข้อความเก่าสุดที่โหลดมาแล้ว

  // ── controllers ───────────────────────────────
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  StreamSubscription<List<Map<String, dynamic>>>? _msgSub;

  // ─────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _myId = _supabase.auth.currentUser!.id;
    _box = Hive.box<LocalMessage>('messages');
    _scrollCtrl.addListener(_onScroll);

    // ตั้งค่า peer เบื้องต้นจาก widget params (แสดงได้ทันทีก่อนดึงจาก DB)
    _peer = _Peer(
      id: widget.targetSellerId ?? '',
      name: widget.peerName ?? 'VAULT User',
      avatarUrl: widget.peerAvatar ?? '',
    );

    _initRoom();
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    _textCtrl.dispose();
    _scrollCtrl
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // INIT
  // ─────────────────────────────────────────────
  Future<void> _initRoom() async {
    try {
      final roomId = await _resolveRoomId();
      if (roomId == null) throw Exception('ไม่สามารถสร้างห้องแชทได้');

      _roomId = roomId;
      _loadCache(); // แสดง offline cache ก่อนเลย

      await Future.wait([_fetchRecent(roomId), _fetchPeer(roomId)]);

      _setupStream(roomId);
      if (mounted) setState(() => _isInitializing = false);
    } catch (e) {
      if (mounted)
        setState(() {
          _isInitializing = false;
          _initError = e.toString();
        });
    }
  }

  Future<String?> _resolveRoomId() async {
    if (widget.roomId != null) return widget.roomId;

    final peerId = widget.product?['seller_id'] ?? widget.targetSellerId;
    if (peerId == null) return null;

    final existing = await _supabase
        .from('chat_rooms')
        .select('id')
        .or(
          'and(buyer_id.eq.$_myId,seller_id.eq.$peerId),'
          'and(buyer_id.eq.$peerId,seller_id.eq.$_myId)',
        )
        .maybeSingle();

    if (existing != null) return existing['id'] as String;

    final created = await _supabase
        .from('chat_rooms')
        .insert({'buyer_id': _myId, 'seller_id': peerId})
        .select('id')
        .single();

    return created['id'] as String;
  }

  // ─────────────────────────────────────────────
  // MESSAGES
  // ─────────────────────────────────────────────
  void _loadCache() {
    if (_roomId == null) return;
    final cached = _box.values.where((m) => m.roomId == _roomId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (mounted && cached.isNotEmpty) {
      setState(() => _messages = cached.map(_toMap).toList());
    }
  }

  Future<void> _fetchRecent(String roomId) async {
    final data =
        await _supabase
                .from('messages')
                .select()
                .eq('room_id', roomId)
                .order('created_at', ascending: false)
                .limit(_kPageSize)
            as List<dynamic>;

    _saveAndSync(data.cast<Map<String, dynamic>>());

    _hasMore = data.length == _kPageSize;
    if (_hasMore && data.isNotEmpty)
      _oldestCursor = data.last['created_at'] as String?;
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore || _roomId == null || _oldestCursor == null)
      return;
    if (mounted) setState(() => _isLoadingMore = true);

    try {
      final data =
          await _supabase
                  .from('messages')
                  .select()
                  .eq('room_id', _roomId!)
                  .lt('created_at', _oldestCursor!) // cursor-based pagination
                  .order('created_at', ascending: false)
                  .limit(_kPageSize)
              as List<dynamic>;

      final msgs = data.cast<Map<String, dynamic>>();
      if (msgs.length < _kPageSize) _hasMore = false;
      if (msgs.isNotEmpty) {
        _oldestCursor = msgs.last['created_at'] as String?;
        _saveAndSync(msgs);
      }
    } catch (_) {
      /* ผู้ใช้ pull-to-refresh ใหม่ได้ */
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _saveAndSync(List<Map<String, dynamic>> remoteList) {
    for (final msg in remoteList) {
      _box.put(
        msg['id'],
        LocalMessage(
          id: msg['id'],
          roomId: msg['room_id'],
          senderId: msg['sender_id'],
          content: msg['content'],
          createdAt: DateTime.parse(msg['created_at']),
          status: 'sent',
        ),
      );
    }
    _loadCache();
  }

  void _setupStream(String roomId) {
    _msgSub = _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .order('created_at', ascending: false)
        .limit(_kPageSize) // ไม่ดึงทั้งหมด
        .listen(
          (data) => _saveAndSync(data),
          onError: (_) {
            /* silent — local cache ยังแสดงได้ */
          },
        );
  }

  void _onScroll() {
    // reverse list → scroll ขึ้น = ใกล้ maxScrollExtent
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  // ─────────────────────────────────────────────
  // SEND
  // ─────────────────────────────────────────────
  Future<void> _sendMessage() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty || _roomId == null) return;

    _textCtrl.clear();
    HapticFeedback.lightImpact();

    final tempId = 'temp-${DateTime.now().microsecondsSinceEpoch}';
    final now = DateTime.now();

    // 1. Optimistic update
    await _box.put(
      tempId,
      LocalMessage(
        id: tempId,
        roomId: _roomId!,
        senderId: _myId,
        content: text,
        createdAt: now,
        status: 'sending',
      ),
    );
    _loadCache();

    try {
      // 2. ส่งขึ้น Supabase
      final res = await _supabase
          .from('messages')
          .insert({'room_id': _roomId!, 'sender_id': _myId, 'content': text})
          .select()
          .single();

      // 3. swap temp → real
      await _box.delete(tempId);
      await _box.put(
        res['id'],
        LocalMessage(
          id: res['id'],
          roomId: _roomId!,
          senderId: _myId,
          content: text,
          createdAt: DateTime.parse(res['created_at']),
          status: 'sent',
        ),
      );
      _loadCache();

      // 4. อัปเดต last_message + แจ้ง inbox
      unawaited(
        _supabase
            .from('chat_rooms')
            .update({
              'last_message': text,
              'last_message_time': now.toIso8601String(),
            })
            .eq('id', _roomId!),
      );

      ChatEvents.instance.notifyRoomUpdated(_roomId!);
    } catch (_) {
      if (mounted) {
        _showSnack('ส่งไม่สำเร็จ — กรุณาลองใหม่');
        // mark error
        await _box.put(
          tempId,
          LocalMessage(
            id: tempId,
            roomId: _roomId!,
            senderId: _myId,
            content: text,
            createdAt: now,
            status: 'error',
          ),
        );
        _loadCache();
      }
    }
  }

  // ─────────────────────────────────────────────
  // PEER PROFILE
  // ─────────────────────────────────────────────
  Future<void> _fetchPeer(String roomId) async {
    try {
      final room = await _supabase
          .from('chat_rooms')
          .select('buyer_id, seller_id')
          .eq('id', roomId)
          .single();

      final otherId = room['buyer_id'] == _myId
          ? room['seller_id'] as String
          : room['buyer_id'] as String;

      final profile = await _supabase
          .from('profiles')
          .select('username, avatar_url')
          .eq('id', otherId)
          .maybeSingle(); // maybeSingle กัน crash ถ้า user ถูกลบ

      if (mounted && profile != null) {
        setState(() {
          _peer = _Peer(
            id: otherId,
            name: profile['username'] ?? _peer.name,
            avatarUrl: profile['avatar_url'] ?? _peer.avatarUrl,
          );
        });
      }
    } catch (_) {
      /* ใช้ widget.peerName / peerAvatar เดิม */
    }
  }

  // ─────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────
  Map<String, dynamic> _toMap(LocalMessage m) => {
    'id': m.id,
    'room_id': m.roomId,
    'sender_id': m.senderId,
    'content': m.content,
    'created_at': m.createdAt.toIso8601String(),
    'status': m.status,
  };

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.manrope(textStyle: TextStyle(fontFamilyFallback: [GoogleFonts.notoSansThai().fontFamily ?? 'Noto Sans Thai']), fontSize: 13)),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _fmtTime(String iso) {
    final dt = DateTime.parse(iso).toLocal();
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // ─────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          if (widget.product != null) _buildProductBanner(),
          Expanded(child: _buildBody()),
          _buildInputBar(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() => AppBar(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.white,
    elevation: 0,
    scrolledUnderElevation: 1,
    centerTitle: false,
    leading: IconButton(
      icon: const Icon(
        Icons.arrow_back_ios_new_rounded,
        color: Color(0xFF191C1D),
        size: 20,
      ),
      onPressed: () {
        FocusScope.of(context).unfocus();
        Navigator.pop(context);
      },
    ),
    titleSpacing: 0,
    title: Row(
      children: [
        _Avatar(url: _peer.avatarUrl, radius: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _peer.name,
                style: GoogleFonts.manrope(textStyle: TextStyle(fontFamilyFallback: [GoogleFonts.notoSansThai().fontFamily ?? 'Noto Sans Thai']), 
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF191C1D),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                'VAULT',
                style: GoogleFonts.manrope(textStyle: TextStyle(fontFamilyFallback: [GoogleFonts.notoSansThai().fontFamily ?? 'Noto Sans Thai']), 
                  fontSize: 11,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildBody() {
    if (_isInitializing && _messages.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: _kAccent, strokeWidth: 2),
      );
    }

    if (_initError != null && _messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              'โหลดไม่สำเร็จ กรุณาลองใหม่',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(textStyle: TextStyle(fontFamilyFallback: [GoogleFonts.notoSansThai().fontFamily ?? 'Noto Sans Thai']), color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isInitializing = true;
                  _initError = null;
                });
                _initRoom();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _kAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'ลองใหม่',
                style: GoogleFonts.manrope(textStyle: TextStyle(fontFamilyFallback: [GoogleFonts.notoSansThai().fontFamily ?? 'Noto Sans Thai']), color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollCtrl,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _messages.length + 1, // +1 สำหรับ top indicator
      itemBuilder: (context, index) {
        // Top: loading more / end of history
        if (index == _messages.length) {
          if (_isLoadingMore) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _kAccent,
                  ),
                ),
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text(
                '— เริ่มต้นการสนทนา —',
                style: GoogleFonts.manrope(textStyle: TextStyle(fontFamilyFallback: [GoogleFonts.notoSansThai().fontFamily ?? 'Noto Sans Thai']), 
                  fontSize: 11,
                  color: Colors.grey[400],
                ),
              ),
            ),
          );
        }

        final msg = _messages[index];
        final isMe = msg['sender_id'] == _myId;
        final showAvatar =
            !isMe &&
            (index == 0 ||
                _messages[index - 1]['sender_id'] != msg['sender_id']);
        final showDate =
            index == _messages.length - 1 ||
            !_isSameDay(
              DateTime.parse(msg['created_at']),
              DateTime.parse(_messages[index + 1]['created_at']),
            );

        return Column(
          children: [
            if (showDate) _DateDivider(isoString: msg['created_at']),
            _Bubble(
              text: msg['content'],
              time: _fmtTime(msg['created_at']),
              isMe: isMe,
              status: msg['status'] ?? 'sent',
              showAvatar: showAvatar,
              avatarUrl: _peer.avatarUrl,
              showTime: _selectedMessageId == msg['id'], // ← เพิ่ม
              onTap: () {
                // ← เพิ่ม
                setState(() {
                  _selectedMessageId = _selectedMessageId == msg['id']
                      ? null
                      : msg['id'];
                });
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildProductBanner() {
    final p = widget.product!;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kAccent.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              p['image_url'] ?? '',
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 48,
                height: 48,
                color: Colors.grey[200],
                child: const Icon(
                  Icons.image_not_supported_outlined,
                  color: Colors.grey,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'สนใจสินค้า',
                  style: GoogleFonts.manrope(textStyle: TextStyle(fontFamilyFallback: [GoogleFonts.notoSansThai().fontFamily ?? 'Noto Sans Thai']), 
                    fontSize: 10,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  p['name'] ?? 'สินค้า',
                  style: GoogleFonts.manrope(textStyle: TextStyle(fontFamilyFallback: [GoogleFonts.notoSansThai().fontFamily ?? 'Noto Sans Thai']), 
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF191C1D),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
        ],
      ),
    );
  }

  Widget _buildInputBar() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.white,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 12,
          offset: const Offset(0, -2),
        ),
      ],
    ),
    child: SafeArea(
      top: false,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            // ConstrainedBox จำกัดความสูงสูงสุดของช่องพิมพ์ไม่ให้บานออก
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 140),
              child: ClipRRect(
                // ← ครอบด้วย ClipRRect ตัดทุกอย่างที่เกินออก
                borderRadius: BorderRadius.circular(24),
                child: TextField(
                  controller: _textCtrl,
                  style: GoogleFonts.manrope(textStyle: TextStyle(fontFamilyFallback: [GoogleFonts.notoSansThai().fontFamily ?? 'Noto Sans Thai']), fontSize: 15, height: 1.4),
                  maxLines: 5,
                  minLines: 1,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  textCapitalization: TextCapitalization.none,
                  inputFormatters: [_ThaiInputFormatter()],
                  strutStyle: const StrutStyle(
                    fontSize: 15,
                    height: 1.4,
                    forceStrutHeight:
                        true, // ← บังคับให้ทุก glyph อยู่ใน line height นี้
                  ),
                  decoration: InputDecoration(
                    hintText: 'พิมพ์ข้อความ...',
                    hintStyle: GoogleFonts.manrope(textStyle: TextStyle(fontFamilyFallback: [GoogleFonts.notoSansThai().fontFamily ?? 'Noto Sans Thai']), 
                      color: Colors.grey[400],
                      fontSize: 15,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF5F7FA),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    isDense: true,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _SendBtn(onTap: _sendMessage),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────
// SMALL WIDGETS
// ─────────────────────────────────────────────
class _Avatar extends StatelessWidget {
  final String url;
  final double radius;
  const _Avatar({required this.url, required this.radius});

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: radius,
    backgroundColor: const Color(0xFFE2E9EC),
    backgroundImage: url.isNotEmpty ? NetworkImage(url) : null,
    child: url.isEmpty
        ? Icon(Icons.person_rounded, size: radius, color: Colors.grey[500])
        : null,
  );
}

class _SendBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _SendBtn({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 44,
      height: 44,
      decoration: const BoxDecoration(color: _kAccent, shape: BoxShape.circle),
      child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
    ),
  );
}

class _DateDivider extends StatelessWidget {
  final String isoString;
  const _DateDivider({required this.isoString});

  @override
  Widget build(BuildContext context) {
    final dt = DateTime.parse(isoString).toLocal();
    final now = DateTime.now();
    final isToday =
        dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday =
        dt.year == yesterday.year &&
        dt.month == yesterday.month &&
        dt.day == yesterday.day;
    final label = isToday
        ? 'วันนี้'
        : isYesterday
        ? 'เมื่อวาน'
        : '${dt.day}/${dt.month}/${dt.year}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.grey[300], thickness: 0.5)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: GoogleFonts.manrope(textStyle: TextStyle(fontFamilyFallback: [GoogleFonts.notoSansThai().fontFamily ?? 'Noto Sans Thai']), 
                fontSize: 11,
                color: Colors.grey[400],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: Divider(color: Colors.grey[300], thickness: 0.5)),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final String text;
  final String time;
  final bool isMe;
  final String status;
  final bool showAvatar;
  final String avatarUrl;
  final bool showTime; // ← เพิ่ม
  final VoidCallback onTap; // ← เพิ่ม

  const _Bubble({
    required this.text,
    required this.time,
    required this.isMe,
    required this.status,
    required this.showAvatar,
    required this.avatarUrl,
    required this.showTime,
    required this.onTap, // ← เพิ่ม
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe)
            showAvatar
                ? Padding(
                    padding: const EdgeInsets.only(right: 8, bottom: 4),
                    child: _Avatar(url: avatarUrl, radius: 13),
                  )
                : const SizedBox(width: 34),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.68,
            ),
            child: Column(
              crossAxisAlignment: isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  // ← ครอบ bubble ด้วย GestureDetector
                  onTap: onTap,
                  onLongPress: () {
                    HapticFeedback.mediumImpact();
                    Clipboard.setData(ClipboardData(text: text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('คัดลอกข้อความแล้ว', style: GoogleFonts.manrope(textStyle: TextStyle(fontFamilyFallback: [GoogleFonts.notoSansThai().fontFamily ?? 'Noto Sans Thai']), fontSize: 13)),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                        margin: const EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    clipBehavior:
                        Clip.hardEdge, // ← ตัดตัวอักษรที่ล้นออกจากกรอบ
                    decoration: BoxDecoration(
                      color: isMe ? _kAccent : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(isMe ? 18 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 18),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Text(
                      text,
                      style: GoogleFonts.manrope(textStyle: TextStyle(fontFamilyFallback: [GoogleFonts.notoSansThai().fontFamily ?? 'Noto Sans Thai']), 
                        fontSize: 15,
                        height: 1.4,
                        color: isMe ? Colors.white : const Color(0xFF191C1D),
                      ),
                      strutStyle: const StrutStyle(
                        fontSize: 15,
                        height: 1.4,
                        forceStrutHeight: true,
                      ),
                    ),
                  ),
                ),
                // ซ่อน/แสดงด้วย AnimatedSize ให้ smooth
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  child: showTime
                      ? Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                time,
                                style: GoogleFonts.manrope(textStyle: TextStyle(fontFamilyFallback: [GoogleFonts.notoSansThai().fontFamily ?? 'Noto Sans Thai']), 
                                  fontSize: 10,
                                  color: Colors.grey[400],
                                ),
                              ),
                              if (isMe) ...[
                                const SizedBox(width: 4),
                                _StatusIcon(status: status),
                              ],
                            ],
                          ),
                        )
                      : const SizedBox.shrink(), // ← ซ่อนเวลาตอนไม่ได้กด
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  final String status;
  const _StatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case 'sending':
        return SizedBox(
          width: 10,
          height: 10,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: Colors.grey[400],
          ),
        );
      case 'error':
        return Icon(
          Icons.error_outline_rounded,
          size: 12,
          color: Colors.red[400],
        );
      default:
        return Icon(Icons.done_rounded, size: 12, color: Colors.grey[400]);
    }
  }
}
