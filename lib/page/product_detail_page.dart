import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';
import '../services/product_service.dart';
import 'seller_profile_page.dart';
import 'edit_item_page.dart';
import 'chat_room_page.dart';

const _kAccent = Color(0xFF35408B);
const _kAccentLight = Color(0xFFEEF0FA);
const _kDark = Color(0xFF191C1D);

class ProductDetailPage extends StatefulWidget {
  final Map<String, dynamic> productData;
  const ProductDetailPage({super.key, required this.productData});
  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage>
    with SingleTickerProviderStateMixin {
  final PageController _pageCtrl = PageController();
  int _imgIdx = 0;
  late Future<Map<String, dynamic>?> _sellerFuture;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _sellerFuture = _fetchSeller(widget.productData['seller_id'] ?? '');
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>?> _fetchSeller(String id) async {
    if (id.isEmpty) return null;
    return await Supabase.instance.client
        .from('profiles').select('username, avatar_url').eq('id', id).maybeSingle();
  }

  @override
  Widget build(BuildContext context) {
    final pid = widget.productData['id'];
    return StreamBuilder(
      stream: ProductService.instance.streamProductById(pid),
      builder: (context, snap) {
        if (snap.hasData && snap.data == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (Navigator.canPop(context)) Navigator.pop(context);
          });
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final d = snap.data?.toRawMap() ?? widget.productData;
        return _page(d);
      },
    );
  }

  Widget _page(Map<String, dynamic> data) {
    final title = data['name'] ?? 'ไม่มีชื่อสินค้า';
    final price = formatPrice(data['price']);
    final desc = data['description'] ?? 'ไม่มีรายละเอียดเพิ่มเติม';
    final cat = data['category'] ?? 'ทั่วไป';
    final sellerId = data['seller_id'] ?? '';
    final List<dynamic> imgs = data['image_urls'] ?? ([data['image_url']].where((e) => e != null).toList());
    final isOwn = Supabase.instance.client.auth.currentUser?.id == sellerId;
    final screenW = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Stack(
          children: [
            // ── Background gradient ──
            Positioned(
              top: 0, left: 0, right: 0, height: screenW * 0.85,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFE8EAF6), Color(0xFFF5F6FA)],
                  ),
                ),
              ),
            ),

            // ── Scrollable content ──
            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // ── Top bar ──
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  pinned: true,
                  leading: _circleBtn(Icons.arrow_back_ios_new_rounded, () => Navigator.pop(context)),
                  actions: [
                    if (!isOwn) _circleBtn(Icons.favorite_border_rounded, () {
                      HapticFeedback.lightImpact();
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text("เพิ่มในรายการโปรดแล้ว", style: GoogleFonts.manrope(textStyle: TextStyle(fontFamilyFallback: [GoogleFonts.notoSansThai().fontFamily ?? 'Noto Sans Thai']), )),
                        behavior: SnackBarBehavior.floating,
                        margin: const EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ));
                    }),
                    const SizedBox(width: 4),
                  ],
                ),

                // ── Image showcase card ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        // Main image in rounded card
                        Hero(
                          tag: 'product_image_${data['id']}',
                          child: Container(
                            height: screenW * 0.85,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(color: _kAccent.withValues(alpha: 0.08), blurRadius: 40, offset: const Offset(0, 16)),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(28),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  PageView.builder(
                                    controller: _pageCtrl,
                                    itemCount: imgs.length,
                                    onPageChanged: (i) => setState(() => _imgIdx = i),
                                    itemBuilder: (_, i) => GestureDetector(
                                      onTap: () => _openViewer(imgs, i),
                                      child: Image.network(
                                        imgs[i], fit: BoxFit.cover,
                                        frameBuilder: (_, child, frame, sync) {
                                          if (sync) return child;
                                          return AnimatedOpacity(
                                            opacity: frame == null ? 0 : 1,
                                            duration: const Duration(milliseconds: 400),
                                            child: child,
                                          );
                                        },
                                        errorBuilder: (_, __, ___) => Container(
                                          color: const Color(0xFFF5F7FA),
                                          child: const Center(child: Icon(Icons.broken_image_outlined, size: 48, color: Colors.grey)),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Counter pill
                                  if (imgs.length > 1)
                                    Positioned(
                                      bottom: 14, right: 14,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.5),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          '${_imgIdx + 1}/${imgs.length}',
                                          style: GoogleFonts.manrope(textStyle: TextStyle(fontFamilyFallback: [GoogleFonts.notoSansThai().fontFamily ?? 'Noto Sans Thai']), color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Thumbnail strip
                        if (imgs.length > 1)
                          Padding(
                            padding: const EdgeInsets.only(top: 14),
                            child: SizedBox(
                              height: 56,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(imgs.length, (i) {
                                  final active = _imgIdx == i;
                                  return GestureDetector(
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      _pageCtrl.animateToPage(i, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      width: 56, height: 56,
                                      margin: const EdgeInsets.symmetric(horizontal: 4),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: active ? _kAccent : Colors.grey.withValues(alpha: 0.15),
                                          width: active ? 2.5 : 1,
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Image.network(imgs[i], fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 16, color: Colors.grey)),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // ── Product info ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: _infoCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Category + status row
                          Row(
                            children: [
                              _chip(cat.toUpperCase(), _kAccent, _kAccentLight),
                              const Spacer(),
                              _chip("พร้อมขาย", const Color(0xFF00C48C), const Color(0xFF00C48C).withValues(alpha: 0.1), dotColor: const Color(0xFF00C48C)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Title
                          Text(title, style: GoogleFonts.manrope(textStyle: TextStyle(fontFamilyFallback: [GoogleFonts.notoSansThai().fontFamily ?? 'Noto Sans Thai']), fontSize: 22, fontWeight: FontWeight.w800, color: _kDark, height: 1.25)),
                          const SizedBox(height: 16),
                          // Price
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [_kAccent, Color(0xFF5B68C0)]),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text("฿$price", style: GoogleFonts.manrope(textStyle: TextStyle(fontFamilyFallback: [GoogleFonts.notoSansThai().fontFamily ?? 'Noto Sans Thai']), fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Description ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: _infoCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionHeader(Icons.description_outlined, "รายละเอียดสินค้า"),
                          const SizedBox(height: 12),
                          const Divider(height: 1, color: Color(0xFFF1F3F4)),
                          const SizedBox(height: 12),
                          Text(desc, style: GoogleFonts.manrope(textStyle: TextStyle(fontFamilyFallback: [GoogleFonts.notoSansThai().fontFamily ?? 'Noto Sans Thai']), fontSize: 14, color: Colors.grey[700], height: 1.7)),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Seller ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: _infoCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionHeader(Icons.storefront_rounded, "ข้อมูลผู้ขาย"),
                          const SizedBox(height: 14),
                          _sellerTile(sellerId),
                        ],
                      ),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),

            // ── Bottom action bar ──
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: _bottomBar(data, isOwn),
            ),
          ],
        ),
      ),
    );
  }

  // ━━━━━━━━━━━━━━━ COMPONENTS ━━━━━━━━━━━━━━━

  Widget _circleBtn(IconData icon, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: IconButton(
        icon: Icon(icon, color: _kDark, size: 18),
        onPressed: () { HapticFeedback.lightImpact(); onTap(); },
      ),
    );
  }

  Widget _infoCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: child,
    );
  }

  Widget _sectionHeader(IconData icon, String text) {
    return Row(children: [
      Icon(icon, size: 18, color: _kAccent),
      const SizedBox(width: 8),
      Text(text, style: GoogleFonts.manrope(textStyle: TextStyle(fontFamilyFallback: [GoogleFonts.notoSansThai().fontFamily ?? 'Noto Sans Thai']), fontSize: 15, fontWeight: FontWeight.w700, color: _kDark)),
    ]);
  }

  Widget _chip(String text, Color fg, Color bg, {Color? dotColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dotColor != null) ...[
            Container(width: 6, height: 6, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
            const SizedBox(width: 6),
          ],
          Text(text, style: GoogleFonts.manrope(textStyle: TextStyle(fontFamilyFallback: [GoogleFonts.notoSansThai().fontFamily ?? 'Noto Sans Thai']), fontSize: 10, fontWeight: FontWeight.w800, color: fg, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _sellerTile(String sellerId) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _sellerFuture,
      builder: (context, snap) {
        if (snap.hasError || (!snap.hasData && snap.connectionState == ConnectionState.done)) {
          return Row(children: [
            const CircleAvatar(radius: 24, backgroundColor: Color(0xFFF5F7FA), child: Icon(Icons.person, color: Colors.grey)),
            const SizedBox(width: 12),
            Expanded(child: Text('ไม่พบข้อมูลผู้ขาย', style: GoogleFonts.manrope(textStyle: TextStyle(fontFamilyFallback: [GoogleFonts.notoSansThai().fontFamily ?? 'Noto Sans Thai']), color: Colors.grey))),
          ]);
        }
        if (!snap.hasData) {
          return const SizedBox(height: 56, child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _kAccent))));
        }
        final name = snap.data?['username'] ?? 'ไม่ทราบชื่อ';
        final avatar = snap.data?['avatar_url'] ?? '';
        return InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SellerProfilePage(sellerId: sellerId))),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              CircleAvatar(radius: 24, backgroundColor: const Color(0xFFF5F7FA),
                backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                child: avatar.isEmpty ? const Icon(Icons.person, color: Colors.grey) : null),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: GoogleFonts.manrope(textStyle: TextStyle(fontFamilyFallback: [GoogleFonts.notoSansThai().fontFamily ?? 'Noto Sans Thai']), fontWeight: FontWeight.w700, fontSize: 15, color: _kDark)),
                const SizedBox(height: 2),
                Row(children: [
                  const Icon(Icons.verified_rounded, size: 14, color: Color(0xFF00C48C)),
                  const SizedBox(width: 4),
                  Text("Verified Member", style: GoogleFonts.manrope(textStyle: TextStyle(fontFamilyFallback: [GoogleFonts.notoSansThai().fontFamily ?? 'Noto Sans Thai']), fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w500)),
                ]),
              ])),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFFF5F7FA), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
              ),
            ]),
          ),
        );
      },
    );
  }

  Widget _bottomBar(Map<String, dynamic> data, bool isOwn) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 14, 20, MediaQuery.of(context).padding.bottom + 14),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, -4))],
      ),
      child: isOwn
          ? SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EditItemPage(item: data))),
                icon: const Icon(Icons.edit_rounded, size: 18),
                label: Text("แก้ไขข้อมูลสินค้า", style: GoogleFonts.manrope(textStyle: TextStyle(fontFamilyFallback: [GoogleFonts.notoSansThai().fontFamily ?? 'Noto Sans Thai']), fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: _kAccentLight, foregroundColor: _kAccent, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              ),
            )
          : Row(children: [
              Container(
                height: 52, width: 52,
                margin: const EdgeInsets.only(right: 12),
                child: OutlinedButton(
                  onPressed: () async {
                    HapticFeedback.lightImpact();
                    final sp = await _sellerFuture;
                    if (mounted) {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => ChatRoomPage(product: data, peerName: sp?['username'], peerAvatar: sp?['avatar_url']),
                      ));
                    }
                  },
                  style: OutlinedButton.styleFrom(padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), side: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
                  child: const Icon(Icons.chat_bubble_outline_rounded, color: _kDark, size: 20),
                ),
              ),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text("ฟีเจอร์นี้กำลังจะมาเร็วๆ นี้", style: GoogleFonts.manrope(textStyle: TextStyle(fontFamilyFallback: [GoogleFonts.notoSansThai().fontFamily ?? 'Noto Sans Thai']), )),
                        behavior: SnackBarBehavior.floating, margin: const EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ));
                    },
                    icon: const Icon(Icons.shopping_bag_outlined, size: 20),
                    label: Text("ซื้อเลย", style: GoogleFonts.manrope(textStyle: TextStyle(fontFamilyFallback: [GoogleFonts.notoSansThai().fontFamily ?? 'Noto Sans Thai']), fontSize: 16, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(backgroundColor: _kAccent, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  ),
                ),
              ),
            ]),
    );
  }

  void _openViewer(List<dynamic> urls, int idx) {
    Navigator.push(context, PageRouteBuilder(
      opaque: false,
      pageBuilder: (_, __, ___) => _ImageViewerPage(urls: urls, initialIndex: idx),
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
    ));
  }
}

// ━━━━━━━━━━━━━━━ IMAGE VIEWER ━━━━━━━━━━━━━━━
class _ImageViewerPage extends StatefulWidget {
  final List<dynamic> urls;
  final int initialIndex;
  const _ImageViewerPage({required this.urls, required this.initialIndex});
  @override
  State<_ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<_ImageViewerPage> {
  late final PageController _ctrl;
  late int _page;

  @override
  void initState() {
    super.initState();
    _ctrl = PageController(initialPage: widget.initialIndex);
    _page = widget.initialIndex;
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: Text('${_page + 1} / ${widget.urls.length}', style: GoogleFonts.manrope(textStyle: TextStyle(fontFamilyFallback: [GoogleFonts.notoSansThai().fontFamily ?? 'Noto Sans Thai']), color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: PageView.builder(
        controller: _ctrl, itemCount: widget.urls.length,
        onPageChanged: (i) => setState(() => _page = i),
        itemBuilder: (_, i) => InteractiveViewer(
          minScale: 0.5, maxScale: 4.0,
          child: Center(child: Image.network(widget.urls[i], fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, size: 64, color: Colors.grey))),
        ),
      ),
    );
  }
}
