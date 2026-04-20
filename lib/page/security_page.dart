import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_page.dart';

class SecurityPage extends StatefulWidget {
  const SecurityPage({super.key});

  @override
  State<SecurityPage> createState() => _SecurityPageState();
}

class _SecurityPageState extends State<SecurityPage> {
  bool _isLoading = true;
  String _userEmail = '';
  String _phoneNumber = '';

  @override
  void initState() {
    super.initState();
    _loadSecurityData();
  }

  // ดึงข้อมูลทั้งจาก Auth และ Database
  Future<void> _loadSecurityData() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user != null) {
        // 1. ดึง Email จาก Auth
        _userEmail = user.email ?? 'No email found';

        // 2. ดึง Phone Number จากตาราง profiles
        final data = await supabase
            .from('profiles')
            .select('phone_number')
            .eq('id', user.id)
            .single();

        if (mounted) {
          setState(() {
            _phoneNumber = data['phone_number'] ?? 'Not set';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ฟังก์ชันอัปเดตข้อมูล (Password หรือ Phone)
  Future<void> _updateSecurityInfo(String column, String newValue) async {
    if (newValue.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      if (column == 'password') {
        await supabase.auth.updateUser(UserAttributes(password: newValue));
      } else {
        await supabase.from('profiles').update({column: newValue}).eq('id', supabase.auth.currentUser!.id);
      }
      await _loadSecurityData();
      _showSuccess('Updated $column successfully!');
    } catch (e) {
      _showError('Update failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Dialog สำหรับแก้ไขข้อมูล
  Future<void> _showEditDialog({required String title, required String currentValue, required String column, bool isPassword = false}) async {
    final controller = TextEditingController(text: isPassword ? "" : currentValue);
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text("Change $title", style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          obscureText: isPassword,
          autofocus: true,
          decoration: InputDecoration(
            hintText: "Enter new $title",
            filled: true,
            fillColor: const Color(0xFFF1F3F4),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateSecurityInfo(column, controller.text.trim());
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4D58A5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text("Save", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ฟังก์ชันลบบัญชีถาวร
  Future<void> _deleteAccount() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text("ลบบัญชีผู้ใช้?", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
        content: const Text("ข้อมูลทั้งหมดจะถูกลบถาวร คุณแน่ใจหรือไม่?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("ยกเลิก", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text("ยืนยันการลบ", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await Supabase.instance.client.functions.invoke('delete-user', body: {'user_id': Supabase.instance.client.auth.currentUser!.id});
        await Supabase.instance.client.auth.signOut();
        if (mounted) {
          Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginPage()), (route) => false);
        }
      } catch (e) {
        _showError('Error: $e');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  void _showSuccess(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text("SECURITY & ACCOUNT", style: GoogleFonts.manrope(fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 16)),
        centerTitle: true, elevation: 0, backgroundColor: Colors.white,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Color(0xFF35408B)), onPressed: () => Navigator.pop(context)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF4D58A5)))
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                _buildSectionTitle("ACCOUNT IDENTITY"),
                _buildInfoTile("Registered Email", _userEmail, null), // Email แก้ไม่ได้
                _buildInfoTile("Phone Number", _phoneNumber, () {
                  _showEditDialog(title: "Phone Number", currentValue: _phoneNumber, column: 'phone_number');
                }),

                const SizedBox(height: 32),
                _buildSectionTitle("AUTHENTICATION"),
                _buildInfoTile("Account Password", "••••••••••••", () {
                  _showEditDialog(title: "Password", currentValue: "", column: 'password', isPassword: true);
                }),

                const SizedBox(height: 40),
                _buildSectionTitle("DANGER ZONE"),
                _buildDeleteTile(),
              ],
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(title, style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF4D58A5), letterSpacing: 1.5)),
    );
  }

  Widget _buildInfoTile(String label, String value, VoidCallback? onEdit) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.withValues(alpha: 0.1))),
      child: Row(
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ]),
          ),
          if (onEdit != null)
            TextButton(
              onPressed: onEdit,
              style: TextButton.styleFrom(backgroundColor: const Color(0xFFD1DDFA).withValues(alpha: 0.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text("Change", style: TextStyle(color: Color(0xFF35408B), fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  Widget _buildDeleteTile() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.red.withValues(alpha: 0.2))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Delete Account", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red)),
          const SizedBox(height: 8),
          const Text("Once deleted, your data cannot be recovered.", style: TextStyle(fontSize: 12, color: Colors.redAccent)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _deleteAccount,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 12)),
              child: const Text("DELETE ACCOUNT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }
}