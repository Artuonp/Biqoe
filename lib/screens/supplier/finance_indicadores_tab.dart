import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'finance_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PESTAÑA: INDICADORES / MÉTRICAS BI
// ─────────────────────────────────────────────────────────────────────────────
class FinanceIndicadoresTab extends StatefulWidget {
  final String supplierId;
  const FinanceIndicadoresTab({super.key, required this.supplierId});

  @override
  State<FinanceIndicadoresTab> createState() => _FinanceIndicadoresTabState();
}

class _FinanceIndicadoresTabState extends State<FinanceIndicadoresTab> {
  String _selectedActivity = 'Todas';

  String _getTopActivity(Map<String, double> map) {
    if (map.isEmpty) return 'N/A';
    return (map.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
        .first
        .key;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header con filtro de actividad ──────────────────────────────
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Métricas de rendimiento',
              style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: kPrimaryColor)),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('destinos')
                .where('supplierId', isEqualTo: widget.supplierId)
                .snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) return const SizedBox();
              final List<DropdownMenuItem<String>> items =
                  snap.data!.docs.map((doc) {
                final d = doc.data() as Map<String, dynamic>;
                final name = d['nombre']?.toString() ?? 'Sin nombre';
                return DropdownMenuItem<String>(
                    value: name,
                    child: Text(name, overflow: TextOverflow.ellipsis));
              }).toList();
              items.insert(
                  0,
                  const DropdownMenuItem<String>(
                      value: 'Todas', child: Text('Todas las actividades')));
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200)),
                width: 170,
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: items.any((i) => i.value == _selectedActivity)
                        ? _selectedActivity
                        : 'Todas',
                    isExpanded: true,
                    icon: const Icon(Icons.filter_list,
                        size: 16, color: kPrimaryColor),
                    style:
                        GoogleFonts.poppins(fontSize: 12, color: kPrimaryColor),
                    items: items,
                    onChanged: (v) => setState(() => _selectedActivity = v!),
                  ),
                ),
              );
            },
          ),
        ]),
        const SizedBox(height: 20),

        // ── Streams de datos ─────────────────────────────────────────────
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collectionGroup('reservas')
              .where('supplier', isEqualTo: widget.supplierId)
              .snapshots(),
          builder: (context, resSnap) {
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('destinos')
                  .where('supplierId', isEqualTo: widget.supplierId)
                  .snapshots(),
              builder: (context, destSnap) {
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('gastos')
                      .where('supplierId', isEqualTo: widget.supplierId)
                      .snapshots(),
                  builder: (context, expSnap) {
                    if (!resSnap.hasData || !destSnap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    // ── Cálculos ───────────────────────────────────────
                    final allDests = destSnap.data!.docs;
                    final filteredDests = _selectedActivity == 'Todas'
                        ? allDests
                        : allDests
                            .where((d) =>
                                (d.data() as Map)['nombre'] ==
                                _selectedActivity)
                            .toList();

                    int totalViews = 0;
                    for (var d in filteredDests) {
                      totalViews +=
                          ((d.data() as Map)['profileViews'] ?? 0) as int;
                    }

                    final allReservas = resSnap.data!.docs;
                    final filteredReservas = _selectedActivity == 'Todas'
                        ? allReservas
                        : allReservas
                            .where((r) =>
                                (r.data() as Map)['planName'] ==
                                _selectedActivity)
                            .toList();

                    int totalSales = 0;
                    double totalRevenue = 0;
                    Map<String, double> revenueMap = {};
                    Map<String, int> reservasMap = {};

                    for (var r in filteredReservas) {
                      final d = r.data() as Map<String, dynamic>;
                      final paid = (d['amountPaid'] ?? 0).toDouble();
                      if (paid > 0) {
                        totalSales++;
                        totalRevenue += paid;
                        final key = d['planName'] ?? 'Otros';
                        revenueMap[key] = (revenueMap[key] ?? 0) + paid;
                        reservasMap[key] = (reservasMap[key] ?? 0) + 1;
                      }
                    }

                    // Ticket promedio
                    final avgTicket =
                        totalSales == 0 ? 0.0 : totalRevenue / totalSales;

                    // Conversión
                    double conversion = totalViews > 0
                        ? (totalSales / totalViews * 100).clamp(0, 100)
                        : 0;

                    // Gastos totales (para margen global)
                    double totalExpense = 0;
                    for (var e in (expSnap.data?.docs ?? [])) {
                      if (_selectedActivity != 'Todas') {
                        // Solo gastos de actividades filtradas
                        final destId = filteredDests.isNotEmpty
                            ? filteredDests.first.id
                            : '';
                        if ((e.data() as Map)['destinationId'] == destId) {
                          totalExpense +=
                              ((e.data() as Map)['monto'] ?? 0).toDouble();
                        }
                      } else {
                        totalExpense +=
                            ((e.data() as Map)['monto'] ?? 0).toDouble();
                      }
                    }
                    final globalMargin = totalRevenue == 0
                        ? 0.0
                        : ((totalRevenue - totalExpense) / totalRevenue * 100)
                            .clamp(-999, 100);

                    return Column(children: [
                      // ── KPIs en grid ─────────────────────────────────
                      GridView.count(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: 1.4,
                        children: [
                          FinAnalyticCard(
                            title: 'Tasa de conversión',
                            value: '${conversion.toStringAsFixed(2)}%',
                            icon: Icons.sync_alt,
                            color: Colors.blue,
                            description: 'Ventas / Vistas',
                          ),
                          FinAnalyticCard(
                            title: 'Vistas totales',
                            value: totalViews.toString(),
                            icon: Icons.visibility_outlined,
                            color: Colors.purple,
                            description: 'Visitas a la actividad',
                          ),
                          FinAnalyticCard(
                            title: 'Ventas totales',
                            value: totalSales.toString(),
                            icon: Icons.shopping_bag_outlined,
                            color: Colors.teal,
                            description: 'Reservas concretadas',
                          ),
                          FinAnalyticCard(
                            title: 'Ticket promedio',
                            value: '\$${avgTicket.toStringAsFixed(0)}',
                            icon: Icons.confirmation_number_outlined,
                            color: kWarningColor,
                            description: 'Ingreso por reserva',
                          ),
                          FinAnalyticCard(
                            title: 'Margen global',
                            value: '${globalMargin.toStringAsFixed(1)}%',
                            icon: Icons.percent,
                            color: globalMargin >= 30
                                ? kIncomeColor
                                : globalMargin >= 0
                                    ? kWarningColor
                                    : kExpenseColor,
                            description: '(Ing - Egr) / Ing',
                          ),
                          FinAnalyticCard(
                            title: 'Actividad top',
                            value: _selectedActivity == 'Todas'
                                ? _getTopActivity(revenueMap)
                                : _selectedActivity,
                            icon: Icons.star_outline,
                            color: Colors.amber[700]!,
                            description: 'Mayor ingreso generado',
                            isSmallText: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),

                      // ── Embudo de ventas visual ───────────────────────
                      _buildFunnel(totalViews, totalSales),
                      const SizedBox(height: 28),

                      // ── Distribución de ingresos (dona) ──────────────
                      if (_selectedActivity == 'Todas' &&
                          revenueMap.isNotEmpty) ...[
                        FinSectionHeader(title: 'Distribución de ingresos'),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 240,
                          child: FinPieChart(dataMap: revenueMap),
                        ),
                        const SizedBox(height: 28),
                      ],

                      // ── Ranking de actividades ────────────────────────
                      if (revenueMap.isNotEmpty) ...[
                        FinSectionHeader(title: 'Ranking de actividades'),
                        const SizedBox(height: 14),
                        ..._buildRanking(revenueMap, reservasMap),
                      ],
                    ]);
                  },
                );
              },
            );
          },
        ),
      ]),
    );
  }

  Widget _buildFunnel(int views, int sales) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Embudo de ventas',
            style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: kPrimaryColor)),
        const SizedBox(height: 16),
        _FunnelStep(
            label: 'Vistas totales',
            value: views,
            maxValue: views == 0 ? 1 : views,
            color: Colors.blue),
        const SizedBox(height: 8),
        _FunnelStep(
            label: 'Reservas concretadas',
            value: sales,
            maxValue: views == 0 ? 1 : views,
            color: kIncomeColor),
        const SizedBox(height: 8),
        _FunnelStep(
            label: 'Pendientes de pago',
            value: (sales * 0.1).toInt(), // estimado
            maxValue: views == 0 ? 1 : views,
            color: kWarningColor),
      ]),
    );
  }

  List<Widget> _buildRanking(
      Map<String, double> revenue, Map<String, int> counts) {
    final sorted = revenue.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxVal = sorted.isEmpty ? 1.0 : sorted.first.value;

    return sorted.asMap().entries.map((entry) {
      final idx = entry.key;
      final name = entry.value.key;
      final val = entry.value.value;
      final cnt = counts[name] ?? 0;

      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade100)),
        child: Column(children: [
          Row(children: [
            // Posición
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                  color: idx == 0
                      ? Colors.amber[700]
                      : idx == 1
                          ? Colors.blueGrey[400]
                          : Colors.brown[300],
                  shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text('${idx + 1}',
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    Text('$cnt reservas',
                        style: GoogleFonts.poppins(
                            fontSize: 11, color: Colors.grey[500])),
                  ]),
            ),
            Text('\$${val.toStringAsFixed(0)}',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: kPrimaryColor)),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: maxVal == 0 ? 0 : val / maxVal,
              minHeight: 6,
              backgroundColor: Colors.grey[100],
              valueColor: AlwaysStoppedAnimation(
                  idx == 0 ? kIncomeColor : kPrimaryColor),
            ),
          ),
        ]),
      );
    }).toList();
  }
}

class _FunnelStep extends StatelessWidget {
  final String label;
  final int value;
  final int maxValue;
  final Color color;

  const _FunnelStep({
    required this.label,
    required this.value,
    required this.maxValue,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = maxValue == 0 ? 0.0 : (value / maxValue).clamp(0.0, 1.0);
    return Row(children: [
      SizedBox(
        width: 130,
        child: Text(label,
            style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[600])),
      ),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 14,
              backgroundColor: Colors.grey[100],
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ]),
      ),
      const SizedBox(width: 10),
      SizedBox(
        width: 34,
        child: Text(value.toString(),
            textAlign: TextAlign.right,
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: kPrimaryColor)),
      ),
    ]);
  }
}
