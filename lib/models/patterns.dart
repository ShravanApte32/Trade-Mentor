class PatternInfo {
  final String title;
  final String type;
  final String description;
  final String tradeTip;
  final String image;

  PatternInfo({
    required this.title,
    required this.type,
    required this.description,
    required this.tradeTip,
    required this.image,
  });

  factory PatternInfo.fromJson(Map<String, dynamic> json) {
    return PatternInfo(
      title: json['title'],
      type: json['type'],
      description: json['description'],
      tradeTip: json['trade_tip'],
      image: json['image'],
    );
  }
}
