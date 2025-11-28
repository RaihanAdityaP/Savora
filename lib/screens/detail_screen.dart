import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../utils/supabase_client.dart';
import '../widgets/custom_bottom_nav.dart';
import '../widgets/theme.dart';
import 'home_screen.dart';
import 'edit_recipe_screen.dart';
import 'profile_screen.dart';
import 'searching_screen.dart';
import 'ai_assistant_screen.dart'; 

class DetailScreen extends StatefulWidget {
  final String recipeId;
  const DetailScreen({super.key, required this.recipeId});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> with TickerProviderStateMixin {
  Map<String, dynamic>? _recipe;
  bool _isLoading = true;
  bool _isFavorite = false;
  int? _userRating;
  double? _averageRating;
  int? _ratingCount;
  List<Map<String, dynamic>> _comments = [];
  List<String> _tags = [];
  final TextEditingController _commentController = TextEditingController();
  String? _userAvatarUrl;
  String? _currentUserId;
  String? _currentUserRole;
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isVideoInitializing = false;

  // Untuk animasi tombol share
  late AnimationController _shareButtonAnimationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _currentUserId = supabase.auth.currentUser?.id;
    _shareButtonAnimationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _shareButtonAnimationController, curve: Curves.easeInOut),
    );
    _initializeScreen();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _chewieController?.dispose();
    _videoPlayerController?.dispose();
    _shareButtonAnimationController.dispose();
    super.dispose();
  }

  Future<void> _initializeScreen() async {
    await Future.wait([
      _loadRecipe(),
      _incrementViews(),
      _checkIfFavorite(),
      _loadUserRating(),
      _loadComments(),
      _loadCurrentUserProfile(),
      _loadRecipeTags(),
    ]);
  }

  Future<void> _initializeVideoPlayer(String videoUrl) async {
    if (_isVideoInitializing) return;
    setState(() => _isVideoInitializing = true);
    try {
      _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      await _videoPlayerController!.initialize();
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: false,
        looping: false,
        aspectRatio: _videoPlayerController!.value.aspectRatio,
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
                const SizedBox(height: 16),
                Text('Gagal memuat video', style: TextStyle(color: Colors.red.shade600)),
              ],
            ),
          );
        },
      );
      if (mounted) setState(() => _isVideoInitializing = false);
    } catch (e) {
      debugPrint('Error initializing video: $e');
      if (mounted) setState(() => _isVideoInitializing = false);
    }
  }

  Future<void> _loadCurrentUserProfile() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId != null) {
        final response = await supabase.from('profiles').select('avatar_url, role').eq('id', userId).single();
        if (!mounted) return;
        setState(() { 
          _userAvatarUrl = response['avatar_url']; 
          _currentUserRole = response['role']; 
        });
      }
    } catch (e) {
      debugPrint('Error loading user profile: $e');
    }
  }

  Future<void> _loadRecipe() async {
    try {
      Map<String, dynamic>? response = await supabase
          .from('recipes')
          .select('*, profiles!recipes_user_id_fkey(username, avatar_url, role, is_premium)')
          .eq('id', widget.recipeId)
          .maybeSingle();
      if (response == null) {
        if (!mounted) return;
        setState(() { _isLoading = false; _recipe = null; });
        return;
      }
      final ratingResponse = await supabase
          .from('recipe_ratings')
          .select('rating')
          .eq('recipe_id', widget.recipeId);
      if (!mounted) return;
      setState(() {
        _recipe = response;
        _ratingCount = ratingResponse.length;
        if (_ratingCount! > 0) {
          final total = ratingResponse.fold(0, (sum, r) => sum + (r['rating'] as int));
          _averageRating = total / _ratingCount!;
        }
        _isLoading = false;
      });
      if (_recipe!['video_url'] != null) _initializeVideoPlayer(_recipe!['video_url']);
    } catch (e) {
      if (!mounted) return;
      setState(() { _isLoading = false; _recipe = null; });
      _showSnackBar('Error loading recipe', isError: true);
    }
  }

  Future<void> _incrementViews() async {
    try {
      final current = await supabase
          .from('recipes')
          .select('views_count')
          .eq('id', widget.recipeId)
          .single();
      await supabase
          .from('recipes')
          .update({'views _count': (current['views_count'] ?? 0) + 1})
          .eq('id', widget.recipeId);
    } catch (e) {
      debugPrint('Error incrementing views: $e');
    }
  }

  Future<void> _checkIfFavorite() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId != null) {
        final response = await supabase
            .from('board_recipes')
            .select('id, recipe_boards!inner(user_id)')
            .eq('recipe_id', widget.recipeId)
            .eq('recipe_boards.user_id', userId)
            .maybeSingle();
        if (!mounted) return;
        setState(() => _isFavorite = response != null);
      }
    } catch (e) {
      debugPrint('Error checking favorite: $e');
    }
  }

  Future<void> _loadUserRating() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId != null) {
        final response = await supabase
            .from('recipe_ratings')
            .select('rating')
            .eq('user_id', userId)
            .eq('recipe_id', widget.recipeId)
            .maybeSingle();
        if (!mounted) return;
        setState(() => _userRating = response?['rating'] as int?);
      }
    } catch (e) {
      debugPrint('Error loading user rating: $e');
    }
  }

  Future<void> _loadRecipeTags() async {
    try {
      final response = await supabase
          .from('recipe_tags')
          .select('tags(name)')
          .eq('recipe_id', widget.recipeId);
      if (!mounted) return;
      final tags = List<Map<String, dynamic>>.from(response);
      setState(() => _tags = tags.map((t) => t['tags']['name'] as String).toList());
    } catch (e) {
      debugPrint('Error loading tags: $e');
    }
  }

// ============ SHARE FEATURE ============

  String _generateShareText() {
    final title = _recipe?['title'] ?? 'Resep Tanpa Judul';
    final profile = _recipe?['profiles'];
    final username = profile?['username'] ?? 'Anonymous';
    final time = _recipe?['cooking_time'] ?? '?';
    final servings = _recipe?['servings'] ?? '?';
    final difficulty = (_recipe?['difficulty'] ?? 'mudah').toUpperCase();
    final rating = _averageRating != null ? '${_averageRating!.toStringAsFixed(1)}/5' : '?/5';

    return '''
🍳 RESEP DARI SAVORA 🍳
📋 Judul: $title
👨‍🍳 Chef: $username
⏱️ Waktu: $time menit
🍽️ Porsi: $servings porsi
📊 Tingkat: $difficulty
⭐ Rating: $rating
📝 Deskripsi:
${_recipe?['description'] ?? 'Tidak ada deskripsi.'}

Lihat resep lengkap:
https://savora-nine.vercel.app/recipe/${widget.recipeId}
'''.trim();
  }

  // Generate Universal Link yang support deep link + web fallback
  String _generateUniversalLink() {
    return 'https://savora-nine.vercel.app/recipe/${widget.recipeId}';
  }

  Future<void> _shareLink() async {
    // Share universal link yang akan:
    // 1. Buka app jika terinstal (via deep link di manifest)
    // 2. Buka web jika tidak terinstal
    await Share.share(
      _generateUniversalLink(),
      subject: 'Resep dari Savora: ${_recipe?['title']}',
    );
  }

  Future<void> _shareDetail() async {
    await Share.share(
      _generateShareText(),
      subject: 'Resep dari Savora: ${_recipe?['title']}',
    );
  }

  Future<void> _shareImage() async {
    final imageUrl = _recipe?['image_url'];
    if (imageUrl == null) return;

    try {
      final uri = Uri.parse(imageUrl);
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final fileName = '${widget.recipeId}.jpg';
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(response.bodyBytes);

        await Share.shareXFiles(
          [XFile(file.path)],
          text: '''${_recipe?['title'] ?? 'Resep Savora'} 🍳

Dari Savora - Komunitas Resep Indonesia

Lihat resep lengkap:
${_generateUniversalLink()}''',
          subject: 'Resep dari Savora: ${_recipe?['title']}',
        );
      } else {
        _showSnackBar('Gagal mengunduh gambar', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error saat berbagi gambar: $e', isError: true);
    }
  }

  Future<void> _shareToWhatsApp() async {
    final text = _generateShareText();
    
    // WhatsApp akan otomatis detect link dan bisa buka app atau web
    try {
      await Share.share(
        text,
        subject: 'Resep dari Savora: ${_recipe?['title']}',
      );
    } catch (e) {
      _showSnackBar('Error saat berbagi ke WhatsApp: $e', isError: true);
    }
  }

  // Share dengan custom app chooser
  Future<void> _shareWithChooser() async {
    final text = '''${_recipe?['title'] ?? 'Resep Savora'} 🍳

${_recipe?['description'] ?? ''}

Lihat resep lengkap:
${_generateUniversalLink()}''';

    await Share.share(
      text,
      subject: 'Resep dari Savora: ${_recipe?['title']}',
    );
  }

  // Copy link to clipboard
  Future<void> _copyLinkToClipboard() async {
    await Clipboard.setData(ClipboardData(text: _generateUniversalLink()));
    _showSnackBar('Link berhasil disalin! 🔗', isError: false);
  }

  Widget _buildShareOption({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          onTap();
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showShareBottomSheet() async {
    _shareButtonAnimationController.forward().then((_) {
      _shareButtonAnimationController.reverse();
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: DraggableScrollableSheet(
            maxChildSize: 0.7,
            minChildSize: 0.4,
            initialChildSize: 0.55,
            expand: false,
            builder: (_, controller) {
              return Column(
                children: [
                  // Drag Handle
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade400,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                  
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Bagikan Resep',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(Icons.close, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  
                  // Share Options
                  Expanded(
                    child: ListView(
                      controller: controller,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      children: [
                        _buildShareOption(
                          icon: Icons.link_rounded,
                          color: Colors.blue,
                          title: 'Share Link',
                          subtitle: 'Bagikan link (otomatis buka app/web)',
                          onTap: _shareLink,
                        ),
                        _buildShareOption(
                          icon: Icons.content_copy_rounded,
                          color: Colors.blueGrey,
                          title: 'Copy Link',
                          subtitle: 'Salin link ke clipboard',
                          onTap: _copyLinkToClipboard,
                        ),
                        _buildShareOption(
                          icon: Icons.description_rounded,
                          color: AppTheme.primaryCoral,
                          title: 'Share Detail Lengkap',
                          subtitle: 'Bagikan dengan deskripsi lengkap',
                          onTap: _shareDetail,
                        ),
                        if (_recipe?['image_url'] != null)
                          _buildShareOption(
                            icon: Icons.image_rounded,
                            color: Colors.green,
                            title: 'Share dengan Gambar',
                            subtitle: 'Bagikan gambar + caption',
                            onTap: _shareImage,
                          ),
                        _buildShareOption(
                          icon: Icons.chat,
                          color: const Color(0xFF25D366),
                          title: 'Share ke WhatsApp',
                          subtitle: 'Kirim langsung ke WhatsApp',
                          onTap: _shareToWhatsApp,
                        ),
                        _buildShareOption(
                          icon: Icons.share_rounded,
                          color: Colors.purple,
                          title: 'Share Lainnya',
                          subtitle: 'Pilih aplikasi untuk berbagi',
                          onTap: _shareWithChooser,
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  // ============ END SHARE FEATURE ============

  Future<void> _showBoardSelector() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        _showSnackBar('Silakan login terlebih dahulu', isError: true);
        return;
      }
      final boards = await supabase
          .from('recipe_boards')
          .select('id, name, description')
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (context) => _buildBoardSelectorSheet(List<Map<String, dynamic>>.from(boards), userId),
      );
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    }
  }

  Widget _buildBoardSelectorSheet(List<Map<String, dynamic>> boards, String userId) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
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
              const Expanded(child: Text('Simpan ke Koleksi', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textPrimary))),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(16), boxShadow: AppTheme.buttonShadow),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Navigator.pop(context);
                  _showCreateBoardDialog(userId);
                },
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(child: Text('Buat Koleksi Baru', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white))),
                      const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (boards.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(16)),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.collections_bookmark_outlined, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text('Belum ada koleksi', style: TextStyle(fontSize: 16, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: boards.length,
                itemBuilder: (context, index) {
                  final board = boards[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.primaryCoral.withValues(alpha: 0.2), width: 1.5),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          _addToBoard(board['id'], board['name']);
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [AppTheme.primaryCoral.withValues(alpha: 0.2), AppTheme.primaryOrange.withValues(alpha: 0.1)]),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.collections_bookmark_rounded, color: AppTheme.primaryCoral, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(board['name'] ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                                    if (board['description'] != null && board['description'].toString().isNotEmpty)
                                      Text(board['description'], style: TextStyle(fontSize: 12, color: Colors.grey.shade600), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.primaryCoral),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  void _showCreateBoardDialog(String userId) {
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
            const Text('Koleksi Baru', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.grey.shade200, width: 1.5)),
              child: TextField(
                controller: nameController,
                decoration: InputDecoration(
                  hintText: 'Nama Koleksi',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  prefixIcon: const Icon(Icons.collections_bookmark_rounded, color: AppTheme.primaryCoral),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.grey.shade200, width: 1.5)),
              child: TextField(
                controller: descController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Deskripsi (opsional)',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  prefixIcon: const Padding(padding: EdgeInsets.only(bottom: 60), child: Icon(Icons.description_rounded, color: AppTheme.primaryOrange)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: TextButton.styleFrom(foregroundColor: Colors.grey.shade600),
            child: const Text('Batal', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          Container(
            decoration: BoxDecoration(gradient: AppTheme.accentGradient, borderRadius: BorderRadius.circular(12)),
            child: TextButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text('Nama koleksi harus diisi')));
                  return;
                }
                try {
                  await supabase.from('recipe_boards').insert({
                    'user_id': userId,
                    'name': nameController.text.trim(),
                    'description': descController.text.trim(),
                  });
                  if (!dialogContext.mounted) return;
                  Navigator.pop(dialogContext);
                  if (!mounted) return;
                  _showSnackBar('Koleksi berhasil dibuat!', isError: false);
                  _showBoardSelector();
                } catch (e) {
                  _showSnackBar('Error: $e', isError: true);
                }
              },
              child: const Text('Buat', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addToBoard(String boardId, String boardName) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;
      final existing = await supabase
          .from('board_recipes')
          .select()
          .eq('board_id', boardId)
          .eq('recipe_id', widget.recipeId)
          .maybeSingle();
      if (existing != null) {
        if (!mounted) return;
        _showSnackBar('Resep sudah ada di koleksi ini', isError: true);
        return;
      }
      await supabase.from('board_recipes').insert({'board_id': boardId, 'recipe_id': widget.recipeId});
      if (mounted) {
        setState(() => _isFavorite = true);
        _showSnackBar('Ditambahkan ke "$boardName"', isError: false);
      }
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    }
  }

  Future<void> _submitRating(int rating) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        _showSnackBar('Silakan login untuk memberi rating', isError: true);
        return;
      }
      final existingRating = await supabase
          .from('recipe_ratings')
          .select()
          .eq('user_id', userId)
          .eq('recipe_id', widget.recipeId)
          .maybeSingle();
      if (existingRating != null) {
        await supabase.from('recipe_ratings').update({'rating': rating}).eq('user_id', userId).eq('recipe_id', widget.recipeId);
      } else {
        await supabase.from('recipe_ratings').insert({'recipe_id': widget.recipeId, 'user_id': userId, 'rating': rating});
      }
      if (!mounted) return;
      setState(() => _userRating = rating);
      await _loadRecipe();
      _showSnackBar(existingRating != null ? 'Rating diperbarui!' : 'Rating dikirim!', isError: false);
    } catch (e) {
      _showSnackBar('Gagal mengirim rating', isError: true);
    }
  }

  Future<void> _loadComments() async {
    try {
      final response = await supabase
          .from('comments')
          .select('*, profiles!comments_user_id_fkey(username, avatar_url)')
          .eq('recipe_id', widget.recipeId)
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(() => _comments = List<Map<String, dynamic>>.from(response));
    } catch (e) {
      debugPrint('Error loading comments: $e');
    }
  }

  Future<void> _postComment() async {
    if (_commentController.text.trim().isEmpty) {
      _showSnackBar('Komentar tidak boleh kosong', isError: true);
      return;
    }
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        _showSnackBar('Silakan login untuk berkomentar', isError: true);
        return;
      }
      await supabase.from('comments').insert({
        'recipe_id': widget.recipeId,
        'user_id': userId,
        'content': _commentController.text.trim(),
      });
      _commentController.clear();
      await _loadComments();
      _showSnackBar('Komentar berhasil dikirim!', isError: false);
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    }
  }

  Future<void> _editComment(String commentId, String newContent) async {
    if (newContent.trim().isEmpty) return;
    try {
      await supabase.from('comments').update({
        'content': newContent.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', commentId);
      await _loadComments();
      _showSnackBar('Komentar berhasil diperbarui!', isError: false);
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    }
  }

  Future<void> _deleteComment(String commentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hapus Komentar'),
        content: const Text('Apakah Anda yakin ingin menghapus komentar ini?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await supabase.from('comments').delete().eq('id', commentId);
        await _loadComments();
        _showSnackBar('Komentar berhasil dihapus!', isError: false);
      } catch (e) {
        _showSnackBar('Error: $e', isError: true);
      }
    }
  }

  Future<void> _deleteRecipe() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hapus Resep'),
        content: const Text('Apakah Anda yakin ingin menghapus resep ini? Tindakan ini tidak dapat dibatalkan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await supabase.from('comments').delete().eq('recipe_id', widget.recipeId);
        await supabase.from('recipe_ratings').delete().eq('recipe_id', widget.recipeId);
        await supabase.from('favorites').delete().eq('recipe_id', widget.recipeId);
        await supabase.from('recipe_tags').delete().eq('recipe_id', widget.recipeId);
        await supabase.from('board_recipes').delete().eq('recipe_id', widget.recipeId);
        await supabase.from('recipes').delete().eq('id', widget.recipeId);
        if (!mounted) return;
        _showSnackBar('Resep berhasil dihapus!', isError: false);
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
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
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  String _formatDateTime(String dateTimeStr) {
    try {
      final dateTime = DateTime.parse(dateTimeStr).toLocal();
      final now = DateTime.now();
      final difference = now.difference(dateTime);
      if (difference.inDays > 7) return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
      if (difference.inDays > 0) return '${difference.inDays} hari lalu';
      if (difference.inHours > 0) return '${difference.inHours} jam lalu';
      if (difference.inMinutes > 0) return '${difference.inMinutes} menit lalu';
      return 'Baru saja';
    } catch (e) {
      return dateTimeStr;
    }
  }

  void _showEditCommentDialog(String commentId, String currentContent) {
    final controller = TextEditingController(text: currentContent);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Ulasan'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Edit ulasan Anda',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _editComment(commentId, controller.text);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryCoral,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

@override
Widget build(BuildContext context) {
  final isOwner = _currentUserId == _recipe?['user_id'].toString();
  final isCurrentUserAdmin = _currentUserRole == 'admin';
  final canEdit = isOwner || isCurrentUserAdmin;
  return Scaffold(
    backgroundColor: AppTheme.backgroundLight,
    body: _isLoading
        ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryCoral))
        : _recipe == null
            ? const Center(child: Text('Resep tidak ditemukan'))
            : CustomScrollView(
                slivers: [
                  _buildAppBar(),
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _buildHeroCard(canEdit),
                        const SizedBox(height: 16),
                        _buildContentCard(),
                        const SizedBox(height: 16),
                        _buildInteractionCard(),
                        const SizedBox(height: 100),
                      ]),
                    ),
                  ),
                ],
              ),
    bottomNavigationBar: CustomBottomNav(currentIndex: 0, avatarUrl: _userAvatarUrl, onRefresh: _loadRecipe),

    // 💡 TAMBAHKAN INI: AI Assistant FAB
    floatingActionButton: _recipe != null
        ? FloatingActionButton.extended(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AIAssistantScreen(
                    recipeContext: (_recipe!['title'] ?? '') +
                       '\n${_recipe!['ingredients'] is List ? (_recipe!['ingredients'] as List).map((i) => i is Map ? i['name'] ?? i.toString() : i.toString()).join(', ') : ''}',
                  ),
                ),
              );
            },
            icon: const Icon(Icons.psychology_rounded),
            label: const Text('Chef AI'),
            backgroundColor: AppTheme.primaryCoral,
          )
        : null,
    floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
  );
}

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 180,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 60, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
                        ),
                        child: const Icon(Icons.restaurant_rounded, color: Colors.white, size: 32),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Detail Resep', style: AppTheme.headingLarge),
                            SizedBox(height: 4),
                            Text('Informasi lengkap resep', style: TextStyle(fontSize: 14, color: Colors.white70)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: AppTheme.primaryCoral.withValues(alpha: 0.3), blurRadius: 8)],
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.primaryDark),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: AppTheme.primaryCoral.withValues(alpha: 0.3), blurRadius: 8)],
            ),
            child: IconButton(
              icon: Icon(
                _isFavorite ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                color: _isFavorite ? AppTheme.primaryCoral : AppTheme.primaryDark,
              ),
              onPressed: _showBoardSelector,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactInfoChip(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildHeroCard(bool canEdit) {
    final profile = _recipe!['profiles'];
    final username = profile?['username'] ?? 'Anonymous';
    final avatarUrl = profile?['avatar_url'];
    final role = profile?['role'] ?? 'user';
    final isPremium = profile?['is_premium'] ?? false;
    final oderId = _recipe!['user_id'];
    return Container(
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            child: Stack(
              children: [
                _recipe!['image_url'] != null
                    ? Image.network(
                        _recipe!['image_url'],
                        width: double.infinity,
                        height: 280,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _buildPlaceholderImage(),
                      )
                    : _buildPlaceholderImage(),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 140,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.4),
                          Colors.black.withValues(alpha: 0.8),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 20,
                  left: 20,
                  right: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _recipe!['title'] ?? 'Untitled',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.2,
                          shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildCompactInfoChip('${_recipe!['cooking_time'] ?? 15} min', Icons.access_time_rounded),
                          const SizedBox(width: 8),
                          _buildCompactInfoChip('${_recipe!['servings'] ?? 1} porsi', Icons.restaurant_menu_rounded),
                          const SizedBox(width: 8),
                          _buildCompactInfoChip((_recipe!['difficulty'] ?? 'mudah').toUpperCase(), Icons.bar_chart_rounded),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_recipe!['description'] != null && _recipe!['description'].toString().isNotEmpty) ...[
                  AppTheme.buildSectionHeader('Deskripsi', Icons.description_rounded),
                  const SizedBox(height: 12),
                  Text(
                    _recipe!['description'],
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.6),
                  ),
                  const SizedBox(height: 20),
                  Divider(color: Colors.grey.shade200),
                  const SizedBox(height: 20),
                ],
                GestureDetector(
                  onTap: oderId != null ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: oderId.toString()))) : null,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryYellow.withValues(alpha: 0.2),
                          AppTheme.primaryOrange.withValues(alpha: 0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.primaryYellow.withValues(alpha: 0.3), width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(colors: AppTheme.getRoleGradient(role)),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 4))],
                          ),
                          child: ClipOval(
                            child: avatarUrl != null
                                ? Image.network(avatarUrl, fit: BoxFit.cover)
                                : const Icon(Icons.person, color: Colors.white, size: 28),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(username, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: role == 'admin'
                                      ? const Color(0xFFFFD700)
                                      : isPremium
                                          ? const Color(0xFF6C63FF)
                                          : Colors.grey.shade400,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  role == 'admin'
                                      ? 'ADMIN'
                                      : isPremium
                                          ? 'SAVORA CHEF'
                                          : 'PENGGUNA',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (oderId != null)
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.7), shape: BoxShape.circle),
                            child: Icon(Icons.chevron_right_rounded, color: Colors.grey.shade700, size: 20),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(child: _buildInfoDetailCard('${_recipe!['cooking_time'] ?? 15}', 'Menit', Icons.access_time_rounded, AppTheme.primaryTeal)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildInfoDetailCard('${_recipe!['servings'] ?? 1}', 'Porsi', Icons.restaurant_menu_rounded, AppTheme.primaryDark)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildInfoDetailCard((_recipe!['difficulty'] ?? 'mudah').toUpperCase(), 'Tingkat', Icons.bar_chart_rounded, AppTheme.primaryOrange)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildInfoDetailCard(_recipe!['calories'] != null ? '${_recipe!['calories']}' : 'N/A', 'Kalori', Icons.local_fire_department_rounded, AppTheme.primaryCoral)),
                  ],
                ),
                const SizedBox(height: 24),
                _buildActionButtons(canEdit),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoDetailCard(String value, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color.withValues(alpha: 0.1), color.withValues(alpha: 0.05)]),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Column(
        children: [
          Icon(icon, size: 28, color: color),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      width: double.infinity,
      height: 280,
      decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
      child: const Icon(Icons.restaurant_rounded, size: 80, color: Colors.white),
    );
  }

  Widget _buildActionButtons(bool canEdit) {
    return Row(
      children: [
        if (canEdit) ...[
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EditRecipeScreen(recipe: _recipe!))).then((_) => _loadRecipe()),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryDark,
                side: BorderSide(color: AppTheme.primaryDark.withValues(alpha: 0.3), width: 2),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.edit_rounded, size: 18),
              label: const Text('Edit', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _deleteRecipe,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade500,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.delete_rounded, size: 18),
              label: const Text('Hapus', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ] else ...[
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: _isFavorite ? AppTheme.orangeGradient : AppTheme.accentGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ElevatedButton.icon(
                onPressed: _showBoardSelector,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: Icon(_isFavorite ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, size: 20),
                label: Text(_isFavorite ? 'Tersimpan' : 'Simpan', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
        const SizedBox(width: 8),
        // Share Button with Animation
        ScaleTransition(
          scale: _scaleAnimation,
          child: GestureDetector(
            onTapDown: (_) => _shareButtonAnimationController.forward(),
            onTapUp: (_) => _shareButtonAnimationController.reverse(),
            onTapCancel: () => _shareButtonAnimationController.reverse(),
            child: Container(
              decoration: BoxDecoration(
                gradient: AppTheme.accentGradient,
                shape: BoxShape.circle,
                boxShadow: AppTheme.buttonShadow,
              ),
              child: IconButton(
                onPressed: _showShareBottomSheet,
                icon: const Icon(Icons.share_rounded, color: Colors.white, size: 28),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContentCard() {
    return Container(
      decoration: AppTheme.cardDecoration,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_recipe!['video_url'] != null) ...[
            AppTheme.buildSectionHeader('Video Tutorial', Icons.videocam_rounded),
            const SizedBox(height: 16),
            _buildVideoPlayer(),
            const SizedBox(height: 28),
            const Divider(height: 1),
            const SizedBox(height: 28),
          ] else ...[
            AppTheme.buildSectionHeader('Video Tutorial', Icons.videocam_rounded),
            const SizedBox(height: 16),
            AppTheme.buildEmptyState(icon: Icons.videocam_off_rounded, title: 'User tidak mengunggah video'),
            const SizedBox(height: 28),
            const Divider(height: 1),
            const SizedBox(height: 28),
          ],
          AppTheme.buildSectionHeader('Bahan-bahan', Icons.restaurant_menu_rounded),
          const SizedBox(height: 16),
          _buildIngredientsList(),
          const SizedBox(height: 28),
          const Divider(height: 1),
          const SizedBox(height: 28),
          AppTheme.buildSectionHeader('Langkah-langkah', Icons.format_list_numbered_rounded),
          const SizedBox(height: 16),
          _buildStepsList(),
          const SizedBox(height: 28),
          const Divider(height: 1),
          const SizedBox(height: 28),
          AppTheme.buildSectionHeader('Tags', Icons.label_rounded),
          const SizedBox(height: 16),
          _buildTagsList(),
        ],
      ),
    );
  }

  Widget _buildVideoPlayer() {
    if (_isVideoInitializing) {
      return Container(
        height: 200,
        decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(12)),
        child: const Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    if (_chewieController != null && _videoPlayerController != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: _videoPlayerController!.value.aspectRatio,
          child: Chewie(controller: _chewieController!),
        ),
      );
    }
    return Container(
      height: 200,
      decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(12)),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
            const SizedBox(height: 12),
            Text('Gagal memuat video', style: TextStyle(color: Colors.red.shade400)),
          ],
        ),
      ),
    );
  }

  Widget _buildIngredientsList() {
    final ingredients = _recipe!['ingredients'] as List<dynamic>?;
    if (ingredients == null || ingredients.isEmpty) return AppTheme.buildEmptyState(icon: Icons.restaurant_menu_rounded, title: 'Belum ada bahan');
    return Column(
      children: ingredients.asMap().entries.map((entry) {
        final index = entry.key;
        final ingredient = entry.value;
        String name;
        String? quantity;
        if (ingredient is String) {
          name = ingredient;
        } else if (ingredient is Map && ingredient.containsKey('name')) {
          name = ingredient['name'].toString();
          quantity = ingredient['quantity']?.toString();
        } else {
          return const SizedBox.shrink();
        }
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: AppTheme.inputDecoration(AppTheme.primaryYellow),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(gradient: AppTheme.accentGradient, shape: BoxShape.circle),
                child: Center(child: Text('${index + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white))),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(name, style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary, fontWeight: FontWeight.w500))),
              if (quantity != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      AppTheme.primaryOrange.withValues(alpha: 0.3),
                      AppTheme.primaryYellow.withValues(alpha: 0.2),
                    ]),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(quantity, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryCoral)),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStepsList() {
    final steps = _recipe!['steps'] as List<dynamic>?;
    if (steps == null || steps.isEmpty) return AppTheme.buildEmptyState(icon: Icons.format_list_numbered_rounded, title: 'Belum ada langkah');
    return Column(
      children: List.generate(steps.length, (index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              AppTheme.primaryCoral.withValues(alpha: 0.1),
              AppTheme.primaryOrange.withValues(alpha: 0.05),
            ]),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.primaryCoral.withValues(alpha: 0.2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(gradient: AppTheme.accentGradient, borderRadius: BorderRadius.circular(10)),
                child: Center(child: Text('${index + 1}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white))),
              ),
              const SizedBox(width: 14),
              Expanded(child: Text(steps[index].toString(), style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary, height: 1.5))),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildTagsList() {
    if (_tags.isEmpty) return AppTheme.buildEmptyState(icon: Icons.label_rounded, title: 'Belum ada tag');
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _tags.map((tag) {
        int? tagId;
        final recipeTags = _recipe!['recipe_tags'] as List<dynamic>?;
        if (recipeTags != null) {
          for (var rt in recipeTags) {
            if (rt['tags']?['name'] == tag) {
              tagId = rt['tags']?['id'];
              break;
            }
          }
        }
        return GestureDetector(
          onTap: () {
            if (tagId != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SearchingScreen(
                    initialTagId: tagId,
                    initialTagName: tag,
                  ),
                ),
              );
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: AppTheme.selectedTagDecoration,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.tag_rounded, size: 14, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  tag,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInteractionCard() {
    return Container(
      decoration: AppTheme.cardDecoration,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTheme.buildSectionHeader('Rating & Ulasan', Icons.star_rounded),
          const SizedBox(height: 20),
          if (_averageRating != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  AppTheme.primaryYellow.withValues(alpha: 0.2),
                  AppTheme.primaryOrange.withValues(alpha: 0.1),
                ]),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.primaryYellow.withValues(alpha: 0.4), width: 1.5),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: Icon(Icons.star_rounded, color: AppTheme.primaryYellow, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_averageRating!.toStringAsFixed(1), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                      Text('dari $_ratingCount rating', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.grey.shade100, Colors.grey.shade50]),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.star_outline_rounded, color: Colors.grey.shade400, size: 28),
                  const SizedBox(width: 12),
                  Text('Belum ada rating', style: TextStyle(color: Colors.grey.shade500)),
                ],
              ),
            ),
          const SizedBox(height: 20),
          Text('Beri Rating Anda', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
          const SizedBox(height: 10),
          Row(
            children: List.generate(5, (index) {
              final isActive = _userRating != null && _userRating! >= index + 1;
              return GestureDetector(
                onTap: () => _submitRating(index + 1),
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(
                    isActive ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: isActive ? AppTheme.primaryYellow : Colors.grey.shade300,
                    size: 32,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 24),
          const Divider(height: 1),
          const SizedBox(height: 20),
          Text('Ulasan (${_comments.length})', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
          const SizedBox(height: 16),
          Container(
            decoration: AppTheme.inputDecoration(AppTheme.primaryYellow),
            child: TextField(
              controller: _commentController,
              maxLines: 3,
              minLines: 1,
              decoration: InputDecoration(
                hintText: 'Tulis ulasan Anda...',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                suffixIcon: Container(
                  margin: const EdgeInsets.all(6),
                  decoration: BoxDecoration(gradient: AppTheme.accentGradient, borderRadius: BorderRadius.circular(8)),
                  child: IconButton(
                    onPressed: _postComment,
                    icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                  ),
                ),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _postComment(),
            ),
          ),
          const SizedBox(height: 16),
          if (_comments.isEmpty)
            AppTheme.buildEmptyState(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'Belum ada ulasan',
              subtitle: 'Jadilah yang pertama memberikan ulasan!',
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _comments.length,
              itemBuilder: (context, index) {
                final comment = _comments[index];
                final profile = comment['profiles'];
                final username = profile?['username'] ?? 'Anonymous';
                final avatarUrl = profile?['avatar_url'];
                final isOwner = _currentUserId == comment['user_id'].toString();
                final commentUserId = comment['user_id'].toString();
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: AppTheme.inputDecoration(AppTheme.primaryYellow),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: commentUserId))),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(colors: [Colors.grey.shade300, Colors.grey.shade400]),
                                  ),
                                  child: ClipOval(
                                    child: avatarUrl != null
                                        ? Image.network(avatarUrl, fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.person, size: 18, color: Colors.white))
                                        : const Icon(Icons.person, size: 18, color: Colors.white),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(username, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                              ],
                            ),
                          ),
                          const Spacer(),
                          if (isOwner)
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _showEditCommentDialog(comment['id'], comment['content']);
                                } else if (value == 'delete') {
                                  _deleteComment(comment['id']);
                                }
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_rounded, size: 16), SizedBox(width: 8), Text('Edit')])),
                                const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_rounded, size: 16, color: Colors.red), SizedBox(width: 8), Text('Hapus', style: TextStyle(color: Colors.red))])),
                              ],
                              icon: Icon(Icons.more_vert_rounded, color: Colors.grey.shade400, size: 18),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(comment['content'] ?? '', style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary, height: 1.4)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded, size: 12, color: Colors.grey.shade400),
                          const SizedBox(width: 4),
                          Text(_formatDateTime(comment['created_at']), style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}