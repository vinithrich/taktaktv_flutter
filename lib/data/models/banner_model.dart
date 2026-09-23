class BannerModel {
  final String id;
  final String title;
  final String subtitle;
  final String imageUrl;
  final String targetType;
  final String targetDramaId;
  final String ctaText;

  BannerModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.targetType,
    required this.targetDramaId,
    required this.ctaText,
  });

  factory BannerModel.fromJson(Map<String, dynamic> json) {
    print("HomeScreen DEBUG BANNER JSON: $json");
    return BannerModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      title: json['title'] ?? '',
      subtitle: json['subtitle'] ?? '',
      imageUrl: json['imageUrl'] ?? json['coverUrl'] ?? '',
      targetType: json['targetType'] ?? 'drama',
      targetDramaId: json['targetDramaId'] ?? '',
      ctaText: json['ctaText'] ?? 'Watch Now',
    );
  }
}