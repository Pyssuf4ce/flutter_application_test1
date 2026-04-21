import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product_model.dart';

/// ProductService — รวม CRUD + Storage ทั้งหมดไว้ที่เดียว
/// แทนการเรียก Supabase ตรงๆ ในแต่ละหน้า
class ProductService {
  // Singleton pattern: ใช้ ProductService.instance ได้เลยทุกที่
  ProductService._();
  static final ProductService instance = ProductService._();

  final _db = Supabase.instance.client;
  static const _table = 'products';
  static const _bucket = 'product_images';

  // ━━━━━━━━━━━━━━━ READ ━━━━━━━━━━━━━━━

  /// Stream สินค้าแบบเรียลไทม์ (ทั้งหมด)
  Stream<List<Product>> streamProducts() {
    return _db
        .from(_table)
        .stream(primaryKey: ['id'])
        .order('created_at')
        .map((list) => list.map((e) => Product.fromJson(e)).toList());
  }

  /// Stream สินค้าแบบเรียลไทม์ (รายตัว)
  Stream<Product?> streamProductById(String id) {
    return _db
        .from(_table)
        .stream(primaryKey: ['id'])
        .eq('id', id)
        .map((list) => list.isNotEmpty ? Product.fromJson(list.first) : null);
  }

  /// Stream สินค้าของผู้ขายแบบเรียลไทม์
  Stream<List<Product>> streamProductsBySeller(String sellerId) {
    return _db
        .from(_table)
        .stream(primaryKey: ['id'])
        .eq('seller_id', sellerId)
        .order('created_at')
        .map((list) => list.map((e) => Product.fromJson(e)).toList());
  }

  /// ดึงสินค้าทั้งหมดที่ status = available
  Future<List<Product>> getAvailableProducts() async {
    final data = await _db
        .from(_table)
        .select()
        .eq('status', 'available')
        .order('created_at', ascending: false);
    return (data as List).map((e) => Product.fromJson(e)).toList();
  }

  /// ดึงสินค้าตาม ID
  Future<Product?> getProductById(String id) async {
    final data = await _db.from(_table).select().eq('id', id).maybeSingle();
    if (data == null) return null;
    return Product.fromJson(data);
  }

  /// ดึงสินค้าของผู้ขายคนนั้น
  Future<List<Product>> getProductsBySeller(String sellerId) async {
    final data = await _db
        .from(_table)
        .select()
        .eq('seller_id', sellerId)
        .order('created_at', ascending: false);
    return (data as List).map((e) => Product.fromJson(e)).toList();
  }

  /// ค้นหาสินค้าตามคำค้นและหมวดหมู่
  Future<List<Product>> searchProducts({
    String query = '',
    String category = 'ทั้งหมด',
  }) async {
    var req = _db.from(_table).select().eq('status', 'available');

    if (category != 'ทั้งหมด') {
      req = req.eq('category', category);
    }

    final data = await req.order('created_at', ascending: false);
    final products = (data as List).map((e) => Product.fromJson(e)).toList();

    // Filter ชื่อในฝั่ง client (Supabase free tier ไม่มี full-text search)
    if (query.isEmpty) return products;
    final q = query.toLowerCase();
    return products.where((p) => p.name.toLowerCase().contains(q)).toList();
  }

  // ━━━━━━━━━━━━━━━ CREATE ━━━━━━━━━━━━━━━

  /// ลงสินค้าใหม่ (รับ imageBytes เพื่ออัปโหลดรูปด้วย)
  Future<Product> createProduct({
    required String name,
    required double price,
    required String description,
    required String category,
    required List<Uint8List> imageBytesList,
    required List<String> fileNames,
  }) async {
    final user = _db.auth.currentUser;
    if (user == null) throw Exception('กรุณาเข้าสู่ระบบก่อน');

    // 1. อัปโหลดรูปทั้งหมดพร้อมกัน
    final urls = await uploadImages(
      imageBytesList: imageBytesList,
      fileNames: fileNames,
      userId: user.id,
    );

    // 2. บันทึกข้อมูลสินค้า
    final newProduct = Product(
      id: '',
      sellerId: user.id,
      name: name,
      price: price,
      description: description,
      category: category,
      imageUrl: urls.isNotEmpty ? urls.first : '',
      imageUrls: urls,
    );

    final inserted = await _db
        .from(_table)
        .insert(newProduct.toJson())
        .select()
        .single();

    return Product.fromJson(inserted);
  }

  // ━━━━━━━━━━━━━━━ UPDATE ━━━━━━━━━━━━━━━

  /// แก้ไขข้อมูลสินค้า
  Future<void> updateProduct({
    required String id,
    required String name,
    required double price,
    required String description,
    required String category,
    required List<String> existingImageUrls,
    List<Uint8List> newImageBytesList = const [],
    List<String> newFileNames = const [],
    String? userId,
  }) async {
    final user = _db.auth.currentUser;
    if (user == null) throw Exception('กรุณาเข้าสู่ระบบก่อน');

    // อัปโหลดรูปใหม่ (ถ้ามี)
    List<String> finalUrls = List.from(existingImageUrls);
    if (newImageBytesList.isNotEmpty) {
      final uploaded = await uploadImages(
        imageBytesList: newImageBytesList,
        fileNames: newFileNames,
        userId: user.id,
      );
      finalUrls.addAll(uploaded);
    }

    await _db.from(_table).update({
      'name': name,
      'price': price,
      'description': description,
      'category': category,
      'image_url': finalUrls.isNotEmpty ? finalUrls.first : '',
      'image_urls': finalUrls,
    }).eq('id', id);
  }

  /// เปลี่ยน status สินค้า (available / sold / hidden)
  Future<void> updateStatus(String id, String status) async {
    await _db.from(_table).update({'status': status}).eq('id', id);
  }

  // ━━━━━━━━━━━━━━━ DELETE ━━━━━━━━━━━━━━━

  /// ลบสินค้าพร้อมรูป (ใช้ RPC ที่ตั้งไว้แล้วใน Supabase)
  Future<void> deleteProduct(String id, List<String> imageUrls) async {
    // ลบจาก DB ก่อน (ผ่าน RPC ที่จัดการ cascade ให้)
    await _db.rpc('delete_product_completely', params: {'p_id': id});

    // ตามลบรูปใน Storage (fire & forget)
    _deleteImages(imageUrls);
  }

  // ━━━━━━━━━━━━━━━ STORAGE ━━━━━━━━━━━━━━━

  /// อัปโหลดรูปหลายรูปพร้อมกัน → คืน URL list
  Future<List<String>> uploadImages({
    required List<Uint8List> imageBytesList,
    required List<String> fileNames,
    required String userId,
  }) async {
    final tasks = <Future<String>>[];

    for (int i = 0; i < imageBytesList.length; i++) {
      final ext = fileNames[i].contains('.') ? fileNames[i].split('.').last : 'jpg';
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_$i.$ext';
      final path = '$userId/$fileName';

      tasks.add(() async {
        await _db.storage.from(_bucket).uploadBinary(
          path,
          imageBytesList[i],
          fileOptions: FileOptions(contentType: 'image/$ext'),
        );
        return _db.storage.from(_bucket).getPublicUrl(path);
      }());
    }

    return Future.wait(tasks);
  }

  /// ลบรูปออกจาก Storage (แปลง URL → path)
  Future<void> _deleteImages(List<String> urls) async {
    if (urls.isEmpty) return;
    try {
      final paths = <String>[];
      for (final url in urls) {
        final uri = Uri.parse(url);
        final idx = uri.pathSegments.indexOf(_bucket);
        if (idx != -1) {
          paths.add(uri.pathSegments.sublist(idx + 1).join('/'));
        }
      }
      if (paths.isNotEmpty) {
        await _db.storage.from(_bucket).remove(paths);
      }
    } catch (e) {
      // Fire & forget — ไม่ throw เพราะสินค้าลบไปแล้ว
    }
  }

  /// ลบรูปบางรูปออก (ใช้ตอน edit)
  Future<void> deleteImageUrls(List<String> urls) => _deleteImages(urls);
}
