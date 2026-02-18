import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:mobile_scanner/mobile_scanner.dart'; // NECESARIO PARA EL ESCÁNER

// IMPORTAR PANTALLA DE DETALLE DE CLIENTE
import 'customer_detail_screen.dart';

const Color kPrimaryColor = Color.fromRGBO(17, 48, 73, 1);
const Color kBackgroundColor = Color(0xFFF8F9FD);

class ManifestScreen extends StatefulWidget {
  final String supplierId;
  final String tripName;
  final String? tripId;
  final DateTime date;

  const ManifestScreen({
    super.key,
    required this.supplierId,
    required this.tripName,
    required this.date,
    this.tripId,
  });

  @override
  State<ManifestScreen> createState() => _ManifestScreenState();
}

class _ManifestScreenState extends State<ManifestScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // --- LÓGICA DE FILTRADO ---
  bool _filterPassenger(Map<String, dynamic> data, String docId, int tabIndex) {
    // 0. FILTRO CRÍTICO: SOLO VERIFICADOS
    if (data['estado'] != 'verificado') return false;

    // 1. Filtro de Búsqueda
    final String name = (data['name'] ?? '').toString().toLowerCase();
    final String code = (data['code'] ?? '').toString().toLowerCase();
    final String query = _searchQuery.toLowerCase();

    if (query.isNotEmpty && !name.contains(query) && !code.contains(query)) {
      return false;
    }

    // 2. Filtro de Pestaña (Check-in)
    final bool isCheckedIn = data['isCheckedIn'] ?? false;
    if (tabIndex == 1 && !isCheckedIn) return false; // Solo Presentes
    if (tabIndex == 2 && isCheckedIn) return false; // Solo Ausentes

    return true;
  }

  // --- TOGGLE CHECK-IN MANUAL ---
  Future<void> _toggleCheckIn(String docId, bool currentValue) async {
    try {
      await FirebaseFirestore.instance
          .collection('reservaciones')
          .doc(widget.supplierId)
          .collection('reservas')
          .doc(docId)
          .update({'isCheckedIn': !currentValue});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error actualizando: $e")));
      }
    }
  }

  // --- LÓGICA DE ESCÁNER QR ---
  void _openQrScanner() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _SimpleScannerPage(
          onDetect: (String code) => _processScannedCode(code),
        ),
      ),
    );
  }

  Future<void> _processScannedCode(String code) async {
    // Cerrar el escáner inmediatamente
    Navigator.pop(context);

    // Mostrar loading
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Procesando código")),
    );

    try {
      // Buscar la reserva por código Y por nombre del plan (para seguridad)
      final querySnapshot = await FirebaseFirestore.instance
          .collection('reservaciones')
          .doc(widget.supplierId)
          .collection('reservas')
          .where('code', isEqualTo: code)
          .where('planName', isEqualTo: widget.tripName)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        _showMsg("Código no encontrado en esta actividad", isError: true);
        return;
      }

      final doc = querySnapshot.docs.first;
      final data = doc.data();

      // Validar si está verificada la reserva
      if (data['estado'] != 'verificado') {
        _showMsg("Esta reserva no está verificada aún.", isError: true);
        return;
      }

      // Validar si ya está presente
      if (data['isCheckedIn'] == true) {
        _showMsg("El pasajero ${data['name']} YA está presente.",
            isError: false);
      } else {
        // Marcar como presente
        await doc.reference.update(
            {'isCheckedIn': true, 'checkInTime': FieldValue.serverTimestamp()});
        _showMsg("¡Bienvenido/a ${data['name']}! Check-in exitoso.");
      }
    } catch (e) {
      _showMsg("Error al procesar código: $e", isError: true);
    }
  }

  void _showMsg(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : kPrimaryColor,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // --- GENERACIÓN DE PDF ---
  Future<void> _generateAndSharePdf(List<QueryDocumentSnapshot> docs) async {
    final verifiedDocs = docs
        .where((doc) => (doc.data() as Map)['estado'] == 'verificado')
        .toList();

    if (verifiedDocs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("No hay clientes verificados para exportar.")));
      return;
    }

    final pdf = pw.Document();
    final String dateStr = DateFormat('dd/MM/yyyy').format(widget.date);

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                  level: 0,
                  child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text("Manifiesto de Pasajeros",
                            style: pw.TextStyle(
                                fontSize: 24, fontWeight: pw.FontWeight.bold)),
                        pw.Text("Biqoe",
                            style: pw.TextStyle(
                                fontSize: 20, color: PdfColors.grey)),
                      ])),
              pw.SizedBox(height: 20),
              pw.Text("Actividad: ${widget.tripName}",
                  style: pw.TextStyle(fontSize: 14)),
              pw.Text("Fecha: $dateStr", style: pw.TextStyle(fontSize: 14)),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                context: context,
                border: null,
                headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration:
                    const pw.BoxDecoration(color: PdfColors.blue900),
                rowDecoration: const pw.BoxDecoration(
                    border: pw.Border(
                        bottom: pw.BorderSide(color: PdfColors.grey300))),
                cellAlignment: pw.Alignment.centerLeft,
                cellPadding: const pw.EdgeInsets.all(8),
                headers: <String>[
                  'Nombre',
                  'Cédula',
                  'Celular',
                  'Pago',
                  'Status'
                ],
                data: verifiedDocs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  String statusPago = _getPaymentStatusText(data, simple: true);
                  String checkIn =
                      (data['isCheckedIn'] ?? false) ? "Presente" : "Ausente";
                  return [
                    data['name'] ?? 'N/A',
                    data['cedula'] ?? 'N/A',
                    data['celular'] ?? 'N/A',
                    statusPago,
                    checkIn
                  ];
                }).toList(),
              ),
              pw.SizedBox(height: 20),
              pw.Text("Total pasajeros: ${verifiedDocs.length}",
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ],
          );
        },
      ),
    );

    await Printing.sharePdf(
        bytes: await pdf.save(), filename: 'manifiesto_${widget.tripName}.pdf');
  }

  // --- HELPERS VISUALES ---
  String _getPaymentStatusText(Map<String, dynamic> data,
      {bool simple = false}) {
    final method = data['paymentMethod'] ?? '';
    final bool isInstallment = data['isInstallment'] ?? false;
    final int paidCount = data['installmentsPaid'] ?? 0;

    if (method == 'Efectivo') return "Efectivo (Verificado)";

    if (isInstallment) {
      double total = (data['totalPlanPrice'] ?? 0).toDouble();
      double paid = (data['amountPaid'] ?? 0).toDouble();
      // Margen de error para flotantes
      if ((total - paid) > 1.0) {
        return simple ? "$paidCount Cuotas" : "$paidCount cuota(s) abonada(s)";
      }
    }
    return "Totalidad Pagada";
  }

  Color _getPaymentColor(Map<String, dynamic> data) {
    final method = data['paymentMethod'] ?? '';
    final bool isInstallment = data['isInstallment'] ?? false;
    double total = (data['totalPlanPrice'] ?? 0).toDouble();
    double paid = (data['amountPaid'] ?? 0).toDouble();

    if (method == 'Efectivo') return Colors.green;
    if (isInstallment && (total - paid) > 1.0) return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.tripName,
                style: GoogleFonts.poppins(
                    color: kPrimaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
            Text(DateFormat('EEEE d MMM', 'es').format(widget.date),
                style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12)),
          ],
        ),
        actions: [
          StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('reservaciones')
                  .doc(widget.supplierId)
                  .collection('reservas')
                  .where('planName', isEqualTo: widget.tripName)
                  .snapshots(),
              builder: (context, snapshot) {
                return IconButton(
                  icon: const Icon(Icons.share, color: kPrimaryColor),
                  onPressed: (!snapshot.hasData || snapshot.data!.docs.isEmpty)
                      ? null
                      : () => _generateAndSharePdf(snapshot.data!.docs),
                );
              })
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(110),
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  decoration: BoxDecoration(
                      color: kBackgroundColor,
                      borderRadius: BorderRadius.circular(12)),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: "Buscar por nombre o código",
                      hintStyle:
                          GoogleFonts.poppins(fontSize: 13, color: Colors.grey),
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = "");
                              })
                          : null,
                    ),
                  ),
                ),
              ),
              TabBar(
                controller: _tabController,
                labelColor: kPrimaryColor,
                unselectedLabelColor: Colors.grey,
                indicatorColor: kPrimaryColor,
                indicatorWeight: 3,
                labelStyle: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold, fontSize: 13),
                onTap: (index) => setState(() {}),
                tabs: const [
                  Tab(text: "Todos"),
                  Tab(text: "Presentes"),
                  Tab(text: "Ausentes"),
                ],
              ),
            ],
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('reservaciones')
            .doc(widget.supplierId)
            .collection('reservas')
            .where('planName', isEqualTo: widget.tripName)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center();
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState("No hay clientes registrados");
          }

          final allDocs = snapshot.data!.docs;
          // FILTRADO
          final filteredDocs = allDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return _filterPassenger(data, doc.id, _tabController.index);
          }).toList();

          if (filteredDocs.isEmpty) {
            return _buildEmptyState("No se encontraron resultados");
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: filteredDocs.length,
            separatorBuilder: (c, i) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final doc = filteredDocs[index];
              final data = doc.data() as Map<String, dynamic>;

              return _PassengerCard(
                doc: doc,
                onToggleCheckIn: () =>
                    _toggleCheckIn(doc.id, data['isCheckedIn'] ?? false),
                paymentStatus: _getPaymentStatusText(data),
                paymentColor: _getPaymentColor(data),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openQrScanner,
        backgroundColor: kPrimaryColor,
        icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
        label: Text("Escanear",
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }

  Widget _buildEmptyState(String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_search, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 10),
          Text(msg, style: GoogleFonts.poppins(color: Colors.grey)),
        ],
      ),
    );
  }
}

// --- WIDGET TARJETA DE PASAJERO ---
class _PassengerCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final VoidCallback onToggleCheckIn;
  final String paymentStatus;
  final Color paymentColor;

  const _PassengerCard({
    required this.doc,
    required this.onToggleCheckIn,
    required this.paymentStatus,
    required this.paymentColor,
  });

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final bool isCheckedIn = data['isCheckedIn'] ?? false;
    final String code = data['code'] ?? '---';
    final String userId = data['userId'] ?? '';
    final String reservationName = data['name'] ?? 'Sin Nombre';

    // Preparar datos para CustomerDetailScreen
    // Calculamos deuda para pasársela a la pantalla de detalle
    double total = (data['totalPlanPrice'] ?? 0).toDouble();
    double paid = (data['amountPaid'] ?? 0).toDouble();
    double debt = total - paid;

    return InkWell(
      onTap: () {
        // NAVEGACIÓN A DETALLE DE CLIENTE
        final clientMap = {
          'name':
              reservationName, // Será sobreescrito si se carga de la colección usuarios
          'email': data['email'],
          'phone': data['celular'] ?? data['numero'],
          'cedula': data['cedula'],
          'uniqueKey':
              userId.isNotEmpty ? 'UID_$userId' : 'EMAIL_${data['email']}',
          'debt': debt,
          'total_spend': paid,
          'reservation_count': 1,
          'type': userId.isNotEmpty ? 'app' : 'external',
        };

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CustomerDetailScreen(clientData: clientMap),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: isCheckedIn
                    ? kPrimaryColor.withAlpha((0.5 * 255).round())
                    : Colors.transparent,
                width: 1.5),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withAlpha((0.04 * 255).round()),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ]),
        child: Row(
          children: [
            // --- 1. AVATAR CON NOMBRE REAL ---
            userId.isNotEmpty
                ? FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('usuarios')
                        .doc(userId)
                        .get(),
                    builder: (context, snapshot) {
                      String displayName = reservationName;
                      if (snapshot.hasData && snapshot.data!.exists) {
                        displayName =
                            snapshot.data!.get('name') ?? reservationName;
                      }
                      return CircleAvatar(
                        radius: 24,
                        backgroundColor:
                            kPrimaryColor.withAlpha((0.1 * 255).round()),
                        child: Text(
                          displayName.isNotEmpty
                              ? displayName.substring(0, 1).toUpperCase()
                              : '?',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              color: kPrimaryColor,
                              fontSize: 18),
                        ),
                      );
                    },
                  )
                : CircleAvatar(
                    radius: 24,
                    backgroundColor:
                        kPrimaryColor.withAlpha((0.1 * 255).round()),
                    child: Text(
                      reservationName.isNotEmpty
                          ? reservationName.substring(0, 1).toUpperCase()
                          : '?',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          color: kPrimaryColor,
                          fontSize: 18),
                    ),
                  ),

            const SizedBox(width: 16),

            // --- 2. INFO DEL CLIENTE ---
            Expanded(
              child: userId.isNotEmpty
                  ? FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('usuarios')
                          .doc(userId)
                          .get(),
                      builder: (context, snapshot) {
                        String displayName = reservationName;
                        if (snapshot.hasData && snapshot.data!.exists) {
                          displayName =
                              snapshot.data!.get('name') ?? reservationName;
                        }
                        return _buildInfoColumn(displayName, data, code,
                            paymentStatus, paymentColor);
                      })
                  : _buildInfoColumn(
                      reservationName, data, code, paymentStatus, paymentColor),
            ),

            // --- 3. SWITCH CHECK-IN ---
            Column(
              children: [
                Switch(
                  value: isCheckedIn,
                  activeThumbColor: kPrimaryColor,
                  onChanged: (_) => onToggleCheckIn(),
                ),
                Text(
                  isCheckedIn ? "Presente" : "Ausente",
                  style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: isCheckedIn ? kPrimaryColor : Colors.grey),
                )
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildInfoColumn(String name, Map<String, dynamic> data, String code,
      String pStatus, Color pColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name,
            style:
                GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15)),
        Text("CI: ${data['cedula'] ?? '--'} • Cod: $code",
            style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[600])),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
              color: pColor.withAlpha((0.1 * 255).round()),
              borderRadius: BorderRadius.circular(4)),
          child: Text(pStatus,
              style: GoogleFonts.poppins(
                  fontSize: 10, fontWeight: FontWeight.bold, color: pColor)),
        )
      ],
    );
  }
}

// --- PANTALLA SIMPLE DE ESCÁNER ---
class _SimpleScannerPage extends StatelessWidget {
  final Function(String) onDetect;

  const _SimpleScannerPage({required this.onDetect});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Escanear código QR"),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: MobileScanner(
        onDetect: (capture) {
          final List<Barcode> barcodes = capture.barcodes;
          for (final barcode in barcodes) {
            if (barcode.rawValue != null) {
              onDetect(barcode.rawValue!);
              break; // Solo procesamos el primero
            }
          }
        },
      ),
    );
  }
}
