// Typed models for order API responses.
// These match backend/app/schemas/order.py exactly.
// Use fromJson when reading order data to get a compile-time field-name check
// instead of silent null from a typo in a Map<String, dynamic> key.
//
// Root cause of Build #39 billing bug: item['quantity'] used instead of item['qty'].
// A typed model makes that a compile error instead of a runtime null.

class OrderItemSnapshot {
  final String itemId;
  final String name;
  final String category;
  final double price;
  final int qty;
  final double subtotal;
  final String? spiceLevel;
  final String? itemNotes;

  const OrderItemSnapshot({
    required this.itemId,
    required this.name,
    required this.category,
    required this.price,
    required this.qty,
    required this.subtotal,
    this.spiceLevel,
    this.itemNotes,
  });

  factory OrderItemSnapshot.fromJson(Map<String, dynamic> j) =>
      OrderItemSnapshot(
        itemId: j['item_id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        category: j['category'] as String? ?? '',
        price: (j['price'] as num?)?.toDouble() ?? 0.0,
        qty: (j['qty'] as num?)?.toInt() ?? 0,
        subtotal: (j['subtotal'] as num?)?.toDouble() ?? 0.0,
        spiceLevel: j['spice_level'] as String?,
        itemNotes: j['item_notes'] as String?,
      );
}

class OrderResponse {
  final String id;
  final String shortId;
  final String restaurantId;
  final String customerName;
  final String customerPhone;
  final String? customerArea;
  final String orderType;
  final String? deliveryAddress;
  final List<OrderItemSnapshot> items;
  final double foodTotal;
  final double restaurantDiscount;
  final double gstRate;
  final double gstAmount;
  final double deliveryFee;
  final double riderTip;
  final double customerPays;
  final double total;
  final double discountAmount;
  final String offerCode;
  final String paymentMethod;
  final String? deliveryPin;
  final String? pickupCode;
  final String status;
  final int? rating;
  final String createdAt;

  const OrderResponse({
    required this.id,
    required this.shortId,
    required this.restaurantId,
    required this.customerName,
    required this.customerPhone,
    this.customerArea,
    required this.orderType,
    this.deliveryAddress,
    required this.items,
    required this.foodTotal,
    required this.restaurantDiscount,
    required this.gstRate,
    required this.gstAmount,
    required this.deliveryFee,
    required this.riderTip,
    required this.customerPays,
    required this.total,
    required this.discountAmount,
    required this.offerCode,
    required this.paymentMethod,
    this.deliveryPin,
    this.pickupCode,
    required this.status,
    this.rating,
    required this.createdAt,
  });

  factory OrderResponse.fromJson(Map<String, dynamic> j) => OrderResponse(
        id: j['id'] as String? ?? '',
        shortId: j['short_id'] as String? ?? '',
        restaurantId: j['restaurant_id'] as String? ?? '',
        customerName: j['customer_name'] as String? ?? '',
        customerPhone: j['customer_phone'] as String? ?? '',
        customerArea: j['customer_area'] as String?,
        orderType: j['order_type'] as String? ?? 'delivery',
        deliveryAddress: j['delivery_address'] as String?,
        items: (j['items'] as List<dynamic>? ?? [])
            .map((e) => OrderItemSnapshot.fromJson(e as Map<String, dynamic>))
            .toList(),
        foodTotal: (j['food_total'] as num?)?.toDouble() ?? 0.0,
        restaurantDiscount: (j['restaurant_discount'] as num?)?.toDouble() ?? 0.0,
        gstRate: (j['gst_rate'] as num?)?.toDouble() ?? 0.0,
        gstAmount: (j['gst_amount'] as num?)?.toDouble() ?? 0.0,
        deliveryFee: (j['delivery_fee'] as num?)?.toDouble() ?? 0.0,
        riderTip: (j['rider_tip'] as num?)?.toDouble() ?? 0.0,
        customerPays: (j['customer_pays'] as num?)?.toDouble() ?? 0.0,
        total: (j['total'] as num?)?.toDouble() ?? 0.0,
        discountAmount: (j['discount_amount'] as num?)?.toDouble() ?? 0.0,
        offerCode: j['offer_code'] as String? ?? '',
        paymentMethod: j['payment_method'] as String? ?? 'online',
        deliveryPin: j['delivery_pin'] as String?,
        pickupCode: j['pickup_code'] as String?,
        status: j['status'] as String? ?? 'placed',
        rating: (j['rating'] as num?)?.toInt(),
        createdAt: j['created_at'] as String? ?? '',
      );
}

// Valid order status values — mirrors backend OrderStatus enum in schemas/order.py
enum OrderStatus {
  placed,
  accepted,
  ready,
  riderAssigned,
  outForDelivery,
  delivered,
  readyForPickup,
  collected,
  cancelled;

  String get value {
    switch (this) {
      case OrderStatus.placed:         return 'placed';
      case OrderStatus.accepted:       return 'accepted';
      case OrderStatus.ready:          return 'ready';
      case OrderStatus.riderAssigned:  return 'rider_assigned';
      case OrderStatus.outForDelivery: return 'out_for_delivery';
      case OrderStatus.delivered:      return 'delivered';
      case OrderStatus.readyForPickup: return 'ready_for_pickup';
      case OrderStatus.collected:      return 'collected';
      case OrderStatus.cancelled:      return 'cancelled';
    }
  }

  static OrderStatus fromString(String s) {
    switch (s) {
      case 'placed':           return OrderStatus.placed;
      case 'accepted':         return OrderStatus.accepted;
      case 'ready':            return OrderStatus.ready;
      case 'rider_assigned':   return OrderStatus.riderAssigned;
      case 'out_for_delivery': return OrderStatus.outForDelivery;
      case 'delivered':        return OrderStatus.delivered;
      case 'ready_for_pickup': return OrderStatus.readyForPickup;
      case 'collected':        return OrderStatus.collected;
      case 'cancelled':        return OrderStatus.cancelled;
      default:                 return OrderStatus.placed;
    }
  }
}
