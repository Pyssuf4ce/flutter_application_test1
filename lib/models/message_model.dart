import 'package:hive/hive.dart';

part 'message_model.g.dart';

@HiveType(typeId: 0)
class LocalMessage extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String roomId;

  @HiveField(2)
  final String senderId;

  @HiveField(3)
  final String content;

  @HiveField(4)
  final DateTime createdAt;

  @HiveField(5)
  String status; // 💡 เอา 'final' ออกเพื่อให้แก้ไขค่าได้ (เช่น จาก 'sending' เป็น 'sent')

  LocalMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.content,
    required this.createdAt,
    this.status = 'sending',
  });
}