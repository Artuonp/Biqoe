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

  PackageReservationData({
    required this.package,
    this.selectedDate,
    this.selectedTimeInterval,
    this.numberOfPeople = 1,
    required this.availability,
    this.timeIntervalsForSelectedDate = const [],
  });
}

class ReservationScreenState extends State<ReservationScreen> {
  List<PackageReservationData> packagesData = [];
  String? selectedPaymentMethod;
  List<String> paymentMethods = [];
  final List<TextEditingController> _peopleControllers = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializePackagesData();
    _loadPaymentMethods();
  }

  void _initializePackagesData() {
    packagesData = widget.selectedPackages.map((package) {
      final disp = package['disponibilidad'];
      final bookingType = package['tipoDeReserva'] ?? 'Reserva';

      return PackageReservationData(
        package: package,
        availability: bookingType == 'Reserva'
            ? (disp is List
                ? List<Map<String, dynamic>>.from(disp)
                : (disp != null ? [disp] : []))
            : [],
        numberOfPeople: 1,
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
        var data = destinationSnapshot.data() as Map<String, dynamic>?;
        if (data != null && data.containsKey('pagos')) {
          if (mounted) {
            setState(() {
              paymentMethods = List<String>.from(
                  data['pagos'].map((payment) => payment['metodo']));
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar métodos de pago: $e')),
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

  // NUEVO: Lógica de descuento de cupos robusta y transaccional
  Future<void> _updateCupos() async {
    final docRef =
        FirebaseFirestore.instance.collection('destinos').doc(widget.planName);

    return FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) throw Exception("El destino ya no existe.");

      var paquetesRemotos =
          List<Map<String, dynamic>>.from(snapshot.data()!['paquetes']);

      for (var localPackageData in packagesData) {
        final tipo = localPackageData.package['tipoDeReserva'] ?? 'Reserva';
        final paqueteIndex = paquetesRemotos.indexWhere(
            (p) => p['numero'] == localPackageData.package['numero']);

        if (paqueteIndex == -1) {
          throw Exception(
              "El paquete ${localPackageData.package['numero']} ya no existe.");
        }

        var paqueteRemoto = paquetesRemotos[paqueteIndex];

        if (tipo == 'Reserva') {
          if (localPackageData.selectedDate == null ||
              localPackageData.selectedTimeInterval == null) {
            continue;
          }
          var disponibilidad =
              List<Map<String, dynamic>>.from(paqueteRemoto['disponibilidad']);
          final dispIndex = disponibilidad.indexWhere((d) =>
              d['fecha'] ==
                  DateFormat('yyyy-MM-dd')
                      .format(localPackageData.selectedDate!) &&
              d['inicio'] == localPackageData.selectedTimeInterval!['inicio'] &&
              d['fin'] == localPackageData.selectedTimeInterval!['fin']);

          if (dispIndex == -1) {
            throw Exception("El horario seleccionado ya no está disponible.");
          }
          if ((disponibilidad[dispIndex]['cupos'] as int) <
              localPackageData.numberOfPeople) {
            throw Exception(
                "No hay suficientes cupos para el Paquete ${localPackageData.package['numero']}.");
          }

          disponibilidad[dispIndex]['cupos'] -= localPackageData.numberOfPeople;
          paqueteRemoto['disponibilidad'] = disponibilidad;
        } else if (tipo == 'Ticket' || tipo == 'Suscripción') {
          if ((paqueteRemoto['cuposDisponibles'] as int) <
              localPackageData.numberOfPeople) {
            throw Exception(
                "No hay suficientes cupos para el Paquete ${localPackageData.package['numero']}.");
          }
          paqueteRemoto['cuposDisponibles'] -= localPackageData.numberOfPeople;
        }
        paquetesRemotos[paqueteIndex] = paqueteRemoto;
      }
      transaction.update(docRef, {'paquetes': paquetesRemotos});
    });
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

  // NUEVO: La validación ahora es transaccional y comprueba todos los tipos de cupos
  Future<void> _validateAndProcessReservation() async {
    setState(() => _isLoading = true);

    try {
      // Validación de datos locales primero
      if (selectedPaymentMethod == null) {
        throw Exception('Seleccione un método de pago.');
      }

      for (var packageData in packagesData) {
        if (packageData.numberOfPeople <= 0) {
          throw Exception(
              'La cantidad para cada paquete debe ser mayor a cero.');
        }
        if (packageData.package['tipoDeReserva'] == 'Reserva' &&
            (packageData.selectedDate == null ||
                packageData.selectedTimeInterval == null)) {
          throw Exception('Seleccione fecha y horario en el calendario.');
        }
      }

      // Validación de cupos contra Firestore
      await _updateCupos();

      // Si la transacción fue exitosa, procedemos a la pantalla de pago
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentDetailsScreen(
              userId: widget.userId,
              paymentMethod: selectedPaymentMethod!,
              planName: widget.planName,
              planLocation: widget.location,
              totalPrice: totalCost,
              supplier: widget.supplier,
              packagesData: packagesData.map((p) {
                final bookingType = p.package['tipoDeReserva'] ?? 'Reserva';
                Map<String, dynamic> packageDetails = {
                  'numero': p.package['numero'],
                  'miniDescripcion': p.package['miniDescripcion'] ?? '',
                  'personas': p.numberOfPeople,
                  'precio': p.package['precio'],
                  'tipoDeReserva': bookingType,
                };

                if (bookingType == 'Reserva') {
                  packageDetails.addAll({
                    'fecha': p.selectedDate!,
                    'hora':
                        '${p.selectedTimeInterval!['inicio']} - ${p.selectedTimeInterval!['fin']}',
                  });
                } else if (bookingType == 'Reserva Flexible') {
                  packageDetails
                      .addAll({'instrucciones': p.package['instrucciones']});
                }
                return packageDetails;
              }).toList(),
            ),
          ),
        );
      }
    } catch (e) {
      _showErrorDialog(e.toString().replaceFirst("Exception: ", ""));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 243, 247, 254),
        iconTheme: const IconThemeData(color: Color.fromRGBO(17, 48, 73, 1)),
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
            // MODIFICADO: Usamos ListView.builder para construir los widgets de paquete
            ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: packagesData.length,
              itemBuilder: (context, index) {
                return _buildPackageWidget(packagesData[index], index);
              },
              separatorBuilder: (context, index) => const SizedBox(height: 16),
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

  // NUEVO: Widget "director" que decide qué tipo de tarjeta de paquete mostrar
  Widget _buildPackageWidget(PackageReservationData packageData, int index) {
    final bookingType = packageData.package['tipoDeReserva'] ?? 'Reserva';
    if (bookingType == 'Reserva') {
      return _buildExpandableReservationCard(packageData, index);
    } else {
      return _buildInfoPackageCard(packageData, index);
    }
  }

  // NUEVO: Tarjeta estática para Tickets, Pases Flexibles y Suscripciones
  Widget _buildInfoPackageCard(PackageReservationData packageData, int index) {
    return Card(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildPackageHeader(packageData, index, false),
            const SizedBox(height: 8),
            _buildInfoUI(packageData),
            const SizedBox(height: 16),
            _buildQuantitySelector(packageData, index),
          ],
        ),
      ),
    );
  }

  // NUEVO: Tarjeta expandible solo para tipo "Reserva"
  Widget _buildExpandableReservationCard(
      PackageReservationData packageData, int index) {
    return Card(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: Theme(
        // Esto elimina las líneas divisorias de arriba y abajo
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          backgroundColor: Colors.white, // Asegura el fondo blanco al expandir
          title: _buildPackageHeader(packageData, index, true),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            _buildReservationUI(packageData, index),
            const SizedBox(height: 16),
            _buildQuantitySelector(packageData, index),
          ],
        ),
      ),
    );
  }

  // NUEVO: Header reutilizable para ambas tarjetas
  Widget _buildPackageHeader(
      PackageReservationData packageData, int index, bool isExpandable) {
    IconData headerIcon;
    final bookingType = packageData.package['tipoDeReserva'] ?? 'Reserva';
    switch (bookingType) {
      case 'Ticket':
        headerIcon = Icons.confirmation_number_outlined;
        break;
      case 'Reserva Flexible':
        headerIcon = Icons.all_inclusive_rounded;
        break;
      case 'Suscripción':
        headerIcon = Icons.autorenew_rounded;
        break;
      default:
        headerIcon =
            isExpandable ? Icons.calendar_today : Icons.event_available;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Paquete ${packageData.package['numero']}",
                  style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color.fromRGBO(17, 48, 73, 1))),
              Text("${packageData.package['miniDescripcion']}",
                  style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: const Color.fromRGBO(17, 48, 73, 1)),
                  overflow: TextOverflow.ellipsis),
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
                    color: const Color.fromRGBO(17, 48, 73, 1))),
            const SizedBox(width: 8),
            Icon(headerIcon, color: const Color.fromRGBO(17, 48, 73, 1)),
          ],
        ),
      ],
    );
  }

  // NUEVO: Selector de cantidad reutilizable
  Widget _buildQuantitySelector(PackageReservationData packageData, int index) {
    return Row(
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
                if (packageData.selectedDate != null &&
                    packageData.package['tipoDeReserva'] == 'Reserva') {
                  _pickDate(packageData.selectedDate!, index);
                }
              });
            },
            decoration: InputDecoration(
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: Color.fromRGBO(17, 48, 73, 1))),
              focusedBorder: OutlineInputBorder(
                  borderSide:
                      const BorderSide(color: Color.fromRGBO(17, 48, 73, 1)),
                  borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
        ),
      ],
    );
  }

  // --- El resto de los métodos se mantienen como estaban ---
  // ... _buildInfoBox, _buildInfoUI, _buildReservationUI, _buildPaymentOptions, etc. ...

  Widget _buildInfoBox({
    required String title,
    required String message,
    required IconData icon,
    required Color color,
    int? cuposDisponibles,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha((0.1 * 255).round()),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cambia el color del título
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: const Color.fromRGBO(17, 48, 73, 1),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Cambia el color y alineación del mensaje
                    Text(
                      message,
                      style: GoogleFonts.poppins(
                        color: const Color.fromRGBO(17, 48, 73, 1),
                      ),
                      textAlign: TextAlign.left,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (cuposDisponibles != null) ...[
            const Divider(height: 24, color: Colors.black26),
            Text(
              cuposDisponibles > 0
                  ? "Cupos disponibles: $cuposDisponibles"
                  : "¡Agotado!",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: const Color.fromRGBO(17, 48, 73, 1),
              ),
            )
          ]
        ],
      ),
    );
  }

  Widget _buildInfoUI(PackageReservationData packageData) {
    String bookingType = packageData.package['tipoDeReserva'] ?? 'Reserva';
    int? cupos = packageData.package['cuposDisponibles'] as int?;
    switch (bookingType) {
      case 'Ticket':
        return _buildInfoBox(
          title: "Detalles del Ticket",
          message:
              "Este ticket es válido únicamente para la(s) fecha(s) y condiciones establecidas en la descripción. Por favor, asegúrate de estar de acuerdo con los detalles antes de continuar, ya que no se permiten cambios de fecha ni horario.",
          icon: Icons.confirmation_number_outlined,
          color: Color.fromARGB(255, 133, 178, 255),
          cuposDisponibles: cupos,
        );
      case 'Reserva Flexible':
        return _buildInfoBox(
          title: "Reserva flexible",
          message:
              "Una vez confirmada tu reserva, el proveedor se pondrá en contacto contigo para coordinar el día y la hora de tu visita.",
          icon: Icons.all_inclusive_rounded,
          color: Color.fromARGB(255, 133, 178, 255),
        );
      case 'Suscripción':
        return _buildInfoBox(
          title: "Suscripción",
          message:
              "Tu suscripción comenzará el día en que se verifique tu pago y será válida durante el periodo detallado en la descripción.",
          icon: Icons.autorenew_rounded,
          color: Color.fromARGB(255, 133, 178, 255),
          cuposDisponibles: cupos,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildReservationUI(PackageReservationData packageData, int index) {
    const primaryColor = Color.fromRGBO(17, 48, 73, 1);

    return Column(
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

          // --- ESTILOS MODIFICADOS ---

          headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true, // Asegura que el título esté centrado
              titleTextStyle: GoogleFonts.poppins(
                // Fuente Poppins para el título
                fontSize: 18,
                color: primaryColor,
                fontWeight: FontWeight.bold,
              ),
              leftChevronIcon:
                  const Icon(Icons.chevron_left, color: primaryColor),
              rightChevronIcon:
                  const Icon(Icons.chevron_right, color: primaryColor),
              titleTextFormatter: (date, locale) {
                final formattedDate = DateFormat.yMMMM(locale).format(date);
                return '${formattedDate[0].toUpperCase()}${formattedDate.substring(1)}';
              }),

          daysOfWeekStyle: DaysOfWeekStyle(
            // Estilo para los días de la semana (Lun, Mar, etc.)
            weekdayStyle: GoogleFonts.poppins(
                color: primaryColor, fontWeight: FontWeight.w600),
            weekendStyle: GoogleFonts.poppins(
                color: primaryColor, fontWeight: FontWeight.w600),
          ),

          calendarStyle: CalendarStyle(
            // Estilo para los días que no son del mes actual
            outsideTextStyle: GoogleFonts.poppins(color: Colors.grey.shade400),

            // Estilo para los días por defecto del mes
            defaultTextStyle: GoogleFonts.poppins(color: primaryColor),

            // Estilo para los fines de semana
            weekendTextStyle: GoogleFonts.poppins(color: primaryColor),

            // Estilo para el día de hoy (que no está seleccionado)
            todayTextStyle: GoogleFonts.poppins(color: primaryColor),
            todayDecoration: BoxDecoration(
              color: primaryColor.withAlpha((0.2 * 255).round()),
              shape: BoxShape.circle,
            ),

            // Estilo para el día seleccionado
            selectedTextStyle: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.bold),
            selectedDecoration: const BoxDecoration(
              color: primaryColor,
              shape: BoxShape.circle,
            ),
          ),

          calendarBuilders: CalendarBuilders(
            defaultBuilder: (context, day, focusedDay) {
              final formattedDay = DateFormat('yyyy-MM-dd').format(day);
              bool isAvailable = packageData.availability.any((item) =>
                  item['fecha'] == formattedDay &&
                  (item['cupos'] ?? 0) >= packageData.numberOfPeople);

              // Si el día está disponible, lo pinta de verde
              if (isAvailable) {
                return Center(
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.green.withAlpha((0.8 * 255).round()),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${day.day}',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              }
              // Si no está disponible, usará los estilos definidos en calendarStyle
              return null;
            },
          ),
        ),
        if (packageData.selectedDate != null) ...[
          const SizedBox(height: 16),
          Text('Horarios disponibles:',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (packageData.timeIntervalsForSelectedDate.isEmpty)
            const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text('No hay cupos disponibles',
                    style: TextStyle(color: Colors.orange)))
          else
            Wrap(
              spacing: 8,
              children: packageData.timeIntervalsForSelectedDate
                  .map((interval) => ChoiceChip(
                        label: Text(
                            '${interval['inicio']} - ${interval['fin']} (Cupos: ${interval['cupos']})',
                            style: TextStyle(
                                color:
                                    packageData.selectedTimeInterval == interval
                                        ? Colors.white
                                        : primaryColor)),
                        side: BorderSide(color: primaryColor),
                        selected: packageData.selectedTimeInterval == interval,
                        onSelected: (selected) => setState(() => packageData
                            .selectedTimeInterval = selected ? interval : null),
                        selectedColor: primaryColor,
                        backgroundColor: Colors.white,
                        checkmarkColor: Colors.white,
                      ))
                  .toList(),
            ),
        ],
      ],
    );
  }

  double get totalCost {
    return packagesData.fold(0.0, (double sum, package) {
      return sum + (package.package['precio'] as num) * package.numberOfPeople;
    });
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
                  .toList()),
        ),
      ],
    );
  }

  Widget _buildPaymentOption(String method) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: ChoiceChip(
        label: Text(method,
            style: GoogleFonts.poppins(
                color: selectedPaymentMethod == method
                    ? Colors.white
                    : const Color.fromRGBO(17, 48, 73, 1))),
        side: const BorderSide(color: Color.fromRGBO(17, 48, 73, 1)),
        selected: selectedPaymentMethod == method,
        onSelected: (selected) =>
            setState(() => selectedPaymentMethod = selected ? method : null),
        selectedColor: const Color.fromRGBO(17, 48, 73, 1),
        backgroundColor: Colors.white,
        checkmarkColor: Colors.white,
        labelStyle:
            GoogleFonts.poppins().copyWith(fontWeight: FontWeight.normal),
      ),
    );
  }

  Widget _buildReserveButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: ElevatedButton(
          onPressed: _isLoading ? null : _validateAndProcessReservation,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color.fromRGBO(17, 48, 73, 1),
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text('Reservar por €${totalCost.toStringAsFixed(2)}',
                  style: GoogleFonts.poppins(
                      color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (var controller in _peopleControllers) {
      controller.dispose();
    }
    super.dispose();
  }
}
