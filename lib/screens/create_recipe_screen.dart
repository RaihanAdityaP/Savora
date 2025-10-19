// ignore_for_file: prefer_final_fields, use_build_context_synchronously
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;
import 'dart:typed_data';
import 'dart:io' show File;
import '../utils/supabase_client.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/custom_bottom_nav.dart';

class CreateRecipeScreen extends StatefulWidget {
  const CreateRecipeScreen({super.key});

  @override
  State<CreateRecipeScreen> createState() => _CreateRecipeScreenState();
}

class _CreateRecipeScreenState extends State<CreateRecipeScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _cookingTimeController = TextEditingController();
  final _servingsController = TextEditingController();
  final _caloriesController = TextEditingController();

  final List<String> _ingredients = [];
  final List<String> _steps = [];
  File? _imageFile;
  Uint8List? _webImageBytes;
  int? _selectedCategoryId;
  String _selectedDifficulty = 'mudah';
  bool _isLoading = false;
  bool _isUploading = false;
  String? _userAvatarUrl;

  List<Map<String, dynamic>> _categories = [];

  final ImagePicker _picker = ImagePicker();

  final _tempIngredientController = TextEditingController();
  final _tempStepController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadUserAvatar();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _tempIngredientController.dispose();
    _tempStepController.dispose();
    _cookingTimeController.dispose();
    _servingsController.dispose();
    _caloriesController.dispose();
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

  Future<void> _loadCategories() async {
    try {
      final response = await supabase
          .from('categories')
          .select()
          .order('name');

      if (mounted) {
        setState(() {
          _categories = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      debugPrint('Error loading categories: $e');
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );

      if (image != null) {
        if (kIsWeb) {
          final bytes = await image.readAsBytes();
          if (mounted) {
            setState(() {
              _webImageBytes = bytes;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _imageFile = File(image.path);
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _addIngredient() {
    if (_tempIngredientController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bahan tidak boleh kosong')),
      );
      return;
    }

    setState(() {
      _ingredients.add(_tempIngredientController.text.trim());
      _tempIngredientController.clear();
    });
  }

  void _addStep() {
    if (_tempStepController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Langkah tidak boleh kosong')),
      );
      return;
    }

    setState(() {
      _steps.add(_tempStepController.text.trim());
      _tempStepController.clear();
    });
  }

  void _removeIngredient(int index) {
    setState(() {
      _ingredients.removeAt(index);
    });
  }

  void _removeStep(int index) {
    setState(() {
      _steps.removeAt(index);
    });
  }

  Future<void> _submitRecipe() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Judul resep harus diisi')),
      );
      return;
    }

    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih kategori terlebih dahulu')),
      );
      return;
    }

    if (_imageFile == null && _webImageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih gambar resep terlebih dahulu')),
      );
      return;
    }

    if (_ingredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tambahkan minimal 1 bahan')),
      );
      return;
    }

    if (_steps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tambahkan minimal 1 langkah')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final fileName = '$userId-${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = 'recipes/$fileName';
      final fileBytes = kIsWeb
          ? _webImageBytes!
          : await _imageFile!.readAsBytes();

      await supabase.storage.from('profiles').uploadBinary(
            filePath,
            fileBytes,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'image/jpeg',
            ),
          );

      final imageUrl =
          supabase.storage.from('profiles').getPublicUrl(filePath);

      int? calories;
      if (_caloriesController.text.trim().isNotEmpty) {
        final parsed = int.tryParse(_caloriesController.text.trim());
        if (parsed == null || parsed < 0) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Kalori harus berupa angka positif')),
            );
          }
          setState(() => _isUploading = false);
          return;
        }
        calories = parsed;
      }

      final recipeData = {
        'user_id': userId,
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'category_id': _selectedCategoryId,
        'cooking_time': int.tryParse(_cookingTimeController.text) ?? 0,
        'servings': int.tryParse(_servingsController.text) ?? 1,
        'calories': calories,
        'difficulty': _selectedDifficulty,
        'ingredients': _ingredients,
        'steps': _steps,
        'image_url': imageUrl,
        'status': 'pending',
      };

      await supabase.from('recipes').insert(recipeData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Resep berhasil dibuat! Menunggu persetujuan admin...'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget imagePreview;
    if (kIsWeb && _webImageBytes != null) {
      imagePreview = Image.memory(_webImageBytes!, fit: BoxFit.cover);
    } else if (!kIsWeb && _imageFile != null) {
      imagePreview = Image.file(_imageFile!, fit: BoxFit.cover);
    } else {
      imagePreview = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_photo_alternate, size: 60, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'Tap untuk memilih gambar',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      appBar: const CustomAppBar(showBackButton: true),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // Image Picker Header
                SliverToBoxAdapter(
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      height: 250,
                      width: double.infinity,
                      margin: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFFE5BFA5).withValues(alpha: 0.5),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: imagePreview,
                      ),
                    ),
                  ),
                ),
                
                SliverToBoxAdapter(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFF4E6),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title Section
                          _buildSectionTitle('Judul Resep'),
                          const SizedBox(height: 8),
                          _buildTextField(
                            controller: _titleController,
                            hint: 'Masukkan judul resep yang menarik',
                          ),
                          const SizedBox(height: 24),

                          // Description Section
                          _buildSectionTitle('Deskripsi'),
                          const SizedBox(height: 8),
                          _buildTextField(
                            controller: _descriptionController,
                            hint: 'Ceritakan tentang resep Anda',
                            maxLines: 3,
                          ),
                          const SizedBox(height: 24),

                          // Category & Difficulty
                          _buildSectionTitle('Kategori & Tingkat Kesulitan'),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: _buildCategoryDropdown()),
                              const SizedBox(width: 12),
                              Expanded(child: _buildDifficultyDropdown()),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Info Chips
                          _buildSectionTitle('Informasi Masak'),
                          const SizedBox(height: 12),
                          Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildInfoInput(
                                      controller: _cookingTimeController,
                                      label: 'Waktu (menit)',
                                      hint: '30',
                                      icon: Icons.access_time,
                                      color: const Color(0xFFFF6B35),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildInfoInput(
                                      controller: _servingsController,
                                      label: 'Porsi',
                                      hint: '4',
                                      icon: Icons.restaurant_menu,
                                      color: const Color(0xFF8BC34A),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              _buildInfoInput(
                                controller: _caloriesController,
                                label: 'Kalori (kcal)',
                                hint: '250',
                                icon: Icons.local_fire_department,
                                color: const Color(0xFFE91E63),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Ingredients Section
                          _buildSectionTitle('Bahan-bahan'),
                          const SizedBox(height: 12),
                          _buildAddItemRow(
                            controller: _tempIngredientController,
                            hint: 'Tambah bahan',
                            onAdd: _addIngredient,
                          ),
                          const SizedBox(height: 12),
                          _buildIngredientsList(),
                          const SizedBox(height: 24),

                          // Steps Section
                          _buildSectionTitle('Langkah-langkah'),
                          const SizedBox(height: 12),
                          _buildAddItemRow(
                            controller: _tempStepController,
                            hint: 'Tambah langkah',
                            onAdd: _addStep,
                            maxLines: 2,
                          ),
                          const SizedBox(height: 12),
                          _buildStepsList(),
                          const SizedBox(height: 24),

                          // Info Box
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline,
                                    color: Colors.blue.shade700, size: 24),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Resep Anda akan ditinjau oleh admin sebelum dipublikasikan',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.blue.shade800,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Submit Button
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isUploading ? null : _submitRecipe,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE5BFA5),
                                disabledBackgroundColor: Colors.grey.shade300,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 4,
                                shadowColor: const Color(0xFFE5BFA5).withValues(alpha: 0.4),
                              ),
                              child: _isUploading
                                  ? const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Publikasikan Resep',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: 2,
        avatarUrl: _userAvatarUrl,
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xFF5C4033),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade500),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Color(0xFFE5BFA5),
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE5BFA5).withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButton<int>(
        value: _selectedCategoryId,
        isExpanded: true,
        underline: Container(),
        hint: Text('Kategori', style: TextStyle(color: Colors.grey.shade600)),
        items: _categories.map((cat) {
          return DropdownMenuItem<int>(
            value: cat['id'],
            child: Text(cat['name'], style: const TextStyle(color: Color(0xFF5C4033))),
          );
        }).toList(),
        onChanged: (value) {
          setState(() => _selectedCategoryId = value);
        },
      ),
    );
  }

  Widget _buildDifficultyDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE5BFA5).withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButton<String>(
        value: _selectedDifficulty,
        isExpanded: true,
        underline: Container(),
        items: const [
          DropdownMenuItem(value: 'mudah', child: Text('Mudah')),
          DropdownMenuItem(value: 'sedang', child: Text('Sedang')),
          DropdownMenuItem(value: 'sulit', child: Text('Sulit')),
        ],
        onChanged: (value) {
          if (value != null) {
            setState(() => _selectedDifficulty = value);
          }
        },
      ),
    );
  }

  Widget _buildInfoInput({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey.shade400),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddItemRow({
    required TextEditingController controller,
    required String hint,
    required VoidCallback onAdd,
    int maxLines = 1,
  }) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey.shade500),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFFE5BFA5),
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: const Color(0xFFE5BFA5),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE5BFA5).withValues(alpha: 0.3),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            onPressed: onAdd,
            icon: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildIngredientsList() {
    if (_ingredients.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            'Belum ada bahan',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ),
      );
    }

    return Column(
      children: _ingredients.asMap().entries.map((entry) {
        final index = entry.key;
        final ingredient = entry.value;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5BFA5).withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B35).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Color(0xFFFF6B35),
                  size: 18,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  ingredient,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF5C4033),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _removeIngredient(index),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 16, color: Colors.red),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStepsList() {
    if (_steps.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            'Belum ada langkah',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ),
      );
    }

    return Column(
      children: _steps.asMap().entries.map((entry) {
        final index = entry.key;
        final step = entry.value;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF9CB5C5),
                const Color(0xFF9CB5C5).withValues(alpha: 0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF9CB5C5).withValues(alpha: 0.3),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF9CB5C5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    step,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => _removeStep(index),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, size: 16, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}