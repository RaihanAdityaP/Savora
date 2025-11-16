import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../utils/supabase_client.dart';
import '../widgets/custom_bottom_nav.dart';
import 'home_screen.dart';
import 'edit_recipe_screen.dart';
import 'profile_screen.dart';
import 'searching_screen.dart';

class DetailScreen extends StatefulWidget {
  final String recipeId;
  const DetailScreen({super.key, required this.recipeId});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  Map<String, dynamic>? _recipe;
  bool _isLoading = true;
  bool _isFavorite = false;
  int? _userRating;
  double? _averageRating;
  int? _ratingCount;
  List<Map<String, dynamic>> _comments = [];
  List<String> _tags = [];
  final TextEditingController _commentController = TextEditingController();
  String? _userAvatarUrl;
  String? _currentUserId;
  String? _currentUserRole;

  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isVideoInitializing = false;

  @override
  void initState() {
    super.initState();
    _currentUserId = supabase.auth.currentUser?.id;
    _initializeScreen();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _chewieController?.dispose();
    _videoPlayerController?.dispose();
    super.dispose();
  }

  Future<void> _initializeScreen() async {
    await Future.wait([
      _loadRecipe(),
      _incrementViews(),
      _checkIfFavorite(),
      _loadUserRating(),
      _loadComments(),
      _loadCurrentUserProfile(),
      _loadRecipeTags(),
    ]);
  }

  Future<void> _initializeVideoPlayer(String videoUrl) async {
    if (_isVideoInitializing) return;
    setState(() => _isVideoInitializing = true);

    try {
      _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      await _videoPlayerController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: false,
        looping: false,
        aspectRatio: _videoPlayerController!.value.aspectRatio,
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
                const SizedBox(height: 16),
                Text(
                  'Gagal memuat video',
                  style: TextStyle(color: Colors.red.shade600),
                ),
              ],
            ),
          );
        },
      );

      if (mounted) {
        setState(() => _isVideoInitializing = false);
      }
    } catch (e) {
      debugPrint('Error initializing video: $e');
      if (mounted) {
        setState(() => _isVideoInitializing = false);
      }
    }
  }

  Future<void> _loadCurrentUserProfile() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId != null) {
        final response = await supabase
            .from('profiles')
            .select('avatar_url, role')
            .eq('id', userId)
            .single();
        if (!mounted) return;
        setState(() {
          _userAvatarUrl = response['avatar_url'];
          _currentUserRole = response['role'];
        });
      }
    } catch (e) {
      debugPrint('Error loading user profile: $e');
    }
  }

  Future<void> _loadRecipe() async {
    try {
      Map<String, dynamic>? response = await supabase
          .from('recipes')
          .select('*, profiles!recipes_user_id_fkey(username, avatar_url, role, is_premium)')
          .eq('id', widget.recipeId)
          .maybeSingle();
      if (response == null) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _recipe = null;
        });
        return;
      }

      final ratingResponse = await supabase
          .from('recipe_ratings')
          .select('rating')
          .eq('recipe_id', widget.recipeId);
      if (!mounted) return;
      setState(() {
        _recipe = response;
        _ratingCount = ratingResponse.length;
        if (_ratingCount! > 0) {
          final total = ratingResponse.fold(0, (sum, r) => sum + (r['rating'] as int));
          _averageRating = total / _ratingCount!;
        }
        _isLoading = false;
      });

      // Initialize video if exists
      if (_recipe!['video_url'] != null) {
        _initializeVideoPlayer(_recipe!['video_url']);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _recipe = null;
      });
      _showSnackBar('Error loading recipe');
    }
  }

  Future<void> _incrementViews() async {
    try {
      final current = await supabase
          .from('recipes')
          .select('views_count')
          .eq('id', widget.recipeId)
          .single();
      await supabase
          .from('recipes')
          .update({'views_count': (current['views_count'] ?? 0) + 1})
          .eq('id', widget.recipeId);
    } catch (e) {
      debugPrint('Error incrementing views: $e');
    }
  }

  Future<void> _checkIfFavorite() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId != null) {
        final response = await supabase
            .from('favorites')
            .select()
            .eq('user_id', userId)
            .eq('recipe_id', widget.recipeId)
            .maybeSingle();
        if (!mounted) return;
        setState(() => _isFavorite = response != null);
      }
    } catch (e) {
      debugPrint('Error checking favorite: $e');
    }
  }

  Future<void> _loadUserRating() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId != null) {
        final response = await supabase
            .from('recipe_ratings')
            .select('rating')
            .eq('user_id', userId)
            .eq('recipe_id', widget.recipeId)
            .maybeSingle();
        if (!mounted) return;
        setState(() => _userRating = response?['rating'] as int?);
      }
    } catch (e) {
      debugPrint('Error loading user rating: $e');
    }
  }

  Future<void> _loadRecipeTags() async {
    try {
      final response = await supabase
          .from('recipe_tags')
          .select('tags(name)')
          .eq('recipe_id', widget.recipeId);
      if (!mounted) return;
      final tags = List<Map<String, dynamic>>.from(response);
      setState(() {
        _tags = tags.map((t) => t['tags']['name'] as String).toList();
      });
    } catch (e) {
      debugPrint('Error loading tags: $e');
    }
  }

  Future<void> _toggleFavorite() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        _showSnackBar('Silakan login terlebih dahulu');
        return;
      }
      if (_isFavorite) {
        await supabase
            .from('favorites')
            .delete()
            .eq('user_id', userId)
            .eq('recipe_id', widget.recipeId);
      } else {
        await supabase.from('favorites').insert({
          'user_id': userId,
          'recipe_id': widget.recipeId,
        });
      }
      if (!mounted) return;
      setState(() => _isFavorite = !_isFavorite);
      _showSnackBar(_isFavorite ? 'Ditambahkan ke favorit!' : 'Dihapus dari favorit');
    } catch (e) {
      _showSnackBar('Error saat menyimpan favorit');
    }
  }

  Future<void> _submitRating(int rating) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        _showSnackBar('Silakan login untuk memberi rating');
        return;
      }
      final existingRating = await supabase
          .from('recipe_ratings')
          .select()
          .eq('user_id', userId)
          .eq('recipe_id', widget.recipeId)
          .maybeSingle();
      if (existingRating != null) {
        await supabase
            .from('recipe_ratings')
            .update({'rating': rating})
            .eq('user_id', userId)
            .eq('recipe_id', widget.recipeId);
      } else {
        await supabase.from('recipe_ratings').insert({
          'recipe_id': widget.recipeId,
          'user_id': userId,
          'rating': rating,
        });
      }
      if (!mounted) return;
      setState(() => _userRating = rating);
      await _loadRecipe();
      _showSnackBar(existingRating != null ? 'Rating diperbarui!' : 'Rating dikirim!');
    } catch (e) {
      _showSnackBar('Gagal mengirim rating');
    }
  }

  Future<void> _loadComments() async {
    try {
      final response = await supabase
          .from('comments')
          .select('*, profiles!comments_user_id_fkey(username, avatar_url)')
          .eq('recipe_id', widget.recipeId)
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(() => _comments = List<Map<String, dynamic>>.from(response));
    } catch (e) {
      debugPrint('Error loading comments: $e');
    }
  }

  Future<void> _postComment() async {
    if (_commentController.text.trim().isEmpty) {
      _showSnackBar('Komentar tidak boleh kosong');
      return;
    }
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        _showSnackBar('Silakan login untuk berkomentar');
        return;
      }
      await supabase.from('comments').insert({
        'recipe_id': widget.recipeId,
        'user_id': userId,
        'content': _commentController.text.trim(),
      });
      _commentController.clear();
      await _loadComments();
      if (!mounted) return;
      _showSnackBar('Komentar berhasil dikirim!');
    } catch (e) {
      _showSnackBar('Error: $e');
    }
  }

  Future<void> _editComment(String commentId, String newContent) async {
    if (newContent.trim().isEmpty) return;
    try {
      await supabase
          .from('comments')
          .update({
            'content': newContent.trim(),
            'updated_at': DateTime.now().toIso8601String()
          })
          .eq('id', commentId);
      await _loadComments();
      if (!mounted) return;
      _showSnackBar('Komentar berhasil diperbarui!');
    } catch (e) {
      _showSnackBar('Error: $e');
    }
  }

  Future<void> _deleteComment(String commentId) async {
    final confirm = await showDialog<bool?>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hapus Komentar'),
        content: const Text('Apakah Anda yakin ingin menghapus komentar ini?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await supabase.from('comments').delete().eq('id', commentId);
        await _loadComments();
        if (!mounted) return;
        _showSnackBar('Komentar berhasil dihapus!');
      } catch (e) {
        _showSnackBar('Error: $e');
      }
    }
  }

  Future<void> _deleteRecipe() async {
    final confirm = await showDialog<bool?>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hapus Resep'),
        content: const Text('Apakah Anda yakin ingin menghapus resep ini? Tindakan ini tidak dapat dibatalkan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await supabase.from('comments').delete().eq('recipe_id', widget.recipeId);
        await supabase.from('recipe_ratings').delete().eq('recipe_id', widget.recipeId);
        await supabase.from('favorites').delete().eq('recipe_id', widget.recipeId);
        await supabase.from('recipe_tags').delete().eq('recipe_id', widget.recipeId);
        await supabase.from('recipes').delete().eq('id', widget.recipeId);
        if (!mounted) return;
        _showSnackBar('Resep berhasil dihapus!');
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      } catch (e) {
        _showSnackBar('Error: $e');
      }
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = _currentUserId == _recipe?['user_id'].toString();
    final isCurrentUserAdmin = _currentUserRole == 'admin';
    final canEdit = isOwner || isCurrentUserAdmin;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _recipe == null
              ? const Center(child: Text('Resep tidak ditemukan'))
              : CustomScrollView(
                  slivers: [
                    // Modern AppBar with Gradient
                    SliverAppBar(
                      expandedHeight: 180,
                      floating: false,
                      pinned: true,
                      backgroundColor: Colors.transparent,
                      flexibleSpace: FlexibleSpaceBar(
                        background: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                const Color(0xFF2B6CB0),
                                const Color(0xFF3182CE),
                                Colors.blue.shade400,
                                Colors.orange.shade400,
                                const Color(0xFFFF6B35),
                              ],
                            ),
                          ),
                          child: SafeArea(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(24, 60, 24, 20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.25),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(
                                            color: Colors.white.withValues(alpha: 0.5),
                                            width: 2,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.restaurant_rounded,
                                          color: Colors.white,
                                          size: 32,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      const Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Detail Resep',
                                              style: TextStyle(
                                                fontSize: 28,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                            SizedBox(height: 4),
                                            Text(
                                              'Informasi lengkap resep',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.white70,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      leading: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF2B6CB0)),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                      ),
                      actions: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: IconButton(
                              icon: Icon(
                                _isFavorite ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                                color: _isFavorite ? const Color(0xFFFF6B35) : const Color(0xFF2B6CB0),
                              ),
                              onPressed: _toggleFavorite,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Content
                    SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _buildHeroCard(canEdit),
                          const SizedBox(height: 16),
                          _buildContentCard(),
                          const SizedBox(height: 16),
                          _buildInteractionCard(),
                          const SizedBox(height: 100),
                        ]),
                      ),
                    ),
                  ],
                ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: 0,
        avatarUrl: _userAvatarUrl,
        onRefresh: _loadRecipe,
      ),
    );
  }

  Widget _buildCompactInfoChip(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard(bool canEdit) {
    final profile = _recipe!['profiles'];
    final username = profile?['username'] ?? 'Anonymous';
    final avatarUrl = profile?['avatar_url'];
    final role = profile?['role'] ?? 'user';
    final isPremium = profile?['is_premium'] ?? false;
    final userId = _recipe!['user_id'];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.blue.shade100,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.15),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero Image with Gradient Overlay
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            child: Stack(
              children: [
                _recipe!['image_url'] != null
                    ? Image.network(
                        _recipe!['image_url'],
                        width: double.infinity,
                        height: 280,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _buildPlaceholderImage(),
                      )
                    : _buildPlaceholderImage(),
                
                // Gradient Overlay
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 140,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.4),
                          Colors.black.withValues(alpha: 0.8),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Title on Image
                Positioned(
                  bottom: 20,
                  left: 20,
                  right: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _recipe!['title'] ?? 'Untitled',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.2,
                          shadows: [
                            Shadow(
                              color: Colors.black54,
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildCompactInfoChip(
                            '${_recipe!['cooking_time'] ?? 15} min',
                            Icons.access_time_rounded,
                          ),
                          const SizedBox(width: 8),
                          _buildCompactInfoChip(
                            '${_recipe!['servings'] ?? 1} porsi',
                            Icons.restaurant_menu_rounded,
                          ),
                          const SizedBox(width: 8),
                          _buildCompactInfoChip(
                            (_recipe!['difficulty'] ?? 'mudah').toUpperCase(),
                            Icons.bar_chart_rounded,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Content Section
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Description
                if (_recipe!['description'] != null && _recipe!['description'].toString().isNotEmpty) ...[
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue.shade400,
                              Colors.blue.shade600,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.description_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Deskripsi',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D3748),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _recipe!['description'],
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Divider(color: Colors.grey.shade200),
                  const SizedBox(height: 20),
                ],
                
                // User Info
                GestureDetector(
                  onTap: userId != null
                      ? () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProfileScreen(userId: userId.toString()),
                            ),
                          )
                      : null,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.blue.shade50,
                          Colors.orange.shade50,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.blue.shade100, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: role == 'admin'
                                  ? [const Color(0xFFD4AF37), const Color(0xFFFFD700)]
                                  : isPremium
                                      ? [const Color(0xFF6C63FF), const Color(0xFF9F8FFF)]
                                      : [Colors.grey.shade300, Colors.grey.shade400],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: avatarUrl != null
                                ? Image.network(avatarUrl, fit: BoxFit.cover)
                                : const Icon(Icons.person, color: Colors.white, size: 28),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                username,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2D3748),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: role == 'admin'
                                      ? const Color(0xFFFFD700)
                                      : isPremium
                                          ? const Color(0xFF6C63FF)
                                          : Colors.grey.shade400,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  role == 'admin'
                                      ? 'ADMIN'
                                      : isPremium
                                          ? 'SAVORA CHEF'
                                          : 'PENGGUNA',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (userId != null)
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.7),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.chevron_right_rounded,
                              color: Colors.grey.shade700,
                              size: 20,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Info Grid
                Row(
                  children: [
                    Expanded(child: _buildInfoDetailCard(
                      '${_recipe!['cooking_time'] ?? 15}',
                      'Menit',
                      Icons.access_time_rounded,
                      Colors.blue.shade600,
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _buildInfoDetailCard(
                      '${_recipe!['servings'] ?? 1}',
                      'Porsi',
                      Icons.restaurant_menu_rounded,
                      const Color(0xFF2B6CB0),
                    )),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildInfoDetailCard(
                      (_recipe!['difficulty'] ?? 'mudah').toUpperCase(),
                      'Tingkat',
                      Icons.bar_chart_rounded,
                      Colors.orange.shade600,
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _buildInfoDetailCard(
                      _recipe!['calories'] != null ? '${_recipe!['calories']}' : 'N/A',
                      'Kalori',
                      Icons.local_fire_department_rounded,
                      const Color(0xFFFF6B35),
                    )),
                  ],
                ),

                const SizedBox(height: 24),
                _buildActionButtons(canEdit),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoDetailCard(String value, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.1),
            color.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Column(
        children: [
          Icon(icon, size: 28, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      width: double.infinity,
      height: 280,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF2B6CB0),
            Colors.blue.shade400,
            Colors.orange.shade400,
            const Color(0xFFFF6B35),
          ],
        ),
      ),
      child: const Icon(Icons.restaurant_rounded, size: 80, color: Colors.white),
    );
  }

  Widget _buildActionButtons(bool canEdit) {
    return Row(
      children: [
        if (canEdit) ...[
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => EditRecipeScreen(recipe: _recipe!)),
                ).then((_) => _loadRecipe());
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2B6CB0),
                side: BorderSide(color: const Color(0xFF2B6CB0).withValues(alpha: 0.3), width: 2),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.edit_rounded, size: 18),
              label: const Text('Edit', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _deleteRecipe,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade500,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.delete_rounded, size: 18),
              label: const Text('Hapus', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ] else ...[
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isFavorite 
                      ? [Colors.amber.shade400, Colors.amber.shade600]
                      : [const Color(0xFF2B6CB0), Colors.blue.shade400],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ElevatedButton.icon(
                onPressed: _toggleFavorite,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: Icon(
                  _isFavorite ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  size: 20,
                ),
                label: Text(
                  _isFavorite ? 'Tersimpan' : 'Simpan',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildContentCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.blue.shade100,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Video Section
          if (_recipe!['video_url'] != null) ...[
            _buildSectionHeader('Video Tutorial', Icons.videocam_rounded),
            const SizedBox(height: 16),
            _buildVideoPlayer(),
            const SizedBox(height: 28),
            const Divider(height: 1),
            const SizedBox(height: 28),
          ] else ...[
            _buildSectionHeader('Video Tutorial', Icons.videocam_rounded),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.grey.shade100,
                    Colors.grey.shade50,
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.videocam_off_rounded, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text(
                      'User tidak mengunggah video',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            const Divider(height: 1),
            const SizedBox(height: 28),
          ],

          // Ingredients
          _buildSectionHeader('Bahan-bahan', Icons.restaurant_menu_rounded),
          const SizedBox(height: 16),
          _buildIngredientsList(),
          
          const SizedBox(height: 28),
          const Divider(height: 1),
          const SizedBox(height: 28),

          // Steps
          _buildSectionHeader('Langkah-langkah', Icons.format_list_numbered_rounded),
          const SizedBox(height: 16),
          _buildStepsList(),

          const SizedBox(height: 28),
          const Divider(height: 1),
          const SizedBox(height: 28),

          // Tags
          _buildSectionHeader('Tags', Icons.label_rounded),
          const SizedBox(height: 16),
          _buildTagsList(),
        ],
      ),
    );
  }

  Widget _buildVideoPlayer() {
    if (_isVideoInitializing) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    if (_chewieController != null && _videoPlayerController != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: _videoPlayerController!.value.aspectRatio,
          child: Chewie(controller: _chewieController!),
        ),
      );
    }

    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
            const SizedBox(height: 12),
            Text(
              'Gagal memuat video',
              style: TextStyle(color: Colors.red.shade400),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF2B6CB0),
                Colors.blue.shade400,
                Colors.orange.shade400,
              ],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D3748),
          ),
        ),
      ],
    );
  }

  Widget _buildIngredientsList() {
    final ingredients = _recipe!['ingredients'] as List<dynamic>?;
    if (ingredients == null || ingredients.isEmpty) {
      return _buildEmptyState('Belum ada bahan');
    }
    return Column(
      children: ingredients.asMap().entries.map((entry) {
        final index = entry.key;
        final ingredient = entry.value;
        String name;
        String? quantity;

        if (ingredient is String) {
          name = ingredient;
        } else if (ingredient is Map && ingredient.containsKey('name')) {
          name = ingredient['name'].toString();
          quantity = ingredient['quantity']?.toString();
        } else {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.blue.shade50,
                Colors.orange.shade50,
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.blue.shade100,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF2B6CB0),
                      Colors.blue.shade400,
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF2D3748),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (quantity != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.orange.shade100,
                        Colors.orange.shade50,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    quantity,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStepsList() {
    final steps = _recipe!['steps'] as List<dynamic>?;
    if (steps == null || steps.isEmpty) {
      return _buildEmptyState('Belum ada langkah');
    }
    return Column(
      children: List.generate(steps.length, (index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF2B6CB0).withValues(alpha: 0.1),
                Colors.blue.shade50,
                Colors.orange.shade50,
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF2B6CB0).withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF2B6CB0),
                      Colors.blue.shade400,
                      Colors.orange.shade400,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  steps[index].toString(),
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF2D3748),
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildTagsList() {
    if (_tags.isEmpty) {
      return _buildEmptyState('Belum ada tag');
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _tags.map((tag) {
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SearchingScreen(initialTagName: tag, initialTagId: null),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF2B6CB0),
                  Colors.blue.shade400,
                  Colors.orange.shade400,
                ],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.tag_rounded, size: 14, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  tag,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.grey.shade100,
            Colors.grey.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Center(
        child: Text(
          message,
          style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildInteractionCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.blue.shade100,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.amber.shade400,
                      Colors.orange.shade400,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.star_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Rating & Ulasan',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),

          if (_averageRating != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.amber.shade50,
                    Colors.orange.shade50,
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.amber.shade200,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.star_rounded, color: Colors.amber.shade600, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _averageRating!.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D3748),
                        ),
                      ),
                      Text(
                        'dari $_ratingCount rating',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.grey.shade100,
                    Colors.grey.shade50,
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.star_outline_rounded, color: Colors.grey.shade400, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    'Belum ada rating',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 20),

          Text(
            'Beri Rating Anda',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: List.generate(5, (index) {
              final isActive = _userRating != null && _userRating! >= index + 1;
              return GestureDetector(
                onTap: () => _submitRating(index + 1),
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(
                    isActive ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: isActive ? Colors.amber.shade600 : Colors.grey.shade300,
                    size: 32,
                  ),
                ),
              );
            }),
          ),

          const SizedBox(height: 24),
          const Divider(height: 1),
          const SizedBox(height: 20),

          Text(
            'Ulasan (${_comments.length})',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3748),
            ),
          ),
          const SizedBox(height: 16),

          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.blue.shade50,
                  Colors.orange.shade50,
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: TextField(
              controller: _commentController,
              maxLines: 3,
              minLines: 1,
              decoration: InputDecoration(
                hintText: 'Tulis ulasan Anda...',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                suffixIcon: Container(
                  margin: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF2B6CB0),
                        Colors.blue.shade400,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    onPressed: _postComment,
                    icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                  ),
                ),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _postComment(),
            ),
          ),

          const SizedBox(height: 16),

          if (_comments.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.grey.shade100,
                    Colors.grey.shade50,
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.chat_bubble_outline_rounded, size: 40, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    Text(
                      'Belum ada ulasan',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Jadilah yang pertama memberikan ulasan!',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _comments.length,
              itemBuilder: (context, index) {
                final comment = _comments[index];
                final profile = comment['profiles'];
                final username = profile?['username'] ?? 'Anonymous';
                final avatarUrl = profile?['avatar_url'];
                final isOwner = _currentUserId == comment['user_id'].toString();
                final userId = comment['user_id'].toString();

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.blue.shade50,
                        Colors.orange.shade50,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ProfileScreen(userId: userId),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.grey.shade300,
                                        Colors.grey.shade400,
                                      ],
                                    ),
                                  ),
                                  child: ClipOval(
                                    child: avatarUrl != null
                                        ? Image.network(
                                            avatarUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, _, _) => const Icon(
                                              Icons.person,
                                              size: 18,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(Icons.person, size: 18, color: Colors.white),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  username,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2D3748),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          if (isOwner)
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _showEditCommentDialog(comment['id'], comment['content']);
                                } else if (value == 'delete') {
                                  _deleteComment(comment['id']);
                                }
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit_rounded, size: 16),
                                      SizedBox(width: 8),
                                      Text('Edit'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_rounded, size: 16, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text('Hapus', style: TextStyle(color: Colors.red)),
                                    ],
                                  ),
                                ),
                              ],
                              icon: Icon(Icons.more_vert_rounded, color: Colors.grey.shade400, size: 18),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        comment['content'] ?? '',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF2D3748),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded, size: 12, color: Colors.grey.shade400),
                          const SizedBox(width: 4),
                          Text(
                            _formatDateTime(comment['created_at']),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  String _formatDateTime(String dateTimeStr) {
    try {
      final dateTime = DateTime.parse(dateTimeStr).toLocal();
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays > 7) {
        return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
      } else if (difference.inDays > 0) {
        return '${difference.inDays} hari lalu';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} jam lalu';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} menit lalu';
      } else {
        return 'Baru saja';
      }
    } catch (e) {
      return dateTimeStr;
    }
  }

  void _showEditCommentDialog(String commentId, String currentContent) {
    final controller = TextEditingController(text: currentContent);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Ulasan'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Edit ulasan Anda',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _editComment(commentId, controller.text);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2B6CB0),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}