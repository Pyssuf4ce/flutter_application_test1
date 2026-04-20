import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shimmer/shimmer.dart';
import '../core/constants.dart';
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
  final FocusNode _searchFocus = FocusNode();

  String _searchQuery = '';
  String _selectedCategory = 'ทั้งหมด';
  Timer? _debounce;

  final List<String> _categories = ['ทั้งหมด', ...kProductCategories];

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    _searchFocus.dispose();
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
                // ── Search bar with clear button & animation ──
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _searchFocus.hasFocus ? const Color(0xFF35408B) : Colors.transparent,
                      width: 1.5,
                    ),
                    boxShadow: _searchFocus.hasFocus
                        ? [BoxShadow(color: const Color(0xFF35408B).withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4))]
                        : [],
                  ),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocus,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF767682)),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                              },
                            )
                          : null,
                      hintText: "ค้นหาสินค้าหรือบริการที่คุณสนใจ...",
                      hintStyle: GoogleFonts.manrope(fontSize: 14, color: Colors.grey),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 50,
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
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedCategory = category);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF35408B) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isSelected ? Colors.transparent : Colors.grey.withValues(alpha: 0.1)),
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
                    if (item['status'] != 'available') return false;

                    final name = (item['name'] ?? '').toString().toLowerCase();
                    final cat = item['category'] ?? 'ทั่วไป';
                    
                    final matchesSearch = name.contains(_searchQuery.toLowerCase());
                    final matchesCategory = _selectedCategory == 'ทั้งหมด' || cat == _selectedCategory;
                    
                    return matchesSearch && matchesCategory;
                  }).toList();

                  if (products.isEmpty) {
                    return _buildEmptyState();
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
                    itemBuilder: (context, index) => _StaggeredCard(
                      index: index,
                      child: _buildGridCard(context, products[index]),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Empty state ──
  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.15),
        Center(
          child: Column(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF35408B).withValues(alpha: 0.06),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.search_off_rounded, size: 40, color: Color(0xFF35408B)),
              ),
              const SizedBox(height: 20),
              Text("ไม่พบสินค้าที่คุณต้องการ", style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[600])),
              const SizedBox(height: 8),
              Text("ลองค้นหาด้วยคำอื่น หรือเปลี่ยนหมวดหมู่ดู", style: GoogleFonts.manrope(fontSize: 13, color: Colors.grey[400])),
            ],
          ),
        ),
      ],
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
    final String formattedPrice = formatPrice(item['price']);
    final String imageUrl = item['image_url'] ?? '';

    return _PressableCard(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => ProductDetailPage(productData: item),
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(
                opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 300),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: const Color(0xFF4D58A5).withValues(alpha: 0.04), blurRadius: 20, offset: const Offset(0, 10))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Hero(
                tag: 'product_image_${item['id']}',
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: Container(
                    color: const Color(0xFFF5F7FA),
                    child: imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            // ── Smooth fade-in เมื่อโหลดรูปเสร็จ ──
                            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                              if (wasSynchronouslyLoaded) return child;
                              return AnimatedOpacity(
                                opacity: frame == null ? 0 : 1,
                                duration: const Duration(milliseconds: 400),
                                curve: Curves.easeOut,
                                child: child,
                              );
                            },
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(Icons.broken_image_outlined, color: Colors.grey),
                            ),
                          )
                        : const Center(child: Icon(Icons.image, color: Colors.grey)),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(category.toUpperCase(), style: GoogleFonts.manrope(fontSize: 9, fontWeight: FontWeight.w800, color: const Color(0xFF35408B).withValues(alpha: 0.6))),
                  const SizedBox(height: 4),
                  Text(title, style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF191C1D)), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  // ── Price badge ──
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF35408B).withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text("฿$formattedPrice", style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w900, color: const Color(0xFF35408B))),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Staggered fade-in animation per card
// ─────────────────────────────────────────────
class _StaggeredCard extends StatefulWidget {
  final int index;
  final Widget child;
  const _StaggeredCard({required this.index, required this.child});

  @override
  State<_StaggeredCard> createState() => _StaggeredCardState();
}

class _StaggeredCardState extends State<_StaggeredCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    // Stagger: delay based on index, but cap at 6 to avoid long waits
    final delay = Duration(milliseconds: (widget.index % 6) * 60);
    Future.delayed(delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Pressable card with scale effect
// ─────────────────────────────────────────────
class _PressableCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _PressableCard({required this.child, required this.onTap});

  @override
  State<_PressableCard> createState() => _PressableCardState();
}

class _PressableCardState extends State<_PressableCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0,
      upperBound: 1,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: widget.child,
      ),
    );
  }
}