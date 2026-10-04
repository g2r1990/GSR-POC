import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

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

  Map<String, dynamic> toJson() => {
    'itemId': itemId,
    'name': name,
    'category': category,
    'price': price,
    'qty': qty,
  };

  factory CartItem.fromJson(Map<String, dynamic> j) => CartItem(
    itemId: j['itemId'] as String,
    name: j['name'] as String,
    category: j['category'] as String,
    price: (j['price'] as num).toDouble(),
    qty: j['qty'] as int,
  );
}

class CartService {
  CartService._();

  static const _kKey = 'cart_data';

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

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kKey);
      if (raw == null) return;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      _restaurantId = json['restaurantId'] as String?;
      _restaurantName = json['restaurantName'] as String?;
      _items.clear();
      for (final item in (json['items'] as List<dynamic>? ?? [])) {
        _items.add(CartItem.fromJson(item as Map<String, dynamic>));
      }
    } catch (_) {}
  }

  static Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_items.isEmpty) {
        await prefs.remove(_kKey);
        return;
      }
      await prefs.setString(_kKey, jsonEncode({
        'restaurantId': _restaurantId,
        'restaurantName': _restaurantName,
        'items': _items.map((i) => i.toJson()).toList(),
      }));
    } catch (_) {}
  }

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
    _save();
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
    _save();
  }

  static void clear() {
    _items.clear();
    _restaurantId = null;
    _restaurantName = null;
    _save();
  }

  static List<Map<String, dynamic>> toOrderItems() => _items
      .map((i) => {'item_id': i.itemId, 'qty': i.qty})
      .toList();
}
