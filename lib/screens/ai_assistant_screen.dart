import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/ai_service.dart';
import '../widgets/theme.dart';

class AIAssistantScreen extends StatefulWidget {
  final String? recipeContext;
  
  const AIAssistantScreen({super.key, this.recipeContext});

  @override
  State<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends State<AIAssistantScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  final ImagePicker _imagePicker = ImagePicker();
  bool _isLoading = false;
  int _retryCount = 0;
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    _addWelcomeMessage();
  }

  void _addWelcomeMessage() {
    setState(() {
      _messages.add(ChatMessage(
        text: 'Halo! Saya Chef AI Savora 👨‍🍳\n\n'
            'Saya siap membantu Anda dengan:\n'
            '• Pertanyaan tentang resep\n'
            '• Tips memasak\n'
            '• Saran variasi resep\n'
            '• Analisis foto makanan 📸\n'
            '• Dan banyak lagi!\n\n'
            'Ada yang bisa saya bantu?',
        isUser: false,
        timestamp: DateTime.now(),
      ));
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
        
        // Show preview with option to analyze
        _showImagePreview();
      }
    } catch (e) {
      _showErrorSnackBar('Gagal memilih gambar: $e');
    }
  }

  void _showImagePreview() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Preview Gambar',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() => _selectedImage = null);
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            
            // Image preview
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    _selectedImage!,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            
            // Analyze button
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _analyzeImage();
                  },
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Analisis Gambar Ini'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppTheme.primaryCoral,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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

  Future<void> _analyzeImage() async {
    if (_selectedImage == null) return;

    setState(() {
      _messages.add(ChatMessage(
        text: '📸 [Foto makanan dikirim]',
        isUser: true,
        timestamp: DateTime.now(),
        imageFile: _selectedImage,
      ));
      _isLoading = true;
    });

    _scrollToBottom();

    try {
      final aiService = AIService();
      final response = await aiService.analyzeRecipeFromImage(_selectedImage!.path);

      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(
            text: response,
            isUser: false,
            timestamp: DateTime.now(),
            isSuccess: true,
          ));
          _isLoading = false;
          _selectedImage = null;
        });

        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = _getErrorMessage(e.toString());
        final isRetryable = _isRetryableError(e.toString());
        
        setState(() {
          _messages.add(ChatMessage(
            text: errorMessage,
            isUser: false,
            timestamp: DateTime.now(),
            isError: true,
            canRetry: isRetryable,
          ));
          _isLoading = false;
        });
        
        _scrollToBottom();
      }
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Pilih Sumber Gambar',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.camera_alt, color: Colors.blue.shade700),
                ),
                title: const Text('Kamera'),
                subtitle: const Text('Ambil foto baru'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.photo_library, color: Colors.purple.shade700),
                ),
                title: const Text('Galeri'),
                subtitle: const Text('Pilih dari galeri'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final userMessage = _messageController.text.trim();
    _messageController.clear();

    setState(() {
      _messages.add(ChatMessage(
        text: userMessage,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isLoading = true;
      _retryCount = 0;
    });

    _scrollToBottom();

    try {
      final aiService = AIService();
      final response = await aiService.askCookingQuestion(
        userMessage,
        widget.recipeContext ?? 'General cooking question',
      );

      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(
            text: response,
            isUser: false,
            timestamp: DateTime.now(),
            isSuccess: true,
          ));
          _isLoading = false;
        });

        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = _getErrorMessage(e.toString());
        final isRetryable = _isRetryableError(e.toString());
        
        setState(() {
          _messages.add(ChatMessage(
            text: errorMessage,
            isUser: false,
            timestamp: DateTime.now(),
            isError: true,
            canRetry: isRetryable,
          ));
          _isLoading = false;
        });
        
        _scrollToBottom();
      }
    }
  }

  String _getErrorMessage(String error) {
    if (error.contains('API key Groq tidak valid')) {
      return '🔑 API key Groq tidak valid!\n\n'
          'Pastikan Anda sudah:\n'
          '1. Daftar di console.groq.com\n'
          '2. Buat API key\n'
          '3. Update API key di kode\n\n'
          'Hubungi developer untuk bantuan.';
    } else if (error.contains('Tidak ada koneksi internet')) {
      return '📡 Tidak ada koneksi internet.\n\n'
          'Pastikan Anda terhubung ke internet dan coba lagi.';
    } else if (error.contains('Terlalu banyak permintaan')) {
      return '⚠️ Terlalu banyak permintaan.\n\n'
          'Tunggu sebentar (sekitar 1 menit) sebelum mencoba lagi.';
    } else if (error.contains('timeout')) {
      return '⏱️ Koneksi timeout.\n\n'
          'Server membutuhkan waktu terlalu lama untuk merespons. Coba lagi.';
    } else if (error.contains('Server Groq sedang sibuk')) {
      return '🔄 Server sedang sibuk.\n\n'
          'Coba lagi dalam beberapa detik.';
    } else {
      return '❌ Maaf, terjadi kesalahan.\n\n'
          'Coba lagi dalam beberapa saat. Jika masalah berlanjut, '
          'hubungi support dengan kode error:\n\n$error';
    }
  }

  bool _isRetryableError(String error) {
    return error.contains('timeout') ||
           error.contains('Tidak ada koneksi internet') ||
           error.contains('Gagal terhubung') ||
           error.contains('Server Groq sedang sibuk');
  }

  Future<void> _retryLastMessage() async {
    if (_messages.length < 2) return;
    
    // Find last user message
    ChatMessage? lastUserMessage;
    File? lastImageFile;
    
    for (int i = _messages.length - 1; i >= 0; i--) {
      if (_messages[i].isUser) {
        lastUserMessage = _messages[i];
        lastImageFile = _messages[i].imageFile;
        break;
      }
    }
    
    if (lastUserMessage == null) return;
    
    // Remove error message
    setState(() {
      _messages.removeWhere((msg) => msg.isError && !msg.isUser);
      _isLoading = true;
      _retryCount++;
    });

    try {
      final aiService = AIService();
      String response;
      
      // Check if it was an image analysis
      if (lastImageFile != null) {
        response = await aiService.analyzeRecipeFromImage(lastImageFile.path);
      } else {
        response = await aiService.askCookingQuestion(
          lastUserMessage.text,
          widget.recipeContext ?? 'General cooking question',
        );
      }

      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(
            text: response,
            isUser: false,
            timestamp: DateTime.now(),
            isSuccess: true,
          ));
          _isLoading = false;
        });

        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = _getErrorMessage(e.toString());
        final isRetryable = _isRetryableError(e.toString());
        
        setState(() {
          _messages.add(ChatMessage(
            text: errorMessage,
            isUser: false,
            timestamp: DateTime.now(),
            isError: true,
            canRetry: isRetryable && _retryCount < 3,
          ));
          _isLoading = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppTheme.accentGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.psychology_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Chef AI', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('Powered by Groq ⚡', style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal)),
              ],
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showInfoDialog(),
            tooltip: 'Info',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      return _buildMessageBubble(_messages[index]);
                    },
                  ),
          ),
          if (_isLoading) _buildLoadingIndicator(),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: AppTheme.accentGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.restaurant_menu,
                size: 48,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Chef AI Savora',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Asisten memasak AI tercepat ⚡',
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 32),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                _buildFeatureChip('💬 Chat', Colors.blue),
                _buildFeatureChip('📸 Analisis Foto', Colors.purple),
                _buildFeatureChip('📖 Tips Resep', Colors.orange),
                _buildFeatureChip('⚡ Super Cepat', Colors.green),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Color.lerp(color, Colors.black, 0.3)!,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.primaryCoral,
                  ),
                ),
                const SizedBox(width: 8),
                const Text('Chef AI sedang berpikir...'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: message.isUser 
            ? CrossAxisAlignment.end 
            : CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            decoration: BoxDecoration(
              gradient: message.isUser
                  ? AppTheme.accentGradient
                  : message.isError
                      ? LinearGradient(
                          colors: [Colors.red.shade50, Colors.red.shade100],
                        )
                      : LinearGradient(
                          colors: [Colors.grey.shade100, Colors.grey.shade50],
                        ),
              borderRadius: BorderRadius.circular(16),
              border: message.isError 
                  ? Border.all(color: Colors.red.shade300, width: 1)
                  : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.imageFile != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      message.imageFile!,
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  message.text,
                  style: TextStyle(
                    color: message.isUser 
                        ? Colors.white 
                        : message.isError
                            ? Colors.red.shade900
                            : AppTheme.textPrimary,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          if (message.canRetry && message.isError)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextButton.icon(
                onPressed: _retryLastMessage,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Coba Lagi'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primaryCoral,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Image picker button
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: _isLoading ? null : _showImageSourceDialog,
                icon: Icon(
                  Icons.image_rounded,
                  color: _isLoading ? Colors.grey : AppTheme.primaryCoral,
                ),
                tooltip: 'Kirim Foto',
              ),
            ),
            const SizedBox(width: 8),
            
            // Text input
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Tanya tentang masak...',
                    hintStyle: TextStyle(color: Colors.grey.shade500),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                  enabled: !_isLoading,
                ),
              ),
            ),
            const SizedBox(width: 8),
            
            // Send button
            Container(
              decoration: BoxDecoration(
                gradient: _isLoading 
                    ? LinearGradient(colors: [Colors.grey, Colors.grey.shade400])
                    : AppTheme.accentGradient,
                shape: BoxShape.circle,
                boxShadow: _isLoading ? [] : AppTheme.buttonShadow,
              ),
              child: IconButton(
                onPressed: _isLoading ? null : _sendMessage,
                icon: const Icon(Icons.send_rounded, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue),
            SizedBox(width: 8),
            Text('Tentang Chef AI'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Chef AI Savora adalah asisten memasak berbasis AI dengan teknologi Groq yang super cepat!',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.bolt, color: Colors.green.shade700, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Powered by Groq - Inference tercepat di dunia!',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Fitur:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildInfoItem('💬', 'Chat interaktif tentang memasak'),
              _buildInfoItem('📸', 'Analisis foto makanan dengan AI'),
              _buildInfoItem('📖', 'Bantuan resep dan tips memasak'),
              _buildInfoItem('🔄', 'Saran variasi resep kreatif'),
              _buildInfoItem('⚡', 'Respons super cepat (< 1 detik)'),
              _buildInfoItem('🇮🇩', 'Jawaban dalam Bahasa Indonesia'),
              const SizedBox(height: 16),
              const Text(
                'Cara Menggunakan:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildInfoItem('1.', 'Ketik pertanyaan atau klik ikon gambar'),
              _buildInfoItem('2.', 'Untuk foto: pilih kamera/galeri'),
              _buildInfoItem('3.', 'Tunggu AI menganalisis (sangat cepat!)'),
              _buildInfoItem('4.', 'Dapatkan jawaban lengkap dan detail'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Mengerti'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isError;
  final bool isSuccess;
  final bool canRetry;
  final File? imageFile;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isError = false,
    this.isSuccess = false,
    this.canRetry = false,
    this.imageFile,
  });
}