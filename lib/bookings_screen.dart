// ignore_for_file: unused_element

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:google_fonts/google_fonts.dart';
import 'saved_destinations_screen.dart';
import 'settings_screen.dart';
import 'booking_provider.dart';
import 'search_screen.dart';
import 'package:intl/intl.dart';
import 'package:hugeicons/hugeicons.dart';

class BookingsScreen extends StatefulWidget {
  final String userId;

  const BookingsScreen({super.key, required this.userId});

  @override
  BookingsScreenState createState() => BookingsScreenState();
}

class BookingsScreenState extends State<BookingsScreen> {
  bool showActivePlans = true;
  List<Map<String, dynamic>> savedDestinations = [];

  @override
  void initState() {
    super.initState();

    // Carga inicial de las reservas
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bookingProvider =
          Provider.of<BookingProvider>(context, listen: false);
      bookingProvider.loadBookings(widget.userId);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bookingProvider = Provider.of<BookingProvider>(context);

    bookingProvider.addListener(() {
      // Eliminar la notificación completa
    });
  }

  @override
  Widget build(BuildContext context) {
    final bookingProvider = Provider.of<BookingProvider>(context);
    final pendingBookings = bookingProvider.getPendingBookings(widget.userId);
    final verifiedBookings = bookingProvider.getVerifiedBookings(widget.userId);
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color.fromARGB(255, 243, 247, 254),
        appBar: AppBar(
          backgroundColor: const Color.fromARGB(255, 243, 247, 254),
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(child: _buildPlanButton("Pendientes", showActivePlans)),
              const SizedBox(width: 8),
              Expanded(
                  child: _buildPlanButton("Verificados", !showActivePlans)),
            ],
          ),
        ),
        body: Center(
          child: showActivePlans
              ? _buildPendingPlans(pendingBookings, screenWidth)
              : _buildVerifiedPlans(verifiedBookings, screenWidth),
        ),
        bottomNavigationBar: Container(
          height: screenHeight * 0.1,
          decoration: const BoxDecoration(
            color: Color.fromARGB(255, 255, 255, 255),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10.0),
            child: BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.transparent,
              elevation: 0,
              selectedItemColor: const Color.fromRGBO(17, 48, 73, 1),
              unselectedItemColor:
                  const Color.fromRGBO(17, 48, 73, 1), // Color uniforme
              showSelectedLabels: false,
              showUnselectedLabels: false,
              onTap: (index) {
                switch (index) {
                  case 0:
                    Navigator.pushReplacement(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (_, __, ___) => SearchScreen(
                          destinations: const [],
                          userId: widget.userId,
                        ),
                        transitionsBuilder: (_, a, __, c) => FadeTransition(
                          opacity: a,
                          child: c,
                        ),
                        transitionDuration: const Duration(milliseconds: 600),
                      ),
                    );
                    break;
                  case 1:
                    // Ya estamos en BookingsScreen, no necesita navegación
                    break;
                  case 2:
                    Navigator.pushReplacement(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (_, __, ___) => SavedDestinationsScreen(
                          userId: widget.userId,
                        ),
                        transitionsBuilder: (_, a, __, c) => FadeTransition(
                          opacity: a,
                          child: c,
                        ),
                        transitionDuration: const Duration(milliseconds: 600),
                      ),
                    );
                    break;
                  case 3:
                    Navigator.pushReplacement(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (_, __, ___) => SettingsScreen(
                          userId: widget.userId,
                          savedDestinations: savedDestinations,
                        ),
                        transitionsBuilder: (_, a, __, c) => FadeTransition(
                          opacity: a,
                          child: c,
                        ),
                        transitionDuration: const Duration(milliseconds: 600),
                      ),
                    );
                    break;
                }
              },
              items: [
                BottomNavigationBarItem(
                  icon: HugeIcon(
                    icon: HugeIcons.strokeRoundedHome02,
                    color: Color.fromRGBO(17, 48, 73, 1), // Color normal
                    size: 24.0,
                  ),
                  label: 'Buscar',
                ),
                BottomNavigationBarItem(
                  icon: HugeIcon(
                    icon: HugeIcons.strokeRoundedTicket03,
                    color: Color.fromRGBO(240, 169, 52, 1), // Color activo
                    size: 24.0,
                  ),
                  label: 'Booked',
                ),
                BottomNavigationBarItem(
                  icon: HugeIcon(
                    icon: HugeIcons.strokeRoundedFavourite,
                    color: Color.fromRGBO(17, 48, 73, 1),
                    size: 24.0,
                  ),
                  label: 'Saved',
                ),
                BottomNavigationBarItem(
                  icon: HugeIcon(
                    icon: HugeIcons.strokeRoundedSettings01,
                    color: Color.fromRGBO(17, 48, 73, 1),
                    size: 24.0,
                  ),
                  label: 'Configuración',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPendingPlans(
      List<Map<String, dynamic>> pendingBookings, double screenWidth) {
    if (pendingBookings.isEmpty) {
      return Text(
        "No tienes planes pendientes",
        style: GoogleFonts.poppins(
            fontSize: 18.0, color: const Color.fromRGBO(17, 48, 73, 1)),
      );
    } else {
      return ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: pendingBookings.length, // o verifiedBookings.length
        itemBuilder: (context, index) {
          final booking = pendingBookings[index]; // o verifiedBookings[index]

          // Verificar si todos los paquetes tienen fecha y hora válidas
          final hasInvalidPackages = booking['packages'].any((pkg) =>
              pkg['fechaReserva'] == null || pkg['horaReserva'] == null);

          // Si hay paquetes inválidos, no mostrar el recuadro
          if (hasInvalidPackages) {
            return const SizedBox.shrink(); // No renderiza nada
          }

          // Si todos los paquetes son válidos, mostrar el recuadro
          return Card(
            color: Colors.white,
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            child: ListTile(
              title: Text(
                booking['planName'],
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: const Color.fromRGBO(17, 48, 73, 1),
                ),
                overflow:
                    TextOverflow.ellipsis, // Maneja el desbordamiento del texto
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${booking['planLocation']} - \$${booking['planPrice']}',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: const Color.fromRGBO(17, 48, 73, 1),
                    ),
                  ),
                  ...booking['packages']
                      .map<Widget>((pkg) => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Paquete: ${pkg['numero']}  (${pkg['miniDescripcion']})',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: const Color.fromRGBO(17, 48, 73, 1),
                                ),
                              ),
                              Text(
                                'Cantidad: ${pkg['personas']}',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: const Color.fromRGBO(17, 48, 73, 1),
                                ),
                              ),
                              Text(
                                'Fecha: ${DateFormat('dd/MM/yyyy').format(DateTime.parse(pkg['fechaReserva']))}',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: const Color.fromRGBO(17, 48, 73, 1),
                                ),
                              ),
                              Text(
                                'Hora: ${pkg['horaReserva']}',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: const Color.fromRGBO(17, 48, 73, 1),
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                          ))
                      .toList(),
                  Text(
                    'Código: ${booking['code']}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: const Color.fromRGBO(17, 48, 73, 1),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              trailing: Text(
                booking['estado'] == 'pendiente' ? 'Pendiente' : 'Verificado',
                style: GoogleFonts.poppins(
                  color: booking['estado'] == 'pendiente'
                      ? Colors.orange
                      : Colors.green,
                ),
              ),
            ),
          );
        },
      );
    }
  }

  Widget _buildVerifiedPlans(
      List<Map<String, dynamic>> verifiedBookings, double screenWidth) {
    if (verifiedBookings.isEmpty) {
      return Text(
        "No tienes planes verificados",
        style: GoogleFonts.poppins(
            fontSize: 18.0, color: const Color.fromRGBO(17, 48, 73, 1)),
      );
    } else {
      return ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: verifiedBookings.length, // o verifiedBookings.length
        itemBuilder: (context, index) {
          final booking = verifiedBookings[index]; // o verifiedBookings[index]

          // Verificar si todos los paquetes tienen fecha y hora válidas
          final hasInvalidPackages = booking['packages'].any((pkg) =>
              pkg['fechaReserva'] == null || pkg['horaReserva'] == null);

          // Si hay paquetes inválidos, no mostrar el recuadro
          if (hasInvalidPackages) {
            return const SizedBox.shrink(); // No renderiza nada
          }

          // Si todos los paquetes son válidos, mostrar el recuadro
          return Card(
            color: Colors.white,
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            child: ListTile(
              title: Text(
                booking['planName'],
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: const Color.fromRGBO(17, 48, 73, 1),
                ),
                overflow:
                    TextOverflow.ellipsis, // Maneja el desbordamiento del texto
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${booking['planLocation']} - \$${booking['planPrice']}',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: const Color.fromRGBO(17, 48, 73, 1),
                    ),
                  ),
                  ...booking['packages']
                      .map<Widget>((pkg) => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Paquete: ${pkg['numero']}  (${pkg['miniDescripcion']})',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: const Color.fromRGBO(17, 48, 73, 1),
                                ),
                              ),
                              Text(
                                'Cantidad: ${pkg['personas']}',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: const Color.fromRGBO(17, 48, 73, 1),
                                ),
                              ),
                              Text(
                                'Fecha: ${DateFormat('dd/MM/yyyy').format(DateTime.parse(pkg['fechaReserva']))}',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: const Color.fromRGBO(17, 48, 73, 1),
                                ),
                              ),
                              Text(
                                'Hora: ${pkg['horaReserva']}',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: const Color.fromRGBO(17, 48, 73, 1),
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                          ))
                      .toList(),
                  Text(
                    'Código: ${booking['code']}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: const Color.fromRGBO(17, 48, 73, 1),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              trailing: Text(
                booking['estado'] == 'pendiente' ? 'Pendiente' : 'Verificado',
                style: GoogleFonts.poppins(
                  color: booking['estado'] == 'pendiente'
                      ? Colors.orange
                      : Colors.green,
                ),
              ),
            ),
          );
        },
      );
    }
  }

  Future<void> _downloadPDF(String documentId) async {
    final pdf = pw.Document();
    final bookingData = await FirebaseFirestore.instance
        .collection('reservaciones')
        .doc(widget.userId)
        .collection('reservas')
        .doc(documentId)
        .get();

    if (bookingData.exists) {
      final data = bookingData.data()!;
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Comprobante de reserva',
                    style: pw.TextStyle(
                        fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 20),
                pw.Text('Nombre del plan: ${data['planName']}'),
                pw.Text('Ubicación: ${data['planLocation']}'),
                pw.Text('Precio: \$${data['totalPrice']}'),
                pw.Text('Método de pago: ${data['paymentMethod']}'),
                pw.SizedBox(height: 20),
                pw.Text('Paquetes:',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ...data['packages']
                    .map<pw.Widget>((pkg) => pw.Column(
                          // Paquetes
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                                '- Paquete ${pkg['numero']}  (${pkg['miniDescripcion']})'),
                            pw.Text('  Cantidad: ${pkg['personas']}'),
                            pw.Text('  Fecha: ${pkg['fechaReserva']}'),
                            pw.Text('  Hora: ${pkg['horaReserva']}'),
                            pw.SizedBox(height: 8),
                          ],
                        ))
                    .toList(),
              ],
            );
          },
        ),
      );

      final output = await getTemporaryDirectory();
      final file = File("${output.path}/comprobante.pdf");
      await file.writeAsBytes(await pdf.save());

      await Printing.sharePdf(
          bytes: await pdf.save(), filename: 'comprobante.pdf');
    }
  }

  Widget _buildPlanButton(String title, bool isActive) {
    return GestureDetector(
      onTap: () {
        setState(() {
          showActivePlans = title == "Pendientes";
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        decoration: BoxDecoration(
          color: isActive
              ? const Color.fromRGBO(17, 48, 73, 1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(color: const Color.fromRGBO(17, 48, 73, 1)),
        ),
        alignment: Alignment.center, // Alinea el contenido en el centro
        child: Center(
          // Asegura que el texto esté centrado
          child: Text(
            title,
            textAlign: TextAlign.center, // Centra el texto dentro del widget
            style: GoogleFonts.poppins(
              color:
                  isActive ? Colors.white : const Color.fromRGBO(17, 48, 73, 1),
              fontSize: 16.0,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
