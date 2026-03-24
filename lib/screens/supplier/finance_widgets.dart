import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ── Colores y constantes ────────────────────────────────────────────────────
const Color kPrimaryColor = Color.fromRGBO(17, 48, 73, 1);
const Color kIncomeColor = Color(0xFF34C759);
const Color kExpenseColor = Color(0xFFFF3B30);
const Color kWarningColor = Color(0xFFFF9500);
const Color kPendingColor = Color(0xFFFFCC00);
const Color kInternalColor = Color(0xFF007AFF);
const Color kBackgroundColor = Color(0xFFF3F7FE);

// Estado de una transacción manual
enum TxStatus { verified, pending, internal }

extension TxStatusExt on TxStatus {
  String get label {
    switch (this) {
      case TxStatus.verified:
        return 'Verificado';
      case TxStatus.pending:
        return 'Pendiente';
      case TxStatus.internal:
        return 'Movimiento interno';
    }
  }

  Color get color {
    switch (this) {
      case TxStatus.verified:
        return kIncomeColor;
      case TxStatus.pending:
        return kPendingColor;
      case TxStatus.internal:
        return kInternalColor;
    }
  }

  IconData get icon {
    switch (this) {
      case TxStatus.verified:
        return Icons.check_circle;
      case TxStatus.pending:
        return Icons.access_time;
      case TxStatus.internal:
        return Icons.swap_horiz;
    }
  }

  static TxStatus fromString(String? s) {
    switch (s) {
      case 'verified':
        return TxStatus.verified;
      case 'internal':
        return TxStatus.internal;
      default:
        return TxStatus.pending;
    }
  }
}

// Helper de fechas
DateTime parseFinanceDate(dynamic value, {DateTime? fallback}) {
  if (value == null) return fallback ?? DateTime(2000);
  if (value is DateTime) return value;
  if (value is Timestamp) return value.toDate();
  if (value is String && value.isNotEmpty) {
    try {
      return DateTime.parse(value);
    } catch (_) {}
  }
  return fallback ?? DateTime(2000);
}

// ─────────────────────────────────────────────────────────────────────────────
// KPI CARD grande (clickable, coloreado)
// ─────────────────────────────────────────────────────────────────────────────
class FinKPICard extends StatelessWidget {
  final String title;
  final double amount;
  final Color color;
  final IconData icon;
  final String? subtitle;
  final VoidCallback? onTap;

  const FinKPICard({
    super.key,
    required this.title,
    required this.amount,
    required this.color,
    required this.icon,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: color.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 6))
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, color: Colors.white, size: 17),
            ),
            if (onTap != null)
              const Icon(Icons.arrow_forward, color: Colors.white54, size: 15),
          ]),
          const SizedBox(height: 14),
          Text(
            NumberFormat.currency(symbol: '\$', decimalDigits: 0)
                .format(amount),
            style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
          ),
          Text(title,
              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11)),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(subtitle!,
                style: GoogleFonts.poppins(
                    color: Colors.white60,
                    fontSize: 10,
                    fontWeight: FontWeight.w500)),
          ]
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MINI KPI (blanco, pequeño)
// ─────────────────────────────────────────────────────────────────────────────
class FinMiniKPI extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData? icon;

  const FinMiniKPI({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        if (icon != null) ...[
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
        ],
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style:
                    GoogleFonts.poppins(fontSize: 10, color: Colors.grey[500])),
            const SizedBox(height: 2),
            Text(value,
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold, fontSize: 14, color: color)),
          ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BADGE de estado de transacción
// ─────────────────────────────────────────────────────────────────────────────
class TxStatusBadge extends StatelessWidget {
  final TxStatus status;
  const TxStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: status.color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(status.icon, size: 11, color: status.color),
        const SizedBox(width: 4),
        Text(status.label,
            style: GoogleFonts.poppins(
                fontSize: 10,
                color: status.color,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LEYENDA para gráficos
// ─────────────────────────────────────────────────────────────────────────────
class FinChartLegend extends StatelessWidget {
  final Color color;
  final String label;
  const FinChartLegend({super.key, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Text(label,
          style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[600])),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECCIÓN HEADER reutilizable
// ─────────────────────────────────────────────────────────────────────────────
class FinSectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const FinSectionHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(title,
          style: GoogleFonts.poppins(
              fontSize: 15, fontWeight: FontWeight.bold, color: kPrimaryColor)),
      if (trailing != null) trailing!,
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GRÁFICO DE LÍNEAS (Flujo de caja acumulado)
// ─────────────────────────────────────────────────────────────────────────────
class FinLineChart extends StatelessWidget {
  final List<Map<String, dynamic>> rawData;
  const FinLineChart({super.key, required this.rawData});

  @override
  Widget build(BuildContext context) {
    if (rawData.isEmpty) {
      return Center(
          child: Text('Sin datos',
              style: GoogleFonts.poppins(color: Colors.grey)));
    }

    final sorted = List<Map<String, dynamic>>.from(rawData)
      ..sort(
          (a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));

    List<FlSpot> incomeSpots = [];
    List<FlSpot> expenseSpots = [];
    double incAcc = 0, expAcc = 0;

    if (sorted.length == 1) {
      incomeSpots.add(const FlSpot(0, 0));
      expenseSpots.add(const FlSpot(0, 0));
    }

    for (int i = 0; i < sorted.length; i++) {
      final item = sorted[i];
      final x = sorted.length == 1 ? 1.0 : i.toDouble();
      if (item['type'] == 'income') {
        incAcc += (item['amount'] as num).toDouble();
      } else {
        expAcc += (item['amount'] as num).toDouble();
      }
      incomeSpots.add(FlSpot(x, incAcc));
      expenseSpots.add(FlSpot(x, expAcc));
    }

    final maxVal = [incAcc, expAcc].reduce((a, b) => a > b ? a : b);
    final interval = maxVal == 0 ? 100.0 : maxVal / 4;

    return LineChart(LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: interval,
        getDrawingHorizontalLine: (v) =>
            FlLine(color: Colors.grey.shade100, strokeWidth: 1),
      ),
      titlesData: FlTitlesData(
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 28,
            interval: 1,
            getTitlesWidget: (value, meta) {
              int idx = value.toInt();
              if (sorted.length == 1) idx -= 1;
              if (idx < 0 || idx >= sorted.length) return const SizedBox();
              if (sorted.length > 6 && idx % (sorted.length ~/ 4) != 0) {
                return const SizedBox();
              }
              final date = sorted[idx]['date'] as DateTime;
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(DateFormat('d MMM').format(date),
                    style:
                        GoogleFonts.poppins(fontSize: 9, color: Colors.grey)),
              );
            },
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        _lineBar(incomeSpots, kIncomeColor),
        _lineBar(expenseSpots, kExpenseColor),
      ],
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (spots) => spots
              .map((s) => LineTooltipItem(
                    '\$${s.y.toStringAsFixed(0)}',
                    GoogleFonts.poppins(
                        color: s.bar.color,
                        fontWeight: FontWeight.bold,
                        fontSize: 11),
                  ))
              .toList(),
        ),
      ),
    ));
  }

  LineChartBarData _lineBar(List<FlSpot> spots, Color color) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.35,
      preventCurveOverShooting: true,
      color: color,
      barWidth: 2.5,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.25), color.withValues(alpha: 0.0)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GRÁFICO DE BARRAS APILADAS (ingresos vs egresos por mes)
// ─────────────────────────────────────────────────────────────────────────────
class FinStackedBarChart extends StatelessWidget {
  // data: List<{label: 'Ene', income: 500, expense: 200}>
  final List<Map<String, dynamic>> monthlyData;
  const FinStackedBarChart({super.key, required this.monthlyData});

  @override
  Widget build(BuildContext context) {
    if (monthlyData.isEmpty) {
      return Center(
          child: Text('Sin datos mensuales',
              style: GoogleFonts.poppins(color: Colors.grey)));
    }

    final maxVal = monthlyData.map((m) {
      final inc = (m['income'] as num? ?? 0).toDouble();
      final exp = (m['expense'] as num? ?? 0).toDouble();
      return inc > exp ? inc : exp;
    }).reduce((a, b) => a > b ? a : b);

    return BarChart(BarChartData(
      alignment: BarChartAlignment.spaceAround,
      maxY: maxVal * 1.2,
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipItem: (group, groupIndex, rod, rodIndex) {
            final label = monthlyData[group.x.toInt()]['label'] as String;
            final isIncome = rodIndex == 0;
            return BarTooltipItem(
              '$label\n${isIncome ? "Ing" : "Egr"}: \$${rod.toY.toStringAsFixed(0)}',
              GoogleFonts.poppins(
                  color: isIncome ? kIncomeColor : kExpenseColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold),
            );
          },
        ),
      ),
      titlesData: FlTitlesData(
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 38,
            getTitlesWidget: (v, _) => Text(
              '\$${_shortNum(v)}',
              style: GoogleFonts.poppins(fontSize: 9, color: Colors.grey),
            ),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (v, _) {
              final idx = v.toInt();
              if (idx < 0 || idx >= monthlyData.length) return const SizedBox();
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(monthlyData[idx]['label'] as String,
                    style:
                        GoogleFonts.poppins(fontSize: 9, color: Colors.grey)),
              );
            },
          ),
        ),
      ),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: maxVal / 4 == 0 ? 100 : maxVal / 4,
        getDrawingHorizontalLine: (v) =>
            FlLine(color: Colors.grey.shade100, strokeWidth: 1),
      ),
      borderData: FlBorderData(show: false),
      barGroups: List.generate(monthlyData.length, (i) {
        final m = monthlyData[i];
        final inc = (m['income'] as num? ?? 0).toDouble();
        final exp = (m['expense'] as num? ?? 0).toDouble();
        return BarChartGroupData(x: i, barRods: [
          BarChartRodData(
            toY: inc,
            color: kIncomeColor,
            width: 10,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
          BarChartRodData(
            toY: exp,
            color: kExpenseColor,
            width: 10,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ]);
      }),
    ));
  }

  String _shortNum(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GRÁFICO DE DONA (ingresos por actividad)
// ─────────────────────────────────────────────────────────────────────────────
class FinPieChart extends StatelessWidget {
  final Map<String, double> dataMap;
  const FinPieChart({super.key, required this.dataMap});

  static const List<Color> _palette = [
    kPrimaryColor,
    kExpenseColor,
    kIncomeColor,
    kWarningColor,
    Color(0xFF9B59B6),
    Color(0xFF1ABC9C),
    Color(0xFF607D8B),
    Color(0xFFE91E63),
  ];

  @override
  Widget build(BuildContext context) {
    if (dataMap.isEmpty) return const SizedBox();
    final total = dataMap.values.fold(0.0, (a, b) => a + b);
    int i = 0;
    final sections = dataMap.entries.map((e) {
      final pct = e.value / total;
      final section = PieChartSectionData(
        color: _palette[i % _palette.length],
        value: e.value,
        title: pct > 0.12 ? '${(pct * 100).toStringAsFixed(0)}%' : '',
        radius: pct > 0.12 ? 58 : 48,
        titleStyle: GoogleFonts.poppins(
            fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
      );
      i++;
      return section;
    }).toList();

    return Row(children: [
      Expanded(
        flex: 2,
        child: PieChart(PieChartData(
          sections: sections,
          centerSpaceRadius: 38,
          sectionsSpace: 2,
        )),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: dataMap.entries.indexed.map((entry) {
            final idx = entry.$1;
            final key = entry.$2.key;
            final val = entry.$2.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                        color: _palette[idx % _palette.length],
                        shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(key,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                                fontSize: 10, color: Colors.grey[700])),
                        Text('\$${val.toStringAsFixed(0)}',
                            style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: kPrimaryColor)),
                      ]),
                ),
              ]),
            );
          }).toList(),
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TARJETA ANALÍTICA (métricas cuadradas)
// ─────────────────────────────────────────────────────────────────────────────
class FinAnalyticCard extends StatelessWidget {
  final String title;
  final String value;
  final String description;
  final IconData icon;
  final Color color;
  final bool isSmallText;

  const FinAnalyticCard({
    super.key,
    required this.title,
    required this.value,
    required this.description,
    required this.icon,
    required this.color,
    this.isSmallText = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Icon(icon, color: color, size: 20),
            Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.5),
                    shape: BoxShape.circle)),
          ]),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                    fontSize: isSmallText ? 15 : 20,
                    fontWeight: FontWeight.bold,
                    color: kPrimaryColor)),
            Text(title,
                style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600])),
            const SizedBox(height: 2),
            Text(description,
                style:
                    GoogleFonts.poppins(fontSize: 9, color: Colors.grey[400])),
          ]),
        ],
      ),
    );
  }
}
