import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import 'package:google_fonts/google_fonts.dart';
import 'booking_provider.dart';
import 'bookings_screen.dart';
import 'dart:convert';
import 'package:googleapis_auth/auth_io.dart';
import 'package:flutter/services.dart';

class PaymentDetailsScreen extends StatefulWidget {
  final String userId;
  final String paymentMethod;
  final String planName;
  final String planLocation;
  final String supplier;
  final double totalPrice;
  final List<Map<String, dynamic>> packagesData;

  const PaymentDetailsScreen({
    super.key,
    required this.userId,
    required this.paymentMethod,
    required this.planName,
    required this.planLocation,
    required this.totalPrice,
    required this.supplier,
    required this.packagesData,
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
    if (['Pago móvil', 'Zelle', 'Zinli', 'Binance']
        .contains(widget.paymentMethod)) {
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
      final method = widget.paymentMethod;
      final paymentData =
          pagos.firstWhere((p) => p['metodo'] == method, orElse: () => null);

      if (paymentData != null) {
        setState(() {
          if (method == 'Pago móvil') {
            bankController.text = paymentData['banco'] ?? '';
            idController.text = paymentData['cedula'] ?? '';
            numberController.text = paymentData['numero'] ?? '';
          } else if (['Zelle', 'Zinli', 'Binance'].contains(method)) {
            emailController.text = paymentData['correo'] ?? '';
            beneficiaryController.text = paymentData['nombre'] ?? '';
          }
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

  void _completeReservation(BuildContext context, String userCelular) async {
    setState(() => _isProcessing = true);

    try {
      final documentId =
          FirebaseFirestore.instance.collection('reservas').doc().id;
      final code = _generateRandomCode(10);
      final userSnapshot = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(widget.userId)
          .get();

      String userName = userSnapshot.data()?['name'] ?? '';
      String userEmail = userSnapshot.data()?['email'] ?? '';

      final configSnapshot = await FirebaseFirestore.instance
          .collection('config')
          .doc('tasa')
          .get();
      double tasa = configSnapshot.data()?['valor'] ?? 67.0;
      double totalPriceBs = widget.totalPrice * tasa;

      // Se pasan los datos del paquete tal como vienen, ya que fueron procesados en la pantalla anterior.
      // ignore: use_build_context_synchronously
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
        correo: ['Zelle', 'Zinli', 'Binance'].contains(widget.paymentMethod)
            ? userEmailController.text
            : emailController.text,
        packagesData: widget.packagesData,
      );

      // RESTAURADO: Se vuelve a llamar la función de notificaciones.
      await _sendNewBookingNotifications();

      if (!mounted) return;
      // ignore: use_build_context_synchronously
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
            builder: (context) => BookingsScreen(userId: widget.userId)),
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      if (mounted) {
        _showErrorDialog(
            // ignore: use_build_context_synchronously
            context,
            'Ocurrió un error al completar la reserva: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  // RESTAURADO Y RENOMBRADO: Para mayor claridad
  Future<void> _sendNewBookingNotifications() async {
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

      final supplierDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(widget.supplier)
          .get();
      final adminDocs = await FirebaseFirestore.instance
          .collection('usuarios')
          .where('isAdmin', isEqualTo: true)
          .get();
      final Set<String> tokens = {};

      if (supplierDoc.exists && supplierDoc.data()?['deviceToken'] != null) {
        tokens.add(supplierDoc.data()!['deviceToken']);
      }
      for (var doc in adminDocs.docs) {
        if (doc.data()['deviceToken'] != null) {
          tokens.add(doc.data()['deviceToken']);
        }
      }

      for (final token in tokens) {
        final notification = {
          'message': {
            'token': token,
            'notification': {
              'title': 'Nueva Reservación',
              'body': '¡Se ha registrado una nueva reserva para verificar!'
            },
            'data': {
              'click_action': 'FLUTTER_NOTIFICATION_CLICK',
              'screen': 'verify'
            },
          },
        };
        await client.post(Uri.parse(fcmUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(notification));
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
          content: Text(message,
              style: const TextStyle(
                  color: Color.fromRGBO(17, 48, 73, 1), fontFamily: 'Poppins')),
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
              offset: const Offset(0, 4))
        ],
        border:
            Border.all(color: const Color.fromRGBO(17, 48, 73, 0.08), width: 1),
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 243, 247, 254),
        iconTheme: const IconThemeData(color: Color.fromRGBO(17, 48, 73, 1)),
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
                  tasa = (snapshot.data!.data()
                          as Map<String, dynamic>)['valor'] ??
                      67.0;
                }
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8.0, vertical: 4.0),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8.0)),
                  child: Text('Tasa: ${tasa.toStringAsFixed(2)} Bs/€',
                      style: GoogleFonts.poppins(
                          color: const Color.fromRGBO(17, 48, 73, 1),
                          fontWeight: FontWeight.bold)),
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
              if ([
                'Pago móvil',
                'Zelle',
                'Zinli',
                'Binance',
                'Efectivo',
                'Gratis'
              ].contains(widget.paymentMethod))
                _buildPaymentUI(),
              const SizedBox(height: 16),
              Center(
                child: ElevatedButton(
                  onPressed: _isProcessing
                      ? null
                      : () async {
                          setState(() => _isProcessing = true);
                          try {
                            final userDoc = await FirebaseFirestore.instance
                                .collection('usuarios')
                                .doc(widget.userId)
                                .get();
                            String? celular = userDoc.data()?['celular'];
                            if (celular == null || celular.trim().isEmpty) {
                              final phone = await _showPhoneDialog();
                              if (phone == null) {
                                setState(() => _isProcessing = false);
                                return;
                              }
                              await FirebaseFirestore.instance
                                  .collection('usuarios')
                                  .doc(widget.userId)
                                  .update({'celular': phone});
                              celular = phone;
                            }

                            bool isPaymentValid = true;
                            String errorMessage = '';
                            if (widget.paymentMethod == 'Efectivo' &&
                                idController.text.isEmpty) {
                              isPaymentValid = false;
                              errorMessage =
                                  'Por favor, ingrese la cédula de la persona que pagará en efectivo.';
                            } else if (widget.paymentMethod == 'Gratis' &&
                                idController.text.isEmpty) {
                              isPaymentValid = false;
                              errorMessage = 'Por favor, ingrese tu cédula.';
                            } else if (widget.paymentMethod == 'Pago móvil' &&
                                (transactionCodeController.text.isEmpty ||
                                    userCedulaController.text.isEmpty ||
                                    userNumeroController.text.isEmpty)) {
                              isPaymentValid = false;
                              errorMessage =
                                  'Por favor, ingrese la referencia y los datos del pagador.';
                            } else if ((['Zelle', 'Zinli', 'Binance']
                                    .contains(widget.paymentMethod)) &&
                                (userController.text.isEmpty ||
                                    userEmailController.text.isEmpty)) {
                              isPaymentValid = false;
                              errorMessage =
                                  'Por favor, ingrese el nombre y el correo de quien hizo la transferencia.';
                            }

                            if (!isPaymentValid) {
                              // ignore: use_build_context_synchronously
                              _showErrorDialog(context, errorMessage);
                              setState(() => _isProcessing = false);
                              return;
                            }
                            // ignore: use_build_context_synchronously
                            _completeReservation(context, celular);
                          } catch (e) {
                            _showErrorDialog(
                                // ignore: use_build_context_synchronously
                                context,
                                "Ocurrió un error inesperado.");
                            if (mounted) setState(() => _isProcessing = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromRGBO(17, 48, 73, 1),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 50, vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24)),
                  ),
                  child: _isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.0))
                      : Text('Completar reserva',
                          style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
      backgroundColor: const Color.fromARGB(255, 243, 247, 254),
    );
  }

  Widget _buildPaymentUI() {
    return Column(
      children: [
        StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('config')
                .doc('tasa')
                .snapshots(),
            builder: (context, snapshot) {
              double tasa = 67.0;
              if (snapshot.hasData && snapshot.data!.exists) {
                tasa =
                    (snapshot.data!.data() as Map<String, dynamic>)['valor'] ??
                        67.0;
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text(
                      widget.paymentMethod,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: const Color.fromRGBO(17, 48, 73, 1),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  infoCard(children: [
                    Text('Precio:',
                        style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: const Color.fromRGBO(17, 48, 73, 1))),
                    Text('En euros: €${widget.totalPrice.toStringAsFixed(2)}',
                        style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: const Color.fromRGBO(17, 48, 73, 1))),
                    Text(
                        'En bolívares: Bs ${(widget.totalPrice * tasa).toStringAsFixed(2)}',
                        style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: const Color.fromRGBO(17, 48, 73, 1))),
                  ]),
                ],
              );
            }),
        const SizedBox(height: 8),
        if (widget.paymentMethod == 'Efectivo' ||
            widget.paymentMethod == 'Gratis') ...[
          Center(
              child: Text('Identifícate',
                  style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color.fromRGBO(17, 48, 73, 1)))),
          infoCard(
            children: [
              Text(
                  widget.paymentMethod == 'Efectivo'
                      ? 'Ingresa la cédula de la persona que pagará en efectivo.'
                      : 'Ingresa tu cédula para completar la reserva.',
                  style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: const Color.fromRGBO(17, 48, 73, 1))),
              TextFormField(
                  controller: idController,
                  decoration: const InputDecoration(labelText: 'Cédula')),
            ],
          ),
        ] else ...[
          infoCard(children: _getProviderPaymentDetails()),
          const SizedBox(height: 20),
          Center(
              child: Text('Reporta tu pago',
                  style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color.fromRGBO(17, 48, 73, 1)))),
          infoCard(children: _getUserPaymentReportFields()),
        ]
      ],
    );
  }

  List<Widget> _getProviderPaymentDetails() {
    if (widget.paymentMethod == 'Pago móvil') {
      return [
        const Text('Datos para el pago móvil:',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                fontFamily: 'Poppins',
                color: Color.fromRGBO(17, 48, 73, 1))),
        Text('Banco: ${bankController.text}',
            style: TextStyle(
                fontSize: 16,
                fontFamily: 'Poppins',
                color: Color.fromRGBO(17, 48, 73, 1))),
        Text('Documento de identificación: ${idController.text}',
            style: TextStyle(
                fontSize: 16,
                fontFamily: 'Poppins',
                color: Color.fromRGBO(17, 48, 73, 1))),
        Text('Número de celular: ${numberController.text}',
            style: TextStyle(
                fontSize: 16,
                fontFamily: 'Poppins',
                color: Color.fromRGBO(17, 48, 73, 1))),
      ];
    } else if (['Zelle', 'Zinli', 'Binance'].contains(widget.paymentMethod)) {
      return [
        Text('Datos de ${widget.paymentMethod}:',
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                fontFamily: 'Poppins',
                color: Color.fromRGBO(17, 48, 73, 1))),
        Text('Correo: ${emailController.text}',
            style: TextStyle(
                fontSize: 16,
                fontFamily: 'Poppins',
                color: Color.fromRGBO(17, 48, 73, 1))),
        Text('Beneficiario: ${beneficiaryController.text}',
            style: TextStyle(
                fontSize: 16,
                fontFamily: 'Poppins',
                color: Color.fromRGBO(17, 48, 73, 1))),
      ];
    }
    return [];
  }

  List<Widget> _getUserPaymentReportFields() {
    if (widget.paymentMethod == 'Pago móvil') {
      return [
        const Text(
            'Ingresa la referencia de la transacción, la cédula y número de celular de quien realizó el pago móvil',
            style: TextStyle(
                fontSize: 16,
                fontFamily: 'Poppins',
                color: Color.fromRGBO(17, 48, 73, 1))),
        TextFormField(
            controller: transactionCodeController,
            decoration: const InputDecoration(
                labelText: 'Código de la transacción',
                hintStyle: TextStyle(
                    fontFamily: 'Poppins',
                    color: Color.fromRGBO(17, 48, 73, 1)))),
        TextFormField(
            controller: userCedulaController,
            decoration: const InputDecoration(
                labelText: 'Cédula',
                hintStyle: TextStyle(
                    fontFamily: 'Poppins',
                    color: Color.fromRGBO(17, 48, 73, 1)))),
        TextFormField(
            controller: userNumeroController,
            decoration: const InputDecoration(
                labelText: 'Número de celular',
                hintStyle: TextStyle(
                    fontFamily: 'Poppins',
                    color: Color.fromRGBO(17, 48, 73, 1)))),
      ];
    } else if (['Zelle', 'Zinli', 'Binance'].contains(widget.paymentMethod)) {
      return [
        const Text(
            'Ingresa el nombre y correo de quien realizó la transferencia',
            style: TextStyle(
                fontSize: 16,
                fontFamily: 'Poppins',
                color: Color.fromRGBO(17, 48, 73, 1))),
        TextFormField(
            controller: userController,
            decoration: const InputDecoration(
                labelText: 'Nombre',
                hintStyle: TextStyle(
                    fontFamily: 'Poppins',
                    color: Color.fromRGBO(17, 48, 73, 1)))),
        TextFormField(
            controller: userEmailController,
            decoration: const InputDecoration(
                labelText: 'Correo',
                hintStyle: TextStyle(
                    fontFamily: 'Poppins',
                    color: Color.fromRGBO(17, 48, 73, 1)))),
      ];
    }
    return [];
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
                child: Text('Ingresa tu número de celular',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.bold,
                        color: Color.fromRGBO(17, 48, 73, 1)))),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                    'Este número será el que usará el proveedor para contactarte después que reserves, asegúrate de que sea un número real',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        color: Color.fromRGBO(17, 48, 73, 1))),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                      hintText: 'Número de celular',
                      hintStyle: const TextStyle(
                          fontFamily: 'Poppins',
                          color: Color.fromRGBO(17, 48, 73, 1)),
                      errorText: errorText),
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
                  onPressed: () => Navigator.of(context).pop(null)),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromRGBO(17, 48, 73, 1)),
                child: const Text('Aceptar',
                    style:
                        TextStyle(fontFamily: 'Poppins', color: Colors.white)),
                onPressed: () {
                  final phone = controller.text.trim();
                  if (!RegExp(r'^\d{10,15}$').hasMatch(phone)) {
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
