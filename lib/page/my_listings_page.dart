import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';
import '../models/product_model.dart';
import '../services/product_service.dart';
import 'edit_item_page.dart';

class MyListingsPage extends StatefulWidget {
  const MyListingsPage({super.key});

  @override
  State<MyListingsPage> createState() => _MyListingsPageState();
}

class _MyListingsPageState extends State<MyListingsPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;

  /// 💡 ฟังก์ชันลบสินค้าแบบใหม่ ใช้ ProductService
  Future<void> _deleteItem(Product item) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text("ลบรายการนี้?", style: GoogleFonts.manrope(fontWeight: FontWeight.bold, color: Colors.red)),
        content: Text("ยืนยันการลบสินค้า ข้อมูลจะหายไปทันทีและไม่สามารถกู้คืนได้นะ", style: GoogleFonts.manrope()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), 
            child: Text("ยกเลิก", style: GoogleFonts.manrope(color: Colors.grey))
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red, 
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
            ),
            child: Text("ยืนยันการลบ", style: GoogleFonts.manrope(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await ProductService.instance.deleteProduct(item.id, item.imageUrls);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ลบรายการเรียบร้อยแล้ว'), 
              backgroundColor: Colors.green, 
              behavior: SnackBarBehavior.floating
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('เกิดข้อผิดพลาด: ${e.toString()}'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _supabase.auth.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF35408B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "MY LISTINGS",
          style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2, color: const Color(0xFF35408B)),
        ),
        centerTitle: true,
      ),
      body: user == null
          ? const Center(child: Text("กรุณาเข้าสู่ระบบก่อนนะคุณ Kong"))
          : Stack(
              children: [
                StreamBuilder<List<Product>>(
                  stream: ProductService.instance.streamProductsBySeller(user.id),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Color(0xFF4D58A5)));
                    }

                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.withValues(alpha: 0.5)),
                            const SizedBox(height: 16),
                            Text("คุณยังไม่มีรายการสินค้าในขณะนี้", style: GoogleFonts.manrope(color: Colors.grey, fontSize: 16)),
                          ],
                        ),
                      );
                    }

                    final items = snapshot.data!;

                    return ListView.builder(
                      padding: const EdgeInsets.all(24),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final title = item.name;
                        final imageUrl = item.imageUrl;
                        final category = item.category;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF4D58A5).withValues(alpha: 0.04), 
                                blurRadius: 20, 
                                offset: const Offset(0, 10)
                              )
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
                                  image: imageUrl.isNotEmpty
                                      ? DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover)
                                      : null,
                                  color: const Color(0xFFE2E9EC),
                                ),
                                child: imageUrl.isEmpty ? const Icon(Icons.image, color: Colors.grey) : null,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(category.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                                    const SizedBox(height: 4),
                                    Text(title, style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 4),
                                    Text("${formatPrice(item.price)} THB", style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF4D58A5))),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, color: Color(0xFF35408B)),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => EditItemPage(item: item.toRawMap())),
                                      );
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                    onPressed: () => _deleteItem(item),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 8),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
                if (_isLoading)
                  Container(
                    color: Colors.black.withValues(alpha: 0.1),
                    child: const Center(child: CircularProgressIndicator(color: Color(0xFF4D58A5))),
                  ),
              ],
            ),
    );
  }
}