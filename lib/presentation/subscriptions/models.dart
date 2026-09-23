class SubscriptionPlan {
  final String id;
  final String name;
  final String planCode;
  final num price;
  final num originalPrice;
  final String currency;
  final int durationDays;
  final int trialDays;
  final String tag;
  final List<String> benefits;

  SubscriptionPlan({
    required this.id,
    required this.name,
    required this.planCode,
    required this.price,
    required this.originalPrice,
    required this.currency,
    required this.durationDays,
    required this.trialDays,
    required this.tag,
    required this.benefits,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      planCode: json['planCode'] ?? '',
      price: json['price'] ?? 0,
      originalPrice: json['originalPrice'] ?? 0,
      currency: json['currency'] ?? 'INR',
      durationDays: json['durationDays'] ?? 0,
      trialDays: json['trialDays'] ?? 0,
      tag: json['tag'] ?? '',
      benefits: List<String>.from(json['benefits'] ?? []),
    );
  }
}