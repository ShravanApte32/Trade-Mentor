import 'package:intl/intl.dart';

import '../models/candle.dart';

class MockDataGenerator {
  static List<String> getMockSymbols() {
    return [
      'RELIANCE.BSE',
      'TCS.BSE',
      'INFY.BSE',
      'HDFCBANK.BSE',
      'ICICIBANK.BSE',
      'SBIN.BSE',
      'BHARTIARTL.BSE',
      'ITC.BSE',
      'HINDUNILVR.BSE',
      'LT.BSE',
      'AXISBANK.BSE',
      'KOTAKBANK.BSE'
    ];
  }

  static List<Candle> generateMockCandles(String symbol, int count) {
    List<Candle> candles = [];
    DateTime now = DateTime.now();

    // Base price varies by symbol (using hash to make it consistent)
    int basePriceInt = symbol.hashCode.abs() % 5000 + 500;
    double basePrice = basePriceInt.toDouble();
    double currentPrice = basePrice;

    for (int i = count; i >= 0; i--) {
      DateTime date = DateTime(now.year, now.month, now.day - i);

      // Generate realistic price movement
      double volatility = 0.02; // 2% max movement
      double changePercent =
          (DateTime.now().millisecondsSinceEpoch % 100 - 50) / 100 * volatility;
      double change = currentPrice * changePercent;

      double open = currentPrice;
      double close = currentPrice + change;
      double high =
          (open > close ? open : close) + (currentPrice * 0.01 * (i % 5) / 100);
      double low =
          (open < close ? open : close) - (currentPrice * 0.01 * (i % 5) / 100);
      int volume = 100000 + (DateTime.now().millisecondsSinceEpoch % 10000000);

      candles.add(Candle(
        date: DateFormat('yyyy-MM-dd').format(date),
        open: open,
        high: high,
        low: low,
        close: close,
        volume: volume,
      ));

      currentPrice = close;
    }

    return candles;
  }

  static Map<int, List<String>> generateMockPatterns(List<Candle> candles) {
    Map<int, List<String>> patterns = {};

    // Generate some random patterns for demonstration
    List<String> possiblePatterns = [
      'Bullish Engulfing',
      'Hammer',
      'Morning Star',
      'Doji',
      'Bearish Engulfing',
      'Shooting Star',
      'Evening Star',
      'Bull Flag',
      'Double Bottom',
      'Head and Shoulders'
    ];

    for (int i = 10; i < candles.length; i += 15) {
      if (DateTime.now().millisecondsSinceEpoch % 3 == 0) {
        int patternCount = (DateTime.now().millisecondsSinceEpoch % 3) + 1;
        List<String> patternList = [];

        for (int j = 0; j < patternCount; j++) {
          int patternIndex = (DateTime.now().millisecondsSinceEpoch + i + j) %
              possiblePatterns.length;
          patternList.add(possiblePatterns[patternIndex]);
        }

        patterns[DateTime.parse(candles[i].date).millisecondsSinceEpoch] =
            patternList;
      }
    }

    return patterns;
  }
}
