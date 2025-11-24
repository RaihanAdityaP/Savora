import 'package:flutter/material.dart';
import '../../utils/supabase_client.dart';

class AdminRecipesScreen extends StatefulWidget {
  const AdminRecipesScreen({super.key});

  @override
  State<AdminRecipesScreen> createState() => _AdminRecipesScreenState();
}

class _AdminRecipesScreenState extends State<AdminRecipesScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _recipes = [];
  bool _isLoading = true;
  String _filterStatus = 'pending';
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _loadRecipes();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadRecipes() async {
    setState(() => _isLoading = true);
    try {
      final response = await supabase
          .from('recipes')
          .select('''*, profiles!recipes_user_id_fkey(username, avatar_url, role),
            categories(id, name), recipe_tags(tags(id, name))''')
          .eq('status', _filterStatus)
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _recipes = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
        _animationController.forward(from: 0);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _moderateRecipe(String recipeId, String status) async {
    try {
      await supabase.from('recipes').update({
        'status': status,
        'moderated_by': supabase.auth.currentUser?.id,
        'moderated_at': DateTime.now().toIso8601String(),
      }).eq('id', recipeId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(status == 'approved' ? 'Recipe Approved!' : 'Recipe Rejected'),
            backgroundColor: status == 'approved' ? Colors.green : Colors.red,
          ),
        );
        _loadRecipes();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showRecipePreview(Map<String, dynamic> recipe) {
      showBottomSheet(
      context: context,
      backgroundColor: Color(0xFF1A1A1A),
      builder: (ctx) => _RecipePreviewSheet(
        recipe: recipe,
        onApprove: () { Navigator.pop(ctx); _moderateRecipe(recipe['id'], 'approved'); },
        onReject: () { Navigator.pop(ctx); _moderateRecipe(recipe['id'], 'rejected'); },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildFilterSection(),
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.all(60),
                    child: CircularProgressIndicator(color: Color(0xFFFFD700)),
                  )
                else if (_recipes.isEmpty)
                  _buildEmptyState()
                else
                  FadeTransition(opacity: _fadeAnimation, child: _buildRecipeList()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 140,
      pinned: true,
      backgroundColor: Colors.black,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF1A1A1A), Color(0xFF2D2D2D)]),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 50, 24, 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFFF9800), Color(0xFFFFB74D)]),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.restaurant_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 16),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('RECIPE MODERATION', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      Text('Review & Approve', style: TextStyle(color: Color(0xFFFF9800), fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _buildFilterChip('Pending', 'pending'),
          _buildFilterChip('Approved', 'approved'),
          _buildFilterChip('Rejected', 'rejected'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterStatus == value;
    return Expanded(
      child: GestureDetector(
        onTap: () { setState(() => _filterStatus = value); _loadRecipes(); },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            gradient: isSelected ? const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFA500)]) : null,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(label, textAlign: TextAlign.center,
            style: TextStyle(color: isSelected ? Colors.black : Colors.grey, fontWeight: FontWeight.bold, fontSize: 13)),
        ),
      ),
    );
  }

  Widget _buildRecipeList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 80),
      itemCount: _recipes.length,
      itemBuilder: (context, index) => _buildRecipeCard(_recipes[index]),
    );
  }

  Widget _buildRecipeCard(Map<String, dynamic> recipe) {
    final profile = recipe['profiles'];
    final username = profile?['username'] ?? 'Unknown';
    final categoryName = recipe['categories']?['name'] ?? 'Uncategorized';

    return GestureDetector(
      onTap: () => _showRecipePreview(recipe),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: recipe['image_url'] != null
                      ? Image.network(recipe['image_url'], height: 180, width: double.infinity, fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _buildPlaceholder())
                      : _buildPlaceholder(),
                ),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
                      ),
                    ),
                  ),
                ),
                Positioned(top: 12, right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFA500)]),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(categoryName, style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
                Positioned(bottom: 12, left: 12, right: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(recipe['title'] ?? 'Untitled', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white), maxLines: 2),
                      const SizedBox(height: 6),
                      Row(children: [
                        CircleAvatar(radius: 12, backgroundImage: profile?['avatar_url'] != null ? NetworkImage(profile['avatar_url']) : null,
                          child: profile?['avatar_url'] == null ? const Icon(Icons.person, size: 14) : null),
                        const SizedBox(width: 8),
                        Text(username, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (_filterStatus == 'pending')
                    Row(children: [
                      Expanded(child: _actionBtn('APPROVE', Icons.check_circle, Colors.green, () => _moderateRecipe(recipe['id'], 'approved'))),
                      const SizedBox(width: 10),
                      Expanded(child: _actionBtn('REJECT', Icons.cancel, Colors.red, () => _moderateRecipe(recipe['id'], 'rejected'))),
                    ]),
                  if (_filterStatus == 'pending') const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFF151515), borderRadius: BorderRadius.circular(10)),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.visibility, color: Colors.grey.shade500, size: 16),
                      const SizedBox(width: 6),
                      Text('Tap to View Details', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                    ]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionBtn(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
        ]),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(height: 180, color: const Color(0xFF2D2D2D),
      child: Center(child: Icon(Icons.restaurant_menu, size: 50, color: Colors.grey.shade700)));
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(60),
      child: Column(children: [
        Icon(Icons.restaurant, size: 60, color: Colors.grey.shade700),
        const SizedBox(height: 16),
        Text('No Recipes Found', style: TextStyle(fontSize: 18, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
      ]),
    );
  }
}

class _RecipePreviewSheet extends StatelessWidget {
  final Map<String, dynamic> recipe;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _RecipePreviewSheet({required this.recipe, required this.onApprove, required this.onReject});

  @override
  Widget build(BuildContext context) {
    final tags = (recipe['recipe_tags'] as List?)?.map((rt) => rt['tags']).where((t) => t != null).toList() ?? [];

    return DraggableScrollableSheet(
      initialChildSize: 0.9, minChildSize: 0.5, maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A1A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(children: [
            Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade700, borderRadius: BorderRadius.circular(2))),
            Expanded(
              child: ListView(controller: scrollController, padding: const EdgeInsets.all(20), children: [
                Text(recipe['title'] ?? 'Untitled', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 16),
                if (recipe['image_url'] != null)
                  ClipRRect(borderRadius: BorderRadius.circular(16),
                    child: Image.network(recipe['image_url'], height: 200, width: double.infinity, fit: BoxFit.cover)),
                const SizedBox(height: 20),
                Row(children: [
                  _infoChip(Icons.schedule, '${recipe['cooking_time'] ?? 0} min', Colors.orange),
                  const SizedBox(width: 8),
                  _infoChip(Icons.restaurant, '${recipe['servings'] ?? 0} srv', Colors.green),
                  const SizedBox(width: 8),
                  _infoChip(Icons.signal_cellular_alt, recipe['difficulty'] ?? '-', Colors.blue),
                ]),
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(spacing: 6, runSpacing: 6, children: tags.map((t) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFFFFD700).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                    child: Text('#${t['name']}', style: const TextStyle(color: Color(0xFFFFD700), fontSize: 11, fontWeight: FontWeight.bold)),
                  )).toList()),
                ],
                const SizedBox(height: 20),
                _section('Description', recipe['description'] ?? '-'),
                const SizedBox(height: 16),
                _section('Ingredients', recipe['ingredients'] ?? '-'),
                const SizedBox(height: 16),
                _section('Instructions', recipe['instructions'] ?? '-'),
                const SizedBox(height: 80),
              ]),
            ),
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(children: [
                Expanded(child: GestureDetector(onTap: onReject,
                  child: Container(height: 50, decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(14)),
                    child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.cancel, color: Colors.white), SizedBox(width: 8),
                      Text('REJECT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ])))),
                const SizedBox(width: 12),
                Expanded(child: GestureDetector(onTap: onApprove,
                  child: Container(height: 50, decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(14)),
                    child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.check_circle, color: Colors.white), SizedBox(width: 8),
                      Text('APPROVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ])))),
              ]),
            ),
          ]),
        );
      },
    );
  }

  Widget _infoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color), const SizedBox(width: 4),
        Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _section(String title, String content) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFFFD700))),
      const SizedBox(height: 8),
      Container(
        width: double.infinity, padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0xFF252525), borderRadius: BorderRadius.circular(12)),
        child: Text(content, style: TextStyle(color: Colors.grey.shade300, fontSize: 13, height: 1.5)),
      ),
    ]);
  }
}