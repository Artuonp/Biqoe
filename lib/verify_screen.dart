import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart'; // Importamos intl para formatear fechas
import 'package:logger/logger.dart';
import 'package:flutter/services.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'booking_provider.dart';

class VerifyScreen extends StatefulWidget {
  final String userId;

  const VerifyScreen({super.key, required this.userId});

  @override
  State<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends State<VerifyScreen> {
  late Stream<QuerySnapshot> _reservationsStream;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final Logger logger = Logger();

  @override
  void initState() {
    super.initState();
    // La consulta inicial está bien, trae todas las reservas
    _reservationsStream =
        FirebaseFirestore.instance.collectionGroup('reservas').snapshots();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _verifyBooking(
      BuildContext context, String reservaId, String supplierId) async {
    // MODIFICADO: Ahora pasamos el supplierId a la función de verificación
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      final bookingProvider =
          Provider.of<BookingProvider>(context, listen: false);
      // Usamos el supplierId que viene con la reserva para la ruta del documento
      await bookingProvider.verifyBooking(reservaId, supplierId);

      // Obtenemos el userId del cliente para enviarle la notificación
      final doc = await FirebaseFirestore.instance
          .collection('reservaciones')
          .doc(supplierId)
          .collection('reservas')
          .doc(reservaId)
          .get();
      final clienteUserId = doc.data()?['userId'];

      if (clienteUserId != null) {
        await _sendNotificationToUser(clienteUserId);
      }

      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Reserva verificada con éxito')),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Error al verificar la reserva: $e')),
      );
    }
  }

  Future<void> _sendNotificationToUser(String userId) async {
    const String serviceAccountPath =
        'assets/biqoe-app-firebase-adminsdk-fbsvc-067c9b5471.json';
    const List<String> scopes = [
      'https://www.googleapis.com/auth/firebase.messaging'
    ];

    try {
      final serviceAccount = ServiceAccountCredentials.fromJson(
          await rootBundle.loadString(serviceAccountPath));
      final client = await clientViaServiceAccount(serviceAccount, scopes);
      const String fcmUrl =
          'https://fcm.googleapis.com/v1/projects/biqoe-app/messages:send';
      final userSnapshot = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(userId)
          .get();

      if (userSnapshot.exists) {
        final userData = userSnapshot.data() as Map<String, dynamic>;
        final deviceToken = userData['deviceToken'];

        if (deviceToken != null && deviceToken.isNotEmpty) {
          final notification = {
            'message': {
              'token': deviceToken,
              'notification': {
                'title': 'Reserva Verificada',
                'body': 'Tu reserva ha sido verificada.',
              },
              'data': {'click_action': 'FLUTTER_NOTIFICATION_CLICK'},
            },
          };
          await client.post(Uri.parse(fcmUrl),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(notification));
        }
      }
    } catch (e) {
      logger.e('Error al enviar la notificación: $e');
    }
  }

  // MODIFICADO: Lógica de detalles de paquete ahora es condicional
  List<Widget> _buildPackageInfo(Map<String, dynamic> reservaData) {
    final packages = reservaData['packages'] as List<dynamic>?;
    if (packages == null || packages.isEmpty) return [];

    return [
      const SizedBox(height: 3),
      Text('Código: ${reservaData['code']}',
          style: GoogleFonts.poppins(
              color: const Color.fromARGB(255, 3, 113, 10),
              fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Text('Detalles de paquetes comprados:',
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: const Color.fromRGBO(17, 48, 73, 1))),
      ...packages.map<Widget>((pkg) {
        final package = pkg as Map<String, dynamic>;
        final bookingType = package['tipoDeReserva'] ?? 'Reserva';

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  '• Paquete ${package['numero']} (${package['miniDescripcion']})',
                  style: GoogleFonts.poppins(
                      color: const Color.fromRGBO(17, 48, 73, 1),
                      fontSize: 14)),
              Text('   Cantidad: ${package['personas']}',
                  style: GoogleFonts.poppins(
                      color: const Color.fromRGBO(17, 48, 73, 1),
                      fontSize: 14)),

              // Lógica condicional para mostrar detalles
              if (bookingType == 'Reserva') ...[
                if (package['fechaReserva'] != null)
                  Text(
                      '   Fecha: ${_formatDate(DateTime.parse(package['fechaReserva']))}',
                      style: GoogleFonts.poppins(
                          color: const Color.fromRGBO(17, 48, 73, 1),
                          fontSize: 14)),
                if (package['horaReserva'] != null)
                  Text('   Hora: ${package['horaReserva']}',
                      style: GoogleFonts.poppins(
                          color: const Color.fromRGBO(17, 48, 73, 1),
                          fontSize: 14)),
              ] else ...[
                Text('   Tipo: $bookingType',
                    style: GoogleFonts.poppins(
                        color: const Color.fromRGBO(17, 48, 73, 1),
                        fontSize: 14,
                        fontWeight: FontWeight.bold)),
              ]
            ],
          ),
        );
      }),
    ];
  }

  // El resto de los métodos build... y auxiliares se mantienen casi igual
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
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
              borderSide: BorderSide.none),
        ),
        style: GoogleFonts.poppins(fontSize: 16),
      ),
    );
  }

  Widget _buildReservationCard(
      Map<String, dynamic> reservaData, String reservaId, String supplierId) {
    final fecha = _parseDate(reservaData['fecha']);
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(reservaData['planName'] ?? 'Nombre no disponible',
                style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF113049))),
            const SizedBox(height: 8),
            ..._buildPackageInfo(reservaData),
            ..._buildPaymentInfo(reservaData, fecha),
            ..._buildUserInfo(reservaData),
            _buildVerificationButton(reservaData, reservaId, supplierId),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPaymentInfo(
      Map<String, dynamic> reservaData, DateTime? fecha) {
    double totalDolares =
        (reservaData['totalPrice'] as num?)?.toDouble() ?? 0.0;
    double totalPriceBs =
        (reservaData['totalPriceBs'] as num?)?.toDouble() ?? 0.0;
    return [
      const SizedBox(height: 12),
      Text('Detalles del pago:',
          style: GoogleFonts.poppins(
              color: const Color.fromRGBO(17, 48, 73, 1),
              fontSize: 14,
              fontWeight: FontWeight.bold)),
      Text(
          'Pago: \$${totalDolares.toStringAsFixed(2)} | Bs ${totalPriceBs.toStringAsFixed(2)}',
          style: GoogleFonts.poppins(
              color: const Color.fromRGBO(17, 48, 73, 1), fontSize: 14)),
      if (fecha != null) ...[
        Text('Fecha: ${_formatDate(fecha)}',
            style: GoogleFonts.poppins(
                color: const Color.fromRGBO(17, 48, 73, 1), fontSize: 14)),
        Text('Hora: ${_formatTime(fecha)}',
            style: GoogleFonts.poppins(
                color: const Color.fromRGBO(17, 48, 73, 1), fontSize: 14)),
      ],
      Text('Método: ${reservaData['paymentMethod'] ?? 'No especificado'}',
          style: GoogleFonts.poppins(
              color: const Color.fromRGBO(17, 48, 73, 1), fontSize: 14)),
    ];
  }

  List<Widget> _buildUserInfo(Map<String, dynamic> reservaData) {
    return [
      if (reservaData['transactionCode']?.isNotEmpty ?? false)
        Text('Referencia: ${reservaData['transactionCode']}',
            style: GoogleFonts.poppins(
                color: const Color.fromRGBO(17, 48, 73, 1), fontSize: 14)),
      if (reservaData['cedula']?.isNotEmpty ?? false)
        Text('Cédula: ${reservaData['cedula']}',
            style: GoogleFonts.poppins(
                color: const Color.fromRGBO(17, 48, 73, 1), fontSize: 14)),
      if (reservaData['correo']?.isNotEmpty ?? false)
        Text('Correo: ${reservaData['correo']}',
            style: GoogleFonts.poppins(
                color: const Color.fromRGBO(17, 48, 73, 1), fontSize: 14)),
      if (reservaData['numero']?.isNotEmpty ?? false)
        Text('Teléfono: ${reservaData['numero']}',
            style: GoogleFonts.poppins(
                color: const Color.fromRGBO(17, 48, 73, 1), fontSize: 14)),
      const SizedBox(height: 12),
      Text('Datos del usuario:',
          style: GoogleFonts.poppins(
              color: const Color.fromRGBO(17, 48, 73, 1),
              fontSize: 14,
              fontWeight: FontWeight.bold)),
      if (reservaData['name']?.isNotEmpty ?? false)
        Text('Nombre: ${reservaData['name']}',
            style: GoogleFonts.poppins(
                color: const Color.fromRGBO(17, 48, 73, 1), fontSize: 14)),
      if (reservaData['email']?.isNotEmpty ?? false)
        Text('Email: ${reservaData['email']}',
            style: GoogleFonts.poppins(
                color: const Color.fromRGBO(17, 48, 73, 1), fontSize: 14)),
      if (reservaData['celular']?.isNotEmpty ?? false)
        Text('Teléfono: ${reservaData['celular']}',
            style: GoogleFonts.poppins(
                color: const Color.fromRGBO(17, 48, 73, 1), fontSize: 14)),
    ];
  }

  Widget _buildVerificationButton(
      Map<String, dynamic> reservaData, String reservaId, String supplierId) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Align(
        alignment: Alignment.centerRight,
        child: reservaData['estado'] == 'pendiente'
            ? ElevatedButton(
                onPressed: () => _verifyBooking(context, reservaId, supplierId),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF113049),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8))),
                child: Text('Verificar',
                    style: GoogleFonts.poppins(color: Colors.white)),
              )
            : Chip(
                label: Text('Verificado',
                    style: GoogleFonts.poppins(color: Colors.white)),
                backgroundColor: const Color.fromARGB(255, 17, 139, 22),
              ),
      ),
    );
  }

  DateTime? _parseDate(dynamic fecha) {
    try {
      if (fecha is String) return DateTime.parse(fecha);
      if (fecha is Timestamp) return fecha.toDate();
      return fecha as DateTime?;
    } catch (_) {
      return null;
    }
  }

  String _formatDate(DateTime date) => DateFormat('dd/MM/yyyy').format(date);
  String _formatTime(DateTime date) => DateFormat('hh:mm a').format(date);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Verificar Reservas"),
        backgroundColor: const Color.fromARGB(255, 243, 248, 255),
        elevation: 0,
      ),
      backgroundColor: const Color.fromARGB(255, 243, 248, 255),
      body: Padding(
        padding: EdgeInsets.symmetric(
            horizontal: MediaQuery.of(context).size.width * 0.04, vertical: 10),
        child: Column(
          children: [
            _buildSearchBar(),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _reservationsStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                        child: Text('Error: ${snapshot.error}',
                            style: GoogleFonts.poppins(fontSize: 16)));
                  }
                  final data = snapshot.data?.docs;
                  if (data == null || data.isEmpty) {
                    return Center(
                        child: Text('No hay reservas disponibles',
                            style: GoogleFonts.poppins(
                                fontSize: 18.0, color: Colors.grey)));
                  }

                  // CORREGIDO: Se elimina el filtro que descartaba las reservas sin fecha/hora.
                  final filteredReservations = data.where((doc) {
                    final reservaData = doc.data() as Map<String, dynamic>;
                    final code =
                        reservaData['code']?.toString().toLowerCase() ?? '';
                    return code.contains(_searchQuery.toLowerCase());
                  }).toList();

                  final pendingReservations = filteredReservations
                      .where((doc) =>
                          (doc.data() as Map<String, dynamic>)['estado'] ==
                          'pendiente')
                      .toList();
                  final verifiedReservations = filteredReservations
                      .where((doc) =>
                          (doc.data() as Map<String, dynamic>)['estado'] ==
                          'verificado')
                      .toList();

                  if (filteredReservations.isEmpty) {
                    return Center(
                        child: Text(
                            'No se encontraron reservas con ese código.',
                            style: GoogleFonts.poppins(
                                fontSize: 18.0, color: Colors.grey)));
                  }

                  return ListView(
                    children: [
                      ...pendingReservations.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        // Pasamos el supplierId correctamente para la verificación
                        final supplierId = data['supplier'] ??
                            doc.reference.parent.parent?.id ??
                            '';
                        return _buildReservationCard(data, doc.id, supplierId);
                      }),
                      ...verifiedReservations.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final supplierId = data['supplier'] ??
                            doc.reference.parent.parent?.id ??
                            '';
                        return _buildReservationCard(data, doc.id, supplierId);
                      }),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
