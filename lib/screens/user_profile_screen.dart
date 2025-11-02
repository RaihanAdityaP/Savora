import 'package:flutter/material.dart';
import '../utils/supabase_client.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/custom_bottom_nav.dart';
import '../widgets/recipe_card.dart';
import 'detail_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;

  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  Map<String, dynamic>? _userProfile;
  List<Map<String, dynamic>> _userRecipes = [];
  bool _isLoading = true;
  bool _isFollowing = false;
  bool _isFollowLoading = false;
  String? _currentUserAvatarUrl;
  String? _currentUserId;
  int _followerCount = 0;
  int _followingCount = 0;
  final Map<String, double> _recipeRatings = {};

  @override
  void initState() {
    super.initState();
    _currentUserId = supabase.auth.currentUser?.id;
    _loadUserProfile();
    _loadUserRecipes();
    _loadCurrentUserAvatar();
    _checkIfFollowing();
  }

  Future<void> _loadCurrentUserAvatar() async {
    try {
      if (_currentUserId != null) {
        final response = await supabase
            .from('profiles')
            .select('avatar_url')
            .eq('id', _currentUserId!)
            .single();
        if (mounted) {
          setState(() => _currentUserAvatarUrl = response['avatar_url']);
        }
      }
    } catch (e) {
      debugPrint('Error loading current user avatar: $e');
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      final response = await supabase
          .from('profiles')
          .select('username, full_name, bio, avatar_url, role, is_premium, total_followers, total_following')
          .eq('id', widget.userId)
          .single();

      if (mounted) {
        setState(() {
          _userProfile = response;
          _followerCount = response['total_followers'] ?? 0;
          _followingCount = response['total_following'] ?? 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat profil: $e')),
        );
      }
    }
  }

  Future<void> _loadUserRecipes() async {
    try {
      final response = await supabase
          .from('recipes')
          .select('''
            *, 
            profiles!recipes_user_id_fkey(username, avatar_url),
            categories(id, name)
          ''')
          .eq('user_id', widget.userId)
          .eq('status', 'approved')
          .order('created_at', ascending: false);

      if (mounted) {
        final recipes = List<Map<String, dynamic>>.from(response);

        // Load ratings for each recipe
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

        setState(() => _userRecipes = recipes);
      }
    } catch (e) {
      debugPrint('Error loading user recipes: $e');
    }
  }

  Future<void> _checkIfFollowing() async {
    if (_currentUserId == null || _currentUserId == widget.userId) return;

    try {
      final response = await supabase
          .from('follows')
          .select()
          .eq('follower_id', _currentUserId!)
          .eq('following_id', widget.userId)
          .maybeSingle();

      if (mounted) {
        setState(() => _isFollowing = response != null);
      }
    } catch (e) {
      debugPrint('Error checking follow status: $e');
    }
  }

  Future<void> _toggleFollow() async {
    if (_currentUserId == null || _currentUserId == widget.userId) return;

    setState(() => _isFollowLoading = true);

    try {
      if (_isFollowing) {
        // Unfollow
        await supabase
            .from('follows')
            .delete()
            .eq('follower_id', _currentUserId!)
            .eq('following_id', widget.userId);

        if (mounted) {
          setState(() => _isFollowing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Berhenti mengikuti')),
          );
        }
      } else {
        // Follow
        await supabase.from('follows').insert({
          'follower_id': _currentUserId,
          'following_id': widget.userId,
        });

        if (mounted) {
          setState(() => _isFollowing = true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Berhasil mengikuti'), backgroundColor: Colors.green),
          );
        }
      }
      
      // Wait a bit for database trigger to complete
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Reload profile to get updated counters from database
      await _loadUserProfile();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isFollowLoading = false);
    }
  }

  Future<void> _showFollowersList() async {
    try {
      final response = await supabase
          .from('follows')
          .select('follower_id, profiles!follows_follower_id_fkey(username, avatar_url, full_name, is_banned, banned_reason)')
          .eq('following_id', widget.userId);

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => _buildFollowListSheet(
          'Pengikut',
          List<Map<String, dynamic>>.from(response),
          true,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _showFollowingList() async {
    try {
      final response = await supabase
          .from('follows')
          .select('following_id, profiles!follows_following_id_fkey(username, avatar_url, full_name, is_banned, banned_reason)')
          .eq('follower_id', widget.userId);

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => _buildFollowListSheet(
          'Mengikuti',
          List<Map<String, dynamic>>.from(response),
          false,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showBannedDialog(String username, String reason) {
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.block, color: Colors.red.shade700),
            const SizedBox(width: 8),
            const Text('Akun Dinonaktifkan'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Akun $username telah dinonaktifkan oleh administrator.',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text('Alasan:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text(
                reason,
                style: TextStyle(color: Colors.red.shade700),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

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
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF5C4033),
            ),
          ),
          const SizedBox(height: 16),
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
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isBanned ? Colors.red.shade50 : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: isBanned ? Border.all(color: Colors.red.shade200) : null,
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isBanned ? Colors.red.shade200 : null,
                      backgroundImage: profile['avatar_url'] != null && !isBanned
                          ? NetworkImage(profile['avatar_url'])
                          : null,
                      child: profile['avatar_url'] == null || isBanned
                          ? Icon(
                              isBanned ? Icons.block : Icons.person,
                              color: isBanned ? Colors.red.shade700 : null,
                            )
                          : null,
                    ),
                    title: Row(
                      children: [
                        Flexible(
                          child: Text(
                            profile['username'] ?? 'Unknown',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isBanned ? Colors.red.shade700 : Colors.black,
                              decoration: isBanned ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ),
                        if (isBanned) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.shade700,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'BANNED',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    subtitle: profile['full_name'] != null
                        ? Text(
                            profile['full_name'],
                            style: TextStyle(
                              color: isBanned ? Colors.red.shade600 : Colors.grey.shade700,
                            ),
                          )
                        : null,
                    trailing: isBanned
                        ? IconButton(
                            icon: Icon(Icons.info_outline, color: Colors.red.shade700),
                            onPressed: () {
                              Navigator.pop(context);
                              _showBannedDialog(
                                profile['username'] ?? 'User',
                                bannedReason,
                              );
                            },
                          )
                        : null,
                    onTap: isBanned
                        ? () {
                            Navigator.pop(context);
                            _showBannedDialog(
                              profile['username'] ?? 'User',
                              bannedReason,
                            );
                          }
                        : () {
                            Navigator.pop(context);
                            if (userId != _currentUserId) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => UserProfileScreen(userId: userId),
                                ),
                              ).then((_) {
                                if (mounted) {
                                  _loadUserProfile();
                                }
                              });
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

  @override
  Widget build(BuildContext context) {
    final isOwnProfile = _currentUserId == widget.userId;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F4F0),
      appBar: const CustomAppBar(showBackButton: true),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // Profile Header
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
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey.shade200,
                            image: _userProfile?['avatar_url'] != null
                                ? DecorationImage(
                                    image: NetworkImage(_userProfile!['avatar_url']),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                            border: Border.all(
                              color: _userProfile?['role'] == 'admin'
                                  ? const Color(0xFFD4AF37)
                                  : _userProfile?['is_premium'] == true
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
                          child: _userProfile?['avatar_url'] == null
                              ? Icon(
                                  Icons.person,
                                  size: 60,
                                  color: Colors.grey.shade500,
                                )
                              : null,
                        ),
                        const SizedBox(height: 16),

                        // Username
                        Text(
                          _userProfile?['username'] ?? 'Unknown',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        if (_userProfile?['full_name'] != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            _userProfile!['full_name'],
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),

                        // Role Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _userProfile?['role'] == 'admin'
                                ? const Color(0xFFD4AF37)
                                : _userProfile?['is_premium'] == true
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
                                _userProfile?['role'] == 'admin'
                                    ? Icons.admin_panel_settings
                                    : _userProfile?['is_premium'] == true
                                        ? Icons.workspace_premium
                                        : Icons.person,
                                size: 18,
                                color: _userProfile?['role'] == 'admin'
                                    ? Colors.white
                                    : _userProfile?['is_premium'] == true
                                        ? const Color(0xFFE5BFA5)
                                        : Colors.white,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _userProfile?['role'] == 'admin'
                                    ? 'ADMIN'
                                    : _userProfile?['is_premium'] == true
                                        ? 'SAVORA CHEF'
                                        : 'PENGGUNA',
                                style: TextStyle(
                                  color: _userProfile?['role'] == 'admin'
                                      ? Colors.white
                                      : _userProfile?['is_premium'] == true
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
                        const SizedBox(height: 20),

                        // Stats Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildStatItem(
                              _userRecipes.length.toString(),
                              'Resep',
                              Icons.restaurant,
                            ),
                            GestureDetector(
                              onTap: _showFollowersList,
                              child: _buildStatItem(
                                _followerCount.toString(),
                                'Pengikut',
                                Icons.people,
                              ),
                            ),
                            GestureDetector(
                              onTap: _showFollowingList,
                              child: _buildStatItem(
                                _followingCount.toString(),
                                'Mengikuti',
                                Icons.person_add,
                              ),
                            ),
                          ],
                        ),
                        
                        // Follow Button (only if not own profile)
                        if (!isOwnProfile) ...[
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: _isFollowLoading ? null : _toggleFollow,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isFollowing
                                    ? Colors.grey.shade300
                                    : Colors.white,
                                foregroundColor: _isFollowing
                                    ? const Color(0xFF5C4033)
                                    : const Color(0xFFE5BFA5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                              ),
                              icon: _isFollowLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : Icon(
                                      _isFollowing ? Icons.person_remove : Icons.person_add,
                                    ),
                              label: Text(
                                _isFollowing ? 'Berhenti Mengikuti' : 'Ikuti',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Bio Section
                if (_userProfile?['bio'] != null && _userProfile!['bio'].toString().isNotEmpty)
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.all(24),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
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
                              color: Color(0xFF5C4033),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _userProfile!['bio'],
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Recipes Section Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                    child: Text(
                      'Resep (${_userRecipes.length})',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF5C4033),
                      ),
                    ),
                  ),
                ),

                // Recipes Grid
                _userRecipes.isEmpty
                    ? SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.restaurant_menu,
                                size: 60,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Belum ada resep',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        sliver: SliverGrid(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.65,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final recipe = _userRecipes[index];
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
                                    if (mounted) {
                                      _loadUserRecipes();
                                    }
                                  });
                                },
                              );
                            },
                            childCount: _userRecipes.length,
                          ),
                        ),
                      ),

                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: 0,
        avatarUrl: _currentUserAvatarUrl,
      ),
    );
  }

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
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
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
          ),
        ),
      ],
    );
  }
}