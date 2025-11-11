import 'package:flutter/material.dart';
import '../screens/detail_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/searching_screen.dart';

/// Widget kartu resep yang dipercantik dengan layout yang lebih menarik
/// Layout struktur:
/// 1. Nama resep di paling atas
/// 2. Gambar dengan rating badge
/// 3. Info user (avatar + username + role) - bisa diklik ke profile
/// 4. Deskripsi resep
/// 5. Category dan Tags yang bisa diklik untuk searching
class RecipeCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    // Ekstrak data dari recipe
    final profile = recipe['profiles'];
    final username = profile?['username'] ?? 'Anonymous';
    final avatarUrl = profile?['avatar_url'];
    final userId = recipe['user_id']; // ID user untuk navigasi ke profile
    final userRole = profile?['role'] ?? 'user'; // Role user (admin/premium/user)
    
    final category = recipe['categories'];
    final categoryName = category?['name'] ?? 'Uncategorized';
    final categoryId = category?['id'];
    
    // Ambil tags dari recipe_tags (relasi many-to-many)
    final recipeTags = recipe['recipe_tags'] as List<dynamic>?;
    final tags = recipeTags?.map((rt) => rt['tags']).where((t) => t != null).toList() ?? [];

    return GestureDetector(
      onTap: onTap ?? () {
        // Tap selain pada user info akan ke detail screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DetailScreen(recipeId: recipe['id'].toString()),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFE5BFA5).withValues(alpha: 0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. NAMA RESEP (Header)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFF6B35).withValues(alpha: 0.1),
                    const Color(0xFFFF8C42).withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Text(
                recipe['title'] ?? 'Untitled Recipe',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF5C4033),
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // 2. GAMBAR + RATING BADGE
            Expanded(
              flex: 5,
              child: Stack(
                children: [
                  // Gambar resep
                  Container(
                    width: double.infinity,
                    color: Colors.grey.shade100,
                    child: recipe['image_url'] != null
                        ? Image.network(
                            recipe['image_url'],
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            errorBuilder: (context, error, stackTrace) => Center(
                              child: Icon(Icons.restaurant, size: 40, color: Colors.grey.shade400),
                            ),
                          )
                        : Center(
                            child: Icon(Icons.restaurant, size: 40, color: Colors.grey.shade400),
                          ),
                  ),

                  // Gradient overlay untuk readability
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.3),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Rating badge (top right)
                  if (rating != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star, color: Colors.white, size: 13),
                            const SizedBox(width: 3),
                            Text(
                              rating!.toStringAsFixed(1),
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
                ],
              ),
            ),

            // INFO SECTION
            Expanded(
              flex: 6,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 3. USER INFO (Avatar + Username + Role) - CLICKABLE
                    GestureDetector(
                      onTap: () {
                        // Navigasi ke profile screen
                        if (userId != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProfileScreen(userId: userId),
                            ),
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            // Avatar
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.grey.shade300,
                                border: Border.all(
                                  color: _getRoleBorderColor(userRole),
                                  width: 2,
                                ),
                              ),
                              child: ClipOval(
                                child: avatarUrl != null
                                    ? Image.network(
                                        avatarUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => Icon(
                                          Icons.person,
                                          size: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      )
                                    : Icon(Icons.person, size: 12, color: Colors.grey.shade600),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Username + role badge
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    username,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade800,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (userRole != 'user')
                                    Text(
                                      _getRoleLabel(userRole),
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: _getRoleBorderColor(userRole),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Icon(Icons.arrow_forward_ios, size: 10, color: Colors.grey.shade400),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // 4. DESKRIPSI RESEP
                    if (recipe['description'] != null && recipe['description'].toString().isNotEmpty) ...[
                      Text(
                        recipe['description'],
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                    ],

                    // 5. CATEGORY + TAGS (CLICKABLE)
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        // Category chip
                        GestureDetector(
                          onTap: categoryId != null
                              ? () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => SearchingScreen(
                                        initialCategoryId: categoryId,
                                        initialCategoryName: categoryName,
                                      ),
                                    ),
                                  );
                                }
                              : null,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)],
                              ),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFF6B35).withValues(alpha: 0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.category, size: 10, color: Colors.white),
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
                        ),
                        
                        // Tags chips (max 2 untuk save space)
                        ...tags.take(2).map((tag) {
                          final tagName = tag['name'] ?? '';
                          final tagId = tag['id'];
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SearchingScreen(
                                    initialTagId: tagId,
                                    initialTagName: tagName,
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6C63FF).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFF6C63FF).withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                '#$tagName',
                                style: const TextStyle(
                                  color: Color(0xFF6C63FF),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),

                    const Spacer(),

                    // Time and Calories (bottom)
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 12, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          '${recipe['cooking_time'] ?? 0}m',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.local_fire_department, size: 12, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          recipe['calories'] != null ? '${recipe['calories']} kcal' : 'N/A',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
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
    );
  }

  /// Mendapatkan warna border berdasarkan role
  Color _getRoleBorderColor(String role) {
    switch (role) {
      case 'admin':
        return const Color(0xFFFFD700); // Gold
      case 'premium':
        return const Color(0xFF6C63FF); // Purple
      default:
        return Colors.grey.shade400;
    }
  }

  /// Mendapatkan label role
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