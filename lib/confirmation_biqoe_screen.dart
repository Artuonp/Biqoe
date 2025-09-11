import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:intl/intl.dart';

class ConfirmationBiqoeScreen extends StatefulWidget {
  const ConfirmationBiqoeScreen({super.key});

  @override
  State<ConfirmationBiqoeScreen> createState() =>
      _ConfirmationBiqoeScreenState();
}

class _ConfirmationBiqoeScreenState extends State<ConfirmationBiqoeScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _unconfirmedSearchController =
      TextEditingController();
  final TextEditingController _confirmedSearchController =
      TextEditingController();

  String _unconfirmedSearchQuery = '';
  String _confirmedSearchQuery = '';

  /// Guardamos las reservas traídas desde Firestore. Cada elemento contendrá:
  /// - los campos del documento,
  /// - 'id' -> doc.id,
  /// - 'ref' -> doc.reference,
  /// - 'attendanceConfirmed' -> valor booleano (si no existe, por defecto false).
  List<Map<String, dynamic>> _allReservations = [];
  bool _isLoading = true;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _setupStream();

    _unconfirmedSearchController.addListener(() {
      if (mounted) {
        setState(() {
          _unconfirmedSearchQuery = _unconfirmedSearchController.text;
        });
      }
    });

    _confirmedSearchController.addListener(() {
      if (mounted) {
        setState(() {
          _confirmedSearchQuery = _confirmedSearchController.text;
        });
      }
    });
  }

  /// Escucha en tiempo real TODAS las reservas verificadas (sin filtrar por supplier).
  void _setupStream() {
    FirebaseFirestore.instance
        .collectionGroup('reservas')
        .where('estado', isEqualTo: 'verificado')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _allReservations = snapshot.docs.map((doc) {
            final data = Map<String, dynamic>.from(doc.data() as Map);
            data['id'] = doc.id;
            data['ref'] = doc.reference;
            if (!data.containsKey('attendanceConfirmed')) {
              data['attendanceConfirmed'] = false;
            }
            return data;
          }).toList();
          _isLoading = false;
        });
      }
    }, onError: (error) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al leer reservas: $error')),
        );
      }
    });
  }

  @override
  void dispose() {
    _unconfirmedSearchController.dispose();
    _confirmedSearchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  /// Actualiza en Firestore el campo 'attendanceConfirmed'.
  Future<void> _toggleConfirmation(dynamic ref, bool currentState) async {
    final newState = !currentState;
    try {
      await ref.update({'attendanceConfirmed': newState});

      // Verifica si el widget sigue montado antes de usar context
      if (!mounted) return;

      // Optimista: actualizar la lista local para reflejar el cambio de inmediato
      setState(() {
        final idx = _allReservations.indexWhere((r) => r['ref'] == ref);
        if (idx != -1) {
          _allReservations[idx]['attendanceConfirmed'] = newState;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              newState ? 'Asistencia confirmada' : 'Asistencia desconfirmada'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar: $e')),
      );
    }
  }

  Future<void> _scanQrCode(bool isConfirmedTab) async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const QRScannerScreen()),
    );

    if (result != null && mounted) {
      setState(() {
        if (isConfirmedTab) {
          _confirmedSearchController.text = result;
          _confirmedSearchQuery = result;
        } else {
          _unconfirmedSearchController.text = result;
          _unconfirmedSearchQuery = result;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 243, 248, 255),
      appBar: AppBar(
        title: Text('Confirmación Biqoe (Admin)',
            style: GoogleFonts.poppins(
                color: const Color.fromRGBO(17, 48, 73, 1),
                fontWeight: FontWeight.bold)),
        backgroundColor: const Color.fromARGB(255, 243, 248, 255),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color.fromRGBO(17, 48, 73, 1)),
        bottom: TabBar(
          controller: _tabController,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          labelColor: const Color.fromRGBO(17, 48, 73, 1),
          unselectedLabelColor: Colors.grey.shade600,
          indicatorColor: const Color.fromRGBO(17, 48, 73, 1),
          tabs: const [
            Tab(text: 'No Confirmados'),
            Tab(text: 'Confirmados'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildReservationListView(isConfirmedList: false),
                _buildReservationListView(isConfirmedList: true),
              ],
            ),
    );
  }

  Widget _buildSearchBar({required bool forConfirmed}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: TextField(
        controller: forConfirmed
            ? _confirmedSearchController
            : _unconfirmedSearchController,
        decoration: InputDecoration(
          hintText: 'Buscar por código...',
          hintStyle: GoogleFonts.poppins(),
          prefixIcon:
              const Icon(Icons.search, color: Color.fromRGBO(17, 48, 73, 1)),
          suffixIcon: IconButton(
            icon: const Icon(Icons.qr_code_scanner,
                color: Color.fromRGBO(17, 48, 73, 1)),
            onPressed: () => _scanQrCode(forConfirmed),
          ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30.0),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildReservationListView({required bool isConfirmedList}) {
    final searchQuery =
        (isConfirmedList ? _confirmedSearchQuery : _unconfirmedSearchQuery)
            .toLowerCase();

    final filteredList = _allReservations.where((reserva) {
      final reservaCode = (reserva['code']?.toString() ?? '').toLowerCase();
      final isConfirmed = (reserva['attendanceConfirmed'] == true);
      final matchesSearch =
          searchQuery.isEmpty ? true : reservaCode.contains(searchQuery);

      return (isConfirmed == isConfirmedList) && matchesSearch;
    }).toList();

    return Column(
      children: [
        _buildSearchBar(forConfirmed: isConfirmedList),
        if (filteredList.isEmpty)
          Expanded(
            child: Center(
                child: Text('No hay reservas en esta lista.',
                    style: GoogleFonts.poppins())),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: filteredList.length,
              itemBuilder: (context, index) {
                return _buildReservationCard(filteredList[index]);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildReservationCard(Map<String, dynamic> reservaData) {
    final reservaCode = reservaData['code']?.toString() ?? '';
    final isConfirmed = (reservaData['attendanceConfirmed'] == true);
    final fechaCompra = _parseDate(reservaData['fecha']);
    final dynamic ref = reservaData['ref'];

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              reservaData['planName'] ?? 'Nombre no disponible',
              style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF113049)),
            ),
            const SizedBox(height: 8),
            ..._buildPackageInfo(reservaData),
            ..._buildPaymentInfo(reservaData, fechaCompra),
            ..._buildUserInfo(reservaData),
            // Mostramos proveedor si está disponible
            if (reservaData['supplierName'] != null) ...[
              const SizedBox(height: 12),
              Text('Proveedor:',
                  style: GoogleFonts.poppins(
                      color: const Color.fromRGBO(17, 48, 73, 1),
                      fontSize: 14,
                      fontWeight: FontWeight.bold)),
              Text(reservaData['supplierName'],
                  style: GoogleFonts.poppins(
                      color: const Color.fromRGBO(17, 48, 73, 1),
                      fontSize: 14)),
            ],
            const SizedBox(height: 12),
            // Mostramos el código (útil en admin)
            Text('Código: $reservaCode',
                style: GoogleFonts.poppins(
                    color: const Color.fromARGB(255, 3, 113, 10),
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: ref == null
                    ? null
                    : () => _toggleConfirmation(ref, isConfirmed),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isConfirmed ? Colors.red.shade400 : Colors.green.shade600,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(
                    isConfirmed
                        ? 'Marcar como No Confirmado'
                        : 'Confirmar Asistencia',
                    style: GoogleFonts.poppins(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- FUNCIONES AUXILIARES ---
  List<Widget> _buildPackageInfo(Map<String, dynamic> reservaData) {
    final packages = reservaData['packages'] as List<dynamic>?;
    if (packages == null || packages.isEmpty) return [const SizedBox.shrink()];

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
          padding: const EdgeInsets.only(top: 4.0, left: 4.0),
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
          'Pago: €${totalDolares.toStringAsFixed(2)} | Bs ${totalPriceBs.toStringAsFixed(2)}',
          style: GoogleFonts.poppins(
              color: const Color.fromRGBO(17, 48, 73, 1), fontSize: 14)),
      if (fecha != null) ...[
        Text('Fecha de compra: ${_formatDate(fecha)}',
            style: GoogleFonts.poppins(
                color: const Color.fromRGBO(17, 48, 73, 1), fontSize: 14)),
        Text('Hora de compra: ${_formatTime(fecha)}',
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
      if (reservaData['transactionCode']?.toString().isNotEmpty ?? false)
        Text('Referencia: ${reservaData['transactionCode']}',
            style: GoogleFonts.poppins(
                color: const Color.fromRGBO(17, 48, 73, 1), fontSize: 14)),
      if (reservaData['cedula']?.toString().isNotEmpty ?? false)
        Text('Cédula: ${reservaData['cedula']}',
            style: GoogleFonts.poppins(
                color: const Color.fromRGBO(17, 48, 73, 1), fontSize: 14)),
      if (reservaData['correo']?.toString().isNotEmpty ?? false)
        Text('Correo: ${reservaData['correo']}',
            style: GoogleFonts.poppins(
                color: const Color.fromRGBO(17, 48, 73, 1), fontSize: 14)),
      if (reservaData['numero']?.toString().isNotEmpty ?? false)
        Text('Teléfono: ${reservaData['numero']}',
            style: GoogleFonts.poppins(
                color: const Color.fromRGBO(17, 48, 73, 1), fontSize: 14)),
      const SizedBox(height: 12),
      Text('Datos del usuario:',
          style: GoogleFonts.poppins(
              color: const Color.fromRGBO(17, 48, 73, 1),
              fontSize: 14,
              fontWeight: FontWeight.bold)),
      if (reservaData['name']?.toString().isNotEmpty ?? false)
        Text('Nombre: ${reservaData['name']}',
            style: GoogleFonts.poppins(
                color: const Color.fromRGBO(17, 48, 73, 1), fontSize: 14)),
      if (reservaData['email']?.toString().isNotEmpty ?? false)
        Text('Email: ${reservaData['email']}',
            style: GoogleFonts.poppins(
                color: const Color.fromRGBO(17, 48, 73, 1), fontSize: 14)),
      if (reservaData['celular']?.toString().isNotEmpty ?? false)
        Text('Teléfono: ${reservaData['celular']}',
            style: GoogleFonts.poppins(
                color: const Color.fromRGBO(17, 48, 73, 1), fontSize: 14)),
    ];
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
}

// Mantenemos la misma pantalla de escáner QR (puedes moverla a un archivo común)
class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  bool _isScanned = false;
  MobileScannerController controller = MobileScannerController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Escanear Código QR',
            style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: const Color.fromRGBO(17, 48, 73, 1),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: MobileScanner(
        controller: controller,
        onDetect: (capture) {
          final List<Barcode> barcodes = capture.barcodes;
          if (barcodes.isNotEmpty && !_isScanned) {
            final String? code = barcodes.first.rawValue;
            if (code != null && code.isNotEmpty) {
              setState(() => _isScanned = true);
              controller.stop();

              Navigator.pop(context, code);
            }
          }
        },
      ),
    );
  }
}
