import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../services/api_service.dart';

class OwnerReportsScreen extends StatefulWidget {
  const OwnerReportsScreen({super.key});

  @override
  State<OwnerReportsScreen> createState() => _OwnerReportsScreenState();
}

class _OwnerReportsScreenState extends State<OwnerReportsScreen> {
  static const _green = Color(0xFF166534);
  static const _amber = Color(0xFFD97706);

  int _preset = 0; // 0 = Last 7 Days, 1 = Last Month, 2 = Custom
  late DateTime _from;
  late DateTime _to;

  Map<String, dynamic>? _report;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _setPreset(0, fetch: false);
    _fetch();
  }

  void _setPreset(int preset, {bool fetch = true}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime from, to;
    switch (preset) {
      case 1: // Last Month
        from = DateTime(now.month == 1 ? now.year - 1 : now.year,
            now.month == 1 ? 12 : now.month - 1, 1);
        to = DateTime(now.year, now.month, 1).subtract(const Duration(days: 1));
        break;
      default: // Last 7 Days
        from = today.subtract(const Duration(days: 6));
        to = today;
    }
    setState(() {
      _preset = preset;
      _from = from;
      _to = to;
      _report = null;
      _error = null;
    });
    if (fetch) _fetch();
  }

  Future<void> _pickCustom() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _from, end: _to),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: _green),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _preset = 2;
        _from = picked.start;
        _to = picked.end;
        _report = null;
        _error = null;
      });
      _fetch();
    }
  }

  String _iso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiService.getOwnerReport(
        fromDate: _iso(_from),
        toDate: _iso(_to),
      );
      if (mounted) setState(() { _report = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  String _fmtRangeLabel() {
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    String f(DateTime d) => '${d.day} ${m[d.month - 1]} ${d.year}';
    return '${f(_from)} – ${f(_to)}';
  }

  String _fmtDay(String iso) {
    try {
      final d = DateTime.parse(iso);
      const wd = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
      const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${wd[d.weekday - 1]} ${d.day} ${m[d.month - 1]}';
    } catch (_) { return iso; }
  }

  String _rs(dynamic v) => 'Rs.${(v as num).toStringAsFixed(2)}';

  Future<void> _generatePdf() async {
    final report = _report;
    if (report == null) return;

    final rows = (report['rows'] as List).cast<Map<String, dynamic>>();
    final totals = report['totals'] as Map<String, dynamic>;
    final restaurantName = report['restaurant_name'] as String? ?? '';

    final baseFont = await PdfGoogleFonts.notoSansRegular();
    final boldFont = await PdfGoogleFonts.notoSansBold();

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: baseFont, bold: boldFont),
    );

    const headerBg = PdfColor.fromInt(0xFF166534);
    const totalBg = PdfColor.fromInt(0xFFDCFCE7);
    const borderColor = PdfColor.fromInt(0xFFD1FAE5);

    List<String> _rowCells(Map<String, dynamic> r) => [
      _fmtDay(r['date'] as String),
      '${r['orders']}',
      'Rs.${(r['item_subtotal'] as num).toStringAsFixed(0)}',
      (r['discount'] as num) > 0
          ? '-Rs.${(r['discount'] as num).toStringAsFixed(0)}' : '—',
      'Rs.${(r['total_food_cost'] as num).toStringAsFixed(0)}',
      'Rs.${(r['gst'] as num).toStringAsFixed(2)}',
      'Rs.${(r['delivery'] as num).toStringAsFixed(0)}',
      'Rs.${(r['customer_paid'] as num).toStringAsFixed(0)}',
      'Rs.${(r['bossbite_fee'] as num).toStringAsFixed(0)}',
      'Rs.${(r['restaurant_earnings'] as num).toStringAsFixed(0)}',
    ];

    List<String> _totalCells() => [
      'TOTAL', '${totals['orders']}',
      'Rs.${(totals['item_subtotal'] as num).toStringAsFixed(0)}',
      (totals['discount'] as num) > 0
          ? '-Rs.${(totals['discount'] as num).toStringAsFixed(0)}' : '—',
      'Rs.${(totals['total_food_cost'] as num).toStringAsFixed(0)}',
      'Rs.${(totals['gst'] as num).toStringAsFixed(2)}',
      'Rs.${(totals['delivery'] as num).toStringAsFixed(0)}',
      'Rs.${(totals['customer_paid'] as num).toStringAsFixed(0)}',
      'Rs.${(totals['bossbite_fee'] as num).toStringAsFixed(0)}',
      'Rs.${(totals['restaurant_earnings'] as num).toStringAsFixed(0)}',
    ];

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(28),
      build: (ctx) => [
        // ── Header ──────────────────────────────────────────────────────────
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('BossBite — Business Report',
                  style: pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold,
                      color: headerBg)),
              pw.SizedBox(height: 3),
              pw.Text(restaurantName,
                  style: pw.TextStyle(fontSize: 12,
                      color: const PdfColor.fromInt(0xFF374151))),
              pw.Text('Period: ${_fmtRangeLabel()}',
                  style: pw.TextStyle(fontSize: 10,
                      color: const PdfColor.fromInt(0xFF6B7280))),
            ]),
            pw.Text(
              'Generated: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
              style: pw.TextStyle(fontSize: 9,
                  color: const PdfColor.fromInt(0xFF6B7280))),
          ],
        ),
        pw.SizedBox(height: 14),

        // ── Summary boxes ───────────────────────────────────────────────────
        pw.Row(children: [
          _pdfSummaryBox('Total Orders', '${totals['orders']}', boldFont),
          pw.SizedBox(width: 8),
          _pdfSummaryBox('Total Food Cost',
              'Rs.${(totals['total_food_cost'] as num).toStringAsFixed(0)}', boldFont),
          pw.SizedBox(width: 8),
          _pdfSummaryBox('GST (5% of Total Food Cost)',
              'Rs.${(totals['gst'] as num).toStringAsFixed(2)}', boldFont),
          pw.SizedBox(width: 8),
          _pdfSummaryBox('BossBite Platform Fee (15%)',
              'Rs.${(totals['bossbite_fee'] as num).toStringAsFixed(0)}', boldFont),
          pw.SizedBox(width: 8),
          _pdfSummaryBox('Restaurant Earnings',
              'Rs.${(totals['restaurant_earnings'] as num).toStringAsFixed(0)}', boldFont,
              highlight: true),
        ]),
        pw.SizedBox(height: 18),

        // ── Daily table ─────────────────────────────────────────────────────
        pw.Text('Daily Breakdown',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(color: borderColor, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(2.1),
            1: const pw.FlexColumnWidth(0.9),
            2: const pw.FlexColumnWidth(1.5),
            3: const pw.FlexColumnWidth(1.4),
            4: const pw.FlexColumnWidth(1.7),
            5: const pw.FlexColumnWidth(1.3),
            6: const pw.FlexColumnWidth(1.2),
            7: const pw.FlexColumnWidth(1.5),
            8: const pw.FlexColumnWidth(2.0),
            9: const pw.FlexColumnWidth(2.0),
          },
          children: [
            // Header
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: headerBg),
              children: [
                'Date', 'Orders', 'Item\nSubtotal', 'Discount',
                'Total Food\nCost', 'GST\n(5%)', 'Delivery', 'Customer\nPaid',
                'BossBite Platform\nFee (15%)', 'Restaurant\nEarnings',
              ].map((h) => _pdfCell(h, bold: true, textColor: PdfColors.white,
                  bg: headerBg)).toList(),
            ),
            // Data rows
            ...rows.map((r) => pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.white),
              children: _rowCells(r).map((c) => _pdfCell(c)).toList(),
            )),
            // Totals row
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: totalBg),
              children: _totalCells()
                  .map((c) => _pdfCell(c, bold: true, textColor: const PdfColor.fromInt(0xFF166534)))
                  .toList(),
            ),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Text(
          'Restaurant Earnings = 85% of Total Food Cost + Delivery Fee  |  '
          'BossBite Platform Fee = 15% of Total Food Cost  |  '
          'GST collected is to be remitted to Government.',
          style: pw.TextStyle(fontSize: 7.5,
              color: const PdfColor.fromInt(0xFF6B7280)),
        ),
      ],
    ));

    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name: 'BossBite_Report_${_iso(_from)}_to_${_iso(_to)}',
    );
  }

  pw.Widget _pdfSummaryBox(String label, String value, pw.Font bold,
      {bool highlight = false}) {
    final bg = highlight
        ? const PdfColor.fromInt(0xFF166534)
        : const PdfColor.fromInt(0xFFECFDF5);
    final valColor = highlight ? PdfColors.white : const PdfColor.fromInt(0xFF166534);
    final lblColor = highlight ? const PdfColor.fromInt(0xFFBBF7D0) : const PdfColor.fromInt(0xFF6B7280);
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          color: bg,
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(color: const PdfColor.fromInt(0xFFD1FAE5), width: 0.5),
        ),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(value,
              style: pw.TextStyle(font: bold, fontSize: 12, color: valColor)),
          pw.SizedBox(height: 3),
          pw.Text(label,
              style: pw.TextStyle(fontSize: 7.5, color: lblColor)),
        ]),
      ),
    );
  }

  pw.Widget _pdfCell(String text,
      {bool bold = false, PdfColor? textColor, PdfColor? bg}) {
    return pw.Container(
      color: bg,
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: pw.Text(text,
          style: pw.TextStyle(
            fontSize: 8,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: textColor ?? PdfColors.black,
          ),
          textAlign: pw.TextAlign.center),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = (_report?['rows'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final totals = _report?['totals'] as Map<String, dynamic>?;
    final hasData = rows.isNotEmpty && totals != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        title: const Text('Reports'),
        actions: [
          if (hasData)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              tooltip: 'Download / Print PDF',
              onPressed: _generatePdf,
            ),
        ],
      ),
      body: Column(children: [
        // ── Date range selector ────────────────────────────────────────────
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              _PresetBtn(label: 'Last 7 Days', selected: _preset == 0,
                  onTap: () => _setPreset(0)),
              const SizedBox(width: 8),
              _PresetBtn(label: 'Last Month', selected: _preset == 1,
                  onTap: () => _setPreset(1)),
              const SizedBox(width: 8),
              _PresetBtn(label: 'Custom Range', selected: _preset == 2,
                  onTap: _pickCustom),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.date_range, size: 13, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              Text(_fmtRangeLabel(),
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            ]),
          ]),
        ),

        // ── Body ──────────────────────────────────────────────────────────
        if (_loading)
          const Expanded(child: Center(
              child: CircularProgressIndicator(color: _green)))
        else if (_error != null)
          Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 40),
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
            const SizedBox(height: 12),
            TextButton(onPressed: _fetch, child: const Text('Retry')),
          ])))
        else if (!hasData)
          Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            const Text('No delivered orders in this period',
                style: TextStyle(fontSize: 15, color: Color(0xFF6B7280))),
          ])))
        else
          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Summary cards
              Row(children: [
                Expanded(child: _SummCard(label: 'Total Orders',
                    value: '${totals!['orders']}',
                    icon: Icons.receipt_long, color: _green)),
                const SizedBox(width: 10),
                Expanded(child: _SummCard(label: 'Customer Paid',
                    value: _rs(totals['customer_paid']),
                    icon: Icons.payments_outlined, color: _amber)),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _SummCard(label: 'Restaurant Earnings',
                    value: _rs(totals['restaurant_earnings']),
                    icon: Icons.account_balance_wallet_outlined,
                    color: const Color(0xFF059669))),
                const SizedBox(width: 10),
                Expanded(child: _SummCard(label: 'BossBite Platform Fee',
                    value: _rs(totals['bossbite_fee']),
                    icon: Icons.store_outlined,
                    color: const Color(0xFF7C3AED))),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _SummCard(label: 'GST (5% of Total Food Cost)',
                    value: _rs(totals['gst']),
                    icon: Icons.account_balance_outlined,
                    color: const Color(0xFF0891B2))),
                const SizedBox(width: 10),
                Expanded(child: _SummCard(label: 'Total Food Cost',
                    value: _rs(totals['total_food_cost']),
                    icon: Icons.restaurant_menu,
                    color: const Color(0xFFD97706))),
              ]),
              const SizedBox(height: 20),

              // Daily table header row
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Daily Breakdown',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A))),
                ElevatedButton.icon(
                  onPressed: _generatePdf,
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 15),
                  label: const Text('Download PDF', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ]),
              const SizedBox(height: 10),

              // Horizontal scrollable table
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: _DailyTable(rows: rows, fmtDay: _fmtDay),
              ),
              const SizedBox(height: 12),

              // Finance note
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: const Text(
                  'Restaurant Earnings = 85% of Total Food Cost + Delivery Fee  •  '
                  'BossBite Platform Fee = 15% of Total Food Cost  •  '
                  'GST collected is to be remitted to Government.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF166534)),
                ),
              ),
            ]),
          )),
      ]),
    );
  }
}

// ── Preset button ──────────────────────────────────────────────────────────────

class _PresetBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _PresetBtn({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF166534) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFF166534) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : const Color(0xFF374151),
            )),
      ),
    );
  }
}

// ── Summary card ───────────────────────────────────────────────────────────────

class _SummCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _SummCard({required this.label, required this.value,
      required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
          Text(label,
              style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
              maxLines: 2, overflow: TextOverflow.ellipsis),
        ])),
      ]),
    );
  }
}

// ── Daily breakdown table ──────────────────────────────────────────────────────

class _DailyTable extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  final String Function(String) fmtDay;
  const _DailyTable({required this.rows, required this.fmtDay});

  static const _hdr = Color(0xFF166534);
  static const _hdrFg = Colors.white;

  @override
  Widget build(BuildContext context) {
    // Compute totals
    final t = <String, num>{};
    final keys = ['orders', 'item_subtotal', 'discount', 'total_food_cost',
        'gst', 'delivery', 'customer_paid', 'bossbite_fee', 'restaurant_earnings'];
    for (final k in keys) t[k] = 0;
    for (final r in rows) {
      for (final k in keys) {
        t[k] = t[k]! + (r[k] as num);
      }
    }

    String rs(num v) => '₹${v.toStringAsFixed(v % 1 == 0 ? 0 : 2)}';

    Widget hCell(String text) => Container(
      color: _hdr,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Text(text,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
              color: _hdrFg),
          textAlign: TextAlign.center),
    );

    Widget dCell(String text, {Color? fg, bool bold = false}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: Text(text,
          style: TextStyle(fontSize: 11, color: fg ?? const Color(0xFF374151),
              fontWeight: bold ? FontWeight.w700 : FontWeight.normal),
          textAlign: TextAlign.center),
    );

    Widget totCell(String text) => Container(
      color: const Color(0xFFDCFCE7),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Text(text,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
              color: Color(0xFF166534)),
          textAlign: TextAlign.center),
    );

    return Table(
      border: TableBorder.all(color: const Color(0xFFE2E8F0)),
      defaultColumnWidth: const IntrinsicColumnWidth(),
      children: [
        // Header
        TableRow(children: [
          hCell('Date'), hCell('Orders'), hCell('Item\nSubtotal'),
          hCell('Discount'), hCell('Total Food\nCost'), hCell('GST\n(5%)'),
          hCell('Delivery'), hCell('Customer\nPaid'),
          hCell('BossBite Platform\nFee (15%)'), hCell('Restaurant\nEarnings'),
        ]),
        // Data rows
        ...rows.map((r) {
          final disc = r['discount'] as num;
          return TableRow(children: [
            dCell(fmtDay(r['date'] as String), bold: true),
            dCell('${r['orders']}'),
            dCell(rs(r['item_subtotal'] as num)),
            dCell(disc > 0 ? '-${rs(disc)}' : '—',
                fg: disc > 0 ? const Color(0xFF166534) : null),
            dCell(rs(r['total_food_cost'] as num)),
            dCell(rs(r['gst'] as num)),
            dCell(rs(r['delivery'] as num)),
            dCell(rs(r['customer_paid'] as num), bold: true),
            dCell(rs(r['bossbite_fee'] as num),
                fg: const Color(0xFF7C3AED)),
            dCell(rs(r['restaurant_earnings'] as num),
                fg: const Color(0xFF166534), bold: true),
          ]);
        }),
        // Totals row
        TableRow(children: [
          totCell('TOTAL'), totCell('${t['orders']}'),
          totCell(rs(t['item_subtotal']!)),
          totCell(t['discount']! > 0 ? '-${rs(t['discount']!)}' : '—'),
          totCell(rs(t['total_food_cost']!)),
          totCell(rs(t['gst']!)),
          totCell(rs(t['delivery']!)),
          totCell(rs(t['customer_paid']!)),
          totCell(rs(t['bossbite_fee']!)),
          totCell(rs(t['restaurant_earnings']!)),
        ]),
      ],
    );
  }
}
