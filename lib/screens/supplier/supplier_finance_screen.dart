import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// SERVICIOS
import '../../services/supplier_service.dart';

// SUB-MÓDULOS FINANCIEROS
import 'finance_widgets.dart';
import 'finance_dashboard_tab.dart';
import 'finance_libro_diario_tab.dart';
import 'finance_rentabilidad_tab.dart';
import 'finance_indicadores_tab.dart';
import 'finance_wallets_tab.dart';
import 'finance_transaction_modal.dart';

// Re-exportamos el helper de fechas para compatibilidad con otros archivos
// que lo usaban desde supplier_finance_screen.dart
export 'finance_widgets.dart' show parseFinanceDate;

// ─────────────────────────────────────────────────────────────────────────────
// PANTALLA PRINCIPAL: MÓDULO FINANCIERO DEL PROVEEDOR
// 5 pestañas: Resumen · Libro Diario · Rentabilidad · Indicadores · Cajas
// ─────────────────────────────────────────────────────────────────────────────
class SupplierFinanceScreen extends StatefulWidget {
  final String userId;
  const SupplierFinanceScreen({super.key, required this.userId});

  @override
  State<SupplierFinanceScreen> createState() => _SupplierFinanceScreenState();
}

class _SupplierFinanceScreenState extends State<SupplierFinanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _isLoading = true;
  String _effectiveSupplierId = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _initData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    setState(() => _isLoading = true);
    String id = await SupplierService.getActiveSupplierId();
    if (id.isEmpty) id = widget.userId;
    setState(() {
      _effectiveSupplierId = id;
      _isLoading = false;
    });
  }

  void _openTransactionModal({String type = 'expense'}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FinTransactionModal(
        supplierId: _effectiveSupplierId,
        initialType: type,
        onSaved: () {},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Text('Finanzas',
              style: GoogleFonts.poppins(
                  color: kPrimaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 18)),
        ),
        actions: [
          // FAB rápido: nueva transacción
          IconButton(
            tooltip: 'Registrar ingreso',
            icon: const Icon(Icons.add_circle_outline, color: kIncomeColor),
            onPressed: () => _openTransactionModal(type: 'income'),
          ),
          IconButton(
            tooltip: 'Registrar egreso',
            icon: const Icon(Icons.remove_circle_outline, color: kExpenseColor),
            onPressed: () => _openTransactionModal(type: 'expense'),
          ),
          const SizedBox(width: 4),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: kPrimaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: kPrimaryColor,
          indicatorWeight: 3,
          isScrollable: true,
          labelStyle:
              GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12),
          unselectedLabelStyle: GoogleFonts.poppins(fontSize: 12),
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'Resumen'),
            Tab(text: 'Libro Diario'),
            Tab(text: 'Rentabilidad'),
            Tab(text: 'Indicadores'),
            Tab(text: 'Cajas'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // 1. Dashboard / Resumen
                FinanceDashboardTab(supplierId: _effectiveSupplierId),

                // 2. Libro Diario (ingresos + egresos manuales)
                FinanceLibroDiarioTab(supplierId: _effectiveSupplierId),

                // 3. Rentabilidad por actividad
                FinanceRentabilidadTab(supplierId: _effectiveSupplierId),

                // 4. Indicadores BI
                FinanceIndicadoresTab(supplierId: _effectiveSupplierId),

                // 5. Cajas / Wallets
                FinanceWalletsTab(supplierId: _effectiveSupplierId),
              ],
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PESTAÑA COSTOS (mantenida por compatibilidad con _ActivityExpensesView)
// ─────────────────────────────────────────────────────────────────────────────

// ignore: unused_element
class _CostsTabLegacy extends StatelessWidget {
  final String supplierId;
  final VoidCallback onAddExpense;

  const _CostsTabLegacy({required this.supplierId, required this.onAddExpense});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onAddExpense,
            icon: const Icon(Icons.add_circle_outline, color: Colors.white),
            label: Text('Registrar costo de actividad',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold, color: Colors.white)),
            style: ElevatedButton.styleFrom(
                backgroundColor: kExpenseColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
          ),
        ),
      ),
      Expanded(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('destinos')
              .where('supplierId', isEqualTo: supplierId)
              .where('status', isEqualTo: 'active')
              .snapshots(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snap.hasData || snap.data!.docs.isEmpty) {
              return Center(
                child: Text('No tienes actividades activas.',
                    style: GoogleFonts.poppins(color: Colors.grey)),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: snap.data!.docs.length,
              itemBuilder: (context, i) {
                final doc = snap.data!.docs[i];
                final data = doc.data() as Map<String, dynamic>;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ActivityCostCard(
                    title: data['nombre'] ?? 'Sin nombre',
                    subtitle: data['lugar'] ?? '',
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => _ActivityExpensesView(
                                  supplierId: supplierId,
                                  destinationId: doc.id,
                                  activityName: data['nombre'] ?? 'Actividad',
                                ))),
                  ),
                );
              },
            );
          },
        ),
      ),
    ]);
  }
}

class _ActivityCostCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActivityCostCard(
      {required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 4))
            ]),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: kPrimaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.map, color: kPrimaryColor),
          ),
          const SizedBox(width: 15),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold, fontSize: 14)),
              if (subtitle.isNotEmpty)
                Text(subtitle,
                    style:
                        GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
            ]),
          ),
          const Icon(Icons.chevron_right, color: Colors.grey),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VISTA DETALLADA DE GASTOS POR ACTIVIDAD
// ─────────────────────────────────────────────────────────────────────────────
class _ActivityExpensesView extends StatelessWidget {
  final String supplierId;
  final String destinationId;
  final String activityName;

  const _ActivityExpensesView({
    required this.supplierId,
    required this.destinationId,
    required this.activityName,
  });

  void _showOptions(BuildContext context, Map<String, dynamic> expense) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 10),
          Container(width: 40, height: 4, color: Colors.grey[300]),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.edit, color: Colors.blue),
            title: Text('Editar costo', style: GoogleFonts.poppins()),
            onTap: () {
              Navigator.pop(c);
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => FinTransactionModal(
                  supplierId: supplierId,
                  txToEdit: expense,
                  initialType: 'expense',
                  onSaved: () {},
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: Text('Eliminar costo', style: GoogleFonts.poppins()),
            onTap: () {
              Navigator.pop(c);
              _confirmDelete(context, expense['id']);
            },
          ),
          const SizedBox(height: 10),
        ]),
      ),
    );
  }

  void _confirmDelete(BuildContext context, String docId) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('¿Eliminar costo?',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content:
            Text('Esta acción es permanente.', style: GoogleFonts.poppins()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c),
              child: Text('Cancelar',
                  style: GoogleFonts.poppins(color: Colors.grey))),
          TextButton(
              onPressed: () {
                FirebaseFirestore.instance
                    .collection('gastos')
                    .doc(docId)
                    .delete();
                Navigator.pop(c);
              },
              child: Text('Eliminar',
                  style: GoogleFonts.poppins(color: Colors.red))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: Text(activityName,
            style: GoogleFonts.poppins(
                color: kPrimaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle, color: kPrimaryColor),
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => FinTransactionModal(
                supplierId: supplierId,
                preSelectedDestinationId: destinationId,
                initialType: 'expense',
                onSaved: () {},
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('gastos')
            .where('supplierId', isEqualTo: supplierId)
            .where('destinationId', isEqualTo: destinationId)
            .orderBy('fecha', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
                child: Text('Error: revisa el índice de Firebase.',
                    style: GoogleFonts.poppins(color: Colors.red),
                    textAlign: TextAlign.center));
          }
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return Center(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.receipt_long_outlined,
                        size: 60, color: Colors.grey[300]),
                    const SizedBox(height: 10),
                    Text('No hay costos registrados',
                        style: GoogleFonts.poppins(color: Colors.grey)),
                  ]),
            );
          }

          final expenses = snap.data!.docs;
          double total = 0;
          for (var e in expenses) {
            total += ((e.data() as Map)['monto'] as num? ?? 0).toDouble();
          }

          return Column(children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total de costos', style: GoogleFonts.poppins()),
                    Text('\$${total.toStringAsFixed(2)}',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: kExpenseColor)),
                  ]),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: expenses.length,
                itemBuilder: (context, i) {
                  final doc = expenses[i];
                  final data = doc.data() as Map<String, dynamic>;
                  data['id'] = doc.id;
                  final date = parseFinanceDate(data['fecha']);

                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200)),
                    child: ListTile(
                      onTap: () => _showOptions(context, data),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: kExpenseColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.attach_money,
                            color: kExpenseColor, size: 20),
                      ),
                      title: Text(data['descripcion'] ?? 'Gasto',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text(
                          '${_fmtDate(date)} · ${data['categoria'] ?? ''}',
                          style: GoogleFonts.poppins(fontSize: 12)),
                      trailing: Text(
                          '-\$${((data['monto'] as num?) ?? 0).toStringAsFixed(2)}',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              color: kExpenseColor,
                              fontSize: 15)),
                    ),
                  );
                },
              ),
            ),
          ]);
        },
      ),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year.toString().substring(2)}';
}
