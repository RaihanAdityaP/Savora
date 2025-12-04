import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

final _logger = Logger();

class AIService {
  static final AIService _instance = AIService._internal();
  factory AIService() => _instance;
  AIService._internal();

  // Groq API Configuration
  final String _groqApiKey = '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'; 
  final String _groqModel = 'llama-3.3-70b-versatile';
  final String _groqBaseUrl = 'https://api.groq.com/openai/v1/chat/completions';
  
  // Hugging Face untuk image analysis (backup)
  final String _hfApiKey = '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';
  final String _imageModel = 'nlpconnect/vit-gpt2-image-captioning';
  
  // Retry configuration
  final int _maxRetries = 3;
  final Duration _retryDelay = const Duration(seconds: 2);
  final Duration _requestTimeout = const Duration(seconds: 30);

  void initialize() {
    _logger.d('AI Service initialized with Groq');
    _logger.d('Model: $_groqModel');
  }

  // Helper method for retry logic
  Future<T> _retryRequest<T>(
    Future<T> Function() request, {
    String operation = 'request',
  }) async {
    int attempts = 0;
    
    while (attempts < _maxRetries) {
      try {
        attempts++;
        _logger.d('Attempt $attempts/$_maxRetries for $operation');
        return await request();
      } catch (e) {
        _logger.w('Attempt $attempts failed for $operation: $e');
        
        if (attempts >= _maxRetries) {
          _logger.e('All retry attempts failed for $operation');
          rethrow;
        }
        
        // Wait before retry with exponential backoff
        await Future.delayed(_retryDelay * attempts);
      }
    }
    
    throw Exception('Max retries exceeded for $operation');
  }

  // 1. Cooking Assistant Chatbot with Groq
  Future<String> askCookingQuestion(String question, String recipeContext) async {
    return await _retryRequest(() async {
      try {
        _logger.d('Sending cooking question to Groq AI...');
        
        final messages = [
          {
            'role': 'system',
            'content': '''Anda adalah Chef AI Savora, asisten koki profesional Indonesia yang ramah dan membantu.

Tugas Anda:
- Menjawab pertanyaan tentang memasak dalam Bahasa Indonesia
- Memberikan tips praktis dan mudah dipahami
- Menjelaskan dengan detail tapi tidak bertele-tele
- Selalu ramah dan suportif
- Jika ada konteks resep, gunakan untuk memberikan jawaban yang lebih spesifik

Konteks Resep: $recipeContext'''
          },
          {
            'role': 'user',
            'content': question
          }
        ];

        final response = await http
            .post(
              Uri.parse(_groqBaseUrl),
              headers: {
                'Authorization': 'Bearer $_groqApiKey',
                'Content-Type': 'application/json',
              },
              body: json.encode({
                'model': _groqModel,
                'messages': messages,
                'temperature': 0.7,
                'max_tokens': 1000,
                'top_p': 0.9,
                'stream': false,
              }),
            )
            .timeout(_requestTimeout);

        _logger.d('Groq Response Status: ${response.statusCode}');

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          
          if (data['choices'] != null && data['choices'].isNotEmpty) {
            final content = data['choices'][0]['message']['content'];
            if (content != null && content.toString().isNotEmpty) {
              return content.toString().trim();
            }
          }
          
          throw Exception('Invalid response format from Groq');
        } else if (response.statusCode == 401) {
          throw Exception('API key Groq tidak valid. Periksa API key Anda.');
        } else if (response.statusCode == 429) {
          throw Exception('Terlalu banyak permintaan. Tunggu sebentar...');
        } else if (response.statusCode == 503) {
          throw Exception('Server Groq sedang sibuk. Coba lagi...');
        } else {
          _logger.e('Groq Error: ${response.statusCode}');
          _logger.e('Response: ${response.body}');
          throw Exception('Error ${response.statusCode}: Gagal menghubungi Groq AI');
        }
      } on TimeoutException catch (e) {
        _logger.e('Request timeout: $e');
        throw Exception('Koneksi timeout. Coba lagi.');
      } on SocketException catch (e) {
        _logger.e('Network error: $e');
        throw Exception('Tidak ada koneksi internet. Periksa koneksi Anda.');
      } on http.ClientException catch (e) {
        _logger.e('HTTP client error: $e');
        throw Exception('Gagal terhubung ke server Groq.');
      } on FormatException catch (e) {
        _logger.e('JSON parsing error: $e');
        throw Exception('Gagal memproses respons dari Groq.');
      } catch (e) {
        _logger.e('Unexpected error in askCookingQuestion: $e');
        rethrow;
      }
    }, operation: 'askCookingQuestion');
  }

  // 2. Analisis Resep dari Foto (Hybrid: HF untuk image, Groq untuk text)
  Future<String> analyzeRecipeFromImage(String imagePath) async {
    return await _retryRequest(() async {
      try {
        _logger.d('Reading image file: $imagePath');
        final imageBytes = await File(imagePath).readAsBytes();
        final base64Image = base64Encode(imageBytes);

        _logger.d('Analyzing image with Hugging Face...');
        
        // Step 1: Get image caption from Hugging Face
        final response = await http
            .post(
              Uri.parse('https://api-inference.huggingface.co/models/$_imageModel'),
              headers: {
                'Authorization': 'Bearer $_hfApiKey',
                'Content-Type': 'application/json',
              },
              body: json.encode({
                'inputs': base64Image,
                'options': {'wait_for_model': true}
              }),
            )
            .timeout(_requestTimeout);

        String caption = 'Gambar makanan';
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data is List && data.isNotEmpty) {
            caption = data[0]['generated_text'] ?? 'Gambar makanan';
          }
        }

        _logger.d('Image caption: $caption');
        
        // Step 2: Generate recipe using Groq based on caption
        return await _generateRecipeFromCaption(caption);
      } on FileSystemException catch (e) {
        _logger.e('File error: $e');
        throw Exception('Gagal membaca file gambar.');
      } catch (e) {
        _logger.e('Error in analyzeRecipeFromImage: $e');
        rethrow;
      }
    }, operation: 'analyzeRecipeFromImage');
  }

  Future<String> _generateRecipeFromCaption(String caption) async {
    final prompt = '''Berdasarkan gambar makanan dengan deskripsi: "$caption"

Tolong analisis dan berikan:
1. Prediksi nama makanan (jika terlihat jelas)
2. Bahan-bahan utama yang mungkin digunakan
3. Perkiraan cara memasak (3-5 langkah)
4. Tips memasak makanan ini

Jawab dalam Bahasa Indonesia dengan format yang rapi.''';

    try {
      return await askCookingQuestion(prompt, 'Analisis gambar makanan');
    } catch (e) {
      _logger.e('Error generating recipe: $e');
      return '''Analisis Gambar: $caption

Maaf, tidak dapat menghasilkan resep lengkap saat ini. 
Silakan coba lagi atau tanyakan langsung!''';
    }
  }

  // 3. Smart Recipe Suggestions
  Future<List<Map<String, dynamic>>> suggestRecipes({
    required List<String> availableIngredients,
    String? cuisine,
    String? difficulty,
  }) async {
    return await _retryRequest(() async {
      try {
        final prompt = '''Saya punya bahan-bahan: ${availableIngredients.join(", ")}
${cuisine != null ? 'Jenis masakan: $cuisine' : ''}
${difficulty != null ? 'Tingkat kesulitan: $difficulty' : ''}

Sarankan 5 resep yang bisa saya buat. Untuk setiap resep berikan dalam format:

RESEP 1:
Nama: [nama resep]
Deskripsi: [deskripsi singkat]
Waktu: [waktu dalam menit]
Tingkat: [mudah/sedang/sulit]

RESEP 2:
...

Dan seterusnya. Jawab dalam Bahasa Indonesia.''';

        final response = await askCookingQuestion(prompt, 'Saran resep');
        return _parseRecipeSuggestions(response);
      } catch (e) {
        _logger.e('Error suggesting recipes: $e');
        return [];
      }
    }, operation: 'suggestRecipes');
  }

  // 4. Generate Recipe from Description
  Future<Map<String, dynamic>> generateRecipe(String description) async {
    return await _retryRequest(() async {
      try {
        final prompt = '''Buatkan resep lengkap untuk: "$description"

Format:
JUDUL: [judul resep]
DESKRIPSI: [deskripsi singkat]

BAHAN-BAHAN:
- [bahan 1 dengan takaran]
- [bahan 2 dengan takaran]
...

LANGKAH-LANGKAH:
1. [langkah 1]
2. [langkah 2]
...

WAKTU MEMASAK: [X menit]
PORSI: [X porsi]
TINGKAT: [mudah/sedang/sulit]

TIPS: [tips memasak]

Jawab dalam Bahasa Indonesia dengan format yang jelas.''';

        final response = await askCookingQuestion(prompt, 'Generate resep');
        return _parseRecipeData(response);
      } catch (e) {
        _logger.e('Error generating recipe: $e');
        return {};
      }
    }, operation: 'generateRecipe');
  }

  // 5. Recipe Variation Suggestions
  Future<List<String>> suggestVariations(String recipeTitle) async {
    return await _retryRequest(() async {
      try {
        final prompt = '''Resep: $recipeTitle

Sarankan 3 variasi kreatif dari resep ini dalam Bahasa Indonesia.
Format setiap variasi sebagai poin terpisah dengan penjelasan singkat.

1. [Variasi 1 dan penjelasannya]
2. [Variasi 2 dan penjelasannya]
3. [Variasi 3 dan penjelasannya]''';

        final response = await askCookingQuestion(prompt, 'Variasi resep');
        return _parseVariations(response);
      } catch (e) {
        _logger.e('Error suggesting variations: $e');
        return [];
      }
    }, operation: 'suggestVariations');
  }

  // Helper: Parse recipe suggestions
  List<Map<String, dynamic>> _parseRecipeSuggestions(String text) {
    final suggestions = <Map<String, dynamic>>[];
    
    try {
      final recipes = text.split(RegExp(r'RESEP \d+:', caseSensitive: false));
      
      for (final recipe in recipes) {
        if (recipe.trim().isEmpty) continue;
        
        final nameMatch = RegExp(r'Nama:\s*(.+)', caseSensitive: false).firstMatch(recipe);
        final descMatch = RegExp(r'Deskripsi:\s*(.+)', caseSensitive: false).firstMatch(recipe);
        final timeMatch = RegExp(r'Waktu:\s*(\d+)', caseSensitive: false).firstMatch(recipe);
        final diffMatch = RegExp(r'Tingkat:\s*(\w+)', caseSensitive: false).firstMatch(recipe);
        
        if (nameMatch != null) {
          suggestions.add({
            'name': nameMatch.group(1)?.trim() ?? 'Resep',
            'description': descMatch?.group(1)?.trim() ?? 'Resep lezat',
            'time': timeMatch != null ? '${timeMatch.group(1)} menit' : '30 menit',
            'difficulty': diffMatch?.group(1)?.trim() ?? 'sedang',
          });
        }
      }
      
      return suggestions.take(5).toList();
    } catch (e) {
      _logger.e('Error parsing suggestions: $e');
      return [];
    }
  }

  // Helper: Parse recipe data
  Map<String, dynamic> _parseRecipeData(String text) {
    try {
      return {
        'title': _extractValue(text, ['JUDUL:', 'Judul:'], 'Resep Generated'),
        'description': _extractValue(text, ['DESKRIPSI:', 'Deskripsi:'], 'Resep lezat'),
        'ingredients': _extractListItems(text, ['BAHAN-BAHAN:', 'BAHAN:']),
        'steps': _extractListItems(text, ['LANGKAH-LANGKAH:', 'LANGKAH:']),
        'cooking_time': _extractNumber(text, ['WAKTU MEMASAK:', 'Waktu:']),
        'servings': _extractNumber(text, ['PORSI:', 'Porsi:']),
        'difficulty': _extractValue(text, ['TINGKAT:', 'Tingkat:'], 'sedang'),
        'tips': _extractValue(text, ['TIPS:', 'Tips:'], ''),
      };
    } catch (e) {
      _logger.e('Error parsing recipe: $e');
      return {
        'title': 'Resep Generated',
        'description': text.length > 200 ? text.substring(0, 200) : text,
        'ingredients': [],
        'steps': [],
        'cooking_time': 30,
        'servings': 4,
        'difficulty': 'sedang',
        'tips': '',
      };
    }
  }

  String _extractValue(String text, List<String> keywords, String defaultValue) {
    for (final keyword in keywords) {
      final regex = RegExp('$keyword\\s*(.+?)(?=\\n\\n|\\n[A-Z]|\\Z)', 
          caseSensitive: false, dotAll: true);
      final match = regex.firstMatch(text);
      if (match != null) {
        return match.group(1)?.trim() ?? defaultValue;
      }
    }
    return defaultValue;
  }

  int _extractNumber(String text, List<String> keywords) {
    for (final keyword in keywords) {
      final regex = RegExp('$keyword\\s*(\\d+)', caseSensitive: false);
      final match = regex.firstMatch(text);
      if (match != null) {
        return int.tryParse(match.group(1) ?? '30') ?? 30;
      }
    }
    return 30;
  }

  List<String> _extractListItems(String text, List<String> keywords) {
    final items = <String>[];
    
    for (final keyword in keywords) {
      final sectionRegex = RegExp(
        '$keyword(.+?)(?=\\n\\n|\\n[A-Z][A-Z]|\\Z)',
        caseSensitive: false,
        dotAll: true
      );
      final sectionMatch = sectionRegex.firstMatch(text);
      
      if (sectionMatch != null) {
        final section = sectionMatch.group(1) ?? '';
        final lines = section.split('\n');
        
        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.isNotEmpty) {
            // Remove bullets and numbers
            final cleaned = trimmed
                .replaceFirst(RegExp(r'^[-•\d.]+\s*'), '')
                .trim();
            if (cleaned.isNotEmpty) {
              items.add(cleaned);
            }
          }
        }
        
        if (items.isNotEmpty) break;
      }
    }
    
    return items.isNotEmpty ? items : ['Tidak ada data'];
  }

  List<String> _parseVariations(String text) {
    final variations = <String>[];
    final lines = text.split('\n');
    
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      
      // Match numbered or bulleted items
      final match = RegExp(r'^[\d•\-]+\.?\s*(.+)').firstMatch(trimmed);
      if (match != null) {
        final variation = match.group(1)?.trim();
        if (variation != null && variation.isNotEmpty) {
          variations.add(variation);
        }
      }
    }
    
    return variations.take(3).toList();
  }

  // Test connection
  Future<bool> testConnection() async {
    try {
      _logger.d('Testing Groq AI connection...');
      final response = await askCookingQuestion('Halo', 'Test');
      final isSuccess = !response.toLowerCase().contains('error');
      _logger.d('Connection test: ${isSuccess ? "SUCCESS ✓" : "FAILED ✗"}');
      return isSuccess;
    } catch (e) {
      _logger.e('Connection test failed: $e');
      return false;
    }
  }
}