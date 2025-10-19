import 'package:flutter/material.dart';
import '../utils/supabase_client.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/custom_bottom_nav.dart';
import '../widgets/recipe_card.dart';
import 'category_recipes_screen.dart';
import 'detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _avatarUrl;
  bool _isLoading = true;
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _popularRecipes = [];
  final Map<String, double> _recipeRatings = {};

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadCategories();
    _loadPopularRecipes();
  }

  Future<void> _loadUserData() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId != null) {
        final response = await supabase
            .from('profiles')
            .select('avatar_url')
            .eq('id', userId)
            .single();
        if (mounted) {
          setState(() {
            _avatarUrl = response['avatar_url'];
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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

  Future<void> _loadPopularRecipes() async {
    try {
      final response = await supabase
          .from('recipes')
          .select('''
            *, 
            profiles!recipes_user_id_fkey(username, avatar_url),
            categories(id, name)
          ''')
          .eq('status', 'approved')
          .order('views_count', ascending: false)
          .limit(10);
      
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
        
        setState(() {
          _popularRecipes = recipes;
        });
      }
    } catch (e) {
      debugPrint('Error loading recipes: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      appBar: const CustomAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // Category Tabs
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
                            itemCount: _categories.length + 1,
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                return _buildCategoryTab('All', true);
                              }
                              final category = _categories[index - 1];
                              return GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => CategoryRecipesScreen(
                                        categoryId: category['id'],
                                        categoryName: category['name'],
                                      ),
                                    ),
                                  );
                                },
                                child: _buildCategoryTab(category['name'], false),
                              );
                            },
                          ),
                  ),
                ),

                // Recipe Grid
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  sliver: _popularRecipes.isEmpty
                      ? SliverToBoxAdapter(
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(40),
                              child: Column(
                                children: [
                                  Icon(Icons.restaurant_menu, size: 60, color: Colors.grey.shade300),
                                  const SizedBox(height: 16),
                                  Text('Belum ada resep', style: TextStyle(fontSize: 16, color: Colors.grey.shade500)),
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
                              final recipe = _popularRecipes[index];
                              return RecipeCard(
                                recipe: recipe,
                                rating: _recipeRatings[recipe['id']],
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => DetailScreen(recipeId: recipe['id'].toString()),
                                    ),
                                  ).then((_) => _loadPopularRecipes());
                                },
                              );
                            },
                            childCount: _popularRecipes.length,
                          ),
                        ),
                ),
                
                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: 0,
        avatarUrl: _avatarUrl,
        onRefresh: _loadPopularRecipes,
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