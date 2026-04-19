import 'dart:async';

/// EventBus สำหรับระบบแชท
/// ใช้แทน ChatListPage.globalRefresh เพื่อให้ Page ไม่ coupling กัน
///
/// วาง file นี้ที่ lib/core/chat_events.dart หรือ lib/page/chat_events.dart
/// แล้ว import ใน chat_room_page.dart และ chat_list_page.dart
class ChatEvents {
  ChatEvents._();
  static final instance = ChatEvents._();

  final _controller = StreamController<String>.broadcast();

  /// Stream ที่ปล่อย roomId เมื่อมีข้อความส่งสำเร็จ
  Stream<String> get onRoomUpdated => _controller.stream;

  /// เรียกเมื่อส่งข้อความสำเร็จ — ChatListPage จะรีเฟรชอัตโนมัติ
  void notifyRoomUpdated(String roomId) {
    if (!_controller.isClosed) _controller.add(roomId);
  }

  /// เรียกตอน App dispose (ถ้าจำเป็น)
  void dispose() => _controller.close();
}