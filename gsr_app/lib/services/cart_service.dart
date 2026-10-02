class CartItem {
  final String itemId;
  final String name;
  final String category;
  final double price;
  int qty;

  CartItem({
    required this.itemId,
    required this.name,
    required this.category,
    required this.price,
    this.qty = 1,
  });
}

class CartService {
  CartService._();

  static String? _restaurantId;
  static String? _restaurantName;
  static final List<CartItem> _items = [];

  static List<CartItem> get items => List.unmodifiable(_items);
  static String? get restaurantId => _restaurantId;
  static String? get restaurantName => _restaurantName;
  static int get itemCount => _items.fold(0, (s, i) => s + i.qty);
  static double get total => _items.fold(0.0, (s, i) => s + i.price * i.qty);

  static int qtyFor(String itemId) =>
      _items.where((i) => i.itemId == itemId).fold(0, (s, i) => s + i.qty);

  static void add(
    String restaurantId,
    String restaurantName,
    String itemId,
    String name,
    String category,
    double price,
  ) {
    if (_restaurantId != null && _restaurantId != restaurantId) {
      _items.clear();
    }
    _restaurantId = restaurantId;
    _restaurantName = restaurantName;

    final idx = _items.indexWhere((i) => i.itemId == itemId);
    if (idx >= 0) {
      _items[idx].qty++;
    } else {
      _items.add(CartItem(
        itemId: itemId,
        name: name,
        category: category,
        price: price,
      ));
    }
  }

  static void remove(String itemId) {
    final idx = _items.indexWhere((i) => i.itemId == itemId);
    if (idx < 0) return;
    if (_items[idx].qty > 1) {
      _items[idx].qty--;
    } else {
      _items.removeAt(idx);
    }
    if (_items.isEmpty) _restaurantId = null;
  }

  static void clear() {
    _items.clear();
    _restaurantId = null;
    _restaurantName = null;
  }

  static List<Map<String, dynamic>> toOrderItems() => _items
      .map((i) => {'item_id': i.itemId, 'qty': i.qty})
      .toList();
}
