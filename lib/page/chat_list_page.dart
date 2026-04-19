import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'chat_room_page.dart';
import 'chat_events.dart'; // EventBus แทน globalRefresh

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => ChatListPageState();
}

class ChatListPageState extends State<ChatListPage> {
  final _supabase = Supabase.instance.client;
  final _scrollCtrl = ScrollController();

  late final String _myUserId;
  bool _isLoading = true;
  bool _hasError = false;
  List<Map<String, dynamic>> _rooms = [];

  RealtimeChannel? _realtimeChannel;
  StreamSubscription? _eventSub;

  // ─── init ────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _myUserId = _supabase.auth.currentUser?.id ?? '';
    _init();
  }

  @override
  void dispose() {
    if (_realtimeChannel != null) _supabase.removeChannel(_realtimeChannel!);
    _eventSub?.cancel();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    if (_myUserId.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    await _fetchRooms(showLoading: true);
    _setupRealtime();
    _listenEvents();
  }

  // ─── data ─────────────────────────────────────────────────────────────────
  Future<void> _fetchRooms({bool showLoading = false}) async {
    if (showLoading && mounted) setState(() { _isLoading = true; _hasError = false; });

    try {
      final data = await _supabase
          .from('chat_list_view')
          .select()
          .or('buyer_id.eq.$_myUserId,seller_id.eq.$_myUserId')
          .order('last_message_time', ascending: false, nullsFirst: false);

      if (mounted) {
        setState(() {
          _rooms = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
          _hasError = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() { _isLoading = false; _hasError = showLoading; });
    }
  }

  /// Realtime: ฟังการเปลี่ยนแปลงของ chat_rooms จาก Supabase
  void _setupRealtime() {
    _realtimeChannel = _supabase
        .channel('inbox:$_myUserId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chat_rooms',
          callback: (_) => _fetchRooms(),
        )
        .subscribe();
  }

  /// EventBus: ฟังเมื่อ ChatRoomPage ส่งข้อความสำเร็จ
  void _listenEvents() {
    _eventSub = ChatEvents.instance.onRoomUpdated.listen((_) => _fetchRooms());
  }

  // ─── public API (MainScreen เรียกผ่าน GlobalKey) ─────────────────────────
  void scrollToTopAndRefresh() {
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(0,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
    _fetchRooms(showLoading: true);
  }

  // ─── helpers ──────────────────────────────────────────────────────────────
  String _formatTime(String? raw) {
  if (raw == null) return '';
  final dt = DateTime.parse(raw).toLocal();
  final now = DateTime.now();
  final diff = now.difference(dt);

  if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
    // วันนี้ → แสดงเวลา
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  } else if (diff.inDays == 1) {
    return 'เมื่อวาน';
  } else if (diff.inDays < 7) {
    // แทน DateFormat('E', 'th') ด้วย map ตรงๆ ไม่ต้องพึ่ง locale
    const days = ['จ.', 'อ.', 'พ.', 'พฤ.', 'ศ.', 'ส.', 'อา.'];
    return days[dt.weekday - 1];
  } else {
    return '${dt.day}/${dt.month}/${dt.year % 100}';
  }
}

  Map<String, String?> _peerOf(Map<String, dynamic> room) {
    final isBuyer = room['buyer_id'] == _myUserId;
    return {
      'id': isBuyer ? room['seller_id'] : room['buyer_id'],
      'name': isBuyer ? room['seller_name'] : room['buyer_name'],
      'avatar': isBuyer ? room['seller_avatar'] : room['buyer_avatar'],
    };
  }

  // ─── build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: true,
      title: Text(
        'INBOX',
        style: GoogleFonts.manrope(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          letterSpacing: 2.5,
          color: const Color(0xFF35408B),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.edit_square, size: 22, color: Color(0xFF35408B)),
          tooltip: 'แชทใหม่',
          onPressed: () {/* TODO: new chat flow */},
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading) return _buildSkeleton();

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 52, color: Colors.grey),
            const SizedBox(height: 12),
            Text('โหลดไม่สำเร็จ',
                style: GoogleFonts.manrope(color: Colors.grey[600])),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _fetchRooms(showLoading: true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF35408B),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('ลองใหม่',
                  style: GoogleFonts.manrope(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    if (_rooms.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline_rounded,
                size: 72, color: Colors.grey.withOpacity(0.25)),
            const SizedBox(height: 16),
            Text('ยังไม่มีการสนทนา',
                style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[400])),
            const SizedBox(height: 6),
            Text('เริ่มแชทจากหน้าสินค้าได้เลย',
                style:
                    GoogleFonts.manrope(fontSize: 13, color: Colors.grey[400])),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF35408B),
      onRefresh: () => _fetchRooms(showLoading: false),
      child: ListView.builder(
        controller: _scrollCtrl,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _rooms.length,
        itemBuilder: (context, index) {
          final room = _rooms[index];
          final peer = _peerOf(room);
          return _RoomTile(
            roomId: room['room_id'] ?? room['id'],
            peer: peer,
            lastMessage: room['last_message'] ?? '',
            time: _formatTime(room['last_message_time']),
            unreadCount: (room['unread_count'] ?? 0) as int,
            myUserId: _myUserId,
          );
        },
      ),
    );
  }

  // Skeleton Loading — ดูดีกว่า CircularProgressIndicator
  Widget _buildSkeleton() {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: 7,
      itemBuilder: (_, i) => const _SkeletonTile(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ROOM TILE
// ─────────────────────────────────────────────────────────────────────────────
class _RoomTile extends StatelessWidget {
  final String roomId;
  final Map<String, String?> peer;
  final String lastMessage;
  final String time;
  final int unreadCount;
  final String myUserId;

  const _RoomTile({
    required this.roomId,
    required this.peer,
    required this.lastMessage,
    required this.time,
    required this.unreadCount,
    required this.myUserId,
  });

  @override
  Widget build(BuildContext context) {
    final hasUnread = unreadCount > 0;

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatRoomPage(
            roomId: roomId,
            targetSellerId: peer['id'],
            peerName: peer['name'],
            peerAvatar: peer['avatar'],
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: const BoxDecoration(
          border: Border(
              bottom: BorderSide(color: Color(0xFFF1F3F4), width: 0.8)),
        ),
        child: Row(
          children: [
            // Avatar
            Stack(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: const Color(0xFFE2E9EC),
                  backgroundImage: (peer['avatar']?.isNotEmpty ?? false)
                      ? NetworkImage(peer['avatar']!)
                      : null,
                  child: (peer['avatar']?.isEmpty ?? true)
                      ? Icon(Icons.person_rounded,
                          color: Colors.grey[500], size: 26)
                      : null,
                ),
                if (hasUnread)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Color(0xFF35408B),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            // Name + last message
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    peer['name'] ?? 'VAULT User',
                    style: GoogleFonts.manrope(
                      fontSize: 15,
                      fontWeight:
                          hasUnread ? FontWeight.w700 : FontWeight.w600,
                      color: const Color(0xFF191C1D),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    lastMessage.isEmpty ? 'เริ่มการสนทนา' : lastMessage,
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      color: hasUnread
                          ? const Color(0xFF35408B)
                          : Colors.grey[500],
                      fontWeight:
                          hasUnread ? FontWeight.w600 : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Time + unread badge
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  time,
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    color: hasUnread
                        ? const Color(0xFF35408B)
                        : Colors.grey[400],
                    fontWeight:
                        hasUnread ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                if (hasUnread) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF35408B),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      unreadCount > 99 ? '99+' : '$unreadCount',
                      style: GoogleFonts.manrope(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SKELETON TILE
// ─────────────────────────────────────────────────────────────────────────────
class _SkeletonTile extends StatefulWidget {
  const _SkeletonTile();

  @override
  State<_SkeletonTile> createState() => _SkeletonTileState();
}

class _SkeletonTileState extends State<_SkeletonTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 0.9).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Opacity(
        opacity: _anim.value,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: const BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: Color(0xFFF1F3F4), width: 0.8))),
          child: Row(
            children: [
              const CircleAvatar(
                  radius: 26, backgroundColor: Color(0xFFE8EAED)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _bar(140, 14),
                    const SizedBox(height: 8),
                    _bar(200, 12),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _bar(36, 11),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bar(double w, double h) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: const Color(0xFFE8EAED),
          borderRadius: BorderRadius.circular(6),
        ),
      );
}