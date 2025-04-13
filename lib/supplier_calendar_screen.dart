import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:collection';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class SupplierCalendarScreen extends StatefulWidget {
  const SupplierCalendarScreen({super.key});

  @override
  State<SupplierCalendarScreen> createState() => _SupplierCalendarScreenState();
}

class _SupplierCalendarScreenState extends State<SupplierCalendarScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late Stream<QuerySnapshot> _reservationsStream;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<Map<String, dynamic>>> _events = {};
  final Color textColor = const Color.fromRGBO(17, 48, 73, 1);
  final Color reservedDayColor = Colors.green;
  List<Map<String, dynamic>> _allReservations = [];
  final Set<String> _checkedReservations = HashSet<String>();
  final Color _backgroundColor = const Color.fromARGB(255, 243, 248, 255);

  @override
  void initState() {
    super.initState();
    _loadCheckedReservations();
    _setupStream();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  Future<void> _loadCheckedReservations() async {
    final prefs = await SharedPreferences.getInstance();
    final checked = prefs.getStringList('checked_reservations') ?? [];
    setState(() {
      _checkedReservations.addAll(checked);
    });
  }

  void _setupStream() {
    final user = _auth.currentUser;
    if (user == null) return;

    final proveedorDocRef =
        FirebaseFirestore.instance.collection('reservaciones').doc(user.uid);

    _reservationsStream = proveedorDocRef
        .collection('reservas')
        .where('estado', isEqualTo: 'verificado')
        .snapshots();

    _reservationsStream.listen((snapshot) {
      final events = <DateTime, List<Map<String, dynamic>>>{};
      _allReservations = [];

      for (final doc in snapshot.docs) {
        final reservaData = doc.data() as Map<String, dynamic>;
        _allReservations.add(reservaData);

        final packages = (reservaData['packages'] as List<dynamic>?) ?? [];
        for (final pkg in packages) {
          final package = pkg as Map<String, dynamic>;
          final fechaStr = package['fechaReserva']?.toString();
          if (fechaStr != null) {
            final fecha = _parseDate(fechaStr);
            if (fecha != null) {
              final day = DateTime(fecha.year, fecha.month, fecha.day);
              events[day] = [...events[day] ?? [], reservaData];
            }
          }
        }
      }
      setState(() => _events = events);
    });
  }

  DateTime? _parseDate(String fechaStr) {
    try {
      return DateTime.parse(fechaStr.trim());
    } catch (e) {
      return null;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleCheck(String code) async {
    setState(() {
      if (_checkedReservations.contains(code)) {
        _checkedReservations.remove(code);
      } else {
        _checkedReservations.add(code);
      }
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        'checked_reservations', _checkedReservations.toList());
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: Container(
        color: _backgroundColor, // Asegura que el fondo sea consistente
        height: double.infinity, // Ocupa toda la altura disponible
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: size.width * 0.04),
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildCalendar(),
                _buildSearchBar(),
                _buildReservationsList(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 60),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Buscar por código',
            hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400),
            prefixIcon:
                const Icon(Icons.search, color: Color.fromRGBO(17, 48, 73, 1)),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          style: GoogleFonts.poppins(fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildCalendar() {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.all(12),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: TableCalendar(
          locale: 'es_ES',
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _focusedDay,
          calendarFormat: _calendarFormat,
          eventLoader: (day) => _events[day] ?? [],
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });
          },
          onFormatChanged: (format) => setState(() => _calendarFormat = format),
          headerStyle: HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
            headerPadding: const EdgeInsets.symmetric(vertical: 8),
            leftChevronIcon: Icon(Icons.chevron_left, color: textColor),
            rightChevronIcon: Icon(Icons.chevron_right, color: textColor),
            titleTextFormatter: (date, locale) {
              // Formatea el título del encabezado
              final formattedDate =
                  '${DateFormat.MMMM(locale).format(date)} de ${date.year}';
              return formattedDate[0].toUpperCase() +
                  formattedDate.substring(1);
            },
            titleTextStyle: GoogleFonts.poppins(
              color: textColor,
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
          calendarStyle: CalendarStyle(
            todayDecoration: BoxDecoration(
              color: textColor.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            selectedDecoration: BoxDecoration(
              color: textColor,
              shape: BoxShape.circle,
            ),
            markersAutoAligned: true,
            markerDecoration: BoxDecoration(
              color: textColor,
              shape: BoxShape.circle,
            ),
            defaultTextStyle: GoogleFonts.poppins(color: textColor),
            weekendTextStyle: GoogleFonts.poppins(color: textColor),
            holidayTextStyle: GoogleFonts.poppins(color: textColor),
          ),
          daysOfWeekStyle: DaysOfWeekStyle(
            weekdayStyle:
                GoogleFonts.poppins(color: textColor.withOpacity(0.7)),
            weekendStyle:
                GoogleFonts.poppins(color: textColor.withOpacity(0.7)),
          ),
          calendarBuilders: CalendarBuilders(
            dowBuilder: (context, day) {
              return Center(
                child: Text(
                  _getDayAbbreviation(day.weekday),
                  style: GoogleFonts.poppins(color: textColor, fontSize: 14),
                ),
              );
            },
            defaultBuilder: (context, day, focusedDay) {
              final hasEvents =
                  _events.containsKey(DateTime(day.year, day.month, day.day));
              return Center(
                child: Text(
                  day.day.toString(),
                  style: GoogleFonts.poppins(
                    color: hasEvents ? reservedDayColor : textColor,
                    fontSize: 16,
                    fontWeight: hasEvents ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  String _getDayAbbreviation(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Lun';
      case DateTime.tuesday:
        return 'Mar';
      case DateTime.wednesday:
        return 'Mié';
      case DateTime.thursday:
        return 'Jue';
      case DateTime.friday:
        return 'Vie';
      case DateTime.saturday:
        return 'Sáb';
      case DateTime.sunday:
        return 'Dom';
      default:
        return '';
    }
  }

  Widget _buildReservationsList() {
    List<Map<String, dynamic>> displayedReservations = [];

    if (_searchQuery.isNotEmpty) {
      displayedReservations = _allReservations.where((reserva) {
        final code = reserva['code']?.toString().toLowerCase() ?? '';
        return code.contains(_searchQuery);
      }).toList();
    } else {
      final selectedDayNormalized = _selectedDay != null
          ? DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day)
          : null;
      displayedReservations = selectedDayNormalized != null
          ? _events[selectedDayNormalized] ?? []
          : [];
    }

    if (displayedReservations.isEmpty) {
      return Container(
        color: _backgroundColor, // Asegura que el fondo sea consistente
        padding: const EdgeInsets.only(bottom: 20),
        child: Center(
          child: Text(
            _searchQuery.isNotEmpty
                ? 'No se encontraron reservas'
                : 'No hay reservas para este día',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: const EdgeInsets.only(bottom: 20),
      itemCount: displayedReservations.length,
      itemBuilder: (context, index) =>
          _buildReservationCard(displayedReservations[index]),
    );
  }

  Widget _buildReservationCard(Map<String, dynamic> reserva) {
    final code = reserva['code'] ?? '';
    final isChecked = _checkedReservations.contains(code);
    final packages = reserva['packages'] as List<dynamic>? ?? [];

    // Extraer los nuevos campos
    final double totalPrice = reserva['totalPrice'] != null
        ? (reserva['totalPrice'] as num).toDouble()
        : 0.0;
    final double totalPriceBs = reserva['totalPriceBs'] != null
        ? (reserva['totalPriceBs'] as num).toDouble()
        : 0.0;
    final String name = reserva['name'] ?? 'N/A';
    final String email = reserva['email'] ?? 'N/A';
    final String celular = reserva['celular'] ?? 'N/A';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Card(
        color: Colors.white,
        elevation: isChecked ? 1 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isChecked ? Colors.green : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.event_available, color: textColor, size: 20),
                      const SizedBox(width: 8),
                      Text(reserva['planName'] ?? 'Reserva',
                          style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: textColor)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow('Código:', code.isEmpty ? 'N/A' : code),
                  const SizedBox(height: 8),
                  ..._buildPackageDetails(packages),
                  // Se agregan los nuevos detalles
                  _buildDetailRow('Nombre:', name),
                  _buildDetailRow('Email:', email),
                  _buildDetailRow('Celular:', celular),
                  _buildDetailRow(
                      'Precio en \$:', '\$${totalPrice.toStringAsFixed(2)}'),
                  _buildDetailRow(
                      'Precio en Bs:', 'Bs ${totalPriceBs.toStringAsFixed(2)}'),
                ],
              ),
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  icon: Icon(
                    isChecked
                        ? Icons.check_circle
                        : Icons.check_circle_outlined,
                    color:
                        isChecked ? Colors.green : textColor.withOpacity(0.5),
                    size: 28,
                  ),
                  onPressed: () => _toggleCheck(code),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildPackageDetails(List<dynamic> packages) {
    return packages.map<Widget>((pkg) {
      final package = pkg as Map<String, dynamic>;
      final numero = package['numero']?.toString() ?? 'N/A';
      final miniDesc = package['miniDescripcion']?.toString() ?? '';
      final personas = package['personas']?.toString() ?? '0';
      final fechaStr = package['fechaReserva']?.toString();
      final hora = package['horaReserva']?.toString() ?? 'Sin hora';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (packages.indexOf(pkg) != 0)
            const Divider(height: 30, color: Colors.grey),
          _buildDetailRow('Paquete:', '$numero ($miniDesc)'.trim()),
          _buildDetailRow('Cantidad:', personas),
          _buildDetailRow('Fecha:',
              fechaStr != null ? _formatDisplayDate(fechaStr) : 'N/A'),
          _buildDetailRow('Hora:', hora),
        ],
      );
    }).toList();
  }

  String _formatDisplayDate(String fechaStr) {
    try {
      final fecha = DateTime.parse(fechaStr);
      return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
    } catch (_) {
      return fechaStr;
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.poppins(
                  color: textColor, fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value,
                style: GoogleFonts.poppins(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w400)),
          ),
        ],
      ),
    );
  }
}
