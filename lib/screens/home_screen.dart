import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/supabase_client.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/custom_bottom_nav.dart';
import '../widgets/recipe_card.dart';
import 'detail_screen.dart';
import 'login_screen.dart';
import 'create_recipe_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  String? _avatarUrl;
  String? _username;
  bool _isLoading = true;
  List<Map<String, dynamic>> _popularRecipes = [];
  final Map<String, double> _recipeRatings = {};
  RealtimeChannel? _bannedChannel;
  
  int _myRecipesCount = 0;
  int _bookmarksCount = 0;
  int _followersCount = 0;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final List<Map<String, String>> _dailyQuotes = [
    {'quote': 'Masakan terbaik dibuat dengan cinta ❤️', 'author': 'Chef Julia Child'},
    {'quote': 'Memasak adalah seni yang bisa dinikmati semua orang 🎨', 'author': 'Gordon Ramsay'},
    {'quote': 'Resep adalah cerita yang berakhir dengan makanan lezat 📖', 'author': 'Pat Conroy'},
    {'quote': 'Kebahagiaan dimulai dari dapur 🍳', 'author': 'Traditional Wisdom'},
    {'quote': 'Setiap chef adalah seniman dengan palet rasa 🎭', 'author': 'Anonymous'},
    {'quote': 'Masak dengan hati, sajikan dengan senyuman 😊', 'author': 'Savora Community'},
  ];

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
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
    
    _loadUserData();
    _loadUserStats();
    _loadPopularRecipes();
    _setupBannedListener();
  }

  @override
  void dispose() {
    _bannedChannel?.unsubscribe();
    _animationController.dispose();
    super.dispose();
  }

  void _setupBannedListener() {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    _bannedChannel = supabase
        .channel('profile_changes_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'profiles',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: userId,
          ),
          callback: (payload) {
            final isBanned = payload.newRecord['is_banned'];
            if (isBanned == true) {
              _handleBannedUser();
            }
          },
        )
        .subscribe();
  }

  Future<void> _handleBannedUser() async {
    try {
      await supabase.auth.signOut();
      
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Akun Anda telah dinonaktifkan oleh administrator.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saat menangani akun yang diblokir: $e');
    }
  }

  Future<void> _loadUserData() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId != null) {
        final response = await supabase
            .from('profiles')
            .select('avatar_url, username')
            .eq('id', userId)
            .single();
        if (mounted) {
          setState(() {
            _avatarUrl = response['avatar_url'];
            _username = response['username'];
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  Future<void> _loadUserStats() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId != null) {
        final response = await supabase
            .from('profiles')
            .select('total_recipes, total_bookmarks, total_followers')
            .eq('id', userId)
            .single();

        if (mounted) {
          setState(() {
            _myRecipesCount = response['total_recipes'] ?? 0;
            _bookmarksCount = response['total_bookmarks'] ?? 0;
            _followersCount = response['total_followers'] ?? 0;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading user stats from profiles: $e');
    }
  }

  Future<void> _loadPopularRecipes() async {
    setState(() => _isLoading = true);
    
    try {
      final response = await supabase
          .from('recipes')
          .select('''
            *, 
            profiles!recipes_user_id_fkey(username, avatar_url, role),
            categories(id, name),
            recipe_tags(tags(id, name))
          ''')
          .eq('status', 'approved')
          .order('views_count', ascending: false)
          .limit(20);
      
      if (mounted) {
        final recipes = List<Map<String, dynamic>>.from(response);
        
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
          _isLoading = false;
        });
        
        _animationController.forward();
      }
    } catch (e) {
      debugPrint('Gagal memuat resep: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getDailyQuote() {
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;
    final index = dayOfYear % _dailyQuotes.length;
    return _dailyQuotes[index]['quote']!;
  }

  String _getDailyQuoteAuthor() {
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;
    final index = dayOfYear % _dailyQuotes.length;
    return _dailyQuotes[index]['author']!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const CustomAppBar(),
      body: _isLoading
          ? _buildLoadingState()
          : _popularRecipes.isEmpty
              ? _buildEnhancedEmptyState()
              : _buildContent(),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: 0,
        avatarUrl: _avatarUrl,
        onRefresh: () {
          _loadUserStats();
          _loadPopularRecipes();
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFE76F51).withValues(alpha: 0.2),
                  const Color(0xFFF4A261).withValues(alpha: 0.2),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: CircularProgressIndicator(
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFE76F51)),
                strokeWidth: 3,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Memuat resep lezat...',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Welcome Card
          SliverToBoxAdapter(
            child: SlideTransition(
              position: _slideAnimation,
              child: Container(
                margin: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF264653),
                      Color(0xFF2A9D8F),
                      Color(0xFFE9C46A),
                      Color(0xFFF4A261),
                      Color(0xFFE76F51),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE76F51).withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Halo, ${_username ?? 'Foodie'}! 👋',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Selamat datang kembali di Savora',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatItem(
                                  icon: Icons.restaurant_rounded,
                                  value: _myRecipesCount.toString(),
                                  label: 'Resep Saya',
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildStatItem(
                                  icon: Icons.bookmark_rounded,
                                  value: _bookmarksCount.toString(),
                                  label: 'Tersimpan',
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildStatItem(
                                  icon: Icons.people_rounded,
                                  value: _followersCount.toString(),
                                  label: 'Pengikut',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    Container(
                      margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.format_quote_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Inspirasi Hari Ini',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withValues(alpha: 0.9),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _getDailyQuote(),
                            style: const TextStyle(
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                              color: Colors.white,
                              height: 1.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '— ${_getDailyQuoteAuthor()}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.85),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Section Title
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 24,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE76F51), Color(0xFFF4A261)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Resep Terpopuler',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF264653),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFE76F51).withValues(alpha: 0.1),
                          const Color(0xFFF4A261).withValues(alpha: 0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFE76F51).withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.local_fire_department_rounded,
                          size: 16,
                          color: Color(0xFFE76F51),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${_popularRecipes.length}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFFE76F51),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Recipe List
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final recipe = _popularRecipes[index];
                  return FadeTransition(
                    opacity: _animationController,
                    child: RecipeCard(
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
                          _loadUserStats();
                          _loadPopularRecipes();
                        });
                      },
                    ),
                  );
                },
                childCount: _popularRecipes.length,
              ),
            ),
          ),
          
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 60),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 1200),
              tween: Tween(begin: 0.0, end: 1.0),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFE76F51).withValues(alpha: 0.15),
                          const Color(0xFFF4A261).withValues(alpha: 0.15),
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE76F51).withValues(alpha: 0.2),
                          blurRadius: 30,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.restaurant_menu_rounded,
                      size: 70,
                      color: Color(0xFFE76F51),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
            
            Text(
              'Belum Ada Resep',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade900,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            
            Text(
              'Jadilah yang pertama membagikan\nresep lezat dan inspirasi kuliner!',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade600,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CreateRecipeScreen(),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFE76F51),
                        Color(0xFFF4A261),
                        Color(0xFFE9C46A),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE76F51).withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add_circle_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Buat Resep Pertama',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}