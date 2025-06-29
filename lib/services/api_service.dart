import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:trading_app/models/patterns.dart';
import '../models/candle.dart';

class ApiService {
  static const String baseUrl = "http://192.168.36.3"; // Replace

  static Future<PatternInfo?> fetchPatternInfo(String pattern) async {
    final encodedPattern = Uri.encodeComponent(pattern);
    final url = Uri.parse(
        '$baseUrl/trading_app/pattern_info.php?pattern=$encodedPattern');

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

  static Future<bool> fetchAndStoreCandles(
      String symbol, String timeframe) async {
    try {
      final url = Uri.parse(
          "$baseUrl/trading_app/fetch_alpha_data.php?symbol=$symbol&timeframe=$timeframe");

      print("🌐 Fetching from Alpha via PHP...\n🔗 URL: $url");

      final response = await http.get(url);

      print("🌐 Alpha API Raw Response: ${response.body}");

      // Find JSON start in case of mixed debug output
      final jsonStart = response.body.indexOf('{');
      if (jsonStart == -1) {
        print("❌ No JSON found in Alpha API response.");
        return false;
      }

      final jsonStr = response.body.substring(jsonStart).trim();
      final data = jsonDecode(jsonStr);

      print("✅ Alpha response status: ${data['status']}");

      if (data['status'] != 'success') {
        print(
            "❌ Alpha returned failure: ${data['message'] ?? 'Unknown error'}");
        if (data['debug'] != null) {
          print("🐞 Debug info: ${jsonEncode(data['debug'])}");
        }
        return false;
      }

      return true;
    } catch (e) {
      print("🔥 Exception in fetchAndStoreCandles: $e");
      return false;
    }
  }

  static Future<List<Candle>> fetchCandlesFromPatterns(
      String symbol, String timeframe) async {
    final url = Uri.parse(
        "$baseUrl/trading_app/fetch_patterns.php?symbol=$symbol&timeframe=$timeframe");
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
        Uri.parse("$baseUrl/trading_app/get_symbols.php"),
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
