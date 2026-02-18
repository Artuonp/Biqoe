import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

// Importamos la pantalla de creación para editar
import 'create_event/create_event_screen.dart';
// Importamos la nueva pantalla de verificación
import 'supplier_verify_payments_screen.dart';

const Color kPrimaryColor = Color.fromRGBO(17, 48, 73, 1);

class SupplierCalendarScreen extends StatefulWidget {
  final String
      userId; // Este userId ya trae el ID correcto (Jefe) desde el Dashboard

  const SupplierCalendarScreen({super.key, required this.userId});

  @override
  State<SupplierCalendarScreen> createState() => _SupplierCalendarScreenState();
}

class _SupplierCalendarScreenState extends State<SupplierCalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _isLoading = true;

  // Mapa de Eventos: Map<DateTime, List<Map>>
  Map<DateTime, List<Map<String, dynamic>>> _events = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadRealEvents();
  }

  // --- 1. CARGA DE DATOS REALES ---
  Future<void> _loadRealEvents() async {
    setState(() => _isLoading = true);
    Map<DateTime, List<Map<String, dynamic>>> newEvents = {};

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('destinos')
          .where('supplierId', isEqualTo: widget.userId)
          .get();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final paquetes = data['paquetes'] as List<dynamic>? ?? [];
        final String docId = doc.id;
        final String nombreBase = data['nombre'] ?? 'Actividad';
        final String imagen = (data['imagenes'] as List?)?.first ?? '';

        // Iteramos sobre los paquetes
        for (int i = 0; i < paquetes.length; i++) {
          final pkg = paquetes[i];
          final disponibilidad = pkg['disponibilidad'] as List<dynamic>? ?? [];
          final String pkgName = pkg['miniDescripcion'] ?? 'Estándar';

          // Iteramos sobre las fechas disponibles
          for (int j = 0; j < disponibilidad.length; j++) {
            final disp = disponibilidad[j];

            // Detectar formato de fecha
            DateTime? date;
            if (disp['fecha'] != null) {
              date = DateTime.parse(disp['fecha']);
            } else if (disp['fechaInicio'] != null) {
              date = DateTime.parse(disp['fechaInicio']);
            }

            if (date != null) {
              final dateKey = DateTime.utc(date.year, date.month, date.day);

              final eventData = {
                'id': docId,
                'pkgIndex': i,
                'dateIndex': j,
                'title': nombreBase,
                'subtitle': pkgName,
                'image': imagen,
                'time': disp['hora'] ?? disp['horaInicio'] ?? 'Todo el día',
                'spots': disp['cupos'] ?? 0,
                'price': pkg['precio'],
                'isBlocked': (disp['cupos'] ?? 0) == 0,
                'fullData': data, // Guardamos toda la data para poder editar
              };

              if (newEvents[dateKey] == null) {
                newEvents[dateKey] = [];
              }
              newEvents[dateKey]!.add(eventData);
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _events = newEvents;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error cargando calendario: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    final normalizedDate = DateTime.utc(day.year, day.month, day.day);
    return _events[normalizedDate] ?? [];
  }

  // --- 2. LÓGICA DE BLOQUEO / DESBLOQUEO ---
  Future<void> _updateSpots(Map<String, dynamic> event, int newSpots) async {
    try {
      final docRef =
          FirebaseFirestore.instance.collection('destinos').doc(event['id']);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) return;

        final data = snapshot.data()!;
        final List<dynamic> paquetes = List.from(data['paquetes']);

        int pIndex = event['pkgIndex'];
        int dIndex = event['dateIndex'];

        if (pIndex < paquetes.length) {
          Map<String, dynamic> targetPkg = Map.from(paquetes[pIndex]);
          List<dynamic> disponibilidades =
              List.from(targetPkg['disponibilidad']);

          if (dIndex < disponibilidades.length) {
            Map<String, dynamic> targetDate =
                Map.from(disponibilidades[dIndex]);

            // ACTUALIZAR CUPOS
            targetDate['cupos'] = newSpots;

            disponibilidades[dIndex] = targetDate;
            targetPkg['disponibilidad'] = disponibilidades;
            paquetes[pIndex] = targetPkg;

            transaction.update(docRef, {'paquetes': paquetes});
          }
        }
      });

      await _loadRealEvents();
      if (mounted) {
        String msg = newSpots == 0
            ? "Actividad bloqueada"
            : "Cupos habilitados: $newSpots";
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      debugPrint("Error actualizando cupos: $e");
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  void _showInventoryDialog(BuildContext context, Map<String, dynamic> event) {
    bool isBlocked = event['isBlocked'];
    final spotsController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isBlocked ? "Habilitar cupos" : "Bloquear disponibilidad",
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: kPrimaryColor)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                isBlocked
                    ? "Esta fecha está cerrada. Ingresa la cantidad de cupos para abrirla nuevamente."
                    : "¿Deseas cerrar esta fecha? Los cupos pasarán a 0 y nadie podrá reservar.",
                style:
                    GoogleFonts.poppins(fontSize: 13, color: Colors.grey[700])),
            if (isBlocked) ...[
              const SizedBox(height: 20),
              TextField(
                controller: spotsController,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: "Nuevos cupos",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.people_alt_outlined),
                ),
              ),
            ]
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  const Text("Cancelar", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isBlocked ? Colors.green : Colors.red,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              if (isBlocked) {
                int spots = int.tryParse(spotsController.text) ?? 0;
                if (spots > 0) {
                  Navigator.pop(context);
                  _updateSpots(event, spots);
                }
              } else {
                Navigator.pop(context);
                _updateSpots(event, 0);
              }
            },
            child: Text(isBlocked ? "Habilitar" : "Bloquear",
                style: GoogleFonts.poppins(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  // --- 3. MODAL DE DETALLES ---
  void _showActivityDetailModal(
      BuildContext context, Map<String, dynamic> event) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: event['image'] != ''
                        ? CachedNetworkImage(
                            imageUrl: event['image'],
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover)
                        : Container(
                            width: 80,
                            height: 80,
                            color: Colors.grey[200],
                            child: const Icon(Icons.image, color: Colors.grey)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(event['title'],
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: kPrimaryColor)),
                        Text(event['subtitle'],
                            style: GoogleFonts.poppins(
                                color: Colors.grey[600], fontSize: 14)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(4)),
                          child: Text(event['time'],
                              style: GoogleFonts.poppins(
                                  fontSize: 12, color: Colors.blue[800])),
                        )
                      ],
                    ),
                  )
                ],
              ),
              const SizedBox(height: 25),

              // 1. VERIFICAR PAGOS
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context); // Cierra el modal
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SupplierVerifyPaymentsScreen(
                          supplierId: widget.userId,
                          planName: event['title'],
                        ),
                      ),
                    );
                  },
                  icon:
                      const Icon(Icons.payments_outlined, color: Colors.white),
                  label: Text("Verificar Pagos",
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                ),
              ),
              const SizedBox(height: 12),

              // 2. VER PASAJEROS
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push('/supplier/manifest', extra: {
                      'tripId': event['id'],
                      'tripName': event['title'],
                      'date': _selectedDay
                    });
                  },
                  icon: const Icon(Icons.people_alt_outlined,
                      color: Colors.white),
                  label: Text("Ver clientes",
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                ),
              ),
              const SizedBox(height: 12),

              // 3. EDITAR ACTIVIDAD (CORREGIDO)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CreateEventScreen(
                          eventToEdit: event['fullData'],
                          eventId: event['id'],
                          supplierId: widget
                              .userId, // <--- CORREGIDO AQUÍ: Pasamos el ID del jefe
                        ),
                      ),
                    ).then((_) => _loadRealEvents());
                  },
                  icon: const Icon(Icons.edit_outlined, color: kPrimaryColor),
                  label: Text("Editar actividad",
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold, color: kPrimaryColor)),
                  style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      side: const BorderSide(color: kPrimaryColor),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  // --- MÉTODO BUILD ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 243, 247, 254),
      body: SafeArea(
        child: Column(
          children: [
            // --- CALENDARIO ---
            Container(
              margin: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withAlpha((0.05 * 255).round()),
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
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                eventLoader: _getEventsForDay,
                calendarStyle: CalendarStyle(
                  todayDecoration: BoxDecoration(
                      color: kPrimaryColor.withAlpha((0.5 * 255).round()),
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
                    final formatted =
                        DateFormat('MMMM yyyy', locale).format(date);
                    if (formatted.isEmpty) return formatted;
                    return formatted[0].toUpperCase() + formatted.substring(1);
                  },
                ),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
              ),
            ),

            const SizedBox(height: 10),

            // --- LISTA DE ACTIVIDADES ---
            Expanded(
              child: _isLoading
                  ? const Center()
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Actividades del ${DateFormat('d MMM', 'es').format(_selectedDay!)}',
                            style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: kPrimaryColor),
                          ),
                          const SizedBox(height: 15),
                          Expanded(
                            child: _getEventsForDay(_selectedDay!).isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.event_available,
                                            color: Colors.grey
                                                .withAlpha((0.3 * 255).round()),
                                            size: 50),
                                        const SizedBox(height: 10),
                                        Text("Sin actividades programadas",
                                            style: GoogleFonts.poppins(
                                                color: Colors.grey)),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.only(bottom: 20),
                                    itemCount:
                                        _getEventsForDay(_selectedDay!).length,
                                    itemBuilder: (context, index) {
                                      final event = _getEventsForDay(
                                          _selectedDay!)[index];
                                      return _buildActivityCard(event);
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildActivityCard(Map<String, dynamic> event) {
    bool isBlocked = event['isBlocked'];

    return GestureDetector(
      onTap: () => _showActivityDetailModal(context, event),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: isBlocked ? Colors.red.shade100 : Colors.transparent),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withAlpha((0.04 * 255).round()),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ]),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: event['image'] != ''
                  ? CachedNetworkImage(
                      imageUrl: event['image'],
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover)
                  : Container(
                      width: 60,
                      height: 60,
                      color: Colors.grey[100],
                      child: const Icon(Icons.image,
                          size: 20, color: Colors.grey)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event['title'],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  Text("${event['subtitle']} • ${event['time']}",
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: Colors.grey[600])),
                  const SizedBox(height: 4),
                  if (isBlocked)
                    Text("CERRADO",
                        style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.red))
                  else
                    Text("${event['spots']} cupos disp.",
                        style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.green[700],
                            fontWeight: FontWeight.w500))
                ],
              ),
            ),
            IconButton(
              icon: Icon(isBlocked ? Icons.lock : Icons.lock_open,
                  color: isBlocked ? Colors.red : Colors.grey[400], size: 20),
              onPressed: () => _showInventoryDialog(context, event),
            )
          ],
        ),
      ),
    );
  }
}
