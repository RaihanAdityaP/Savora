import 'package:flutter/material.dart';
import '../utils/supabase_client.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/custom_bottom_nav.dart';
import '../widgets/recipe_card.dart';
import 'detail_screen.dart';
import 'home_screen.dart';

class CategoryRecipesScreen extends StatefulWidget {
  final int categoryId;
  final String categoryName;

  const CategoryRecipesScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
  });

  @override
  State<CategoryRecipesScreen> createState() => _CategoryRecipesScreenState();
}

class _CategoryRecipesScreenState extends State<CategoryRecipesScreen> {
  List<Map<String, dynamic>> _recipes = [];
  List<Map<String, dynamic>> _categories = []; // ✅ Added
  bool _isLoading = true;
  String? _avatarUrl;
  final Map<String, double> _recipeRatings = {};

  @override
  void initState() {
    super.initState();
    _loadCategories(); // ✅ Load categories first
    _loadRecipes();
    _loadUserAvatar();
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
        setState(() {
          _avatarUrl = response['avatar_url'];
        });
      }
    } catch (e) {
      debugPrint('Error loading avatar: $e');
    }
  }

  // ✅ Added method to load all categories
  Future<void> _loadCategories() async {
    try {
      final response = await supabase.from('categories').select().order('name');
      if (mounted) {
        setState(() {
          _categories = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      debugPrint('Error loading categories: $e');
    }
  }

  Future<void> _loadRecipes() async {
    setState(() => _isLoading = true);
    try {
      final response = await supabase
          .from('recipes')
          .select('''
            *, 
            profiles!recipes_user_id_fkey(username, avatar_url),
            categories(id, name)
          ''')
          .eq('category_id', widget.categoryId)
          .eq('status', 'approved')
          .order('created_at', ascending: false);

      if (!mounted) return;
      
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
      
      setState(() {
        _recipes = recipes;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat resep: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      appBar: const CustomAppBar(showBackButton: true),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // Category Tabs - ✅ FIXED: Show all categories
                SliverToBoxAdapter(
                  child: Container(
                    height: 40,
                    margin: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: _categories.isEmpty
                        ? const Center(child: CircularProgressIndicator())
                        : ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            itemCount: _categories.length + 1, // +1 for "All"
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                // "All" category
                                return GestureDetector(
                                  onTap: () {
                                    if (!mounted) return;
                                    Navigator.pushAndRemoveUntil(
                                      context,
                                      MaterialPageRoute(builder: (_) => const HomeScreen()),
                                      (route) => false,
                                    );
                                  },
                                  child: _buildCategoryTab('All', false),
                                );
                              } else {
                                // Other categories
                                final category = _categories[index - 1];
                                final isSelected = category['id'] == widget.categoryId;
                                
                                return GestureDetector(
                                  onTap: () {
                                    if (isSelected) return; // Already on this category
                                    
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => CategoryRecipesScreen(
                                          categoryId: category['id'],
                                          categoryName: category['name'],
                                        ),
                                      ),
                                    );
                                  },
                                  child: _buildCategoryTab(category['name'], isSelected),
                                );
                              }
                            },
                          ),
                  ),
                ),

                // Recipe Grid
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  sliver: _recipes.isEmpty
                      ? SliverToBoxAdapter(
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(40),
                              child: Column(
                                children: [
                                  Icon(Icons.restaurant_menu, size: 60, color: Colors.grey.shade300),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Belum ada resep di kategori ini',
                                    style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : SliverGrid(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.65,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final recipe = _recipes[index];
                              return RecipeCard(
                                recipe: recipe,
                                rating: _recipeRatings[recipe['id']],
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => DetailScreen(recipeId: recipe['id'].toString()),
                                    ),
                                  ).then((_) => _loadRecipes());
                                },
                              );
                            },
                            childCount: _recipes.length,
                          ),
                        ),
                ),
                
                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: 0,
        avatarUrl: _avatarUrl,
        onRefresh: _loadRecipes,
      ),
    );
  }

  Widget _buildCategoryTab(String name, bool isSelected) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFE89A6F) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          name,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : const Color(0xFF5C4033),
            fontStyle: isSelected ? FontStyle.normal : FontStyle.italic,
          ),
        ),
      ),
    );
  }
}