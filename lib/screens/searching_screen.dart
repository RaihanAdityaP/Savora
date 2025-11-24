import 'package:flutter/material.dart';
import '../utils/supabase_client.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/custom_bottom_nav.dart';
import '../widgets/recipe_card.dart';
import '../widgets/theme.dart';
import 'detail_screen.dart';

class SearchingScreen extends StatefulWidget {
  final int? initialCategoryId;
  final String? initialCategoryName;
  final int? initialTagId;
  final String? initialTagName;

  const SearchingScreen({super.key, this.initialCategoryId, this.initialCategoryName, this.initialTagId, this.initialTagName});

  @override
  State<SearchingScreen> createState() => _SearchingScreenState();
}

class _SearchingScreenState extends State<SearchingScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  final Map<String, double> _recipeRatings = {};
  bool _isLoading = false;
  String _lastSearchQuery = '';
  String? _userAvatarUrl;

  int? _selectedCategoryId;
  String? _selectedCategoryName;
  int? _selectedTagId;
  String? _selectedTagName;
  String _sortBy = 'popular';
  bool _followedUsersOnly = false;

  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _popularTags = [];

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = widget.initialCategoryId;
    _selectedCategoryName = widget.initialCategoryName;
    _selectedTagId = widget.initialTagId;
    _selectedTagName = widget.initialTagName;

    _animationController = AnimationController(duration: const Duration(milliseconds: 1000), vsync: this);
    _fadeAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeInOut);
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic));

    _loadUserAvatar();
    _loadCategories();
    _loadPopularTags();
    if (_selectedCategoryId != null || _selectedTagId != null) {
      _searchRecipes('');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadUserAvatar() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId != null) {
        final response = await supabase.from('profiles').select('avatar_url').eq('id', userId).single();
        if (!mounted) return;
        setState(() => _userAvatarUrl = response['avatar_url']);
      }
    } catch (e) {
      debugPrint('Error loading user avatar: $e');
    }
  }

  Future<void> _loadCategories() async {
    try {
      final response = await supabase.from('categories').select('id, name').order('name');
      if (!mounted) return;
      setState(() => _categories = List<Map<String, dynamic>>.from(response));
    } catch (e) {
      debugPrint('Error loading categories: $e');
    }
  }

  Future<void> _loadPopularTags() async {
    try {
      final response = await supabase.from('popular_tags').select('id, name, usage_count').limit(15);
      if (!mounted) return;
      setState(() => _popularTags = List<Map<String, dynamic>>.from(response));
    } catch (e) {
      debugPrint('Error loading tags: $e');
    }
  }

  Future<void> _searchRecipes(String query) async {
    setState(() {
      _isLoading = true;
      _lastSearchQuery = query.trim();
    });
    try {
      final userId = supabase.auth.currentUser?.id;
      var queryBuilder = supabase.from('recipes').select('*, profiles!recipes_user_id_fkey(id, username, avatar_url, role), categories(id, name), recipe_tags(tags(id, name))').eq('status', 'approved');

      if (_lastSearchQuery.isNotEmpty) {
        final safeQuery = _lastSearchQuery.replaceAll('%', '\\%').replaceAll('_', '\\_');
        queryBuilder = queryBuilder.ilike('title', '%$safeQuery%');
      }
      if (_selectedCategoryId != null) {
        queryBuilder = queryBuilder.eq('category_id', _selectedCategoryId!);
      }

      if (_followedUsersOnly && userId != null) {
        final followedResponse = await supabase.from('follows').select('following_id').eq('follower_id', userId);
        final followedIds = followedResponse.map((f) => f['following_id'] as String).toList();
        if (followedIds.isNotEmpty) {
          queryBuilder = queryBuilder.filter('user_id', 'in', '(${followedIds.join(',')})');
        } else {
          if (mounted) {
            setState(() {
              _searchResults = [];
              _isLoading = false;
            });
          }
          return;
        }
      }

      final dynamic response;
      switch (_sortBy) {
        case 'newest':
          response = await queryBuilder.order('created_at', ascending: false).limit(50);
          break;
        case 'rating':
          response = await queryBuilder.order('created_at', ascending: false).limit(50);
          break;
        case 'popular':
        default:
          response = await queryBuilder.order('views_count', ascending: false).limit(50);
          break;
      }
      if (!mounted) return;

      var recipes = List<Map<String, dynamic>>.from(response);
      if (_selectedTagId != null) {
        recipes = recipes.where((recipe) {
          final recipeTags = recipe['recipe_tags'] as List<dynamic>?;
          if (recipeTags == null) return false;
          return recipeTags.any((rt) => rt['tags']?['id'] == _selectedTagId);
        }).toList();
      }

      for (var recipe in recipes) {
        final ratingResponse = await supabase.from('recipe_ratings').select('rating').eq('recipe_id', recipe['id']);
        if (ratingResponse.isNotEmpty) {
          final total = ratingResponse.fold<num>(0, (sum, r) => sum + (r['rating'] as num));
          _recipeRatings[recipe['id']] = (total / ratingResponse.length).toDouble();
        }
      }

      if (_sortBy == 'rating') {
        recipes.sort((a, b) {
          final ratingA = _recipeRatings[a['id']] ?? 0.0;
          final ratingB = _recipeRatings[b['id']] ?? 0.0;
          return ratingB.compareTo(ratingA);
        });
      }

      if (mounted) {
        setState(() {
          _searchResults = recipes;
          _isLoading = false;
        });
        _animationController.forward(from: 0);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      debugPrint('Error searching recipes: $e');
    }
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.backgroundLight,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.75,
          maxChildSize: 0.92,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) => Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: AppTheme.accentGradient,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: AppTheme.buttonShadow,
                      ),
                      child: const Icon(Icons.tune, color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Text('Filter & Urutkan', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [AppTheme.primaryCoral.withValues(alpha: 0.15), AppTheme.primaryOrange.withValues(alpha: 0.15)]),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.primaryCoral.withValues(alpha: 0.3)),
                      ),
                      child: TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _selectedCategoryId = null;
                            _selectedCategoryName = null;
                            _selectedTagId = null;
                            _selectedTagName = null;
                            _sortBy = 'popular';
                            _followedUsersOnly = false;
                          });
                          Navigator.pop(context);
                          _searchRecipes(_lastSearchQuery);
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 18, color: AppTheme.primaryCoral),
                        label: const Text('Reset', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryCoral)),
                        style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      // Sort Section
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [AppTheme.primaryTeal.withValues(alpha: 0.08), AppTheme.primaryTeal.withValues(alpha: 0.04)]),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppTheme.primaryTeal.withValues(alpha: 0.2), width: 1.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: AppTheme.primaryTeal.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
                                  child: const Icon(Icons.sort_rounded, color: AppTheme.primaryTeal, size: 20),
                                ),
                                const SizedBox(width: 10),
                                const Text('Urutkan Berdasarkan', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Wrap(spacing: 10, runSpacing: 10, children: [
                              _buildSortChip('Terpopuler', 'popular', Icons.trending_up),
                              _buildSortChip('Terbaru', 'newest', Icons.fiber_new),
                              _buildSortChip('Rating Tertinggi', 'rating', Icons.star),
                            ]),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Followed Users Filter
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [AppTheme.primaryOrange.withValues(alpha: 0.08), AppTheme.primaryOrange.withValues(alpha: 0.04)]),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppTheme.primaryOrange.withValues(alpha: 0.3), width: 1.5),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: AppTheme.primaryOrange.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                              child: const Icon(Icons.people_rounded, color: AppTheme.primaryOrange, size: 24),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Dari yang Diikuti', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                                  SizedBox(height: 2),
                                  Text('Hanya tampilkan resep dari pengguna yang Anda ikuti', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Transform.scale(
                              scale: 0.95,
                              child: Switch(
                                value: _followedUsersOnly,
                                onChanged: (value) => setState(() => _followedUsersOnly = value),
                                activeThumbColor: AppTheme.primaryOrange,
                                activeTrackColor: AppTheme.primaryOrange.withValues(alpha: 0.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Categories Section
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [AppTheme.primaryCoral.withValues(alpha: 0.08), AppTheme.primaryCoral.withValues(alpha: 0.04)]),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppTheme.primaryCoral.withValues(alpha: 0.2), width: 1.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: AppTheme.primaryCoral.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
                                  child: const Icon(Icons.category_rounded, color: AppTheme.primaryCoral, size: 20),
                                ),
                                const SizedBox(width: 10),
                                const Text('Kategori', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _categories.map((cat) {
                                final isSelected = _selectedCategoryId == cat['id'];
                                return _buildFilterChip(
                                  label: cat['name'] ?? '',
                                  isSelected: isSelected,
                                  icon: Icons.restaurant_menu_rounded,
                                  color: AppTheme.primaryCoral,
                                  onTap: () {
                                    setState(() {
                                      if (isSelected) {
                                        _selectedCategoryId = null;
                                        _selectedCategoryName = null;
                                      } else {
                                        _selectedCategoryId = cat['id'];
                                        _selectedCategoryName = cat['name'];
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Tags Section
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [AppTheme.primaryYellow.withValues(alpha: 0.08), AppTheme.primaryYellow.withValues(alpha: 0.04)]),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppTheme.primaryYellow.withValues(alpha: 0.3), width: 1.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: AppTheme.primaryYellow.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(10)),
                                  child: const Icon(Icons.local_offer_rounded, color: AppTheme.primaryDark, size: 20),
                                ),
                                const SizedBox(width: 10),
                                const Text('Tags Populer', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _popularTags.map((tag) {
                                final isSelected = _selectedTagId == tag['id'];
                                return _buildFilterChip(
                                  label: '#${tag['name'] ?? ''}',
                                  count: tag['usage_count'],
                                  isSelected: isSelected,
                                  icon: Icons.tag_rounded,
                                  color: AppTheme.primaryYellow,
                                  onTap: () {
                                    setState(() {
                                      if (isSelected) {
                                        _selectedTagId = null;
                                        _selectedTagName = null;
                                      } else {
                                        _selectedTagId = tag['id'];
                                        _selectedTagName = tag['name'];
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  height: 56,
                  decoration: AppTheme.primaryButtonDecoration,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _searchRecipes(_lastSearchQuery);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.search_rounded, color: Colors.white, size: 24),
                    label: const Text('Terapkan Filter', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSortChip(String label, String value, IconData icon) {
    final isSelected = _sortBy == value;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (!isSelected) {
            setState(() => _sortBy = value);
          }
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: isSelected ? AppTheme.tealGradient : null,
            color: isSelected ? null : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isSelected ? AppTheme.primaryTeal : Colors.grey.shade300, width: isSelected ? 2 : 1.5),
            boxShadow: isSelected ? [BoxShadow(color: AppTheme.primaryTeal.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))] : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: isSelected ? Colors.white : AppTheme.textPrimary),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(color: isSelected ? Colors.white : AppTheme.textPrimary, fontWeight: isSelected ? FontWeight.bold : FontWeight.w600, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip({required String label, int? count, required bool isSelected, required IconData icon, required Color color, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: isSelected ? LinearGradient(colors: [color, color.withValues(alpha: 0.8)]) : null,
            color: isSelected ? null : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isSelected ? color : Colors.grey.shade300, width: isSelected ? 2 : 1.5),
            boxShadow: isSelected ? [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 3))] : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: isSelected ? Colors.white : color),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: isSelected ? Colors.white : AppTheme.textPrimary, fontWeight: isSelected ? FontWeight.bold : FontWeight.w600, fontSize: 13)),
              if (count != null) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: isSelected ? Colors.white.withValues(alpha: 0.3) : color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                  child: Text('$count', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : color)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int activeFilters = 0;
    if (_selectedCategoryId != null) {
      activeFilters++;
    }
    if (_selectedTagId != null) {
      activeFilters++;
    }
    if (_followedUsersOnly) {
      activeFilters++;
    }
    if (_sortBy != 'popular') {
      activeFilters++;
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: const CustomAppBar(showBackButton: false),
      body: Column(
        children: [
          // Search Bar
          Container(
            margin: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppTheme.primaryCoral.withValues(alpha: 0.3), width: 2),
                      boxShadow: [BoxShadow(color: AppTheme.primaryCoral.withValues(alpha: 0.1), blurRadius: 15, offset: const Offset(0, 5))],
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Cari resep lezat...',
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
                        border: InputBorder.none,
                        prefixIcon: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Icon(Icons.search_rounded, color: AppTheme.primaryCoral, size: 24),
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear_rounded, color: Colors.grey.shade600),
                                onPressed: () {
                                  _searchController.clear();
                                  _searchRecipes('');
                                  setState(() {});
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      ),
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
                      onChanged: (value) {
                        setState(() {});
                        Future.delayed(const Duration(milliseconds: 500), () {
                          if (_searchController.text == value) {
                            _searchRecipes(value);
                          }
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: AppTheme.primaryButtonDecoration,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _showFilterBottomSheet,
                          borderRadius: BorderRadius.circular(16),
                          child: const Icon(Icons.tune_rounded, color: Colors.white, size: 26),
                        ),
                      ),
                    ),
                    if (activeFilters > 0)
                      Positioned(
                        top: -6,
                        right: -6,
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFFFF3B30), Color(0xFFFF6B6B)]),
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: Colors.red.withValues(alpha: 0.5), blurRadius: 8, spreadRadius: 1)],
                          ),
                          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                          child: Text('$activeFilters', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, height: 1), textAlign: TextAlign.center),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Active Filters
          if (activeFilters > 0)
            Container(
              height: 48,
              margin: const EdgeInsets.only(bottom: 12),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                physics: const BouncingScrollPhysics(),
                children: [
                  if (_selectedCategoryName != null)
                    _buildActiveFilterChip(_selectedCategoryName!, Icons.category_rounded, AppTheme.primaryCoral, () {
                      setState(() {
                        _selectedCategoryId = null;
                        _selectedCategoryName = null;
                      });
                      _searchRecipes(_lastSearchQuery);
                    }),
                  if (_selectedTagName != null)
                    _buildActiveFilterChip('#$_selectedTagName', Icons.tag_rounded, AppTheme.primaryYellow, () {
                      setState(() {
                        _selectedTagId = null;
                        _selectedTagName = null;
                      });
                      _searchRecipes(_lastSearchQuery);
                    }),
                  if (_followedUsersOnly)
                    _buildActiveFilterChip('Dari yang diikuti', Icons.people_rounded, AppTheme.primaryOrange, () {
                      setState(() => _followedUsersOnly = false);
                      _searchRecipes(_lastSearchQuery);
                    }),
                  if (_sortBy != 'popular')
                    _buildActiveFilterChip(_sortBy == 'newest' ? 'Terbaru' : 'Rating Tertinggi', Icons.sort_rounded, AppTheme.primaryTeal, () {
                      setState(() => _sortBy = 'popular');
                      _searchRecipes(_lastSearchQuery);
                    }),
                ],
              ),
            ),

          // Results
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(gradient: AppTheme.accentGradient, borderRadius: BorderRadius.circular(26), boxShadow: AppTheme.buttonShadow),
                          child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 3.5),
                        ),
                        const SizedBox(height: 26),
                        const Text('Mencari resep...', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                      ],
                    ),
                  )
                : _searchResults.isEmpty
                    ? _buildEmptyState(activeFilters)
                    : FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                            physics: const BouncingScrollPhysics(),
                            itemCount: _searchResults.length,
                            itemBuilder: (context, index) {
                              final recipe = _searchResults[index];
                              return RecipeCard(
                                recipe: recipe,
                                rating: _recipeRatings[recipe['id']],
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => DetailScreen(recipeId: recipe['id'].toString())),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
          ),
        ],
      ),
      bottomNavigationBar: CustomBottomNav(currentIndex: 1, avatarUrl: _userAvatarUrl),
    );
  }

  Widget _buildActiveFilterChip(String label, IconData icon, Color color, VoidCallback onRemove) {
    return Container(
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color.withValues(alpha: 0.15), color.withValues(alpha: 0.1)]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 2),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.8)]),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 4)],
              ),
              child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(int activeFilters) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 1400),
              tween: Tween(begin: 0.0, end: 1.0),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      gradient: AppTheme.cardGradient,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _lastSearchQuery.isNotEmpty || activeFilters > 0 ? Icons.search_off_rounded : Icons.manage_search_rounded,
                      size: 70,
                      color: AppTheme.primaryCoral,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 28),
            Text(
              _lastSearchQuery.isNotEmpty || activeFilters > 0 ? 'Tidak Ditemukan Resep' : 'Mulai Pencarian',
              style: const TextStyle(fontSize: 24, color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              _lastSearchQuery.isNotEmpty || activeFilters > 0 ? 'Coba kata kunci lain atau ubah filter pencarian' : 'Temukan ribuan resep lezat\ndengan mudah dan cepat',
              style: AppTheme.bodyLarge.copyWith(color: AppTheme.textSecondary, height: 1.6),
              textAlign: TextAlign.center,
            ),
            if (activeFilters > 0) ...[
              const SizedBox(height: 28),
              Container(
                decoration: AppTheme.primaryButtonDecoration,
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedCategoryId = null;
                      _selectedCategoryName = null;
                      _selectedTagId = null;
                      _selectedTagName = null;
                      _sortBy = 'popular';
                      _followedUsersOnly = false;
                    });
                    _searchRecipes(_lastSearchQuery);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
                  label: const Text('Reset Semua Filter', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}