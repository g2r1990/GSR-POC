class Validators {
  // ── Patterns ────────────────────────────────────────────────────────────────

  static final _nameRe =
      RegExp(r"^[A-Za-z\s.\-']{2,100}$");

  static final _businessNameRe =
      RegExp(r"^[A-Za-z0-9\s&.,\-']{2,150}$");

  static final _areaRe =
      RegExp(r'^[A-Za-z0-9\s.\-,]{2,100}$');

  static final _stateRe =
      RegExp(r'^[A-Za-z\s]{2,100}$');

  static final _emailRe =
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static final _gstinRe =
      RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$');

  static final _addressRe =
      RegExp(r'^[A-Za-z0-9\s,.\-/()\#:]{5,}$');

  static final _itemRe =
      RegExp(r"^[A-Za-z0-9\s.,\-'&()]{2,150}$");

  static final _offerTitleRe =
      RegExp(r"^[A-Za-z0-9\s.,\-'&()%·]{2,200}$");

  // ── Public validators ────────────────────────────────────────────────────────

  static String? personName(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Required';
    if (!_nameRe.hasMatch(s)) {
      return 'Only letters, spaces, . or - are allowed';
    }
    return null;
  }

  static String? businessName(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Required';
    if (!_businessNameRe.hasMatch(s)) {
      return 'Only letters, numbers & basic punctuation allowed';
    }
    return null;
  }

  static String? mobile(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Required';
    if (s.length != 10) return 'Enter a valid 10-digit number';
    return null;
  }

  static String? pincode(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Required';
    if (s.length != 6) return 'Enter a valid 6-digit pincode';
    if (s[0] == '0') return 'Pincode cannot start with 0';
    return null;
  }

  static String? password(String? v) {
    final s = v ?? '';
    if (s.isEmpty) return 'Required';
    if (s.length < 8) return 'At least 8 characters required';
    if (!s.contains(RegExp(r'[A-Za-z]'))) {
      return 'Must contain at least one letter';
    }
    if (!s.contains(RegExp(r'[0-9]'))) {
      return 'Must contain at least one number';
    }
    return null;
  }

  static String? email(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return null; // optional
    if (!_emailRe.hasMatch(s)) return 'Enter a valid email address';
    return null;
  }

  static String? gstin(String? v) {
    final s = (v?.trim() ?? '').toUpperCase();
    if (s.isEmpty) return null; // optional
    if (s.length != 15) return 'GSTIN must be 15 characters';
    if (!_gstinRe.hasMatch(s)) {
      return 'Enter a valid GSTIN (e.g. 27AAXXX1234X1ZX)';
    }
    return null;
  }

  static String? address(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Required';
    if (s.length < 5) return 'Enter a complete address';
    if (!_addressRe.hasMatch(s)) {
      return 'Address contains invalid characters';
    }
    return null;
  }

  static String? area(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Required';
    if (!_areaRe.hasMatch(s)) {
      return 'Only letters, numbers and basic punctuation allowed';
    }
    return null;
  }

  static String? state(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Required';
    if (!_stateRe.hasMatch(s)) return 'Only letters and spaces allowed';
    return null;
  }

  static String? itemName(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Required';
    if (!_itemRe.hasMatch(s)) {
      return 'Only letters, numbers & basic punctuation allowed';
    }
    return null;
  }

  static String? offerTitle(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Required';
    if (!_offerTitleRe.hasMatch(s)) {
      return 'Only letters, numbers & basic punctuation allowed';
    }
    return null;
  }

  static String? discountPct(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return null; // optional
    final d = double.tryParse(s);
    if (d == null || d <= 0 || d > 100) {
      return 'Enter a value between 1 and 100';
    }
    return null;
  }

  static String? price(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Required';
    final d = double.tryParse(s);
    if (d == null) return 'Enter a valid price';
    if (d <= 0) return 'Price must be greater than 0';
    if (d > 100000) return 'Price seems too high';
    return null;
  }

  static String? confirmPassword(String? v, String original) {
    if (v != original) return 'Passwords do not match';
    return null;
  }
}
