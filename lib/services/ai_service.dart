import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:io';
import 'dart:convert';

class AIService {
  static final AIService _instance = AIService._internal();
  factory AIService() => _instance;
  AIService._internal();

  final String _apiKey = 'AIzaSyAYVkGrQnQAP2lWWpP-r6YFwHTpkDS9Dbw';
  late final GenerativeModel _model;

  void initialize() {
    _model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: _apiKey,
    );
  }

  // 1. Analisis Resep dari Foto
  Future<String> analyzeRecipeFromImage(String imagePath) async {
    try {
      final imageBytes = await File(imagePath).readAsBytes();
      
      final prompt = '''
      Analisis foto makanan ini dan berikan:
      1. Nama makanan (prediksi)
      2. Bahan-bahan yang terlihat
      3. Estimasi cara pembuatan
      4. Tips memasak
      
      Format: JSON dengan struktur:
      {
        "name": "...",
        "ingredients": ["...", "..."],
        "steps": ["...", "..."],
        "tips": "..."
      }
      ''';

      final content = [
        Content.multi([
          TextPart(prompt),
          DataPart('image/jpeg', imageBytes),
        ])
      ];

      final response = await _model.generateContent(content);
      return response.text ?? 'Gagal menganalisis gambar';
    } catch (e) {
      return 'Error: $e';
    }
  }

  // 2. Smart Recipe Suggestions
  Future<List<String>> suggestRecipes({
    required List<String> availableIngredients,
    String? cuisine,
    String? difficulty,
  }) async {
    try {
      final prompt = '''
      Saya punya bahan: ${availableIngredients.join(", ")}
      ${cuisine != null ? 'Masakan: $cuisine' : ''}
      ${difficulty != null ? 'Tingkat kesulitan: $difficulty' : ''}
      
      Berikan 5 saran resep yang bisa dibuat.
      Format: JSON array dengan struktur:
      [
        {
          "name": "Nama Resep",
          "description": "Deskripsi singkat",
          "time": "30 menit",
          "difficulty": "mudah"
        }
      ]
      ''';

      final response = await _model.generateContent([Content.text(prompt)]);
      final text = response.text ?? '[]';
      
      // Parse JSON dan return list
      return _parseRecipeSuggestions(text);
    } catch (e) {
      return [];
    }
  }

  // 3. Cooking Assistant Chatbot
  Future<String> askCookingQuestion(String question, String recipeContext) async {
    try {
      final prompt = '''
      Konteks Resep: $recipeContext
      
      Pertanyaan: $question
      
      Jawab dengan jelas dan singkat sebagai chef profesional.
      ''';

      final response = await _model.generateContent([Content.text(prompt)]);
      return response.text ?? 'Maaf, saya tidak bisa menjawab pertanyaan itu.';
    } catch (e) {
      return 'Error: $e';
    }
  }

  // 4. Generate Recipe from Description
  Future<Map<String, dynamic>> generateRecipe(String description) async {
    try {
      final prompt = '''
      Buatkan resep lengkap untuk: "$description"
      
      Format JSON:
      {
        "title": "...",
        "description": "...",
        "ingredients": ["...", "..."],
        "steps": ["...", "..."],
        "cooking_time": 30,
        "servings": 4,
        "difficulty": "mudah",
        "tips": "..."
      }
      ''';

      final response = await _model.generateContent([Content.text(prompt)]);
      return _parseRecipeData(response.text ?? '{}');
    } catch (e) {
      return {};
    }
  }

  // 5. Recipe Variation Suggestions
  Future<List<String>> suggestVariations(String recipeTitle) async {
    try {
      final prompt = '''
      Resep: $recipeTitle
      
      Berikan 3 variasi kreatif dari resep ini.
      Format: JSON array of strings
      ["Variasi 1", "Variasi 2", "Variasi 3"]
      ''';

      final response = await _model.generateContent([Content.text(prompt)]);
      return _parseStringList(response.text ?? '[]');
    } catch (e) {
      return [];
    }
  }

  // Helper methods
  List<String> _parseRecipeSuggestions(String jsonText) {
    // Implement JSON parsing
    try {
      final cleaned = jsonText.replaceAll('```json', '').replaceAll('```', '').trim();
      final List<dynamic> data = json.decode(cleaned);
      return data.map((item) => item['name'] as String).toList();
    } catch (e) {
      return [];
    }
  }

  Map<String, dynamic> _parseRecipeData(String jsonText) {
    try {
      final cleaned = jsonText.replaceAll('```json', '').replaceAll('```', '').trim();
      return json.decode(cleaned) as Map<String, dynamic>;
    } catch (e) {
      return {};
    }
  }

  List<String> _parseStringList(String jsonText) {
    try {
      final cleaned = jsonText.replaceAll('```json', '').replaceAll('```', '').trim();
      final List<dynamic> data = json.decode(cleaned);
      return data.map((item) => item.toString()).toList();
    } catch (e) {
      return [];
    }
  }
}