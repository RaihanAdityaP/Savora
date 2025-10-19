import 'package:flutter/material.dart';
import '../utils/supabase_client.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/custom_bottom_nav.dart';
import 'detail_screen.dart';

class SearchingScreen extends StatefulWidget {
  const SearchingScreen({super.key});

  @override
  State<SearchingScreen> createState() => _SearchingScreenState();
}

class _SearchingScreenState extends State<SearchingScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;
  String _lastSearchQuery = '';
  String? _userAvatarUrl;

  @override
  void initState() {
    super.initState();
    _loadUserAvatar();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
          _userAvatarUrl = response['avatar_url'];
        });
      }
    } catch (e) {
      debugPrint('Error loading user avatar: $e');
    }
  }

  Future<void> _searchRecipes(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      setState(() {
        _searchResults = [];
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _lastSearchQuery = cleanQuery;
    });

    try {
      final safeQuery = cleanQuery.replaceAll('%', '\\%').replaceAll('_', '\\_');
      final response = await supabase
          .from('recipes')
          .select('*, profiles!recipes_user_id_fkey(username, avatar_url)')
          .ilike('title', '%$safeQuery%')
          .eq('status', 'approved')
          .order('views_count', ascending: false)
          .limit(20);

      if (mounted) {
        setState(() {
          _searchResults = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      debugPrint('Error searching recipes: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      appBar: const CustomAppBar(showBackButton: true),
      body: Column(
        children: [
          // Search Bar
          Container(
            margin: const EdgeInsets.all(20),
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
                hintText: 'Search recipe...',
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
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (_searchController.text == value) {
                    _searchRecipes(value);
                  }
                });
              },
            ),
          ),
          // Results
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _searchResults.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search, size: 60, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              _lastSearchQuery.isNotEmpty
                                  ? 'Tidak ditemukan resep "$_lastSearchQuery"'
                                  : 'Cari resep favoritmu',
                              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final recipe = _searchResults[index];
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => DetailScreen(recipeId: recipe['id'].toString()),
                                ),
                              );
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFFFE0B2), width: 1),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      width: 60,
                                      height: 60,
                                      color: Colors.grey.shade200,
                                      child: recipe['image_url'] != null
                                          ? Image.network(
                                              recipe['image_url'],
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) =>
                                                  Icon(Icons.fastfood, size: 30, color: Colors.grey.shade400),
                                            )
                                          : Icon(Icons.fastfood, size: 30, color: Colors.grey.shade400),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          recipe['title'] ?? 'Untitled Recipe',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF5C4033),
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Container(
                                              width: 16,
                                              height: 16,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: Colors.grey.shade300,
                                              ),
                                              child: ClipOval(
                                                child: recipe['profiles']?['avatar_url'] != null
                                                    ? Image.network(
                                                        recipe['profiles']['avatar_url'],
                                                        fit: BoxFit.cover,
                                                        errorBuilder: (context, error, stackTrace) => Icon(
                                                          Icons.person,
                                                          size: 10,
                                                          color: Colors.grey.shade600,
                                                        ),
                                                      )
                                                    : Icon(Icons.person, size: 10, color: Colors.grey.shade600),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              recipe['profiles']?['username'] ?? 'Anonymous',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
                                ],
                              ),
                            ),
                          );
                        },
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
}