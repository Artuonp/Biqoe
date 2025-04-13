import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:flutter/services.dart';
import 'booking_provider.dart';

class SupplierVerifyScreen extends StatefulWidget {
  final String userId;

  const SupplierVerifyScreen({super.key, required this.userId});

  @override
  State<SupplierVerifyScreen> createState() => _SupplierVerifyScreenState();
}

class _SupplierVerifyScreenState extends State<SupplierVerifyScreen> {
  late Stream<QuerySnapshot> _reservationsStream;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _setupStream();
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

  void _setupStream() {
    final user = _auth.currentUser;
    if (user == null) return;

    _reservationsStream = FirebaseFirestore.instance
        .collectionGroup('reservas')
        .where('supplier', isEqualTo: user.uid)
        .snapshots();
  }

  Future<void> _verifyBooking(
      String reservaId, String supplierId, String clienteUserId) async {
    try {
      final bookingProvider =
          Provider.of<BookingProvider>(context, listen: false);
      await bookingProvider.verifyBooking(reservaId, supplierId);

      await _sendNotificationToUser(clienteUserId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reserva verificada con éxito')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
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
        await rootBundle.loadString(serviceAccountPath),
      );

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
              'data': {
                'click_action': 'FLUTTER_NOTIFICATION_CLICK',
                'message': 'Tu reserva ha sido verificada.',
              },
            },
          };

          final response = await client.post(
            Uri.parse(fcmUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(notification),
          );

          if (response.statusCode != 200) {
            // ignore: avoid_print
            print('Error al enviar la notificación: ${response.body}');
          }
        }
      }
    } catch (e) {
      // ignore: avoid_print
      print('Error al enviar la notificación: $e');
    }
  }

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
            borderSide: BorderSide.none,
          ),
        ),
        style: GoogleFonts.poppins(fontSize: 16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Usuario no autenticado')),
      );
    }

    final size = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 243, 248, 255),
      ),
      backgroundColor: const Color.fromARGB(255, 243, 248, 255),
      body: Padding(
        padding:
            EdgeInsets.symmetric(horizontal: size.width * 0.08, vertical: 20),
        child: Column(
          children: [
            _buildSearchBar(),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _reservationsStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildLoadingIndicator();
                  }

                  if (snapshot.hasError) {
                    return _buildErrorWidget(snapshot.error.toString());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return _buildEmptyState();
                  }

                  final allReservations = snapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final code = data['code']?.toString().toLowerCase() ?? '';
                    if (!code.contains(_searchQuery.toLowerCase())) {
                      return false;
                    }

                    final packages = data['packages'] as List<dynamic>?;
                    if (packages == null || packages.isEmpty) return false;

                    return packages.any((pkg) {
                      final package = pkg as Map<String, dynamic>;
                      final fechaReserva = package['fechaReserva'];
                      final horaReserva = package['horaReserva'];
                      return fechaReserva != null && horaReserva != null;
                    });
                  }).toList();

                  final pendingReservations = allReservations
                      .where((doc) =>
                          (doc.data() as Map<String, dynamic>)['estado'] ==
                          'pendiente')
                      .toList();
                  final verifiedReservations = allReservations
                      .where((doc) =>
                          (doc.data() as Map<String, dynamic>)['estado'] ==
                          'verificado')
                      .toList();

                  return ListView(
                    children: [
                      ...pendingReservations.map((doc) {
                        final reservaData = doc.data() as Map<String, dynamic>;
                        return _buildReservationCard(
                            reservaData,
                            doc.id,
                            reservaData[
                                'userId'], // ID del usuario cliente (notificaciones)
                            reservaData[
                                'supplier'] // 🎯 ID del proveedor (Firestore path)
                            );
                      }),
                      ...verifiedReservations.map((doc) {
                        final reservaData = doc.data() as Map<String, dynamic>;
                        return _buildReservationCard(
                            reservaData,
                            doc.id,
                            reservaData['userId'], // ID del usuario cliente
                            reservaData['supplier'] // ID del proveedor
                            );
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

  Widget _buildLoadingIndicator() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF113049)),
      ),
    );
  }

  Widget _buildErrorWidget(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          'Error al cargar reservas: $error',
          style: GoogleFonts.poppins(color: Colors.red, fontSize: 16),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Text(
        'No hay reservas pendientes',
        style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey),
      ),
    );
  }

  Widget _buildReservationCard(
    Map<String, dynamic> reservaData,
    String reservaId,
    String clienteUserId,
    String supplierId, // Nuevo parámetro con el ID correcto
  ) {
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
            Text(
              reservaData['planName'] ?? 'Nombre no disponible',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF113049),
              ),
            ),
            const SizedBox(height: 8),
            ..._buildPackageInfo(reservaData),
            ..._buildPaymentInfo(reservaData, fecha),
            ..._buildUserInfo(reservaData),
            _buildVerificationButton(
                reservaData, reservaId, supplierId, clienteUserId),
          ],
        ),
      ),
    );
  }

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
      Text(
        'Detalles de paquetes comprados:',
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.bold,
          color: const Color.fromRGBO(17, 48, 73, 1),
        ),
      ),
      ...packages.map<Widget>((pkg) {
        final package = pkg as Map<String, dynamic>;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  '• Paquete ${package['numero']}  (${package['miniDescripcion']})',
                  style: GoogleFonts.poppins(
                      color: const Color.fromRGBO(17, 48, 73, 1),
                      fontSize: 14)),
              if (package['fechaReserva'] != null)
                Text(
                    '    Fecha: ${_formatDate(DateTime.parse(package['fechaReserva']))}',
                    style: GoogleFonts.poppins(
                        color: const Color.fromRGBO(17, 48, 73, 1),
                        fontSize: 14)),
              if (package['horaReserva'] != null)
                Text('    Hora: ${package['horaReserva']}',
                    style: GoogleFonts.poppins(
                        color: const Color.fromRGBO(17, 48, 73, 1),
                        fontSize: 14)),
              Text('    Cantidad: ${package['personas']}',
                  style: GoogleFonts.poppins(
                      color: const Color.fromRGBO(17, 48, 73, 1),
                      fontSize: 14)),
            ],
          ),
        );
      }),
    ];
  }

  List<Widget> _buildPaymentInfo(
      Map<String, dynamic> reservaData, DateTime? fecha) {
    double totalDolares = reservaData['totalPrice']?.toDouble() ?? 0.0;
    double totalPriceBs = reservaData['totalPriceBs']?.toDouble() ?? 0.0;

    return [
      const SizedBox(height: 12),
      Text(
        'Detalles del pago:',
        style: GoogleFonts.poppins(
            color: const Color.fromRGBO(17, 48, 73, 1),
            fontSize: 14,
            fontWeight: FontWeight.bold),
      ),
      Text(
        'Pago: \$${totalDolares.toStringAsFixed(2)} | Bs ${totalPriceBs.toStringAsFixed(2)}',
        style: GoogleFonts.poppins(
            color: const Color.fromRGBO(17, 48, 73, 1), fontSize: 14),
      ),
      if (fecha != null) ...[
        Text('Fecha: ${_formatDate(fecha)}',
            style: GoogleFonts.poppins(
                color: const Color.fromRGBO(17, 48, 73, 1), fontSize: 14)),
        Text('Hora: ${_formatTime(fecha)}',
            style: GoogleFonts.poppins(
                color: const Color.fromRGBO(17, 48, 73, 1), fontSize: 14)),
      ],
      Text(
        'Método: ${reservaData['paymentMethod'] ?? 'No especificado'}',
        style: GoogleFonts.poppins(
            color: const Color.fromRGBO(17, 48, 73, 1), fontSize: 14),
      ),
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
      Text(
        'Datos del usuario:',
        style: GoogleFonts.poppins(
            color: const Color.fromRGBO(17, 48, 73, 1),
            fontSize: 14,
            fontWeight: FontWeight.bold),
      ),
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
      Map<String, dynamic> reservaData,
      String reservaId,
      String supplierId,
      clienteUserId // ID del cliente recibido
      ) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Align(
        alignment: Alignment.centerRight,
        child: reservaData['estado'] == 'pendiente'
            ? ElevatedButton(
                onPressed: () => _verifyBooking(reservaId, supplierId,
                    clienteUserId), // Usamos el ID correcto
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF113049),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Verificar',
                  style: GoogleFonts.poppins(color: Colors.white),
                ),
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
      return fecha is String ? DateTime.parse(fecha) : fecha as DateTime?;
    } catch (_) {
      return null;
    }
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  String _formatTime(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}
