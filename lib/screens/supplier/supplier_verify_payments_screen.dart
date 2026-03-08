import 'dart:convert'; // Para JSON
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Para rootBundle
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http; // Para Email y Notificaciones
import 'package:googleapis_auth/auth_io.dart'; // Para Auth de Firebase FCM

// Importamos el Provider y el Dashboard para el Dialogo de Detalle
import '../../booking_provider.dart';
import 'dashboard_home_screen.dart';

// Helper: convierte Timestamp, String ISO o DateTime a DateTime de forma segura.
// Necesario porque reservas creadas vía REST (Safari web) guardan fechas como String ISO.
DateTime _parseDate(dynamic value, {DateTime? fallback}) {
  if (value == null) return fallback ?? DateTime(2000);
  if (value is DateTime) return value;
  if (value is Timestamp) return value.toDate();
  if (value is String && value.isNotEmpty) {
    try {
      return DateTime.parse(value);
    } catch (_) {}
  }
  return fallback ?? DateTime(2000);
}

const Color kPrimaryColor = Color.fromRGBO(17, 48, 73, 1);
const Color kBackgroundColor = Color(0xFFF8F9FD);

class SupplierVerifyPaymentsScreen extends StatefulWidget {
  final String supplierId;
  final String planName;
  final int initialIndex;

  const SupplierVerifyPaymentsScreen({
    super.key,
    required this.supplierId,
    required this.planName,
    this.initialIndex = 0,
  });

  @override
  State<SupplierVerifyPaymentsScreen> createState() =>
      _SupplierVerifyPaymentsScreenState();
}

class _SupplierVerifyPaymentsScreenState
    extends State<SupplierVerifyPaymentsScreen> {
  // --- 1. LÓGICA DE NOTIFICACIÓN PUSH AL CLIENTE (FCM V1) ---
  Future<void> _sendNotificationToClient(String userId, String planName) async {
    debugPrint("🔔 [NOTIFICACIÓN] Iniciando envío al cliente ($userId)...");
    try {
      // Obtener token del cliente
      final userDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(userId)
          .get();

      if (!userDoc.exists) {
        debugPrint("❌ Cliente no encontrado en BD.");
        return;
      }

      final data = userDoc.data();
      final String? token = data?['fcmToken'] ?? data?['deviceToken'];

      if (token == null || token.isEmpty) {
        debugPrint("❌ Cliente sin token FCM.");
        return;
      }

      // Credenciales
      const String serviceAccountPath =
          'assets/biqoe-app-firebase-adminsdk-fbsvc-067c9b5471.json';
      const List<String> scopes = [
        'https://www.googleapis.com/auth/firebase.messaging'
      ];

      final serviceAccount = ServiceAccountCredentials.fromJson(
          await rootBundle.loadString(serviceAccountPath));
      final client = await clientViaServiceAccount(serviceAccount, scopes);

      // Payload
      final notificationPayload = {
        'message': {
          'token': token,
          'notification': {
            'title': '¡Pago verificado! ✅',
            'body': 'Tu pago para $planName ha sido aprobado por el proveedor.',
          },
          'data': {
            'click_action': 'FLUTTER_NOTIFICATION_CLICK',
            'screen': 'bookings', // <--- REDIRECCIÓN A MIS RESERVAS
            'type': 'payment_verified',
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

      final response = await client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(notificationPayload),
      );

      if (response.statusCode == 200) {
        debugPrint("✅ Notificación enviada al cliente.");
      } else {
        debugPrint("❌ Error FCM: ${response.body}");
      }
      client.close();
    } catch (e) {
      debugPrint("❌ Excepción FCM: $e");
    }
  }

  // --- 2. LÓGICA DE CORREO AL CLIENTE (APPS SCRIPT) ---
  Future<void> _sendEmailToClient({
    required String userEmail,
    required String userName,
    required String planName,
    required double amount,
    required String code,
  }) async {
    debugPrint("📧 [EMAIL] Enviando correo de verificación a $userEmail...");

    if (userEmail.isEmpty) return;

    const String emailServiceUrl =
        'https://script.google.com/macros/s/AKfycbz5Wy1Qtn_uUT1sgL78MYOWvI4M3TJA1fml0rTd7qtjQBAB2DI7MXMP74P24aFN7bT6Jg/exec';

    final String dateStr = DateFormat('dd/MM/yyyy').format(DateTime.now());

    // Generar URL del QR (Color verde oscuro para combinar)
    final String qrUrl =
        "https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=$code&color=2e7d32";

    final String htmlContent = """
      <div style="font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif; color: #333; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #e0e0e0; border-radius: 8px; background-color: #ffffff;">
        
        <div style="text-align: center; padding-bottom: 20px; border-bottom: 1px solid #eee;">
          <h2 style="color: #2e7d32; margin: 0;">¡Pago Verificado!</h2>
          <p style="color: #666; margin-top: 5px;">El proveedor ha confirmado tu transacción</p>
        </div>

        <div style="padding: 20px 0;">
          <p>Hola <strong>$userName</strong>,</p>
          <p>Te informamos que tu pago para la actividad <strong>$planName</strong> ha sido verificado exitosamente.</p>
          
          <div style="background-color: #f1f8e9; padding: 20px; border-radius: 8px; text-align: center; margin: 25px 0; border: 1px dashed #2e7d32;">
            <p style="margin: 0 0 10px 0; font-size: 12px; color: #555; text-transform: uppercase; letter-spacing: 1px;">Código de Reserva</p>
            <h1 style="margin: 0 0 15px 0; font-size: 32px; letter-spacing: 5px; color: #2e7d32;">$code</h1>
            
            <img src="$qrUrl" alt="Código QR" width="150" height="150" style="display: block; margin: 0 auto; border: 4px solid white; border-radius: 8px;" />
            <p style="margin: 10px 0 0 0; font-size: 11px; color: #666;">Muestra este código al llegar</p>
          </div>

          <table style="width: 100%; border-collapse: collapse; margin-top: 10px;">
            <tr>
              <td style="padding: 10px 0; border-bottom: 1px solid #eee; color: #666;">Fecha de verificación:</td>
              <td style="padding: 10px 0; border-bottom: 1px solid #eee; font-weight: bold; text-align: right;">$dateStr</td>
            </tr>
            <tr>
              <td style="padding: 10px 0; border-bottom: 1px solid #eee; color: #666;">Actividad:</td>
              <td style="padding: 10px 0; border-bottom: 1px solid #eee; font-weight: bold; text-align: right;">$planName</td>
            </tr>
            <tr style="background-color: #f9fff9;">
              <td style="padding: 10px 5px; color: #2e7d32; font-weight: bold;">Monto verificado:</td>
              <td style="padding: 10px 5px; font-weight: bold; color: #2e7d32; text-align: right; font-size: 16px;">\$${amount.toStringAsFixed(2)}</td>
            </tr>
          </table>
        </div>
        
        <div style="text-align: center; margin-top: 30px; padding-top: 20px; border-top: 1px solid #eee; color: #888; font-size: 12px;">
          <p>Puedes ver los detalles en la sección "Mis Reservas" de la aplicación.</p>
          <p>&copy; ${DateTime.now().year} Biqoe App</p>
        </div>
      </div>
    """;

    try {
      await http.post(
        Uri.parse(emailServiceUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'to': userEmail,
          'subject': 'Pago Verificado - $planName',
          'htmlBody': htmlContent,
          'name': "Biqoe - Pagos"
        }),
      );
      debugPrint("✅ Email enviado.");
    } catch (e) {
      debugPrint("❌ Error enviando email: $e");
    }
  }

  // --- TRIGGER COMÚN DE COMUNICACIÓN ---
  void _notifyUserSuccess(Map<String, dynamic> docData, double amount) {
    final String userId = docData['userId'] ?? '';
    final String email = docData['email'] ?? '';
    final String name = docData['name'] ?? 'Usuario';
    final String plan = docData['planName'] ?? 'Actividad';
    final String code = docData['code'] ?? '---';

    // Disparar procesos en segundo plano (sin await para no bloquear UI)
    _sendNotificationToClient(userId, plan);
    _sendEmailToClient(
      userEmail: email,
      userName: name,
      planName: plan,
      amount: amount,
      code: code,
    );
  }

  // Verificar un pago individual (Cuota)
  Future<void> _verifyPaymentItem(String docId, Map<String, dynamic> docData,
      Map<String, dynamic> paymentItem) async {
    try {
      final double amount = (paymentItem['amount'] ?? 0).toDouble();

      await Provider.of<BookingProvider>(context, listen: false)
          .verifyIndividualPayment(
        supplierId: widget.supplierId,
        bookingId: docId,
        paymentData: paymentItem,
        currentTotalPaid: (docData['amountPaid'] ?? 0).toDouble(),
        totalPlanPrice: (docData['totalPlanPrice'] ?? 0).toDouble(),
        currentInstallments: docData['installmentsPaid'] ?? 0,
      );

      // Notificar al usuario
      _notifyUserSuccess(docData, amount);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Pago verificado y sumado al saldo")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  // Verificar Reserva Completa (Pago Inicial)
  // MODIFICADO: Ahora recibe docData para poder enviar correos/notificaciones
  Future<void> _verifyInitialPayment(String docId, Map<String, dynamic> docData,
      Map<String, dynamic> paymentItem) async {
    try {
      final docRef = FirebaseFirestore.instance
          .collection('reservaciones')
          .doc(widget.supplierId)
          .collection('reservas')
          .doc(docId);

      // Preparamos el item actualizado (verified)
      Map<String, dynamic> updatedItem = Map.from(paymentItem);
      updatedItem['status'] = 'verified';
      updatedItem['verifiedAt'] = Timestamp.now();

      // Usamos runTransaction para asegurar que todo se actualice junto
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // 1. Si el item en historial era 'pending', lo quitamos y ponemos el 'verified'
        if (paymentItem['status'] == 'pending') {
          transaction.update(docRef, {
            'paymentHistory': FieldValue.arrayRemove([paymentItem])
          });
          transaction.update(docRef, {
            'paymentHistory': FieldValue.arrayUnion([updatedItem])
          });
        }

        // 2. Actualizamos el estado global de la reserva
        transaction.update(docRef, {
          'estado': 'verificado',
          'verifiedAt': FieldValue.serverTimestamp(),
        });
      });

      // Notificar al usuario
      final double amount = (paymentItem['amount'] ?? 0).toDouble();
      _notifyUserSuccess(docData, amount);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Reserva verificada exitosamente")));
      }
    } catch (e) {
      debugPrint("Error verifying initial: $e");
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      initialIndex: widget.initialIndex,
      child: Scaffold(
        backgroundColor: kBackgroundColor,
        appBar: AppBar(
          title: Text(
              widget.planName.isEmpty ? "Gestión de pagos" : widget.planName,
              style: GoogleFonts.poppins(
                  color: kPrimaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 18)),
          backgroundColor: Colors.white,
          elevation: 0,
          leading: const BackButton(color: Colors.black),
          bottom: TabBar(
            isScrollable: true,
            labelColor: kPrimaryColor,
            unselectedLabelColor: Colors.grey,
            indicatorColor: kPrimaryColor,
            labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            tabs: const [
              Tab(text: "Todas"),
              Tab(text: "Pendientes"),
              Tab(text: "Verificadas"),
              Tab(text: "Por cobrar"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _PaymentsList(
                supplierId: widget.supplierId,
                planName: widget.planName,
                filterType: 'all',
                onVerify: _verifyPaymentItem,
                onVerifyInitial: _verifyInitialPayment),
            _PaymentsList(
                supplierId: widget.supplierId,
                planName: widget.planName,
                filterType: 'pending',
                onVerify: _verifyPaymentItem,
                onVerifyInitial: _verifyInitialPayment),
            _PaymentsList(
                supplierId: widget.supplierId,
                planName: widget.planName,
                filterType: 'verified',
                onVerify: _verifyPaymentItem,
                onVerifyInitial: _verifyInitialPayment),
            _PaymentsList(
                supplierId: widget.supplierId,
                planName: widget.planName,
                filterType: 'receivable',
                onVerify: _verifyPaymentItem,
                onVerifyInitial: _verifyInitialPayment),
          ],
        ),
      ),
    );
  }
}

class _PaymentsList extends StatefulWidget {
  final String supplierId;
  final String planName;
  final String filterType;
  final Function(String, Map<String, dynamic>, Map<String, dynamic>) onVerify;
  // MODIFICADO: Ahora aceptamos docData también para la inicial
  final Function(String, Map<String, dynamic>, Map<String, dynamic>)
      onVerifyInitial;

  const _PaymentsList({
    required this.supplierId,
    required this.planName,
    required this.filterType,
    required this.onVerify,
    required this.onVerifyInitial,
  });

  @override
  State<_PaymentsList> createState() => _PaymentsListState();
}

class _PaymentsListState extends State<_PaymentsList> {
  String _searchQuery = "";

  @override
  Widget build(BuildContext context) {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('reservaciones')
        .doc(widget.supplierId)
        .collection('reservas');

    if (widget.planName.isNotEmpty) {
      query = query.where('planName', isEqualTo: widget.planName);
    }

    query = query.orderBy('createdAt', descending: true);

    return Column(
      children: [
        // Buscador
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            onChanged: (val) =>
                setState(() => _searchQuery = val.toLowerCase()),
            decoration: InputDecoration(
              hintText: "Buscar por nombre, referencia o código",
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),

        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: query.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data?.docs ?? [];
              List<Map<String, dynamic>> flattenedItems = [];

              for (var doc in docs) {
                final data = doc.data() as Map<String, dynamic>;
                final List history = data['paymentHistory'] ?? [];

                // --- 1. Filtros de Búsqueda ---
                final name = (data['name'] ?? '').toString().toLowerCase();
                final code = (data['code'] ?? '').toString().toLowerCase();
                final trans =
                    (data['transactionCode'] ?? '').toString().toLowerCase();

                bool matchesSearch = _searchQuery.isEmpty ||
                    name.contains(_searchQuery) ||
                    code.contains(_searchQuery) ||
                    trans.contains(_searchQuery);

                if (!matchesSearch) {
                  bool internalMatch = history.any((h) =>
                      (h['referencia'] ?? '')
                          .toString()
                          .toLowerCase()
                          .contains(_searchQuery));
                  if (!internalMatch) continue;
                }

                // --- 2. Lógica "Por Cobrar" ---
                if (widget.filterType == 'receivable') {
                  double total = (data['totalPlanPrice'] ?? 0).toDouble();
                  double paid = (data['amountPaid'] ?? 0).toDouble();

                  if ((total - paid) > 1.0) {
                    flattenedItems.add({
                      'docId': doc.id,
                      'docData': data,
                      'type': 'debt_summary',
                      'date': data['createdAt']
                    });
                  }
                  continue;
                }

                // --- 3. Lógica de Pagos Normales ---

                if (history.isNotEmpty) {
                  for (var payment in history) {
                    String status = payment['status'] ?? 'verified';
                    String type = payment['type'] ?? 'installment';

                    // --- FIX: Forzar pendiente si la reserva global está pendiente ---
                    if (type == 'initial' && data['estado'] == 'pendiente') {
                      status = 'pending';
                    }

                    bool include = false;
                    if (widget.filterType == 'all') include = true;
                    if (widget.filterType == 'pending' && status == 'pending') {
                      include = true;
                    }
                    if (widget.filterType == 'verified' &&
                        status == 'verified') {
                      include = true;
                    }

                    if (include) {
                      flattenedItems.add({
                        'docId': doc.id,
                        'docData': data,
                        'payment': payment,
                        'type': 'payment_item',
                        'date': payment['date'],
                        'computedStatus': status,
                      });
                    }
                  }
                }
                // CASO LEGACY (Sin historial)
                else if (data['estado'] == 'pendiente') {
                  bool include = widget.filterType == 'all' ||
                      widget.filterType == 'pending';

                  if (include) {
                    flattenedItems.add({
                      'docId': doc.id,
                      'docData': data,
                      'payment': {
                        'amount': data['totalPrice'] ?? data['amountPaid'],
                        'method': data['paymentMethod'],
                        'referencia': data['transactionCode'],
                        'date': data['createdAt'],
                        'type': 'initial_legacy',
                        'status': 'pending',
                      },
                      'type': 'payment_item',
                      'date': data['createdAt'],
                      'computedStatus': 'pending',
                    });
                  }
                }
              }

              // Ordenar
              flattenedItems.sort((a, b) {
                var dateA = a['date'];
                var dateB = b['date'];
                DateTime dtA =
                    (dateA is Timestamp) ? dateA.toDate() : DateTime.now();
                DateTime dtB =
                    (dateB is Timestamp) ? dateB.toDate() : DateTime.now();
                return dtB.compareTo(dtA);
              });

              if (flattenedItems.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.filter_list_off,
                          size: 50, color: Colors.grey[300]),
                      const SizedBox(height: 10),
                      Text("No hay elementos aquí",
                          style: GoogleFonts.poppins(color: Colors.grey)),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: flattenedItems.length,
                separatorBuilder: (c, i) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = flattenedItems[index];

                  if (item['type'] == 'debt_summary') {
                    return _DebtCard(
                      docId: item['docId'],
                      docData: item['docData'],
                      supplierId: widget.supplierId,
                    );
                  }

                  return _DetailedPaymentCard(
                    docId: item['docId'],
                    docData: item['docData'],
                    payment: item['payment'],
                    computedStatus: item['computedStatus'],
                    isVerifiedTab: widget.filterType == 'verified',
                    onVerify: () {
                      final type = item['payment']['type'];
                      if (type == 'initial' || type == 'initial_legacy') {
                        // Verificación de Pago Inicial
                        widget.onVerifyInitial(
                            item['docId'], item['docData'], item['payment']);
                      } else {
                        // Verificación de Cuota
                        widget.onVerify(
                            item['docId'], item['docData'], item['payment']);
                      }
                    },
                    supplierId: widget.supplierId,
                  );
                },
              );
            },
          ),
        )
      ],
    );
  }
}

class _DetailedPaymentCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> docData;
  final Map<String, dynamic> payment;
  final String computedStatus;
  final bool isVerifiedTab;
  final VoidCallback onVerify;
  final String supplierId;

  const _DetailedPaymentCard({
    required this.docId,
    required this.docData,
    required this.payment,
    required this.computedStatus,
    required this.isVerifiedTab,
    required this.onVerify,
    required this.supplierId,
  });

  @override
  Widget build(BuildContext context) {
    final String clientName = docData['name'] ?? 'Cliente';
    final String code = docData['code'] ?? '---';

    final double amount = (payment['amount'] ?? 0).toDouble();
    final String method =
        payment['method'] ?? payment['paymentMethod'] ?? 'N/A';
    final String ref =
        payment['referencia'] ?? payment['transactionCode'] ?? 'S/R';
    final String typeRaw = payment['type'] ?? 'installment';

    final String typeLabel =
        (typeRaw == 'initial' || typeRaw == 'initial_legacy')
            ? 'Inicial'
            : 'Cuota';

    final double amountBs = (payment['amountBs'] ?? 0).toDouble();
    final double rate = (payment['currencyRate'] ?? 0).toDouble();
    final String? bank = payment['banco'];
    final String? phone = payment['telefono'] ?? payment['celular'];
    final String? cedula = payment['cedula'];
    final String? email = payment['email'] ?? payment['email_pago'];

    String dateStr = '';
    if (payment['date'] != null && payment['date'] is Timestamp) {
      dateStr = DateFormat('dd MMM yyyy, hh:mm a')
          .format(_parseDate(payment['date']));
    }

    bool showVerifyBtn = (computedStatus == 'pending');

    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => BookingDetailDialog(
            data: docData,
            docId: docId,
            supplierId: supplierId,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withAlpha((0.04 * 255).round()),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
          border: Border.all(
            color: showVerifyBtn
                ? Colors.orange.withValues(alpha: 0.5)
                : Colors.green.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(clientName,
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: kPrimaryColor)),
                      Text("$typeLabel • Cod: $code",
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                ),
                Text("\$${amount.toStringAsFixed(2)}",
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.black87)),
              ],
            ),
            const Divider(height: 20),
            _detailRow(Icons.payment, "Método:", method),
            if (ref.isNotEmpty && ref != 'S/R')
              _detailRow(
                  Icons.confirmation_number_outlined, "Referencia:", ref),
            if (amountBs > 0)
              _detailRow(Icons.currency_exchange, "Monto Bs:",
                  "Bs ${amountBs.toStringAsFixed(2)} (Tasa: $rate)"),
            if (bank != null && bank.isNotEmpty)
              _detailRow(Icons.account_balance, "Banco:", bank),
            if (phone != null && phone.isNotEmpty)
              _detailRow(Icons.phone_android, "Teléfono:", phone),
            if (cedula != null && cedula.isNotEmpty)
              _detailRow(Icons.badge_outlined, "Cédula:", cedula),
            if (email != null && email.isNotEmpty)
              _detailRow(Icons.email_outlined, "Email cuenta:", email),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(dateStr,
                    style:
                        GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
                if (showVerifyBtn && !isVerifiedTab)
                  ElevatedButton(
                    onPressed: onVerify,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryColor,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 0),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        minimumSize: const Size(0, 36)),
                    child: const Text("Verificar",
                        style: TextStyle(color: Colors.white, fontSize: 12)),
                  )
                else
                  const Chip(
                    label: Text("Verificado",
                        style: TextStyle(color: Colors.white, fontSize: 10)),
                    backgroundColor: Colors.green,
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  )
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey[500]),
          const SizedBox(width: 8),
          Text(label,
              style:
                  GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }
}

class _DebtCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> docData;
  final String supplierId;

  const _DebtCard(
      {required this.docId, required this.docData, required this.supplierId});

  @override
  Widget build(BuildContext context) {
    final double total = (docData['totalPlanPrice'] ?? 0).toDouble();
    final double paid = (docData['amountPaid'] ?? 0).toDouble();
    final double debt = total - paid;

    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => BookingDetailDialog(
            data: docData,
            docId: docId,
            supplierId: supplierId,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.red.withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(docData['name'] ?? 'Cliente',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  Text("Debe: \$${debt.toStringAsFixed(2)}",
                      style: GoogleFonts.poppins(
                          color: Colors.red, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey)
          ],
        ),
      ),
    );
  }
}
