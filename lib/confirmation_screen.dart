import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:intl/intl.dart';

class ConfirmationScreen extends StatefulWidget {
  const ConfirmationScreen({super.key});

  @override
  State<ConfirmationScreen> createState() => _ConfirmationScreenState();
}

class _ConfirmationScreenState extends State<ConfirmationScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final TextEditingController _unconfirmedSearchController =
      TextEditingController();
  final TextEditingController _confirmedSearchController =
      TextEditingController();

  String _unconfirmedSearchQuery = '';
  String _confirmedSearchQuery = '';

  // ignore: unintended_html_in_doc_comment
  /// Listado en memoria de reservas (cada elemento es Map<String, dynamic>)
  /// ahora incluye el DocumentReference en la clave 'ref' y el campo
  /// 'attendanceConfirmed' proveniente de Firestore.
  List<Map<String, dynamic>> _allReservations = [];
  bool _isLoading = true;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Escucha en tiempo real las reservas del proveedor
    _setupStream();

    // (Opcional) si quieres migrar códigos locales guardados en SharedPreferences
    // a Firestore, descomenta la siguiente línea o déjala activa para ejecutar
    // la migración automáticamente una vez al iniciar.
    _migrateLocalConfirmedCodesToFirestore();

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

  /// --- STREAM: escucha 'reservas' en todas las subcolecciones (collectionGroup)
  void _setupStream() {
    final user = _auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    FirebaseFirestore.instance
        .collectionGroup('reservas')
        .where('supplier', isEqualTo: user.uid)
        .where('estado', isEqualTo: 'verificado')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _allReservations = snapshot.docs.map((doc) {
            final data = Map<String, dynamic>.from(doc.data() as Map);
            data['id'] = doc.id; // ID del documento
            data['ref'] = doc.reference; // DocumentReference para updates
            // Aseguramos que exista la clave attendanceConfirmed (por si es null)
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

  /// Actualiza en Firestore el campo `attendanceConfirmed` del documento.
  Future<void> _toggleConfirmation(
      DocumentReference ref, bool currentState) async {
    final newState = !currentState;
    try {
      // Actualiza en Firestore — esto se replicará a todos los dispositivos.
      await ref.update({'attendanceConfirmed': newState});

      // Verifica si el widget sigue montado antes de usar context
      if (!mounted) return;

      // Opcional: actualización optimista local para que la UI responda de inmediato
      setState(() {
        final idx = _allReservations.indexWhere((r) => r['ref'] == ref);
        if (idx != -1) {
          _allReservations[idx]['attendanceConfirmed'] = newState;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newState ? 'Asistencia confirmada' : 'Asistencia desconfirmada',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar: $e')),
      );
    }
  }

  /// Escanea un QR y coloca el resultado en la barra de búsqueda correspondiente.
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
        title: Text('Confirmar Asistencia',
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

    // Filtramos leyendo el campo 'attendanceConfirmed' desde cada reserva
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
    final isConfirmed = (reservaData['attendanceConfirmed'] == true);
    final fechaCompra = _parseDate(reservaData['fecha']);
    final dynamic ref =
        reservaData['ref']; // DocumentReference (puede ser null)

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

  // -------------------------------------------------------------------
  // Migración opcional de SharedPreferences -> Firestore
  // -------------------------------------------------------------------
  ///
  /// Si en versiones anteriores guardaste códigos localmente en
  /// 'attendance_confirmed_codes', esta función los busca y actualiza
  /// el campo 'attendanceConfirmed' en los documentos que correspondan
  /// al proveedor actualmente autenticado.
  Future<void> _migrateLocalConfirmedCodesToFirestore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final confirmed = prefs.getStringList('attendance_confirmed_codes') ?? [];
      if (confirmed.isEmpty) return;

      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      for (final code in confirmed) {
        final query = await FirebaseFirestore.instance
            .collectionGroup('reservas')
            .where('code', isEqualTo: code)
            .get();

        for (final doc in query.docs) {
          final data = doc.data();
          if (data['supplier'] == userId) {
            await doc.reference.update({'attendanceConfirmed': true});
          }
        }
      }

      await prefs.remove('attendance_confirmed_codes');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Migración de confirmaciones completada')));
      }
    } catch (e) {
      // Si falla la migración, no bloqueamos la app: solo notificamos.
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error en migración: $e')));
      }
    }
  }
}

// =======================================================================
// PANTALLA PARA EL ESCÁNER DE CÓDIGOS QR
// =======================================================================
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

              // Devolvemos el código a la pantalla anterior
              Navigator.pop(context, code);
            }
          }
        },
      ),
    );
  }
}
