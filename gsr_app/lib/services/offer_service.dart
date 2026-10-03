class OfferService {
  OfferService._();

  static Map<String, dynamic>? _applied;

  static void apply(Map<String, dynamic> offer) => _applied = offer;
  static void clear() => _applied = null;

  static bool get hasOffer => _applied != null;
  static String? get restaurantId => _applied?['restaurant_id'] as String?;

  // 'order' | 'item' | 'bogo'
  static String get offerType => _applied?['offer_type'] as String? ?? 'order';

  // For 'order' and 'item' types
  static double get discountPct =>
      (_applied?['discount_pct'] as num?)?.toDouble() ?? 0;

  // For 'item' and 'bogo' types
  static String? get menuItemId => _applied?['menu_item_id'] as String?;
  static String get menuItemName =>
      _applied?['menu_item_name'] as String? ?? '';

  // For 'bogo' type
  static int get buyQty => (_applied?['buy_qty'] as num?)?.toInt() ?? 0;
  static int get freeQty => (_applied?['free_qty'] as num?)?.toInt() ?? 0;

  static String get title => _applied?['title'] as String? ?? '';
}
