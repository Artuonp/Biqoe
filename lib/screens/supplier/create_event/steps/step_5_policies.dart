import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';

const Color kPrimaryColor = Color.fromRGBO(17, 48, 73, 1);

class Step5Policies extends StatefulWidget {
  final Map<String, dynamic> initialData;
  final Function(Map<String, dynamic>) onNext;

  const Step5Policies({
    super.key,
    required this.initialData,
    required this.onNext,
  });

  @override
  State<Step5Policies> createState() => _Step5PoliciesState();
}

class _Step5PoliciesState extends State<Step5Policies> {
  // --- ESTADO DEL FORMULARIO DE CLIENTE ---
  List<Map<String, dynamic>> _customQuestions = [];

  // --- ESTADO DE PAGOS ---
  List<Map<String, dynamic>> _selectedPaymentMethods = [];

  // Métodos guardados persistidos con Hive
  List<Map<String, dynamic>> _savedProfileMethods = [];
  Box? _savedMethodsBox;

  @override
  void initState() {
    super.initState();
    if (widget.initialData['preguntas'] != null) {
      _customQuestions =
          List<Map<String, dynamic>>.from(widget.initialData['preguntas']);
    }
    if (widget.initialData['metodosPago'] != null) {
      _selectedPaymentMethods =
          List<Map<String, dynamic>>.from(widget.initialData['metodosPago']);
    }
    _loadSavedMethods();
  }

  Future<void> _loadSavedMethods() async {
    try {
      final box = await Hive.openBox('saved_payment_methods');
      _savedMethodsBox = box;
      final loaded =
          box.values.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (mounted) setState(() => _savedProfileMethods = loaded);
    } catch (e) {
      debugPrint('[Pagos] Error cargando métodos guardados: $e');
    }
  }

  Future<void> _persistMethod(Map<String, dynamic> method) async {
    try {
      final box =
          _savedMethodsBox ?? await Hive.openBox('saved_payment_methods');
      // Usamos la combinación método+correo/teléfono como clave única para evitar duplicados
      final key =
          '${method['metodo']}_${method['correo'] ?? method['telefono'] ?? 'cash'}';
      await box.put(key, method);
      final loaded =
          box.values.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (mounted) setState(() => _savedProfileMethods = loaded);
    } catch (e) {
      debugPrint('[Pagos] Error guardando método: $e');
    }
  }

  Future<void> _deletePersistedMethod(Map<String, dynamic> method) async {
    try {
      final box =
          _savedMethodsBox ?? await Hive.openBox('saved_payment_methods');
      final key =
          '${method['metodo']}_${method['correo'] ?? method['telefono'] ?? 'cash'}';
      await box.delete(key);
      final loaded =
          box.values.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (mounted) setState(() => _savedProfileMethods = loaded);
    } catch (e) {
      debugPrint('[Pagos] Error eliminando método guardado: $e');
    }
  }

  // --- LÓGICA DE PREGUNTAS ---
  void _addQuestion() {
    showDialog(
      context: context,
      builder: (context) => _AddQuestionDialog(
        onAdd: (question) {
          setState(() {
            _customQuestions.add(question);
          });
        },
      ),
    );
  }

  // --- LÓGICA DE PAGOS ---
  void _openPaymentModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)),
      ),
      builder: (context) => _PaymentForm(
        savedMethods: _savedProfileMethods,
        onDeleteSaved: _deletePersistedMethod,
        onAdd: (paymentData, saveToProfile) {
          setState(() {
            _selectedPaymentMethods.add(paymentData);
          });
          if (saveToProfile) {
            _persistMethod(paymentData);
          }
        },
      ),
    );
  }

  void _validateAndFinish() {
    if (_selectedPaymentMethods.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Debes agregar al menos un método de pago')),
      );
      return;
    }

    widget.onNext({
      'preguntas': _customQuestions,
      'metodosPago': _selectedPaymentMethods,
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Datos y pago",
            style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: kPrimaryColor),
          ),
          Text(
            "Configura qué datos necesitas del cliente y cómo te pagarán.",
            style: GoogleFonts.poppins(color: Colors.grey),
          ),
          const SizedBox(height: 30),

          // ==========================================
          // SECCIÓN 1: FORMULARIO DE INSCRIPCIÓN
          // ==========================================
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Datos del cliente",
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: kPrimaryColor)),
              TextButton.icon(
                onPressed: _addQuestion,
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: const Text("Agregar pregunta"),
                style: TextButton.styleFrom(foregroundColor: kPrimaryColor),
              )
            ],
          ),
          const SizedBox(height: 5),

          if (_customQuestions.isEmpty)
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200)),
              child: Row(
                children: [
                  Icon(Icons.assignment_outlined, color: Colors.grey.shade400),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(
                          "Sólo se pedirá nombre, correo y teléfono por defecto. Agrega más preguntas o solicitudes si así lo necesitas (Ej: Alergias).",
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: Colors.grey))),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _customQuestions.length,
              separatorBuilder: (c, i) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final q = _customQuestions[index];
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.help_outline,
                        color: kPrimaryColor.withValues(alpha: 0.7)),
                    title: Text(q['pregunta'],
                        style:
                            GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                        "Tipo: ${q['tipo']} • ${q['requerido'] ? 'Obligatorio' : 'Opcional'}",
                        style: GoogleFonts.poppins(fontSize: 11)),
                    trailing: IconButton(
                      icon:
                          const Icon(Icons.close, color: Colors.red, size: 18),
                      onPressed: () =>
                          setState(() => _customQuestions.removeAt(index)),
                    ),
                  ),
                );
              },
            ),

          const SizedBox(height: 40),
          const Divider(),
          const SizedBox(height: 20),

          // ==========================================
          // SECCIÓN 2: MÉTODOS DE PAGO
          // ==========================================
          Text("Métodos de pago aceptados",
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: kPrimaryColor)),
          const SizedBox(height: 5),
          Text("Estos datos se mostrarán al cliente al momento de reservar.",
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 15),

          // Botón principal de agregar
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _openPaymentModal,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                side: const BorderSide(color: kPrimaryColor),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.account_balance_wallet_outlined,
                  color: kPrimaryColor),
              label: Text("Agregar método de pago",
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold, color: kPrimaryColor)),
            ),
          ),
          const SizedBox(height: 15),

          // Lista de pagos agregados
          if (_selectedPaymentMethods.isNotEmpty)
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _selectedPaymentMethods.length,
              separatorBuilder: (c, i) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final method = _selectedPaymentMethods[index];
                String details = "";

                if (['Zelle', 'Zinli', 'Binance'].contains(method['metodo'])) {
                  details = "${method['correo']} (${method['titular']})";
                } else if (method['metodo'] == 'Pago móvil') {
                  details = "${method['banco']} - ${method['telefono']}";
                } else if (method['metodo'] == 'Efectivo') {
                  details = "Pago presencial";
                } else {
                  details = "Ver detalles";
                }

                return Container(
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 5,
                            offset: const Offset(0, 2))
                      ]),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    leading: CircleAvatar(
                      backgroundColor: kPrimaryColor.withValues(alpha: 0.1),
                      radius: 18,
                      child: const Icon(Icons.attach_money,
                          color: kPrimaryColor, size: 20),
                    ),
                    title: Text(method['metodo'],
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text(details,
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: Colors.grey[700])),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => setState(
                          () => _selectedPaymentMethods.removeAt(index)),
                    ),
                  ),
                );
              },
            ),

          const SizedBox(height: 50),

          // --- BOTÓN SIGUIENTE (AZUL) ---
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor, // VUELVE A SER AZUL
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 4,
                shadowColor: kPrimaryColor.withValues(alpha: 0.4),
              ),
              onPressed: _validateAndFinish,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Siguiente: Ver resumen",
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
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

// =============================================================================
// DIALOGO AGREGAR PREGUNTA (TEMA CORREGIDO)
// =============================================================================
class _AddQuestionDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onAdd;
  const _AddQuestionDialog({required this.onAdd});

  @override
  State<_AddQuestionDialog> createState() => _AddQuestionDialogState();
}

class _AddQuestionDialogState extends State<_AddQuestionDialog> {
  final _controller = TextEditingController();
  bool _required = false;
  String _type = 'Texto';

  @override
  Widget build(BuildContext context) {
    // ENVOLVEMOS EN THEME PARA FORZAR EL COLOR AZUL
    return Theme(
      data: Theme.of(context).copyWith(
        primaryColor: kPrimaryColor,
        colorScheme: const ColorScheme.light(
            primary: kPrimaryColor, onPrimary: Colors.white),
        // Esto arregla el dropdown background
        canvasColor: Colors.white,
      ),
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Nueva Pregunta",
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                  labelText: "¿Qué quieres preguntar?",
                  hintText: "Ej: ¿Eres alérgico?",
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(
                  labelText: "Tipo de respuesta", border: OutlineInputBorder()),
              items: ['Texto', 'Sí/No', 'Número']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() => _type = v!),
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              title: const Text("¿Es obligatoria?"),
              value: _required,
              activeThumbColor: kPrimaryColor,
              onChanged: (v) => setState(() => _required = v),
              contentPadding: EdgeInsets.zero,
            )
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  const Text("Cancelar", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor),
            onPressed: () {
              if (_controller.text.isNotEmpty) {
                widget.onAdd({
                  'pregunta': _controller.text,
                  'tipo': _type,
                  'requerido': _required
                });
                Navigator.pop(context);
              }
            },
            child: const Text("Agregar", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }
}

// =============================================================================
// MODAL DE PAGOS (TEMA Y ESTILOS CORREGIDOS)
// =============================================================================
class _PaymentForm extends StatefulWidget {
  final Function(Map<String, dynamic>, bool) onAdd;
  final Function(Map<String, dynamic>) onDeleteSaved;
  final List<Map<String, dynamic>> savedMethods;

  const _PaymentForm({
    required this.onAdd,
    required this.onDeleteSaved,
    required this.savedMethods,
  });

  @override
  State<_PaymentForm> createState() => _PaymentFormState();
}

class _PaymentFormState extends State<_PaymentForm>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  String _selectedMethod = 'Pago móvil';

  // Controllers
  final _titularCtrl = TextEditingController();
  final _idCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _bankCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  bool _saveForFuture = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  InputDecoration _deco(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon != null ? Icon(icon, color: Colors.grey) : null,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
    );
  }

  void _submitNew() {
    if (_formKey.currentState!.validate()) {
      Map<String, dynamic> data = {'metodo': _selectedMethod};

      if (_selectedMethod == 'Pago móvil') {
        data.addAll({
          'banco': _bankCtrl.text,
          'telefono': _phoneCtrl.text,
          'cedula': _idCtrl.text,
        });
      } else if (['Zelle', 'Zinli', 'Binance'].contains(_selectedMethod)) {
        data.addAll({
          'correo': _emailCtrl.text,
          'titular': _titularCtrl.text,
        });
      }

      widget.onAdd(data, _saveForFuture);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    // TEMA FORZADO PARA QUITAR MORADO EN TABS Y DROPDOWN
    return Theme(
      data: Theme.of(context).copyWith(
        primaryColor: kPrimaryColor,
        colorScheme: const ColorScheme.light(
            primary: kPrimaryColor, onPrimary: Colors.white),
        canvasColor: Colors.white, // Fondo del dropdown
      ),
      child: Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20, top: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // HEADER TABS (DISEÑO MEJORADO)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 255, 255, 255),
                  borderRadius: BorderRadius.circular(12)),
              child: TabBar(
                controller: _tabController,
                indicatorPadding: const EdgeInsets.all(4),
                labelColor: kPrimaryColor,
                unselectedLabelColor: const Color.fromARGB(179, 79, 79, 79),
                labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                tabs: const [
                  Tab(text: "Nueva cuenta"),
                  Tab(text: "Mis guardadas")
                ],
              ),
            ),

            SizedBox(
              height: 420, // Altura fija suficiente para scroll
              child: TabBarView(
                controller: _tabController,
                children: [
                  // --- TAB 1: NUEVA CUENTA ---
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          DropdownButtonFormField<String>(
                            initialValue: _selectedMethod,
                            decoration: _deco("Tipo"),
                            items: [
                              'Pago móvil',
                              'Zelle',
                              'Zinli',
                              'Binance',
                              'Efectivo'
                            ]
                                .map((e) =>
                                    DropdownMenuItem(value: e, child: Text(e)))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _selectedMethod = v!),
                          ),
                          const SizedBox(height: 15),

                          // CAMPOS DINÁMICOS
                          if (_selectedMethod == 'Pago móvil') ...[
                            TextFormField(
                                controller: _bankCtrl,
                                decoration:
                                    _deco("Banco", icon: Icons.account_balance),
                                validator: (v) =>
                                    v!.isEmpty ? 'Requerido' : null),
                            const SizedBox(height: 10),
                            TextFormField(
                                controller: _phoneCtrl,
                                decoration: _deco("Teléfono",
                                    icon: Icons.phone_android),
                                keyboardType: TextInputType.phone,
                                validator: (v) =>
                                    v!.isEmpty ? 'Requerido' : null),
                            const SizedBox(height: 10),
                            TextFormField(
                                controller: _idCtrl,
                                decoration:
                                    _deco("Cédula / RIF", icon: Icons.badge),
                                validator: (v) =>
                                    v!.isEmpty ? 'Requerido' : null),
                          ],

                          // LÓGICA UNIFICADA PARA ZELLE, ZINLI Y BINANCE
                          if (['Zelle', 'Zinli', 'Binance']
                              .contains(_selectedMethod)) ...[
                            TextFormField(
                                controller: _emailCtrl,
                                decoration: _deco("Correo electrónico",
                                    icon: Icons.email),
                                keyboardType: TextInputType.emailAddress,
                                validator: (v) =>
                                    v!.isEmpty ? 'Requerido' : null),
                            const SizedBox(height: 10),
                            TextFormField(
                                controller: _titularCtrl,
                                decoration: _deco("Nombre", icon: Icons.person),
                                validator: (v) =>
                                    v!.isEmpty ? 'Requerido' : null),
                          ],

                          if (_selectedMethod == 'Efectivo')
                            const Padding(
                              padding: EdgeInsets.all(10),
                              child: Text(
                                  "El pago se acordará directamente en el lugar.",
                                  style: TextStyle(color: Colors.grey)),
                            ),

                          const SizedBox(height: 20),

                          // CHECKBOX GUARDAR
                          if (_selectedMethod != 'Efectivo')
                            Container(
                              decoration: BoxDecoration(
                                  color: kPrimaryColor.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(8)),
                              child: CheckboxListTile(
                                value: _saveForFuture,
                                activeColor: kPrimaryColor,
                                title: Text("Guardar en mi perfil",
                                    style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600)),
                                subtitle: Text("Para no escribirlo de nuevo",
                                    style: GoogleFonts.poppins(fontSize: 11)),
                                onChanged: (v) =>
                                    setState(() => _saveForFuture = v!),
                              ),
                            ),

                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: kPrimaryColor,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12)),
                              onPressed: _submitNew,
                              child: const Text("Agregar método",
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold)),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),

                  // --- TAB 2: GUARDADAS ---
                  widget.savedMethods.isEmpty
                      ? Center(
                          child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.bookmark_border,
                                size: 50, color: Colors.grey[300]),
                            const SizedBox(height: 10),
                            Text("No tienes cuentas guardadas",
                                style: GoogleFonts.poppins(color: Colors.grey)),
                            const SizedBox(height: 6),
                            Text(
                              "Marca \"Guardar en mi perfil\" al agregar\nuna cuenta nueva.",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                  fontSize: 11, color: Colors.grey[400]),
                            ),
                          ],
                        ))
                      : ListView.builder(
                          padding: const EdgeInsets.all(20),
                          itemCount: widget.savedMethods.length,
                          itemBuilder: (context, index) {
                            final saved = widget.savedMethods[index];
                            final subtitle = saved['metodo'] == 'Pago móvil'
                                ? '${saved['banco']} · ${saved['telefono']}'
                                : saved['correo'] ?? '';
                            return Card(
                              elevation: 0,
                              color: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side:
                                      BorderSide(color: Colors.grey.shade200)),
                              margin: const EdgeInsets.only(bottom: 10),
                              child: ListTile(
                                leading:
                                    Icon(Icons.bookmark, color: kPrimaryColor),
                                title: Text(saved['metodo'],
                                    style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14)),
                                subtitle: Text(subtitle,
                                    style: GoogleFonts.poppins(
                                        fontSize: 12, color: Colors.grey[600])),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Botón "Usar"
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor: kPrimaryColor,
                                          shape: const StadiumBorder(),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 6)),
                                      onPressed: () {
                                        widget.onAdd(saved, false);
                                        Navigator.pop(context);
                                      },
                                      child: const Text("Usar",
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 12)),
                                    ),
                                    const SizedBox(width: 4),
                                    // Botón eliminar
                                    IconButton(
                                      icon: const Icon(Icons.close,
                                          color: Colors.red, size: 18),
                                      tooltip: 'Eliminar guardado',
                                      onPressed: () =>
                                          widget.onDeleteSaved(saved),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
