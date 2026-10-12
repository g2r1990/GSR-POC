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

class _RestaurantCart {
  final String restaurantId;
  final String restaurantName;
  final List<CartItem> _items = [];

  _RestaurantCart({required this.restaurantId, required this.restaurantName});

  List<CartItem> get items => List.unmodifiable(_items);
  int get itemCount => _items.fold(0, (s, i) => s + i.qty);
  double get total => _items.fold(0.0, (s, i) => s + i.price * i.qty);

  void add(String itemId, String name, String category, double price) {
    final idx = _items.indexWhere((i) => i.itemId == itemId);
    if (idx >= 0) {
      _items[idx].qty++;
    } else {
      _items.add(CartItem(itemId: itemId, name: name, category: category, price: price));
    }
  }

  void remove(String itemId) {
    final idx = _items.indexWhere((i) => i.itemId == itemId);
    if (idx < 0) return;
    if (_items[idx].qty > 1) {
      _items[idx].qty--;
    } else {
      _items.removeAt(idx);
    }
  }

  int qtyFor(String itemId) =>
      _items.where((i) => i.itemId == itemId).fold(0, (s, i) => s + i.qty);

  Map<String, dynamic> toJson() => {
    'restaurantId': restaurantId,
    'restaurantName': restaurantName,
    'items': _items.map((i) => i.toJson()).toList(),
  };

  factory _RestaurantCart.fromJson(Map<String, dynamic> j) {
    final cart = _RestaurantCart(
      restaurantId: j['restaurantId'] as String,
      restaurantName: j['restaurantName'] as String,
    );
    for (final item in (j['items'] as List<dynamic>? ?? [])) {
      cart._items.add(CartItem.fromJson(item as Map<String, dynamic>));
    }
    return cart;
  }
}

class CartService {
  CartService._();

  static const _kKey = 'cart_data_v2';

  static final Map<String, _RestaurantCart> _carts = {};
  static String? _activeRestaurantId;

  // ── Active-restaurant (backward-compat) getters ──────────────────────────
  static String? get restaurantId => _activeRestaurantId;
  static String? get restaurantName =>
      _activeRestaurantId != null ? _carts[_activeRestaurantId]?.restaurantName : null;
  static List<CartItem> get items =>
      _activeRestaurantId != null ? (_carts[_activeRestaurantId]?.items ?? []) : [];
  static int get itemCount => items.fold(0, (s, i) => s + i.qty);
  static double get total => items.fold(0.0, (s, i) => s + i.price * i.qty);

  // ── Multi-restaurant getters ─────────────────────────────────────────────
  static int get totalItemCount =>
      _carts.values.fold(0, (s, c) => s + c.itemCount);
  static List<String> get restaurantIds =>
      _carts.keys.where((id) => _carts[id]!.items.isNotEmpty).toList();

  static List<CartItem> itemsForRestaurant(String id) =>
      _carts[id]?.items ?? [];
  static String? nameForRestaurant(String id) => _carts[id]?.restaurantName;
  static int countForRestaurant(String id) => _carts[id]?.itemCount ?? 0;
  static double totalForRestaurant(String id) => _carts[id]?.total ?? 0.0;

  static int qtyFor(String itemId) =>
      _activeRestaurantId != null
          ? (_carts[_activeRestaurantId]?.qtyFor(itemId) ?? 0)
          : 0;

  // ── Set active restaurant (called by menu screen on load) ────────────────
  static void setActive(String restaurantId) {
    _activeRestaurantId = restaurantId;
  }

  // ── Persistence ──────────────────────────────────────────────────────────
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Try new multi-restaurant format first
      final raw = prefs.getString(_kKey);
      if (raw != null) {
        final list = jsonDecode(raw) as List<dynamic>;
        _carts.clear();
        for (final entry in list) {
          final cart = _RestaurantCart.fromJson(entry as Map<String, dynamic>);
          if (cart.items.isNotEmpty) {
            _carts[cart.restaurantId] = cart;
          }
        }
        if (_carts.isNotEmpty) _activeRestaurantId = _carts.keys.first;
        return;
      }
      // Migrate from old single-restaurant format
      final oldRaw = prefs.getString('cart_data');
      if (oldRaw != null) {
        final json = jsonDecode(oldRaw) as Map<String, dynamic>;
        final restaurantId = json['restaurantId'] as String?;
        final restaurantName = json['restaurantName'] as String?;
        if (restaurantId != null && restaurantName != null) {
          final cart = _RestaurantCart(restaurantId: restaurantId, restaurantName: restaurantName);
          for (final item in (json['items'] as List<dynamic>? ?? [])) {
            cart._items.add(CartItem.fromJson(item as Map<String, dynamic>));
          }
          if (cart.items.isNotEmpty) {
            _carts[restaurantId] = cart;
            _activeRestaurantId = restaurantId;
            await _save();
            await prefs.remove('cart_data');
          }
        }
      }
    } catch (_) {}
  }

  static Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final nonEmpty = _carts.values.where((c) => c.items.isNotEmpty).toList();
      if (nonEmpty.isEmpty) {
        await prefs.remove(_kKey);
        return;
      }
      await prefs.setString(_kKey, jsonEncode(nonEmpty.map((c) => c.toJson()).toList()));
    } catch (_) {}
  }

  // ── Mutations ─────────────────────────────────────────────────────────────
  static void add(
    String restaurantId,
    String restaurantName,
    String itemId,
    String name,
    String category,
    double price,
  ) {
    _activeRestaurantId = restaurantId;
    _carts.putIfAbsent(
      restaurantId,
      () => _RestaurantCart(restaurantId: restaurantId, restaurantName: restaurantName),
    );
    _carts[restaurantId]!.add(itemId, name, category, price);
    _save();
  }

  static void remove(String itemId) {
    if (_activeRestaurantId == null) return;
    _carts[_activeRestaurantId]?.remove(itemId);
    if (_carts[_activeRestaurantId]?.items.isEmpty ?? false) {
      _carts.remove(_activeRestaurantId);
      _activeRestaurantId = _carts.isNotEmpty ? _carts.keys.first : null;
    }
    _save();
  }

  static void clearRestaurant(String restaurantId) {
    _carts.remove(restaurantId);
    if (_activeRestaurantId == restaurantId) {
      _activeRestaurantId = _carts.isNotEmpty ? _carts.keys.first : null;
    }
    _save();
  }

  static void clear() {
    _carts.clear();
    _activeRestaurantId = null;
    _save();
  }

  static List<Map<String, dynamic>> toOrderItems() =>
      items.map((i) => {'item_id': i.itemId, 'qty': i.qty}).toList();
}
