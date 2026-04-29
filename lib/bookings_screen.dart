import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:math';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'booking_provider.dart';

const Color kPrimaryColor = Color.fromRGBO(17, 48, 73, 1);
const Color kBackgroundColor = Color(0xFFF8F9FD);

class BookingsScreen extends StatefulWidget {
  final String userId;

  const BookingsScreen({super.key, required this.userId});

  @override
  BookingsScreenState createState() => BookingsScreenState();
}

class BookingsScreenState extends State<BookingsScreen> {
  bool showPendingPlans = true;
  double exchangeRate = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // YA NO CARGAMOS MANUALMENTE PORQUE EL STREAM LO HARÁ SOLO
      _fetchExchangeRate();
    });
  }

  Future<void> _fetchExchangeRate() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('config')
          .doc('tasa')
          .get();
      if (doc.exists && mounted) {
        setState(() {
          exchangeRate = (doc.data()?['valor'] as num?)?.toDouble() ?? 0.0;
        });
      }
    } catch (e) {
      debugPrint("Error obteniendo tasa: $e");
    }
  }

  /// Devuelve el símbolo de la divisa del booking: '€' para EUR, '$' para USD
  String _cs(Map<String, dynamic> booking) {
    return booking['divisa']?.toString() == 'eur' ? '€' : '\$';
  }

  // --- ABRIR DIÁLOGO DE PAGO ---
  void _showPaymentRegistrationDialog(
      BuildContext context, Map<String, dynamic> booking) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return _PaymentDialogContent(
          booking: booking,
          userId: widget.userId,
          exchangeRate: exchangeRate,
          parentContext: context,
        );
      },
    );
  }

  // --- PDF ACTUALIZADO CON LOGO ---
  Future<void> _generateAndDownloadPdf(Map<String, dynamic> booking) async {
    final logoData = await rootBundle.load('assets/images/Biqoe logo.png');
    final logoImage = pw.MemoryImage(logoData.buffer.asUint8List());

    String? mapLink;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('destinos')
          .where('nombre', isEqualTo: booking['planName'])
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        mapLink = snapshot.docs.first.data()['googleMapsLink'];
      }
    } catch (e) {
      debugPrint("Error buscando mapa para PDF: $e");
    }

    final pdf = pw.Document();
    final headerStyle = pw.TextStyle(
        fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700);
    final normalStyle = pw.TextStyle(fontSize: 10);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Container(
                      height: 50,
                      child: pw.Image(logoImage),
                    ),
                    pw.Text("RESERVA CONFIRMADA",
                        style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.green700)),
                  ]),
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300),
                      borderRadius:
                          const pw.BorderRadius.all(pw.Radius.circular(5))),
                  child: pw.Row(children: [
                    pw.Expanded(
                        child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                          pw.Text("ACTIVIDAD", style: headerStyle),
                          pw.Text(booking['planName'] ?? 'Actividad',
                              style: pw.TextStyle(
                                  fontSize: 14,
                                  fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 5),
                          pw.Text("UBICACIÓN", style: headerStyle),
                          pw.Text(booking['planLocation'] ?? 'Ver mapa',
                              style: normalStyle),
                          if (mapLink != null && mapLink.isNotEmpty)
                            pw.UrlLink(
                              child: pw.Text("Ver ubicación en Google Maps",
                                  style: pw.TextStyle(
                                      fontSize: 10,
                                      color: PdfColors.blue,
                                      decoration: pw.TextDecoration.underline)),
                              destination: mapLink,
                            ),
                          pw.SizedBox(height: 5),
                          pw.Text("CÓDIGO ÚNICO", style: headerStyle),
                          pw.Text(booking['code'] ?? '---',
                              style: pw.TextStyle(
                                  fontSize: 16,
                                  fontWeight: pw.FontWeight.bold,
                                  letterSpacing: 2)),
                        ])),
                    pw.BarcodeWidget(
                      data: booking['code'] ?? '0000',
                      barcode: pw.Barcode.qrCode(),
                      width: 80,
                      height: 80,
                    ),
                  ])),
              pw.SizedBox(height: 20),
              pw.Text("DATOS DEL CLIENTE", style: headerStyle),
              pw.Text("Nombre: ${booking['name']}", style: normalStyle),
              pw.Text("Email: ${booking['email']}", style: normalStyle),
              pw.SizedBox(height: 20),
              pw.Text("HISTORIAL DE PAGOS", style: headerStyle),
              pw.SizedBox(height: 5),
              pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  children: [
                    pw.TableRow(
                        decoration:
                            const pw.BoxDecoration(color: PdfColors.grey100),
                        children: [
                          pw.Padding(
                              padding: const pw.EdgeInsets.all(5),
                              child: pw.Text("Fecha",
                                  style: pw.TextStyle(
                                      fontWeight: pw.FontWeight.bold,
                                      fontSize: 10))),
                          pw.Padding(
                              padding: const pw.EdgeInsets.all(5),
                              child: pw.Text("Método",
                                  style: pw.TextStyle(
                                      fontWeight: pw.FontWeight.bold,
                                      fontSize: 10))),
                          pw.Padding(
                              padding: const pw.EdgeInsets.all(5),
                              child: pw.Text(
                                  "Monto (${booking['divisa']?.toString() == 'eur' ? 'EUR' : 'USD'})",
                                  style: pw.TextStyle(
                                      fontWeight: pw.FontWeight.bold,
                                      fontSize: 10))),
                        ]),
                    if (booking['paymentHistory'] != null)
                      ...((booking['paymentHistory'] as List).map((p) {
                        final date = p['date'] is Timestamp
                            ? (p['date'] as Timestamp)
                                .toDate()
                                .toString()
                                .split(' ')[0]
                            : p['date'].toString().split('T')[0];
                        return pw.TableRow(children: [
                          pw.Padding(
                              padding: const pw.EdgeInsets.all(5),
                              child: pw.Text(date, style: normalStyle)),
                          pw.Padding(
                              padding: const pw.EdgeInsets.all(5),
                              child: pw.Text(p['method'] ?? 'N/A',
                                  style: normalStyle)),
                          pw.Padding(
                              padding: const pw.EdgeInsets.all(5),
                              child: pw.Text(
                                  "${booking['divisa']?.toString() == 'eur' ? '€' : '\$'}${p['amount']}",
                                  style: normalStyle)),
                        ]);
                      }).toList())
                  ]),
              pw.SizedBox(height: 10),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
                pw.Text("Total Pagado: \$${booking['amountPaid']}",
                    style: pw.TextStyle(
                        fontSize: 12, fontWeight: pw.FontWeight.bold))
              ]),
              pw.Spacer(),
              pw.Center(
                  child: pw.Text(
                      "Biqoe - Explora, reserva y vive experiencias únicas en Venezuela",
                      style: const pw.TextStyle(
                          fontSize: 10, color: PdfColors.grey500))),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Reserva-${booking['code']}.pdf',
    );
  }

  // --- DIÁLOGO QR ---
  void _showQrDialog(String code, String status) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Código de reserva',
                    style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: kPrimaryColor)),
                const SizedBox(height: 20),
                QrImageView(
                  data: code,
                  version: QrVersions.auto,
                  size: 200.0,
                  eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square, color: kPrimaryColor),
                  dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: kPrimaryColor),
                ),
                const SizedBox(height: 20),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                      color: kBackgroundColor,
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(code,
                      style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                          color: kPrimaryColor)),
                ),
                const SizedBox(height: 10),
                Text(
                  status == 'verificado'
                      ? "Reserva verificada"
                      : "Esperando verificación del proveedor",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  // --- DETALLES ---
  Widget _buildFinancialStatus(Map<String, dynamic> booking, bool isVerified) {
    final double total = (booking['totalPlanPrice'] ?? 0.0).toDouble();
    final double verifiedPaid = (booking['amountPaid'] ?? 0.0).toDouble();

    double pendingAmount = 0.0;
    if (booking['paymentHistory'] != null) {
      final history = booking['paymentHistory'] as List;
      for (var p in history) {
        if (p['status'] == 'pending') {
          pendingAmount += (p['amount'] ?? 0).toDouble();
        }
      }
    }

    final double totalPerceived = verifiedPaid + pendingAmount;
    final bool isInstallment = booking['isInstallment'] ?? false;
    final double remaining = max(0, total - totalPerceived);

    if (isInstallment && total > 0) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.blue.withValues(alpha: 0.2))),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Progreso de pago",
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: kPrimaryColor)),
                Text(
                    remaining < 0.1
                        ? "Pagado"
                        : "Resta: ${_cs(booking)}${remaining.toStringAsFixed(2)}",
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: remaining < 0.1 ? Colors.green : Colors.red)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: SizedBox(
                height: 6,
                child: Row(
                  children: [
                    if (verifiedPaid > 0)
                      Expanded(
                        flex: (verifiedPaid * 100).toInt(),
                        child: Container(color: kPrimaryColor),
                      ),
                    if (pendingAmount > 0)
                      Expanded(
                        flex: (pendingAmount * 100).toInt(),
                        child: Container(color: Colors.amber),
                      ),
                    if (remaining > 0)
                      Expanded(
                        flex: (remaining * 100).toInt(),
                        child: Container(color: Colors.grey[200]),
                      )
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                    "Pagado: ${_cs(booking)}${verifiedPaid.toStringAsFixed(2)}",
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: Colors.grey[700])),
                Text("Total: ${_cs(booking)}${total.toStringAsFixed(2)}",
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: Colors.grey[700])),
              ],
            ),
            if (pendingAmount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Pendiente por verificar: ${_cs(booking)}${pendingAmount.toStringAsFixed(2)}",
                    style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.amber[800]),
                  ),
                ),
              ),
            if (isVerified && remaining > 0.1) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () =>
                      _showPaymentRegistrationDialog(context, booking),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: kPrimaryColor),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text("Registrar nuevo pago",
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: kPrimaryColor)),
                ),
              )
            ]
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 18),
          const SizedBox(width: 8),
          Text("Pagado totalmente (${_cs(booking)}${total.toStringAsFixed(2)})",
              style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.green[800])),
        ],
      ),
    );
  }

  // --- BOTÓN FILTRO ---
  Widget _buildPlanButton(String title, bool isActive) {
    return GestureDetector(
      onTap: () => setState(() => showPendingPlans = title == "Pendientes"),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? kPrimaryColor : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isActive
              ? [
                  BoxShadow(
                      color: kPrimaryColor.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 3))
                ]
              : [],
          border: Border.all(color: Colors.transparent),
        ),
        alignment: Alignment.center,
        child: Text(title,
            style: GoogleFonts.poppins(
                color: isActive ? Colors.white : Colors.grey[600],
                fontWeight: FontWeight.w600)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ELIMINAMOS LA LECTURA DEL PROVIDER QUE CAUSABA CONFLICTO
    // final bookingProvider = Provider.of<BookingProvider>(context);

    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: kBackgroundColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: Text("Reservas",
            style: GoogleFonts.poppins(
                color: kPrimaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 20)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 15),
            child: Row(
              children: [
                Expanded(
                    child: _buildPlanButton("Pendientes", showPendingPlans)),
                const SizedBox(width: 12),
                Expanded(
                    child: _buildPlanButton("Verificados", !showPendingPlans)),
              ],
            ),
          ),
        ),
      ),
      // --- AQUÍ INSERTAMOS EL STREAMBUILDER CORRECTAMENTE ---
      body: StreamBuilder<QuerySnapshot>(
        // Usamos collectionGroup para buscar en las subcolecciones 'reservas' de todos los proveedores
        stream: FirebaseFirestore.instance
            .collectionGroup('reservas')
            .where('userId', isEqualTo: widget.userId)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center();
          }

          if (snapshot.hasError) {
            // Manejo de error por falta de índice
            if (snapshot.error.toString().contains('indexes')) {
              return const Center(
                  child: Text(
                      "Se requiere crear un índice en Firebase. Revisa la consola."));
            }
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          final docs = snapshot.data?.docs ?? [];

          List<Map<String, dynamic>> pendingBookings = [];
          List<Map<String, dynamic>> verifiedBookings = [];

          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id; // Importante: ID del documento

            final String status = data['estado'] ?? 'pendiente';

            if (status == 'verificado') {
              verifiedBookings.add(data);
            } else {
              pendingBookings.add(data);
            }
          }

          return _buildBookingsList(
              showPendingPlans ? pendingBookings : verifiedBookings);
        },
      ),
    );
  }

  Widget _buildBookingsList(List<Map<String, dynamic>> bookings) {
    if (bookings.isEmpty) {
      return Center(
          child: Text(
              showPendingPlans
                  ? "Sin reservas pendientes"
                  : "Sin reservas verificadas",
              style: GoogleFonts.poppins(color: Colors.grey, fontSize: 16)));
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 100),
      itemCount: bookings.length,
      itemBuilder: (context, index) {
        final booking = bookings[index];
        final isVerified = booking['estado'] == 'verificado';
        return Card(
          color: Colors.white,
          margin: const EdgeInsets.only(bottom: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 2,
          shadowColor: Colors.black.withValues(alpha: 0.05),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            booking['planName'] ?? '',
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: kPrimaryColor),
                          ),
                          Row(
                            children: [
                              Icon(Icons.location_on_outlined,
                                  size: 14, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  booking['planLocation'] ?? '',
                                  style: GoogleFonts.poppins(
                                      fontSize: 12, color: Colors.grey[600]),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          _MapLinkLoader(planName: booking['planName'] ?? ''),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isVerified)
                      GestureDetector(
                        onTap: () => _showQrDialog(
                            booking['code'] ?? '', booking['estado']),
                        child: const Icon(Icons.qr_code_2,
                            color: kPrimaryColor, size: 28),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6)),
                        child: Text("Pendiente",
                            style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: Colors.orange[800],
                                fontWeight: FontWeight.bold)),
                      )
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Divider(height: 1),
                ),
                if (booking['packages'] != null)
                  ...(booking['packages'] as List).map((p) => Text(
                      "• ${p['miniDescripcion']} (x${p['personas']})",
                      style: GoogleFonts.poppins(fontSize: 13))),
                const SizedBox(height: 12),
                _buildFinancialStatus(booking, isVerified),
                if (isVerified) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _generateAndDownloadPdf(booking),
                      icon: const Icon(Icons.download_rounded,
                          size: 18, color: kPrimaryColor),
                      label: Text("Descargar Detalles",
                          style: GoogleFonts.poppins(
                              color: kPrimaryColor,
                              fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                          side: BorderSide(
                              color: kPrimaryColor.withValues(alpha: 0.3))),
                    ),
                  )
                ]
              ],
            ),
          ),
        );
      },
    );
  }
}

// ============================================================================
// CLASE PRIVADA PARA EL DIÁLOGO DE PAGO
// ============================================================================
class _PaymentDialogContent extends StatefulWidget {
  final Map<String, dynamic> booking;
  final String userId;
  final double exchangeRate;
  final BuildContext parentContext;

  const _PaymentDialogContent({
    required this.booking,
    required this.userId,
    required this.exchangeRate,
    required this.parentContext,
  });

  @override
  State<_PaymentDialogContent> createState() => _PaymentDialogContentState();
}

class _PaymentDialogContentState extends State<_PaymentDialogContent> {
  bool isLoadingData = true;
  String paymentOption = 'total';
  String selectedMethod = 'Efectivo';

  double totalPlanPrice = 0.0;
  double amountPaid = 0.0;
  double remainingBalance = 0.0;
  double nextInstallmentAmount = 0.0;
  String nextInstallmentLabel = "Siguiente Cuota";
  bool showNextOption = false;

  Map<String, dynamic>? providerPaymentMethods;
  List<String> availableMethods = ['Efectivo'];

  final refCtrl = TextEditingController();
  final bankCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final idCtrl = TextEditingController();
  final emailCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    final booking = widget.booking;
    totalPlanPrice = (booking['totalPlanPrice'] ?? 0.0).toDouble();
    amountPaid = (booking['amountPaid'] ?? 0.0).toDouble();
    remainingBalance = max(0, totalPlanPrice - amountPaid);
    nextInstallmentAmount = remainingBalance;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('destinos')
          .where('nombre', isEqualTo: booking['planName'])
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty && mounted) {
        final data = snapshot.docs.first.data();
        debugPrint(">>> DESTINO ENCONTRADO: ${data['nombre']}");

        List<double> installmentConfig = [];

        if (data['paquetes'] != null) {
          final paquetes = data['paquetes'] as List;
          for (var p in paquetes) {
            if (p['tieneCuotas'] == true && p['configuracionCuotas'] != null) {
              installmentConfig = List<double>.from(
                  (p['configuracionCuotas'] as List)
                      .map((e) => (e as num).toDouble()));
              debugPrint(">>> CONFIG: $installmentConfig");
              break;
            }
          }
        }

        if (data['metodosPago'] != null) {
          providerPaymentMethods = {};
          for (var m in data['metodosPago']) {
            providerPaymentMethods![m['metodo']] = m;
          }
          Set<String> uniqueMethods = {};
          uniqueMethods.addAll(providerPaymentMethods!.keys.cast<String>());
          uniqueMethods.add('Efectivo');
          availableMethods = uniqueMethods.toList();

          if (availableMethods.isNotEmpty &&
              availableMethods.contains('Pago móvil')) {
            selectedMethod = 'Pago móvil';
          } else if (availableMethods.length > 1) {
            selectedMethod = availableMethods.first;
          }
        }

        if (installmentConfig.isNotEmpty) {
          double cumulativePct = 0.0;
          for (int i = 0; i < installmentConfig.length; i++) {
            double pct = installmentConfig[i];
            cumulativePct += pct;
            double targetAmount = totalPlanPrice * (cumulativePct / 100);

            if (amountPaid < (targetAmount - 0.5)) {
              nextInstallmentAmount = targetAmount - amountPaid;
              nextInstallmentLabel = "Cuota ${i + 1} (${pct.toInt()}%)";
              if (nextInstallmentAmount > remainingBalance) {
                nextInstallmentAmount = remainingBalance;
              }
              break;
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Error inicializando pago: $e");
    }

    if (mounted) {
      setState(() {
        showNextOption = (remainingBalance - nextInstallmentAmount).abs() > 1.0;
        paymentOption = showNextOption ? 'next' : 'total';
        isLoadingData = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    double currentAmountToPay =
        (paymentOption == 'next') ? nextInstallmentAmount : remainingBalance;
    double amountBs = currentAmountToPay * widget.exchangeRate;
    Map<String, dynamic>? methodData = providerPaymentMethods?[selectedMethod];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Registrar pago",
                    style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: kPrimaryColor)),
                IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.pop(context))
              ],
            ),
            const Divider(),
            const SizedBox(height: 10),
            Text("Selecciona el monto a abonar:",
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800])),
            const SizedBox(height: 10),
            if (showNextOption)
              Row(
                children: [
                  Expanded(
                      child: _OptionCard(
                    title: nextInstallmentLabel,
                    amount: nextInstallmentAmount,
                    isSelected: paymentOption == 'next',
                    color: kPrimaryColor,
                    onTap: () => setState(() => paymentOption = 'next'),
                  )),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _OptionCard(
                    title: "Total restante",
                    amount: remainingBalance,
                    isSelected: paymentOption == 'total',
                    color: Colors.green,
                    onTap: () => setState(() => paymentOption = 'total'),
                  )),
                ],
              )
            else
              _OptionCard(
                  title: "Deuda total restante",
                  amount: remainingBalance,
                  isSelected: true,
                  color: const Color.fromARGB(196, 17, 48, 73),
                  onTap: () {},
                  fullWidth: true),
            const SizedBox(height: 15),
            if (widget.exchangeRate > 0)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE1E8ED)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Monto en bolívares:",
                        style: GoogleFonts.poppins(
                            fontSize: 13, color: Colors.grey[700])),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text("Bs ${amountBs.toStringAsFixed(2)}",
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.black87)),
                        Text("(Tasa: ${widget.exchangeRate})",
                            style: GoogleFonts.poppins(
                                fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 25),
            Text("Método de pago",
                style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: kPrimaryColor)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: selectedMethod,
              isExpanded: true,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              items: availableMethods
                  .map((method) => DropdownMenuItem(
                        value: method,
                        child: Text(method,
                            style: GoogleFonts.poppins(fontSize: 14)),
                      ))
                  .toList(),
              onChanged: (val) {
                setState(() {
                  selectedMethod = val!;
                  refCtrl.clear();
                });
              },
            ),
            const SizedBox(height: 20),
            if (selectedMethod != 'Efectivo' && methodData != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: kPrimaryColor.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: kPrimaryColor.withValues(alpha: 0.15))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.info_outline_rounded,
                          size: 16, color: kPrimaryColor),
                      const SizedBox(width: 8),
                      Text("Datos para transferir",
                          style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: kPrimaryColor)),
                    ]),
                    const Divider(height: 20),
                    if (selectedMethod == 'Pago móvil') ...[
                      _infoRow("Banco", methodData['banco']),
                      _infoRow("Teléfono", methodData['telefono']),
                      _infoRow("Cédula", methodData['cedula']),
                    ] else ...[
                      _infoRow("Cuenta",
                          methodData['correo'] ?? methodData['usuario']),
                      if (methodData['nombre'] != null)
                        _infoRow("Titular", methodData['nombre']),
                    ]
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
            if (selectedMethod != 'Efectivo') ...[
              Text("Datos del comprobante",
                  style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: kPrimaryColor)),
              const SizedBox(height: 10),
              if (selectedMethod == 'Pago móvil') ...[
                _field(bankCtrl, "Tu banco emisor"),
                const SizedBox(height: 10),
                _field(phoneCtrl, "Teléfono asociado",
                    type: TextInputType.phone),
                const SizedBox(height: 10),
                _field(idCtrl, "Cédulada asociada"),
                const SizedBox(height: 10),
                _field(refCtrl, "Referencia (4 últimos dígitos)",
                    icon: Icons.tag),
              ] else ...[
                _field(emailCtrl, "Tu correo"),
                const SizedBox(height: 10),
                _field(refCtrl, "Código de referencia", icon: Icons.tag),
              ]
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.orange.withValues(alpha: 0.3))),
                child: Row(children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Colors.orange, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(
                          "El pago en efectivo se verificará presencialmente.",
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: Colors.orange[900])))
                ]),
              )
            ],
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () async {
                  if (selectedMethod != 'Efectivo' && refCtrl.text.isEmpty) {
                    ScaffoldMessenger.of(widget.parentContext).showSnackBar(
                        const SnackBar(content: Text("Ingresa la referencia")));
                    return;
                  }

                  Navigator.pop(context);

                  try {
                    Map<String, dynamic> paymentDetails = {
                      'method': selectedMethod,
                      'amountBs': amountBs,
                      'currencyRate': widget.exchangeRate,
                      // GUARDAMOS LA FECHA DEL PAGO AQUÍ DIRECTAMENTE PARA ASEGURARNOS
                      'date': Timestamp.now(),
                    };

                    // --- CAMBIO AQUÍ: GUARDAMOS LOS DATOS DEL CLIENTE EN EL HISTORIAL ---
                    if (selectedMethod == 'Pago móvil') {
                      paymentDetails['banco'] = bankCtrl.text;
                      paymentDetails['telefono'] = phoneCtrl.text;
                      paymentDetails['cedula'] = idCtrl.text;
                      paymentDetails['referencia'] = refCtrl.text;
                      paymentDetails['titular'] =
                          widget.booking['name'] ?? 'Cliente';
                    } else if (selectedMethod != 'Efectivo') {
                      paymentDetails['email'] = emailCtrl.text;
                      paymentDetails['referencia'] = refCtrl.text;
                      // Como es un pago secundario (cuota), usamos el nombre de la reserva original
                      paymentDetails['titular'] =
                          widget.booking['name'] ?? 'Cliente';
                    } else {
                      // Si es efectivo
                      paymentDetails['titular'] =
                          widget.booking['name'] ?? 'Cliente';
                    }

                    await Provider.of<BookingProvider>(widget.parentContext,
                            listen: false)
                        .addPaymentToBooking(
                            supplierId: widget.booking['supplier'],
                            bookingId: widget.booking['id'],
                            userId: widget.userId,
                            amountPaid: currentAmountToPay,
                            currentTotalPaid:
                                widget.booking['amountPaid']?.toDouble() ?? 0.0,
                            totalPlanPrice: totalPlanPrice,
                            paymentDetails: paymentDetails);
                    // ignore: empty_catches
                  } catch (e) {}
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(196, 17, 48, 73),
                  shadowColor: const Color.fromARGB(196, 17, 48, 73)
                      .withValues(alpha: 0.4),
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text("Confirmar y enviar",
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String? value) {
    if (value == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Text("$label: ",
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
        SelectableText(value,
            style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black87)),
      ]),
    );
  }

  Widget _field(TextEditingController c, String lbl,
      {TextInputType type = TextInputType.text, IconData? icon}) {
    return TextField(
      controller: c,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: lbl,
        suffixIcon:
            icon != null ? Icon(icon, color: Colors.grey, size: 18) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
        isDense: true,
      ),
      style: GoogleFonts.poppins(fontSize: 14),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final String title;
  final double amount;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;
  final bool fullWidth;

  const _OptionCard({
    required this.title,
    required this.amount,
    required this.isSelected,
    required this.color,
    required this.onTap,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: fullWidth ? double.infinity : null,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 15),
        decoration: BoxDecoration(
            color: isSelected ? color : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: isSelected ? Colors.transparent : Colors.grey.shade200,
                width: 2),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                        color: color.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6))
                  ]
                : []),
        child: Column(
          children: [
            Text(title,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.9)
                        : Colors.grey[600])),
            const SizedBox(height: 8),
            Text("\$${amount.toStringAsFixed(2)}",
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: isSelected ? Colors.white : color)),
          ],
        ),
      ),
    );
  }
}

// --- WIDGET PARA CARGAR EL LINK DE MAPAS DESDE DESTINOS ---
class _MapLinkLoader extends StatelessWidget {
  final String planName;

  const _MapLinkLoader({required this.planName});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('destinos')
          .where('nombre', isEqualTo: planName)
          .limit(1)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final data = snapshot.data!.docs.first.data() as Map<String, dynamic>;
        final String? mapLink = data['googleMapsLink'];

        if (mapLink == null || mapLink.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(left: 18.0, top: 4),
          child: InkWell(
            onTap: () async {
              final messenger = ScaffoldMessenger.of(context);
              final Uri url = Uri.parse(mapLink);
              // Usamos mode: LaunchMode.externalApplication para forzar que abra la app de Mapas
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              } else {
                debugPrint("No se pudo abrir el mapa: $mapLink");
                messenger.showSnackBar(
                  const SnackBar(
                      content: Text("No se pudo abrir el enlace del mapa")),
                );
              }
            },
            child: Text(
              "Ver ubicación en Google Maps",
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: kPrimaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      },
    );
  }
}
