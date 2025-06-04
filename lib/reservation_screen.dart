import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'payment_details_screen.dart';

class ReservationScreen extends StatefulWidget {
  final String userId;
  final List<Map<String, dynamic>> selectedPackages;
  final String planName;
  final String location;
  final String supplier;

  const ReservationScreen({
    super.key,
    required this.userId,
    required this.selectedPackages,
    required this.planName,
    required this.location,
    required this.supplier,
  });

  @override
  ReservationScreenState createState() => ReservationScreenState();
}

class PackageReservationData {
  Map<String, dynamic> package;
  DateTime? selectedDate;
  Map<String, dynamic>? selectedTimeInterval;
  int numberOfPeople;

  List<Map<String, dynamic>> availability;
  List<Map<String, dynamic>> timeIntervalsForSelectedDate;
  bool isExpanded;

  PackageReservationData({
    required this.package,
    this.selectedDate,
    this.selectedTimeInterval,
    this.numberOfPeople = 1,
    required this.availability,
    this.timeIntervalsForSelectedDate = const [],
    this.isExpanded = false,
  });
}

class ReservationScreenState extends State<ReservationScreen> {
  List<PackageReservationData> packagesData = [];
  String? selectedPaymentMethod;
  List<String> paymentMethods = [];
  final List<TextEditingController> _peopleControllers = [];

  @override
  void initState() {
    super.initState();
    _initializePackagesData();
    _loadPaymentMethods();
  }

  void _initializePackagesData() {
    packagesData = widget.selectedPackages.map((package) {
      final disp = package['disponibilidad'];
      return PackageReservationData(
        package: package,
        availability: disp is Map<String, dynamic>
            ? [disp]
            : List<Map<String, dynamic>>.from(disp ?? []),
        numberOfPeople: 1,
        isExpanded: false,
      );
    }).toList();

    _peopleControllers.addAll(List.generate(
        packagesData.length, (index) => TextEditingController(text: '1')));
  }

  Future<void> _loadPaymentMethods() async {
    try {
      DocumentSnapshot destinationSnapshot = await FirebaseFirestore.instance
          .collection('destinos')
          .doc(widget.planName)
          .get();

      if (destinationSnapshot.exists) {
        setState(() {
          paymentMethods = List<String>.from(
              destinationSnapshot['pagos'].map((payment) => payment['metodo']));
        });
      }
    } catch (e) {
      final context = this
          .context; // Guarda el contexto antes de llamar a la función asíncrona
      if (context.mounted) {
        // Verifica si el contexto sigue montado
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al cargar métodos de pago: $e',
              style: const TextStyle(fontFamily: 'Poppins'),
            ),
          ),
        );
      }
    }
  }

  void _pickDate(DateTime pickedDate, int packageIndex) {
    final package = packagesData[packageIndex];
    final formattedDate = DateFormat('yyyy-MM-dd').format(pickedDate);

    final availabilityForDate = package.availability.where((item) {
      return item['fecha'] == formattedDate &&
          (item['cupos'] ?? 0) >= package.numberOfPeople;
    }).toList();

    setState(() {
      package.selectedDate = pickedDate;
      package.timeIntervalsForSelectedDate = availabilityForDate;
      package.selectedTimeInterval = null;
    });
  }

  Future<void> _updateCupos() async {
    try {
      final docRef = FirebaseFirestore.instance
          .collection('destinos')
          .doc(widget.planName);

      final docSnapshot = await docRef.get();
      if (!docSnapshot.exists) return;

      final data = docSnapshot.data() as Map<String, dynamic>;
      final paquetes = List<Map<String, dynamic>>.from(
          data['paquetes']); // Lista de paquetes

      for (var packageData in packagesData) {
        final updatedPaquetes = paquetes.map((paquete) {
          if (paquete['numero'] == packageData.package['numero']) {
            // Convertir 'disponibilidad' a lista si es necesario
            final disponibilidad = paquete['disponibilidad'] is List
                ? List<Map<String, dynamic>>.from(paquete['disponibilidad'])
                : [
                    paquete['disponibilidad'] as Map<String, dynamic>
                  ]; // Si es un solo mapa, lo convierte en lista

            final updatedDisponibilidad = disponibilidad.map((disp) {
              if (disp['fecha'] ==
                      DateFormat('yyyy-MM-dd')
                          .format(packageData.selectedDate!) &&
                  disp['inicio'] ==
                      packageData.selectedTimeInterval!['inicio'] &&
                  disp['fin'] == packageData.selectedTimeInterval!['fin']) {
                return {
                  ...disp,
                  'cupos': disp['cupos'] - packageData.numberOfPeople
                };
              }
              return disp;
            }).toList();

            return {
              ...paquete,
              'disponibilidad': updatedDisponibilidad // Guardar como lista
            };
          }
          return paquete;
        }).toList();

        await docRef.update({'paquetes': updatedPaquetes});
      }
    } catch (e) {
      final context = this
          .context; // Guarda el contexto antes de llamar a la función asíncrona
      if (context.mounted) {
        // Verifica si el contexto sigue montado
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar cupos: $e')),
        );
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Error',
              style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Color.fromRGBO(17, 48, 73, 1),
                  fontWeight: FontWeight.bold)),
          content: Text(message,
              style: const TextStyle(
                  fontFamily: 'Poppins', color: Color.fromRGBO(17, 48, 73, 1))),
          actions: <Widget>[
            TextButton(
              child: const Text('OK',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.bold,
                      color: Color.fromRGBO(17, 48, 73, 1))),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  ExpansionPanel _buildPackageExpansionPanel(
      PackageReservationData packageData, int index) {
    return ExpansionPanel(
      backgroundColor: Colors.white,
      canTapOnHeader: true,
      headerBuilder: (context, isExpanded) {
        return SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  // Se adapta al espacio disponible
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            "Paquete ${packageData.package['numero']}",
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: const Color.fromRGBO(17, 48, 73, 1),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        "${packageData.package['miniDescripcion']}",
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: const Color.fromRGBO(17, 48, 73, 1),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        "Cantidad: ${packageData.numberOfPeople}",
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: const Color.fromRGBO(17, 48, 73, 1),
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Text(
                      "€${(packageData.package['precio'] * packageData.numberOfPeople).toStringAsFixed(2)}",
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color.fromRGBO(17, 48, 73, 1),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.calendar_today,
                      color: const Color.fromRGBO(17, 48, 73, 1),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            TableCalendar(
              locale: 'es_ES',
              firstDay: DateTime.now(),
              lastDay: DateTime.now().add(const Duration(days: 365)),
              focusedDay: packageData.selectedDate ?? DateTime.now(),
              selectedDayPredicate: (day) =>
                  isSameDay(packageData.selectedDate, day),
              onDaySelected: (selectedDay, focusedDay) =>
                  _pickDate(selectedDay, index),
              calendarBuilders: CalendarBuilders(
                defaultBuilder: (context, day, focusedDay) {
                  final isSelected = isSameDay(packageData.selectedDate, day);
                  final formattedDay = DateFormat('yyyy-MM-dd').format(day);

                  bool isAvailable = packageData.availability.any((item) =>
                      item['fecha'] == formattedDay &&
                      (item['cupos'] ?? 0) >= packageData.numberOfPeople);

                  if (isAvailable && !isSelected) {
                    // Día disponible: círculo verde y número blanco
                    return Center(
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${day.day}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                    );
                  }

                  // Día seleccionado: círculo principal
                  if (isSelected) {
                    return Center(
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: Color.fromRGBO(17, 48, 73, 1),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${day.day}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                    );
                  }

                  // Día normal
                  return Center(
                    child: Text(
                      '${day.day}',
                      style: const TextStyle(
                        color: Color.fromRGBO(17, 48, 73, 1),
                        fontWeight: FontWeight.normal,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  );
                },
                dowBuilder: (context, day) {
                  final text = DateFormat.E('es_ES').format(day);
                  return Center(
                    child: Text(
                      text,
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          color: Color.fromRGBO(17, 48, 73, 1)),
                    ),
                  );
                },
              ),
              calendarStyle: CalendarStyle(
                defaultTextStyle: GoogleFonts.poppins(),
                weekendTextStyle: GoogleFonts.poppins(),
                selectedTextStyle: GoogleFonts.poppins(color: Colors.white),
                todayTextStyle: GoogleFonts.poppins(
                  color: const Color.fromRGBO(17, 48, 73, 1),
                ),
                outsideTextStyle: GoogleFonts.poppins(color: Colors.grey),
                selectedDecoration: const BoxDecoration(
                  color: Color.fromRGBO(17, 48, 73, 1),
                  shape: BoxShape.circle,
                ),
              ),
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleTextStyle: GoogleFonts.poppins(
                    fontSize: 18, color: const Color.fromRGBO(17, 48, 73, 1)),
                titleTextFormatter: (date, locale) {
                  final formattedDate = DateFormat.yMMMM(locale).format(date);
                  return '${formattedDate[0].toUpperCase()}${formattedDate.substring(1)}';
                },
                leftChevronIcon: const Icon(Icons.chevron_left,
                    color: Color.fromRGBO(17, 48, 73, 1)),
                rightChevronIcon: const Icon(Icons.chevron_right,
                    color: Color.fromRGBO(17, 48, 73, 1)),
              ),
            ),
            if (packageData.selectedDate != null) ...[
              const SizedBox(height: 16),
              Text('Horarios disponibles:',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: const Color.fromRGBO(17, 48, 73, 1))),
              const SizedBox(height: 8),
              if (packageData.timeIntervalsForSelectedDate.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    'No hay cupos disponibles',
                    style: GoogleFonts.poppins(
                      color: const Color.fromRGBO(240, 169, 52, 1),
                      fontSize: 14,
                    ),
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  children:
                      packageData.timeIntervalsForSelectedDate.map((interval) {
                    return ChoiceChip(
                      label: Text(
                        '${interval['inicio']} - ${interval['fin']} (Cupos: ${interval['cupos']})',
                        style: GoogleFonts.poppins(
                          color: packageData.selectedTimeInterval == interval
                              ? Colors.white
                              : const Color.fromRGBO(17, 48, 73, 1),
                        ),
                      ),
                      side: const BorderSide(
                        color: Color.fromRGBO(17, 48, 73, 1),
                      ),
                      selected: packageData.selectedTimeInterval == interval,
                      onSelected: (selected) => setState(() {
                        packageData.selectedTimeInterval =
                            selected ? interval : null;
                      }),
                      selectedColor: const Color.fromRGBO(17, 48, 73, 1),
                      backgroundColor: Colors.white,
                      checkmarkColor: Colors.white,
                      labelStyle: const TextStyle(
                        fontFamily: 'Poppins',
                      ),
                    );
                  }).toList(),
                ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Cantidad:',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: const Color.fromRGBO(17, 48, 73, 1))),
                SizedBox(
                  width: 100,
                  child: TextFormField(
                    controller: _peopleControllers[index],
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (value) {
                      int newValue = int.tryParse(value) ?? 1;
                      if (newValue < 1) {
                        newValue = 1;
                        _peopleControllers[index].text = '1';
                      }
                      setState(() {
                        packageData.numberOfPeople = newValue;
                        if (packageData.selectedDate != null) {
                          _pickDate(packageData.selectedDate!, index);
                        }
                      });
                    },
                    decoration: InputDecoration(
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: Color.fromRGBO(17, 48, 73, 1),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(
                            color: Color.fromRGBO(17, 48, 73, 1)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      isExpanded: packageData.isExpanded,
    );
  }

  Widget _buildPaymentOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Método de Pago:',
            style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: const Color.fromRGBO(17, 48, 73, 1))),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: paymentMethods
                .map((method) => _buildPaymentOption(method))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentOption(String method) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: ChoiceChip(
        label: Text(
          method,
          style: GoogleFonts.poppins(
            // Color condicional para el texto
            color: selectedPaymentMethod == method
                ? Colors.white
                : const Color.fromRGBO(17, 48, 73, 1),
          ),
        ),
        side: const BorderSide(color: Color.fromRGBO(17, 48, 73, 1)),
        selected: selectedPaymentMethod == method,
        onSelected: (selected) => setState(() {
          selectedPaymentMethod = selected ? method : null;
        }),
        selectedColor: const Color.fromRGBO(17, 48, 73, 1),
        backgroundColor: Colors.white,
        checkmarkColor: Colors.white, // Check en blanco
        labelStyle: GoogleFonts.poppins().copyWith(
            // Estilo base sin color para evitar conflicto
            fontWeight: FontWeight.normal),
      ),
    );
  }

  Widget _buildReserveButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: ElevatedButton(
          onPressed: () => _validateReservation(),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color.fromRGBO(17, 48, 73, 1),
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
          ),
          child: Text(
            'Reservar por €${totalCost.toString()}',
            style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  double get totalCost {
    return packagesData.fold(0.0, (double sum, package) {
      return sum + (package.package['precio'] as num) * package.numberOfPeople;
    });
  }

  Future<void> _validateReservation() async {
    // Validación normal de paquetes y método de pago
    for (var package in packagesData) {
      if (package.selectedDate == null ||
          package.selectedTimeInterval == null ||
          package.numberOfPeople <= 0) {
        _showErrorDialog(
            'Todos los paquetes deben tener fecha, horario y cantidad válida');
        return;
      }
    }

    if (selectedPaymentMethod == null) {
      _showErrorDialog('Por favor seleccione un método de pago');
      return;
    }

    await _processReservation();
  }

  Future<void> _processReservation() async {
    final context = this
        .context; // Guarda el contexto antes de llamar a la función asíncrona
    try {
      await _updateCupos();
      if (context.mounted) {
        // Verifica si el contexto sigue montado
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentDetailsScreen(
              userId: widget.userId,
              paymentMethod: selectedPaymentMethod!,
              planName: widget.planName,
              planLocation: widget.location,
              totalPrice: totalCost, // Total calculado
              supplier: widget.supplier,
              packagesData: packagesData
                  .map((p) => {
                        // Lista de paquetes
                        'numero': p.package['numero'],
                        'fecha': p.selectedDate!,
                        'hora':
                            '${p.selectedTimeInterval!['inicio']} - ${p.selectedTimeInterval!['fin']}',
                        'personas': p.numberOfPeople,
                        'miniDescripcion': p.package['miniDescripcion'] ??
                            '', // <-- Manejo de null
                        // Agrega estos campos adicionales
                        'precio': p.package['precio'],
                      })
                  .toList(),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        // Verifica si el contexto sigue montado
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error en la reserva: $e',
              style: const TextStyle(fontFamily: 'Poppins'),
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    for (var controller in _peopleControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 243, 247, 254),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.planName,
                style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: const Color.fromRGBO(17, 48, 73, 1))),
            Text(widget.location,
                style: GoogleFonts.poppins(
                    color: const Color.fromRGBO(17, 48, 73, 1))),
            const SizedBox(height: 20),
            ExpansionPanelList(
              expansionCallback: (int panelIndex, bool isExpanded) {
                setState(() {
                  packagesData[panelIndex].isExpanded =
                      !packagesData[panelIndex]
                          .isExpanded; // Invierte el estado
                });
              },
              children: packagesData
                  .asMap()
                  .entries
                  .map((entry) =>
                      _buildPackageExpansionPanel(entry.value, entry.key))
                  .toList(),
            ),
            const SizedBox(height: 20),
            _buildPaymentOptions(),
            const SizedBox(height: 20),
            _buildReserveButton(),
          ],
        ),
      ),
      backgroundColor: const Color.fromARGB(255, 243, 247, 254),
    );
  }
}
