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
        builder: (_) => _SimpleScannerPage(
          // El escáner ya hace su propio Navigator.pop antes de llamar a onDetect.
          // Aquí NO hacemos ningún pop extra: solo procesamos el código.
          onDetect: _processScannedCode,
        ),
      ),
    );
  }

  Future<void> _processScannedCode(String code) async {
    // Mostrar loading
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Procesando código…"),
        duration: Duration(seconds: 1),
      ),
    );

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('reservaciones')
          .doc(widget.supplierId)
          .collection('reservas')
          .where('code', isEqualTo: code)
          .where('planName', isEqualTo: widget.tripName)
          .limit(1)
          .get();

      if (!mounted) return;

      if (querySnapshot.docs.isEmpty) {
        _showMsg("Código no encontrado en esta actividad", isError: true);
        return;
      }

      final doc = querySnapshot.docs.first;
      final data = doc.data();

      // Validar pago verificado
      if (data['estado'] != 'verificado') {
        _showMsg("Esta reserva no está verificada aún.", isError: true);
        return;
      }

      final bool isCheckedIn = data['isCheckedIn'] == true;

      if (isCheckedIn) {
        // Ya fue escaneado — advertencia clara
        _showAlreadyCheckedInWarning(data['name'] ?? 'el cliente', code);
      } else {
        // Primera vez — marcar entrada y guardar timestamp
        await doc.reference.update({
          'isCheckedIn': true,
          'checkInTime': FieldValue.serverTimestamp(),
        });
        _showMsg("¡Bienvenido/a ${data['name']}! ✓ Check-in registrado.");
      }
    } catch (e) {
      if (mounted) _showMsg("Error al procesar código: $e", isError: true);
    }
  }

  void _showAlreadyCheckedInWarning(String name, String code) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.warning_amber_rounded,
            color: Colors.orange, size: 48),
        title: Text('¡Código ya utilizado!',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: Colors.orange[800],
                fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'El código de $name ya fue escaneado anteriormente.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: Colors.orange.withValues(alpha: 0.4))),
              child: Text(
                'Código: $code',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'No se permite el doble ingreso con el mismo QR.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[700],
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              onPressed: () => Navigator.pop(ctx),
              child: Text('Entendido',
                  style: GoogleFonts.poppins(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
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
                        pw.Text("Asistentes",
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

            // --- 3. SWITCH CHECK-IN + BOTÓN RESPUESTAS ---
            Builder(builder: (context) {
              // Extracción robusta de respuestasPreguntas — Firestore SDK puede
              // devolverlo como Map<String,dynamic>, Map<dynamic,dynamic> o
              // incluso como null. Convertimos a Map<String,String> siempre.
              Map<String, String> answers = {};
              try {
                final raw = data['respuestasPreguntas'];
                if (raw is Map && raw.isNotEmpty) {
                  raw.forEach((k, v) {
                    if (v != null && v.toString().trim().isNotEmpty) {
                      answers[k.toString()] = v.toString();
                    }
                  });
                }
              } catch (_) {}

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Insignia QR escaneado (verde, permanente) ──────────
                  if (isCheckedIn)
                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                          color: Colors.green.withAlpha((0.12 * 255).round()),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color:
                                  Colors.green.withAlpha((0.4 * 255).round()),
                              width: 1)),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.qr_code,
                              color: Colors.green, size: 18),
                          Text(
                            'Escaneado',
                            style: GoogleFonts.poppins(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700]),
                          ),
                        ],
                      ),
                    ),

                  // Ícono ? — visible siempre que haya al menos una respuesta
                  if (answers.isNotEmpty)
                    GestureDetector(
                      onTap: () => _showAnswersDialog(context, answers),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 2),
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                            color:
                                kPrimaryColor.withAlpha((0.08 * 255).round()),
                            shape: BoxShape.circle),
                        child: const Icon(Icons.help_outline,
                            color: kPrimaryColor, size: 18),
                      ),
                    ),
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
              );
            })
          ],
        ),
      ),
    );
  }

  void _showAnswersDialog(BuildContext context, Map<String, String> answers) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: kPrimaryColor.withAlpha((0.1 * 255).round()),
                        shape: BoxShape.circle),
                    child: const Icon(Icons.quiz_outlined,
                        color: kPrimaryColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Respuestas del cliente',
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: kPrimaryColor)),
                        Text(
                            (doc.data() as Map<String, dynamic>)['name']
                                    ?.toString() ??
                                '',
                            style: GoogleFonts.poppins(
                                fontSize: 12, color: Colors.grey[600])),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                          color: Colors.grey.shade100, shape: BoxShape.circle),
                      child: const Icon(Icons.close,
                          color: Colors.black54, size: 18),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // Lista de preguntas y respuestas
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.45,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    children: answers.entries.map<Widget>((entry) {
                      final String pregunta = entry.key;
                      final String respuesta =
                          entry.value.isNotEmpty ? entry.value : '—';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: kPrimaryColor.withAlpha((0.04 * 255).round()),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: kPrimaryColor
                                  .withAlpha((0.12 * 255).round())),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.help_outline,
                                size: 16, color: kPrimaryColor),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(pregunta,
                                      style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.w500)),
                                  const SizedBox(height: 4),
                                  Text(respuesta,
                                      style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
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

// --- PANTALLA DE ESCÁNER (StatefulWidget con debounce) ---
class _SimpleScannerPage extends StatefulWidget {
  final Function(String) onDetect;

  const _SimpleScannerPage({required this.onDetect});

  @override
  State<_SimpleScannerPage> createState() => _SimpleScannerPageState();
}

class _SimpleScannerPageState extends State<_SimpleScannerPage> {
  bool _processed = false; // evita disparar múltiples veces
  final MobileScannerController _controller = MobileScannerController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Escanear código QR',
            style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            tooltip: 'Linterna',
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              if (_processed) return; // ya procesamos, ignorar
              final barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  _processed = true;
                  _controller.stop();
                  // Primero cerramos esta pantalla, LUEGO llamamos onDetect
                  Navigator.pop(context);
                  widget.onDetect(barcode.rawValue!);
                  break;
                }
              }
            },
          ),
          // Overlay visual — recuadro de escaneo centrado
          Center(
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Text(
              'Enfoca el código QR dentro del recuadro',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
