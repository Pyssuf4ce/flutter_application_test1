import 'package:intl/intl.dart';

/// หมวดหมู่สินค้ากลาง — ใช้ไฟล์นี้แทนการประกาศซ้ำใน discover, post_item, edit_item
const kProductCategories = [
  'แฟชั่น',
  'ไอที/อุปกรณ์',
  'ความงาม',
  'งานบริการ',
  'อาหาร',
  'ของสะสม',
  'ทั่วไป',
];

/// จัดรูปแบบราคาสินค้า เช่น 1500 → "1,500"
String formatPrice(dynamic price) {
  final num value = (price is num)
      ? price
      : (double.tryParse(price?.toString() ?? '0') ?? 0);
  return NumberFormat('#,##0').format(value);
}
