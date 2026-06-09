import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'create_event/create_event_screen.dart';
import 'supplier_verify_payments_screen.dart';

const Color kPrimaryColor = Color.fromRGBO(17, 48, 73, 1);
const Color kBg = Color(0xFFF3F7FE);

// ─────────────────────────────────────────────────────────────────────────────
// Modelo de actividad cargada
// ─────────────────────────────────────────────────────────────────────────────
class _Activity {
  final String id;
  final String nombre;
  final String imagen;
  final Map<String, dynamic> fullData;
  // Fechas en calendario (paquetes tipo 'dated')
  final List<_CalendarDate> calendarDates;
  // Fecha de control (paquetes sin fecha pública)
  final DateTime? controlDate;
  final String tipo; // 'dated' | 'fixed' | 'flexible'

  _Activity({
    required this.id,
    required this.nombre,
    required this.imagen,
    required this.fullData,
    required this.calendarDates,
    required this.controlDate,
    required this.tipo,
  });
}

class _CalendarDate {
  final DateTime date;
  final String hora;
  final int cupos;
  final int pkgIndex;
  final int dateIndex;
  final String pkgName;
  final double precio;

  _CalendarDate({
    required this.date,
    required this.hora,
    required this.cupos,
    required this.pkgIndex,
    required this.dateIndex,
    required this.pkgName,
    required this.precio,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Pantalla principal
// ─────────────────────────────────────────────────────────────────────────────
class SupplierCalendarScreen extends StatefulWidget {
  final String userId;
  const SupplierCalendarScreen({super.key, required this.userId});

  @override
  State<SupplierCalendarScreen> createState() => _SupplierCalendarScreenState();
}

class _SupplierCalendarScreenState extends State<SupplierCalendarScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _isLoading = true;

  // Todas las actividades cargadas
  // Actividades sin ninguna fecha (ni control ni calendario)
  List<_Activity> _noDateActivities = [];

  // Mapa de fecha → lista de actividades con esa fecha
  Map<DateTime, List<_Activity>> _calendarMap = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedDay = DateTime.now();
    _loadActivities();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Carga de datos ──────────────────────────────────────────────────────────
  Future<void> _loadActivities() async {
    setState(() => _isLoading = true);

    final Map<DateTime, List<_Activity>> calMap = {};
    final List<_Activity> allActivities = [];
    final List<_Activity> noDate = [];

    try {
      final snap = await FirebaseFirestore.instance
          .collection('destinos')
          .where('supplierId', isEqualTo: widget.userId)
          .get();

      for (final doc in snap.docs) {
        final data = doc.data();
        final String nombre = data['nombre'] ?? 'Actividad';
        final String imagen = (data['imagenes'] as List?)?.isNotEmpty == true
            ? (data['imagenes'] as List).first.toString()
            : '';
        final paquetes = data['paquetes'] as List<dynamic>? ?? [];

        final List<_CalendarDate> calDates = [];
        DateTime? controlDate;
        String tipoGeneral = 'flexible';

        for (int i = 0; i < paquetes.length; i++) {
          final pkg = paquetes[i] as Map? ?? {};
          final tipo = pkg['tipo']?.toString() ?? 'flexible';
          final pkgName = pkg['miniDescripcion']?.toString() ?? 'Estándar';
          final double precio = (pkg['precio'] as num?)?.toDouble() ?? 0.0;

          if (tipo == 'dated') {
            tipoGeneral = 'dated';
            final disp = pkg['disponibilidad'] as List<dynamic>? ?? [];
            for (int j = 0; j < disp.length; j++) {
              final d = disp[j] as Map? ?? {};
              DateTime? date;
              if (d['fechaInicio'] != null) {
                try {
                  date = DateTime.parse(d['fechaInicio'].toString());
                } catch (_) {}
              } else if (d['fecha'] != null) {
                try {
                  date = DateTime.parse(d['fecha'].toString());
                } catch (_) {}
              }
              if (date != null) {
                calDates.add(_CalendarDate(
                  date: date,
                  hora: d['horaInicio']?.toString() ??
                      d['hora']?.toString() ??
                      'Todo el día',
                  cupos: (d['cupos'] as num?)?.toInt() ?? 0,
                  pkgIndex: i,
                  dateIndex: j,
                  pkgName: pkgName,
                  precio: precio,
                ));
              }
            }
          } else {
            tipoGeneral = tipo;
            // Fecha de control para paquetes sin fecha pública
            if (pkg['fechaControl'] != null) {
              try {
                final fc = DateTime.parse(pkg['fechaControl'].toString());
                if (controlDate == null || fc.isBefore(controlDate)) {
                  controlDate = fc;
                }
              } catch (_) {}
            }
          }
        }

        final activity = _Activity(
          id: doc.id,
          nombre: nombre,
          imagen: imagen,
          fullData: data,
          calendarDates: calDates,
          controlDate: controlDate,
          tipo: tipoGeneral,
        );

        allActivities.add(activity);

        // Registrar en el mapa de calendario
        if (calDates.isNotEmpty) {
          for (final cd in calDates) {
            final key = DateTime.utc(cd.date.year, cd.date.month, cd.date.day);
            calMap.putIfAbsent(key, () => []);
            if (!calMap[key]!.any((a) => a.id == activity.id)) {
              calMap[key]!.add(activity);
            }
          }
        } else if (controlDate != null) {
          final key = DateTime.utc(
              controlDate.year, controlDate.month, controlDate.day);
          calMap.putIfAbsent(key, () => []);
          calMap[key]!.add(activity);
        } else {
          noDate.add(activity);
        }
      }

      if (mounted) {
        setState(() {
          _calendarMap = calMap;
          _noDateActivities = noDate;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando actividades del calendario: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<_Activity> _getActivitiesForDay(DateTime day) {
    final key = DateTime.utc(day.year, day.month, day.day);
    return _calendarMap[key] ?? [];
  }

  // ── Actualizar cupos en Firestore ────────────────────────────────────────
  Future<void> _updateSpots(
      String docId, int pkgIndex, int dateIndex, int newSpots) async {
    try {
      final ref = FirebaseFirestore.instance.collection('destinos').doc(docId);
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) return;
        final List<dynamic> paquetes = List.from(snap.data()!['paquetes']);
        if (pkgIndex < paquetes.length) {
          final pkg = Map<String, dynamic>.from(paquetes[pkgIndex]);
          final disp = List<dynamic>.from(pkg['disponibilidad'] ?? []);
          if (dateIndex < disp.length) {
            final d = Map<String, dynamic>.from(disp[dateIndex]);
            d['cupos'] = newSpots;
            disp[dateIndex] = d;
            pkg['disponibilidad'] = disp;
            paquetes[pkgIndex] = pkg;
            tx.update(ref, {'paquetes': paquetes});
          }
        }
      });
      await _loadActivities();
    } catch (e) {
      debugPrint('Error actualizando cupos: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Calendario ─────────────────────────────────────────────────
            Container(
              margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4)),
                ],
              ),
              padding: const EdgeInsets.only(bottom: 10),
              child: TableCalendar(
                locale: 'es_ES',
                firstDay: DateTime.utc(2024, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                selectedDayPredicate: (d) => isSameDay(_selectedDay, d),
                eventLoader: _getActivitiesForDay,
                calendarStyle: CalendarStyle(
                  todayDecoration: BoxDecoration(
                      color: kPrimaryColor.withValues(alpha: 0.45),
                      shape: BoxShape.circle),
                  selectedDecoration: const BoxDecoration(
                      color: kPrimaryColor, shape: BoxShape.circle),
                  markerDecoration: const BoxDecoration(
                      color: Colors.green, shape: BoxShape.circle),
                ),
                headerStyle: HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold, fontSize: 16),
                  titleTextFormatter: (date, locale) {
                    final s = DateFormat('MMMM yyyy', locale).format(date);
                    return s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
                  },
                ),
                onDaySelected: (selected, focused) => setState(() {
                  _selectedDay = selected;
                  _focusedDay = focused;
                  // Cambiar a tab de calendario al tocar un día
                  _tabController.animateTo(0);
                }),
              ),
            ),

            const SizedBox(height: 10),

            // ── Tabs: Calendario | Sin fecha ───────────────────────────────
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6)
                ],
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: kPrimaryColor,
                unselectedLabelColor: Colors.grey,
                indicatorColor: kPrimaryColor,
                labelStyle: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold, fontSize: 13),
                tabs: [
                  const Tab(text: 'Calendario'),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Sin fecha'),
                        if (_noDateActivities.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                                color: kPrimaryColor,
                                borderRadius: BorderRadius.circular(10)),
                            child: Text(
                              '${_noDateActivities.length}',
                              style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ── Contenido de tabs ──────────────────────────────────────────
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: kPrimaryColor))
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _CalendarTab(
                          selectedDay: _selectedDay!,
                          activities: _getActivitiesForDay(_selectedDay!),
                          supplierId: widget.userId,
                          onEdit: () => _loadActivities(),
                          onUpdateSpots: _updateSpots,
                          onDetailTap: (a) => _showActivityDetail(context, a),
                        ),
                        _NoDateTab(
                          activities: _noDateActivities,
                          supplierId: widget.userId,
                          onEdit: () => _loadActivities(),
                          onDetailTap: (a) => _showActivityDetail(context, a),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Modal de detalle de actividad ────────────────────────────────────────
  void _showActivityDetail(BuildContext context, _Activity activity) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _ActivityDetailSheet(
        activity: activity,
        supplierId: widget.userId,
        selectedDay: _selectedDay,
        onEdit: () {
          Navigator.pop(context);
          _loadActivities();
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 1: Actividades del día seleccionado
// ─────────────────────────────────────────────────────────────────────────────
class _CalendarTab extends StatelessWidget {
  final DateTime selectedDay;
  final List<_Activity> activities;
  final String supplierId;
  final VoidCallback onEdit;
  final Function(String, int, int, int) onUpdateSpots;
  final Function(_Activity) onDetailTap;

  const _CalendarTab({
    required this.selectedDay,
    required this.activities,
    required this.supplierId,
    required this.onEdit,
    required this.onUpdateSpots,
    required this.onDetailTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('d MMM yyyy', 'es').format(selectedDay);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
          child: Text(
            'Actividades · ${dateStr[0].toUpperCase()}${dateStr.substring(1)}',
            style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: kPrimaryColor),
          ),
        ),
        Expanded(
          child: activities.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_available,
                          size: 50, color: Colors.grey.withValues(alpha: 0.35)),
                      const SizedBox(height: 10),
                      Text('Sin actividades para este día',
                          style: GoogleFonts.poppins(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  itemCount: activities.length,
                  itemBuilder: (ctx, i) {
                    return _ActivityCard(
                      activity: activities[i],
                      selectedDay: selectedDay,
                      onTap: () => onDetailTap(activities[i]),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 2: Actividades sin fecha
// ─────────────────────────────────────────────────────────────────────────────
class _NoDateTab extends StatelessWidget {
  final List<_Activity> activities;
  final String supplierId;
  final VoidCallback onEdit;
  final Function(_Activity) onDetailTap;

  const _NoDateTab({
    required this.activities,
    required this.supplierId,
    required this.onEdit,
    required this.onDetailTap,
  });

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline,
                size: 50, color: Colors.green.withValues(alpha: 0.4)),
            const SizedBox(height: 10),
            Text('Todas las actividades tienen fechas asignadas',
                style: GoogleFonts.poppins(color: Colors.grey),
                textAlign: TextAlign.center),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
          child: Text(
            'Actividades sin fecha programada',
            style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: kPrimaryColor),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            itemCount: activities.length,
            itemBuilder: (ctx, i) => _ActivityCard(
              activity: activities[i],
              selectedDay: null,
              onTap: () => onDetailTap(activities[i]),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card de actividad compacta
// ─────────────────────────────────────────────────────────────────────────────
class _ActivityCard extends StatelessWidget {
  final _Activity activity;
  final DateTime? selectedDay;
  final VoidCallback onTap;

  const _ActivityCard({
    required this.activity,
    required this.selectedDay,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Fechas del día seleccionado para esta actividad
    final datesForDay = selectedDay != null
        ? activity.calendarDates.where((cd) {
            final key = DateTime.utc(cd.date.year, cd.date.month, cd.date.day);
            final selKey = DateTime.utc(
                selectedDay!.year, selectedDay!.month, selectedDay!.day);
            return key == selKey;
          }).toList()
        : <_CalendarDate>[];

    final hasBlocked = datesForDay.any((d) => d.cupos == 0);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: hasBlocked ? Colors.red.shade100 : Colors.transparent),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 3))
          ],
        ),
        child: Row(
          children: [
            // Imagen
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: activity.imagen.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: activity.imagen,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: 64,
                      height: 64,
                      color: Colors.grey[100],
                      child: const Icon(Icons.image,
                          color: Colors.grey, size: 28)),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(activity.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: kPrimaryColor)),
                  const SizedBox(height: 4),
                  if (datesForDay.isNotEmpty) ...[
                    // Mostrar horarios del día
                    ...datesForDay.map((cd) => Text(
                          '${cd.pkgName}  ·  ${cd.hora}  ·  ${cd.cupos == 0 ? "CERRADO" : "${cd.cupos} cupos"}',
                          style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: cd.cupos == 0
                                  ? Colors.red
                                  : Colors.grey[600]),
                        )),
                  ] else if (activity.controlDate != null) ...[
                    Text(
                      'Control: ${DateFormat('d MMM yyyy', 'es').format(activity.controlDate!)}',
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: Colors.amber[700]),
                    ),
                  ] else ...[
                    Text('Sin fecha asignada',
                        style: GoogleFonts.poppins(
                            fontSize: 11, color: Colors.grey[400])),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Modal detalle de actividad
// ─────────────────────────────────────────────────────────────────────────────
class _ActivityDetailSheet extends StatelessWidget {
  final _Activity activity;
  final String supplierId;
  final DateTime? selectedDay;
  final VoidCallback onEdit;

  const _ActivityDetailSheet({
    required this.activity,
    required this.supplierId,
    required this.selectedDay,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final datesForDay = selectedDay != null
        ? activity.calendarDates.where((cd) {
            final key = DateTime.utc(cd.date.year, cd.date.month, cd.date.day);
            final sel = DateTime.utc(
                selectedDay!.year, selectedDay!.month, selectedDay!.day);
            return key == sel;
          }).toList()
        : activity.calendarDates.take(5).toList();

    final divisa =
        activity.fullData['divisa']?.toString() == 'eur' ? '€' : '\$';

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, scrollCtrl) => SingleChildScrollView(
        controller: scrollCtrl,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),

              // ── Cabecera ────────────────────────────────────────────────
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: activity.imagen.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: activity.imagen,
                            width: 70,
                            height: 70,
                            fit: BoxFit.cover)
                        : Container(
                            width: 70,
                            height: 70,
                            color: Colors.grey[200],
                            child: const Icon(Icons.image, color: Colors.grey)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(activity.nombre,
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: kPrimaryColor)),
                        const SizedBox(height: 4),
                        _TypeBadge(tipo: activity.tipo),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Fechas y cupos ──────────────────────────────────────────
              if (datesForDay.isNotEmpty) ...[
                _SheetSection(
                  icon: Icons.calendar_today,
                  title: selectedDay != null
                      ? 'Fechas del ${DateFormat("d MMM", "es").format(selectedDay!)}'
                      : 'Próximas fechas',
                  child: Column(
                    children: datesForDay
                        .map((cd) => _DateRow(cd: cd, divisa: divisa))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ── Reservas en tiempo real ─────────────────────────────────
              _SheetSection(
                icon: Icons.people_outline,
                title: 'Clientes reservados',
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('reservaciones')
                      .doc(supplierId)
                      .collection('reservas')
                      .where('planName', isEqualTo: activity.nombre)
                      .snapshots(),
                  builder: (ctx, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(8),
                        child: LinearProgressIndicator(color: kPrimaryColor),
                      );
                    }
                    final docs = snap.data?.docs ?? [];
                    final verificados = docs
                        .where(
                            (d) => (d.data() as Map)['estado'] == 'verificado')
                        .length;
                    final pendientes = docs.length - verificados;
                    double totalRecaudado = 0;
                    for (final d in docs) {
                      final m = d.data() as Map;
                      if (m['estado'] == 'verificado') {
                        totalRecaudado +=
                            (m['amountPaid'] as num?)?.toDouble() ?? 0.0;
                      }
                    }
                    return Column(
                      children: [
                        _StatRow(
                          label: 'Total reservas',
                          value: '${docs.length}',
                          icon: Icons.confirmation_number_outlined,
                        ),
                        _StatRow(
                          label: 'Verificados',
                          value: '$verificados',
                          icon: Icons.check_circle_outline,
                          color: Colors.green,
                        ),
                        _StatRow(
                          label: 'Pendientes',
                          value: '$pendientes',
                          icon: Icons.hourglass_empty,
                          color: Colors.orange,
                        ),
                        _StatRow(
                          label: 'Recaudado',
                          value: '$divisa${totalRecaudado.toStringAsFixed(2)}',
                          icon: Icons.attach_money,
                          color: Colors.blue[700],
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),

              // ── Acciones ────────────────────────────────────────────────
              _ActionButton(
                icon: Icons.payments_outlined,
                label: 'Verificar pagos',
                color: Colors.green,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SupplierVerifyPaymentsScreen(
                        supplierId: supplierId,
                        planName: activity.nombre,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              _ActionButton(
                icon: Icons.people_alt_outlined,
                label: 'Ver clientes / Manifiesto',
                color: kPrimaryColor,
                onTap: () {
                  Navigator.pop(context);
                  context.push('/supplier/manifest', extra: {
                    'tripId': activity.id,
                    'tripName': activity.nombre,
                    'date': selectedDay ?? DateTime.now(),
                  });
                },
              ),
              const SizedBox(height: 10),
              _ActionButton(
                icon: Icons.edit_outlined,
                label: 'Editar actividad',
                color: kPrimaryColor,
                outlined: true,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CreateEventScreen(
                        eventToEdit: activity.fullData,
                        eventId: activity.id,
                        supplierId: supplierId,
                      ),
                    ),
                  ).then((_) => onEdit());
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets auxiliares para el modal
// ─────────────────────────────────────────────────────────────────────────────
class _SheetSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _SheetSection(
      {required this.icon, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: kBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: kPrimaryColor, size: 16),
            const SizedBox(width: 6),
            Text(title,
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: kPrimaryColor)),
          ]),
          const Divider(height: 16),
          child,
        ],
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  final _CalendarDate cd;
  final String divisa;
  const _DateRow({required this.cd, required this.divisa});

  @override
  Widget build(BuildContext context) {
    final bool closed = cd.cupos == 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cd.pkgName,
                    style: GoogleFonts.poppins(
                        fontSize: 12, fontWeight: FontWeight.w600)),
                Text('${cd.hora}  ·  $divisa${cd.precio.toStringAsFixed(0)}',
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: Colors.grey[600])),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: closed
                    ? Colors.red.withValues(alpha: 0.1)
                    : Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8)),
            child: Text(
              closed ? 'CERRADO' : '${cd.cupos} cupos',
              style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: closed ? Colors.red : Colors.green[700]),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;
  const _StatRow(
      {required this.label,
      required this.value,
      required this.icon,
      this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color ?? Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
              child: Text(label,
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: Colors.grey[700]))),
          Text(value,
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: color ?? Colors.black87)),
        ],
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final String tipo;
  const _TypeBadge({required this.tipo});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (tipo) {
      case 'dated':
        color = Colors.blue;
        label = 'Con calendario';
        break;
      case 'fixed':
        color = Colors.purple;
        label = 'Cupos fijos';
        break;
      default:
        color = Colors.teal;
        label = 'Flexible';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Text(label,
          style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color.withValues(alpha: 0.8))),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool outlined;
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: outlined
          ? OutlinedButton.icon(
              onPressed: onTap,
              icon: Icon(icon, color: color),
              label: Text(label,
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold, color: color)),
              style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: color),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
            )
          : ElevatedButton.icon(
              onPressed: onTap,
              icon: Icon(icon, color: Colors.white),
              label: Text(label,
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
            ),
    );
  }
}
