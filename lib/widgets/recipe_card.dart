import 'package:flutter/material.dart';
import '../screens/detail_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/searching_screen.dart';

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
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isPressed 
                  ? const Color(0xFF2B6CB0).withValues(alpha: 0.3)
                  : Colors.grey.shade200,
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Gambar Resep - EXPANDED untuk mengisi ruang
              Expanded(
                flex: 3,
                child: Stack(
                  children: [
                    // Gambar utama
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      child: Container(
                        width: double.infinity,
                        color: Colors.grey.shade100,
                        child: widget.recipe['image_url'] != null
                            ? Image.network(
                                widget.recipe['image_url'],
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Center(
                                    child: CircularProgressIndicator(
                                      value: loadingProgress.expectedTotalBytes != null
                                          ? loadingProgress.cumulativeBytesLoaded /
                                              loadingProgress.expectedTotalBytes!
                                          : null,
                                      strokeWidth: 2,
                                      color: const Color(0xFF2B6CB0),
                                    ),
                                  );
                                },
                              )
                            : _buildPlaceholder(),
                      ),
                    ),
                    
                    // Gradient overlay di bawah
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        height: 60,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.4),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    // Rating badge
                    if (widget.rating != null)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded, color: Colors.white, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                widget.rating!.toStringAsFixed(1),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Judul resep di atas gambar
                    Positioned(
                      bottom: 10,
                      left: 12,
                      right: 12,
                      child: Text(
                        widget.recipe['title'] ?? 'Untitled Recipe',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: Colors.black54,
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              // Info Section - TIDAK EXPANDED, menggunakan mainAxisSize
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _getRoleBorderColor(userRole).withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: _getRoleGradient(userRole),
                                ),
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: ClipOval(
                                child: avatarUrl != null
                                    ? Image.network(
                                        avatarUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => Icon(
                                          Icons.person_rounded,
                                          size: 14,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Icon(Icons.person_rounded, size: 14, color: Colors.white),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    username,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2D3748),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (userRole != 'user')
                                    Container(
                                      margin: const EdgeInsets.only(top: 2),
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: _getRoleGradient(userRole),
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        _getRoleLabel(userRole),
                                        style: const TextStyle(
                                          fontSize: 8,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Colors.grey.shade400),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Category & Tags
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _buildCategoryChip(context, categoryId, categoryName),
                        ...tags.take(2).map((tag) => _buildTagChip(context, tag)),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Time & Calories
                    Row(
                      children: [
                        _buildInfoBadge(
                          Icons.access_time_rounded,
                          '${widget.recipe['cooking_time'] ?? 0}m',
                          const Color(0xFF2B6CB0),
                        ),
                        const SizedBox(width: 8),
                        _buildInfoBadge(
                          Icons.local_fire_department_rounded,
                          widget.recipe['calories'] != null
                              ? '${widget.recipe['calories']} kcal'
                              : 'N/A',
                          const Color(0xFFFF6B35),
                        ),
                      ],
                    ),
                  ],
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
      width: double.infinity,
      height: double.infinity,
      color: Colors.grey.shade200,
      child: Center(
        child: Icon(
          Icons.restaurant_rounded,
          size: 50,
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF2B6CB0),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.category_rounded, size: 10, color: Colors.white),
            const SizedBox(width: 4),
            Text(
              categoryName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFFF6B35).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFFFF6B35).withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          '#$tagName',
          style: const TextStyle(
            color: Color(0xFFFF6B35),
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBadge(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
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

  Color _getRoleBorderColor(String role) {
    switch (role) {
      case 'admin':
        return const Color(0xFFFFD700);
      case 'premium':
        return const Color(0xFF6C63FF);
      default:
        return Colors.grey.shade400;
    }
  }

  String _getRoleLabel(String role) {
    switch (role) {
      case 'admin':
        return 'ADMIN';
      case 'premium':
        return 'PREMIUM';
      default:
        return '';
    }
  }
}