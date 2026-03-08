import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'supplier_verify_payments_screen.dart';

// SERVICIOS
import '../../services/supplier_service.dart';
import '../../services/finance_service.dart';

// Helper: convierte Timestamp, String ISO o DateTime a DateTime de forma segura.
// Necesario porque reservas creadas vía REST (Safari web) guardan fechas como String ISO.
DateTime _parseDate(dynamic value, {DateTime? fallback}) {
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

// COLORES
const Color kPrimaryColor = Color.fromRGBO(17, 48, 73, 1);
const Color kIncomeColor = Color(0xFF34C759); // Verde
const Color kExpenseColor = Color(0xFFFF3B30); // Rojo
const Color kWarningColor = Color(0xFFFF9500); // Naranja
const Color kBackgroundColor = Color(0xFFF3F7FE);

class SupplierFinanceScreen extends StatefulWidget {
  final String userId;

  const SupplierFinanceScreen({super.key, required this.userId});

  @override
  State<SupplierFinanceScreen> createState() => _SupplierFinanceScreenState();
}

class _SupplierFinanceScreenState extends State<SupplierFinanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FinanceService _financeService = FinanceService();

  // ESTADO
  bool _isLoading = true;
  String _effectiveSupplierId = '';
  Map<String, dynamic> _financeData = {};

  // FILTROS DE FECHA
  final DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  final DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    // AHORA SON 4 PESTAÑAS
    _tabController = TabController(length: 4, vsync: this);
    _initData();
  }

  Future<void> _initData() async {
    setState(() => _isLoading = true);
    String id = await SupplierService.getActiveSupplierId();
    if (id.isEmpty) id = widget.userId;
    _effectiveSupplierId = id;
    await _loadFinancials();
  }

  Future<void> _loadFinancials() async {
    try {
      final data = await _financeService.getFinancialSummary(
        supplierId: _effectiveSupplierId,
        startDate: _startDate,
        endDate: _endDate,
      );

      if (mounted) {
        setState(() {
          _financeData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error cargando finanzas: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ABRIR MODAL DE GASTO
  void _openExpenseModal({Map<String, dynamic>? expenseToEdit}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Para que suba con el teclado
      backgroundColor: Colors.transparent,
      builder: (context) => _AddExpenseModal(
        supplierId: _effectiveSupplierId,
        expenseToEdit: expenseToEdit,
        onExpenseSaved: _loadFinancials, // Recargar al guardar
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
        centerTitle: false,
        automaticallyImplyLeading: false, // Sin flecha de regreso
        title: Text("Resumen",
            style: GoogleFonts.poppins(
                color: kPrimaryColor, fontWeight: FontWeight.bold)),
        // ELIMINADO: actions: [IconButton(icon: Icon(Icons.refresh)...)]
        bottom: TabBar(
          controller: _tabController,
          labelColor: kPrimaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: kPrimaryColor,
          indicatorWeight: 3,
          isScrollable: true,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: "Resumen"),
            Tab(text: "Rentabilidad"),
            Tab(text: "Costos"),
            Tab(text: "Indicadores"),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ELIMINADO: Container con Dropdown "Período"

                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _DashboardTab(
                          supplierId: _effectiveSupplierId), // Pasa el ID
                      _ActivitiesTab(
                        supplierId: _effectiveSupplierId,
                        financeData: _financeData,
                        onDataChanged: _loadFinancials,
                      ),
                      _CostsTab(
                        supplierId: _effectiveSupplierId,
                        onAddExpense: () => _openExpenseModal(),
                      ),
                      _MetricsTab(supplierId: _effectiveSupplierId),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

// -----------------------------------------------------------------------------
// PESTAÑA 1: DASHBOARD (REAL-TIME + NAVEGACIÓN + GRÁFICO MEJORADO)
// -----------------------------------------------------------------------------
class _DashboardTab extends StatelessWidget {
  final String supplierId; // Ahora recibimos el ID, no la data estática

  const _DashboardTab({required this.supplierId});

  @override
  Widget build(BuildContext context) {
    // 1. STREAM DE GASTOS
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('gastos')
          .where('supplierId', isEqualTo: supplierId)
          .snapshots(),
      builder: (context, expenseSnap) {
        // 2. STREAM DE INGRESOS (RESERVAS)
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collectionGroup('reservas')
              .where('supplier', isEqualTo: supplierId)
              .snapshots(),
          builder: (context, incomeSnap) {
            if (!expenseSnap.hasData || !incomeSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            // --- CÁLCULOS EN TIEMPO REAL ---
            double totalIncome = 0;
            double totalExpenses = 0;
            double totalReceivable = 0;
            List<Map<String, dynamic>> chartData = [];

            // Procesar Gastos
            for (var doc in expenseSnap.data!.docs) {
              final data = doc.data() as Map<String, dynamic>;
              final double amount = (data['monto'] ?? 0).toDouble();
              final DateTime date = _parseDate(data['fecha']);
              totalExpenses += amount;

              chartData
                  .add({'date': date, 'amount': amount, 'type': 'expense'});
            }

            // Procesar Ingresos
            for (var doc in incomeSnap.data!.docs) {
              final data = doc.data() as Map<String, dynamic>;
              final double paid = (data['amountPaid'] ?? 0).toDouble();
              final double total = (data['totalPlanPrice'] ?? 0).toDouble();
              final DateTime date = _parseDate(data['createdAt']);

              // Ingreso Real (Cash Flow)
              if (paid > 0) {
                totalIncome += paid;
                chartData.add({'date': date, 'amount': paid, 'type': 'income'});
              }

              // Por Cobrar (Deuda)
              double debt = total - paid;
              if (debt > 1.0) {
                totalReceivable += debt;
              }
            }

            final double netProfit = totalIncome - totalExpenses;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- TARJETAS KPI CLICKABLES ---
                  Row(
                    children: [
                      Expanded(
                        child: _KPICard(
                          title: "Beneficio neto",
                          amount: netProfit,
                          color: netProfit >= 0 ? kIncomeColor : kExpenseColor,
                          icon: Icons.account_balance_wallet,
                          onTap: () {
                            // Navegar a verificar pagos (Pestaña "Verificadas")
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (c) =>
                                        SupplierVerifyPaymentsScreen(
                                          supplierId: supplierId,
                                          planName: '', // Todas
                                          initialIndex: 2, // Tab Verificadas
                                        )));
                          },
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: _KPICard(
                          title: "Por cobrar",
                          amount: totalReceivable,
                          color: kWarningColor,
                          icon: Icons.pending_actions,
                          onTap: () {
                            // Navegar a verificar pagos (Pestaña "Por Cobrar")
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (c) =>
                                        SupplierVerifyPaymentsScreen(
                                          supplierId: supplierId,
                                          planName: '',
                                          initialIndex: 3, // Tab Por Cobrar
                                        )));
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),

                  // Mini KPIs (Solo informativos)
                  Row(
                    children: [
                      Expanded(
                        child: _MiniKPI(
                            label: "Ingresos totales",
                            amount: totalIncome,
                            color: kPrimaryColor,
                            isPositive: true),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MiniKPI(
                            label: "Costos totales",
                            amount: totalExpenses,
                            color: kExpenseColor,
                            isPositive: false),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // --- GRÁFICO MEJORADO ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Flujo de caja",
                          style: GoogleFonts.poppins(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      // Leyenda
                      Row(
                        children: [
                          _ChartLegend(color: kIncomeColor, label: "Ingresos"),
                          const SizedBox(width: 10),
                          _ChartLegend(color: kExpenseColor, label: "Costos"),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 300, // Un poco más alto para las fechas
                    child: _FinanceLineChart(rawData: chartData),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ChartLegend extends StatelessWidget {
  final Color color;
  final String label;
  const _ChartLegend({required this.color, required this.label});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label,
            style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey))
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// PESTAÑA 2: RENTABILIDAD POR ACTIVIDAD (REAL-TIME REACTIVE)
// -----------------------------------------------------------------------------
class _ActivitiesTab extends StatelessWidget {
  final String supplierId;
  final Map<String, dynamic> financeData;
  final VoidCallback onDataChanged;

  const _ActivitiesTab({
    required this.supplierId,
    required this.financeData,
    required this.onDataChanged,
  });

  @override
  Widget build(BuildContext context) {
    // 1. STREAM DE ACTIVIDADES
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('destinos')
          .where('supplierId', isEqualTo: supplierId)
          .where('status', isEqualTo: 'active')
          .snapshots(),
      builder: (context, destSnapshot) {
        if (!destSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final destinations = destSnapshot.data!.docs;

        if (destinations.isEmpty) {
          return Center(
              child: Text("No tienes actividades activas",
                  style: GoogleFonts.poppins()));
        }

        // 2. STREAM DE GASTOS en tiempo real
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('gastos')
              .where('supplierId', isEqualTo: supplierId)
              .snapshots(),
          builder: (context, expenseSnapshot) {
            final expenseDocs = expenseSnapshot.data?.docs ?? [];

            // 3. STREAM DE INGRESOS en tiempo real — igual que _DashboardTab.
            // Reemplaza el lookup estático en financeData['transactions'] que
            // solo se cargaba una vez y no reflejaba ventas nuevas.
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collectionGroup('reservas')
                  .where('supplier', isEqualTo: supplierId)
                  .snapshots(),
              builder: (context, reservasSnapshot) {
                final reservasDocs = reservasSnapshot.data?.docs ?? [];

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: destinations.length,
                  itemBuilder: (context, index) {
                    final doc = destinations[index];
                    final dData = doc.data() as Map<String, dynamic>;
                    final String destId = doc.id;
                    final String name = dData['nombre'] ?? 'Sin nombre';

                    double inc = 0;
                    double exp = 0;

                    // A. INGRESOS: cruzar cada reserva contra este destino.
                    // Primero por destinationId (campo exacto), luego por
                    // planName como fallback para reservas que no lo tienen.
                    for (var rDoc in reservasDocs) {
                      final rData = rDoc.data() as Map<String, dynamic>;
                      final bool byId =
                          rData['destinationId']?.toString() == destId;
                      final bool byName =
                          rData['planName']?.toString().contains(name) == true;
                      if (byId || byName) {
                        final num paid = rData['amountPaid'] ?? 0;
                        inc += paid.toDouble();
                      }
                    }

                    // B. GASTOS: por destinationId del gasto
                    for (var eDoc in expenseDocs) {
                      final eData = eDoc.data() as Map<String, dynamic>;
                      if (eData['destinationId'] == destId) {
                        exp += (eData['monto'] ?? 0).toDouble();
                      }
                    }

                    final double profit = inc - exp;

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => _ActivityProfitabilityDetail(
                              supplierId: supplierId,
                              destinationId: destId,
                              activityName: name,
                              onDataChanged: onDataChanged,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
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
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(name,
                                      style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16)),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                      color: profit >= 0
                                          ? kIncomeColor.withValues(alpha: 0.1)
                                          : kExpenseColor.withValues(
                                              alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8)),
                                  child: Text(
                                      profit >= 0
                                          ? "+ \$${profit.toStringAsFixed(0)}"
                                          : "- \$${profit.abs().toStringAsFixed(0)}",
                                      style: GoogleFonts.poppins(
                                          color: profit >= 0
                                              ? kIncomeColor
                                              : kExpenseColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12)),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward_ios,
                                    size: 12, color: Colors.grey)
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Barra visual
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Row(
                                children: [
                                  if (inc > 0)
                                    Expanded(
                                        flex: inc.toInt(),
                                        child: Container(
                                            height: 6, color: kIncomeColor)),
                                  if (exp > 0)
                                    Expanded(
                                        flex: exp.toInt(),
                                        child: Container(
                                            height: 6, color: kExpenseColor)),
                                  if (inc == 0 && exp == 0)
                                    Expanded(
                                        child: Container(
                                            height: 6, color: Colors.grey[200]))
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("Ventas: \$${inc.toStringAsFixed(0)}",
                                    style: GoogleFonts.poppins(
                                        fontSize: 11, color: Colors.grey[600])),
                                Text("Costos: \$${exp.toStringAsFixed(0)}",
                                    style: GoogleFonts.poppins(
                                        fontSize: 11, color: Colors.red[300])),
                              ],
                            )
                          ],
                        ),
                      ),
                    );
                  }, // itemBuilder
                ); // ListView.builder
              }, // reservasSnapshot builder
            ); // StreamBuilder reservas
          }, // expenseSnapshot builder
        ); // StreamBuilder gastos
      }, // destSnapshot builder
    ); // StreamBuilder destinos
  } // build
}

// -----------------------------------------------------------------------------
// PESTAÑA 3: COSTOS (SOLO ACTIVIDADES)
// -----------------------------------------------------------------------------
class _CostsTab extends StatelessWidget {
  final String supplierId;
  final VoidCallback onAddExpense;

  const _CostsTab({
    required this.supplierId,
    required this.onAddExpense,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // BOTÓN DE REGISTRO
        Padding(
          padding: const EdgeInsets.all(20),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onAddExpense,
              icon: const Icon(Icons.add_circle_outline, color: Colors.white),
              label: Text("Registrar costo",
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: kExpenseColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
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
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Text("No tienes actividades activas.",
                      style: GoogleFonts.poppins(color: Colors.grey)),
                );
              }

              final destinations = snapshot.data!.docs;

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: destinations.length,
                itemBuilder: (context, index) {
                  final doc = destinations[index];
                  final data = doc.data() as Map<String, dynamic>;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ActivityCostCard(
                      title: data['nombre'] ?? 'Sin nombre',
                      subtitle: data['lugar'] ?? '',
                      icon: Icons.map,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => _ActivityExpensesView(
                              supplierId: supplierId,
                              destinationId: doc.id,
                              activityName: data['nombre'] ?? 'Actividad',
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ActivityCostCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _ActivityCostCard(
      {required this.title,
      required this.subtitle,
      required this.icon,
      required this.onTap});

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
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: kPrimaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: kPrimaryColor),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  if (subtitle.isNotEmpty)
                    Text(subtitle,
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey)
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// PESTAÑA 4: MÉTRICAS AVANZADAS (BI DASHBOARD CON FILTRO)
// -----------------------------------------------------------------------------
class _MetricsTab extends StatefulWidget {
  final String supplierId;

  const _MetricsTab({required this.supplierId});

  @override
  State<_MetricsTab> createState() => _MetricsTabState();
}

class _MetricsTabState extends State<_MetricsTab> {
  String _selectedActivityFilter = 'Todas';

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER CON FILTRO
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Rendimiento",
                  style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: kPrimaryColor)),
              // Dropdown de Actividades
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('destinos')
                    .where('supplierId', isEqualTo: widget.supplierId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox();

                  // CORRECCIÓN: Definimos explícitamente el tipo de la lista
                  final List<DropdownMenuItem<String>> items =
                      snapshot.data!.docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final String name =
                        data['nombre']?.toString() ?? 'Sin nombre';

                    return DropdownMenuItem<String>(
                      value: name,
                      child: Text(name, overflow: TextOverflow.ellipsis),
                    );
                  }).toList();

                  items.insert(
                      0,
                      const DropdownMenuItem<String>(
                          value: 'Todas',
                          child: Text("Todas las actividades")));

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200)),
                    width: 180,
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value:
                            items.any((i) => i.value == _selectedActivityFilter)
                                ? _selectedActivityFilter
                                : 'Todas',
                        isExpanded: true,
                        icon: const Icon(Icons.filter_list,
                            size: 18, color: kPrimaryColor),
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: kPrimaryColor),
                        items: items,
                        onChanged: (val) =>
                            setState(() => _selectedActivityFilter = val!),
                      ),
                    ),
                  );
                },
              )
            ],
          ),
          const SizedBox(height: 20),

          // STREAM DE DATOS
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collectionGroup('reservas')
                .where('supplier', isEqualTo: widget.supplierId)
                .snapshots(),
            builder: (context, resSnapshot) {
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('destinos')
                    .where('supplierId', isEqualTo: widget.supplierId)
                    .snapshots(),
                builder: (context, destSnapshot) {
                  if (!resSnapshot.hasData || !destSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  // 1. Filtrar Actividades (Para obtener VISTAS)
                  final allDestinations = destSnapshot.data!.docs;
                  final filteredDestinations =
                      _selectedActivityFilter == 'Todas'
                          ? allDestinations
                          : allDestinations
                              .where((d) =>
                                  (d.data() as Map)['nombre'] ==
                                  _selectedActivityFilter)
                              .toList();

                  int totalViews = 0;
                  for (var d in filteredDestinations) {
                    final data = d.data() as Map<String, dynamic>;
                    // Sumamos las vistas guardadas en el destino
                    // IMPORTANTE: Asegúrate de implementar el PASO 1 mencionado arriba
                    totalViews += (data['profileViews'] ?? 0) as int;
                  }

                  // 2. Filtrar Reservas (Para obtener VENTAS)
                  final allReservas = resSnapshot.data!.docs;
                  final filteredReservas = _selectedActivityFilter == 'Todas'
                      ? allReservas
                      : allReservas
                          .where((r) =>
                              (r.data() as Map)['planName'] ==
                              _selectedActivityFilter)
                          .toList();

                  int totalSales = 0;
                  Map<String, double> revenueMap = {};

                  for (var r in filteredReservas) {
                    final data = r.data() as Map<String, dynamic>;
                    final double paid = (data['amountPaid'] ?? 0).toDouble();

                    // Contamos como venta si hay dinero abonado
                    if (paid > 0) {
                      totalSales++;
                      String key = data['planName'] ?? 'Otros';
                      revenueMap[key] = (revenueMap[key] ?? 0) + paid;
                    }
                  }

                  // CÁLCULOS FINALES
                  // Tasa Conversión: (Ventas / Vistas) * 100
                  double conversionRate =
                      totalViews > 0 ? (totalSales / totalViews) * 100 : 0.0;

                  // Topes lógicos (si hay más ventas que vistas por error de datos)
                  if (conversionRate > 100) conversionRate = 100;

                  return Column(
                    children: [
                      GridView.count(
                        crossAxisCount: 2,
                        crossAxisSpacing: 15,
                        mainAxisSpacing: 15,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: 1.4,
                        children: [
                          // CAMBIO 1: TASA DE CONVERSIÓN
                          _AnalyticCard(
                            title: "Tasa de conversión",
                            value: "${conversionRate.toStringAsFixed(2)}%",
                            icon: Icons.sync_alt,
                            color: Colors.blue,
                            description: "Ventas / Vistas",
                          ),
                          // CAMBIO 2: VISTAS TOTALES
                          _AnalyticCard(
                            title: "Vistas totales",
                            value: totalViews.toString(),
                            icon: Icons.visibility_outlined,
                            color: Colors.purple,
                            description: "Visitas a la actividad",
                          ),
                          _AnalyticCard(
                            title: "Ventas totales",
                            value: totalSales.toString(),
                            icon: Icons.shopping_bag_outlined,
                            color: Colors.teal,
                            description: "Reservas concretadas",
                          ),
                          _AnalyticCard(
                            title: "Actividad top",
                            value: _selectedActivityFilter == 'Todas'
                                ? _getTopActivity(revenueMap)
                                : _selectedActivityFilter,
                            icon: Icons.star_outline,
                            color: Colors.amber[700]!,
                            description: "Mayor ingreso generado",
                            isSmallText: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                      if (_selectedActivityFilter == 'Todas') ...[
                        Text("Distribución de ingresos",
                            style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: kPrimaryColor)),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 250,
                          child: _ActivityPieChart(dataMap: revenueMap),
                        ),
                      ]
                    ],
                  );
                },
              );
            },
          )
        ],
      ),
    );
  }

  String _getTopActivity(Map<String, double> map) {
    if (map.isEmpty) return "N/A";
    var sorted = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.key;
  }
}

class _AnalyticCard extends StatelessWidget {
  final String title;
  final String value;
  final String description;
  final IconData icon;
  final Color color;
  final bool isSmallText;

  const _AnalyticCard({
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 20),
              Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.5),
                      shape: BoxShape.circle))
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                      fontSize: isSmallText ? 16 : 22,
                      fontWeight: FontWeight.bold,
                      color: kPrimaryColor)),
              Text(title,
                  style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600])),
              const SizedBox(height: 2),
              Text(description,
                  style: GoogleFonts.poppins(
                      fontSize: 9, color: Colors.grey[400])),
            ],
          )
        ],
      ),
    );
  }
}

// GRÁFICO DE DONA (FL_CHART)
class _ActivityPieChart extends StatelessWidget {
  final Map<String, double> dataMap;

  const _ActivityPieChart({required this.dataMap});

  @override
  Widget build(BuildContext context) {
    if (dataMap.isEmpty) return const SizedBox();

    // Convertir mapa a Sections
    int i = 0;
    // Colores para el gráfico
    final List<Color> colors = [
      kPrimaryColor,
      kExpenseColor,
      kIncomeColor,
      kWarningColor,
      Colors.purple,
      Colors.teal,
      Colors.blueGrey,
    ];

    List<PieChartSectionData> sections = [];
    double total = dataMap.values.fold(0, (acc, item) => acc + item);

    dataMap.forEach((key, value) {
      final isLarge =
          value / total > 0.15; // Si es mayor al 15% mostramos título
      sections.add(PieChartSectionData(
        color: colors[i % colors.length],
        value: value,
        title: isLarge ? "${((value / total) * 100).toStringAsFixed(0)}%" : "",
        radius: isLarge ? 60 : 50,
        titleStyle: GoogleFonts.poppins(
            fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      ));
      i++;
    });

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 40,
              sectionsSpace: 2,
            ),
          ),
        ),
        const SizedBox(width: 20),
        // Leyenda Manual
        Expanded(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: dataMap.length,
            itemBuilder: (context, index) {
              String key = dataMap.keys.elementAt(index);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                            color: colors[index % colors.length],
                            shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(key,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                                fontSize: 11, color: Colors.grey[700])))
                  ],
                ),
              );
            },
          ),
        )
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// MODAL PARA AGREGAR / EDITAR GASTOS (DISEÑO MEJORADO)
// -----------------------------------------------------------------------------
class _AddExpenseModal extends StatefulWidget {
  final String supplierId;
  final Map<String, dynamic>? expenseToEdit;
  final VoidCallback onExpenseSaved;
  final String? preSelectedDestinationId; // <--- NUEVO PARÁMETRO

  const _AddExpenseModal(
      {required this.supplierId,
      this.expenseToEdit,
      required this.onExpenseSaved,
      this.preSelectedDestinationId}); // <--- AGREGAR AQUÍ

  @override
  State<_AddExpenseModal> createState() => _AddExpenseModalState();
}

class _AddExpenseModalState extends State<_AddExpenseModal> {
  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();

  String _category = 'Operativo';
  DateTime _selectedDate = DateTime.now();
  String? _selectedDestinationId;
  bool _isSaving = false;

  final List<String> _categories = [
    'Operativo',
    'Transporte',
    'Comida',
    'Marketing',
    'Nómina',
    'Mantenimiento',
    'Otros'
  ];

  @override
  void initState() {
    super.initState();
    // Prioridad: 1. Edición, 2. Preselección, 3. Null
    if (widget.expenseToEdit != null) {
      final e = widget.expenseToEdit!;
      _descCtrl.text = e['descripcion'];
      _amountCtrl.text = e['monto'].toString();
      _category = e['categoria'];
      _selectedDate = _parseDate(e['fecha']);
      _selectedDestinationId = e['destinationId'];
    } else if (widget.preSelectedDestinationId != null) {
      // Si venimos de la pantalla de detalle, pre-cargamos el ID
      _selectedDestinationId = widget.preSelectedDestinationId;
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    // Validación: Actividad obligatoria (según solicitud)
    if (_selectedDestinationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Debes seleccionar una actividad para el gasto"),
          backgroundColor: Colors.red));
      return;
    }

    setState(() => _isSaving = true);

    try {
      final double amount = double.parse(_amountCtrl.text.replaceAll(',', '.'));

      final data = {
        'supplierId': widget.supplierId,
        'monto': amount,
        'descripcion': _descCtrl.text,
        'categoria': _category,
        'fecha': Timestamp.fromDate(_selectedDate),
        'destinationId': _selectedDestinationId,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (widget.expenseToEdit != null) {
        // Editar
        await FirebaseFirestore.instance
            .collection('gastos')
            .doc(widget.expenseToEdit!['id'])
            .update(data);
      } else {
        // Crear
        data['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('gastos').add(data);
      }

      widget.onExpenseSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint("Error: $e");
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Altura dinámica para el teclado
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                  widget.expenseToEdit != null
                      ? "Editar costo"
                      : "Registrar costo",
                  style: TextStyle(
                      color: kPrimaryColor,
                      fontFamily: 'Poppins',
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 25),

              // 1. SELECTOR DE ACTIVIDAD (Destacado por ser obligatorio)
              Text("Actividad",
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700])),
              const SizedBox(height: 8),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('destinos')
                    .where('supplierId', isEqualTo: widget.supplierId)
                    .where('status', isEqualTo: 'active')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const LinearProgressIndicator();
                  }

                  final items = snapshot.data!.docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return DropdownMenuItem(
                      value: doc.id,
                      child: Text(data['nombre'] ?? 'Sin nombre',
                          overflow: TextOverflow.ellipsis),
                    );
                  }).toList();

                  // Opción General al final (si la quieres permitir, sino quítala)
                  // items.add(const DropdownMenuItem(value: null, child: Text("Gasto Operativo General (Oficina, etc)")));

                  return DropdownButtonFormField<String>(
                    initialValue: _selectedDestinationId,
                    isExpanded: true,
                    hint: const Text("Selecciona la actividad"),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: kPrimaryColor.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                      prefixIcon:
                          const Icon(Icons.map_rounded, color: kPrimaryColor),
                    ),
                    items: items,
                    onChanged: (v) =>
                        setState(() => _selectedDestinationId = v),
                  );
                },
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  // 2. MONTO
                  Expanded(
                    flex: 4,
                    child: TextFormField(
                      controller: _amountCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold, fontSize: 18),
                      decoration: InputDecoration(
                        labelText: "Monto",
                        prefixText: "\$ ",
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (v) => v!.isEmpty ? "Requerido" : null,
                    ),
                  ),
                  const SizedBox(width: 15),
                  // 3. FECHA
                  Expanded(
                    flex: 3,
                    child: InkWell(
                      onTap: () async {
                        final d = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now());
                        if (d != null) setState(() => _selectedDate = d);
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: "Fecha",
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          prefixIcon:
                              const Icon(Icons.calendar_today, size: 18),
                        ),
                        child: Text(DateFormat('dd/MM').format(_selectedDate),
                            style: GoogleFonts.poppins(fontSize: 14)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),

              // 4. DESCRIPCIÓN
              TextFormField(
                controller: _descCtrl,
                decoration: InputDecoration(
                  labelText: "Descripción del costo",
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.description_outlined),
                ),
                validator: (v) => v!.isEmpty ? "Requerido" : null,
              ),
              const SizedBox(height: 15),

              // 5. CATEGORÍA
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: InputDecoration(
                  labelText: "Categoría",
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.category_outlined),
                ),
                items: _categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _category = v!),
              ),

              const SizedBox(height: 30),

              // BOTÓN GUARDAR
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kExpenseColor,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 5,
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          widget.expenseToEdit != null
                              ? "Actualizar costo"
                              : "Guardar costo",
                          style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _KPICard extends StatelessWidget {
  final String title;
  final double amount;
  final Color color;
  final IconData icon;
  final VoidCallback? onTap; // <--- Nuevo parámetro opcional

  const _KPICard({
    required this.title,
    required this.amount,
    required this.color,
    required this.icon,
    this.onTap, // <--- Recibirlo
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // <--- Envolver en GestureDetector
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5))
            ]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8)),
                    child: Icon(icon, color: Colors.white, size: 18)),
                // Icono indicativo de click si hay acción
                if (onTap != null)
                  const Icon(Icons.arrow_forward,
                      color: Colors.white54, size: 16)
              ],
            ),
            const SizedBox(height: 15),
            Text(NumberFormat.currency(symbol: '\$').format(amount),
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 22)),
            Text(title,
                style:
                    GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _MiniKPI extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final bool isPositive;

  const _MiniKPI(
      {required this.label,
      required this.amount,
      required this.color,
      required this.isPositive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey)),
          const SizedBox(height: 4),
          Text("\$${amount.toStringAsFixed(0)}",
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold, fontSize: 14, color: color)),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// GRÁFICO DE LÍNEAS MEJORADO (CON FECHAS Y GRADIENTES)
// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------
// GRÁFICO DE LÍNEAS MEJORADO (LÍNEAS CONTINUAS + FECHAS)
// -----------------------------------------------------------------------------
class _FinanceLineChart extends StatelessWidget {
  final List<Map<String, dynamic>> rawData;

  const _FinanceLineChart({required this.rawData});

  @override
  Widget build(BuildContext context) {
    if (rawData.isEmpty) {
      return Center(
          child: Text("Sin datos para graficar",
              style: GoogleFonts.poppins(color: Colors.grey)));
    }

    // 1. Preparar datos cronológicos
    // Ordenamos por fecha
    final List<Map<String, dynamic>> sortedData = List.from(rawData)
      ..sort((a, b) => a['date'].compareTo(b['date']));

    // 2. Agrupar acumulados para que la línea tenga sentido
    // Creamos puntos secuenciales (0, 1, 2...) para que la línea sea continua
    // y no se rompa si hay días vacíos.
    List<FlSpot> incomeSpots = [];
    List<FlSpot> expenseSpots = [];

    double currentIncome = 0;
    double currentExpense = 0;

    // Si solo hay 1 punto, agregamos un punto inicial en 0 para que se dibuje una línea
    if (sortedData.length == 1) {
      incomeSpots.add(const FlSpot(0, 0));
      expenseSpots.add(const FlSpot(0, 0));
    }

    for (int i = 0; i < sortedData.length; i++) {
      final item = sortedData[i];
      // Índice X ajustado (si agregamos punto inicial, desplazamos +1)
      double xIndex = (sortedData.length == 1) ? 1.0 : i.toDouble();

      if (item['type'] == 'income') {
        currentIncome += (item['amount'] as num).toDouble();
      } else {
        currentExpense += (item['amount'] as num).toDouble();
      }

      // Creamos un punto acumulativo o puntual.
      // Para flujo de caja, mejor mostrar el acumulado del periodo hasta ese momento
      incomeSpots.add(FlSpot(xIndex, currentIncome));
      expenseSpots.add(FlSpot(xIndex, currentExpense));
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: _calculateInterval(currentIncome, currentExpense),
          getDrawingHorizontalLine: (value) =>
              FlLine(color: Colors.grey.shade100, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1, // Mostrar etiquetas según índice
              getTitlesWidget: (value, meta) {
                int index = value.toInt();
                // Ajuste si agregamos punto fantasma
                if (sortedData.length == 1) index = index - 1;

                if (index < 0 || index >= sortedData.length) {
                  return const SizedBox();
                }

                // Evitar amontonamiento de fechas
                // Si hay muchos datos, mostrar solo 1 de cada 3 o 4
                if (sortedData.length > 6 &&
                    index % (sortedData.length ~/ 4) != 0) {
                  return const SizedBox();
                }

                final date = sortedData[index]['date'] as DateTime;
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    DateFormat('d MMM').format(date),
                    style:
                        GoogleFonts.poppins(fontSize: 10, color: Colors.grey),
                  ),
                );
              },
              reservedSize: 30,
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          // LÍNEA DE INGRESOS
          LineChartBarData(
            spots: incomeSpots,
            isCurved: true,
            curveSmoothness: 0.35,
            preventCurveOverShooting: true,
            color: kIncomeColor,
            barWidth: 3,
            isStrokeCapRound: true,
            // Importante: show: false oculta los puntos individuales, dejando solo la línea
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  kIncomeColor.withValues(alpha: 0.3),
                  kIncomeColor.withValues(alpha: 0.0)
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          // LÍNEA DE GASTOS
          LineChartBarData(
            spots: expenseSpots,
            isCurved: true,
            curveSmoothness: 0.35,
            preventCurveOverShooting: true,
            color: kExpenseColor,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  kExpenseColor.withValues(alpha: 0.3),
                  kExpenseColor.withValues(alpha: 0.0)
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
        // Tooltip al tocar
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((LineBarSpot touchedSpot) {
                final textStyle = GoogleFonts.poppins(
                  color: touchedSpot.bar.color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                );
                return LineTooltipItem(
                  '\$${touchedSpot.y.toStringAsFixed(0)}',
                  textStyle,
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  double _calculateInterval(double max1, double max2) {
    double maxVal = max1 > max2 ? max1 : max2;
    if (maxVal == 0) return 100;
    return maxVal / 4; // Dividir en 4 líneas horizontales
  }
}

// -----------------------------------------------------------------------------
// VISTA DETALLADA DE GASTOS POR ACTIVIDAD (CON STREAM REAL-TIME)
// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------
// VISTA DETALLADA DE GASTOS POR ACTIVIDAD
// -----------------------------------------------------------------------------
class _ActivityExpensesView extends StatelessWidget {
  final String supplierId;
  final String destinationId;
  final String activityName;

  const _ActivityExpensesView({
    required this.supplierId,
    required this.destinationId,
    required this.activityName,
  });

  void _showEditDeleteOptions(
      BuildContext context, Map<String, dynamic> expense) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(width: 40, height: 4, color: Colors.grey[300]),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.blue),
              title: const Text(
                "Editar costo",
                style: TextStyle(fontFamily: 'Poppins'),
              ),
              onTap: () {
                Navigator.pop(context);
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (c) => _AddExpenseModal(
                    supplierId: supplierId,
                    expenseToEdit: expense,
                    onExpenseSaved: () {},
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text("Eliminar costo",
                  style: TextStyle(fontFamily: 'Poppins')),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(context, expense['id']);
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, String docId) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("¿Eliminar costo?"),
        content: const Text(
          "Esta acción eliminará el registro permanentemente.",
          style: TextStyle(fontFamily: 'Poppins'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text("Cancelar",
                  style: TextStyle(color: Colors.grey, fontFamily: 'Poppins'))),
          TextButton(
              onPressed: () {
                FirebaseFirestore.instance
                    .collection('gastos')
                    .doc(docId)
                    .delete();
                Navigator.pop(c);
              },
              child: const Text("Eliminar",
                  style: TextStyle(color: Colors.red, fontFamily: 'Poppins'))),
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
          // Botón "+" para agregar gasto DIRECTO a esta actividad
          IconButton(
            icon: const Icon(Icons.add_circle, color: kPrimaryColor),
            tooltip: "Agregar gasto a esta actividad",
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => _AddExpenseModal(
                  supplierId: supplierId,
                  preSelectedDestinationId: destinationId, // <--- CLAVE
                  onExpenseSaved: () {},
                ),
              );
            },
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('gastos')
            .where('supplierId', isEqualTo: supplierId)
            .where('destinationId', isEqualTo: destinationId)
            .orderBy('fecha', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            // DIAGNÓSTICO DE ERROR DE ÍNDICE
            debugPrint("Error loading expenses: ${snapshot.error}");
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  "Error cargando gastos.\n\nSi es la primera vez, revisa la consola de depuración para crear el índice de Firebase.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(color: Colors.red),
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_outlined,
                      size: 60, color: Colors.grey[300]),
                  const SizedBox(height: 10),
                  Text("No hay costos registrados",
                      style: GoogleFonts.poppins(color: Colors.grey)),
                ],
              ),
            );
          }

          final expenses = snapshot.data!.docs;

          // Calcular total localmente para mostrarlo arriba
          double totalActivityExpenses = 0;
          for (var e in expenses) {
            totalActivityExpenses += (e['monto'] as num).toDouble();
          }

          return Column(
            children: [
              // RESUMEN RÁPIDO
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Total de costos", style: GoogleFonts.poppins()),
                    Text("\$${totalActivityExpenses.toStringAsFixed(2)}",
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: kExpenseColor)),
                  ],
                ),
              ),

              // LISTA
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: expenses.length,
                  itemBuilder: (context, index) {
                    final doc = expenses[index];
                    final data = doc.data() as Map<String, dynamic>;
                    data['id'] = doc.id; // Importante para editar/borrar

                    final DateTime date = _parseDate(data['fecha']);

                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade200)),
                      child: ListTile(
                        onTap: () => _showEditDeleteOptions(context, data),
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
                            "${DateFormat('dd/MM/yy').format(date)} • ${data['categoria']}",
                            style: GoogleFonts.poppins(fontSize: 12)),
                        trailing: Text(
                          "-\$${(data['monto'] as num).toStringAsFixed(2)}",
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              color: kExpenseColor,
                              fontSize: 15),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// PANTALLA: DETALLE DE RENTABILIDAD (ACTUALIZADA)
// -----------------------------------------------------------------------------
class _ActivityProfitabilityDetail extends StatelessWidget {
  final String supplierId;
  final String destinationId;
  final String activityName;
  final VoidCallback
      onDataChanged; // Recibimos el callback para avisar al padre

  const _ActivityProfitabilityDetail({
    required this.supplierId,
    required this.destinationId,
    required this.activityName,
    required this.onDataChanged,
  });

  void _showExpenseOptions(BuildContext context, Map<String, dynamic> expense) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.blue),
              title: const Text(
                "Editar costo",
                style: TextStyle(fontFamily: 'Poppins'),
              ),
              onTap: () {
                Navigator.pop(c);
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (ctx) => _AddExpenseModal(
                    supplierId: supplierId,
                    expenseToEdit: expense,
                    onExpenseSaved:
                        onDataChanged, // Importante: Actualiza al guardar
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text("Eliminar costo",
                  style: TextStyle(fontFamily: 'Poppins')),
              onTap: () {
                Navigator.pop(c);
                _confirmDelete(context, expense['id']);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, String docId) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text(
          "¿Eliminar costo?",
          style: TextStyle(fontFamily: 'Poppins'),
        ),
        content: const Text(
          "Esta acción es irreversible.",
          style: TextStyle(fontFamily: 'Poppins'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text("Cancelar",
                  style: TextStyle(color: Colors.grey, fontFamily: 'Poppins'))),
          TextButton(
              onPressed: () async {
                // Borrar de Firebase
                await FirebaseFirestore.instance
                    .collection('gastos')
                    .doc(docId)
                    .delete();

                // Actualizar los datos globales
                onDataChanged();

                if (context.mounted) Navigator.pop(c);
              },
              child: const Text("Eliminar",
                  style: TextStyle(color: Colors.red, fontFamily: 'Poppins'))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: Text("Detalle financiero",
            style: GoogleFonts.poppins(
                color: kPrimaryColor, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // 1. STREAM DE GASTOS
        stream: FirebaseFirestore.instance
            .collection('gastos')
            .where('supplierId', isEqualTo: supplierId)
            .where('destinationId', isEqualTo: destinationId)
            .snapshots(),
        builder: (context, expensesSnap) {
          return StreamBuilder<QuerySnapshot>(
            // 2. STREAM DE INGRESOS
            stream: FirebaseFirestore.instance
                .collectionGroup('reservas')
                .where('supplier', isEqualTo: supplierId)
                .where('planName', isEqualTo: activityName)
                .snapshots(),
            builder: (context, incomeSnap) {
              if (!expensesSnap.hasData || !incomeSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              List<Map<String, dynamic>> items = [];
              double totalIncome = 0;
              double totalExpense = 0;

              // Procesar Gastos
              for (var doc in expensesSnap.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                data['id'] = doc.id; // ASEGURAMOS QUE EL ID ESTÉ EN EL MAPA RAW

                final double amount = (data['monto'] ?? 0).toDouble();
                totalExpense += amount;

                items.add({
                  'type': 'expense',
                  'amount': amount,
                  'date': _parseDate(data['fecha']),
                  'title': data['descripcion'] ?? 'Gasto',
                  'subtitle': data['categoria'] ?? 'Operativo',
                  'raw': data, // Pasamos la data completa con ID incluido
                  'id': doc.id,
                });
              }

              // Procesar Ingresos (Ventas)
              for (var doc in incomeSnap.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                final double paid = (data['amountPaid'] ?? 0).toDouble();
                final String status = data['estado'] ?? 'pendiente';

                if (paid > 0 || status == 'verificado') {
                  totalIncome += paid;
                  items.add({
                    'type': 'income',
                    'amount': paid,
                    'date': _parseDate(data['createdAt']),
                    'title': data['name'] ?? 'Venta',
                    'subtitle':
                        status == 'verificado' ? 'Verificado' : 'Parcial',
                    'raw': data,
                    'id': doc.id,
                  });
                }
              }

              items.sort((a, b) => b['date'].compareTo(a['date']));
              final double profit = totalIncome - totalExpense;

              return Column(
                children: [
                  // HEADER RESUMEN
                  Container(
                    padding: const EdgeInsets.all(20),
                    color: Colors.white,
                    child: Column(
                      children: [
                        Text(activityName,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: kPrimaryColor)),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                                child: _MiniSummary(
                                    label: "Ingresos",
                                    amount: totalIncome,
                                    color: kIncomeColor)),
                            Container(
                                width: 1, height: 40, color: Colors.grey[200]),
                            Expanded(
                                child: _MiniSummary(
                                    label: "Costos",
                                    amount: totalExpense,
                                    color: kExpenseColor)),
                            Container(
                                width: 1, height: 40, color: Colors.grey[200]),
                            Expanded(
                                child: _MiniSummary(
                                    label: "Neto",
                                    amount: profit,
                                    color: profit >= 0
                                        ? kIncomeColor
                                        : kExpenseColor,
                                    isBold: true)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // LISTA MIXTA
                  Expanded(
                    child: items.isEmpty
                        ? Center(
                            child: Text("Sin movimientos",
                                style: GoogleFonts.poppins(color: Colors.grey)))
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: items.length,
                            separatorBuilder: (c, i) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final item = items[index];
                              final bool isIncome = item['type'] == 'income';

                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border(
                                    left: BorderSide(
                                      color: isIncome
                                          ? kIncomeColor
                                          : kExpenseColor,
                                      width: 4,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: (isIncome
                                                ? kIncomeColor
                                                : kExpenseColor)
                                            .withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        isIncome
                                            ? Icons.arrow_downward
                                            : Icons.arrow_upward,
                                        color: isIncome
                                            ? kIncomeColor
                                            : kExpenseColor,
                                        size: 18,
                                      ),
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
                                              "${DateFormat('dd MMM').format(item['date'])} • ${item['subtitle']}",
                                              style: GoogleFonts.poppins(
                                                  fontSize: 11,
                                                  color: Colors.grey)),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                            "\$${item['amount'].toStringAsFixed(2)}",
                                            style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.bold,
                                                color: isIncome
                                                    ? kIncomeColor
                                                    : kExpenseColor)),

                                        // BOTÓN GESTIONAR (Solo para Gastos)
                                        if (!isIncome)
                                          GestureDetector(
                                            onTap: () {
                                              // Aquí pasamos el item['raw'] que ya tiene el ID correcto
                                              _showExpenseOptions(
                                                  context, item['raw']);
                                            },
                                            child: Padding(
                                              padding: const EdgeInsets.only(
                                                  top: 4.0),
                                              child: Text("Gestionar",
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 10,
                                                    color: const Color.fromARGB(
                                                        255, 0, 0, 0),
                                                  )),
                                            ),
                                          )
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
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
    return Column(
      children: [
        Text(label,
            style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 4),
        Text("\$${amount.toStringAsFixed(0)}",
            style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                color: color)),
      ],
    );
  }
}
