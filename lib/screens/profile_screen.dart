import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/supabase_client.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/custom_bottom_nav.dart';
import '../widgets/recipe_card.dart';
import 'admin/admin_dashboard_screen.dart';
import 'detail_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId;
  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  final _usernameController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _bioController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingImage = false;
  String? _avatarUrl;
  String _userRole = 'user';
  bool _isPremium = false;
  String? _currentUserId;
  bool _isOwnProfile = false;

  bool _isFollowing = false;
  bool _isFollowLoading = false;
  int _followerCount = 0;
  int _followingCount = 0;

  List<Map<String, dynamic>> _userRecipes = [];
  final Map<String, double> _recipeRatings = {};

  final ImagePicker _picker = ImagePicker();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _currentUserId = supabase.auth.currentUser?.id;
    _isOwnProfile = widget.userId == null || widget.userId == _currentUserId;

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeInOut);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic));

    _loadProfile();
    _loadUserRecipes();
    if (!_isOwnProfile) _checkIfFollowing();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _fullNameController.dispose();
    _bioController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final targetUserId = widget.userId ?? _currentUserId;
      if (targetUserId == null) return;

      final response = await supabase
          .from('profiles')
          .select('username, full_name, bio, avatar_url, role, is_premium, total_followers, total_following')
          .eq('id', targetUserId)
          .single();

      if (!mounted) return;

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

      _animationController.forward();
    } catch (e) {
      if (mounted) {
        _showSnackBar('Gagal memuat profil: $e', isError: true);
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadUserRecipes() async {
    try {
      final targetUserId = widget.userId ?? _currentUserId;
      if (targetUserId == null) return;

      final response = await supabase
          .from('recipes')
          .select('''
            *, 
            profiles!recipes_user_id_fkey(username, avatar_url, role),
            categories(id, name),
            recipe_tags(tags(id, name))
          ''')
          .eq('user_id', targetUserId)
          .eq('status', 'approved')
          .order('created_at', ascending: false);

      if (!mounted) return;

      final recipes = List<Map<String, dynamic>>.from(response);

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

  Future<void> _toggleFollow() async {
    if (_currentUserId == null || _isOwnProfile) return;
    setState(() => _isFollowLoading = true);
    try {
      if (_isFollowing) {
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
      await _loadProfile();
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isFollowLoading = false);
    }
  }

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

      await supabase.storage.from('profiles').uploadBinary(filePath, bytes);
      final publicUrl = supabase.storage.from('profiles').getPublicUrl(filePath);

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
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (context) => _buildFollowListSheet('Pengikut', List<Map<String, dynamic>>.from(response), true),
      );
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error: $e', isError: true);
      }
    }
  }

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
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (context) => _buildFollowListSheet('Mengikuti', List<Map<String, dynamic>>.from(response), false),
      );
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error: $e', isError: true);
      }
    }
  }

  Widget _buildFollowListSheet(String title, List<Map<String, dynamic>> users, bool isFollowers) {
    if (users.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 40),
              Icon(Icons.people_outline, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                isFollowers ? 'Belum ada pengikut' : 'Belum mengikuti siapa pun',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF264653),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                final profile = user['profiles'];
                final userId = isFollowers ? user['follower_id'] : user['following_id'];
                final isBanned = profile['is_banned'] == true;
                final bannedReason = profile['banned_reason'] ?? 'Tidak disebutkan';

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isBanned ? Colors.red.shade50 : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isBanned
                          ? Colors.red.shade200
                          : const Color(0xFFE76F51).withValues(alpha: 0.2),
                      width: 1.5,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: isBanned
                            ? LinearGradient(colors: [Colors.red.shade300, Colors.red.shade400])
                            : const LinearGradient(
                                colors: [Color(0xFFE76F51), Color(0xFFF4A261)],
                              ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: CircleAvatar(
                          backgroundColor: Colors.white,
                          backgroundImage: profile['avatar_url'] != null && !isBanned
                              ? NetworkImage(profile['avatar_url'])
                              : null,
                          child: profile['avatar_url'] == null || isBanned
                              ? Icon(
                                  isBanned ? Icons.block : Icons.person,
                                  color: isBanned ? Colors.red.shade700 : Colors.grey.shade400,
                                )
                              : null,
                        ),
                      ),
                    ),
                    title: Text(
                      profile['username'] ?? 'Unknown',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isBanned ? Colors.red.shade700 : const Color(0xFF264653),
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (profile['full_name'] != null)
                          Text(
                            profile['full_name'],
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        if (isBanned)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Dibanned: $bannedReason',
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    trailing: isBanned
                        ? null
                        : Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 16,
                            color: const Color(0xFFE76F51),
                          ),
                    onTap: isBanned
                        ? null
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
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, {required bool isError}) {
    if (!mounted) return;
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
          ? _buildLoadingState()
          : FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    _buildProfileHeader(),
                    _buildProfileContent(),
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

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE76F51), Color(0xFFF4A261)],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE76F51).withValues(alpha: 0.4),
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
    );
  }

  Widget _buildProfileHeader() {
    return SliverToBoxAdapter(
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF264653),
              Color(0xFF2A9D8F),
              Color(0xFFE9C46A),
              Color(0xFFF4A261),
              Color(0xFFE76F51),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE76F51).withValues(alpha: 0.3),
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
                // Avatar
                Stack(
                  children: [
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: _getRoleGradient(_userRole),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(55),
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
                              gradient: const LinearGradient(
                                colors: [Color(0xFFE76F51), Color(0xFFF4A261)],
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    if (_userRole == 'admin')
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.verified_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Username & Name
                Text(
                  _usernameController.text.isEmpty ? 'Unknown' : _usernameController.text,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                if (_fullNameController.text.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    _fullNameController.text,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
                const SizedBox(height: 12),

                // Role Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _getRoleGradient(_userRole)
                          .map((c) => c.withValues(alpha: 0.3))
                          .toList(),
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _userRole == 'admin'
                            ? Icons.admin_panel_settings_rounded
                            : _isPremium
                                ? Icons.workspace_premium_rounded
                                : Icons.person_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _getRoleLabel(_userRole),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),

                // Bio
                if (_bioController.text.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      _bioController.text,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),

                // Stats
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatItem(
                      'Resep',
                      _userRecipes.length.toString(),
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                    GestureDetector(
                      onTap: _showFollowersList,
                      child: _buildStatItem(
                        'Pengikut',
                        _followerCount.toString(),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                    GestureDetector(
                      onTap: _showFollowingList,
                      child: _buildStatItem(
                        'Mengikuti',
                        _followingCount.toString(),
                      ),
                    ),
                  ],
                ),

                // Action Button
                if (!_isOwnProfile) ...[
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: _isFollowing
                          ? null
                          : const LinearGradient(
                              colors: [Color(0xFFE76F51), Color(0xFFF4A261)],
                            ),
                      color: _isFollowing ? Colors.white.withValues(alpha: 0.2) : null,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                      boxShadow: _isFollowing
                          ? null
                          : [
                              BoxShadow(
                                color: const Color(0xFFE76F51).withValues(alpha: 0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _isFollowLoading ? null : _toggleFollow,
                        borderRadius: BorderRadius.circular(16),
                        child: Center(
                          child: _isFollowLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _isFollowing ? Icons.person_remove_rounded : Icons.person_add_rounded,
                                      color: Colors.white,
                                      size: 20,
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
    );
  }

  Widget _buildProfileContent() {
    return SliverPadding(
      padding: const EdgeInsets.all(20),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          // Admin Dashboard Button
          if (_isOwnProfile && _userRole == 'admin') ...[
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
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
                          child: const Icon(
                            Icons.dashboard_customize_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Dashboard Admin',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Kelola sistem dan pengguna',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Edit Profile Form
          if (_isOwnProfile) ...[
            Row(
              children: [
                Container(
                  width: 4,
                  height: 24,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE76F51), Color(0xFFF4A261)],
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
                    color: Color(0xFF264653),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFE76F51).withValues(alpha: 0.2),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE76F51).withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildModernTextField(
                    controller: _usernameController,
                    label: 'Username',
                    icon: Icons.alternate_email_rounded,
                    iconColor: const Color(0xFFE76F51),
                  ),
                  const SizedBox(height: 16),
                  _buildModernTextField(
                    controller: _fullNameController,
                    label: 'Nama Lengkap',
                    icon: Icons.person_outline_rounded,
                    iconColor: const Color(0xFF2A9D8F),
                  ),
                  const SizedBox(height: 16),
                  _buildModernTextField(
                    controller: _bioController,
                    label: 'Bio',
                    icon: Icons.edit_note_rounded,
                    iconColor: const Color(0xFFF4A261),
                    maxLines: 4,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE76F51), Color(0xFFF4A261)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE76F51).withValues(alpha: 0.4),
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

          // Recipes Section Header
          Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE76F51), Color(0xFFF4A261)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _isOwnProfile ? 'Resep Saya' : 'Resep',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF264653),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFE76F51).withValues(alpha: 0.1),
                      const Color(0xFFF4A261).withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFE76F51).withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  '${_userRecipes.length}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFFE76F51),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Recipes List or Empty State
          if (_userRecipes.isEmpty)
            Container(
              padding: const EdgeInsets.all(48),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.grey.shade100,
                    Colors.grey.shade50,
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.restaurant_menu_rounded,
                      size: 64,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isOwnProfile ? 'Belum ada resep' : 'Pengguna ini belum memiliki resep',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isOwnProfile
                          ? 'Mulai berbagi resep favorit Anda!'
                          : 'Tunggu hingga mereka membagikan kreasi kuliner',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade400,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            ..._userRecipes.map((recipe) {
              return RecipeCard(
                recipe: recipe,
                rating: _recipeRatings[recipe['id']],
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DetailScreen(
                        recipeId: recipe['id'].toString(),
                      ),
                    ),
                  ).then((_) {
                    if (mounted) _loadUserRecipes();
                  });
                },
              );
            }),
          const SizedBox(height: 100),
        ]),
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _getRoleGradient(_userRole),
        ),
      ),
      child: const Icon(Icons.person_rounded, size: 50, color: Colors.white),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.white.withValues(alpha: 0.9),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color iconColor,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            iconColor.withValues(alpha: 0.05),
            iconColor.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: iconColor.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: TextStyle(
          fontSize: 15,
          color: Colors.grey.shade800,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Padding(
            padding: EdgeInsets.only(top: maxLines > 1 ? 12 : 0),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: iconColor, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          alignLabelWithHint: maxLines > 1,
        ),
      ),
    );
  }

  List<Color> _getRoleGradient(String role) {
    switch (role) {
      case 'admin':
        return [const Color(0xFFFFD700), const Color(0xFFFFA500)];
      case 'premium':
        return [const Color(0xFF6C63FF), const Color(0xFF9F8FFF)];
      default:
        return [Colors.grey.shade400, Colors.grey.shade500];
    }
  }

  String _getRoleLabel(String role) {
    switch (role) {
      case 'admin':
        return '👑 ADMIN';
      case 'premium':
        return '⭐ PREMIUM';
      default:
        return '👤 USER';
    }
  }
}