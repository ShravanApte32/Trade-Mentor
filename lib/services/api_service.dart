import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:trading_app/models/patterns.dart';
import '../models/candle.dart';

class ApiService {
  static const String baseUrl = "http://192.168.0.112:3000"; // Replace

  static Future<PatternInfo?> fetchPatternInfo(String pattern) async {
    final encodedPattern = Uri.encodeComponent(pattern);
    final url =
        Uri.parse('$baseUrl/get_pattern_info.php?pattern=$encodedPattern');

    print("🔍 Fetching pattern info for: $pattern");
    print("🔗 URL: $url");

    try {
      final res = await http.get(url);

      print("📩 Raw Response (${res.statusCode}):");
      print(res.body); // 👈 This prints the full raw JSON string

      final data = jsonDecode(res.body);

      print("📦 Decoded JSON:");
      print(jsonEncode(data)); // Pretty JSON print

      if (data['status'] == 'success') {
        print("✅ Pattern data found: ${data['pattern']['title']}");
        return PatternInfo.fromJson(data['pattern']);
      } else {
        print("❌ Pattern info not found for: $pattern");
      }
    } catch (e) {
      print("🔥 Error: $e");
    }

    return null;
  }

  static Future<Map<String, dynamic>> fetchAndStoreCandles(
      String symbol, String timeframe) async {
    try {
      final url = Uri.parse(
          "$baseUrl/fetch_alpha_data.php?symbol=$symbol&timeframe=$timeframe");
      print("🌐 Fetching from: $url");

      final response = await http.get(url);
      print("📡 Response status: ${response.statusCode}");

      if (response.statusCode == 200) {
        // Clean the response - remove HTML comments
        String cleanResponse = response.body;
        final commentRegex = RegExp(r'<!--.*?-->', dotAll: true);
        cleanResponse = cleanResponse.replaceAll(commentRegex, '');

        final jsonStart = cleanResponse.indexOf('{');
        if (jsonStart == -1) {
          return {"success": false, "source": "error"};
        }

        final jsonStr = cleanResponse.substring(jsonStart);
        final data = jsonDecode(jsonStr);

        if (data['status'] == 'success' &&
            data['results'] != null &&
            data['results'].isNotEmpty) {
          final firstResult = data['results'][0];
          return {
            "success": true,
            "source": firstResult['source'] ?? 'unknown', // 'cache' or 'api'
            "candles": firstResult['candles'] ?? 0
          };
        }
      }
      return {"success": false, "source": "error"};
    } catch (e) {
      print("🔥 Exception: $e");
      return {"success": false, "source": "error"};
    }
  }

  static Future<List<Candle>> fetchCandlesFromPatterns(
      String symbol, String timeframe) async {
    final url = Uri.parse(
        "$baseUrl/fetch_patterns.php?symbol=$symbol&timeframe=$timeframe");
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json["status"] == "success") {
        final List data = json["candles"];
        return data.map((c) => Candle.fromJson(c)).toList();
      }
    }
    return [];
  }

  static Future<List<String>> fetchSymbols() async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/get_symbols.php"),
      );

      print("🌐 GET Symbols Response: ${res.body}");

      final json = jsonDecode(res.body);

      if (json['status'] == 'success') {
        print("✅ Symbols fetched: ${json['symbols']}");
        return List<String>.from(json['symbols']);
      } else {
        print("❌ API returned failure: ${json['status']}");
        return [];
      }
    } catch (e) {
      print("🔥 Exception fetching symbols: $e");
      return [];
    }
  }
}
