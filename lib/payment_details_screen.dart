import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import 'package:google_fonts/google_fonts.dart';
import 'booking_provider.dart';
import 'bookings_screen.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:googleapis_auth/auth_io.dart';
import 'package:flutter/services.dart';

class PaymentDetailsScreen extends StatefulWidget {
  final String userId;
  final String paymentMethod;
  final String planName;
  final String planLocation;
  final String supplier;
  final double totalPrice; // Cambiado de planPrice a totalPrice
  final List<Map<String, dynamic>> packagesData; // Nueva lista de paquetes

  const PaymentDetailsScreen({
    super.key,
    required this.userId,
    required this.paymentMethod,
    required this.planName,
    required this.planLocation,
    required this.totalPrice, // Recibe el total calculado
    required this.supplier,
    required this.packagesData, // Recibe la lista de paquetes
  });

  @override
  PaymentDetailsScreenState createState() => PaymentDetailsScreenState();
}

class PaymentDetailsScreenState extends State<PaymentDetailsScreen> {
  final TextEditingController transactionCodeController =
      TextEditingController();
  final TextEditingController receiptController = TextEditingController();
  final TextEditingController idController = TextEditingController();
  final TextEditingController numberController = TextEditingController();
  final TextEditingController bankController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController userController = TextEditingController();
  final TextEditingController beneficiaryController = TextEditingController();
  final TextEditingController userCedulaController = TextEditingController();
  final TextEditingController userNumeroController = TextEditingController();
  final TextEditingController userEmailController = TextEditingController();

  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    if (widget.paymentMethod == 'Pago móvil' ||
        widget.paymentMethod == 'Zelle' ||
        widget.paymentMethod == 'Zinli' ||
        widget.paymentMethod == 'Binance') {
      _loadPaymentDetails();
    }
  }

  Future<void> _loadPaymentDetails() async {
    final docSnapshot = await FirebaseFirestore.instance
        .collection('destinos')
        .doc(widget.planName)
        .get();

    if (docSnapshot.exists) {
      final data = docSnapshot.data() as Map<String, dynamic>;
      final pagos = data['pagos'] as List<dynamic>;

      if (widget.paymentMethod == 'Pago móvil') {
        final pagoMovil =
            pagos.firstWhere((pago) => pago['metodo'] == 'Pago móvil');
        setState(() {
          bankController.text = pagoMovil['banco'];
          idController.text = pagoMovil['cedula'];
          numberController.text = pagoMovil['numero'];
        });
      } else if (widget.paymentMethod == 'Zelle') {
        final zelle = pagos.firstWhere((pago) => pago['metodo'] == 'Zelle');
        setState(() {
          emailController.text = zelle['correo'];
          beneficiaryController.text = zelle['nombre'];
        });
      } else if (widget.paymentMethod == 'Zinli') {
        final zinli = pagos.firstWhere((pago) => pago['metodo'] == 'Zinli');
        setState(() {
          emailController.text = zinli['correo'];
          beneficiaryController.text = zinli['nombre'];
        });
      } else if (widget.paymentMethod == 'Binance') {
        final binance = pagos.firstWhere((pago) => pago['metodo'] == 'Binance');
        setState(() {
          emailController.text = binance['correo'];
          beneficiaryController.text = binance['nombre'];
        });
      }
    }
  }

  String _generateRandomCode(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random();
    return String.fromCharCodes(Iterable.generate(
        length, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  }

  void _completeReservation(BuildContext context) async {
    setState(() {
      _isProcessing = true; // Deshabilitar el botón
    });

    try {
      final documentId =
          FirebaseFirestore.instance.collection('reservas').doc().id;
      final code = _generateRandomCode(10);

      // Obtener datos del usuario desde la colección 'usuarios'
      final userSnapshot = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(widget.userId)
          .get();
      String userName = '';
      String userCelular = '';
      String userEmail = '';
      if (userSnapshot.exists) {
        final userData = userSnapshot.data() as Map<String, dynamic>;
        userName = userData['name'] ?? '';
        userCelular = userData['celular'] ?? '';
        userEmail = userData['email'] ?? '';
      }

      // Obtener la tasa y calcular totalPriceBs
      final configSnapshot = await FirebaseFirestore.instance
          .collection('config')
          .doc('tasa')
          .get();
      double tasa = 67.0;
      if (configSnapshot.exists) {
        tasa = configSnapshot.get('valor') ?? 67.0;
      }
      double totalPriceBs = widget.totalPrice * tasa;

      // Agregar la reserva mediante el provider (si es que lo usas)
      if (context.mounted) {
        await Provider.of<BookingProvider>(context, listen: false).addBooking(
          userId: widget.userId,
          planName: widget.planName,
          name: userName,
          email: userEmail,
          celular: userCelular,
          totalPriceBs: totalPriceBs,
          planLocation: widget.planLocation,
          planPrice: widget.totalPrice,
          supplier: widget.supplier,
          paymentMethod: widget.paymentMethod,
          transactionCode: transactionCodeController.text,
          receipt: receiptController.text,
          documentId: documentId,
          code: code,
          cedula: widget.paymentMethod == 'Pago móvil'
              ? userCedulaController.text
              : idController.text,
          numero: widget.paymentMethod == 'Pago móvil'
              ? userNumeroController.text
              : numberController.text,
          correo: (widget.paymentMethod == 'Zelle' ||
                  widget.paymentMethod == 'Zinli' ||
                  widget.paymentMethod == 'Binance')
              ? userEmailController.text
              : emailController.text,
          packagesData: widget.packagesData
              .map((package) => {
                    'numero': package['numero'],
                    'fecha': DateFormat('yyyy-MM-dd').format(package['fecha']),
                    'hora': package['hora'],
                    'personas': package['personas'],
                    'miniDescripcion': package['miniDescripcion'],
                  })
              .toList(),
        );
      }

      // Crear el documento de reserva con los nuevos campos
      await FirebaseFirestore.instance
          .collection('reservas')
          .doc(documentId)
          .set({
        'estado': 'pendiente',
        'userId': widget.userId,
        'paymentMethod': widget.paymentMethod,
        'planName': widget.planName,
        'planLocation': widget.planLocation,
        'totalPrice': widget.totalPrice,
        'totalPriceBs': totalPriceBs,
        'supplier': widget.supplier,
        'transactionCode': transactionCodeController.text,
        'receipt': receiptController.text,
        'code': code,
        'name': userName,
        'celular': userCelular,
        'email': userEmail,
        'packages': widget.packagesData
            .map((package) => {
                  'numero': package['numero'],
                  'fecha': DateFormat('yyyy-MM-dd').format(package['fecha']),
                  'hora': package['hora'],
                  'personas': package['personas'],
                  'miniDescripcion': package['miniDescripcion'],
                })
            .toList(),
        if (widget.paymentMethod == 'Pago móvil') ...{
          'cedula': userCedulaController.text,
          'numero': userNumeroController.text,
          'banco': bankController.text,
        },
        if (widget.paymentMethod == 'Zelle') ...{
          'correo': userEmailController.text,
          'beneficiario': beneficiaryController.text,
        },
        if (widget.paymentMethod == 'Zinli') ...{
          'correo': userEmailController.text,
          'beneficiario': beneficiaryController.text,
        },
        if (widget.paymentMethod == 'Binance') ...{
          'correo': userEmailController.text,
          'beneficiario': beneficiaryController.text,
        },
        if (widget.paymentMethod == 'Efectivo') ...{
          'cedula': idController.text,
        },
        if (widget.paymentMethod == 'Gratis') ...{
          'cedula': idController.text,
        },
      });

      // Obtener el token del supplier
      final supplierSnapshot = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(widget.supplier)
          .get();

      if (supplierSnapshot.exists) {
        final supplierData = supplierSnapshot.data() as Map<String, dynamic>;
        final deviceToken = supplierData['deviceToken'];

        if (deviceToken != null && deviceToken.isNotEmpty) {
          // Enviar notificación al supplier
          await _sendNotificationToSupplier(deviceToken);
        }
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushReplacement(
            this.context,
            MaterialPageRoute(
              builder: (context) => BookingsScreen(userId: widget.userId),
            ),
          );
        }
      });
    } catch (e) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showErrorDialog(
              context, 'Ocurrió un error al completar la reserva.');
        }
      });
    } finally {
      setState(() {
        _isProcessing = false; // Habilitar el botón nuevamente
      });
    }
  }

  Future<void> _sendNotificationToSupplier(String supplierToken) async {
    const String serviceAccountPath =
        'assets/biqoe-app-firebase-adminsdk-fbsvc-067c9b5471.json'; // Cambia esto
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

      // Obtener el nombre del proveedor
      final supplierSnapshot = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(widget.supplier)
          .get();

      String supplierName = 'El proveedor';
      if (supplierSnapshot.exists) {
        final supplierData = supplierSnapshot.data() as Map<String, dynamic>;
        supplierName = supplierData['name'] ?? 'El proveedor';
      }

      // Obtener los tokens de los administradores
      final adminSnapshot = await FirebaseFirestore.instance
          .collection('usuarios')
          .where('isAdmin', isEqualTo: true)
          .get();

      final adminTokens = adminSnapshot.docs
          .map((doc) => doc.data()['deviceToken'] as String?)
          .where((token) => token != null && token.isNotEmpty)
          .toList();

      // Combinar el token del proveedor con los tokens de los administradores
      final allTokens = [supplierToken, ...adminTokens];

      for (final token in allTokens) {
        // Determinar el mensaje según el destinatario
        final isSupplier = token == supplierToken;
        final notificationBody = isSupplier
            ? 'Tienes una nueva reservación.'
            : '$supplierName tiene una nueva reservación.';

        final notification = {
          'message': {
            'token': token,
            'notification': {
              'title': 'Nueva Reservación',
              'body': notificationBody,
            },
            'data': {
              'click_action': 'FLUTTER_NOTIFICATION_CLICK',
              'message': notificationBody,
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
    } catch (e) {
      // ignore: avoid_print
      print('Error al enviar la notificación: $e');
    }
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Error',
              style: TextStyle(
                  color: Color.fromRGBO(17, 48, 73, 1),
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins')),
          content: Text(
            message,
            style: TextStyle(
                color: const Color.fromRGBO(17, 48, 73, 1),
                fontFamily: 'Poppins'),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('OK',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.bold,
                      color: Color.fromRGBO(17, 48, 73, 1))),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Widget infoCard({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color.fromARGB(255, 214, 214, 214),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: const Color.fromRGBO(17, 48, 73, 0.08),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String pagoMovilCedula = idController.text;
    final String pagoMovilNumero = numberController.text;
    final String emailproveedor = emailController.text;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 243, 247, 254),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('config')
                  .doc('tasa')
                  .snapshots(),
              builder: (context, snapshot) {
                double tasa = 67.0;
                if (snapshot.hasData && snapshot.data!.exists) {
                  tasa = snapshot.data!.get('valor') ?? 67.0;
                }
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8.0, vertical: 4.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Text(
                    'Tasa: ${tasa.toStringAsFixed(2)} Bs/€',
                    style: GoogleFonts.poppins(
                        color: const Color.fromRGBO(17, 48, 73, 1),
                        fontWeight: FontWeight.bold),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  widget.paymentMethod,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color.fromRGBO(17, 48, 73, 1),
                  ),
                ),
              ),
              if (widget.paymentMethod == 'Pago móvil') ...[
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('config')
                      .doc('tasa')
                      .snapshots(),
                  builder: (context, snapshot) {
                    double tasa = 67.0;
                    if (snapshot.hasData && snapshot.data!.exists) {
                      tasa = snapshot.data!.get('valor') ?? 67.0;
                    }
                    final amountInBolivares = widget.totalPrice * tasa;
                    return infoCard(
                      children: [
                        Text(
                          'Precio:',
                          style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: const Color.fromRGBO(17, 48, 73, 1)),
                        ),
                        Text(
                          'En euros: €${widget.totalPrice.toStringAsFixed(2)}',
                          style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: const Color.fromRGBO(17, 48, 73, 1)),
                        ),
                        Text(
                          'En bolívares: Bs ${amountInBolivares.toStringAsFixed(2)}',
                          style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: const Color.fromRGBO(17, 48, 73, 1)),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Datos para el pago móvil:',
                          style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: const Color.fromRGBO(17, 48, 73, 1)),
                        ),
                        Text('Banco: ${bankController.text}',
                            style: GoogleFonts.poppins(
                                fontSize: 16,
                                color: const Color.fromRGBO(17, 48, 73, 1))),
                        Text('Documento de identificación: $pagoMovilCedula',
                            style: GoogleFonts.poppins(
                                fontSize: 16,
                                color: const Color.fromRGBO(17, 48, 73, 1))),
                        Text('Número de celular: $pagoMovilNumero',
                            style: GoogleFonts.poppins(
                                fontSize: 16,
                                color: const Color.fromRGBO(17, 48, 73, 1))),
                      ],
                    );
                  },
                ),
              ],
              if (widget.paymentMethod == 'Pago móvil') ...[
                const SizedBox(height: 20),
                Center(
                  child: Text(
                    'Reporta tu pago',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color.fromRGBO(17, 48, 73, 1),
                    ),
                  ),
                ),
                infoCard(
                  children: [
                    Text(
                      'Ingresa la referencia de la transacción, la cédula y número de celular de quien realizó el pago móvil',
                      style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: const Color.fromRGBO(17, 48, 73, 1)),
                    ),
                    TextFormField(
                      controller: transactionCodeController,
                      decoration: InputDecoration(
                          labelText: 'Código de Transacción',
                          labelStyle: GoogleFonts.poppins(
                              color: const Color.fromRGBO(17, 48, 73, 1))),
                    ),
                    TextFormField(
                      controller: userCedulaController,
                      decoration: InputDecoration(
                          labelText: 'Cédula',
                          labelStyle: GoogleFonts.poppins(
                              color: const Color.fromRGBO(17, 48, 73, 1))),
                    ),
                    TextFormField(
                      controller: userNumeroController,
                      decoration: InputDecoration(
                          labelText: 'Número de Celular',
                          labelStyle: GoogleFonts.poppins(
                              color: const Color.fromRGBO(17, 48, 73, 1))),
                    ),
                  ],
                ),
              ],
              if (widget.paymentMethod == 'Zelle') ...[
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('config')
                      .doc('tasa')
                      .snapshots(),
                  builder: (context, snapshot) {
                    double tasa = 67.0;
                    if (snapshot.hasData && snapshot.data!.exists) {
                      tasa = snapshot.data!.get('valor') ?? 67.0;
                    }
                    final amountInBolivares = widget.totalPrice * tasa;
                    return infoCard(
                      children: [
                        Text(
                          'Precio:',
                          style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: const Color.fromRGBO(17, 48, 73, 1)),
                        ),
                        Text(
                          'En euros: €${widget.totalPrice.toStringAsFixed(2)}',
                          style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: const Color.fromRGBO(17, 48, 73, 1)),
                        ),
                        Text(
                          'En bolívares: Bs ${amountInBolivares.toStringAsFixed(2)}',
                          style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: const Color.fromRGBO(17, 48, 73, 1)),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Datos de Zelle:',
                          style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: const Color.fromRGBO(17, 48, 73, 1)),
                        ),
                        Text('Correo: $emailproveedor',
                            style: GoogleFonts.poppins(
                                fontSize: 16,
                                color: const Color.fromRGBO(17, 48, 73, 1))),
                        Text('Beneficiario: ${beneficiaryController.text}',
                            style: GoogleFonts.poppins(
                                fontSize: 16,
                                color: const Color.fromRGBO(17, 48, 73, 1))),
                      ],
                    );
                  },
                ),
              ],
              if (widget.paymentMethod == 'Zelle') ...[
                const SizedBox(height: 20),
                Center(
                  child: Text(
                    'Reporta tu pago',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color.fromRGBO(17, 48, 73, 1),
                    ),
                  ),
                ),
                infoCard(
                  children: [
                    Text(
                      'Ingresa el nombre y correo de quien realizó la transferencia',
                      style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: const Color.fromRGBO(17, 48, 73, 1)),
                    ),
                    TextFormField(
                      controller: userController,
                      decoration: InputDecoration(
                          labelText: 'Nombre',
                          labelStyle: GoogleFonts.poppins(
                              color: const Color.fromRGBO(17, 48, 73, 1))),
                    ),
                    TextFormField(
                      controller: userEmailController,
                      decoration: InputDecoration(
                          labelText: 'Correo',
                          labelStyle: GoogleFonts.poppins(
                              color: const Color.fromRGBO(17, 48, 73, 1))),
                    ),
                  ],
                ),
              ],
              if (widget.paymentMethod == 'Zinli') ...[
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('config')
                      .doc('tasa')
                      .snapshots(),
                  builder: (context, snapshot) {
                    double tasa = 67.0;
                    if (snapshot.hasData && snapshot.data!.exists) {
                      tasa = snapshot.data!.get('valor') ?? 67.0;
                    }
                    final amountInBolivares = widget.totalPrice * tasa;
                    return infoCard(
                      children: [
                        Text(
                          'Precio:',
                          style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: const Color.fromRGBO(17, 48, 73, 1)),
                        ),
                        Text(
                          'En euros: €${widget.totalPrice.toStringAsFixed(2)}',
                          style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: const Color.fromRGBO(17, 48, 73, 1)),
                        ),
                        Text(
                          'En bolívares: Bs ${amountInBolivares.toStringAsFixed(2)}',
                          style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: const Color.fromRGBO(17, 48, 73, 1)),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Datos de Zinli:',
                          style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: const Color.fromRGBO(17, 48, 73, 1)),
                        ),
                        Text('Correo: $emailproveedor',
                            style: GoogleFonts.poppins(
                                fontSize: 16,
                                color: const Color.fromRGBO(17, 48, 73, 1))),
                        Text('Beneficiario: ${beneficiaryController.text}',
                            style: GoogleFonts.poppins(
                                fontSize: 16,
                                color: const Color.fromRGBO(17, 48, 73, 1))),
                      ],
                    );
                  },
                ),
              ],
              if (widget.paymentMethod == 'Zinli') ...[
                const SizedBox(height: 20),
                Center(
                  child: Text(
                    'Reporta tu pago',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color.fromRGBO(17, 48, 73, 1),
                    ),
                  ),
                ),
                infoCard(
                  children: [
                    Text(
                      'Ingresa el nombre y correo de quien realizó la transferencia',
                      style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: const Color.fromRGBO(17, 48, 73, 1)),
                    ),
                    TextFormField(
                      controller: userController,
                      decoration: InputDecoration(
                          labelText: 'Nombre',
                          labelStyle: GoogleFonts.poppins(
                              color: const Color.fromRGBO(17, 48, 73, 1))),
                    ),
                    TextFormField(
                      controller: userEmailController,
                      decoration: InputDecoration(
                          labelText: 'Correo',
                          labelStyle: GoogleFonts.poppins(
                              color: const Color.fromRGBO(17, 48, 73, 1))),
                    ),
                  ],
                ),
              ],
              if (widget.paymentMethod == 'Binance') ...[
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('config')
                      .doc('tasa')
                      .snapshots(),
                  builder: (context, snapshot) {
                    double tasa = 67.0;
                    if (snapshot.hasData && snapshot.data!.exists) {
                      tasa = snapshot.data!.get('valor') ?? 67.0;
                    }
                    final amountInBolivares = widget.totalPrice * tasa;
                    return infoCard(
                      children: [
                        Text(
                          'Precio:',
                          style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: const Color.fromRGBO(17, 48, 73, 1)),
                        ),
                        Text(
                          'En euros: €${widget.totalPrice.toStringAsFixed(2)}',
                          style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: const Color.fromRGBO(17, 48, 73, 1)),
                        ),
                        Text(
                          'En bolívares: Bs ${amountInBolivares.toStringAsFixed(2)}',
                          style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: const Color.fromRGBO(17, 48, 73, 1)),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Datos de Binance:',
                          style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: const Color.fromRGBO(17, 48, 73, 1)),
                        ),
                        Text('Correo: $emailproveedor',
                            style: GoogleFonts.poppins(
                                fontSize: 16,
                                color: const Color.fromRGBO(17, 48, 73, 1))),
                        Text('Beneficiario: ${beneficiaryController.text}',
                            style: GoogleFonts.poppins(
                                fontSize: 16,
                                color: const Color.fromRGBO(17, 48, 73, 1))),
                      ],
                    );
                  },
                ),
              ],
              if (widget.paymentMethod == 'Binance') ...[
                const SizedBox(height: 20),
                Center(
                  child: Text(
                    'Reporta tu pago',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color.fromRGBO(17, 48, 73, 1),
                    ),
                  ),
                ),
                infoCard(
                  children: [
                    Text(
                      'Ingresa el nombre y correo de quien realizó la transferencia',
                      style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: const Color.fromRGBO(17, 48, 73, 1)),
                    ),
                    TextFormField(
                      controller: userController,
                      decoration: InputDecoration(
                          labelText: 'Nombre',
                          labelStyle: GoogleFonts.poppins(
                              color: const Color.fromRGBO(17, 48, 73, 1))),
                    ),
                    TextFormField(
                      controller: userEmailController,
                      decoration: InputDecoration(
                          labelText: 'Correo',
                          labelStyle: GoogleFonts.poppins(
                              color: const Color.fromRGBO(17, 48, 73, 1))),
                    ),
                  ],
                ),
              ],
              if (widget.paymentMethod == 'Efectivo') ...[
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('config')
                      .doc('tasa')
                      .snapshots(),
                  builder: (context, snapshot) {
                    double tasa = 67.0;
                    if (snapshot.hasData && snapshot.data!.exists) {
                      tasa = snapshot.data!.get('valor') ?? 67.0;
                    }
                    final amountInBolivares = widget.totalPrice * tasa;
                    return infoCard(
                      children: [
                        Text(
                          'Precio:',
                          style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: const Color.fromRGBO(17, 48, 73, 1)),
                        ),
                        Text(
                          'En euros: €${widget.totalPrice.toStringAsFixed(2)}',
                          style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: const Color.fromRGBO(17, 48, 73, 1)),
                        ),
                        Text(
                          'En bolívares: Bs ${amountInBolivares.toStringAsFixed(2)}',
                          style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: const Color.fromRGBO(17, 48, 73, 1)),
                        ),
                        const SizedBox(height: 8),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
                Center(
                  child: Text(
                    'Identifícate',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color.fromRGBO(17, 48, 73, 1),
                    ),
                  ),
                ),
                infoCard(
                  children: [
                    Text(
                      'Ingresa la cédula de la persona que pagará en efectivo y completa la reserva',
                      style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: const Color.fromRGBO(17, 48, 73, 1)),
                    ),
                    TextFormField(
                      controller: idController,
                      decoration: InputDecoration(
                          labelText: 'Cédula',
                          labelStyle: GoogleFonts.poppins(
                              color: const Color.fromRGBO(17, 48, 73, 1))),
                    ),
                  ],
                ),
              ],
              if (widget.paymentMethod == 'Gratis') ...[
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('config')
                      .doc('tasa')
                      .snapshots(),
                  builder: (context, snapshot) {
                    double tasa = 67.0;
                    if (snapshot.hasData && snapshot.data!.exists) {
                      tasa = snapshot.data!.get('valor') ?? 67.0;
                    }
                    final amountInBolivares = widget.totalPrice * tasa;
                    return infoCard(
                      children: [
                        Text(
                          'Precio:',
                          style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: const Color.fromRGBO(17, 48, 73, 1)),
                        ),
                        Text(
                          'En euros: €${widget.totalPrice.toStringAsFixed(2)}',
                          style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: const Color.fromRGBO(17, 48, 73, 1)),
                        ),
                        Text(
                          'En bolívares: Bs ${amountInBolivares.toStringAsFixed(2)}',
                          style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: const Color.fromRGBO(17, 48, 73, 1)),
                        ),
                        const SizedBox(height: 8),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
                Center(
                  child: Text(
                    'Identifícate',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color.fromRGBO(17, 48, 73, 1),
                    ),
                  ),
                ),
                infoCard(
                  children: [
                    Text(
                      'Ingresa tu cédula y completa la reserva',
                      style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: const Color.fromRGBO(17, 48, 73, 1)),
                    ),
                    TextFormField(
                      controller: idController,
                      decoration: InputDecoration(
                          labelText: 'Cédula',
                          labelStyle: GoogleFonts.poppins(
                              color: const Color.fromRGBO(17, 48, 73, 1))),
                    ),
                  ],
                ),
              ],
              if (widget.paymentMethod != 'Efectivo' &&
                  widget.paymentMethod != 'Gratis' &&
                  widget.paymentMethod != 'Pago móvil' &&
                  widget.paymentMethod != 'Zelle' &&
                  widget.paymentMethod != 'Zinli' &&
                  widget.paymentMethod != 'Binance') ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: transactionCodeController,
                  decoration: InputDecoration(
                      labelText: 'Código de Transacción',
                      labelStyle: GoogleFonts.poppins(
                          color: const Color.fromRGBO(17, 48, 73, 1))),
                ),
                TextFormField(
                  controller: receiptController,
                  decoration: InputDecoration(
                      labelText: 'Recibo',
                      labelStyle: GoogleFonts.poppins(
                          color: const Color.fromRGBO(17, 48, 73, 1))),
                ),
              ],
              const SizedBox(height: 16),
              const SizedBox(height: 16),
              Center(
                child: ElevatedButton(
                  onPressed: _isProcessing
                      ? null
                      : () async {
                          // 1. Verifica si el usuario tiene celular en Firestore
                          final userDoc = await FirebaseFirestore.instance
                              .collection('usuarios')
                              .doc(widget.userId)
                              .get();

                          String? celular = userDoc.data()?['celular'];
                          if (celular == null || celular.trim().isEmpty) {
                            final phone = await _showPhoneDialog();
                            if (phone == null) return; // Cancelado

                            // Guarda el número en Firestore
                            await FirebaseFirestore.instance
                                .collection('usuarios')
                                .doc(widget.userId)
                                .update({'celular': phone});
                          }

                          // Validaciones originales
                          if (widget.paymentMethod == 'Efectivo' &&
                              idController.text.isEmpty) {
                            if (mounted) {
                              _showErrorDialog(this.context,
                                  'Por favor, ingrese la cédula de la persona que pagará en efectivo.');
                            }
                          } else if (widget.paymentMethod == 'Gratis' &&
                              idController.text.isEmpty) {
                            if (mounted) {
                              _showErrorDialog(this.context,
                                  'Por favor, ingrese tu cédula.');
                            }
                          } else if (widget.paymentMethod == 'Pago móvil' &&
                              (transactionCodeController.text.isEmpty ||
                                  idController.text.isEmpty ||
                                  numberController.text.isEmpty)) {
                            if (mounted) {
                              _showErrorDialog(this.context,
                                  'Por favor, ingrese la referencia de la transacción, la cédula y el número de celular de quien realizó el pago móvil.');
                            }
                          } else if (widget.paymentMethod == 'Zelle' &&
                              (userController.text.isEmpty ||
                                  emailController.text.isEmpty)) {
                            if (mounted) {
                              _showErrorDialog(this.context,
                                  'Por favor, ingrese el nombre y el correo de quien hizo la transferencia.');
                            }
                          } else if (widget.paymentMethod == 'Zinli' &&
                              (userController.text.isEmpty ||
                                  emailController.text.isEmpty)) {
                            if (mounted) {
                              _showErrorDialog(this.context,
                                  'Por favor, ingrese el nombre y el correo de quien hizo la transferencia.');
                            }
                          } else if (widget.paymentMethod == 'Binance' &&
                              (userController.text.isEmpty ||
                                  emailController.text.isEmpty)) {
                            if (mounted) {
                              _showErrorDialog(this.context,
                                  'Por favor, ingrese el nombre y el correo de quien hizo la transferencia.');
                            }
                          } else {
                            if (mounted) {
                              _completeReservation(this.context);
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromRGBO(17, 48, 73, 1),
                  ),
                  child: _isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.0,
                          ),
                        )
                      : Text(
                          'Completar reserva',
                          style: GoogleFonts.poppins(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
      backgroundColor: const Color.fromARGB(255, 243, 247, 254),
    );
  }
  // ...existing code...

  bool isValidPhone(String phone) {
    return RegExp(r'^\d{10,15}$').hasMatch(phone);
  }

  Future<String?> _showPhoneDialog() async {
    final controller = TextEditingController();
    String? errorText;

    return await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            backgroundColor: Colors.white,
            title: const Center(
              child: Text(
                'Ingresa tu número de celular',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.bold,
                  color: Color.fromRGBO(17, 48, 73, 1),
                ),
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Este número será el que usará el proveedor para contactarte después que reserves, asegúrate de que sea un número real',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      color: Color.fromRGBO(17, 48, 73, 1)),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    hintText: 'Número de celular',
                    hintStyle: const TextStyle(
                        fontFamily: 'Poppins',
                        color: Color.fromRGBO(17, 48, 73, 1)),
                    errorText: errorText,
                  ),
                ),
              ],
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              TextButton(
                child: const Text('Cancelar',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        color: Color.fromRGBO(17, 48, 73, 1))),
                onPressed: () => Navigator.of(context).pop(null),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromRGBO(17, 48, 73, 1),
                ),
                child: const Text('Aceptar',
                    style:
                        TextStyle(fontFamily: 'Poppins', color: Colors.white)),
                onPressed: () {
                  final phone = controller.text.trim();
                  if (!isValidPhone(phone)) {
                    setState(() => errorText = 'Número inválido');
                  } else {
                    Navigator.of(context).pop(phone);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
