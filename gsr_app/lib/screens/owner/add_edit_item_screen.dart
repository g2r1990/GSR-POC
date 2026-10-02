import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_service.dart';
import '../../utils/validators.dart';

class AddEditItemScreen extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const AddEditItemScreen({super.key, this.existing});

  @override
  State<AddEditItemScreen> createState() => _AddEditItemScreenState();
}

class _AddEditItemScreenState extends State<AddEditItemScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtr;
  late final TextEditingController _categoryCtr;
  late final TextEditingController _descCtr;
  late final TextEditingController _priceCtr;
  bool _loading = false;
  String? _error;

  static const _categories = [
    'Starters', 'Main Course', 'Breads', 'Rice & Biryani',
    'Desserts', 'Beverages', 'Snacks', 'Other',
  ];

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtr = TextEditingController(text: e?['name'] as String? ?? '');
    _categoryCtr = TextEditingController(text: e?['category'] as String? ?? '');
    _descCtr = TextEditingController(text: e?['description'] as String? ?? '');
    final price = e?['price'];
    _priceCtr = TextEditingController(
        text: price != null
            ? double.tryParse(price.toString())?.toStringAsFixed(2) ?? ''
            : '');
  }

  @override
  void dispose() {
    _nameCtr.dispose();
    _categoryCtr.dispose();
    _descCtr.dispose();
    _priceCtr.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    final payload = {
      'name': _nameCtr.text.trim(),
      'category': _categoryCtr.text.trim(),
      'description': _descCtr.text.trim().isEmpty ? null : _descCtr.text.trim(),
      'price': double.parse(_priceCtr.text.trim()),
    };

    try {
      if (_isEdit) {
        await ApiService.updateMenuItem(
            widget.existing!['id'] as String, payload);
      } else {
        await ApiService.addMenuItem(payload);
      }
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Connection error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Item' : 'Add Item'),
        backgroundColor: const Color(0xFF166534),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label('Item Name'),
                _field(_nameCtr, 'e.g. Paneer Tikka',
                    validator: Validators.itemName),
                const SizedBox(height: 16),

                _label('Category'),
                _autocompleteField(),
                const SizedBox(height: 16),

                _label('Description (optional)'),
                TextFormField(
                  controller: _descCtr,
                  maxLines: 2,
                  decoration: _deco('Short description'),
                ),
                const SizedBox(height: 16),

                _label('Price (₹)'),
                TextFormField(
                  controller: _priceCtr,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                  decoration: _deco('0.00'),
                  validator: Validators.price,
                ),

                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Text(_error!,
                        style:
                            const TextStyle(color: Color(0xFFDC2626))),
                  ),
                ],

                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF166534),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(_isEdit ? 'Save Changes' : 'Add to Menu',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151))),
      );

  Widget _field(TextEditingController ctr, String hint,
          {String? Function(String?)? validator}) =>
      TextFormField(
        controller: ctr,
        decoration: _deco(hint),
        validator: validator,
      );

  Widget _autocompleteField() => Autocomplete<String>(
        initialValue: TextEditingValue(text: _categoryCtr.text),
        optionsBuilder: (v) => _categories
            .where((c) => c.toLowerCase().contains(v.text.toLowerCase())),
        onSelected: (v) => _categoryCtr.text = v,
        fieldViewBuilder: (ctx, ctr, focusNode, onSubmit) {
          _categoryCtr.text = ctr.text;
          return TextFormField(
            controller: ctr,
            focusNode: focusNode,
            decoration: _deco('e.g. Main Course'),
            validator: Validators.itemName,
            onChanged: (v) => _categoryCtr.text = v,
          );
        },
      );

  InputDecoration _deco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: Color(0xFF166534), width: 2)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFDC2626))),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: Color(0xFFDC2626), width: 2)),
      );
}
