import 'package:flutter/material.dart';
import '../utils/supabase_client.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/custom_bottom_nav.dart';
import '../widgets/recipe_card.dart';
import '../widgets/theme.dart';
import 'detail_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _collections = [];
  Map<String, dynamic>? _selectedCollection;
  List<Map<String, dynamic>> _collectionRecipes = [];
  bool _isLoading = true;
  String? _userAvatarUrl;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(duration: const Duration(milliseconds: 1200), vsync: this);
    _fadeAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeInOut);
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic));

    _loadUserAvatar();
    _loadCollections();
  }

  @override
  void dispose() {
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

  Future<void> _loadCollections() async {
    setState(() => _isLoading = true);
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        setState(() => _isLoading = false);
        return;
      }

      final response = await supabase
          .from('recipe_boards')
          .select('id, name, description, created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      if (!mounted) return;
      final collections = List<Map<String, dynamic>>.from(response);

      for (var collection in collections) {
        final count = await supabase.from('board_recipes').select('id').eq('board_id', collection['id']).count();
        collection['recipe_count'] = count.count;
      }

      setState(() {
        _collections = collections;
        _isLoading = false;
      });
      _animationController.forward();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      debugPrint('Error loading collections: $e');
    }
  }

  Future<void> _loadCollectionRecipes(String collectionId) async {
    setState(() => _isLoading = true);
    try {
      final response = await supabase
          .from('board_recipes')
          .select('''
            id, recipe_id,
            recipes!inner(*, profiles!recipes_user_id_fkey(username, avatar_url, role), categories(id, name), recipe_tags(tags(id, name)))
          ''')
          .eq('board_id', collectionId)
          .order('added_at', ascending: false);

      if (!mounted) return;
      final recipes = List<Map<String, dynamic>>.from(response);

      setState(() {
        _collectionRecipes = recipes;
        _isLoading = false;
      });
      _animationController.forward(from: 0);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      debugPrint('Error loading collection recipes: $e');
    }
  }

  Future<void> _deleteCollection(Map<String, dynamic> collection) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.delete_outline_rounded, color: Colors.red.shade600, size: 24),
            ),
            const SizedBox(width: 12),
            const Text('Hapus Koleksi'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Apakah Anda yakin ingin menghapus koleksi "${collection['name']}"?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.amber.shade200)),
              child: Row(
                children: [
                  Icon(Icons.warning_rounded, color: Colors.amber.shade700, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Semua resep dalam koleksi ini akan dihapus dari koleksi.', style: TextStyle(fontSize: 12))),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600, foregroundColor: Colors.white),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await supabase.from('board_recipes').delete().eq('board_id', collection['id']);
        await supabase.from('recipe_boards').delete().eq('id', collection['id']);

        if (!mounted) return;
        _showSnackBar('Koleksi berhasil dihapus!', isError: false);
        _loadCollections();
      } catch (e) {
        if (!mounted) return;
        _showSnackBar('Error: $e', isError: true);
      }
    }
  }

  void _showEditCollectionDialog(Map<String, dynamic> collection) {
    final nameController = TextEditingController(text: collection['name']);
    final descController = TextEditingController(text: collection['description'] ?? '');

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(gradient: AppTheme.accentGradient, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.edit_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            const Text('Edit Koleksi', style: AppTheme.headingMedium),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: AppTheme.inputDecoration(AppTheme.primaryCoral),
              child: TextField(
                controller: nameController,
                decoration: AppTheme.buildInputDecoration(
                  hint: 'Nama Koleksi',
                  icon: Icons.collections_bookmark_rounded,
                  iconColor: AppTheme.primaryCoral,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: AppTheme.inputDecoration(AppTheme.primaryOrange),
              child: TextField(
                controller: descController,
                maxLines: 3,
                decoration: AppTheme.buildInputDecoration(
                  hint: 'Deskripsi (opsional)',
                  icon: Icons.description_rounded,
                  iconColor: AppTheme.primaryOrange,
                  maxLines: 3,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: TextButton.styleFrom(foregroundColor: AppTheme.textSecondary),
            child: const Text('Batal'),
          ),
          Container(
            decoration: AppTheme.primaryButtonDecoration,
            child: TextButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text('Nama koleksi harus diisi')));
                  return;
                }
                try {
                  await supabase.from('recipe_boards').update({
                    'name': nameController.text.trim(),
                    'description': descController.text.trim(),
                    'updated_at': DateTime.now().toIso8601String(),
                  }).eq('id', collection['id']);

                  if (!dialogContext.mounted) return;
                  Navigator.pop(dialogContext);
                  if (!mounted) return;
                  _showSnackBar('Koleksi berhasil diperbarui!', isError: false);
                  _loadCollections();
                } catch (e) {
                  _showSnackBar('Error: $e', isError: true);
                }
              },
              child: const Text('Simpan', style: AppTheme.buttonText),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _removeRecipeFromCollection(Map<String, dynamic> boardRecipe) async {
    final recipe = boardRecipe['recipes'];
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hapus dari Koleksi'),
        content: Text('Hapus "${recipe['title']}" dari koleksi ini?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600, foregroundColor: Colors.white),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await supabase.from('board_recipes').delete().eq('id', boardRecipe['id']);
        if (!mounted) return;
        _showSnackBar('Resep dihapus dari koleksi', isError: false);
        _loadCollectionRecipes(_selectedCollection!['id']);
      } catch (e) {
        _showSnackBar('Error: $e', isError: true);
      }
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded, color: Colors.white),
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

  void _showCreateCollectionDialog() {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(gradient: AppTheme.accentGradient, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            const Text('Koleksi Baru', style: AppTheme.headingMedium),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: AppTheme.inputDecoration(AppTheme.primaryCoral),
              child: TextField(
                controller: nameController,
                decoration: AppTheme.buildInputDecoration(
                  hint: 'Nama Koleksi',
                  icon: Icons.collections_bookmark_rounded,
                  iconColor: AppTheme.primaryCoral,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: AppTheme.inputDecoration(AppTheme.primaryOrange),
              child: TextField(
                controller: descController,
                maxLines: 3,
                decoration: AppTheme.buildInputDecoration(
                  hint: 'Deskripsi (opsional)',
                  icon: Icons.description_rounded,
                  iconColor: AppTheme.primaryOrange,
                  maxLines: 3,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: TextButton.styleFrom(foregroundColor: AppTheme.textSecondary),
            child: const Text('Batal'),
          ),
          Container(
            decoration: AppTheme.primaryButtonDecoration,
            child: TextButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text('Nama koleksi harus diisi')));
                  return;
                }
                try {
                  final userId = supabase.auth.currentUser?.id;
                  await supabase.from('recipe_boards').insert({'user_id': userId, 'name': nameController.text.trim(), 'description': descController.text.trim()});
                  if (!dialogContext.mounted) return;
                  Navigator.pop(dialogContext);
                  if (!mounted) return;
                  _loadCollections();
                  _showSnackBar('Koleksi berhasil dibuat!', isError: false);
                } catch (e) {
                  _showSnackBar('Error: $e', isError: true);
                }
              },
              child: const Text('Buat', style: AppTheme.buttonText),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: const CustomAppBar(showBackButton: false),
      body: _isLoading ? _buildLoadingState() : _selectedCollection == null ? _buildCollectionsView() : _buildCollectionRecipesView(),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: 3,
        avatarUrl: _userAvatarUrl,
        onRefresh: () {
          if (_selectedCollection != null) {
            _loadCollectionRecipes(_selectedCollection!['id']);
          } else {
            _loadCollections();
          }
        },
      ),
      floatingActionButton: _selectedCollection == null
          ? FloatingActionButton.extended(
              onPressed: _showCreateCollectionDialog,
              backgroundColor: AppTheme.primaryCoral,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text('Koleksi Baru', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: AppTheme.accentGradient,
              borderRadius: BorderRadius.circular(24),
              boxShadow: AppTheme.buttonShadow,
            ),
            child: const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white), strokeWidth: 3),
          ),
          const SizedBox(height: 24),
          const Text('Memuat koleksi...', style: AppTheme.bodyLarge),
        ],
      ),
    );
  }

  Widget _buildCollectionsView() {
    if (_collections.isEmpty) {
      return _buildEmptyCollectionsState();
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                boxShadow: AppTheme.primaryShadow,
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
                          ),
                          child: const Icon(Icons.collections_bookmark_rounded, color: Colors.white, size: 32),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Koleksi Resep', style: AppTheme.headingLarge),
                              const SizedBox(height: 4),
                              Text('${_collections.length} koleksi tersimpan', style: TextStyle(fontSize: 16, color: Colors.white.withValues(alpha: 0.9), fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.9),
              delegate: SliverChildBuilderDelegate((context, index) => _buildCollectionCard(_collections[index]), childCount: _collections.length),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildCollectionCard(Map<String, dynamic> collection) {
    final recipeCount = collection['recipe_count'] ?? 0;
    final description = collection['description'];

    return GestureDetector(
      onTap: () {
        setState(() => _selectedCollection = collection);
        _loadCollectionRecipes(collection['id']);
      },
      onLongPress: () => _showCollectionOptions(collection),
      child: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.accentGradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppTheme.buttonShadow,
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.collections_bookmark_rounded, color: Colors.white, size: 32),
                  ),
                  const Spacer(),
                  Text(collection['name'] ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (description != null && description.toString().trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.85), fontWeight: FontWeight.w400),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text('$recipeCount resep', style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.9), fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCollectionOptions(Map<String, dynamic> collection) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(gradient: AppTheme.accentGradient, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.collections_bookmark_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(collection['name'] ?? '', style: AppTheme.headingMedium)),
              ],
            ),
            const SizedBox(height: 24),
            _buildOptionTile(Icons.edit_rounded, 'Edit Koleksi', 'Ubah nama dan deskripsi', Colors.blue.shade600, () {
              Navigator.pop(context);
              _showEditCollectionDialog(collection);
            }),
            const SizedBox(height: 12),
            _buildOptionTile(Icons.delete_rounded, 'Hapus Koleksi', 'Hapus koleksi ini secara permanen', Colors.red.shade600, () {
              Navigator.pop(context);
              _deleteCollection(collection);
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile(IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
          ),
          child: Row(
            children: [
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 24)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
                    Text(subtitle, style: AppTheme.bodySmall),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: color),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCollectionRecipesView() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                gradient: AppTheme.accentGradient,
                boxShadow: AppTheme.buttonShadow,
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _selectedCollection = null;
                            _collectionRecipes = [];
                          });
                        },
                        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_selectedCollection!['name'] ?? '', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                            Text('${_collectionRecipes.length} resep', style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.9))),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => _showCollectionOptions(_selectedCollection!),
                        icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_collectionRecipes.isEmpty)
            SliverFillRemaining(
              child: AppTheme.buildEmptyState(
                icon: Icons.restaurant_rounded,
                title: 'Belum ada resep',
                subtitle: 'Tambahkan resep ke koleksi ini',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final boardRecipe = _collectionRecipes[index];
                    final recipe = boardRecipe['recipes'] as Map<String, dynamic>;
                    return Dismissible(
                      key: Key(boardRecipe['id'].toString()),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade500,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 24),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.delete_rounded, color: Colors.white, size: 28),
                            SizedBox(height: 4),
                            Text('Hapus', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      confirmDismiss: (direction) async {
                        return await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            title: const Text('Hapus dari Koleksi'),
                            content: Text('Hapus "${recipe['title']}" dari koleksi ini?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600, foregroundColor: Colors.white),
                                child: const Text('Hapus'),
                              ),
                            ],
                          ),
                        ) ??
                            false;
                      },
                      onDismissed: (direction) async {
                        try {
                          await supabase.from('board_recipes').delete().eq('id', boardRecipe['id']);
                          _showSnackBar('Resep dihapus dari koleksi', isError: false);
                          setState(() => _collectionRecipes.removeAt(index));
                        } catch (e) {
                          _showSnackBar('Error: $e', isError: true);
                          _loadCollectionRecipes(_selectedCollection!['id']);
                        }
                      },
                      child: Stack(
                        children: [
                          RecipeCard(
                            recipe: recipe,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => DetailScreen(recipeId: recipe['id'].toString())),
                              ).then((_) => _loadCollectionRecipes(_selectedCollection!['id']));
                            },
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _removeRecipeFromCollection(boardRecipe),
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade500,
                                    shape: BoxShape.circle,
                                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4)],
                                  ),
                                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  childCount: _collectionRecipes.length,
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildEmptyCollectionsState() {
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
                    child: const Icon(Icons.collections_bookmark_outlined, size: 70, color: AppTheme.primaryCoral),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
            const Text('Belum Ada Koleksi', style: AppTheme.headingMedium, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text('Mulai kumpulkan resep favoritmu!\nBuat koleksi untuk mengorganisir resep.', style: AppTheme.bodyLarge.copyWith(color: AppTheme.textSecondary, height: 1.5), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}