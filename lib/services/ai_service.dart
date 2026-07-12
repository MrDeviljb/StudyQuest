import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../database/hive_service.dart';
import 'timetable_parser.dart';

class AIService {
  // Retrieve Gemini API Key from Hive
  static String getGeminiApiKey() {
    return HiveService.settingsBox.get('gemini_api_key', defaultValue: '') as String;
  }

  // Save Gemini API Key to Hive
  static Future<void> saveGeminiApiKey(String key) async {
    await HiveService.settingsBox.put('gemini_api_key', key.trim());
  }

  // Check if API key is set
  static bool hasApiKey() {
    return getGeminiApiKey().isNotEmpty;
  }

  // Parse a timetable image byte stream using Gemini API
  static Future<List<ImportedTask>> parseTimetableImage(Uint8List imageBytes, String mimeType) async {
    final apiKey = getGeminiApiKey();
    if (apiKey.isEmpty) {
      throw Exception('Gemini API Key is missing. Please configure it in Settings.');
    }

    final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey');

    final base64Image = base64Encode(imageBytes);

    final payload = {
      'contents': [
        {
          'parts': [
            {
              'text': 'Analyze this timetable image and extract the study schedule/timetable. '
                  'Output ONLY a raw JSON array of objects with the exact fields: '
                  '"subject" (String), "day" (String - e.g. "Monday", "Tuesday", etc.), '
                  '"startTime" (String in 12-hour AM/PM format, e.g. "7:00 PM" or "9:30 AM"), '
                  'and "endTime" (String in 12-hour AM/PM format or null). '
                  'Do not include any markdown styling like ```json or any other text. Output only the pure JSON array.'
            },
            {
              'inlineData': {
                'mimeType': mimeType,
                'data': base64Image
              }
            }
          ]
        }
      ]
    };

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      throw Exception('Gemini API error: ${response.statusCode} - ${response.body}');
    }

    final Map<String, dynamic> data = jsonDecode(response.body);
    final String text = data['candidates']?[0]?['content']?[0]?['text'] ?? '';
    
    // Clean any markdown styling like ```json ... ``` using a robust regex pattern
    final jsonRegex = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```');
    final match = jsonRegex.firstMatch(text);
    String cleanedJson = match != null ? match.group(1)!.trim() : text.trim();

    final List<dynamic> parsedList = jsonDecode(cleanedJson);
    final List<ImportedTask> tasks = [];
    
    for (var item in parsedList) {
      if (item is Map) {
        tasks.add(ImportedTask(
          subject: item['subject']?.toString() ?? '',
          day: item['day']?.toString() ?? 'Monday',
          startTime: item['startTime']?.toString() ?? '',
          endTime: item['endTime']?.toString(),
        ));
      }
    }

    // Merge sequential items and sort chronologically
    return TimetableParser.mergeSequentialTasks(tasks);
  }
}
