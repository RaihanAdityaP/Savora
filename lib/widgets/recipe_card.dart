import 'package:flutter/material.dart';
import '../screens/detail_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/searching_screen.dart';
import '../utils/supabase_client.dart';

class RecipeCard extends StatefulWidget {
  final Map<String, dynamic> recipe;
  final double? rating;
  final VoidCallback? onTap;

  const RecipeCard({
    super.key,
    required this.recipe,
    this.rating,
    this.onTap,
  });

  @override
  State<RecipeCard> createState() => _RecipeCardState();
}

class _RecipeCardState extends State<RecipeCard> {
  bool _isPressed = false;
  bool _isFavorite = false;
  bool _isCheckingFavorite = true;

  @override
  void initState() {
    super.initState();
    _checkIfFavorite();
  }

  Future<void> _checkIfFavorite() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId != null) {
        final response = await supabase
            .from('favorites')
            .select()
            .eq('user_id', userId)
            .eq('recipe_id', widget.recipe['id'])
            .maybeSingle();
        
        if (mounted) {
          setState(() {
            _isFavorite = response != null;
            _isCheckingFavorite = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCheckingFavorite = false);
      }
    }
  }

  Future<void> _showBoardSelector() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        if (!mounted) return;
        _showSnackBar('Silakan login terlebih dahulu', isError: true);
        return;
      }

      final boards = await supabase
          .from('recipe_boards')
          .select('id, name, description')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (context) => _buildBoardSelectorSheet(
          List<Map<String, dynamic>>.from(boards),
          userId,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Error: $e', isError: true);
    }
  }

  Widget _buildBoardSelectorSheet(List<Map<String, dynamic>> boards, String userId) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE76F51), Color(0xFFF4A261)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.collections_bookmark_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Simpan ke Koleksi',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF264653),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Create new collection button
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE76F51), Color(0xFFF4A261), Color(0xFFE9C46A)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE76F51).withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Navigator.pop(context);
                  _showCreateBoardDialog(userId);
                },
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Buat Koleksi Baru',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Collections list
          if (boards.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.collections_bookmark_outlined, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text(
                      'Belum ada koleksi',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Buat koleksi pertama Anda',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: boards.length,
                itemBuilder: (context, index) {
                  final board = boards[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFE76F51).withValues(alpha: 0.2),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          _addToBoard(board['id'], board['name']);
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      const Color(0xFFE76F51).withValues(alpha: 0.2),
                                      const Color(0xFFF4A261).withValues(alpha: 0.1),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.collections_bookmark_rounded,
                                  color: Color(0xFFE76F51),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      board['name'] ?? '',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF264653),
                                      ),
                                    ),
                                    if (board['description'] != null &&
                                        board['description'].toString().isNotEmpty)
                                      Text(
                                        board['description'],
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 14,
                                color: Color(0xFFE76F51),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  void _showCreateBoardDialog(String userId) {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE76F51), Color(0xFFF4A261)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            const Text(
              'Koleksi Baru',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200, width: 1.5),
              ),
              child: TextField(
                controller: nameController,
                decoration: InputDecoration(
                  hintText: 'Nama Koleksi',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  prefixIcon: const Icon(Icons.collections_bookmark_rounded, color: Color(0xFFE76F51)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200, width: 1.5),
              ),
              child: TextField(
                controller: descController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Deskripsi (opsional)',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 60),
                    child: Icon(Icons.description_rounded, color: Color(0xFFF4A261)),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey.shade600,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text('Batal', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE76F51), Color(0xFFF4A261)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  if (!dialogContext.mounted) return;
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('Nama koleksi harus diisi')),
                  );
                  return;
                }

                try {
                  await supabase.from('recipe_boards').insert({
                    'user_id': userId,
                    'name': nameController.text.trim(),
                    'description': descController.text.trim(),
                  });

                  if (!dialogContext.mounted) return;
                  Navigator.pop(dialogContext);
                  
                  if (!mounted) return;
                  _showSnackBar('Koleksi berhasil dibuat!', isError: false);
                  _showBoardSelector();
                } catch (e) {
                  if (!mounted) return;
                  _showSnackBar('Error: $e', isError: true);
                }
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: const Text(
                'Buat',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addToBoard(String boardId, String boardName) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Check if already exists
      final existing = await supabase
          .from('board_recipes')
          .select()
          .eq('board_id', boardId)
          .eq('recipe_id', widget.recipe['id'])
          .maybeSingle();

      if (existing != null) {
        if (!mounted) return;
        _showSnackBar('Resep sudah ada di koleksi ini', isError: true);
        return;
      }

      await supabase.from('board_recipes').insert({
        'board_id': boardId,
        'recipe_id': widget.recipe['id'],
      });

      if (mounted) {
        setState(() => _isFavorite = true);
        _showSnackBar('Ditambahkan ke "$boardName"', isError: false);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Error: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
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
    final profile = widget.recipe['profiles'];
    final username = profile?['username'] ?? 'Anonymous';
    final avatarUrl = profile?['avatar_url'];
    final userId = widget.recipe['user_id'];
    final userRole = profile?['role'] ?? 'user';

    final category = widget.recipe['categories'];
    final categoryName = category?['name'] ?? 'Uncategorized';
    final categoryId = category?['id'];

    final recipeTags = widget.recipe['recipe_tags'] as List<dynamic>?;
    final tags = recipeTags?.map((rt) => rt['tags']).where((t) => t != null).toList() ?? [];

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        if (widget.onTap != null) {
          widget.onTap!();
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DetailScreen(recipeId: widget.recipe['id'].toString()),
            ),
          );
        }
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          height: 140,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isPressed
                  ? const Color(0xFFE76F51).withValues(alpha: 0.4)
                  : const Color(0xFFE76F51).withValues(alpha: 0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _isPressed ? 0.12 : 0.08),
                blurRadius: _isPressed ? 16 : 12,
                offset: Offset(0, _isPressed ? 6 : 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Image Section
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      bottomLeft: Radius.circular(20),
                    ),
                    child: Container(
                      width: 130,
                      height: double.infinity,
                      color: Colors.grey.shade100,
                      child: widget.recipe['image_url'] != null
                          ? Image.network(
                              widget.recipe['image_url'],
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
                            )
                          : _buildPlaceholder(),
                    ),
                  ),
                  // Rating badge
                  if (widget.rating != null)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                          ),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded, color: Colors.white, size: 12),
                            const SizedBox(width: 3),
                            Text(
                              widget.rating!.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),

              // Content Section
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        widget.recipe['title'] ?? 'Untitled Recipe',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF264653),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),

                      // User info
                      GestureDetector(
                        onTap: userId != null
                            ? () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ProfileScreen(userId: userId),
                                  ),
                                )
                            : null,
                        child: Row(
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: _getRoleGradient(userRole),
                                ),
                              ),
                              child: ClipOval(
                                child: avatarUrl != null
                                    ? Image.network(
                                        avatarUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) =>
                                            const Icon(Icons.person_rounded, size: 12, color: Colors.white),
                                      )
                                    : const Icon(Icons.person_rounded, size: 12, color: Colors.white),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                username,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Spacer(),

                      // Bottom row: Category/Tags + Actions
                      Row(
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: [
                                _buildCategoryChip(context, categoryId, categoryName),
                                if (tags.isNotEmpty) _buildTagChip(context, tags.first),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Favorite button
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _isCheckingFavorite ? null : _showBoardSelector,
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  gradient: _isFavorite
                                      ? const LinearGradient(
                                          colors: [Color(0xFFE76F51), Color(0xFFF4A261)],
                                        )
                                      : null,
                                  color: _isFavorite ? null : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  _isFavorite ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                                  color: _isFavorite ? Colors.white : Colors.grey.shade600,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey.shade200,
      child: Center(
        child: Icon(
          Icons.restaurant_rounded,
          size: 40,
          color: Colors.grey.shade400,
        ),
      ),
    );
  }

  Widget _buildCategoryChip(BuildContext context, int? categoryId, String categoryName) {
    return GestureDetector(
      onTap: categoryId != null
          ? () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SearchingScreen(
                    initialCategoryId: categoryId,
                    initialCategoryName: categoryName,
                  ),
                ),
              )
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF264653), Color(0xFF2A9D8F)],
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          categoryName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildTagChip(BuildContext context, dynamic tag) {
    final tagName = tag['name'] ?? '';
    final tagId = tag['id'];

    return GestureDetector(
      onTap: tagId != null
          ? () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SearchingScreen(
                    initialTagId: tagId,
                    initialTagName: tagName,
                  ),
                ),
              )
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFE9C46A).withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: const Color(0xFFE9C46A),
            width: 1,
          ),
        ),
        child: Text(
          '#$tagName',
          style: const TextStyle(
            color: Color(0xFF264653),
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  List<Color> _getRoleGradient(String role) {
    switch (role) {
      case 'admin':
        return [const Color(0xFFFFD700), const Color(0xFFFFB300)];
      case 'premium':
        return [const Color(0xFF6C63FF), const Color(0xFF9F8FFF)];
      default:
        return [Colors.grey.shade400, Colors.grey.shade500];
    }
  }
}