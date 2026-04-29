import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

const Color kPrimaryColor = Color.fromRGBO(17, 48, 73, 1);

// --- EXTENSIÓN PARA MAYÚSCULAS ---
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return "";
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}

class Step4Inventory extends StatefulWidget {
  final Map<String, dynamic> initialData;
  final Function(Map<String, dynamic>) onNext;

  const Step4Inventory({
    super.key,
    required this.initialData,
    required this.onNext,
  });

  @override
  State<Step4Inventory> createState() => _Step4InventoryState();
}

class _Step4InventoryState extends State<Step4Inventory> {
  List<Map<String, dynamic>> _packages = [];

  // 'usd' o 'eur' — divisa seleccionada para todos los paquetes del destino
  String _divisa = 'usd';

  // Devuelve el símbolo según la divisa seleccionada
  String get _currencySymbol => _divisa == 'eur' ? '€' : '\$';

  @override
  void initState() {
    super.initState();
    if (widget.initialData['paquetes'] != null) {
      _packages =
          List<Map<String, dynamic>>.from(widget.initialData['paquetes']);
    }
    // Cargamos la divisa si ya existe (modo edición)
    final savedDivisa = widget.initialData['divisa']?.toString();
    if (savedDivisa == 'eur' || savedDivisa == 'usd') {
      _divisa = savedDivisa!;
    }
  }

  void _showPackageModal({Map<String, dynamic>? existingPackage, int? index}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)),
      ),
      builder: (context) {
        final maxH = MediaQuery.of(context).size.height * 0.92;
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxH),
          child: _PackageForm(
            mainEventName: widget.initialData['nombre'] ?? 'Evento',
            initialPackage: existingPackage,
            divisa: _divisa,
            onSave: (packageData) {
              setState(() {
                if (index != null) {
                  _packages[index] = packageData;
                } else {
                  _packages.add(packageData);
                }
              });
            },
          ),
        );
      },
    );
  }

  void _removePackage(int index) {
    setState(() {
      _packages.removeAt(index);
    });
  }

  void _validateAndContinue() {
    if (_packages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Debes crear al menos una opción de compra')),
      );
      return;
    }
    widget.onNext({'paquetes': _packages, 'divisa': _divisa});
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Paquetes y precios",
            style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: kPrimaryColor),
          ),
          Text(
            "Configura los paquetes disponibles para: ${widget.initialData['nombre'] ?? 'Tu evento'}",
            style: GoogleFonts.poppins(color: Colors.grey),
          ),
          const SizedBox(height: 20),

          // ── SELECTOR DE DIVISA ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 3))
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.currency_exchange,
                        color: kPrimaryColor, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Divisa de los precios',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: kPrimaryColor),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Elige la moneda con la que se mostrarán todos los precios de esta actividad.',
                  style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _DivisaOption(
                      label: 'Dólar (USD)',
                      symbol: '\$',
                      isSelected: _divisa == 'usd',
                      onTap: () => setState(() => _divisa = 'usd'),
                    ),
                    const SizedBox(width: 12),
                    _DivisaOption(
                      label: 'Euro (EUR)',
                      symbol: '€',
                      isSelected: _divisa == 'eur',
                      onTap: () => setState(() => _divisa = 'eur'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (_packages.isEmpty)
            _buildEmptyState()
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _packages.length,
              itemBuilder: (context, index) {
                final pkg = _packages[index];
                IconData icon;
                String typeLabel;

                if (pkg['tipo'] == 'dated') {
                  icon = Icons.calendar_month;
                  typeLabel = "Reserva";
                } else if (pkg['tipo'] == 'flexible') {
                  icon = Icons.confirmation_number_outlined;
                  typeLabel = "Reserva flexible";
                } else {
                  icon = Icons.local_activity;
                  typeLabel = "Ticket";
                }

                // Info de cuotas para mostrar en la tarjeta
                String installmentInfo = "";
                if (pkg['tieneCuotas'] == true) {
                  List cuotas = pkg['configuracionCuotas'] ?? [];
                  installmentInfo =
                      " • ${cuotas.length} cuotas (Inicial: ${cuotas.isNotEmpty ? cuotas[0] : 0}%)";
                }

                return GestureDetector(
                  onTap: () =>
                      _showPackageModal(existingPackage: pkg, index: index),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 15),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4))
                      ],
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: kPrimaryColor.withValues(alpha: 0.1),
                        child: Icon(icon, color: kPrimaryColor, size: 22),
                      ),
                      title: Text("$_currencySymbol${pkg['precio']}",
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.green[700])),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(pkg['miniDescripcion'],
                              style: GoogleFonts.poppins(
                                  fontSize: 12, fontWeight: FontWeight.bold)),
                          Text("$typeLabel$installmentInfo",
                              style: GoogleFonts.poppins(
                                  fontSize: 11, color: Colors.grey)),
                          if (pkg['tipo'] == 'dated')
                            Text(
                                "${pkg['disponibilidad'].length} opciones en calendario",
                                style: GoogleFonts.poppins(
                                    fontSize: 11, color: kPrimaryColor)),
                        ],
                      ),
                      trailing: IconButton(
                        icon:
                            const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _removePackage(index),
                      ),
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showPackageModal(),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
                side: const BorderSide(color: kPrimaryColor, width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.add_circle_outline, color: kPrimaryColor),
              label: Text("Crear paquete",
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: kPrimaryColor,
                      fontSize: 16)),
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
                elevation: 4,
                shadowColor: kPrimaryColor.withValues(alpha: 0.4),
              ),
              onPressed: _validateAndContinue,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Siguiente paso",
                      style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  const SizedBox(width: 10),
                  const Icon(Icons.arrow_forward_rounded, color: Colors.white)
                ],
              ),
            ),
          ),
          const SizedBox(height: 50),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: Colors.blue.shade50, shape: BoxShape.circle),
              child: Icon(Icons.local_offer_outlined,
                  size: 40, color: Colors.blue.shade400),
            ),
            const SizedBox(height: 15),
            Text("Sin paquetes definidos",
                style: GoogleFonts.poppins(
                    color: Colors.grey.shade800, fontWeight: FontWeight.w600)),
            const SizedBox(height: 5),
            Text(
              "Agrega precios y fechas para que los clientes puedan comprar.",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  color: Colors.grey.shade500, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// FORMULARIO MODAL
// =============================================================================

class _PackageForm extends StatefulWidget {
  final Function(Map<String, dynamic>) onSave;
  final String mainEventName;
  final Map<String, dynamic>? initialPackage;
  final String divisa; // 'usd' o 'eur'

  const _PackageForm({
    required this.onSave,
    required this.mainEventName,
    this.initialPackage,
    this.divisa = 'usd',
  });

  @override
  State<_PackageForm> createState() => _PackageFormState();
}

class _PackageFormState extends State<_PackageForm> {
  final _formKey = GlobalKey<FormState>();

  final _miniDescController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();

  String _selectedType = 'dated';
  List<Map<String, dynamic>> _availabilityList = [];

  // VARIABLES PARA CUOTAS MEJORADAS
  bool _hasInstallments = false;
  // Lista de porcentajes (ej: [50.0, 50.0] para 2 cuotas)
  List<double> _installmentPercentages = [50.0, 50.0];

  @override
  void initState() {
    super.initState();
    if (widget.initialPackage != null) {
      final pkg = widget.initialPackage!;
      _selectedType = pkg['tipo'];
      _miniDescController.text = pkg['miniDescripcion'];
      _descController.text = pkg['descripcion'];
      _priceController.text = pkg['precio'].toString();

      // --- CORRECCIÓN AQUÍ: Cargar configuración de cuotas ---
      _hasInstallments = pkg['tieneCuotas'] ?? false;
      if (pkg['configuracionCuotas'] != null) {
        // Convertimos la lista dinámica a lista de doubles
        _installmentPercentages = List<double>.from(
            pkg['configuracionCuotas'].map((e) => e.toDouble()));
      }
      // -------------------------------------------------------

      if (pkg['cuposDisponibles'] != null && pkg['cuposDisponibles'] > 0) {
        _stockController.text = pkg['cuposDisponibles'].toString();
      }

      if (pkg['disponibilidad'] != null) {
        _availabilityList =
            List<Map<String, dynamic>>.from(pkg['disponibilidad']);
      }
    }
  }

  InputDecoration _inputDeco(
      {required String label,
      String? hint,
      IconData? icon,
      String? helper,
      bool alignLabelWithHint = false}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helper,
      helperStyle: GoogleFonts.poppins(fontSize: 10, color: Colors.grey),
      prefixIcon:
          icon != null ? Icon(icon, color: Colors.grey[600], size: 20) : null,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kPrimaryColor, width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      filled: true,
      fillColor: Colors.grey.shade50,
      alignLabelWithHint: alignLabelWithHint,
    );
  }

  void _openDateGenerator() async {
    final result = await showDialog<List<Map<String, dynamic>>>(
      context: context,
      builder: (context) => _DateGeneratorDialog(),
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        _availabilityList.addAll(result);
        _availabilityList
            .sort((a, b) => a['fechaInicio'].compareTo(b['fechaInicio']));
      });
    }
  }

  // --- LÓGICA DE CUOTAS ---
  void _updateInstallmentCount(int count) {
    setState(() {
      // Reiniciar porcentajes equitativos al cambiar cantidad
      double equalShare = double.parse((100 / count).toStringAsFixed(1));
      // Ajustar el último para que sume 100 exacto
      double remainder = 100 - (equalShare * (count - 1));

      _installmentPercentages = List.generate(count, (index) {
        return index == count - 1 ? remainder : equalShare;
      });
    });
  }

  void _updatePercentage(int index, String val) {
    double? newVal = double.tryParse(val);
    if (newVal != null) {
      setState(() {
        _installmentPercentages[index] = newVal;
      });
    }
  }

  double _calculateTotalPercentage() {
    return _installmentPercentages.fold(0, (sum, item) => sum + item);
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      if (_selectedType == 'dated' && _availabilityList.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                "Debes agregar al menos una fecha o rango al calendario")));
        return;
      }

      // Validación de suma de cuotas
      if (_hasInstallments) {
        double total = _calculateTotalPercentage();
        if ((total - 100).abs() > 0.1) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                "La suma de las cuotas debe ser 100% (Actual: ${total.toStringAsFixed(1)}%)"),
            backgroundColor: Colors.red,
          ));
          return;
        }
      }

      final newPkg = {
        'nombre': widget.mainEventName,
        'miniDescripcion': _miniDescController.text.trim(),
        'descripcion': _descController.text.trim(),
        'precio': double.tryParse(_priceController.text) ?? 0.0,
        'tipo': _selectedType,
        'cuposDisponibles': _selectedType == 'fixed'
            ? int.tryParse(_stockController.text) ?? 0
            : 0,
        'disponibilidad': _selectedType == 'dated' ? _availabilityList : [],

        // --- CORRECCIÓN AQUÍ: Guardar explícitamente la cantidad ---
        'tieneCuotas': _hasInstallments,
        'configuracionCuotas': _hasInstallments ? _installmentPercentages : [],
        'cantidadCuotas': _hasInstallments
            ? _installmentPercentages.length
            : 1, // <--- ESTA LÍNEA FALTABA
        // -----------------------------------------------------------
      };

      widget.onSave(newPkg);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          top: 10,
          left: 20,
          right: 20),
      child: Form(
        key: _formKey,
        // ScrollConfiguration elimina el glow de scroll que queda en el modal
        child: ScrollConfiguration(
          behavior: const ScrollBehavior().copyWith(overscroll: false),
          child: ListView(
            // shrinkWrap: false para que ocupe toda la altura disponible
            // y permita scroll sin importar dónde toque el usuario
            shrinkWrap: true,
            children: [
              // --- DRAG HANDLE (decorativo, centrado) ---
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 14),
              // --- TÍTULO + X en la misma fila, perfectamente alineados ---
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                        widget.initialPackage == null
                            ? "Crear nuevo paquete"
                            : "Editar paquete",
                        style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: kPrimaryColor)),
                  ),
                  // La X queda alineada al centro del título gracias al CrossAxisAlignment.center
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close,
                          color: Colors.black54, size: 20),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // --- SELECTOR DE TIPO ---
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _TypeCard(
                        label: "Reserva\n(Calendario)",
                        icon: Icons.calendar_month,
                        isSelected: _selectedType == 'dated',
                        onTap: () => setState(() => _selectedType = 'dated')),
                    const SizedBox(width: 10),
                    _TypeCard(
                        label: "Reserva\n(Flexible)",
                        icon: Icons.confirmation_number_outlined,
                        isSelected: _selectedType == 'flexible',
                        onTap: () =>
                            setState(() => _selectedType = 'flexible')),
                    const SizedBox(width: 10),
                    _TypeCard(
                        label: "Ticket\n(Eventos)",
                        icon: Icons.local_activity,
                        isSelected: _selectedType == 'fixed',
                        onTap: () => setState(() => _selectedType = 'fixed')),
                  ],
                ),
              ),
              const SizedBox(height: 25),

              // --- 1. MINI DESCRIPCIÓN ---
              TextFormField(
                controller: _miniDescController,
                decoration: _inputDeco(
                    label: "Mini descripción",
                    hint: "Ej: Full, Básico o Por pareja",
                    helper: "Por defecto colocar: Por persona"),
                validator: (v) => v!.isEmpty ? "Este campo es requerido" : null,
              ),
              const SizedBox(height: 15),

              // --- 2. DESCRIPCIÓN COMPLETA ---
              TextFormField(
                controller: _descController,
                decoration: _inputDeco(
                    label: "Descripción completa",
                    hint:
                        "Explica lo que incluye este paquete y toda la información relevante de la actividad",
                    helper:
                        "**Palabra** para negritas y guiones (-) para listas ",
                    alignLabelWithHint: true),
                maxLines: 3,
                validator: (v) => v!.isEmpty ? "Este campo es requerido" : null,
              ),
              const SizedBox(height: 15),

              // --- 3. PRECIO ---
              TextFormField(
                controller: _priceController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: _inputDeco(
                    label: widget.divisa == 'eur'
                        ? "Precio total (en euros)"
                        : "Precio total (en dólares)",
                    icon: widget.divisa == 'eur'
                        ? Icons.euro
                        : Icons.attach_money),
                validator: (v) => v!.isEmpty ? "Requerido" : null,
                onChanged: (val) => setState(
                    () {}), // Actualizar vista para recálculo de cuotas
              ),

              // --- NUEVA SECCIÓN DE CUOTAS AVANZADA ---
              const SizedBox(height: 15),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text("Ofrecer pago en cuotas",
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                      value: _hasInstallments,
                      activeThumbColor: kPrimaryColor,
                      onChanged: (val) => setState(() {
                        _hasInstallments = val;
                        if (val) {
                          _updateInstallmentCount(2); // Reset to 2 defaults
                        }
                      }),
                    ),
                    if (_hasInstallments) ...[
                      const Divider(),
                      // SELECTOR DE CANTIDAD
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Cantidad de cuotas:",
                              style: GoogleFonts.poppins(
                                  fontSize: 13, color: Colors.grey[700])),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                color: kPrimaryColor,
                                onPressed: _installmentPercentages.length > 2
                                    ? () => _updateInstallmentCount(
                                        _installmentPercentages.length - 1)
                                    : null,
                              ),
                              Text("${_installmentPercentages.length}",
                                  style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                color: kPrimaryColor,
                                onPressed: _installmentPercentages.length < 12
                                    ? () => _updateInstallmentCount(
                                        _installmentPercentages.length + 1)
                                    : null,
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // LISTA DE EDICIÓN DE PORCENTAJES
                      Text("Define el % de cada cuota (Debe sumar 100%)",
                          style: GoogleFonts.poppins(
                              fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 8),
                      ...List.generate(_installmentPercentages.length, (index) {
                        double totalPrice =
                            double.tryParse(_priceController.text) ?? 0;
                        double percentage = _installmentPercentages[index];
                        double amount = totalPrice * (percentage / 100);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            children: [
                              SizedBox(
                                  width: 80,
                                  child: Text(
                                      index == 0 ? "Inicial" : "Cuota $index",
                                      style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold))),
                              Expanded(
                                child: TextFormField(
                                  initialValue:
                                      percentage.toString(), // Muestra 50.0
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                      suffixText: "%",
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              vertical: 8, horizontal: 10),
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                      isDense: true),
                                  onChanged: (val) =>
                                      _updatePercentage(index, val),
                                ),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                width: 80,
                                child: Text(
                                    "${widget.divisa == 'eur' ? '€' : '\$'}${amount.toStringAsFixed(2)}",
                                    textAlign: TextAlign.end,
                                    style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.green[700])),
                              )
                            ],
                          ),
                        );
                      }),

                      // TOTALIZADOR
                      const SizedBox(height: 5),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                              "Total: ${_calculateTotalPercentage().toStringAsFixed(1)}%",
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  color: (_calculateTotalPercentage() - 100)
                                              .abs() <
                                          0.1
                                      ? kPrimaryColor
                                      : Colors.red)),
                        ],
                      )
                    ]
                  ],
                ),
              ),

              // --- STOCK (Solo si es Fijo) ---
              if (_selectedType == 'fixed') ...[
                const SizedBox(height: 15),
                TextFormField(
                    controller: _stockController,
                    keyboardType: TextInputType.number,
                    decoration: _inputDeco(
                        label: "Cupos disponibles", icon: Icons.people_alt),
                    validator: (v) => v!.isEmpty ? "Requerido" : null),
              ],

              // --- GESTIÓN DE FECHAS ---
              if (_selectedType == 'dated') ...[
                const SizedBox(height: 30),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300)),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Calendario de actividades",
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  color: kPrimaryColor)),
                          Text("${_availabilityList.length} opciones",
                              style: GoogleFonts.poppins(
                                  fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                      const SizedBox(height: 15),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _openDateGenerator,
                          style: OutlinedButton.styleFrom(
                              foregroundColor: kPrimaryColor,
                              side: const BorderSide(color: kPrimaryColor),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8))),
                          icon: const Icon(Icons.date_range, size: 18),
                          label: Text("Agregar fechas",
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ),

                // LISTA DE FECHAS GENERADAS
                if (_availabilityList.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 10),
                    constraints: const BoxConstraints(maxHeight: 150),
                    child: ListView.separated(
                      itemCount: _availabilityList.length,
                      separatorBuilder: (c, i) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = _availabilityList[index];
                        // Formatear display
                        String dateDisplay;
                        if (item['tipo'] == 'rango') {
                          String start = DateFormat('dd MMM', 'es')
                              .format(DateTime.parse(item['fechaInicio']))
                              .capitalize();
                          String end = DateFormat('dd MMM, yyyy', 'es')
                              .format(DateTime.parse(item['fechaFin']))
                              .capitalize();
                          dateDisplay = "Del $start al $end";
                        } else {
                          dateDisplay = DateFormat('EEEE d MMM, yyyy', 'es')
                              .format(DateTime.parse(item['fechaInicio']))
                              .capitalize();
                        }

                        String timeDisplay = item['horaInicio'];
                        if (item['horaFin'] != null &&
                            item['horaFin'].isNotEmpty) {
                          timeDisplay += " - ${item['horaFin']}";
                        }

                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                              item['tipo'] == 'rango'
                                  ? Icons.date_range
                                  : Icons.event,
                              color: kPrimaryColor,
                              size: 20),
                          title: Text(dateDisplay,
                              style: GoogleFonts.poppins(
                                  fontSize: 13, fontWeight: FontWeight.w600)),
                          subtitle:
                              Text("$timeDisplay • ${item['cupos']} cupos"),
                          trailing: IconButton(
                            icon: const Icon(Icons.close,
                                color: Colors.red, size: 18),
                            onPressed: () => setState(
                                () => _availabilityList.removeAt(index)),
                          ),
                        );
                      },
                    ),
                  ),
              ],

              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryColor,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  onPressed: _save,
                  child: Text(
                      widget.initialPackage == null
                          ? "Guardar opción"
                          : "Actualizar opción",
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
      ),
    );
  }
}

// =============================================================================
// DIALOGO GENERADOR DE FECHAS (3 PESTAÑAS)
// =============================================================================

class _DateGeneratorDialog extends StatefulWidget {
  @override
  State<_DateGeneratorDialog> createState() => _DateGeneratorDialogState();
}

class _DateGeneratorDialogState extends State<_DateGeneratorDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Variables Tab 1 (Calendario Específico)
  final Set<DateTime> _selectedSpecificDays = {};

  // Variables Tab 2 (Recurrente)
  final List<int> _selectedWeekdays = [6, 7];

  // Variables Tab 3 (Rango/Tour)
  DateTime? _rangeStart;
  DateTime? _rangeEnd;

  // Comunes
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay? _endTime; // Opcional
  final TextEditingController _stockController =
      TextEditingController(text: "15");

  DateTime _focusedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  // --- LÓGICA DE GENERACIÓN ---

  // 1. Días Específicos: Genera un item por cada día seleccionado
  void _generateSpecific() {
    if (_selectedSpecificDays.isEmpty) return;
    _generateItemsFromList(_selectedSpecificDays.toList(), 'dia');
  }

  // 2. Recurrente: Genera un item por cada día que coincida
  void _generateRecurring() {
    if (_selectedWeekdays.isEmpty) return;
    final now = DateTime.now();
    final endOfYear = DateTime(now.year + 1, 12, 31);

    List<DateTime> dates = [];
    DateTime current = now;
    while (current.isBefore(endOfYear)) {
      if (_selectedWeekdays.contains(current.weekday)) {
        dates.add(current);
      }
      current = current.add(const Duration(days: 1));
    }
    _generateItemsFromList(dates, 'dia');
  }

  // 3. Rango/Tour: Genera UN SOLO ITEM que representa el lapso
  void _generateRangeTour() {
    if (_rangeStart == null || _rangeEnd == null) return;
    if (_stockController.text.isEmpty) return;

    // Guardamos un objeto tipo "rango"
    final item = {
      'tipo': 'rango',
      'fechaInicio': DateFormat('yyyy-MM-dd').format(_rangeStart!),
      'fechaFin': DateFormat('yyyy-MM-dd').format(_rangeEnd!),
      'horaInicio': _startTime.format(context),
      'horaFin': _endTime?.format(context) ?? '',
      'cupos': int.parse(_stockController.text),
    };
    Navigator.pop(context, [item]);
  }

  void _generateItemsFromList(List<DateTime> dates, String tipo) {
    if (_stockController.text.isEmpty) return;

    List<Map<String, dynamic>> generatedItems = [];
    int stock = int.parse(_stockController.text);
    String startStr = _startTime.format(context);
    String endStr = _endTime?.format(context) ?? '';

    for (var date in dates) {
      generatedItems.add({
        'tipo': tipo,
        'fechaInicio': DateFormat('yyyy-MM-dd').format(date),
        'fechaFin': DateFormat('yyyy-MM-dd').format(date), // Mismo día
        'horaInicio': startStr,
        'horaFin': endStr,
        'cupos': stock,
      });
    }
    Navigator.pop(context, generatedItems);
  }

  @override
  Widget build(BuildContext context) {
    // TEMA FORZADO (AZUL)
    // GestureDetector exterior: al tocar cualquier parte del diálogo que no sea
    // un campo de texto, oculta el teclado. Crítico en iOS/Apple donde el teclado
    // bloquea la interacción con el calendario si se tocó la casilla de cupos antes.
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.translucent,
      child: Theme(
        data: Theme.of(context).copyWith(
          primaryColor: kPrimaryColor,
          colorScheme: const ColorScheme.light(
              primary: kPrimaryColor, onPrimary: Colors.white),
        ),
        child: AlertDialog(
          contentPadding: EdgeInsets.zero,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: SizedBox(
            width: double.maxFinite,
            height: 520, // Altura ajustada
            child: Column(
              children: [
                // Header Tabs
                Container(
                  decoration: const BoxDecoration(
                    color: kPrimaryColor,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: Colors.white,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white60,
                    labelStyle: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600, fontSize: 12),
                    tabs: const [
                      Tab(text: "Días"),
                      Tab(text: "Días del año"),
                      Tab(text: "Rango"),
                    ],
                  ),
                ),

                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // --- TAB 1: CALENDARIO MULTI-SELECCIÓN ---
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          children: [
                            Text("Toca días salteados para seleccionarlos.",
                                style: GoogleFonts.poppins(
                                    fontSize: 12, color: Colors.grey)),
                            Expanded(
                              child: TableCalendar(
                                locale: 'es_ES',
                                firstDay: DateTime.now(),
                                lastDay: DateTime.now()
                                    .add(const Duration(days: 365)),
                                focusedDay: _focusedDay,
                                calendarFormat: CalendarFormat.month,
                                shouldFillViewport: true,
                                headerStyle: HeaderStyle(
                                  titleCentered: true,
                                  formatButtonVisible: false,
                                  titleTextFormatter: (date, locale) =>
                                      DateFormat.yMMMM(locale)
                                          .format(date)
                                          .capitalize(),
                                  titleTextStyle: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14),
                                  leftChevronIcon: const Icon(
                                      Icons.chevron_left,
                                      color: kPrimaryColor),
                                  rightChevronIcon: const Icon(
                                      Icons.chevron_right,
                                      color: kPrimaryColor),
                                ),
                                calendarStyle: CalendarStyle(
                                  selectedDecoration: const BoxDecoration(
                                      color: kPrimaryColor,
                                      shape: BoxShape.circle),
                                  todayDecoration: BoxDecoration(
                                      color:
                                          kPrimaryColor.withValues(alpha: 0.3),
                                      shape: BoxShape.circle),
                                  todayTextStyle: const TextStyle(
                                      color: kPrimaryColor,
                                      fontWeight: FontWeight.bold),
                                ),
                                daysOfWeekStyle: DaysOfWeekStyle(
                                  dowTextFormatter: (date, locale) =>
                                      DateFormat.E(locale)
                                          .format(date)
                                          .capitalize(),
                                ),
                                selectedDayPredicate: (day) =>
                                    _selectedSpecificDays
                                        .any((d) => isSameDay(d, day)),
                                onDaySelected: (selectedDay, focusedDay) {
                                  // Cerrar teclado si estaba abierto (iOS/Apple)
                                  FocusScope.of(context).unfocus();
                                  setState(() {
                                    _focusedDay = focusedDay;
                                    if (_selectedSpecificDays.any(
                                        (d) => isSameDay(d, selectedDay))) {
                                      _selectedSpecificDays.removeWhere(
                                          (d) => isSameDay(d, selectedDay));
                                    } else {
                                      _selectedSpecificDays.add(selectedDay);
                                    }
                                  });
                                },
                              ),
                            ),
                            const Divider(),
                            _buildCommonFields(),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: kPrimaryColor),
                                onPressed: _selectedSpecificDays.isEmpty
                                    ? null
                                    : _generateSpecific,
                                child: Text(
                                    "Agregar ${_selectedSpecificDays.length} fechas",
                                    style:
                                        const TextStyle(color: Colors.white)),
                              ),
                            )
                          ],
                        ),
                      ),

                      // --- TAB 2: RECURRENTE ---
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Text("Estos días aplicarán para todo el año.",
                                style: GoogleFonts.poppins(
                                    fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 20),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              alignment: WrapAlignment.center,
                              children: [
                                _DayToggle(
                                    label: "Lun",
                                    day: 1,
                                    selected: _selectedWeekdays,
                                    onToggle: _toggleDay),
                                _DayToggle(
                                    label: "Mar",
                                    day: 2,
                                    selected: _selectedWeekdays,
                                    onToggle: _toggleDay),
                                _DayToggle(
                                    label: "Mié",
                                    day: 3,
                                    selected: _selectedWeekdays,
                                    onToggle: _toggleDay),
                                _DayToggle(
                                    label: "Jue",
                                    day: 4,
                                    selected: _selectedWeekdays,
                                    onToggle: _toggleDay),
                                _DayToggle(
                                    label: "Vie",
                                    day: 5,
                                    selected: _selectedWeekdays,
                                    onToggle: _toggleDay),
                                _DayToggle(
                                    label: "Sáb",
                                    day: 6,
                                    selected: _selectedWeekdays,
                                    onToggle: _toggleDay),
                                _DayToggle(
                                    label: "Dom",
                                    day: 7,
                                    selected: _selectedWeekdays,
                                    onToggle: _toggleDay),
                              ],
                            ),
                            const Spacer(),
                            const Divider(),
                            _buildCommonFields(),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: kPrimaryColor),
                                onPressed: _selectedWeekdays.isEmpty
                                    ? null
                                    : _generateRecurring,
                                child: const Text("Generar anual",
                                    style: TextStyle(color: Colors.white)),
                              ),
                            )
                          ],
                        ),
                      ),

                      // --- TAB 3: RANGO / TOUR (Calendario estilo rango) ---
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          children: [
                            Text(
                                "Selecciona inicio y fin de una sola actividad\n(ej: Viaje de 3 días).",
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                    fontSize: 12, color: Colors.grey)),
                            Expanded(
                              child: TableCalendar(
                                locale: 'es_ES',
                                firstDay: DateTime.now(),
                                lastDay: DateTime.now()
                                    .add(const Duration(days: 365)),
                                focusedDay: _focusedDay,
                                calendarFormat: CalendarFormat.month,
                                shouldFillViewport: true,
                                rangeSelectionMode: RangeSelectionMode
                                    .toggledOn, // MODO RANGO ACTIVADO
                                headerStyle: HeaderStyle(
                                  titleCentered: true,
                                  formatButtonVisible: false,
                                  titleTextFormatter: (date, locale) =>
                                      DateFormat.yMMMM(locale)
                                          .format(date)
                                          .capitalize(),
                                  titleTextStyle: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14),
                                  leftChevronIcon: const Icon(
                                      Icons.chevron_left,
                                      color: kPrimaryColor),
                                  rightChevronIcon: const Icon(
                                      Icons.chevron_right,
                                      color: kPrimaryColor),
                                ),
                                calendarStyle: CalendarStyle(
                                  rangeHighlightColor:
                                      kPrimaryColor.withValues(alpha: 0.2),
                                  rangeStartDecoration: const BoxDecoration(
                                      color: kPrimaryColor,
                                      shape: BoxShape.circle),
                                  rangeEndDecoration: const BoxDecoration(
                                      color: kPrimaryColor,
                                      shape: BoxShape.circle),
                                  todayDecoration: BoxDecoration(
                                      color:
                                          kPrimaryColor.withValues(alpha: 0.3),
                                      shape: BoxShape.circle),
                                ),
                                daysOfWeekStyle: DaysOfWeekStyle(
                                  dowTextFormatter: (date, locale) =>
                                      DateFormat.E(locale)
                                          .format(date)
                                          .capitalize(),
                                ),
                                rangeStartDay: _rangeStart,
                                rangeEndDay: _rangeEnd,
                                onRangeSelected: (start, end, focusedDay) {
                                  // Cerrar teclado si estaba abierto (iOS/Apple)
                                  FocusScope.of(context).unfocus();
                                  setState(() {
                                    _rangeStart = start;
                                    _rangeEnd = end;
                                    _focusedDay = focusedDay;
                                  });
                                },
                              ),
                            ),
                            const Divider(),
                            _buildCommonFields(),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: kPrimaryColor),
                                onPressed:
                                    (_rangeStart != null && _rangeEnd != null)
                                        ? _generateRangeTour
                                        : null,
                                child: const Text("Guardar rango",
                                    style: TextStyle(color: Colors.white)),
                              ),
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancelar",
                    style: TextStyle(color: Colors.grey))),
          ],
        ),
      ), // Theme
    ); // GestureDetector
  }

  // --- CAMPOS COMUNES (Hora inicio, fin y cupos) ---
  Widget _buildCommonFields() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _TimePickerField(
                  label: "Hora de inicio",
                  time: _startTime,
                  onChanged: (t) => setState(() => _startTime = t)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _TimePickerField(
                  label: "Hora de fin (opcional)",
                  time: _endTime,
                  isOptional: true,
                  onChanged: (t) => setState(() => _endTime = t)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Icon(Icons.people_alt_outlined, size: 18, color: Colors.grey),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _stockController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: "Cupos disponibles",
                    contentPadding:
                        EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                    border: OutlineInputBorder(),
                    isDense: true),
              ),
            ),
          ],
        )
      ],
    );
  }

  void _toggleDay(int day) {
    setState(() {
      if (_selectedWeekdays.contains(day)) {
        _selectedWeekdays.remove(day);
      } else {
        _selectedWeekdays.add(day);
      }
    });
  }
}

// ── Widget selector de divisa ─────────────────────────────────────────────────
class _DivisaOption extends StatelessWidget {
  final String label;
  final String symbol;
  final bool isSelected;
  final VoidCallback onTap;

  const _DivisaOption({
    required this.label,
    required this.symbol,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
              color: isSelected ? kPrimaryColor : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: isSelected ? kPrimaryColor : Colors.grey.shade300,
                  width: isSelected ? 2 : 1),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                          color: kPrimaryColor.withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4))
                    ]
                  : []),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                symbol,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : Colors.grey[600]),
              ),
              const SizedBox(width: 8),
              Text(label,
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : Colors.grey[700])),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimePickerField extends StatelessWidget {
  final String label;
  final TimeOfDay? time;
  final bool isOptional;
  final Function(TimeOfDay) onChanged;

  const _TimePickerField(
      {required this.label,
      required this.time,
      required this.onChanged,
      this.isOptional = false});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final t = await showTimePicker(
            context: context,
            initialTime: time ?? const TimeOfDay(hour: 12, minute: 0),
            builder: (context, child) {
              return Theme(
                  data: Theme.of(context).copyWith(
                      colorScheme:
                          const ColorScheme.light(primary: kPrimaryColor)),
                  child: child!);
            });
        if (t != null) onChanged(t);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey)),
            Text(time != null ? time!.format(context) : "--:--",
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _DayToggle extends StatelessWidget {
  final String label;
  final int day;
  final List<int> selected;
  final Function(int) onToggle;

  const _DayToggle(
      {required this.label,
      required this.day,
      required this.selected,
      required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final isSelected = selected.contains(day);
    return GestureDetector(
      onTap: () => onToggle(day),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
            color: isSelected ? kPrimaryColor : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: isSelected ? kPrimaryColor : Colors.grey.shade300)),
        child: Text(label,
            style: TextStyle(
                color: isSelected ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 12)),
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeCard(
      {required this.label,
      required this.icon,
      required this.isSelected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
            color: isSelected ? kPrimaryColor : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: isSelected ? kPrimaryColor : Colors.grey.shade300,
                width: isSelected ? 2 : 1),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                        color: kPrimaryColor.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4))
                  ]
                : []),
        child: Column(
          children: [
            Icon(icon,
                color: isSelected ? Colors.white : Colors.grey, size: 24),
            const SizedBox(height: 8),
            Text(label,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: isSelected ? Colors.white : Colors.grey[700],
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
