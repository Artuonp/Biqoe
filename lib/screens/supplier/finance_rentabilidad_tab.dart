import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'finance_widgets.dart';
import 'finance_transaction_modal.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PESTAÑA: RENTABILIDAD POR ACTIVIDAD
// ─────────────────────────────────────────────────────────────────────────────
class FinanceRentabilidadTab extends StatelessWidget {
  final String supplierId;
  const FinanceRentabilidadTab({super.key, required this.supplierId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('destinos')
          .where('supplierId', isEqualTo: supplierId)
          .where('status', isEqualTo: 'active')
          .snapshots(),
      builder: (context, destSnap) {
        if (!destSnap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final destinations = destSnap.data!.docs;
        if (destinations.isEmpty) {
          return Center(
              child: Text('No tienes actividades activas',
                  style: GoogleFonts.poppins(color: Colors.grey)));
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('gastos')
              .where('supplierId', isEqualTo: supplierId)
              .snapshots(),
          builder: (context, expSnap) {
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('ingresos_egresos')
                  .where('supplierId', isEqualTo: supplierId)
                  .snapshots(),
              builder: (context, manualSnap) {
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collectionGroup('reservas')
                      .where('supplier', isEqualTo: supplierId)
                      .snapshots(),
                  builder: (context, reservasSnap) {
                    final expDocs = expSnap.data?.docs ?? [];
                    final manualDocs = manualSnap.data?.docs ?? [];
                    final reservasDocs = reservasSnap.data?.docs ?? [];

                    // Calcular totales globales para el header

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: destinations.length,
                      itemBuilder: (context, index) {
                        final doc = destinations[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final destId = doc.id;
                        final name = data['nombre'] ?? 'Sin nombre';

                        double inc = 0, exp = 0;

                        // Ingresos de reservas automáticas
                        for (var r in reservasDocs) {
                          final rData = r.data() as Map<String, dynamic>;
                          if (rData['destinationId'] == destId ||
                              (rData['planName']?.toString().contains(name) ==
                                  true)) {
                            inc += (rData['amountPaid'] ?? 0).toDouble();
                          }
                        }

                        // Ingresos manuales vinculados
                        for (var m in manualDocs) {
                          final mData = m.data() as Map<String, dynamic>;
                          if (mData['destinationId'] == destId &&
                              mData['type'] == 'income') {
                            inc += (mData['monto'] ?? 0).toDouble();
                          } else if (mData['destinationId'] == destId &&
                              mData['type'] == 'expense') {
                            exp += (mData['monto'] ?? 0).toDouble();
                          }
                        }

                        // Gastos
                        for (var e in expDocs) {
                          final eData = e.data() as Map<String, dynamic>;
                          if (eData['destinationId'] == destId) {
                            exp += (eData['monto'] ?? 0).toDouble();
                          }
                        }

                        final profit = inc - exp;
                        final margin =
                            inc == 0 ? 0.0 : ((profit / inc) * 100).toDouble();

                        return _ActivityCard(
                          supplierId: supplierId,
                          destId: destId,
                          name: name,
                          income: inc,
                          expense: exp,
                          profit: profit,
                          margin: margin,
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final String supplierId;
  final String destId;
  final String name;
  final double income;
  final double expense;
  final double profit;
  final double margin;

  const _ActivityCard({
    required this.supplierId,
    required this.destId,
    required this.name,
    required this.income,
    required this.expense,
    required this.profit,
    required this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = profit >= 0;

    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => _ActivityProfitabilityDetail(
                    supplierId: supplierId,
                    destinationId: destId,
                    activityName: name,
                  ))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
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
        child: Column(children: [
          Row(children: [
            Expanded(
              child: Text(name,
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold, fontSize: 15)),
            ),
            // Badge margen
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                  color: (isPositive ? kIncomeColor : kExpenseColor)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20)),
              child: Text(
                  '${isPositive ? '+' : ''}${margin.toStringAsFixed(1)}%',
                  style: GoogleFonts.poppins(
                      color: isPositive ? kIncomeColor : kExpenseColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                  color: (isPositive ? kIncomeColor : kExpenseColor)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: Text(
                  '${isPositive ? '+' : ''}\$${profit.abs().toStringAsFixed(0)}',
                  style: GoogleFonts.poppins(
                      color: isPositive ? kIncomeColor : kExpenseColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
          ]),
          const SizedBox(height: 12),
          // Barra proporcional
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Row(children: [
              if (income > 0)
                Expanded(
                    flex: income.toInt().clamp(1, 99999),
                    child: Container(height: 7, color: kIncomeColor)),
              if (expense > 0)
                Expanded(
                    flex: expense.toInt().clamp(1, 99999),
                    child: Container(height: 7, color: kExpenseColor)),
              if (income == 0 && expense == 0)
                Expanded(child: Container(height: 7, color: Colors.grey[200])),
            ]),
          ),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Ventas: \$${income.toStringAsFixed(0)}',
                style:
                    GoogleFonts.poppins(fontSize: 11, color: Colors.grey[600])),
            Text('Costos: \$${expense.toStringAsFixed(0)}',
                style:
                    GoogleFonts.poppins(fontSize: 11, color: Colors.red[300])),
          ]),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DETALLE DE RENTABILIDAD
// ─────────────────────────────────────────────────────────────────────────────
class _ActivityProfitabilityDetail extends StatelessWidget {
  final String supplierId;
  final String destinationId;
  final String activityName;

  const _ActivityProfitabilityDetail({
    required this.supplierId,
    required this.destinationId,
    required this.activityName,
  });

  void _openExpenseModal(BuildContext context, {Map<String, dynamic>? tx}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FinTransactionModal(
        supplierId: supplierId,
        txToEdit: tx,
        preSelectedDestinationId: destinationId,
        initialType: 'expense',
        onSaved: () {},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: Text('Detalle financiero',
            style: GoogleFonts.poppins(
                color: kPrimaryColor, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle, color: kPrimaryColor),
            tooltip: 'Registrar egreso',
            onPressed: () => _openExpenseModal(context),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('gastos')
            .where('supplierId', isEqualTo: supplierId)
            .where('destinationId', isEqualTo: destinationId)
            .snapshots(),
        builder: (context, expSnap) {
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('ingresos_egresos')
                .where('supplierId', isEqualTo: supplierId)
                .where('destinationId', isEqualTo: destinationId)
                .snapshots(),
            builder: (context, manualSnap) {
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collectionGroup('reservas')
                    .where('supplier', isEqualTo: supplierId)
                    .where('planName', isEqualTo: activityName)
                    .snapshots(),
                builder: (context, reservasSnap) {
                  if (!expSnap.hasData || !reservasSnap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  List<Map<String, dynamic>> items = [];
                  double totalIncome = 0, totalExpense = 0;

                  // Reservas automáticas
                  for (var doc in reservasSnap.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final paid = (data['amountPaid'] ?? 0).toDouble();
                    if (paid > 0) {
                      totalIncome += paid;
                      items.add({
                        'type': 'income',
                        'amount': paid,
                        'date': parseFinanceDate(data['createdAt']),
                        'title': data['name'] ?? 'Reserva',
                        'subtitle': 'Verificado',
                        'raw': data,
                      });
                    }
                  }

                  // Transacciones manuales
                  for (var doc in (manualSnap.data?.docs ?? [])) {
                    final data = doc.data() as Map<String, dynamic>;
                    data['id'] = doc.id;
                    final amt = (data['monto'] ?? 0).toDouble();
                    final type = data['type'] ?? 'expense';
                    if (type == 'income') {
                      totalIncome += amt;
                    } else {
                      totalExpense += amt;
                    }
                    items.add({
                      'type': type,
                      'amount': amt,
                      'date': parseFinanceDate(data['fecha']),
                      'title': data['descripcion'] ?? 'Movimiento',
                      'subtitle': data['categoria'] ?? '',
                      'raw': data,
                    });
                  }

                  // Gastos actividad
                  for (var doc in expSnap.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    data['id'] = doc.id;
                    final amt = (data['monto'] ?? 0).toDouble();
                    totalExpense += amt;
                    items.add({
                      'type': 'expense',
                      'amount': amt,
                      'date': parseFinanceDate(data['fecha']),
                      'title': data['descripcion'] ?? 'Gasto',
                      'subtitle': data['categoria'] ?? 'Operativo',
                      'raw': data,
                    });
                  }

                  items.sort((a, b) =>
                      (b['date'] as DateTime).compareTo(a['date'] as DateTime));
                  final profit = totalIncome - totalExpense;

                  return Column(children: [
                    // Resumen
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(20),
                      child: Column(children: [
                        Text(activityName,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: kPrimaryColor)),
                        const SizedBox(height: 16),
                        Row(children: [
                          Expanded(
                              child: _MiniSummary(
                                  label: 'Ingresos',
                                  amount: totalIncome,
                                  color: kIncomeColor)),
                          Container(
                              width: 1, height: 40, color: Colors.grey[200]),
                          Expanded(
                              child: _MiniSummary(
                                  label: 'Costos',
                                  amount: totalExpense,
                                  color: kExpenseColor)),
                          Container(
                              width: 1, height: 40, color: Colors.grey[200]),
                          Expanded(
                              child: _MiniSummary(
                                  label: 'Neto',
                                  amount: profit,
                                  color: profit >= 0
                                      ? kIncomeColor
                                      : kExpenseColor,
                                  isBold: true)),
                        ]),
                      ]),
                    ),
                    const SizedBox(height: 8),

                    // Lista
                    Expanded(
                      child: items.isEmpty
                          ? Center(
                              child: Text('Sin movimientos',
                                  style:
                                      GoogleFonts.poppins(color: Colors.grey)))
                          : ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: items.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, i) {
                                final item = items[i];
                                final isIncome = item['type'] == 'income';
                                final isInternal = item['type'] == 'internal';
                                final color = isIncome
                                    ? kIncomeColor
                                    : isInternal
                                        ? kInternalColor
                                        : kExpenseColor;

                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border(
                                        left:
                                            BorderSide(color: color, width: 4)),
                                  ),
                                  child: Row(children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                          color: color.withValues(alpha: 0.1),
                                          shape: BoxShape.circle),
                                      child: Icon(
                                          isIncome
                                              ? Icons.arrow_downward
                                              : Icons.arrow_upward,
                                          color: color,
                                          size: 16),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(item['title'],
                                                style: GoogleFonts.poppins(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 13)),
                                            Text(
                                              '${DateFormat('dd MMM').format(item['date'] as DateTime)} · ${item['subtitle']}',
                                              style: GoogleFonts.poppins(
                                                  fontSize: 11,
                                                  color: Colors.grey),
                                            ),
                                          ]),
                                    ),
                                    Text(
                                      '\$${(item['amount'] as double).toStringAsFixed(2)}',
                                      style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.bold,
                                          color: color),
                                    ),
                                  ]),
                                );
                              },
                            ),
                    ),
                  ]);
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _MiniSummary extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final bool isBold;

  const _MiniSummary(
      {required this.label,
      required this.amount,
      required this.color,
      this.isBold = false});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(label, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
      const SizedBox(height: 4),
      Text('\$${amount.toStringAsFixed(0)}',
          style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color)),
    ]);
  }
}
