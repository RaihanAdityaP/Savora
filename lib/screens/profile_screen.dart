import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/supabase_client.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/custom_bottom_nav.dart';
import 'admin/admin_dashboard_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _usernameController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _bioController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingImage = false;
  String? _avatarUrl;
  String _userRole = 'user';
  bool _isPremium = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _fullNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await supabase
          .from('profiles')
          .select('username, full_name, bio, avatar_url, role, is_premium')
          .eq('id', userId)
          .single();

      if (!mounted) return;

      setState(() {
        _usernameController.text = response['username'] ?? '';
        _fullNameController.text = response['full_name'] ?? '';
        _bioController.text = response['bio'] ?? '';
        _avatarUrl = response['avatar_url'];
        _userRole = response['role'] ?? 'user';
        _isPremium = response['is_premium'] ?? false;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat profil: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );

      if (image == null) return;

      setState(() => _isUploadingImage = true);

      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final bytes = await image.readAsBytes();
      final fileExt = image.path.split('.').last;
      final fileName = '$userId-${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = 'avatars/$fileName';

      await supabase.storage.from('profiles').uploadBinary(
            filePath,
            bytes,
          );

      final publicUrl = supabase.storage.from('profiles').getPublicUrl(filePath);

      await supabase.from('profiles').update({
        'avatar_url': publicUrl,
      }).eq('id', userId);

      if (mounted) {
        setState(() {
          _avatarUrl = publicUrl;
          _isUploadingImage = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto profil berhasil diperbarui!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingImage = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengunggah foto: $e')),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (_usernameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Username tidak boleh kosong')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      await supabase.from('profiles').upsert({
        'id': userId,
        'username': _usernameController.text.trim(),
        'full_name': _fullNameController.text.trim(),
        'bio': _bioController.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil berhasil diperbarui!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F4F0),
      appBar: const CustomAppBar(showBackButton: false),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // Header Section with Avatar
                SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFE5BFA5),
                          const Color(0xFFE5BFA5).withValues(alpha: 0.8),
                        ],
                      ),
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(30),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE5BFA5).withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Avatar
                        Stack(
                          children: [
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.grey.shade200,
                                image: _avatarUrl != null
                                    ? DecorationImage(
                                        image: NetworkImage(_avatarUrl!),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                                border: Border.all(
                                  color: _userRole == 'admin'
                                      ? const Color(0xFFD4AF37)
                                      : _isPremium
                                          ? Colors.white
                                          : Colors.white.withValues(alpha: 0.5),
                                  width: 4,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: _avatarUrl == null
                                  ? Icon(
                                      Icons.person,
                                      size: 60,
                                      color: Colors.grey.shade500,
                                    )
                                  : null,
                            ),
                            if (_isUploadingImage)
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.black.withValues(alpha: 0.5),
                                  ),
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: _isUploadingImage ? null : _pickAndUploadImage,
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFFE5BFA5),
                                      width: 3,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.2),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt,
                                    size: 20,
                                    color: Color(0xFFE5BFA5),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Role Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _userRole == 'admin'
                                ? const Color(0xFFD4AF37)
                                : _isPremium
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _userRole == 'admin'
                                    ? Icons.admin_panel_settings
                                    : _isPremium
                                        ? Icons.workspace_premium
                                        : Icons.person,
                                size: 18,
                                color: _userRole == 'admin'
                                    ? Colors.white
                                    : _isPremium
                                        ? const Color(0xFFE5BFA5)
                                        : Colors.white,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _userRole == 'admin'
                                    ? 'ADMIN'
                                    : _isPremium
                                        ? 'SAVORA CHEF'
                                        : 'PENGGUNA',
                                style: TextStyle(
                                  color: _userRole == 'admin'
                                      ? Colors.white
                                      : _isPremium
                                          ? const Color(0xFFE5BFA5)
                                          : Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Content Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Admin Dashboard Button
                        if (_userRole == 'admin')
                          Container(
                            margin: const EdgeInsets.only(bottom: 24),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFD4AF37), Color(0xFFF4E5C3)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const AdminDashboardScreen(),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.3),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Icon(
                                          Icons.dashboard,
                                          color: Colors.white,
                                          size: 28,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Dashboard Admin',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Kelola pengguna, resep, dan aktivitas',
                                              style: TextStyle(
                                                color: Colors.white.withValues(alpha: 0.9),
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(
                                        Icons.arrow_forward_ios,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                        // Section Title
                        const Text(
                          'Informasi Akun',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF5C4033),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Username Field
                        TextField(
                          controller: _usernameController,
                          decoration: InputDecoration(
                            labelText: 'Username',
                            labelStyle: const TextStyle(color: Color(0xFF5C4033)),
                            prefixIcon: const Icon(Icons.alternate_email, color: Color(0xFF5C4033)),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE5BFA5), width: 2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Full Name Field
                        TextField(
                          controller: _fullNameController,
                          decoration: InputDecoration(
                            labelText: 'Nama Lengkap',
                            labelStyle: const TextStyle(color: Color(0xFF5C4033)),
                            prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF5C4033)),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE5BFA5), width: 2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Bio Field
                        TextField(
                          controller: _bioController,
                          maxLines: 4,
                          decoration: InputDecoration(
                            labelText: 'Bio',
                            labelStyle: const TextStyle(color: Color(0xFF5C4033)),
                            prefixIcon: const Padding(
                              padding: EdgeInsets.only(bottom: 60),
                              child: Icon(Icons.description_outlined, color: Color(0xFF5C4033)),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE5BFA5), width: 2),
                            ),
                            alignLabelWithHint: true,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Save Button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _saveProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE5BFA5),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey.shade300,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 4,
                              shadowColor: const Color(0xFFE5BFA5).withValues(alpha: 0.4),
                            ),
                            child: _isSaving
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Simpan Perubahan',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: 4,
        avatarUrl: _avatarUrl,
        onRefresh: _loadProfile,
      ),
    );
  }
}