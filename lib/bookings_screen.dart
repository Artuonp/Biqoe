import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart'; // NUEVO: Import para el QR
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
  bool showPendingPlans = true;
  List<Map<String, dynamic>> savedDestinations = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<BookingProvider>(context, listen: false)
          .loadBookings(widget.userId);
    });
  }

  // NUEVO: Función para mostrar el QR en grande
  void _showQrDialog(String code) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(15)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Código de Reserva',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color.fromRGBO(17, 48, 73, 1),
                  ),
                ),
                const SizedBox(height: 16),
                QrImageView(
                  data: code,
                  version: QrVersions.auto,
                  size: 200.0,
                ),
                const SizedBox(height: 16),
                Text(
                  code,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color.fromRGBO(17, 48, 73, 1),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildPackageDetails(Map<String, dynamic> pkg) {
    final bookingType = pkg['tipoDeReserva'] ?? 'Reserva';

    List<Widget> details = [
      Text(
        'Paquete: ${pkg['numero']} (${pkg['miniDescripcion']})',
        style: GoogleFonts.poppins(
            fontSize: 12, color: const Color.fromRGBO(17, 48, 73, 1)),
      ),
      Text(
        'Cantidad: ${pkg['personas']}',
        style: GoogleFonts.poppins(
            fontSize: 12, color: const Color.fromRGBO(17, 48, 73, 1)),
      ),
    ];

    switch (bookingType) {
      case 'Reserva':
        if (pkg['fechaReserva'] != null) {
          details.add(Text(
              'Fecha: ${DateFormat('dd/MM/yyyy').format(DateTime.parse(pkg['fechaReserva']))}',
              style: GoogleFonts.poppins(
                  fontSize: 12, color: const Color.fromRGBO(17, 48, 73, 1))));
        }
        if (pkg['horaReserva'] != null) {
          details.add(Text('Hora: ${pkg['horaReserva']}',
              style: GoogleFonts.poppins(
                  fontSize: 12, color: const Color.fromRGBO(17, 48, 73, 1))));
        }
        break;
      case 'Reserva Flexible':
        details.add(Text('Tipo: Reserva flexible',
            style: GoogleFonts.poppins(
                fontSize: 12, color: const Color.fromRGBO(17, 48, 73, 1))));
        if (pkg['instrucciones'] != null) {
          details.add(Text(
              'Requiere coordinación: ${pkg['instrucciones'] ? 'Sí' : 'No'}',
              style: GoogleFonts.poppins(
                  fontSize: 12, color: const Color.fromRGBO(17, 48, 73, 1))));
        }
        break;
      case 'Ticket':
        details.add(Text('Tipo: Ticket',
            style: GoogleFonts.poppins(
                fontSize: 12, color: const Color.fromRGBO(17, 48, 73, 1))));
        break;
      case 'Suscripción':
        details.add(Text('Tipo: Suscripción',
            style: GoogleFonts.poppins(
                fontSize: 12, color: const Color.fromRGBO(17, 48, 73, 1))));
        break;
    }

    details.add(const SizedBox(height: 8));
    return details;
  }

  Widget _buildBookingsList(
      List<Map<String, dynamic>> bookings, double screenWidth) {
    if (bookings.isEmpty) {
      return Center(
        child: Text(
          showPendingPlans
              ? "No tienes planes pendientes"
              : "No tienes planes verificados",
          style: GoogleFonts.poppins(
              fontSize: 18.0, color: const Color.fromRGBO(17, 48, 73, 1)),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: bookings.length,
      itemBuilder: (context, index) {
        final booking = bookings[index];
        final bookingCode = booking['code'] ?? '';

        return Card(
          color: Colors.white,
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Columna izquierda con toda la información
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking['planName'],
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: const Color.fromRGBO(17, 48, 73, 1)),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${booking['planLocation']} - €${booking['planPrice']}',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            color: const Color.fromRGBO(17, 48, 73, 1)),
                      ),
                      const Divider(height: 16, color: Colors.black12),
                      ...(booking['packages'] as List<dynamic>)
                          .expand<Widget>((pkg) => _buildPackageDetails(pkg)),
                      Text(
                        'Código: $bookingCode',
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: const Color.fromRGBO(17, 48, 73, 1),
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16), // Espacio entre el texto y el QR

                // Columna derecha con el estado y el QR
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      booking['estado'] == 'pendiente'
                          ? 'Pendiente'
                          : 'Verificado',
                      style: GoogleFonts.poppins(
                          color: booking['estado'] == 'pendiente'
                              ? Colors.orange
                              : Colors.green,
                          fontWeight: FontWeight.bold),
                    ),
                    if (booking['estado'] == 'verificado') ...[
                      const SizedBox(height: 6), // Espacio reducido
                      GestureDetector(
                        onTap: () => _showQrDialog(bookingCode),
                        child: QrImageView(
                          data: bookingCode,
                          version: QrVersions.auto,
                          size: 48.0, // Tamaño ligeramente ajustado
                          gapless: false,
                        ),
                      ),
                    ]
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlanButton(String title, bool isActive) {
    return GestureDetector(
      onTap: () {
        setState(() {
          showPendingPlans = title == "Pendientes";
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
        alignment: Alignment.center,
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            color:
                isActive ? Colors.white : const Color.fromRGBO(17, 48, 73, 1),
            fontSize: 16.0,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bookingProvider = Provider.of<BookingProvider>(context);
    bookingProvider.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bookingProvider = Provider.of<BookingProvider>(context);
    final pendingBookings = bookingProvider.getPendingBookings(widget.userId);
    final verifiedBookings = bookingProvider.getVerifiedBookings(widget.userId);
    final screenWidth = MediaQuery.of(context).size.width;

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
              Expanded(child: _buildPlanButton("Pendientes", showPendingPlans)),
              const SizedBox(width: 8),
              Expanded(
                  child: _buildPlanButton("Verificados", !showPendingPlans)),
            ],
          ),
        ),
        body: Center(
          child: showPendingPlans
              ? _buildBookingsList(pendingBookings, screenWidth)
              : _buildBookingsList(verifiedBookings, screenWidth),
        ),
        bottomNavigationBar: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
          child: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            elevation: 0,
            selectedItemColor: const Color.fromRGBO(17, 48, 73, 1),
            unselectedItemColor: const Color.fromRGBO(17, 48, 73, 1),
            showSelectedLabels: false,
            showUnselectedLabels: false,
            currentIndex: 1, // Marcar 'Booked' como activo
            onTap: (index) {
              switch (index) {
                case 0:
                  Navigator.pushReplacement(
                      context,
                      PageRouteBuilder(
                          pageBuilder: (_, __, ___) => SearchScreen(
                              destinations: const [], userId: widget.userId),
                          transitionsBuilder: (_, a, __, c) =>
                              FadeTransition(opacity: a, child: c),
                          transitionDuration:
                              const Duration(milliseconds: 600)));
                  break;
                case 1:
                  break;
                case 2:
                  Navigator.pushReplacement(
                      context,
                      PageRouteBuilder(
                          pageBuilder: (_, __, ___) =>
                              SavedDestinationsScreen(userId: widget.userId),
                          transitionsBuilder: (_, a, __, c) =>
                              FadeTransition(opacity: a, child: c),
                          transitionDuration:
                              const Duration(milliseconds: 600)));
                  break;
                case 3:
                  Navigator.pushReplacement(
                      context,
                      PageRouteBuilder(
                          pageBuilder: (_, __, ___) => SettingsScreen(
                              userId: widget.userId,
                              savedDestinations: savedDestinations),
                          transitionsBuilder: (_, a, __, c) =>
                              FadeTransition(opacity: a, child: c),
                          transitionDuration:
                              const Duration(milliseconds: 600)));
                  break;
              }
            },
            items: [
              BottomNavigationBarItem(
                  icon: HugeIcon(
                      icon: HugeIcons.strokeRoundedHome02,
                      color: const Color.fromRGBO(17, 48, 73, 1),
                      size: 24.0),
                  label: 'Buscar'),
              BottomNavigationBarItem(
                  icon: HugeIcon(
                      icon: HugeIcons.strokeRoundedTicket03,
                      color: const Color.fromRGBO(240, 169, 52, 1),
                      size: 24.0),
                  label: 'Booked'),
              BottomNavigationBarItem(
                  icon: HugeIcon(
                      icon: HugeIcons.strokeRoundedFavourite,
                      color: const Color.fromRGBO(17, 48, 73, 1),
                      size: 24.0),
                  label: 'Saved'),
              BottomNavigationBarItem(
                  icon: HugeIcon(
                      icon: HugeIcons.strokeRoundedSettings01,
                      color: const Color.fromRGBO(17, 48, 73, 1),
                      size: 24.0),
                  label: 'Configuración'),
            ],
          ),
        ),
      ),
    );
  }
}
