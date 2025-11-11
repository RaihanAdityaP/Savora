import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/supabase_client.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/custom_bottom_nav.dart';
import '../widgets/recipe_card.dart';
import 'admin/admin_dashboard_screen.dart';
import 'detail_screen.dart';

/// Layar profil yang unified — bisa menampilkan profil sendiri atau orang lain
/// - Jika userId == null atau sama dengan user saat ini → profil sendiri (bisa edit)
/// - Jika userId berbeda → profil orang lain (hanya bisa lihat + tombol ikuti)
class ProfileScreen extends StatefulWidget {
  final String? userId;
  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  // ===== KONTROLER TEKS =====
  // Digunakan untuk mengelola input teks di form profil
  final _usernameController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _bioController = TextEditingController();

  // ===== STATE APLIKASI =====
  bool _isLoading = true;           // Menandakan apakah data sedang dimuat
  bool _isSaving = false;           // Menandakan apakah sedang menyimpan profil
  bool _isUploadingImage = false;   // Menandakan apakah sedang mengunggah foto
  String? _avatarUrl;               // URL foto profil
  String _userRole = 'user';        // Peran pengguna: 'user', 'admin', dll.
  bool _isPremium = false;          // Status premium
  String? _currentUserId;           // ID pengguna yang sedang login
  bool _isOwnProfile = false;       // Apakah ini profil sendiri?

  // ===== SISTEM IKUTI (FOLLOW) =====
  bool _isFollowing = false;        // Apakah pengguna saat ini mengikuti target?
  bool _isFollowLoading = false;    // Loading saat toggle ikuti/berhenti
  int _followerCount = 0;           // Jumlah pengikut
  int _followingCount = 0;          // Jumlah yang diikuti

  // ===== RESEP PENGGUNA =====
  List<Map<String, dynamic>> _userRecipes = [];         // Daftar resep milik pengguna
  final Map<String, double> _recipeRatings = {};        // Penilaian rata-rata per resep

  // ===== PICKER GAMBAR & ANIMASI =====
  final ImagePicker _picker = ImagePicker();            // Untuk memilih gambar dari galeri
  late AnimationController _animationController;        // Kontroler animasi loading
  late Animation<double> _fadeAnimation;                // Animasi fade-in
  late Animation<Offset> _slideAnimation;               // Animasi slide-up

  @override
  void initState() {
    super.initState();
    // Ambil ID pengguna yang sedang login
    _currentUserId = supabase.auth.currentUser?.id;
    // Tentukan apakah ini profil sendiri
    _isOwnProfile = widget.userId == null || widget.userId == _currentUserId;

    // Inisialisasi animasi
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeInOut);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic));

    // Muat data profil dan resep
    _loadProfile();
    _loadUserRecipes();
    // Jika bukan profil sendiri, cek status mengikuti
    if (!_isOwnProfile) _checkIfFollowing();
  }

  @override
  void dispose() {
    // Bersihkan resource saat widget dihancurkan
    _usernameController.dispose();
    _fullNameController.dispose();
    _bioController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // ===== MEMUAT DATA PROFIL =====
  Future<void> _loadProfile() async {
    try {
      final targetUserId = widget.userId ?? _currentUserId;
      if (targetUserId == null) return;

      // Ambil data profil dari Supabase
      final response = await supabase
          .from('profiles')
          .select('username, full_name, bio, avatar_url, role, is_premium, total_followers, total_following')
          .eq('id', targetUserId)
          .single();

      if (!mounted) return;

      // Perbarui state dengan data yang diterima
      setState(() {
        _usernameController.text = response['username'] ?? '';
        _fullNameController.text = response['full_name'] ?? '';
        _bioController.text = response['bio'] ?? '';
        _avatarUrl = response['avatar_url'];
        _userRole = response['role'] ?? 'user';
        _isPremium = response['is_premium'] ?? false;
        _followerCount = response['total_followers'] ?? 0;
        _followingCount = response['total_following'] ?? 0;
        _isLoading = false;
      });

      // Jalankan animasi setelah data dimuat
      _animationController.forward();
    } catch (e) {
      if (mounted) {
        _showSnackBar('Gagal memuat profil: $e', isError: true);
        setState(() => _isLoading = false);
      }
    }
  }

  // ===== MEMUAT RESEP PENGGUNA =====
  Future<void> _loadUserRecipes() async {
    try {
      final targetUserId = widget.userId ?? _currentUserId;
      if (targetUserId == null) return;

      // Ambil daftar resep yang disetujui
      final response = await supabase
          .from('recipes')
          .select('''
            *, 
            profiles!recipes_user_id_fkey(username, avatar_url),
            categories(id, name)
          ''')
          .eq('user_id', targetUserId)
          .eq('status', 'approved')
          .order('created_at', ascending: false);

      if (!mounted) return;

      final recipes = List<Map<String, dynamic>>.from(response);

      // Hitung rating rata-rata untuk setiap resep
      for (var recipe in recipes) {
        final ratingResponse = await supabase
            .from('recipe_ratings')
            .select('rating')
            .eq('recipe_id', recipe['id']);
        if (ratingResponse.isNotEmpty) {
          final total = ratingResponse.fold(0, (sum, r) => sum + (r['rating'] as int));
          _recipeRatings[recipe['id']] = total / ratingResponse.length;
        }
      }

      if (mounted) {
        setState(() => _userRecipes = recipes);
      }
    } catch (e) {
      debugPrint('Error loading user recipes: $e');
    }
  }

  // ===== CEK APAKAH SUDAH MENGIKUTI =====
  Future<void> _checkIfFollowing() async {
    if (_currentUserId == null || _isOwnProfile) return;
    try {
      final response = await supabase
          .from('follows')
          .select()
          .eq('follower_id', _currentUserId!)
          .eq('following_id', widget.userId!)
          .maybeSingle();
      if (mounted) {
        setState(() => _isFollowing = response != null);
      }
    } catch (e) {
      debugPrint('Error checking follow status: $e');
    }
  }

  // ===== GANTI STATUS IKUTI / TIDAK IKUTI =====
  Future<void> _toggleFollow() async {
    if (_currentUserId == null || _isOwnProfile) return;
    setState(() => _isFollowLoading = true);
    try {
      if (_isFollowing) {
        // Hapus relasi mengikuti
        await supabase
            .from('follows')
            .delete()
            .eq('follower_id', _currentUserId!)
            .eq('following_id', widget.userId!);
        if (mounted) {
          setState(() => _isFollowing = false);
          _showSnackBar('Berhenti mengikuti', isError: false);
        }
      } else {
        // Tambahkan relasi mengikuti
        await supabase.from('follows').insert({
          'follower_id': _currentUserId,
          'following_id': widget.userId,
        });
        if (mounted) {
          setState(() => _isFollowing = true);
          _showSnackBar('Berhasil mengikuti', isError: false);
        }
      }
      await Future.delayed(const Duration(milliseconds: 300));
      await _loadProfile(); // Perbarui jumlah pengikut
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isFollowLoading = false);
    }
  }

  // ===== PILIH DAN UNGGAH FOTO PROFIL =====
  Future<void> _pickAndUploadImage() async {
    if (!_isOwnProfile) return;
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

      // Unggah ke Supabase Storage
      await supabase.storage.from('profiles').uploadBinary(filePath, bytes);
      final publicUrl = supabase.storage.from('profiles').getPublicUrl(filePath);

      // Simpan URL ke database
      await supabase.from('profiles').update({'avatar_url': publicUrl}).eq('id', userId);
      if (mounted) {
        setState(() {
          _avatarUrl = publicUrl;
          _isUploadingImage = false;
        });
        _showSnackBar('Foto profil berhasil diperbarui!', isError: false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingImage = false);
        _showSnackBar('Gagal mengunggah foto: $e', isError: true);
      }
    }
  }

  // ===== SIMPAN PERUBAHAN PROFIL =====
  Future<void> _saveProfile() async {
    if (!_isOwnProfile) return;
    if (_usernameController.text.isEmpty) {
      _showSnackBar('Username tidak boleh kosong', isError: true);
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
        _showSnackBar('Profil berhasil diperbarui!', isError: false);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Gagal menyimpan: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ===== TAMPILKAN DAFTAR PENGIKUT =====
  Future<void> _showFollowersList() async {
    try {
      final targetUserId = widget.userId ?? _currentUserId;
      final response = await supabase
          .from('follows')
          .select('follower_id, profiles!follows_follower_id_fkey(username, avatar_url, full_name, is_banned, banned_reason)')
          .eq('following_id', targetUserId!);

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => _buildFollowListSheet('Pengikut', List<Map<String, dynamic>>.from(response), true),
      );
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error: $e', isError: true);
      }
    }
  }

  // ===== TAMPILKAN DAFTAR YANG DIIKUTI =====
  Future<void> _showFollowingList() async {
    try {
      final targetUserId = widget.userId ?? _currentUserId;
      final response = await supabase
          .from('follows')
          .select('following_id, profiles!follows_following_id_fkey(username, avatar_url, full_name, is_banned, banned_reason)')
          .eq('follower_id', targetUserId!);

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => _buildFollowListSheet('Mengikuti', List<Map<String, dynamic>>.from(response), false),
      );
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error: $e', isError: true);
      }
    }
  }

  // ===== MEMBANGUN TAMPILAN DAFTAR FOLLOW (PENGIKUT / MENGUTI) =====
  Widget _buildFollowListSheet(String title, List<Map<String, dynamic>> users, bool isFollowers) {
    if (users.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Text(
            isFollowers ? 'Belum ada pengikut' : 'Belum mengikuti siapa pun',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle kecil di atas bottom sheet
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          // Judul sheet
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF5C4033),
            ),
          ),
          const SizedBox(height: 16),
          // Daftar pengguna
          Expanded(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                final profile = user['profiles'];
                final userId = isFollowers ? user['follower_id'] : user['following_id'];
                final isBanned = profile['is_banned'] == true;
                // ✅ VARIABEL INI SEKARANG DIGUNAKAN!
                final bannedReason = profile['banned_reason'] ?? 'Tidak disebutkan';

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isBanned ? Colors.red.shade200 : Colors.grey.shade300,
                    backgroundImage: profile['avatar_url'] != null && !isBanned
                        ? NetworkImage(profile['avatar_url'])
                        : null,
                    child: profile['avatar_url'] == null || isBanned
                        ? Icon(
                            isBanned ? Icons.block : Icons.person,
                            color: isBanned ? Colors.red.shade700 : Colors.grey.shade600,
                          )
                        : null,
                  ),
                  title: Text(
                    profile['username'] ?? 'Unknown',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isBanned ? Colors.red.shade700 : Colors.black,
                    ),
                  ),
                  // ✅ TAMPILKAN bannedReason JIKA DIBANNED
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (profile['full_name'] != null) Text(profile['full_name']),
                      if (isBanned)
                        Text(
                          'Dibanned: $bannedReason',
                          style: const TextStyle(color: Colors.red, fontSize: 12),
                        ),
                    ],
                  ),
                  onTap: isBanned
                      ? null // Tidak bisa diklik jika dibanned
                      : () {
                          Navigator.pop(context);
                          if (userId != _currentUserId) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ProfileScreen(userId: userId),
                              ),
                            );
                          }
                        },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ===== TAMPILKAN SNACKBAR =====
  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: CustomAppBar(showBackButton: !_isOwnProfile),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.orange.shade400, Colors.deepOrange.shade600],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withValues(alpha: 0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeWidth: 3,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Memuat profil...',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          : FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // ===== HEADER PROFIL =====
                    SliverToBoxAdapter(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: _userRole == 'admin'
                                ? [Color(0xFFFFD700), Color(0xFFFFB300), Color(0xFFFF8F00)]
                                : [Colors.orange.shade400, Colors.deepOrange.shade500, Colors.red.shade400],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.withValues(alpha: 0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: SafeArea(
                          bottom: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
                            child: Column(
                              children: [
                                // Avatar dengan ikon kamera (jika profil sendiri)
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Container(
                                      width: 130,
                                      height: 130,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.white.withValues(alpha: 0.6),
                                            blurRadius: 30,
                                            spreadRadius: 10,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      width: 130,
                                      height: 130,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 4),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.2),
                                            blurRadius: 15,
                                            offset: const Offset(0, 5),
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(65),
                                        child: _avatarUrl != null
                                            ? Image.network(
                                                _avatarUrl!,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, _, _) => _buildDefaultAvatar(),
                                              )
                                            : _buildDefaultAvatar(),
                                      ),
                                    ),
                                    if (_isUploadingImage)
                                      Positioned.fill(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.black.withValues(alpha: 0.6),
                                          ),
                                          child: const Center(
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 3,
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (_isOwnProfile)
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: GestureDetector(
                                          onTap: _isUploadingImage ? null : _pickAndUploadImage,
                                          child: Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [Colors.blue.shade400, Colors.blue.shade600],
                                              ),
                                              shape: BoxShape.circle,
                                              border: Border.all(color: Colors.white, width: 3),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.blue.withValues(alpha: 0.4),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            child: const Icon(
                                              Icons.camera_alt,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                // Username
                                Text(
                                  _usernameController.text.isEmpty ? 'Unknown' : _usernameController.text,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                // Nama lengkap (jika ada)
                                if (_fullNameController.text.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    _fullNameController.text,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.white.withValues(alpha: 0.9),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                // Badge peran (Admin / Premium / User)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.25),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.5),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.1),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
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
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _userRole == 'admin'
                                            ? 'ADMIN'
                                            : _isPremium
                                                ? 'SAVORA CHEF'
                                                : 'PENGGUNA',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),
                                // Statistik: Resep, Pengikut, Mengikuti
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _buildStatItem(_userRecipes.length.toString(), 'Resep', Icons.restaurant),
                                    GestureDetector(
                                      onTap: _showFollowersList,
                                      child: _buildStatItem(_followerCount.toString(), 'Pengikut', Icons.people),
                                    ),
                                    GestureDetector(
                                      onTap: _showFollowingList,
                                      child: _buildStatItem(_followingCount.toString(), 'Mengikuti', Icons.person_add),
                                    ),
                                  ],
                                ),
                                // Tombol ikuti (hanya untuk profil orang lain)
                                if (!_isOwnProfile) ...[
                                  const SizedBox(height: 20),
                                  Container(
                                    width: double.infinity,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      gradient: _isFollowing
                                          ? null
                                          : LinearGradient(
                                              colors: [Colors.blue.shade400, Colors.blue.shade600],
                                            ),
                                      color: _isFollowing ? Colors.white.withValues(alpha: 0.3) : null,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.1),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: _isFollowLoading ? null : _toggleFollow,
                                        borderRadius: BorderRadius.circular(12),
                                        child: Center(
                                          child: _isFollowLoading
                                              ? const SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Colors.white,
                                                  ),
                                                )
                                              : Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      _isFollowing ? Icons.person_remove : Icons.person_add,
                                                      color: Colors.white,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      _isFollowing ? 'Berhenti Mengikuti' : 'Ikuti',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 16,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // ===== ISI UTAMA (Bio, Form, Resep) =====
                    SliverPadding(
                      padding: const EdgeInsets.all(20),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          // Tombol Dashboard Admin (hanya untuk admin & profil sendiri)
                          if (_isOwnProfile && _userRole == 'admin') ...[
                            _buildGradientCard(
                              gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFB300)]),
                              icon: Icons.dashboard_customize,
                              title: 'Dashboard Admin',
                              subtitle: 'Kelola sistem dan pengguna',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const AdminDashboardScreen(),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 20),
                          ],
                          // Bagian Bio
                          if (_bioController.text.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.06),
                                    blurRadius: 15,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Bio',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2D3748),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _bioController.text,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade700,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                          // Form edit profil (hanya untuk profil sendiri)
                          if (_isOwnProfile) ...[
                            Row(
                              children: [
                                Container(
                                  width: 4,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Colors.orange.shade400, Colors.deepOrange.shade600],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Informasi Akun',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2D3748),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 20,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  children: [
                                    _buildModernTextField(
                                      controller: _usernameController,
                                      label: 'Username',
                                      icon: Icons.alternate_email,
                                      iconColor: Colors.blue,
                                    ),
                                    const SizedBox(height: 16),
                                    _buildModernTextField(
                                      controller: _fullNameController,
                                      label: 'Nama Lengkap',
                                      icon: Icons.person_outline,
                                      iconColor: Colors.green,
                                    ),
                                    const SizedBox(height: 16),
                                    _buildModernTextField(
                                      controller: _bioController,
                                      label: 'Bio',
                                      icon: Icons.edit_note,
                                      iconColor: Colors.purple,
                                      maxLines: 4,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            // Tombol Simpan
                            Container(
                              height: 56,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.orange.shade400, Colors.deepOrange.shade600],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.orange.withValues(alpha: 0.4),
                                    blurRadius: 15,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _isSaving ? null : _saveProfile,
                                  borderRadius: BorderRadius.circular(16),
                                  child: Center(
                                    child: _isSaving
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2.5,
                                            ),
                                          )
                                        : const Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.save_rounded, color: Colors.white),
                                              SizedBox(width: 12),
                                              Text(
                                                'Simpan Perubahan',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                          // Header Resep
                          Row(
                            children: [
                              Container(
                                width: 4,
                                height: 24,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.orange.shade400, Colors.deepOrange.shade600],
                                  ),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Resep (${_userRecipes.length})',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2D3748),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Tampilkan resep atau pesan kosong
                          _userRecipes.isEmpty
                              ? Container(
                                  padding: const EdgeInsets.all(48),
                                  child: Center(
                                    child: Column(
                                      children: [
                                        Icon(Icons.restaurant_menu, size: 60, color: Colors.grey.shade300),
                                        const SizedBox(height: 16),
                                        Text(
                                          'Belum ada resep',
                                          style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    childAspectRatio: 0.65,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                  ),
                                  itemCount: _userRecipes.length,
                                  itemBuilder: (context, index) {
                                    final recipe = _userRecipes[index];
                                    return RecipeCard(
                                      recipe: recipe,
                                      rating: _recipeRatings[recipe['id']],
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => DetailScreen(recipeId: recipe['id'].toString()),
                                          ),
                                        ).then((_) {
                                          if (mounted) _loadUserRecipes();
                                        });
                                      },
                                    );
                                  },
                                ),
                          const SizedBox(height: 100),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: _isOwnProfile ? 4 : 0,
        avatarUrl: _avatarUrl,
        onRefresh: _loadProfile,
      ),
    );
  }

  // ===== AVATAR DEFAULT JIKA TIDAK ADA FOTO =====
  Widget _buildDefaultAvatar() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.blue.shade300, Colors.purple.shade400]),
      ),
      child: const Icon(Icons.person, size: 60, color: Colors.white),
    );
  }

  // ===== KOMPONEN STATISTIK (Resep, Pengikut, Mengikuti) =====
  Widget _buildStatItem(String value, String label, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.9))),
      ],
    );
  }

  // ===== KARTU GRADIEN (misal: Dashboard Admin) =====
  Widget _buildGradientCard({
    required Gradient gradient,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===== FIELD INPUT MODERN =====
  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color iconColor,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200, width: 1.5),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: TextStyle(fontSize: 15, color: Colors.grey.shade800, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500),
          prefixIcon: Padding(
            padding: EdgeInsets.only(top: maxLines > 1 ? 12 : 0),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: iconColor, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          alignLabelWithHint: maxLines > 1,
        ),
      ),
    );
  }
}