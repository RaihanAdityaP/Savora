import 'package:flutter/material.dart';
import '../utils/supabase_client.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/custom_bottom_nav.dart';
import '../widgets/recipe_card.dart';
import 'detail_screen.dart';

/// Enhanced SearchingScreen dengan fitur:
/// 1. Filter berdasarkan category dan tags (clickable)
/// 2. Sorting (rating tertinggi, terbaru, terpopuler)
/// 3. Toggle untuk menampilkan resep dari user yang difollow saja
/// 4. Animasi loading seperti ProfileScreen
class SearchingScreen extends StatefulWidget {
  final int? initialCategoryId;
  final String? initialCategoryName;
  final int? initialTagId;
  final String? initialTagName;

  const SearchingScreen({
    super.key,
    this.initialCategoryId,
    this.initialCategoryName,
    this.initialTagId,
    this.initialTagName,
  });

  @override
  State<SearchingScreen> createState() => _SearchingScreenState();
}

class _SearchingScreenState extends State<SearchingScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  final Map<String, double> _recipeRatings = {}; // Cache rating
  bool _isLoading = false;
  String _lastSearchQuery = '';
  String? _userAvatarUrl;

  // Filter states
  int? _selectedCategoryId;
  String? _selectedCategoryName;
  int? _selectedTagId;
  String? _selectedTagName;
  String _sortBy = 'popular'; // popular, newest, rating
  bool _followedUsersOnly = false;

  // Available categories & tags
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _popularTags = [];

  // Animation
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    
    // Set initial filters dari parameter
    _selectedCategoryId = widget.initialCategoryId;
    _selectedCategoryName = widget.initialCategoryName;
    _selectedTagId = widget.initialTagId;
    _selectedTagName = widget.initialTagName;

    // Setup animation
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _loadUserAvatar();
    _loadCategories();
    _loadPopularTags();
    
    // Auto search jika ada initial filter
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

  /// Memuat avatar user yang sedang login
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
        setState(() {
          _userAvatarUrl = response['avatar_url'];
        });
      }
    } catch (e) {
      debugPrint('Error loading user avatar: $e');
    }
  }

  /// Memuat daftar kategori
  Future<void> _loadCategories() async {
    try {
      final response = await supabase
          .from('categories')
          .select('id, name')
          .order('name');
      if (!mounted) return;
      setState(() {
        _categories = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      debugPrint('Error loading categories: $e');
    }
  }

  /// Memuat popular tags dari view
  Future<void> _loadPopularTags() async {
    try {
      final response = await supabase
          .from('popular_tags')
          .select('id, name, usage_count')
          .limit(15);
      if (!mounted) return;
      setState(() {
        _popularTags = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      debugPrint('Error loading tags: $e');
    }
  }

  /// Fungsi utama untuk mencari resep dengan berbagai filter
  Future<void> _searchRecipes(String query) async {
    setState(() {
      _isLoading = true;
      _lastSearchQuery = query.trim();
    });

    try {
      final userId = supabase.auth.currentUser?.id;
      
      // Build query dengan select yang include tags
      var queryBuilder = supabase
          .from('recipes')
          .select('''
            *, 
            profiles!recipes_user_id_fkey(id, username, avatar_url, role),
            categories(id, name),
            recipe_tags(tags(id, name))
          ''')
          .eq('status', 'approved');

      // Filter berdasarkan search text
      if (_lastSearchQuery.isNotEmpty) {
        final safeQuery = _lastSearchQuery.replaceAll('%', '\\%').replaceAll('_', '\\_');
        queryBuilder = queryBuilder.ilike('title', '%$safeQuery%');
      }

      // Filter berdasarkan category
      if (_selectedCategoryId != null) {
        queryBuilder = queryBuilder.eq('category_id', _selectedCategoryId!);
      }

      // Filter berdasarkan followed users
      if (_followedUsersOnly && userId != null) {
        // Ambil daftar user yang difollow
        final followedResponse = await supabase
            .from('follows')
            .select('following_id')
            .eq('follower_id', userId);
        
        final followedIds = followedResponse
            .map((f) => f['following_id'] as String)
            .toList();
        
        if (followedIds.isNotEmpty) {
          queryBuilder = queryBuilder.filter('user_id', 'in', '(${followedIds.join(',')})');
        } else {
          // Jika tidak ada yang difollow, return empty
          if (mounted) {
            setState(() {
              _searchResults = [];
              _isLoading = false;
            });
          }
          return;
        }
      }

      // Sorting - kita perlu execute query dengan order dan limit
      final dynamic response;
      switch (_sortBy) {
        case 'newest':
          response = await queryBuilder.order('created_at', ascending: false).limit(50);
          break;
        case 'rating':
          // Sort by rating akan dilakukan di client side karena butuh join
          response = await queryBuilder.order('created_at', ascending: false).limit(50);
          break;
        case 'popular':
        default:
          response = await queryBuilder.order('views_count', ascending: false).limit(50);
          break;
      }
      if (!mounted) return;

      var recipes = List<Map<String, dynamic>>.from(response);

      // Filter by tag di client side (karena many-to-many)
      if (_selectedTagId != null) {
        recipes = recipes.where((recipe) {
          final recipeTags = recipe['recipe_tags'] as List<dynamic>?;
          if (recipeTags == null) return false;
          return recipeTags.any((rt) => rt['tags']?['id'] == _selectedTagId);
        }).toList();
      }

      // Load ratings untuk semua resep
      for (var recipe in recipes) {
        final ratingResponse = await supabase
            .from('recipe_ratings')
            .select('rating')
            .eq('recipe_id', recipe['id']);
        
        if (ratingResponse.isNotEmpty) {
          final total = ratingResponse.fold<num>(0, (sum, r) => sum + (r['rating'] as num));
          _recipeRatings[recipe['id']] = (total / ratingResponse.length).toDouble();
        }
      }

      // Sort by rating jika dipilih
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

  /// Bottom sheet untuk memilih filter
  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Filter & Urutkan',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF5C4033),
                    ),
                  ),
                  TextButton(
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
                    child: const Text('Reset'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    // Sort By
                    const Text(
                      'Urutkan Berdasarkan',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF5C4033),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildSortChip('Terpopuler', 'popular', Icons.trending_up),
                        _buildSortChip('Terbaru', 'newest', Icons.fiber_new),
                        _buildSortChip('Rating Tertinggi', 'rating', Icons.star),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Followed Users Only Toggle
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.people, color: Colors.blue.shade700),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Hanya dari yang diikuti',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue.shade900,
                              ),
                            ),
                          ),
                          Switch(
                            value: _followedUsersOnly,
                            onChanged: (value) {
                              setState(() => _followedUsersOnly = value);
                            },
                            activeTrackColor: Colors.blue.shade700,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Categories
                    const Text(
                      'Kategori',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF5C4033),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _categories.map((cat) {
                        final isSelected = _selectedCategoryId == cat['id'];
                        return FilterChip(
                          label: Text(cat['name'] ?? ''),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedCategoryId = cat['id'];
                                _selectedCategoryName = cat['name'];
                              } else {
                                _selectedCategoryId = null;
                                _selectedCategoryName = null;
                              }
                            });
                          },
                          backgroundColor: Colors.grey.shade100,
                          selectedColor: const Color(0xFFFF6B35).withValues(alpha: 0.2),
                          checkmarkColor: const Color(0xFFFF6B35),
                          labelStyle: TextStyle(
                            color: isSelected ? const Color(0xFFFF6B35) : Colors.grey.shade700,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // Popular Tags
                    const Text(
                      'Tags Populer',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF5C4033),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _popularTags.map((tag) {
                        final isSelected = _selectedTagId == tag['id'];
                        return FilterChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('#${tag['name'] ?? ''}'),
                              const SizedBox(width: 4),
                              Text(
                                '(${tag['usage_count'] ?? 0})',
                                style: const TextStyle(fontSize: 10),
                              ),
                            ],
                          ),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedTagId = tag['id'];
                                _selectedTagName = tag['name'];
                              } else {
                                _selectedTagId = null;
                                _selectedTagName = null;
                              }
                            });
                          },
                          backgroundColor: Colors.grey.shade100,
                          selectedColor: const Color(0xFF6C63FF).withValues(alpha: 0.2),
                          checkmarkColor: const Color(0xFF6C63FF),
                          labelStyle: TextStyle(
                            color: isSelected ? const Color(0xFF6C63FF) : Colors.grey.shade700,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              
              // Apply button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _searchRecipes(_lastSearchQuery);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B35),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Terapkan Filter',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Widget untuk sort chip
  Widget _buildSortChip(String label, String value, IconData icon) {
    final isSelected = _sortBy == value;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.grey.shade700),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _sortBy = value);
        }
      },
      backgroundColor: Colors.grey.shade100,
      selectedColor: const Color(0xFFFF6B35),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.grey.shade700,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Hitung jumlah active filters
    int activeFilters = 0;
    if (_selectedCategoryId != null) activeFilters++;
    if (_selectedTagId != null) activeFilters++;
    if (_followedUsersOnly) activeFilters++;
    if (_sortBy != 'popular') activeFilters++;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      appBar: const CustomAppBar(showBackButton: true),
      body: Column(
        children: [
          // Search Bar + Filter Button
          Container(
            margin: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Search field
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFF6B35), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Cari resep...',
                        hintStyle: TextStyle(color: Colors.grey.shade500),
                        border: InputBorder.none,
                        prefixIcon: const Icon(Icons.search, color: Color(0xFFFF6B35)),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: Color(0xFF5C4033)),
                                onPressed: () {
                                  _searchController.clear();
                                  _searchRecipes('');
                                  setState(() {});
                                },
                              )
                            : null,
                      ),
                      style: const TextStyle(color: Color(0xFF5C4033)),
                      onChanged: (value) {
                        setState(() {});
                        // Debounce search
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
                
                // Filter button dengan badge
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF6B35).withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _showFilterBottomSheet,
                          borderRadius: BorderRadius.circular(12),
                          child: const Icon(Icons.tune, color: Colors.white),
                        ),
                      ),
                    ),
                    if (activeFilters > 0)
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 20,
                            minHeight: 20,
                          ),
                          child: Text(
                            '$activeFilters',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Active filters chips
          if (activeFilters > 0)
            Container(
              height: 40,
              margin: const EdgeInsets.only(bottom: 12),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  if (_selectedCategoryName != null)
                    _buildActiveFilterChip(
                      _selectedCategoryName!,
                      Icons.category,
                      () {
                        setState(() {
                          _selectedCategoryId = null;
                          _selectedCategoryName = null;
                        });
                        _searchRecipes(_lastSearchQuery);
                      },
                    ),
                  if (_selectedTagName != null)
                    _buildActiveFilterChip(
                      '#$_selectedTagName',
                      Icons.tag,
                      () {
                        setState(() {
                          _selectedTagId = null;
                          _selectedTagName = null;
                        });
                        _searchRecipes(_lastSearchQuery);
                      },
                    ),
                  if (_followedUsersOnly)
                    _buildActiveFilterChip(
                      'Dari yang diikuti',
                      Icons.people,
                      () {
                        setState(() => _followedUsersOnly = false);
                        _searchRecipes(_lastSearchQuery);
                      },
                    ),
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
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const CircularProgressIndicator(color: Colors.white),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Mencari resep...',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF5C4033),
                          ),
                        ),
                      ],
                    ),
                  )
                : _searchResults.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off, size: 80, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text(
                              _lastSearchQuery.isNotEmpty || activeFilters > 0
                                  ? 'Tidak ditemukan resep'
                                  : 'Cari resep favoritmu',
                              style: TextStyle(fontSize: 18, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                              textAlign: TextAlign.center,
                            ),
                            if (activeFilters > 0) ...[
                              const SizedBox(height: 8),
                              TextButton(
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
                                child: const Text('Reset Filter'),
                              ),
                            ],
                          ],
                        ),
                      )
                    : FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: GridView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.55,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                            itemCount: _searchResults.length,
                            itemBuilder: (context, index) {
                              final recipe = _searchResults[index];
                              return RecipeCard(
                                recipe: recipe,
                                rating: _recipeRatings[recipe['id']],
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => DetailScreen(recipeId: recipe['id'].toString()),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ),
          ),
        ],
      ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: 1,
        avatarUrl: _userAvatarUrl,
      ),
    );
  }

  /// Widget untuk active filter chip yang bisa dihapus
  Widget _buildActiveFilterChip(String label, IconData icon, VoidCallback onRemove) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFF6B35).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFF6B35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFFFF6B35)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFFF6B35),
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close, size: 16, color: Color(0xFFFF6B35)),
          ),
        ],
      ),
    );
  }
}