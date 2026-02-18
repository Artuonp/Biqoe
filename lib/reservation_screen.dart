import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'payment_details_screen.dart';

const Color kPrimaryColor = Color.fromRGBO(17, 48, 73, 1);
const Color kBackgroundColor = Color(0xFFF8F9FD);

// --- NOTA: He borrado la extensión 'StringExtension' de aquí porque
// ya existe en 'payment_details_screen.dart' y se importa automáticamente. ---

class ReservationScreen extends StatefulWidget {
  final String userId;
  final List<Map<String, dynamic>> selectedPackages;
  final String planName;
  final String location;
  final String supplier;
  final String destinationId;

  const ReservationScreen({
    super.key,
    required this.userId,
    required this.selectedPackages,
    required this.planName,
    required this.location,
    required this.supplier,
    required this.destinationId,
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
  bool _isLoading = false;

  String? _realDocId;

  @override
  void initState() {
    super.initState();
    _initializePackagesData();
    _resolveIdAndLoadData();
  }

  void _initializePackagesData() {
    packagesData = widget.selectedPackages.map((package) {
      final disp = package['disponibilidad'];
      String rawType = package['tipo'] ?? package['tipoDeReserva'] ?? 'Reserva';
      String bookingType = 'Reserva';

      if (rawType == 'fixed' || rawType == 'Ticket') {
        bookingType = 'Ticket';
      } else if (rawType == 'flexible' || rawType == 'Reserva Flexible') {
        bookingType = 'Reserva Flexible';
      } else if (rawType == 'dated' || rawType == 'Reserva') {
        bookingType = 'Reserva';
      } else if (rawType == 'Suscripción') {
        bookingType = 'Suscripción';
      }

      package['internal_type'] = bookingType;

      return PackageReservationData(
        package: package,
        availability: bookingType == 'Reserva'
            ? (disp is List ? List<Map<String, dynamic>>.from(disp) : [])
            : [],
        numberOfPeople: 1,
      );
    }).toList();
  }

  Future<void> _resolveIdAndLoadData() async {
    try {
      DocumentSnapshot? doc;

      // 1. Intentar usar el ID que nos pasaron directamente
      if (widget.destinationId.isNotEmpty) {
        doc = await FirebaseFirestore.instance
            .collection('destinos')
            .doc(widget.destinationId)
            .get();
      }

      // 2. Si no existe ese ID, buscamos por nombre
      if (doc == null || !doc.exists) {
        final query = await FirebaseFirestore.instance
            .collection('destinos')
            .where('nombre', isEqualTo: widget.planName)
            .limit(1)
            .get();

        if (query.docs.isNotEmpty) {
          doc = query.docs.first;
        }
      }

      // 3. Si encontramos el documento, guardamos el ID real y cargamos pagos
      if (doc != null && doc.exists) {
        _realDocId = doc.id;
        final data = doc.data() as Map<String, dynamic>;

        List<dynamic> rawPagos = [];
        if (data.containsKey('metodosPago')) {
          rawPagos = data['metodosPago'];
        } else if (data.containsKey('pagos')) {
          rawPagos = data['pagos'];
        }

        if (mounted) {
          setState(() {
            paymentMethods = [];
            for (var item in rawPagos) {
              if (item is Map && item['metodo'] != null) {
                paymentMethods.add(item['metodo'].toString());
              }
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Error resolviendo ID: $e");
    }
  }

  void _pickDate(DateTime pickedDate, int packageIndex) {
    final package = packagesData[packageIndex];
    final formattedDate = DateFormat('yyyy-MM-dd').format(pickedDate);

    final availabilityForDate = package.availability.where((item) {
      bool matchesDate = false;
      if (item.containsKey('fecha')) {
        matchesDate = item['fecha'] == formattedDate;
      }
      if (item.containsKey('fechaInicio')) {
        matchesDate = item['fechaInicio'] == formattedDate;
      }
      return matchesDate && (item['cupos'] ?? 0) >= package.numberOfPeople;
    }).map((item) {
      String inicio =
          item['hora'] ?? item['horaInicio'] ?? item['inicio'] ?? "";
      String fin = item['horaFin'] ?? item['fin'] ?? "";
      return {...item, 'inicio': inicio, 'fin': fin, 'cupos': item['cupos']};
    }).toList();

    setState(() {
      package.selectedDate = pickedDate;
      package.timeIntervalsForSelectedDate = availabilityForDate;
      package.selectedTimeInterval = null;
    });
  }

  Future<void> _updateCupos() async {
    if (_realDocId == null) {
      throw Exception(
          "No se ha podido identificar el destino en la base de datos.");
    }

    final docRef =
        FirebaseFirestore.instance.collection('destinos').doc(_realDocId);

    return FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) throw Exception("El destino ya no existe.");

      var data = snapshot.data()!;
      var paquetesRemotos = List<Map<String, dynamic>>.from(data['paquetes']);

      for (var localPackageData in packagesData) {
        final paqueteIndex = paquetesRemotos.indexWhere((p) =>
            (p['miniDescripcion'] ==
                localPackageData.package['miniDescripcion']) ||
            (p['nombre'] == localPackageData.package['nombre']));

        if (paqueteIndex == -1) continue;

        var paqueteRemoto = paquetesRemotos[paqueteIndex];
        String tipo = localPackageData.package['internal_type'];

        if (tipo == 'Reserva') {
          if (localPackageData.selectedDate == null ||
              localPackageData.selectedTimeInterval == null) {
            continue;
          }

          var disponibilidad =
              List<Map<String, dynamic>>.from(paqueteRemoto['disponibilidad']);
          final dateStr =
              DateFormat('yyyy-MM-dd').format(localPackageData.selectedDate!);

          final dispIndex = disponibilidad.indexWhere((d) {
            bool matchDate =
                (d['fecha'] == dateStr) || (d['fechaInicio'] == dateStr);
            String dInicio = d['hora'] ?? d['horaInicio'] ?? d['inicio'];
            return matchDate &&
                dInicio == localPackageData.selectedTimeInterval!['inicio'];
          });

          if (dispIndex != -1) {
            if ((disponibilidad[dispIndex]['cupos'] as int) <
                localPackageData.numberOfPeople) {
              throw Exception("No hay suficientes cupos.");
            }
            disponibilidad[dispIndex]['cupos'] -=
                localPackageData.numberOfPeople;
            paqueteRemoto['disponibilidad'] = disponibilidad;
          }
        } else if (tipo == 'Ticket' || tipo == 'Suscripción') {
          if (paqueteRemoto['cuposDisponibles'] != null) {
            if ((paqueteRemoto['cuposDisponibles'] as int) <
                localPackageData.numberOfPeople) {
              throw Exception("No hay suficientes cupos.");
            }
            paqueteRemoto['cuposDisponibles'] -=
                localPackageData.numberOfPeople;
          }
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Atención',
              style: GoogleFonts.poppins(
                  color: kPrimaryColor, fontWeight: FontWeight.bold)),
          content:
              Text(message, style: GoogleFonts.poppins(color: Colors.black87)),
          actions: <Widget>[
            TextButton(
              child: Text('Entendido',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold, color: kPrimaryColor)),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  Future<void> _validateAndProcessReservation() async {
    setState(() => _isLoading = true);
    try {
      if (selectedPaymentMethod == null) {
        throw Exception('Seleccione un método de pago.');
      }

      for (var packageData in packagesData) {
        if (packageData.package['internal_type'] == 'Reserva' &&
            (packageData.selectedDate == null ||
                packageData.selectedTimeInterval == null)) {
          throw Exception(
              'Seleccione fecha y horario para todos los paquetes de reserva.');
        }
      }

      await _updateCupos();

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
              // Pasamos el ID real encontrado para evitar problemas en la siguiente pantalla
              destinationId: _realDocId ?? widget.destinationId,
              packagesData: packagesData.map((p) {
                Map<String, dynamic> packageDetails = {
                  'numero': p.package['numero'] ?? 1,
                  'miniDescripcion':
                      p.package['miniDescripcion'] ?? p.package['nombre'] ?? '',
                  'personas': p.numberOfPeople,
                  'precio': p.package['precio'],
                  'tipoDeReserva': p.package['internal_type'],
                };

                if (p.package['internal_type'] == 'Reserva') {
                  packageDetails.addAll({
                    'fecha': p.selectedDate!,
                    'hora': p.selectedTimeInterval!['fin'].toString().isEmpty
                        ? p.selectedTimeInterval!['inicio']
                        : '${p.selectedTimeInterval!['inicio']} - ${p.selectedTimeInterval!['fin']}',
                  });
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double get totalCost {
    return packagesData.fold(0.0, (total, package) {
      return total +
          (package.package['precio'] as num) * package.numberOfPeople;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            bottom: 100,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.planName,
                      style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: kPrimaryColor)),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined,
                          size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Expanded(
                          child: Text(widget.location,
                              style: GoogleFonts.poppins(
                                  color: Colors.grey[600], fontSize: 14),
                              overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                  const SizedBox(height: 25),
                  ListView.separated(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemCount: packagesData.length,
                    itemBuilder: (context, index) =>
                        _buildPackageWidget(packagesData[index], index),
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 5),
                  ),
                  const SizedBox(height: 1),
                  const Divider(),
                  const SizedBox(height: 10),
                  Text('Método de pago',
                      style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: kPrimaryColor)),
                  const SizedBox(height: 15),
                  if (paymentMethods.isEmpty)
                    Text("Cargando o sin métodos de pago...",
                        style: GoogleFonts.poppins(color: Colors.grey))
                  else
                    _buildPaymentOptions(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 20,
                      offset: const Offset(0, -5))
                ],
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text("Total a pagar",
                              style: GoogleFonts.poppins(
                                  fontSize: 12, color: Colors.grey)),
                          Text("€${totalCost.toStringAsFixed(2)}",
                              style: GoogleFonts.poppins(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: kPrimaryColor)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    ElevatedButton(
                      onPressed:
                          _isLoading ? null : _validateAndProcessReservation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _isLoading ? Colors.grey.shade300 : kPrimaryColor,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 30, vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 5,
                      ),
                      child: Container(
                        alignment: Alignment.center,
                        child: Text("Reservar",
                            style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _isLoading
                                    ? Colors.transparent
                                    : Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackageWidget(PackageReservationData packageData, int index) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kPrimaryColor.withValues(alpha: 0.03),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade200)),
                  child: Text("${index + 1}",
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold, color: kPrimaryColor)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          packageData.package['miniDescripcion'] ??
                              packageData.package['nombre'] ??
                              'Paquete',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      Text("€${packageData.package['precio']} x persona",
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                ),
                _buildModernQuantitySelector(packageData, index),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoUI(packageData),
                if (packageData.package['internal_type'] == 'Reserva') ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  _buildReservationUI(packageData, index),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernQuantitySelector(
      PackageReservationData packageData, int index) {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _quantityBtn(Icons.remove, () {
            if (packageData.numberOfPeople > 1) {
              setState(() {
                packageData.numberOfPeople--;
                if (packageData.package['internal_type'] == 'Reserva' &&
                    packageData.selectedDate != null) {
                  _pickDate(packageData.selectedDate!, index);
                }
              });
            }
          }),
          Container(
              width: 30,
              alignment: Alignment.center,
              child: Text("${packageData.numberOfPeople}",
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
          _quantityBtn(Icons.add, () {
            setState(() {
              packageData.numberOfPeople++;
              if (packageData.package['internal_type'] == 'Reserva' &&
                  packageData.selectedDate != null) {
                _pickDate(packageData.selectedDate!, index);
              }
            });
          }),
        ],
      ),
    );
  }

  Widget _quantityBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
        onTap: onTap,
        child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Icon(icon, size: 16, color: kPrimaryColor)));
  }

  Widget _buildInfoUI(PackageReservationData packageData) {
    String bookingType = packageData.package['internal_type'];
    int? cupos = packageData.package['cuposDisponibles'] as int?;
    switch (bookingType) {
      case 'Ticket':
        return _buildInfoBox(
            title: "Ticket fijo",
            message: "Válido para la fecha del evento.",
            icon: Icons.confirmation_number_outlined,
            color: Colors.blue,
            cuposDisponibles: cupos);
      case 'Reserva Flexible':
        return _buildInfoBox(
            title: "Fecha flexible",
            message: "Coordina luego de la compra.",
            icon: Icons.all_inclusive_rounded,
            color: Colors.purple);
      case 'Suscripción':
        return _buildInfoBox(
            title: "Suscripción",
            message: "Acceso recurrente.",
            icon: Icons.autorenew_rounded,
            color: Colors.orange,
            cuposDisponibles: cupos);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildInfoBox(
      {required String title,
      required String message,
      required IconData icon,
      required Color color,
      int? cuposDisponibles}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Row(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.black87)),
          Text(message,
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.black54)),
          if (cuposDisponibles != null)
            Text("Cupos: $cuposDisponibles",
                style: GoogleFonts.poppins(
                    fontSize: 12, fontWeight: FontWeight.bold, color: color))
        ]))
      ]),
    );
  }

  Widget _buildReservationUI(PackageReservationData packageData, int index) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Selecciona una fecha",
            style:
                GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(12)),
          child: TableCalendar(
            locale: 'es_ES',
            firstDay: DateTime.now(),
            lastDay: DateTime.now().add(const Duration(days: 365)),
            focusedDay: packageData.selectedDate ?? DateTime.now(),
            selectedDayPredicate: (day) =>
                isSameDay(packageData.selectedDate, day),
            onDaySelected: (selectedDay, focusedDay) =>
                _pickDate(selectedDay, index),
            headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: kPrimaryColor),
                leftChevronIcon: const Icon(Icons.chevron_left,
                    color: kPrimaryColor, size: 20),
                rightChevronIcon: const Icon(Icons.chevron_right,
                    color: kPrimaryColor, size: 20),
                titleTextFormatter: (date, locale) =>
                    DateFormat.yMMMM(locale).format(date).capitalize()),
            calendarStyle: CalendarStyle(
                outsideTextStyle: const TextStyle(color: Colors.grey),
                defaultTextStyle: GoogleFonts.poppins(color: Colors.black87),
                weekendTextStyle: GoogleFonts.poppins(color: Colors.black87),
                todayDecoration: BoxDecoration(
                    color: kPrimaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle),
                todayTextStyle: const TextStyle(color: kPrimaryColor),
                selectedDecoration: const BoxDecoration(
                    color: kPrimaryColor, shape: BoxShape.circle)),
            calendarBuilders:
                CalendarBuilders(defaultBuilder: (context, day, focusedDay) {
              final formattedDay = DateFormat('yyyy-MM-dd').format(day);
              bool isAvailable = packageData.availability.any((item) {
                bool matchesDate = false;
                if (item.containsKey('fecha')) {
                  matchesDate = item['fecha'] == formattedDay;
                }
                if (item.containsKey('fechaInicio')) {
                  matchesDate = item['fechaInicio'] == formattedDay;
                }
                return matchesDate &&
                    (item['cupos'] ?? 0) >= packageData.numberOfPeople;
              });
              if (isAvailable) {
                return Center(
                    child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            shape: BoxShape.circle),
                        alignment: Alignment.center,
                        child: Text('${day.day}',
                            style: GoogleFonts.poppins(
                                color: Colors.green[700],
                                fontWeight: FontWeight.bold))));
              }
              return null;
            }),
          ),
        ),
        if (packageData.selectedDate != null) ...[
          const SizedBox(height: 16),
          Text('Horarios disponibles:',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          if (packageData.timeIntervalsForSelectedDate.isEmpty)
            Text('No hay cupos suficientes.',
                style: GoogleFonts.poppins(color: Colors.red, fontSize: 12))
          else
            Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    packageData.timeIntervalsForSelectedDate.map((interval) {
                  bool isSelected =
                      packageData.selectedTimeInterval == interval;
                  String labelText = interval['inicio'];
                  if (interval['fin'] != null &&
                      interval['fin'].toString().isNotEmpty) {
                    labelText += " - ${interval['fin']}";
                  }
                  labelText += " (${interval['cupos']} cupos)";
                  return ChoiceChip(
                      label: Text(labelText,
                          style: GoogleFonts.poppins(
                              fontSize: 12,
                              color:
                                  isSelected ? Colors.white : Colors.black87)),
                      selected: isSelected,
                      selectedColor: kPrimaryColor,
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                              color: isSelected
                                  ? kPrimaryColor
                                  : Colors.grey.shade300)),
                      onSelected: (selected) => setState(() => packageData
                          .selectedTimeInterval = selected ? interval : null),
                      showCheckmark: false);
                }).toList()),
        ],
      ],
    );
  }

  Widget _buildPaymentOptions() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: paymentMethods.map((method) {
          bool isSelected = selectedPaymentMethod == method;
          return GestureDetector(
            onTap: () => setState(() => selectedPaymentMethod = method),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                  color: isSelected ? kPrimaryColor : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: isSelected ? kPrimaryColor : Colors.grey.shade300),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                              color: kPrimaryColor.withValues(alpha: 0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 4))
                        ]
                      : []),
              child: Row(children: [
                Icon(
                    method.contains('Zelle')
                        ? Icons.attach_money
                        : Icons.payment,
                    color: isSelected ? Colors.white : Colors.grey,
                    size: 18),
                const SizedBox(width: 8),
                Text(method,
                    style: GoogleFonts.poppins(
                        color: isSelected ? Colors.white : Colors.grey[800],
                        fontWeight: FontWeight.w500))
              ]),
            ),
          );
        }).toList(),
      ),
    );
  }
}
