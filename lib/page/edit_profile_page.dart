import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart'; 
import 'package:supabase_flutter/supabase_flutter.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  String _username = '';
  String _avatarUrl = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentData();
  }

  Future<void> _loadCurrentData() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user != null) {
        // ลบการดึง phone_number และ email ออกไปแล้ว
        final data = await supabase.from('profiles').select('username, avatar_url').eq('id', user.id).single();
        setState(() {
          _username = data['username'] ?? '';
          _avatarUrl = data['avatar_url'] ?? '';
        });
      }
    } catch (e) {
      debugPrint("Error loading: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _changeAvatar() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() => _isLoading = true);
      try {
        final supabase = Supabase.instance.client;
        final user = supabase.auth.currentUser;
        if (user == null) return;

        final bytes = await pickedFile.readAsBytes();
        final fileExtension = pickedFile.name.split('.').last;
        final fileName = '${user.id}_avatar.$fileExtension';

        await supabase.storage.from('avatars').uploadBinary(
              fileName, bytes, fileOptions: FileOptions(contentType: 'image/$fileExtension', upsert: true));

        // เพิ่ม ?v=เวลาปัจจุบัน เพื่อป้องกันแอปจำรูปเก่า (Cache Buster)
        final publicUrl = supabase.storage.from('avatars').getPublicUrl(fileName);
        final newAvatarUrl = "$publicUrl?v=${DateTime.now().millisecondsSinceEpoch}";
        
        await supabase.from('profiles').update({'avatar_url': newAvatarUrl}).eq('id', user.id);

        await _loadCurrentData();
        _showSuccess('Avatar updated successfully!');
      } catch (e) {
        _showError('Error uploading: $e');
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showEditDialog({required String title, required String currentValue, required Function(String) onSave}) async {
    final controller = TextEditingController(text: currentValue);
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text("Change $title", style: GoogleFonts.manrope(textStyle: TextStyle(fontFamilyFallback: [GoogleFonts.notoSansThai().fontFamily ?? 'Noto Sans Thai']), fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.text,
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
              onSave(controller.text.trim());
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4D58A5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text("Save", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _updateData(String column, String newValue) async {
    if (newValue.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      await supabase.from('profiles').update({column: newValue}).eq('id', user!.id);
      await _loadCurrentData();
      _showSuccess('Updated $column successfully!');
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  void _showSuccess(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text("EDIT PROFILE", style: GoogleFonts.manrope(textStyle: TextStyle(fontFamilyFallback: [GoogleFonts.notoSansThai().fontFamily ?? 'Noto Sans Thai']), fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 16)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF35408B)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF4D58A5)))
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 120, height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle, color: const Color(0xFFE2E9EC),
                          image: _avatarUrl.isNotEmpty ? DecorationImage(image: NetworkImage(_avatarUrl), fit: BoxFit.cover) : null,
                          boxShadow: [BoxShadow(color: const Color(0xFF4D58A5).withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 10))],
                        ),
                        child: _avatarUrl.isEmpty ? const Icon(Icons.person, size: 50, color: Color(0xFF4D58A5)) : null,
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: _changeAvatar,
                        icon: const Icon(Icons.photo_camera, size: 16, color: Color(0xFF35408B)),
                        label: const Text("Change Photo", style: TextStyle(color: Color(0xFF35408B), fontWeight: FontWeight.bold)),
                        style: TextButton.styleFrom(backgroundColor: const Color(0xFFD1DDFA).withValues(alpha: 0.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                _buildSectionTitle("PERSONAL INFO"),
                _buildInfoTile("Display Name", _username, () {
                  _showEditDialog(title: "Username", currentValue: _username, onSave: (val) => _updateData('username', val));
                }),
                // ลบส่วน Phone Number ออกเรียบร้อยแล้ว
              ],
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(title, style: GoogleFonts.manrope(textStyle: TextStyle(fontFamilyFallback: [GoogleFonts.notoSansThai().fontFamily ?? 'Noto Sans Thai']), fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF4D58A5), letterSpacing: 1.5)),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF191C1D))),
              ],
            ),
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
}