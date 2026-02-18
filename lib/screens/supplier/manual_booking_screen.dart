import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

const Color kPrimaryColor = Color.fromRGBO(17, 48, 73, 1);
const Color kBackgroundColor = Color(0xFFF8F9FD);

class ManualBookingScreen extends StatefulWidget {
  final String supplierId; // <--- AGREGAR ESTO

  const ManualBookingScreen({super.key, required this.supplierId});

  @override
  State<ManualBookingScreen> createState() => _ManualBookingScreenState();
}

class _ManualBookingScreenState extends State<ManualBookingScreen> {
  final _formKey = GlobalKey<FormState>();

  // ELIMINAR O MODIFICAR ESTA LÍNEA:
  // final String _currentSupplierId = FirebaseAuth.instance.currentUser?.uid ?? '';

  // USAR widget.supplierId EN SU LUGAR
  String get _currentSupplierId => widget.supplierId;

  // --- CONTROLADORES CLIENTE ---
  final _searchEmailCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _cedulaCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  // --- CONTROLADORES RESERVA ---
  String? _selectedDestinationId;
  Map<String, dynamic>? _selectedDestinationData;
  Map<String, dynamic>? _selectedPackage;

  final _peopleCtrl = TextEditingController(text: "1");
  final _notesCtrl = TextEditingController();

  DateTime? _selectedDate;
  final List<DateTime> _availableDates = [];

  // --- CONTROLADORES PAGO ---
  final _amountPaidCtrl = TextEditingController();
  String _paymentMethod = "Efectivo";

  // Campos condicionales de pago
  final _paymentRefCtrl =
      TextEditingController(); // Para Pago Móvil, Transferencia
  final _paymentEmailCtrl =
      TextEditingController(); // Para Zelle, Binance, Zinli

  // ESTADO
  bool _isSearching = false;
  bool _userFound = false;
  String? _foundUserId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _peopleCtrl.addListener(() => setState(() {}));
  }

  // --- LÓGICA DE FECHAS DISPONIBLES ---
  void _updateAvailableDates(Map<String, dynamic> package) {
    _availableDates.clear();
    _selectedDate = null;

    if (package['disponibilidad'] != null) {
      for (var item in package['disponibilidad']) {
        DateTime? date;
        if (item['fecha'] != null) {
          date = DateTime.tryParse(item['fecha']);
        } else if (item['fechaInicio'] != null) {
          date = DateTime.tryParse(item['fechaInicio']);
        }

        if (date != null) {
          int cupos = item['cupos'] ?? 0;
          if (cupos > 0) {
            _availableDates.add(date);
          }
        }
      }
    }
    _availableDates.sort();
  }

  bool _isDateSelectable(DateTime day) {
    if (_selectedPackage == null) return true;
    for (DateTime date in _availableDates) {
      if (date.year == day.year &&
          date.month == day.month &&
          date.day == day.day) {
        return true;
      }
    }
    return false;
  }

  // --- BÚSQUEDA USUARIO ---
  Future<void> _searchUser() async {
    if (_searchEmailCtrl.text.isEmpty) return;
    setState(() {
      _isSearching = true;
      _userFound = false;
      _foundUserId = null;
    });

    try {
      final query = await FirebaseFirestore.instance
          .collection('usuarios')
          .where('email', isEqualTo: _searchEmailCtrl.text.trim().toLowerCase())
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final data = query.docs.first.data();
        setState(() {
          _userFound = true;
          _foundUserId = query.docs.first.id;
          _nameCtrl.text = data['name'] ?? '';
          _phoneCtrl.text = data['celular'] ?? '';
          // Cédula no siempre está en el perfil base, pero si estuviera:
          if (data['cedula'] != null) _cedulaCtrl.text = data['cedula'];
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("Usuario encontrado"),
              backgroundColor: Colors.green));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Usuario no encontrado en Biqoe")));
        }
        _emailCtrl.text = _searchEmailCtrl.text;
      }
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      setState(() => _isSearching = false);
    }
  }

  void _resetClient() {
    setState(() {
      _userFound = false;
      _foundUserId = null;
      _searchEmailCtrl.clear();
      _nameCtrl.clear();
      _phoneCtrl.clear();
      _cedulaCtrl.clear();
      _emailCtrl.clear();
    });
  }

  // --- CÁLCULOS ---
  double get _packagePrice => (_selectedPackage != null)
      ? (_selectedPackage!['precio'] as num).toDouble()
      : 0.0;
  int get _peopleCount => int.tryParse(_peopleCtrl.text) ?? 1;
  double get _totalPrice => _packagePrice * _peopleCount;
  double get _amountPaid => double.tryParse(_amountPaidCtrl.text) ?? 0.0;
  double get _debt =>
      (_totalPrice - _amountPaid) < 0 ? 0 : (_totalPrice - _amountPaid);

  // --- GUARDAR RESERVA ---
  Future<void> _saveBooking() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedPackage == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Selecciona un paquete")));
      return;
    }
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Debes seleccionar una fecha disponible")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final docRef = FirebaseFirestore.instance
          .collection('reservaciones')
          .doc(_currentSupplierId)
          .collection('reservas')
          .doc();

      final String status = _debt <= 0
          ? 'verificado'
          : (_amountPaid > 0 ? 'verificado' : 'pendiente');
      final String payStatus = _debt <= 0 ? 'completed' : 'partial';

      // 1. Construir objeto de Pago para el Historial
      // CORRECCIÓN: Usamos DateTime.now() en lugar de FieldValue.serverTimestamp()
      // porque Firestore NO permite serverTimestamp dentro de arrays.
      Map<String, dynamic> initialPayment = {
        'amount': _amountPaid,
        'date': DateTime.now(), // <--- CORREGIDO AQUÍ
        'type': 'initial',
        'method': _paymentMethod,
      };

      // Agregar detalles según método
      if (_paymentMethod == 'Pago móvil' || _paymentMethod == 'Transferencia') {
        initialPayment['referencia'] = _paymentRefCtrl.text.trim();
      }
      if (['Zelle', 'Binance', 'Zinli'].contains(_paymentMethod)) {
        initialPayment['email_pago'] = _paymentEmailCtrl.text.trim();
      }

      final bookingData = {
        'supplier': _currentSupplierId,
        'userId': _foundUserId ?? '', // Si es vacío, es invitado
        'name': _nameCtrl.text.trim(),
        'email': _userFound ? _searchEmailCtrl.text : _emailCtrl.text.trim(),
        'celular': _phoneCtrl.text.trim(),
        'cedula': _cedulaCtrl.text.trim(),
        'planName': _selectedDestinationData?['nombre'] ?? 'Actividad Manual',
        'planLocation': _selectedDestinationData?['ubicacion'] ?? '',
        'fecha': DateFormat('yyyy-MM-dd').format(_selectedDate!),

        // Aquí SÍ se puede usar serverTimestamp porque es nivel raíz
        'createdAt': FieldValue.serverTimestamp(),

        // Datos Financieros Globales
        'totalPlanPrice': _totalPrice,
        'totalPrice': _amountPaid, // Legacy compatibility
        'amountPaid': _amountPaid,
        'paymentStatus': payStatus,
        'paymentMethod': _paymentMethod,

        // Detalles Específicos del Pago (Nivel Raíz - Legacy)
        'transactionCode': _paymentRefCtrl.text.trim(),
        'paymentEmail': _paymentEmailCtrl.text.trim(),

        // HISTORIAL DE PAGOS
        'paymentHistory': _amountPaid > 0 ? [initialPayment] : [],

        'notes': _notesCtrl.text,
        'estado': status,
        'code': 'MAN-${docRef.id.substring(0, 5).toUpperCase()}',
        'read': true,
        'hiddenEvents': [], // Inicializamos vacío para la lógica de ocultar
        'packages': [
          {
            'numero': 1,
            'miniDescripcion':
                _selectedPackage!['miniDescripcion'] ?? 'Estándar',
            'personas': _peopleCount,
            'precio': _packagePrice,
            'tipoDeReserva': 'Manual',
            'fechaReserva': DateFormat('yyyy-MM-dd').format(_selectedDate!),
          }
        ]
      };

      // Guardamos la reserva.
      await docRef.set(bookingData);

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Venta registrada con éxito")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      } else {
        debugPrint("Error: $e");
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- SELECCIONAR FECHA ---
  Future<void> _pickDate() async {
    if (_selectedPackage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Primero selecciona un paquete")));
      return;
    }

    if (_availableDates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Este paquete no tiene fechas disponibles")));
      return;
    }

    DateTime initialDate = DateTime.now();
    if (_availableDates.isNotEmpty) {
      initialDate = _availableDates.first;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      selectableDayPredicate: _isDateSelectable,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: kPrimaryColor,
              onPrimary: Colors.white,
              onSurface: kPrimaryColor,
              surface: Colors.white,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: kPrimaryColor),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Definir si mostramos campos extra de pago
    bool showRef =
        _paymentMethod == 'Pago móvil' || _paymentMethod == 'Transferencia';
    bool showEmail = ['Zelle', 'Binance', 'Zinli'].contains(_paymentMethod);

    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: Text('Registrar reserva',
            style: GoogleFonts.poppins(
                color: kPrimaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. CLIENTE
              _SectionHeader(number: "1", title: "Datos de cliente"),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: _cardDecoration(),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _searchEmailCtrl,
                            enabled: !_userFound,
                            decoration: _inputDecoration(
                                    "Correo para buscar", Icons.search)
                                .copyWith(
                                    suffixIcon: _userFound
                                        ? IconButton(
                                            onPressed: _resetClient,
                                            icon: const Icon(Icons.close,
                                                color: Colors.red))
                                        : null),
                          ),
                        ),
                        const SizedBox(width: 10),
                        if (!_userFound)
                          ElevatedButton(
                            onPressed: _isSearching ? null : _searchUser,
                            style: ElevatedButton.styleFrom(
                                backgroundColor: kPrimaryColor,
                                padding: const EdgeInsets.all(16),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12))),
                            child: _isSearching
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.check, color: Colors.white),
                          )
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (_userFound)
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.shade200)),
                        child: Row(children: [
                          const Icon(Icons.verified_user, color: Colors.green),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Text("Usuario de Biqoe vinculado.",
                                  style: GoogleFonts.poppins(
                                      color: Colors.green[800], fontSize: 12)))
                        ]),
                      ),
                    TextFormField(
                        controller: _nameCtrl,
                        decoration: _inputDecoration(
                            "Nombre completo", Icons.person_outline),
                        validator: (v) => v!.isEmpty ? "Requerido" : null,
                        readOnly: _userFound),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        Expanded(
                            child: TextFormField(
                          controller: _cedulaCtrl,
                          decoration:
                              _inputDecoration("Cédula", Icons.badge_outlined),
                          validator: (v) => v!.isEmpty ? "Requerido" : null,
                        )),
                        const SizedBox(width: 15),
                        Expanded(
                            child: TextFormField(
                                controller: _phoneCtrl,
                                decoration: _inputDecoration(
                                    "Teléfono", Icons.phone_android),
                                keyboardType: TextInputType.phone,
                                validator: (v) =>
                                    v!.isEmpty ? "Requerido" : null,
                                readOnly: _userFound)),
                      ],
                    ),
                    if (!_userFound) ...[
                      const SizedBox(height: 15),
                      TextFormField(
                          controller: _emailCtrl,
                          decoration: _inputDecoration(
                              "Correo (Requerido)", Icons.email_outlined),
                          validator: (v) => v!.isEmpty ? "Requerido" : null,
                          keyboardType: TextInputType.emailAddress),
                    ]
                  ],
                ),
              ),

              const SizedBox(height: 25),

              // 2. SERVICIO
              _SectionHeader(number: "2", title: "Detalles del servicio"),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: _cardDecoration(),
                child: Column(
                  children: [
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('destinos')
                          .where('supplierId', isEqualTo: _currentSupplierId)
                          .where('status', isEqualTo: 'active')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const LinearProgressIndicator();
                        }
                        List<DropdownMenuItem<String>> items = [];
                        for (var doc in snapshot.data!.docs) {
                          items.add(DropdownMenuItem(
                              value: doc.id,
                              child: Text(doc['nombre'],
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis)));
                        }
                        return DropdownButtonFormField<String>(
                          initialValue: _selectedDestinationId,
                          decoration: _inputDecoration("Seleccionar actividad",
                              Icons.local_activity_outlined),
                          isExpanded: true,
                          items: items,
                          onChanged: (val) {
                            setState(() {
                              _selectedDestinationId = val;
                              _selectedDestinationData = snapshot.data!.docs
                                  .firstWhere((d) => d.id == val)
                                  .data() as Map<String, dynamic>;
                              _selectedPackage = null;
                              _selectedDate = null;
                              _availableDates.clear();
                            });
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 15),

                    if (_selectedDestinationId != null &&
                        _selectedDestinationData != null) ...[
                      DropdownButtonFormField<Map<String, dynamic>>(
                        initialValue: _selectedPackage,
                        decoration: _inputDecoration(
                            "Seleccionar paquete", Icons.inventory_2_outlined),
                        isExpanded: true,
                        hint: const Text("Elige una opción"),
                        items: (_selectedDestinationData!['paquetes'] as List)
                            .map<DropdownMenuItem<Map<String, dynamic>>>((pkg) {
                          return DropdownMenuItem(
                              value: pkg,
                              child: Text(
                                  "${pkg['miniDescripcion']} - \$${pkg['precio']}"));
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedPackage = val;
                            _updateAvailableDates(val!);
                          });
                        },
                      ),
                      const SizedBox(height: 15),
                    ],

                    // FECHA Y PERSONAS
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: _pickDate,
                            child: InputDecorator(
                              decoration: _inputDecoration(
                                  "Fecha", Icons.calendar_today),
                              child: Text(
                                _selectedDate == null
                                    ? "Seleccionar"
                                    : DateFormat('dd/MM/yyyy')
                                        .format(_selectedDate!),
                                style: TextStyle(
                                    color: _selectedDate == null
                                        ? Colors.grey
                                        : Colors.black87),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: TextFormField(
                            controller: _peopleCtrl,
                            keyboardType: TextInputType.number,
                            decoration:
                                _inputDecoration("Personas", Icons.group),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),

                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                          color: kPrimaryColor.withAlpha((0.05 * 255).round()),
                          borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Total a pagar:",
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  color: kPrimaryColor)),
                          Text("\$${_totalPrice.toStringAsFixed(2)}",
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: kPrimaryColor)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              // 3. PAGO
              _SectionHeader(number: "3", title: "Registro del pago"),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: _cardDecoration(),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _amountPaidCtrl,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration(
                              "Monto recibido (\$)", Icons.attach_money)
                          .copyWith(
                              helperText:
                                  "Si dejas 0, quedará como deuda total."),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 15),

                    if (_debt > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 12),
                        margin: const EdgeInsets.only(bottom: 15),
                        decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8)),
                        child: Row(children: [
                          const Icon(Icons.warning_amber_rounded,
                              color: Colors.orange, size: 20),
                          const SizedBox(width: 10),
                          Text(
                              "Quedará una deuda de \$${_debt.toStringAsFixed(2)}",
                              style: GoogleFonts.poppins(
                                  color: Colors.orange[800],
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold))
                        ]),
                      ),

                    // MÉTODO DE PAGO
                    DropdownButtonFormField<String>(
                      initialValue: _paymentMethod,
                      decoration:
                          _inputDecoration("Método de pago", Icons.payment),
                      items: [
                        "Efectivo",
                        "Zelle",
                        "Pago móvil",
                        "Transferencia",
                        "Binance",
                        "Zinli",
                      ]
                          .map(
                              (m) => DropdownMenuItem(value: m, child: Text(m)))
                          .toList(),
                      onChanged: (val) => setState(() => _paymentMethod = val!),
                    ),

                    // CAMPOS CONDICIONALES DE PAGO
                    if (showRef) ...[
                      const SizedBox(height: 15),
                      TextFormField(
                        controller: _paymentRefCtrl,
                        decoration: _inputDecoration(
                            "Referencia (últimos 4 dígitos)",
                            Icons.confirmation_number_outlined),
                        validator: (v) =>
                            v!.isEmpty ? "Referencia requerida" : null,
                      ),
                    ],

                    if (showEmail) ...[
                      const SizedBox(height: 15),
                      TextFormField(
                        controller: _paymentEmailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: _inputDecoration(
                            "Correo de la cuenta", Icons.alternate_email),
                        validator: (v) =>
                            v!.isEmpty ? "Correo de pago requerido" : null,
                      ),
                    ]
                  ],
                ),
              ),

              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryColor,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 4),
                  onPressed: _isLoading ? null : _saveBooking,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text("Registrar",
                          style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
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
              color: Colors.black.withAlpha((0.03 * 255).round()),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
        border: Border.all(color: Colors.grey.shade200));
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.grey),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kPrimaryColor)),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String number;
  final String title;
  const _SectionHeader({required this.number, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: const EdgeInsets.only(bottom: 10, left: 4),
        child: Row(children: [
          Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                  color: kPrimaryColor, shape: BoxShape.circle),
              child: Text(number,
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12))),
          const SizedBox(width: 10),
          Text(title,
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: kPrimaryColor))
        ]));
  }
}
