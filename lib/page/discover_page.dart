import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shimmer/shimmer.dart';
import 'product_detail_page.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});

  @override
  State<DiscoverPage> createState() => DiscoverPageState();
}

class DiscoverPageState extends State<DiscoverPage> {
  final _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey = GlobalKey<RefreshIndicatorState>();

  String _searchQuery = '';
  String _selectedCategory = 'ทั้งหมด';
  Timer? _debounce;

  final List<String> _categories = [
    'ทั้งหมด',
    'แฟชั่น',
    'ไอที/อุปกรณ์',
    'ความงาม',
    'งานบริการ',
    'อาหาร',
    'ของสะสม',
    'ทั่วไป'
  ];

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() => _searchQuery = value.trim());
    });
  }

  void scrollToTopAndRefresh() {
    if (_scrollController.hasClients) {
      if (_scrollController.offset > 0) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 600),
          curve: Curves.fastOutSlowIn,
        );
      } else {
        _refreshIndicatorKey.currentState?.show();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          "VAULT",
          style: GoogleFonts.manrope(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 4,
            color: const Color(0xFF35408B),
          ),
        ),
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.grid_view_rounded, color: Color(0xFF35408B)), onPressed: () {}),
        actions: [IconButton(icon: const Icon(Icons.notifications_none, color: Colors.grey), onPressed: () {})],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("ค้นหาสิ่งที่ต้องการ", style: GoogleFonts.manrope(fontSize: 28, fontWeight: FontWeight.w800, color: const Color(0xFF191C1D), height: 1.1)),
                const SizedBox(height: 20),
                TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF767682)),
                    hintText: "ค้นหาสินค้าหรือบริการที่คุณสนใจ...",
                    hintStyle: GoogleFonts.manrope(fontSize: 14, color: Colors.grey),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 50,
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse}),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: _categories.map((category) {
                    final isSelected = _selectedCategory == category;
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedCategory = category),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF35408B) : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: isSelected ? Colors.transparent : Colors.grey.withOpacity(0.1)),
                          ),
                          child: Text(
                            category,
                            style: GoogleFonts.manrope(color: isSelected ? Colors.white : Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: RefreshIndicator(
              key: _refreshIndicatorKey,
              onRefresh: () async {
                setState(() {});
                await Future.delayed(const Duration(seconds: 1));
              },
              color: const Color(0xFF35408B),
              child: StreamBuilder<List<Map<String, dynamic>>>(
                // 💡 1. ปลดล็อกตัวกรองออกจาก Stream เพื่อให้รับรู้ตอนโดนลบได้ 100%
                stream: Supabase.instance.client
                    .from('products')
                    .stream(primaryKey: ['id'])
                    .order('created_at'),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                    return _buildShimmerGrid();
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text("เกิดข้อผิดพลาดในการโหลดข้อมูล", style: GoogleFonts.manrope(color: Colors.red)));
                  }

                  final allProducts = snapshot.data ?? [];
                  
                  final products = allProducts.where((item) {
                    // 💡 2. ย้ายมากรองของที่ยัง 'available' ในนี้แทน! (ปราบผีสำเร็จ)
                    if (item['status'] != 'available') return false;

                    final name = (item['name'] ?? '').toString().toLowerCase();
                    final cat = item['category'] ?? 'ทั่วไป';
                    
                    final matchesSearch = name.contains(_searchQuery.toLowerCase());
                    final matchesCategory = _selectedCategory == 'ทั้งหมด' || cat == _selectedCategory;
                    
                    return matchesSearch && matchesCategory;
                  }).toList();

                  if (products.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                        Center(child: Text("ไม่พบสินค้าที่คุณต้องการ", style: GoogleFonts.manrope(color: Colors.grey))),
                      ],
                    );
                  }

                  return GridView.builder(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.72,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: products.length,
                    itemBuilder: (context, index) => _buildGridCard(context, products[index]),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerGrid() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.72,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: 6,
        itemBuilder: (_, __) => Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Container(decoration: const BoxDecoration(borderRadius: BorderRadius.vertical(top: Radius.circular(20)), color: Colors.white))),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 40, height: 10, color: Colors.white),
                    const SizedBox(height: 8),
                    Container(width: double.infinity, height: 14, color: Colors.white),
                    const SizedBox(height: 8),
                    Container(width: 60, height: 16, color: Colors.white),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGridCard(BuildContext context, Map<String, dynamic> item) {
    final String title = item['name'] ?? 'ไม่มีชื่อสินค้า';
    final String category = item['category'] ?? 'ทั่วไป';
    final String price = item['price']?.toString() ?? '0';
    final String imageUrl = item['image_url'] ?? '';

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ProductDetailPage(productData: item))),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: const Color(0xFF4D58A5).withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Hero(
                tag: 'product_image_${item['id']}',
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    color: const Color(0xFFF5F7FA),
                    image: imageUrl.isNotEmpty ? DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover) : null,
                  ),
                  child: imageUrl.isEmpty ? const Center(child: Icon(Icons.image, color: Colors.grey)) : null,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(category.toUpperCase(), style: GoogleFonts.manrope(fontSize: 9, fontWeight: FontWeight.w800, color: const Color(0xFF35408B).withOpacity(0.6))),
                  const SizedBox(height: 4),
                  Text(title, style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF191C1D)), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Text("$price THB", style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w900, color: const Color(0xFF35408B))),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}