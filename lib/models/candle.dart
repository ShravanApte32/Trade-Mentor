class Candle {
  final String date;
  final double open;
  final double high;
  final double low;
  final double close;
  final int volume;

  Candle({
    required this.date,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });

  factory Candle.fromJson(Map<String, dynamic> json) {
    return Candle(
      date: json['date'], // 👈 Make sure this matches the API response
      open: json['open'].toDouble(),
      high: json['high'].toDouble(),
      low: json['low'].toDouble(),
      close: json['close'].toDouble(),
      volume: json['volume'],
    );
  }
}
