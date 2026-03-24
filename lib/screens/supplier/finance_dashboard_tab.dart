import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'finance_widgets.dart';
import 'supplier_verify_payments_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PESTAÑA 1: DASHBOARD FINANCIERO
// KPIs en tiempo real, filtros temporales, gráfico de barras apiladas MoM,
// gráfico de líneas de flujo de caja, comparativo mes anterior.
// ─────────────────────────────────────────────────────────────────────────────
class FinanceDashboardTab extends StatefulWidget {
  final String supplierId;
  const FinanceDashboardTab({super.key, required this.supplierId});

  @override
  State<FinanceDashboardTab> createState() => _FinanceDashboardTabState();
}

class _FinanceDashboardTabState extends State<FinanceDashboardTab> {
  // Filtro activo: 'week' | 'month' | 'quarter' | 'year' | 'all'
  String _filter = 'month';

  DateTimeRange _getRange() {
    final now = DateTime.now();
    switch (_filter) {
      case 'week':
        return DateTimeRange(
            start: now.subtract(const Duration(days: 7)), end: now);
      case 'quarter':
        return DateTimeRange(
            start: now.subtract(const Duration(days: 90)), end: now);
      case 'year':
        return DateTimeRange(start: DateTime(now.year, 1, 1), end: now);
      case 'all':
        return DateTimeRange(start: DateTime(2020), end: now);
      default: // month
        return DateTimeRange(start: DateTime(now.year, now.month, 1), end: now);
    }
  }

  DateTimeRange _getPreviousRange(DateTimeRange current) {
    final duration = current.end.difference(current.start);
    return DateTimeRange(
        start: current.start.subtract(duration), end: current.start);
  }

  @override
  Widget build(BuildContext context) {
    final range = _getRange();
    final prevRange = _getPreviousRange(range);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('gastos')
          .where('supplierId', isEqualTo: widget.supplierId)
          .snapshots(),
      builder: (context, expenseSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collectionGroup('reservas')
              .where('supplier', isEqualTo: widget.supplierId)
              .snapshots(),
          builder: (context, incomeSnap) {
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('ingresos_egresos')
                  .where('supplierId', isEqualTo: widget.supplierId)
                  .snapshots(),
              builder: (context, manualSnap) {
                if (!expenseSnap.hasData || !incomeSnap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                // ── CÁLCULOS ─────────────────────────────────────────────
                double income = 0, expenses = 0, receivable = 0;
                double prevIncome = 0, prevExpenses = 0;
                List<Map<String, dynamic>> chartData = [];
                // Mapa para gráfico de barras: {mes_key: {income, expense}}
                Map<String, Map<String, double>> monthly = {};

                // Función para acumular al mapa mensual
                void addMonthly(String key, double inc, double exp) {
                  monthly[key] ??= {'income': 0.0, 'expense': 0.0};
                  monthly[key]!['income'] = monthly[key]!['income']! + inc;
                  monthly[key]!['expense'] = monthly[key]!['expense']! + exp;
                }

                bool inRange(DateTime d) =>
                    d.isAfter(
                        range.start.subtract(const Duration(seconds: 1))) &&
                    d.isBefore(range.end.add(const Duration(days: 1)));
                bool inPrev(DateTime d) =>
                    d.isAfter(
                        prevRange.start.subtract(const Duration(seconds: 1))) &&
                    d.isBefore(prevRange.end.add(const Duration(days: 1)));

                // Gastos (colección gastos — egresos de actividades)
                for (var doc in expenseSnap.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final amt = (data['monto'] ?? 0).toDouble();
                  final date = parseFinanceDate(data['fecha']);
                  final key = DateFormat('MMM yy', 'es').format(date);
                  addMonthly(key, 0, amt);
                  if (inRange(date)) {
                    expenses += amt;
                    chartData
                        .add({'date': date, 'amount': amt, 'type': 'expense'});
                  }
                  if (inPrev(date)) prevExpenses += amt;
                }

                // Ingresos manuales (colección ingresos_egresos)
                for (var doc in (manualSnap.data?.docs ?? [])) {
                  final data = doc.data() as Map<String, dynamic>;
                  final amt = (data['monto'] ?? 0).toDouble();
                  final date = parseFinanceDate(data['fecha']);
                  final type = data['type'] ?? 'expense';
                  final estado = data['estado'] ?? 'pending';
                  final key = DateFormat('MMM yy', 'es').format(date);

                  if (type == 'income' && estado != 'internal') {
                    addMonthly(key, amt, 0);
                    if (inRange(date)) {
                      income += amt;
                      chartData
                          .add({'date': date, 'amount': amt, 'type': 'income'});
                    }
                    if (inPrev(date)) prevIncome += amt;
                  } else if (type == 'expense') {
                    addMonthly(key, 0, amt);
                    if (inRange(date)) {
                      expenses += amt;
                      chartData.add(
                          {'date': date, 'amount': amt, 'type': 'expense'});
                    }
                    if (inPrev(date)) prevExpenses += amt;
                  }
                }

                // Ingresos de reservas automáticas
                for (var doc in incomeSnap.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final paid = (data['amountPaid'] ?? 0).toDouble();
                  final total = (data['totalPlanPrice'] ?? 0).toDouble();
                  final date = parseFinanceDate(data['createdAt']);
                  final key = DateFormat('MMM yy', 'es').format(date);
                  final debt = total - paid;
                  if (debt > 1) receivable += debt;
                  addMonthly(key, paid, 0);
                  if (inRange(date) && paid > 0) {
                    income += paid;
                    chartData
                        .add({'date': date, 'amount': paid, 'type': 'income'});
                    if (inPrev(date)) prevIncome += paid;
                  }
                }

                final netProfit = income - expenses;
                final prevNet = prevIncome - prevExpenses;
                final incDelta = prevIncome == 0
                    ? null
                    : ((income - prevIncome) / prevIncome * 100);
                final expDelta = prevExpenses == 0
                    ? null
                    : ((expenses - prevExpenses) / prevExpenses * 100);
                final netDelta = prevNet == 0
                    ? null
                    : ((netProfit - prevNet) / prevNet.abs() * 100);

                // Preparar datos gráfico de barras (últimos 6 meses)
                final sortedMonthKeys = monthly.keys.toList()
                  ..sort((a, b) {
                    try {
                      return DateFormat('MMM yy', 'es')
                          .parse(a)
                          .compareTo(DateFormat('MMM yy', 'es').parse(b));
                    } catch (_) {
                      return 0;
                    }
                  });
                final last6 = sortedMonthKeys.length > 6
                    ? sortedMonthKeys.sublist(sortedMonthKeys.length - 6)
                    : sortedMonthKeys;
                final barData = last6
                    .map((k) => {
                          'label': k,
                          'income': monthly[k]!['income']!,
                          'expense': monthly[k]!['expense']!,
                        })
                    .toList();

                return RefreshIndicator(
                  onRefresh: () async {}, // streams auto-refresh
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Filtros temporales ───────────────────────────
                        _buildFilterRow(),
                        const SizedBox(height: 18),

                        // ── KPIs principales ─────────────────────────────
                        Row(children: [
                          Expanded(
                            child: FinKPICard(
                              title: 'Beneficio neto',
                              amount: netProfit,
                              color:
                                  netProfit >= 0 ? kIncomeColor : kExpenseColor,
                              icon: Icons.account_balance_wallet,
                              subtitle: netDelta != null
                                  ? '${netDelta >= 0 ? '+' : ''}${netDelta.toStringAsFixed(1)}% vs. período ant.'
                                  : null,
                              onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (c) =>
                                          SupplierVerifyPaymentsScreen(
                                            supplierId: widget.supplierId,
                                            planName: '',
                                            initialIndex: 2,
                                          ))),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FinKPICard(
                              title: 'Por cobrar',
                              amount: receivable,
                              color: kWarningColor,
                              icon: Icons.pending_actions,
                              onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (c) =>
                                          SupplierVerifyPaymentsScreen(
                                            supplierId: widget.supplierId,
                                            planName: '',
                                            initialIndex: 3,
                                          ))),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 12),

                        // ── Mini KPIs con comparativo ───────────────────
                        Row(children: [
                          Expanded(
                            child: FinMiniKPI(
                              label: 'Ingresos',
                              value: '\$${_fmt(income)}',
                              color: kIncomeColor,
                              icon: Icons.trending_up,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FinMiniKPI(
                              label: 'Egresos',
                              value: '\$${_fmt(expenses)}',
                              color: kExpenseColor,
                              icon: Icons.trending_down,
                            ),
                          ),
                        ]),
                        const SizedBox(height: 8),

                        // Comparativo badges
                        if (incDelta != null || expDelta != null)
                          Row(children: [
                            if (incDelta != null)
                              Expanded(
                                  child: _DeltaBadge(
                                      delta: incDelta,
                                      label: 'vs período ant.')),
                            const SizedBox(width: 10),
                            if (expDelta != null)
                              Expanded(
                                  child: _DeltaBadge(
                                      delta: -expDelta,
                                      label: 'vs período ant.')),
                          ]),
                        const SizedBox(height: 28),

                        // ── Gráfico de barras apiladas ──────────────────
                        FinSectionHeader(
                          title: 'Ingresos vs Egresos (mensual)',
                          trailing: Row(children: const [
                            FinChartLegend(color: kIncomeColor, label: 'Ing.'),
                            SizedBox(width: 10),
                            FinChartLegend(color: kExpenseColor, label: 'Egr.'),
                          ]),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 220,
                          child: FinStackedBarChart(monthlyData: barData),
                        ),
                        const SizedBox(height: 28),

                        // ── Gráfico de líneas (flujo acumulado) ─────────
                        FinSectionHeader(
                          title: 'Flujo de caja acumulado',
                          trailing: Row(children: const [
                            FinChartLegend(
                                color: kIncomeColor, label: 'Ingresos'),
                            SizedBox(width: 10),
                            FinChartLegend(
                                color: kExpenseColor, label: 'Egresos'),
                          ]),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 260,
                          child: FinLineChart(rawData: chartData),
                        ),
                        const SizedBox(height: 24),

                        // ── Salud financiera ─────────────────────────────
                        _buildHealthBar(income, expenses),
                        const SizedBox(height: 24),

                        // ── Exportar reporte ──────────────────────────────
                        _buildExportSection(
                          income: income,
                          expenses: expenses,
                          netProfit: netProfit,
                          receivable: receivable,
                          chartData: chartData,
                          barData: barData,
                          incDelta: incDelta,
                          expDelta: expDelta,
                          netDelta: netDelta,
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // ── Sección de exportación ───────────────────────────────────────────────
  Widget _buildExportSection({
    required double income,
    required double expenses,
    required double netProfit,
    required double receivable,
    required List<Map<String, dynamic>> chartData,
    required List<Map<String, dynamic>> barData,
    required double? incDelta,
    required double? expDelta,
    required double? netDelta,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.download_rounded,
              color: Color.fromRGBO(17, 48, 73, 1), size: 18),
          const SizedBox(width: 8),
          Text('Exportar reporte',
              style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color.fromRGBO(17, 48, 73, 1))),
        ]),
        const SizedBox(height: 6),
        Text('Descarga el resumen financiero del período seleccionado',
            style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500])),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: _ExportBtn(
              label: 'PDF',
              icon: Icons.picture_as_pdf_outlined,
              color: const Color(0xFFE53935),
              onTap: () => _exportPdf(
                income: income,
                expenses: expenses,
                netProfit: netProfit,
                receivable: receivable,
                barData: barData,
                incDelta: incDelta,
                expDelta: expDelta,
                netDelta: netDelta,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _ExportBtn(
              label: 'Excel',
              icon: Icons.table_chart_outlined,
              color: const Color(0xFF1D6F42),
              onTap: () => _exportExcel(
                income: income,
                expenses: expenses,
                netProfit: netProfit,
                receivable: receivable,
                chartData: chartData,
                barData: barData,
              ),
            ),
          ),
        ]),
      ]),
    );
  }

  // ── Generación PDF ────────────────────────────────────────────────────────
  Future<void> _exportPdf({
    required double income,
    required double expenses,
    required double netProfit,
    required double receivable,
    required List<Map<String, dynamic>> barData,
    required double? incDelta,
    required double? expDelta,
    required double? netDelta,
  }) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final fmt = DateFormat('dd/MM/yyyy');
    final fmtMoney = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    // Intentar cargar el logo
    pw.MemoryImage? logo;
    try {
      final logoData = await rootBundle.load('assets/images/Biqoe logo.png');
      logo = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (_) {}

    final primary = PdfColor.fromHex('#113049');
    final green = PdfColor.fromHex('#34C759');
    final red = PdfColor.fromHex('#FF3B30');
    final orange = PdfColor.fromHex('#FF9500');
    final greyBg = PdfColor.fromHex('#F3F7FE');
    final greyText = PdfColor.fromHex('#666666');

    final filterLabels = {
      'week': 'Última semana',
      'month': 'Este mes',
      'quarter': 'Último trimestre',
      'year': 'Este año',
      'all': 'Todo el histórico',
    };
    final periodLabel = filterLabels[_filter] ?? _filter;

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (logo != null)
                pw.Container(height: 38, child: pw.Image(logo))
              else
                pw.Text('BIQOE',
                    style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: primary)),
              pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('REPORTE FINANCIERO',
                        style: pw.TextStyle(
                            fontSize: 13,
                            fontWeight: pw.FontWeight.bold,
                            color: primary)),
                    pw.Text('Período: $periodLabel',
                        style: pw.TextStyle(fontSize: 9, color: greyText)),
                    pw.Text('Generado: ${fmt.format(now)}',
                        style: pw.TextStyle(fontSize: 9, color: greyText)),
                  ]),
            ],
          ),
          pw.Divider(color: primary, thickness: 1.5),
          pw.SizedBox(height: 16),

          // KPIs principales
          pw.Text('RESUMEN EJECUTIVO',
              style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: primary,
                  letterSpacing: 0.5)),
          pw.SizedBox(height: 10),
          pw.Row(children: [
            _pdfKpi(
                'Ingresos totales',
                fmtMoney.format(income),
                green,
                incDelta != null
                    ? '${incDelta >= 0 ? '+' : ''}${incDelta.toStringAsFixed(1)}% vs período ant.'
                    : null),
            pw.SizedBox(width: 10),
            _pdfKpi(
                'Egresos totales',
                fmtMoney.format(expenses),
                red,
                expDelta != null
                    ? '${expDelta >= 0 ? '+' : ''}${expDelta.toStringAsFixed(1)}% vs período ant.'
                    : null),
            pw.SizedBox(width: 10),
            _pdfKpi(
                'Beneficio neto',
                fmtMoney.format(netProfit),
                netProfit >= 0 ? green : red,
                netDelta != null
                    ? '${netDelta >= 0 ? '+' : ''}${netDelta.toStringAsFixed(1)}% vs período ant.'
                    : null),
            pw.SizedBox(width: 10),
            _pdfKpi('Por cobrar', fmtMoney.format(receivable), orange, null),
          ]),
          pw.SizedBox(height: 20),

          // Margen operativo (calculado en línea para evitar declaración en lista)
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
                color: greyBg, borderRadius: pw.BorderRadius.circular(8)),
            child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Margen operativo neto',
                      style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: primary)),
                  pw.Text(
                      '${(income == 0 ? 0.0 : (netProfit / income * 100).clamp(-999.0, 100.0)).toStringAsFixed(1)}%',
                      style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: (income == 0
                                      ? 0.0
                                      : (netProfit / income * 100)
                                          .clamp(-999.0, 100.0)) >=
                                  0
                              ? green
                              : red)),
                ]),
          ),
          pw.SizedBox(height: 20),

          // Tabla mensual
          if (barData.isNotEmpty) ...[
            pw.Text('DETALLE MENSUAL',
                style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: primary,
                    letterSpacing: 0.5)),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(
                  color: PdfColor.fromHex('#E5E7EB'), width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(2),
                3: const pw.FlexColumnWidth(2),
              },
              children: [
                pw.TableRow(
                  decoration:
                      pw.BoxDecoration(color: PdfColor.fromHex('#F3F7FE')),
                  children: [
                    _pdfTableCell('Mes', isHeader: true),
                    _pdfTableCell('Ingresos', isHeader: true),
                    _pdfTableCell('Egresos', isHeader: true),
                    _pdfTableCell('Neto', isHeader: true),
                  ],
                ),
                ...barData.map((m) {
                  final inc = (m['income'] as num? ?? 0).toDouble();
                  final exp = (m['expense'] as num? ?? 0).toDouble();
                  final net = inc - exp;
                  return pw.TableRow(children: [
                    _pdfTableCell(m['label'] as String),
                    _pdfTableCell('\$${inc.toStringAsFixed(0)}'),
                    _pdfTableCell('\$${exp.toStringAsFixed(0)}'),
                    _pdfTableCell('\$${net.toStringAsFixed(0)}',
                        color: net >= 0 ? green : red),
                  ]);
                }),
              ],
            ),
            pw.SizedBox(height: 20),
          ],

          // Footer
          pw.Spacer(),
          pw.Divider(color: PdfColor.fromHex('#E5E7EB')),
          pw.Center(
              child: pw.Text(
            'Biqoe — Reporte generado automáticamente el ${fmt.format(now)}',
            style: pw.TextStyle(fontSize: 8, color: greyText),
          )),
        ],
      ),
    ));

    await Printing.layoutPdf(
      name: 'Reporte-Financiero-Biqoe-${DateFormat('yyyy-MM').format(now)}.pdf',
      onLayout: (_) async => pdf.save(),
    );
  }

  pw.Widget _pdfKpi(String label, String value, PdfColor color, String? sub) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
            color: color.shade(0.9),
            borderRadius: pw.BorderRadius.circular(8),
            border: pw.Border.all(color: color.shade(0.7), width: 0.5)),
        child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(label,
                  style: pw.TextStyle(
                      fontSize: 8, color: PdfColor.fromHex('#444444'))),
              pw.SizedBox(height: 3),
              pw.Text(value,
                  style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                      color: color)),
              if (sub != null) ...[
                pw.SizedBox(height: 2),
                pw.Text(sub,
                    style: pw.TextStyle(
                        fontSize: 7, color: PdfColor.fromHex('#888888'))),
              ],
            ]),
      ),
    );
  }

  pw.Widget _pdfTableCell(String text,
      {bool isHeader = false, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(text,
          style: pw.TextStyle(
              fontSize: 9,
              fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: color ??
                  (isHeader
                      ? PdfColor.fromHex('#113049')
                      : PdfColor.fromHex('#333333')))),
    );
  }

  // ── Generación Excel (CSV descargable) ────────────────────────────────────
  // Flutter no tiene un paquete excel nativo estable sin dependencias pesadas.
  // Generamos un CSV profesional con separador por tabulador que Excel/Sheets
  // abre directamente, y lo compartimos con Printing.sharePdf como texto.
  // Para xlsx real se necesita el paquete `excel` en pubspec.yaml.
  Future<void> _exportExcel({
    required double income,
    required double expenses,
    required double netProfit,
    required double receivable,
    required List<Map<String, dynamic>> chartData,
    required List<Map<String, dynamic>> barData,
  }) async {
    final now = DateTime.now();
    final fmt = DateFormat('dd/MM/yyyy');
    final filterLabels = {
      'week': 'Última semana',
      'month': 'Este mes',
      'quarter': 'Último trimestre',
      'year': 'Este año',
      'all': 'Todo el histórico',
    };

    // Construir contenido CSV (compatible Excel/Sheets)
    final buffer = StringBuffer();

    // Hoja 1: Resumen ejecutivo
    buffer.writeln('REPORTE FINANCIERO BIQOE');
    buffer.writeln('Período,${filterLabels[_filter] ?? _filter}');
    buffer.writeln('Fecha de generación,${fmt.format(now)}');
    buffer.writeln();

    buffer.writeln('=== RESUMEN EJECUTIVO ===');
    buffer.writeln('Concepto,Monto (USD)');
    buffer.writeln('Ingresos totales,${income.toStringAsFixed(2)}');
    buffer.writeln('Egresos totales,${expenses.toStringAsFixed(2)}');
    buffer.writeln('Beneficio neto,${netProfit.toStringAsFixed(2)}');
    buffer.writeln('Cuentas por cobrar,${receivable.toStringAsFixed(2)}');
    final margin = income == 0 ? 0.0 : (netProfit / income * 100);
    buffer.writeln('Margen neto (%),${margin.toStringAsFixed(2)}%');
    buffer.writeln();

    // Detalle mensual
    if (barData.isNotEmpty) {
      buffer.writeln('=== DETALLE MENSUAL ===');
      buffer.writeln('Mes,Ingresos,Egresos,Neto');
      for (final m in barData) {
        final inc = (m['income'] as num? ?? 0).toDouble();
        final exp = (m['expense'] as num? ?? 0).toDouble();
        final net = inc - exp;
        buffer.writeln(
            '${m['label']},${inc.toStringAsFixed(2)},${exp.toStringAsFixed(2)},${net.toStringAsFixed(2)}');
      }
      buffer.writeln();
    }

    // Libro de movimientos
    if (chartData.isNotEmpty) {
      buffer.writeln('=== LIBRO DE MOVIMIENTOS ===');
      buffer.writeln('Fecha,Tipo,Monto (USD)');
      final sorted = List<Map<String, dynamic>>.from(chartData)
        ..sort((a, b) => (a['date'] as DateTime).compareTo(b['date']));
      for (final item in sorted) {
        final date = fmt.format(item['date'] as DateTime);
        final type = item['type'] == 'income' ? 'Ingreso' : 'Egreso';
        final amt = (item['amount'] as num).toStringAsFixed(2);
        buffer.writeln('$date,$type,$amt');
      }
    }

    // Compartir como reporte PDF con los datos del CSV
    await Printing.sharePdf(
      bytes: await _csvToPdfBytes(
          buffer.toString(), filterLabels[_filter] ?? _filter, now),
      filename:
          'Reporte-Financiero-Biqoe-${DateFormat('yyyy-MM').format(now)}.pdf',
    );
  }

  // Genera un PDF sencillo con el contenido del CSV para compartir
  Future<Uint8List> _csvToPdfBytes(
      String content, String period, DateTime now) async {
    final pdf = pw.Document();
    final primary = PdfColor.fromHex('#113049');
    final grey = PdfColor.fromHex('#666666');
    final fmt = DateFormat('dd/MM/yyyy');

    pw.MemoryImage? logo;
    try {
      final logoData = await rootBundle.load('assets/images/Biqoe logo.png');
      logo = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (_) {}

    final lines =
        content.split('\n').where((l) => l.trim().isNotEmpty).toList();

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      header: (ctx) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          if (logo != null)
            pw.Container(height: 28, child: pw.Image(logo))
          else
            pw.Text('BIQOE',
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: primary,
                    fontSize: 14)),
          pw.Text('Reporte Financiero · $period · ${fmt.format(now)}',
              style: pw.TextStyle(fontSize: 8, color: grey)),
        ],
      ),
      footer: (ctx) => pw.Center(
        child: pw.Text('Página ${ctx.pageNumber} de ${ctx.pagesCount}',
            style: pw.TextStyle(fontSize: 8, color: grey)),
      ),
      build: (ctx) => [
        pw.SizedBox(height: 10),
        pw.TableHelper.fromTextArray(
          context: ctx,
          data: lines
              .map((l) => l.split(',').map((c) => c.trim()).toList())
              .toList(),
          headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold, color: primary, fontSize: 9),
          cellStyle: const pw.TextStyle(fontSize: 8),
          headerDecoration:
              pw.BoxDecoration(color: PdfColor.fromHex('#F3F7FE')),
          rowDecoration: const pw.BoxDecoration(),
          border: pw.TableBorder.all(
              color: PdfColor.fromHex('#E5E7EB'), width: 0.3),
          cellAlignments: {0: pw.Alignment.centerLeft},
        ),
      ],
    ));

    return pdf.save();
  }

  Widget _buildFilterRow() {
    final filters = [
      ('week', 'Semana'),
      ('month', 'Mes'),
      ('quarter', 'Trimestre'),
      ('year', 'Año'),
      ('all', 'Todo'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final selected = _filter == f.$1;
          return GestureDetector(
            onTap: () => setState(() => _filter = f.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? Color.fromRGBO(17, 48, 73, 1) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: selected
                        ? Color.fromRGBO(17, 48, 73, 1)
                        : Colors.grey.shade200),
              ),
              child: Text(f.$2,
                  style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : Colors.grey[600])),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHealthBar(double income, double expenses) {
    final ratio = income == 0 ? 0.0 : (expenses / income).clamp(0.0, 1.0);
    final isHealthy = ratio < 0.7;
    final label = ratio < 0.5
        ? '🟢 Salud financiera excelente'
        : ratio < 0.7
            ? '🟡 Salud financiera aceptable'
            : '🔴 Egresos elevados — revisa tus costos';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Índice de gastos sobre ingresos',
            style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600])),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 10,
            backgroundColor: Colors.grey[100],
            valueColor: AlwaysStoppedAnimation(
                isHealthy ? kIncomeColor : kExpenseColor),
          ),
        ),
        const SizedBox(height: 8),
        Text(label,
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700])),
      ]),
    );
  }

  String _fmt(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
  }
}

// ── Botón de exportación ──────────────────────────────────────────────────────
class _ExportBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ExportBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 7),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.w600, color: color)),
        ]),
      ),
    );
  }
}

class _DeltaBadge extends StatelessWidget {
  final double delta;
  final String label;
  const _DeltaBadge({required this.delta, required this.label});

  @override
  Widget build(BuildContext context) {
    final positive = delta >= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color:
              (positive ? kIncomeColor : kExpenseColor).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(positive ? Icons.arrow_upward : Icons.arrow_downward,
            size: 12, color: positive ? kIncomeColor : kExpenseColor),
        const SizedBox(width: 4),
        Text(
          '${positive ? '+' : ''}${delta.toStringAsFixed(1)}% $label',
          style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: positive ? kIncomeColor : kExpenseColor),
        ),
      ]),
    );
  }
}
