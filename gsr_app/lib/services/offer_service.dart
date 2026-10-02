class OfferService {
  OfferService._();

  static Map<String, dynamic>? _applied;

  static void apply(Map<String, dynamic> offer) => _applied = offer;
  static void clear() => _applied = null;

  static bool get hasOffer => _applied != null;
  static String? get restaurantId => _applied?['restaurant_id'] as String?;
  static double get discountPct =>
      (_applied?['discount_pct'] as num?)?.toDouble() ?? 0;
  static String get title => _applied?['title'] as String? ?? '';
}
