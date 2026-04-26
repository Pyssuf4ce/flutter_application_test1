import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main_screen.dart';
import 'setup_profile_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();
  
  bool _isLoading = false;
  bool _isLoginMode = true; 

  Future<void> _authenticate() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;
    final phone = _phoneController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showError('กรุณากรอกอีเมลและรหัสผ่านนะคุณ Kong');
      return;
    }

    if (!_isLoginMode) {
      if (password != confirmPassword) {
        _showError('รหัสผ่านไม่ตรงกันครับ ลองเช็กอีกทีนะ');
        return;
      }
      if (phone.isEmpty) {
        _showError('อย่าลืมใส่เบอร์โทรศัพท์ด้วยนะครับ');
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;

      if (_isLoginMode) {
        // --- 💡 ส่วนที่แก้ไข: ระบบ Login พร้อมเช็ก "บัญชีผี" ---
        final authResponse = await supabase.auth.signInWithPassword(email: email, password: password);
        
        if (authResponse.user != null) {
          // เช็กว่ามีข้อมูลในตาราง profiles หรือยัง
          final profileCheck = await supabase
              .from('profiles')
              .select('id')
              .eq('id', authResponse.user!.id)
              .maybeSingle();

          if (mounted) {
            if (profileCheck == null) {
              // 🚨 ถ้ายังไม่มี Profile บังคับให้ไปหน้า Setup ทันที
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const SetupProfilePage(phoneNumber: '')),
              );
            } else {
              // ✅ ถ้ามี Profile แล้ว เข้าหน้าหลักได้เลย
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const MainScreen()),
              );
            }
          }
        }
      } else {
        // Sign Up
        await supabase.auth.signUp(email: email, password: password);
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => SetupProfilePage(phoneNumber: phone),
            ),
          );
        }
      }
    } on AuthException catch (e) {
      String errorMessage = e.message;
      
      if (errorMessage.toLowerCase().contains('already registered') || 
          errorMessage.toLowerCase().contains('already exists')) {
        errorMessage = 'อีเมลนี้ถูกใช้งานแล้ว โปรดใช้เมลอื่นหรือเข้าสู่ระบบนะ';
      } else if (errorMessage.toLowerCase().contains('invalid login credentials')) {
        errorMessage = 'อีเมลหรือรหัสผ่านไม่ถูกต้องครับ';
      }
      
      _showError(errorMessage);
    } catch (e) {
      _showError('เกิดข้อผิดพลาด: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating),
      );
    }
  }

  void _toggleMode() {
    setState(() {
      _isLoginMode = !_isLoginMode;
      _emailController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();
      _phoneController.clear();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              Text("VAULT", style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Noto Sans Thai'], fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: 6, color: const Color(0xFF4D58A5))),
              const SizedBox(height: 48),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(opacity: animation, child: SlideTransition(position: Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(animation), child: child));
                },
                child: Text(
                  _isLoginMode ? "ยินดีต้อนรับ" : "สร้างบัญชีใหม่",
                  key: ValueKey<bool>(_isLoginMode),
                  style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Noto Sans Thai'], fontSize: 32, fontWeight: FontWeight.w800, color: const Color(0xFF191C1D), height: 1.1),
                ),
              ),
              const SizedBox(height: 12),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: Text(
                  _isLoginMode 
                      ? "กรุณาเข้าสู่ระบบเพื่อเข้าใช้งานคลังของคุณ"
                      : "ลงทะเบียนเพื่อเริ่มต้นการซื้อขายใน VAULT",
                  key: ValueKey<bool>(_isLoginMode),
                  style: const TextStyle(color: Color(0xFF586062), fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 40),
              
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF4D58A5).withValues(alpha: 0.06), blurRadius: 40, offset: const Offset(0, 20))
                  ],
                ),
                child: Column(
                  children: [
                    _buildInputField("อีเมล", "example@mail.com", false, _emailController),
                    const SizedBox(height: 20),
                    _buildInputField("รหัสผ่าน", "••••••••••••", true, _passwordController),
                    
                    AnimatedSize(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.fastOutSlowIn,
                      child: _isLoginMode ? const SizedBox(width: double.infinity) : Column(
                        children: [
                          const SizedBox(height: 20),
                          _buildInputField("ยืนยันรหัสผ่าน", "••••••••••••", true, _confirmPasswordController),
                          const SizedBox(height: 20),
                          _buildInputField("เบอร์โทรศัพท์", "เช่น 0812345678", false, _phoneController, isNumber: true),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),
              
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF35408B), Color(0xFF4D58A5)]),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _authenticate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            _isLoginMode ? "เข้าสู่ระบบ" : "สมัครสมาชิก",
                            key: ValueKey<bool>(_isLoginMode),
                            style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Noto Sans Thai'], fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 2, color: Colors.white),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 32),
              TextButton(
                onPressed: _toggleMode,
                child: Text(
                  _isLoginMode ? "ยังไม่มีบัญชี? สมัครสมาชิกที่นี่" : "มีบัญชีอยู่แล้ว? เข้าสู่ระบบ",
                  style: const TextStyle(color: Color(0xFF4D58A5), fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField(String label, String hint, bool isPassword, TextEditingController controller, {bool isNumber = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Noto Sans Thai'], fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: const Color(0xFF767682))),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: isPassword,
          autofocus: label == "อีเมล", // บังคับเปิดแป้นพิมพ์ที่ช่องอีเมล
          keyboardType: isPassword ? TextInputType.text : (isNumber ? TextInputType.phone : TextInputType.emailAddress),
          style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Noto Sans Thai'], fontWeight: FontWeight.w600, color: Color(0xFF191C1D)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: const Color(0xFF767682).withValues(alpha: 0.5), fontWeight: FontWeight.normal),
            filled: true,
            fillColor: const Color(0xFFF5F7FA),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }
}