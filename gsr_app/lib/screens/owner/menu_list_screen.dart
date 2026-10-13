import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'add_edit_item_screen.dart';

class MenuListScreen extends StatefulWidget {
  final bool readOnly;
  const MenuListScreen({super.key, this.readOnly = false});

  @override
  State<MenuListScreen> createState() => _MenuListScreenState();
}

class _MenuListScreenState extends State<MenuListScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final items = await ApiService.getMenu();
      if (mounted) setState(() { _items = items; _loading = false; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Connection error'; _loading = false; });
    }
  }

  Map<String, List<Map<String, dynamic>>> get _grouped {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final item in _items) {
      final cat = item['category'] as String? ?? 'Other';
      map.putIfAbsent(cat, () => []).add(item);
    }
    return map;
  }

  Future<void> _toggle(Map<String, dynamic> item) async {
    try {
      await ApiService.toggleAvailability(item['id'] as String);
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Item'),
        content: Text('Remove "${item['name']}" from menu?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ApiService.deleteMenuItem(item['id'] as String);
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _openAddEdit({Map<String, dynamic>? item}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AddEditItemScreen(existing: item)),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final readOnly = widget.readOnly;
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(readOnly ? 'Menu (View Only)' : 'Menu'),
        backgroundColor: const Color(0xFF166534),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _load,
              tooltip: 'Refresh'),
        ],
      ),
      floatingActionButton: readOnly
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openAddEdit(),
              backgroundColor: const Color(0xFF166534),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Add Item'),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!,
                          style: const TextStyle(color: Color(0xFFDC2626))),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : _items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.restaurant_menu,
                              size: 64, color: Color(0xFF94A3B8)),
                          const SizedBox(height: 12),
                          const Text('No menu items yet.',
                              style: TextStyle(
                                  fontSize: 16, color: Color(0xFF64748B))),
                          const SizedBox(height: 8),
                          const Text('Tap + Add Item to get started.',
                              style: TextStyle(
                                  fontSize: 13, color: Color(0xFF94A3B8))),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                        children: [
                          if (readOnly)
                            Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: const Color(0xFFFDE68A)),
                              ),
                              child: const Row(children: [
                                Icon(Icons.lock_outline,
                                    size: 15, color: Color(0xFF92400E)),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'View only — turn off Accepting Orders to edit menu',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF92400E)),
                                  ),
                                ),
                              ]),
                            ),
                          ..._grouped.entries.map((entry) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                  child: Text(entry.key.toUpperCase(),
                                      style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1.2,
                                          color: Color(0xFF64748B))),
                                ),
                                ...entry.value
                                    .map((item) => _MenuItemCard(
                                          item: item,
                                          readOnly: readOnly,
                                          onToggle: () => _toggle(item),
                                          onEdit: () =>
                                              _openAddEdit(item: item),
                                          onDelete: () => _delete(item),
                                        ))
                                    .toList(),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
    );
  }
}

class _MenuItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool readOnly;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MenuItemCard({
    required this.item,
    this.readOnly = false,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isAvailable = item['is_available'] as bool? ?? true;
    final price = double.tryParse(item['price'].toString()) ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isAvailable
                ? const Color(0xFFE2E8F0)
                : const Color(0xFFFECACA)),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        title: Text(item['name'] as String? ?? '',
            style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isAvailable
                    ? const Color(0xFF0F172A)
                    : const Color(0xFF94A3B8))),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((item['description'] as String?)?.isNotEmpty == true)
              Text(item['description'] as String,
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF64748B)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            Text('₹${price.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF166534))),
          ],
        ),
        trailing: readOnly
            ? Icon(
                isAvailable ? Icons.check_circle : Icons.cancel,
                color: isAvailable
                    ? const Color(0xFF166534)
                    : const Color(0xFF94A3B8),
                size: 22,
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch(
                    value: isAvailable,
                    onChanged: (_) => onToggle(),
                    activeColor: const Color(0xFF166534),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'edit') onEdit();
                      if (v == 'delete') onDelete();
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                          value: 'edit',
                          child: Row(children: [
                            Icon(Icons.edit, size: 18),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ])),
                      const PopupMenuItem(
                          value: 'delete',
                          child: Row(children: [
                            Icon(Icons.delete, size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Remove', style: TextStyle(color: Colors.red)),
                          ])),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}
