/// Product model — แทนการใช้ Map แบบดิบๆ
class Product {
  final String id;
  final String sellerId;
  final String name;
  final double price;
  final String description;
  final String category;
  final String imageUrl;       // รูปแรก (backward compat)
  final List<String> imageUrls; // รูปทั้งหมด
  final String status;         // 'available' | 'sold' | 'hidden'
  final DateTime? createdAt;

  const Product({
    required this.id,
    required this.sellerId,
    required this.name,
    required this.price,
    required this.description,
    required this.category,
    required this.imageUrl,
    required this.imageUrls,
    this.status = 'available',
    this.createdAt,
  });

  // ── แปลง Map จาก Supabase → Product ──
  factory Product.fromJson(Map<String, dynamic> json) {
    // รองรับทั้ง image_urls (array) และ image_url (string เดี่ยว)
    final List<String> urls = json['image_urls'] != null
        ? List<String>.from(json['image_urls'])
        : (json['image_url'] != null ? [json['image_url'] as String] : []);

    return Product(
      id: json['id'] as String? ?? '',
      sellerId: json['seller_id'] as String? ?? '',
      name: json['name'] as String? ?? 'ไม่มีชื่อสินค้า',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? 'ทั่วไป',
      imageUrl: urls.isNotEmpty ? urls.first : '',
      imageUrls: urls,
      status: json['status'] as String? ?? 'available',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  // ── แปลง Product → Map สำหรับ insert/update ──
  Map<String, dynamic> toJson() => {
        'seller_id': sellerId,
        'name': name,
        'price': price,
        'description': description,
        'category': category,
        'image_url': imageUrl,
        'image_urls': imageUrls,
        'status': status,
      };

  // ── คืน Map ดิบ (ใช้ส่งต่อให้ Page เดิมที่ยังใช้ Map) ──
  Map<String, dynamic> toRawMap() => {
        'id': id,
        'seller_id': sellerId,
        'name': name,
        'price': price,
        'description': description,
        'category': category,
        'image_url': imageUrl,
        'image_urls': imageUrls,
        'status': status,
        'created_at': createdAt?.toIso8601String(),
      };

  // ── copyWith: แก้บางฟิลด์โดยไม่ต้องสร้างใหม่ทั้งหมด ──
  Product copyWith({
    String? id,
    String? sellerId,
    String? name,
    double? price,
    String? description,
    String? category,
    String? imageUrl,
    List<String>? imageUrls,
    String? status,
    DateTime? createdAt,
  }) {
    return Product(
      id: id ?? this.id,
      sellerId: sellerId ?? this.sellerId,
      name: name ?? this.name,
      price: price ?? this.price,
      description: description ?? this.description,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      imageUrls: imageUrls ?? this.imageUrls,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  bool get isAvailable => status == 'available';

  @override
  String toString() => 'Product(id: $id, name: $name, price: $price)';
}
