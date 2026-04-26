import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main_screen.dart';

class SetupProfilePage extends StatefulWidget {
  final String phoneNumber; 
  
  const SetupProfilePage({super.key, required this.phoneNumber});

  @override
  State<SetupProfilePage> createState() => _SetupProfilePageState();
}

class _SetupProfilePageState extends State<SetupProfilePage> {
  final _usernameController = TextEditingController();
  XFile? _pickedFile;
  Uint8List? _imageBytes;
  bool _isLoading = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _pickedFile = pickedFile;
        _imageBytes = bytes;
      });
    }
  }

  Future<void> _saveProfile({required bool isSkip}) async {
    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) throw Exception('User not logged in');

      String finalUsername;
      String finalAvatarUrl;

      if (isSkip || (_usernameController.text.isEmpty && _imageBytes == null)) {
        int randomId = Random().nextInt(99999);
        finalUsername = 'VaultUser_$randomId';
        finalAvatarUrl = 'https://ui-avatars.com/api/?name=$finalUsername&background=4D58A5&color=fff&size=256';
      } else {
        finalUsername = _usernameController.text.isNotEmpty ? _usernameController.text.trim() : 'VaultUser_${Random().nextInt(99999)}';
        
        if (_pickedFile != null && _imageBytes != null) {
          final fileExtension = _pickedFile!.name.split('.').last;
          final fileName = '${user.id}_avatar.$fileExtension';
          
          await supabase.storage.from('avatars').uploadBinary(
            fileName, 
            _imageBytes!,
            fileOptions: FileOptions(contentType: 'image/$fileExtension', upsert: true),
          );
          finalAvatarUrl = supabase.storage.from('avatars').getPublicUrl(fileName);
        } else {
          finalAvatarUrl = 'https://ui-avatars.com/api/?name=$finalUsername&background=4D58A5&color=fff&size=256';
        }
      }

      await supabase.from('profiles').upsert({
        'id': user.id, 
        'username': finalUsername,
        'phone_number': widget.phoneNumber, 
        'avatar_url': finalAvatarUrl,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving profile: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              Text("Complete Profile", style: GoogleFonts.manrope(textStyle: TextStyle(fontFamilyFallback: [GoogleFonts.notoSansThai().fontFamily ?? 'Noto Sans Thai']), fontSize: 32, fontWeight: FontWeight.w800, color: const Color(0xFF191C1D))),
              const SizedBox(height: 8),
              const Text("Add a photo and username to start selling.", style: TextStyle(color: Color(0xFF586062), fontSize: 14)),
              const SizedBox(height: 40),

              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E9EC),
                    shape: BoxShape.circle,
                    image: _imageBytes != null ? DecorationImage(image: MemoryImage(_imageBytes!), fit: BoxFit.cover) : null,
                  ),
                  child: _imageBytes == null 
                      ? const Icon(Icons.add_a_photo, size: 40, color: Color(0xFF4D58A5))
                      : null,
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("USERNAME", style: GoogleFonts.manrope(textStyle: TextStyle(fontFamilyFallback: [GoogleFonts.notoSansThai().fontFamily ?? 'Noto Sans Thai']), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: const Color(0xFF767682))),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _usernameController,
                      style: GoogleFonts.manrope(textStyle: TextStyle(fontFamilyFallback: [GoogleFonts.notoSansThai().fontFamily ?? 'Noto Sans Thai']), fontWeight: FontWeight.w600, color: const Color(0xFF191C1D)),
                      decoration: InputDecoration(
                        hintText: "Enter your display name",
                        hintStyle: TextStyle(color: const Color(0xFF767682).withValues(alpha: 0.5), fontWeight: FontWeight.normal),
                        filled: true,
                        fillColor: const Color(0xFFF5F7FA),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              Container(
                width: double.infinity,
                decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF35408B), Color(0xFF4D58A5)]), borderRadius: BorderRadius.circular(24)),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : () => _saveProfile(isSkip: false),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, padding: const EdgeInsets.symmetric(vertical: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
                  child: _isLoading 
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text("SAVE & CONTINUE", style: GoogleFonts.manrope(textStyle: TextStyle(fontFamilyFallback: [GoogleFonts.notoSansThai().fontFamily ?? 'Noto Sans Thai']), fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 2, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: _isLoading ? null : () => _saveProfile(isSkip: true),
                child: const Text("Skip for now", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}