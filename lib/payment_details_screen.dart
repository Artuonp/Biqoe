import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Para rootBundle
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
// IMPORTANTE: Librería para autenticación FCM (Notificaciones al proveedor)
import 'package:googleapis_auth/auth_io.dart';
// Librería HTTP para enviar el correo al usuario (Tu Script de Google)
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart'; // Para fechas en el email

import 'booking_provider.dart';

const Color kPrimaryColor = Color.fromRGBO(17, 48, 73, 1);
const Color kBackgroundColor = Color(0xFFF8F9FD);

class PaymentDetailsScreen extends StatefulWidget {
  final String userId;
  final String paymentMethod;
  final String planName;
  final String planLocation;
  final String supplier;
  final double totalPrice;
  final List<Map<String, dynamic>> packagesData;
  final String? destinationId;

  const PaymentDetailsScreen({
    super.key,
    required this.userId,
    required this.paymentMethod,
    required this.planName,
    required this.planLocation,
    required this.totalPrice,
    required this.supplier,
    required this.packagesData,
    this.destinationId,
  });

  @override
  PaymentDetailsScreenState createState() => PaymentDetailsScreenState();
}

class PaymentDetailsScreenState extends State<PaymentDetailsScreen> {
  // --- CONTROLADORES DE PAGO ---
  final _transactionCtrl = TextEditingController();
  final _payerIdCtrl = TextEditingController();
  final _payerPhoneCtrl = TextEditingController();
  final _payerNameCtrl = TextEditingController();
  final _payerEmailCtrl = TextEditingController();

  // --- DATOS DEL PROVEEDOR ---
  Map<String, String> _providerBankData = {};
  bool _isLoadingBankData = true;

  // --- CONTROLADORES DE INVITADO ---
  final _guestNameCtrl = TextEditingController();
  final _guestEmailCtrl = TextEditingController();
  final _guestPhoneCtrl = TextEditingController();

  // --- LÓGICA DE CUOTAS ---
  bool _payInInstallments = false;
  bool _canPayInInstallments = false;
  List<double> _installmentConfig = [];

  bool _isProcessing = false;
  bool _isGuest = false;

  @override
  void initState() {
    super.initState();
    _checkIfGuest();
    _loadData();
  }

  void _checkIfGuest() {
    final user = FirebaseAuth.instance.currentUser;
    setState(() => _isGuest = user?.isAnonymous ?? false);
  }

  Future<void> _loadData() async {
    await _fetchInstallmentConfig();
    await _loadProviderPaymentData();
  }

  Future<void> _fetchInstallmentConfig() async {
    try {
      QuerySnapshot query;
      if (widget.destinationId != null && widget.destinationId!.isNotEmpty) {
        query = await FirebaseFirestore.instance
            .collection('destinos')
            .where(FieldPath.documentId, isEqualTo: widget.destinationId)
            .get();
      } else {
        query = await FirebaseFirestore.instance
            .collection('destinos')
            .where('nombre', isEqualTo: widget.planName)
            .limit(1)
            .get();
      }

      if (query.docs.isNotEmpty) {
        final data = query.docs.first.data() as Map<String, dynamic>;
        final paquetes = data['paquetes'] as List? ?? [];

        for (var p in paquetes) {
          if (p['tieneCuotas'] == true) {
            if (mounted) {
              setState(() {
                _canPayInInstallments = true;
                if (p['configuracionCuotas'] != null) {
                  _installmentConfig = List<double>.from(
                      p['configuracionCuotas'].map((e) => e.toDouble()));
                } else {
                  _installmentConfig = [50.0, 50.0];
                }
              });
            }
            break;
          }
        }
      }
    } catch (e) {
      debugPrint("Error buscando cuotas: $e");
    }
  }

  Future<void> _loadProviderPaymentData() async {
    try {
      QuerySnapshot query;
      if (widget.destinationId != null && widget.destinationId!.isNotEmpty) {
        query = await FirebaseFirestore.instance
            .collection('destinos')
            .where(FieldPath.documentId, isEqualTo: widget.destinationId)
            .get();
      } else {
        query = await FirebaseFirestore.instance
            .collection('destinos')
            .where('nombre', isEqualTo: widget.planName)
            .limit(1)
            .get();
      }

      if (query.docs.isNotEmpty) {
        final data = query.docs.first.data() as Map<String, dynamic>;
        List<dynamic> methods = [];
        if (data.containsKey('metodosPago')) {
          methods = data['metodosPago'];
        } else if (data.containsKey('pagos')) {
          methods = data['pagos'];
        }

        final selected = methods.firstWhere(
            (m) => m['metodo'].toString() == widget.paymentMethod,
            orElse: () => null);

        if (selected != null && mounted) {
          setState(() {
            _providerBankData = Map<String, String>.from(
                selected.map((k, v) => MapEntry(k.toString(), v.toString())));
            _isLoadingBankData = false;
          });
        } else {
          if (mounted) setState(() => _isLoadingBankData = false);
        }
      }
    } catch (e) {
      debugPrint("Error loading bank data: $e");
      if (mounted) setState(() => _isLoadingBankData = false);
    }
  }

  String _generateRandomCode(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random();
    return String.fromCharCodes(Iterable.generate(
        length, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  }

  // --- 1. NOTIFICACIÓN AL PROVEEDOR (HTTP V1 - FCM) ---
  Future<void> _sendNotificationToSupplier(
      String supplierId, String planName, String clientName) async {
    debugPrint("🔔 [NOTIFICACIÓN] Iniciando envío al proveedor...");
    try {
      final supplierDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(supplierId)
          .get();

      if (!supplierDoc.exists) {
        debugPrint("❌ [NOTIFICACIÓN] Proveedor no encontrado.");
        return;
      }

      final data = supplierDoc.data();
      final String? token = data?['fcmToken'] ?? data?['deviceToken'];

      if (token == null || token.isEmpty) {
        debugPrint("❌ [NOTIFICACIÓN] Proveedor sin token.");
        return;
      }

      const String serviceAccountPath =
          'assets/biqoe-app-firebase-adminsdk-fbsvc-067c9b5471.json';
      const List<String> scopes = [
        'https://www.googleapis.com/auth/firebase.messaging'
      ];

      final serviceAccount = ServiceAccountCredentials.fromJson(
          await rootBundle.loadString(serviceAccountPath));
      final client = await clientViaServiceAccount(serviceAccount, scopes);

      final notificationPayload = {
        'message': {
          'token': token,
          'notification': {
            'title': 'Nueva Reserva 📅',
            'body': '$clientName ha reservado $planName. ¡Verifícalo!',
          },
          'data': {
            'click_action': 'FLUTTER_NOTIFICATION_CLICK',
            'screen': 'dashboard',
            'type': 'new_reservation',
            'planName': planName,
          },
          'android': {
            'priority': 'high',
            'notification': {
              'sound': 'default',
              'click_action': 'FLUTTER_NOTIFICATION_CLICK',
            }
          },
          'apns': {
            'payload': {
              'aps': {'sound': 'default', 'badge': 1}
            }
          }
        }
      };

      const String projectId = 'biqoe-app';
      final url = Uri.parse(
          'https://fcm.googleapis.com/v1/projects/$projectId/messages:send');

      debugPrint("🚀 [NOTIFICACIÓN] Enviando a FCM...");
      final response = await client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(notificationPayload),
      );

      if (response.statusCode == 200) {
        debugPrint("✅ [NOTIFICACIÓN] Enviada con éxito.");
      } else {
        debugPrint("❌ [NOTIFICACIÓN] Error: ${response.body}");
      }
      client.close();
    } catch (e) {
      debugPrint("❌ [NOTIFICACIÓN] Excepción: $e");
    }
  }

  // --- 2. CORREO AL USUARIO (GOOGLE APPS SCRIPT) ---
  Future<void> _sendUserEmail({
    required String contactEmail,
    required String contactName,
    required String planName,
    required String code,
    required double paidAmount,
    required double totalAmount,
    required String paymentMethod,
  }) async {
    debugPrint("📧 [EMAIL] Iniciando envío de correo al cliente...");

    // 1. Determinar destinatarios
    List<String> recipients = [];
    if (contactEmail.isNotEmpty) recipients.add(contactEmail);
    // Si usó Zelle/Binance y puso un correo diferente, enviamos ahí también
    if (_payerEmailCtrl.text.isNotEmpty) recipients.add(_payerEmailCtrl.text);

    recipients = recipients.toSet().toList(); // Quitar duplicados

    if (recipients.isEmpty) {
      debugPrint("⚠ [EMAIL] No hay correos destinatarios. Omitiendo.");
      return;
    }
    debugPrint("   > Destinatarios: $recipients");

    // 2. URL DE TU SCRIPT DE GOOGLE
    const String emailServiceUrl =
        'https://script.google.com/macros/s/AKfycbz5Wy1Qtn_uUT1sgL78MYOWvI4M3TJA1fml0rTd7qtjQBAB2DI7MXMP74P24aFN7bT6Jg/exec';

    // 3. Construir Cuerpo HTML con QR
    final String dateStr = DateFormat('dd/MM/yyyy').format(DateTime.now());

    // API para generar QR visualmente en el correo
    final String qrUrl =
        "https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=$code&color=113049";

    final String htmlContent = """
      <div style="font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif; color: #333; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #e0e0e0; border-radius: 8px; background-color: #ffffff;">
        
        <div style="text-align: center; padding-bottom: 20px; border-bottom: 1px solid #eee;">
          <h2 style="color: #113049; margin: 0;">¡Solicitud recibida!</h2>
          <p style="color: #666; margin-top: 5px;">Tu reserva está en proceso de verificación</p>
        </div>

        <div style="padding: 20px 0;">
          <p>Hola <strong>$contactName</strong>,</p>
          <p>Gracias por reservar <strong>$planName</strong>.</p>
          
          <div style="background-color: #f0f7ff; padding: 20px; border-radius: 8px; text-align: center; margin: 25px 0; border: 1px dashed #113049;">
            <p style="margin: 0 0 10px 0; font-size: 12px; color: #555; text-transform: uppercase; letter-spacing: 1px;">Código de reserva</p>
            <h1 style="margin: 0 0 15px 0; font-size: 32px; letter-spacing: 5px; color: #113049;">$code</h1>
            
            <img src="$qrUrl" alt="Código QR de Reserva" width="150" height="150" style="display: block; margin: 0 auto; border: 4px solid white; border-radius: 8px;" />
            <p style="margin: 10px 0 0 0; font-size: 11px; color: #888;">Muestra este código al proveedor cuando asistas</p>
          </div>

          <h3 style="color: #113049; border-bottom: 2px solid #113049; padding-bottom: 5px; display: inline-block;">Detalles del pago</h3>
          <table style="width: 100%; border-collapse: collapse; margin-top: 10px;">
            <tr>
              <td style="padding: 10px 0; border-bottom: 1px solid #eee; color: #666;">Fecha:</td>
              <td style="padding: 10px 0; border-bottom: 1px solid #eee; font-weight: bold; text-align: right;">$dateStr</td>
            </tr>
            <tr>
              <td style="padding: 10px 0; border-bottom: 1px solid #eee; color: #666;">Actividad:</td>
              <td style="padding: 10px 0; border-bottom: 1px solid #eee; font-weight: bold; text-align: right;">$planName</td>
            </tr>
            <tr>
              <td style="padding: 10px 0; border-bottom: 1px solid #eee; color: #666;">Método:</td>
              <td style="padding: 10px 0; border-bottom: 1px solid #eee; font-weight: bold; text-align: right;">$paymentMethod</td>
            </tr>
            <tr>
              <td style="padding: 10px 0; border-bottom: 1px solid #eee; color: #666;">Precio total:</td>
              <td style="padding: 10px 0; border-bottom: 1px solid #eee; font-weight: bold; text-align: right;">\$${totalAmount.toStringAsFixed(2)}</td>
            </tr>
            <tr style="background-color: #f9fff9;">
              <td style="padding: 10px 5px; color: #2e7d32; font-weight: bold;">Abonado hoy:</td>
              <td style="padding: 10px 5px; font-weight: bold; color: #2e7d32; text-align: right; font-size: 16px;">\$${paidAmount.toStringAsFixed(2)}</td>
            </tr>
          </table>
        </div>
        
        <div style="text-align: center; margin-top: 30px; padding-top: 20px; border-top: 1px solid #eee; color: #888; font-size: 12px;">
          <p>Si tienes alguna pregunta, responde a este correo o contacta a soporte.</p>
          <p>&copy; ${DateTime.now().year} Biqoe</p>
        </div>
      </div>
    """;

    // 4. Enviar Solicitud al Script
    try {
      debugPrint("🚀 [EMAIL] Conectando con Google Apps Script...");
      final response = await http.post(
        Uri.parse(emailServiceUrl),
        headers: {'Content-Type': 'application/json'},
        // Seguir las redirecciones es importante con Google Scripts
        body: jsonEncode({
          'to': recipients.join(','),
          'subject': 'Reserva Recibida - $planName ($code)',
          'htmlBody': htmlContent,
          'name': "Biqoe Reservas"
        }),
      );

      // Google Scripts a veces devuelve redirecciones (302) que el cliente HTTP sigue automáticamente,
      // pero si devuelve JSON, será status 200.
      debugPrint("📥 [EMAIL] Respuesta Script: ${response.statusCode}");
      debugPrint("   Cuerpo: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 302) {
        debugPrint("✅ [EMAIL] Correo enviado exitosamente.");
      } else {
        debugPrint("❌ [EMAIL] El script devolvió error: ${response.body}");
      }
    } catch (e) {
      debugPrint("❌ [EMAIL] Excepción de red: $e");
    }
  }

  void _validateAndSubmit() {
    if (_isGuest) {
      if (_guestNameCtrl.text.isEmpty ||
          _guestEmailCtrl.text.isEmpty ||
          _guestPhoneCtrl.text.isEmpty) {
        _showErrorDialog("Por favor completa tus datos de contacto.");
        return;
      }
    }

    if (widget.paymentMethod != 'Efectivo' &&
        widget.paymentMethod != 'Gratis') {
      if (widget.paymentMethod == 'Pago móvil') {
        if (_transactionCtrl.text.isEmpty ||
            _payerIdCtrl.text.isEmpty ||
            _payerPhoneCtrl.text.isEmpty) {
          _showErrorDialog("Completa los datos del pago móvil realizado.");
          return;
        }
      } else {
        if (_payerNameCtrl.text.isEmpty ||
            _payerEmailCtrl.text.isEmpty ||
            _transactionCtrl.text.isEmpty) {
          _showErrorDialog("Completa los datos de la transferencia.");
          return;
        }
      }
    }

    _processReservation();
  }

  Future<void> _processReservation() async {
    setState(() => _isProcessing = true);
    debugPrint(">>> Iniciando _processReservation...");

    final bookingProvider =
        Provider.of<BookingProvider>(context, listen: false);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final userId = user?.uid ?? widget.userId;

      // --- CAMBIO AQUÍ: OBTENER DATOS FRESCOS ---
      String contactName = "";
      String contactEmail = "";
      String contactPhone = "";

      if (_isGuest) {
        contactName = _guestNameCtrl.text.trim();
        contactEmail = _guestEmailCtrl.text.trim();
        contactPhone = _guestPhoneCtrl.text.trim();
      } else {
        // Buscamos los datos actualizados directo en Firestore
        final userDoc = await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(userId)
            .get();

        if (userDoc.exists && userDoc.data() != null) {
          final userData = userDoc.data()!;
          contactName = userData['name'] ?? user?.displayName ?? "Usuario";
          contactEmail = userData['email'] ?? user?.email ?? "";
          contactPhone = userData['celular'] ?? userData['telefono'] ?? "";
        } else {
          // Fallback por si acaso el documento no existe
          contactName = user?.displayName ?? "Usuario";
          contactEmail = user?.email ?? "";
        }
      }
      // ------------------------------------------

      double finalAmount = widget.totalPrice;
      if (_payInInstallments && _installmentConfig.isNotEmpty) {
        finalAmount = widget.totalPrice * (_installmentConfig[0] / 100);
      }

      double tasa = 67.0;
      try {
        final configSnapshot = await FirebaseFirestore.instance
            .collection('config')
            .doc('tasa')
            .get();
        if (configSnapshot.exists) {
          tasa = configSnapshot.data()?['valor'] ?? 67.0;
        }
      } catch (_) {}

      double amountBs = finalAmount * tasa;

      final reservationId =
          FirebaseFirestore.instance.collection('reservas').doc().id;
      final code = _generateRandomCode(8);

      // --- 1. GUARDAR RESERVA ---
      debugPrint("  - Llamando a bookingProvider.addBooking...");
      await bookingProvider.addBooking(
        userId: userId,
        planName: widget.planName,
        name: contactName,
        email: contactEmail,
        celular: contactPhone,
        totalPriceBs: amountBs,
        planLocation: widget.planLocation,
        planPrice: finalAmount,
        totalPlanPrice: widget.totalPrice,
        isInstallment: _payInInstallments,
        installmentsPaid: _payInInstallments ? 1 : 0,
        supplier: widget.supplier,
        paymentMethod: widget.paymentMethod,
        transactionCode: _transactionCtrl.text,
        receipt: '',
        documentId: reservationId,
        code: code,
        cedula: _payerIdCtrl.text.isNotEmpty ? _payerIdCtrl.text : '',
        numero: _payerPhoneCtrl.text.isNotEmpty ? _payerPhoneCtrl.text : '',
        correo: _payerEmailCtrl.text.isNotEmpty ? _payerEmailCtrl.text : '',
        packagesData: widget.packagesData,
        initialPaymentDetails: {
          'amountBs': amountBs,
          'currencyRate': tasa,
          'method': widget.paymentMethod,
          if (widget.paymentMethod == 'Pago móvil') ...{
            'referencia': _transactionCtrl.text,
            'cedula': _payerIdCtrl.text,
            'telefono': _payerPhoneCtrl.text,
          } else if (widget.paymentMethod != 'Efectivo') ...{
            'referencia': _transactionCtrl.text,
            'email_pago': _payerEmailCtrl.text,
            'titular': _payerNameCtrl.text,
          }
        },
      );
      debugPrint("  ✅ Reserva guardada.");

      // --- 2. TAREAS DE FONDO ---

      // Notificación al proveedor (HTTP v1)
      _sendNotificationToSupplier(
          widget.supplier, widget.planName, contactName);

      // Correo al usuario (Google Apps Script)
      _sendUserEmail(
        contactEmail: contactEmail,
        contactName: contactName,
        planName: widget.planName,
        code: code,
        paidAmount: finalAmount,
        totalAmount: widget.totalPrice,
        paymentMethod: widget.paymentMethod,
      );

      if (!mounted) return;

      // EN LUGAR DE IRSE DIRECTO, MOSTRAMOS EL DIÁLOGO
      _showSuccessDialog();
    } catch (e) {
      debugPrint("❌ Error CRÍTICO en _processReservation: $e");
      _showErrorDialog("Error al procesar: $e");
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showErrorDialog(String msg) {
    showDialog(
        context: context,
        builder: (c) => AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                title: const Text("Atención"),
                content: Text(msg),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c),
                      child: const Text("OK"))
                ]));
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mark_email_read_rounded,
                    size: 40, color: Colors.green),
              ),
              const SizedBox(height: 20),
              Text(
                "¡Reserva enviada!",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: kPrimaryColor,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "Hemos enviado un correo con todos los detalles y tu código QR.",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
              ),
              const SizedBox(height: 12), // Un poco más de espacio aquí
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        size: 18, color: Colors.orange),
                    const SizedBox(width: 10),
                    // CORRECCIÓN: Flexible para evitar overflow
                    Flexible(
                      child: Text(
                        "Si no lo ves, revisa tu carpeta de SPAM",
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.orange[800],
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.go('/bookings');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    "Entendido",
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: Text("Detalles del pago",
            style: GoogleFonts.poppins(
                color: kPrimaryColor, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: kBackgroundColor,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. INVITADO
            if (_isGuest) ...[
              _SectionTitle(title: "Tus Datos de Contacto"),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: _cardDecoration(),
                child: Column(
                  children: [
                    _buildTextField(
                        controller: _guestNameCtrl,
                        label: "Nombre completo",
                        icon: Icons.person_outline),
                    const SizedBox(height: 12),
                    _buildTextField(
                        controller: _guestEmailCtrl,
                        label: "Correo electrónico",
                        icon: Icons.email_outlined,
                        type: TextInputType.emailAddress),
                    const SizedBox(height: 12),
                    _buildTextField(
                        controller: _guestPhoneCtrl,
                        label: "Teléfono (WhatsApp)",
                        icon: Icons.phone_outlined,
                        type: TextInputType.phone),
                  ],
                ),
              ),
              const SizedBox(height: 25),
            ],

            // 2. CUOTAS
            if (_canPayInInstallments) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: kPrimaryColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: kPrimaryColor.withValues(alpha: 0.2))),
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text("Pagar en cuotas",
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              color: kPrimaryColor)),
                      subtitle: Text(
                          "Paga el ${_installmentConfig.isNotEmpty ? _installmentConfig[0] : 50}% hoy y el resto después.",
                          style: GoogleFonts.poppins(fontSize: 12)),
                      value: _payInInstallments,
                      activeThumbColor: kPrimaryColor,
                      onChanged: (val) =>
                          setState(() => _payInInstallments = val),
                    ),
                    if (_payInInstallments) ...[
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Monto a pagar hoy:",
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w500)),
                          Text(
                              "\$${(widget.totalPrice * ((_installmentConfig.isNotEmpty ? _installmentConfig[0] : 50) / 100)).toStringAsFixed(2)}",
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Colors.green[700])),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Restante:",
                              style: GoogleFonts.poppins(
                                  fontSize: 12, color: Colors.grey)),
                          Text(
                              "\$${(widget.totalPrice * (1 - ((_installmentConfig.isNotEmpty ? _installmentConfig[0] : 50) / 100))).toStringAsFixed(2)}",
                              style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ]
                  ],
                ),
              ),
              const SizedBox(height: 25),
            ],

            // 3. DATOS BANCARIOS
            _SectionTitle(title: "Realiza el pago a esta cuenta"),
            _isLoadingBankData
                ? const Padding(padding: EdgeInsets.all(20), child: Center())
                : Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: _cardDecoration(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                                widget.paymentMethod.contains('Zelle')
                                    ? Icons.attach_money
                                    : Icons.account_balance,
                                color: kPrimaryColor),
                            const SizedBox(width: 10),
                            Text(widget.paymentMethod,
                                style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                        const Divider(height: 25),
                        if (_providerBankData.isEmpty)
                          Text(
                              "No hay datos disponibles para este método. Contacta soporte.",
                              style: GoogleFonts.poppins(
                                  color: Color.fromRGBO(17, 48, 73, 1))),
                        ..._providerBankData.entries
                            .where((e) => e.key != 'metodo')
                            .map((e) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12.0),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(
                                          width: 100,
                                          child: Text(e.key.capitalize(),
                                              style: GoogleFonts.poppins(
                                                  color: Colors.grey[600],
                                                  fontSize: 13))),
                                      Expanded(
                                          child: SelectableText(e.value,
                                              style: GoogleFonts.poppins(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 14,
                                                  color: Colors.black87))),
                                      InkWell(
                                        onTap: () {
                                          Clipboard.setData(
                                              ClipboardData(text: e.value));
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(const SnackBar(
                                                  content: Text("Copiado"),
                                                  duration: Duration(
                                                      milliseconds: 500)));
                                        },
                                        child: Padding(
                                          padding:
                                              const EdgeInsets.only(left: 8.0),
                                          child: Icon(Icons.copy,
                                              size: 18,
                                              color: Colors.blue[300]),
                                        ),
                                      )
                                    ],
                                  ),
                                ))
                      ],
                    ),
                  ),

            const SizedBox(height: 25),

            // 4. REPORTE DE PAGO
            if (widget.paymentMethod != 'Efectivo' &&
                widget.paymentMethod != 'Gratis') ...[
              _SectionTitle(title: "Reporta tu transferencia"),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: _cardDecoration(),
                child: Column(
                  children: [
                    if (widget.paymentMethod == 'Pago móvil') ...[
                      _buildTextField(
                          controller: _transactionCtrl,
                          label: "Referencia (últimos 4 dígitos)",
                          icon: Icons.confirmation_number),
                      const SizedBox(height: 12),
                      _buildTextField(
                          controller: _payerIdCtrl,
                          label: "Cédula del titular",
                          icon: Icons.badge),
                      const SizedBox(height: 12),
                      _buildTextField(
                          controller: _payerPhoneCtrl,
                          label: "Teléfono del titular",
                          icon: Icons.phone_android,
                          type: TextInputType.phone),
                    ] else ...[
                      _buildTextField(
                          controller: _payerNameCtrl,
                          label: "Nombre del titular",
                          icon: Icons.person),
                      const SizedBox(height: 12),
                      _buildTextField(
                          controller: _payerEmailCtrl,
                          label: "Correo / Usuario",
                          icon: Icons.email),
                      const SizedBox(height: 12),
                      _buildTextField(
                          controller: _transactionCtrl,
                          label: "Código de referencia / confirmación",
                          icon: Icons.confirmation_number),
                    ]
                  ],
                ),
              ),
            ],

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 4),
                onPressed: _isProcessing ? null : _validateAndSubmit,
                child: _isProcessing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                      )
                    : Text("Confirmar pago",
                        style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // --- HELPERS ---

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
        border: Border.all(color: Colors.grey.shade200));
  }

  Widget _buildTextField(
      {required TextEditingController controller,
      required String label,
      required IconData icon,
      TextInputType type = TextInputType.text}) {
    return TextFormField(
      controller: controller,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        isDense: true,
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4),
      child: Text(title,
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold, fontSize: 16, color: kPrimaryColor)),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return "";
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
