import 'package:flutter/material.dart';
import '../utils/supabase_client.dart';
import '../widgets/custom_bottom_nav.dart';
import 'home_screen.dart';
import 'edit_recipe_screen.dart';

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
  final TextEditingController _commentController = TextEditingController();
  String? _userAvatarUrl;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = supabase.auth.currentUser?.id;
    _initializeScreen();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _initializeScreen() async {
    await Future.wait([
      _loadRecipe(),
      _incrementViews(),
      _checkIfFavorite(),
      _loadUserRating(),
      _loadComments(),
      _loadUserAvatar(),
    ]);
  }

  Future<void> _loadUserAvatar() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId != null) {
        final response = await supabase
            .from('profiles')
            .select('avatar_url')
            .eq('id', userId)
            .single();
        if (!mounted) return;
        setState(() => _userAvatarUrl = response['avatar_url']);
      }
    } catch (e) {
      debugPrint('Error loading user avatar: $e');
    }
  }

  Future<void> _loadRecipe() async {
    try {
      final response = await supabase
          .from('recipes')
          .select('*, profiles!recipes_user_id_fkey(username, avatar_url, role, is_premium)')
          .eq('id', widget.recipeId)
          .single();

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
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnackBar('Error loading recipe: $e');
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

  Future<void> _toggleFavorite() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        _showSnackBar('Please log in to favorite.');
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
      _showSnackBar(_isFavorite ? 'Added to favorites!' : 'Removed from favorites.');
    } catch (e) {
      _showSnackBar('Error updating favorite: $e');
    }
  }

  Future<void> _submitRating(int rating) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        _showSnackBar('Please log in to rate.');
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
      _showSnackBar('Rating ${existingRating != null ? 'updated' : 'submitted'}!');
    } catch (e) {
      _showSnackBar('Failed to submit rating: $e');
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
      _showSnackBar('Comment cannot be empty.');
      return;
    }
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        _showSnackBar('Please log in to comment.');
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
      _showSnackBar('Comment posted!');
    } catch (e) {
      _showSnackBar('Error posting comment: $e');
    }
  }

  Future<void> _editComment(String commentId, String newContent) async {
    if (newContent.trim().isEmpty) return;
    try {
      await supabase
          .from('comments')
          .update({'content': newContent.trim(), 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', commentId);
      await _loadComments();
      if (!mounted) return;
      _showSnackBar('Comment updated!');
    } catch (e) {
      _showSnackBar('Error updating comment: $e');
    }
  }

  Future<void> _deleteComment(String commentId) async {
    final confirm = await _showConfirmDialog(
      'Hapus Komentar',
      'Apakah Anda yakin ingin menghapus komentar ini?',
    );
    if (confirm == true) {
      try {
        await supabase.from('comments').delete().eq('id', commentId);
        await _loadComments();
        if (!mounted) return;
        _showSnackBar('Comment deleted!');
      } catch (e) {
        _showSnackBar('Error deleting comment: $e');
      }
    }
  }

  Future<void> _deleteRecipe() async {
    final confirm = await _showConfirmDialog(
      'Hapus Resep',
      'Apakah Anda yakin ingin menghapus resep ini? Tindakan ini tidak dapat dibatalkan.',
    );

    if (confirm == true) {
      try {
        await supabase.from('comments').delete().eq('recipe_id', widget.recipeId);
        await supabase.from('recipe_ratings').delete().eq('recipe_id', widget.recipeId);
        await supabase.from('favorites').delete().eq('recipe_id', widget.recipeId);
        await supabase.from('recipes').delete().eq('id', widget.recipeId);

        if (!mounted) return;
        _showSnackBar('Resep berhasil dihapus!');
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      } catch (e) {
        _showSnackBar('Error menghapus resep: $e');
      }
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool?> _showConfirmDialog(String title, String content) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  void _showEditCommentDialog(String commentId, String currentContent) {
    final controller = TextEditingController(text: currentContent);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Comment'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Edit your comment'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _editComment(commentId, controller.text);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userRole = _recipe?['profiles']?['role'] as String? ?? 'user';
    final isOwner = _currentUserId == _recipe?['user_id'].toString();
    final canEdit = isOwner || userRole == 'admin';

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _recipe == null
              ? const Center(child: Text('Recipe not found'))
              : CustomScrollView(
                  slivers: [
                    _buildAppBar(canEdit),
                    SliverToBoxAdapter(
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFF4E6),
                          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildHeader(),
                              const SizedBox(height: 16),
                              _buildRatingSection(),
                              const SizedBox(height: 20),
                              _buildUserInfo(),
                              const SizedBox(height: 20),
                              _buildInfoChips(),
                              const SizedBox(height: 24),
                              _buildSectionTitle('Ingredients'),
                              const SizedBox(height: 12),
                              _buildIngredientsList(),
                              const SizedBox(height: 24),
                              _buildSectionTitle('Steps'),
                              const SizedBox(height: 12),
                              _buildStepsList(),
                              const SizedBox(height: 24),
                              _buildSectionTitle('Comments'),
                              const SizedBox(height: 12),
                              _buildCommentInput(),
                              const SizedBox(height: 12),
                              _buildCommentsList(),
                              const SizedBox(height: 100),
                            ],
                          ),
                        ),
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

  Widget _buildAppBar(bool canEdit) {
    return SliverAppBar(
      expandedHeight: 300,
      pinned: true,
      backgroundColor: const Color(0xFFE5BFA5),
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.arrow_back, color: Color(0xFF5C4033)),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        if (canEdit)
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.edit, color: Color(0xFF5C4033)),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditRecipeScreen(recipe: _recipe!),
                ),
              ).then((_) => _loadRecipe());
            },
          ),
        if (canEdit)
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete, color: Colors.red),
            ),
            onPressed: _deleteRecipe,
          ),
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isFavorite ? Icons.bookmark : Icons.bookmark_border,
              color: const Color(0xFF5C4033),
            ),
          ),
          onPressed: _toggleFavorite,
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            _recipe!['image_url'] != null
                ? Image.network(_recipe!['image_url'], fit: BoxFit.cover)
                : Container(
                    color: Colors.grey[300],
                    child: const Icon(Icons.restaurant, size: 80, color: Colors.grey),
                  ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.3)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _recipe!['title'] ?? 'Untitled',
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Color(0xFF5C4033),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _recipe!['description'] ?? '',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildRatingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_averageRating != null)
          Row(
            children: [
              const Icon(Icons.star, color: Colors.amber, size: 20),
              const SizedBox(width: 4),
              Text(
                _averageRating!.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF5C4033),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '($_ratingCount ratings)',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          )
        else
          Text('No ratings yet', style: TextStyle(color: Colors.grey[600])),
        const SizedBox(height: 8),
        Wrap(
          spacing: 4,
          children: List.generate(5, (index) {
            final isActive = _userRating != null && _userRating! >= index + 1;
            return GestureDetector(
              onTap: () => _submitRating(index + 1),
              child: Icon(
                Icons.star,
                color: isActive ? Colors.amber : Colors.grey[400],
                size: 28,
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildUserInfo() {
    final profile = _recipe!['profiles'];
    final username = profile?['username'] ?? 'Anonymous';
    final avatarUrl = profile?['avatar_url'];
    final role = profile?['role'] ?? 'user';
    final isPremium = profile?['is_premium'] ?? false;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: role == 'admin'
                    ? const Color(0xFFD4AF37)
                    : isPremium
                        ? const Color(0xFFE5BFA5)
                        : Colors.grey[300]!,
                width: role == 'admin' || isPremium ? 2 : 1,
              ),
            ),
            child: ClipOval(
              child: avatarUrl != null
                  ? Image.network(avatarUrl, fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const Icon(Icons.person, size: 24, color: Colors.grey))
                  : const Icon(Icons.person, size: 24, color: Colors.grey),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  username,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF5C4033),
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: role == 'admin'
                        ? const Color(0xFFD4AF37)
                        : isPremium
                            ? const Color(0xFFE5BFA5)
                            : Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        role == 'admin'
                            ? Icons.admin_panel_settings
                            : isPremium
                                ? Icons.workspace_premium
                                : Icons.person,
                        size: 12,
                        color: role == 'admin' || isPremium
                            ? Colors.white
                            : Colors.grey[700],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        role == 'admin'
                            ? 'ADMIN'
                            : isPremium
                                ? 'SAVORA CHEF'
                                : 'PENGGUNA',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: role == 'admin' || isPremium
                              ? Colors.white
                              : Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChips() {
    return Column(
      children: [
        Row(
          children: [
            _buildInfoChip(
              '${_recipe!['cooking_time'] ?? 15} MIN',
              'prep time',
              const Color(0xFFFF6B35),
              Icons.access_time,
            ),
            const SizedBox(width: 8),
            _buildInfoChip(
              '${_recipe!['servings'] ?? 1}',
              'Serving',
              const Color(0xFF8BC34A),
              Icons.restaurant_menu,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildInfoChip(
              _recipe!['difficulty'] ?? 'mudah',
              'level',
              const Color(0xFFFF9800),
              Icons.bar_chart,
            ),
            const SizedBox(width: 8),
            _buildInfoChip(
              _recipe!['calories'] != null ? '${_recipe!['calories']} kcal' : 'N/A',
              'calories',
              const Color(0xFFE91E63),
              Icons.local_fire_department,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoChip(String value, String label, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              value.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xFF5C4033),
      ),
    );
  }

  Widget _buildIngredientsList() {
    final ingredients = _recipe!['ingredients'] as List<dynamic>?;
    if (ingredients == null || ingredients.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            'No ingredients listed',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ),
      );
    }
    return Column(
      children: ingredients.map((ingredient) {
        if (ingredient is String) {
          return _buildIngredientItem(ingredient, null);
        } else if (ingredient is Map && ingredient.containsKey('name')) {
          return _buildIngredientItem(
            ingredient['name'].toString(),
            ingredient['quantity']?.toString(),
          );
        }
        return const SizedBox.shrink();
      }).toList(),
    );
  }

  Widget _buildIngredientItem(String name, String? quantity) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5BFA5).withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B35).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle,
              color: Color(0xFFFF6B35),
              size: 18,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF5C4033),
                height: 1.4,
              ),
            ),
          ),
          if (quantity != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF8BC34A).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                quantity,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF5C4033),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStepsList() {
    final steps = _recipe!['steps'] as List<dynamic>?;
    if (steps == null || steps.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            'No steps listed',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ),
      );
    }
    return Column(
      children: List.generate(steps.length, (index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF9CB5C5),
                const Color(0xFF9CB5C5).withValues(alpha: 0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF9CB5C5).withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF9CB5C5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    steps[index].toString(),
                    style: const TextStyle(
                      fontSize: 15,
                      color: Colors.white,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildCommentInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: _commentController,
        maxLines: 3,
        minLines: 1,
        decoration: InputDecoration(
          hintText: 'Write a comment...',
          hintStyle: TextStyle(color: Colors.grey[500]),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          suffixIcon: IconButton(
            onPressed: _postComment,
            icon: const Icon(Icons.send, color: Color(0xFF5C4033)),
          ),
        ),
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _postComment(),
      ),
    );
  }

  Widget _buildCommentsList() {
    if (_comments.isEmpty) {
      return const Text('No comments yet. Be the first to comment!');
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _comments.length,
      itemBuilder: (context, index) {
        final comment = _comments[index];
        final profile = comment['profiles'];
        final username = profile?['username'] ?? 'Anonymous';
        final avatarUrl = profile?['avatar_url'];
        final isOwner = _currentUserId == comment['user_id'].toString();

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey[300],
                    ),
                    child: ClipOval(
                      child: avatarUrl != null
                          ? Image.network(
                              avatarUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Icon(
                                Icons.person,
                                size: 18,
                                color: Colors.grey,
                              ),
                            )
                          : const Icon(Icons.person, size: 18, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          username,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF5C4033),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          comment['content'] ?? '',
                          style: const TextStyle(fontSize: 14, color: Color(0xFF5C4033)),
                        ),
                      ],
                    ),
                  ),
                  if (isOwner)
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          _showEditCommentDialog(comment['id'], comment['content']);
                        } else if (value == 'delete') {
                          _deleteComment(comment['id']);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'edit', child: Text('Edit')),
                        const PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                DateTime.parse(comment['created_at']).toLocal().toString().split('.')[0],
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              ),
            ],
          ),
        );
      },
    );
  }
}