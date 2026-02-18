import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:hive_flutter/hive_flutter.dart';

// --- IMPORT DASHBOARD PARA REUTILIZAR DIALOGO ---
import '../supplier/dashboard_home_screen.dart';

const Color kPrimaryColor = Color.fromRGBO(17, 48, 73, 1);
const Color kBackgroundColor = Color(0xFFF8F9FD);

class CustomerDetailScreen extends StatefulWidget {
  final Map<String, dynamic> clientData;

  const CustomerDetailScreen({
    super.key,
    required this.clientData,
  });

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  // Variables para Datos del Usuario
  Map<String, dynamic>? _realUserData;

  // Variables para Notas (Hive)
  Box? _notesBox;
  List<String> _notes = [];
  bool _isNotesLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRealUserData();
    _initHiveNotes();
  }

  // --- 1. HIVE: GESTIÓN DE NOTAS LOCALES ---
  Future<void> _initHiveNotes() async {
    try {
      _notesBox = await Hive.openBox('supplier_client_notes');
      _loadNotes();
    } catch (e) {
      debugPrint("Error iniciando Hive: $e");
      setState(() => _isNotesLoading = false);
    }
  }

  String _getClientKey() {
    String key = widget.clientData['uniqueKey'].toString();
    if (key.startsWith('UID_') && key.length > 4) return key;

    if (widget.clientData['cedula'] != null &&
        widget.clientData['cedula'].toString().isNotEmpty) {
      return "CED_${widget.clientData['cedula']}";
    }
    if (widget.clientData['phone'] != null &&
        widget.clientData['phone'].toString().isNotEmpty) {
      return "TEL_${widget.clientData['phone']}";
    }
    return "EMAIL_${widget.clientData['email']}";
  }

  void _loadNotes() {
    if (_notesBox == null) return;
    String key = _getClientKey();
    List<dynamic> savedNotes = _notesBox!.get(key, defaultValue: []);

    if (mounted) {
      setState(() {
        _notes = savedNotes.cast<String>().toList();
        _isNotesLoading = false;
      });
    }
  }

  Future<void> _saveNoteToHive(String newNote) async {
    if (_notesBox == null) return;
    setState(() {
      _notes.add(newNote);
    });
    await _notesBox!.put(_getClientKey(), _notes);
  }

  Future<void> _deleteNoteFromHive(int index) async {
    if (_notesBox == null) return;
    setState(() {
      _notes.removeAt(index);
    });
    await _notesBox!.put(_getClientKey(), _notes);
  }

  // --- 2. OBTENER DATOS REALES (Firebase) ---
  Future<void> _fetchRealUserData() async {
    String uid = '';
    if (widget.clientData['uniqueKey'].toString().startsWith('UID_')) {
      uid = widget.clientData['uniqueKey'].toString().substring(4);
    }

    if (uid.isNotEmpty) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(uid)
            .get();
        if (doc.exists && mounted) {
          setState(() {
            _realUserData = doc.data();
          });
        }
      } catch (e) {
        debugPrint("Error buscando usuario real: $e");
      }
    }
  }

  // --- 3. ACCIONES DE CONTACTO ---
  String _getBestPhone() {
    if (_realUserData != null) {
      if (_realUserData!['celular'] != null &&
          _realUserData!['celular'].toString().isNotEmpty) {
        return _realUserData!['celular'];
      }
      if (_realUserData!['numero'] != null &&
          _realUserData!['numero'].toString().isNotEmpty) {
        return _realUserData!['numero'];
      }
    }
    return widget.clientData['phone'] ?? '';
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw 'No se pudo abrir $url';
      }
    } catch (e) {
      _showMessage("No se pudo ejecutar la acción.");
    }
  }

  void _callClient() {
    final phone = _getBestPhone();
    if (phone.isNotEmpty && phone.length > 3) {
      _launchUrl("tel:$phone");
    } else {
      _showSimpleDialog(
          "Sin número", "Este usuario no tiene un número asociado.");
    }
  }

  void _whatsappClient() {
    String rawPhone = _getBestPhone();
    if (rawPhone.isEmpty || rawPhone.length < 3) {
      _showSimpleDialog(
          "Sin WhatsApp", "Este usuario no tiene un número disponible.");
      return;
    }

    String num = rawPhone.replaceAll(RegExp(r'\D'), '');
    if (num.startsWith('0')) num = num.substring(1);
    if (!num.startsWith('58') && num.length == 10) num = '58$num';

    if (num.length == 12 && num.startsWith('58')) {
      _launchUrl("https://wa.me/$num");
    } else {
      if (num.length > 7) {
        _launchUrl("https://wa.me/$num");
      } else {
        _showSimpleDialog("Número inválido",
            "El número ($rawPhone) no tiene un formato válido.");
      }
    }
  }

  void _emailClient() {
    String email = widget.clientData['email'] ?? '';
    if (_realUserData != null && _realUserData!['email'] != null) {
      email = _realUserData!['email'];
    }

    if (email.isNotEmpty) {
      _launchUrl("mailto:$email");
    } else {
      _showSimpleDialog("Sin correo", "Este usuario no tiene correo asociado.");
    }
  }

  // --- 4. FUNCIONES DE GESTIÓN (EDITAR Y PAGOS) ---

  void _showEditClientDialog() {
    final nameCtrl = TextEditingController(text: widget.clientData['name']);
    final phoneCtrl = TextEditingController(text: widget.clientData['phone']);
    final emailCtrl = TextEditingController(text: widget.clientData['email']);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Editar Cliente",
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold, color: kPrimaryColor)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: "Nombre completo"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(labelText: "Teléfono"),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(labelText: "Correo"),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  const Text("Cancelar", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (nameCtrl.text.isNotEmpty) {
                _updateClientData(nameCtrl.text.trim(), phoneCtrl.text.trim(),
                    emailCtrl.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor),
            child: const Text("Guardar", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  Future<void> _updateClientData(
      String newName, String newPhone, String newEmail) async {
    QuerySnapshot? snapshot;
    try {
      if (widget.clientData['cedula'] != null &&
          widget.clientData['cedula'].toString().isNotEmpty) {
        snapshot = await FirebaseFirestore.instance
            .collectionGroup('reservas')
            .where('cedula', isEqualTo: widget.clientData['cedula'])
            .get();
      } else {
        snapshot = await FirebaseFirestore.instance
            .collectionGroup('reservas')
            .where('email', isEqualTo: widget.clientData['email'])
            .get();
      }

      if (snapshot.docs.isNotEmpty) {
        WriteBatch batch = FirebaseFirestore.instance.batch();
        for (var doc in snapshot.docs) {
          batch.update(doc.reference, {
            'name': newName,
            'celular': newPhone,
            'numero': newPhone,
            'email': newEmail
          });
        }
        await batch.commit();
        _showMessage("Datos actualizados correctamente.");
      } else {
        _showMessage("No se encontraron registros para actualizar.");
      }
    } catch (e) {
      debugPrint("Error updating client: $e");
      _showMessage("Error al actualizar datos.");
    }
  }

  void _showRegisterPaymentDialog(DocumentSnapshot reservaDoc) {
    final Map<String, dynamic> data = reservaDoc.data() as Map<String, dynamic>;
    final double total = (data['totalPlanPrice'] ?? 0).toDouble();
    final double paid = (data['amountPaid'] ?? 0).toDouble();
    final double debt = total - paid;
    final int currentInstallments = data['installmentsPaid'] ?? 1;

    final amountCtrl = TextEditingController();
    final refCtrl = TextEditingController();
    final emailPayCtrl = TextEditingController();
    String method = "Efectivo";

    showDialog(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              bool showRef =
                  method == 'Pago móvil' || method == 'Transferencia';
              bool showEmail = ['Zelle', 'Binance', 'Zinli'].contains(method);

              return AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                title: Text("Registrar pago",
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold, color: kPrimaryColor)),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("Deuda pendiente: \$${debt.toStringAsFixed(2)}",
                          style: GoogleFonts.poppins(
                              color: Colors.orange,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 15),
                      TextField(
                        controller: amountCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: "Monto a pagar (\$)",
                            border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 15),
                      DropdownButtonFormField<String>(
                        initialValue: method,
                        decoration: const InputDecoration(
                            labelText: "Método", border: OutlineInputBorder()),
                        items: [
                          "Efectivo",
                          "Pago móvil",
                          "Zelle",
                          "Binance",
                          "Zinli",
                          "Transferencia"
                        ]
                            .map((m) =>
                                DropdownMenuItem(value: m, child: Text(m)))
                            .toList(),
                        onChanged: (val) => setDialogState(() => method = val!),
                      ),
                      if (showRef) ...[
                        const SizedBox(height: 10),
                        TextField(
                          controller: refCtrl,
                          decoration: const InputDecoration(
                              labelText: "Referencia (Obligatorio)",
                              border: OutlineInputBorder()),
                        )
                      ],
                      if (showEmail) ...[
                        const SizedBox(height: 10),
                        TextField(
                          controller: emailPayCtrl,
                          decoration: const InputDecoration(
                              labelText: "Correo cuenta (Obligatorio)",
                              border: OutlineInputBorder()),
                        )
                      ]
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("Cancelar",
                          style: TextStyle(color: Colors.grey))),
                  ElevatedButton(
                    onPressed: () async {
                      double amount = double.tryParse(amountCtrl.text) ?? 0;
                      if (amount <= 0 || amount > debt + 1) {
                        _showMessage("Monto inválido");
                        return;
                      }
                      if (showRef && refCtrl.text.isEmpty) {
                        _showMessage("Referencia requerida");
                        return;
                      }
                      if (showEmail && emailPayCtrl.text.isEmpty) {
                        _showMessage("Correo requerido");
                        return;
                      }

                      Navigator.pop(ctx);
                      await _processPayment(reservaDoc, amount, method,
                          refCtrl.text, emailPayCtrl.text, currentInstallments);
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryColor),
                    child: const Text("Registrar",
                        style: TextStyle(color: Colors.white)),
                  )
                ],
              );
            },
          );
        });
  }

  Future<void> _processPayment(DocumentSnapshot doc, double amount,
      String method, String ref, String emailPay, int installmentCount) async {
    try {
      final data = doc.data() as Map<String, dynamic>;
      double currentPaid = (data['amountPaid'] ?? 0).toDouble();
      double total = (data['totalPlanPrice'] ?? 0).toDouble();

      double newPaid = currentPaid + amount;
      bool isCompleted = newPaid >= (total - 1);

      Map<String, dynamic> newPayment = {
        'amount': amount,
        'date': DateTime.now(), // Fecha local para el array
        'type': 'installment',
        'method': method,
      };

      if (ref.isNotEmpty) newPayment['referencia'] = ref;
      if (emailPay.isNotEmpty) newPayment['email_pago'] = emailPay;

      await doc.reference.update({
        'amountPaid': newPaid,
        'installmentsPaid': installmentCount + 1,
        'paymentStatus': isCompleted ? 'completed' : 'partial',
        'estado': isCompleted ? 'verificado' : data['estado'],
        'paymentHistory': FieldValue.arrayUnion([newPayment])
      });
      _showMessage("Pago registrado exitosamente");
    } catch (e) {
      _showMessage("Error: $e");
    }
  }

  // --- UI HELPERS ---
  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showSimpleDialog(String title, String body) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title,
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold, color: kPrimaryColor)),
        content: Text(body, style: GoogleFonts.poppins(fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Entendido",
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold, color: kPrimaryColor)),
          )
        ],
      ),
    );
  }

  void _showAddNoteDialog() {
    TextEditingController noteCtrl = TextEditingController();
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Text("Nueva Nota",
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold, color: kPrimaryColor)),
              content: TextField(
                controller: noteCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                    hintText: "Escribe aquí...",
                    hintStyle:
                        GoogleFonts.poppins(fontSize: 13, color: Colors.grey),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey[50]),
                maxLines: 3,
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("Cancelar",
                        style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                    onPressed: () {
                      if (noteCtrl.text.trim().isNotEmpty) {
                        _saveNoteToHive(noteCtrl.text.trim());
                        Navigator.pop(ctx);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryColor,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8))),
                    child: Text("Guardar",
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold, color: Colors.white)))
              ],
            ));
  }

  // --- QUERY CON ORDERBY (REQUIERE ÍNDICES) ---
  Stream<QuerySnapshot> _getHistoryStream() {
    // NOTA: ESTO REQUIERE ÍNDICES COMPUESTOS EN FIRESTORE CONSOLE
    // CollectionGroup "reservas" -> userId ASC + createdAt DESC
    // CollectionGroup "reservas" -> cedula ASC + createdAt DESC
    // CollectionGroup "reservas" -> email ASC + createdAt DESC

    if (widget.clientData['uniqueKey'].toString().startsWith('UID_')) {
      String uid = widget.clientData['uniqueKey'].toString().substring(4);
      return FirebaseFirestore.instance
          .collectionGroup('reservas')
          .where('userId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .snapshots();
    }
    if (widget.clientData['cedula'].toString().isNotEmpty) {
      return FirebaseFirestore.instance
          .collectionGroup('reservas')
          .where('cedula', isEqualTo: widget.clientData['cedula'])
          .orderBy('createdAt', descending: true)
          .snapshots();
    }
    return FirebaseFirestore.instance
        .collectionGroup('reservas')
        .where('email', isEqualTo: widget.clientData['email'])
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final bool hasDebt = (widget.clientData['debt'] ?? 0) > 1.0;

    final String name = _realUserData != null
        ? (_realUserData!['name'] ?? widget.clientData['name'] ?? 'Cliente')
        : (widget.clientData['name'] ?? 'Cliente');

    final String initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    String? userImage = _realUserData?['imagen'];

    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: Text("Perfil del cliente",
            style: GoogleFonts.poppins(
                color: Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () {
              if (widget.clientData['type'] == 'app') {
                _showSimpleDialog("Usuario de Biqoe",
                    "Los datos de este usuario son gestionados por la aplicación y no pueden editarse manualmente.");
              } else {
                _showEditClientDialog();
              }
            },
            child: Text("Editar",
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold, color: kPrimaryColor)),
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // HEADER
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(20),
              width: double.infinity,
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: kPrimaryColor,
                    backgroundImage: (userImage != null && userImage.isNotEmpty)
                        ? NetworkImage(userImage)
                        : null,
                    child: (userImage == null || userImage.isEmpty)
                        ? Text(initial,
                            style: GoogleFonts.poppins(
                                fontSize: 30,
                                color: Colors.white,
                                fontWeight: FontWeight.bold))
                        : null,
                  ),
                  const SizedBox(height: 10),
                  Text(name,
                      style: GoogleFonts.poppins(
                          fontSize: 20, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center),
                  Text(
                    widget.clientData['type'] == 'app'
                        ? 'Usuario App • Verificado'
                        : 'Cliente externo',
                    style:
                        GoogleFonts.poppins(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _ActionButton(
                          icon: Icons.phone,
                          label: "Llamar",
                          onTap: _callClient),
                      const SizedBox(width: 25),
                      _ActionButton(
                          icon: Icons.message,
                          label: "WhatsApp",
                          onTap: _whatsappClient,
                          color: Colors.green),
                      const SizedBox(width: 25),
                      _ActionButton(
                          icon: Icons.email,
                          label: "Correo",
                          onTap: _emailClient),
                    ],
                  )
                ],
              ),
            ),

            const SizedBox(height: 15),

            // ESTADÍSTICAS
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _StatItem(
                      label: "Total gastado",
                      value:
                          "\$${(widget.clientData['total_spend'] as double? ?? 0).toStringAsFixed(0)}"),
                  Container(width: 1, height: 40, color: Colors.grey.shade200),
                  _StatItem(
                      label: "Reservas",
                      value: "${widget.clientData['reservation_count'] ?? 0}"),
                  Container(width: 1, height: 40, color: Colors.grey.shade200),
                  _StatItem(
                      label: "Deuda",
                      value:
                          "\$${(widget.clientData['debt'] as double? ?? 0).toStringAsFixed(0)}",
                      valueColor: hasDebt ? Colors.red : Colors.green),
                ],
              ),
            ),

            const SizedBox(height: 15),

            // TABS (3 PESTAÑAS)
            DefaultTabController(
              length: 3,
              child: Column(
                children: [
                  Container(
                    color: Colors.white,
                    child: TabBar(
                      labelColor: kPrimaryColor,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: kPrimaryColor,
                      labelStyle:
                          GoogleFonts.poppins(fontWeight: FontWeight.bold),
                      tabs: const [
                        Tab(text: "Historial"),
                        Tab(text: "Pagos"),
                        Tab(text: "Notas"),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 500,
                    child: TabBarView(
                      children: [
                        // TAB 1: HISTORIAL
                        StreamBuilder<QuerySnapshot>(
                          stream: _getHistoryStream(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center();
                            }
                            if (!snapshot.hasData ||
                                snapshot.data!.docs.isEmpty) {
                              return Center(
                                  child: Text("Sin historial visible",
                                      style: GoogleFonts.poppins(
                                          color: Colors.grey)));
                            }
                            final docs = snapshot.data!.docs;
                            return ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: docs.length,
                              separatorBuilder: (c, i) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final data =
                                    docs[index].data() as Map<String, dynamic>;
                                final docId = docs[index].id;
                                final String title =
                                    data['planName'] ?? 'Reserva';
                                final double price = (data['amountPaid'] ??
                                        data['totalPrice'] ??
                                        0)
                                    .toDouble();
                                final String status =
                                    data['estado'] == 'verificado'
                                        ? 'Confirmado'
                                        : 'Pendiente';
                                DateTime date = DateTime(2000);
                                if (data['createdAt'] != null) {
                                  date =
                                      (data['createdAt'] as Timestamp).toDate();
                                }
                                final String dateStr =
                                    DateFormat('dd/MM/yyyy').format(date);

                                return GestureDetector(
                                  onTap: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => BookingDetailDialog(
                                        data: data,
                                        docId: docId,
                                        // --- CORRECCIÓN AQUÍ ---
                                        // El campo en Firebase se llama 'supplier', no 'supplierId'
                                        supplierId: data['supplier'] ?? '',
                                        // -----------------------
                                      ),
                                    );
                                  },
                                  child: _HistoryItem(
                                      title: title,
                                      date: dateStr,
                                      status: status,
                                      price: "\$${price.toStringAsFixed(0)}"),
                                );
                              },
                            );
                          },
                        ),

                        // TAB 2: REGISTRO DE PAGOS
                        StreamBuilder<QuerySnapshot>(
                          stream: _getHistoryStream(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center();
                            }

                            if (!snapshot.hasData ||
                                snapshot.data!.docs.isEmpty) {
                              return Center(
                                  child: Text("No hay pagos pendientes",
                                      style: GoogleFonts.poppins(
                                          color: Colors.grey)));
                            }

                            final docs = snapshot.data!.docs.where((doc) {
                              final d = doc.data() as Map<String, dynamic>;
                              double total =
                                  (d['totalPlanPrice'] ?? 0).toDouble();
                              double paid = (d['amountPaid'] ?? 0).toDouble();
                              return (total - paid) > 1.0;
                            }).toList();

                            if (docs.isEmpty) {
                              return Center(
                                  child: Text("El cliente está solvente",
                                      style: GoogleFonts.poppins(
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold)));
                            }

                            return ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: docs.length,
                              separatorBuilder: (c, i) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final doc = docs[index];
                                final data = doc.data() as Map<String, dynamic>;
                                double total =
                                    (data['totalPlanPrice'] ?? 0).toDouble();
                                double paid =
                                    (data['amountPaid'] ?? 0).toDouble();
                                double debt = total - paid;

                                return Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: Colors.orange.shade200),
                                      boxShadow: [
                                        BoxShadow(
                                            color: Colors.black.withAlpha(5),
                                            blurRadius: 4)
                                      ]),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(data['planName'] ?? 'Reserva',
                                              style: GoogleFonts.poppins(
                                                  fontWeight: FontWeight.bold)),
                                          Text(
                                              "Deuda: \$${debt.toStringAsFixed(2)}",
                                              style: GoogleFonts.poppins(
                                                  color: Colors.red,
                                                  fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          ElevatedButton(
                                            onPressed: () =>
                                                _showRegisterPaymentDialog(doc),
                                            style: ElevatedButton.styleFrom(
                                                backgroundColor: kPrimaryColor,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 16,
                                                        vertical: 8),
                                                shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8))),
                                            child: const Text("Registrar pago",
                                                style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12)),
                                          )
                                        ],
                                      )
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        ),

                        // TAB 3: NOTAS (HIVE LOCAL)
                        _isNotesLoading
                            ? const Center()
                            : SingleChildScrollView(
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    children: [
                                      if (_notes.isEmpty)
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 20),
                                          child: Column(
                                            children: [
                                              const Icon(
                                                  HugeIcons.strokeRoundedNote01,
                                                  size: 40,
                                                  color: Colors.grey),
                                              const SizedBox(height: 10),
                                              Text("No hay notas guardadas.",
                                                  style: GoogleFonts.poppins(
                                                      color: Colors.grey)),
                                            ],
                                          ),
                                        )
                                      else
                                        ListView.builder(
                                          shrinkWrap: true,
                                          physics:
                                              const NeverScrollableScrollPhysics(),
                                          itemCount: _notes.length,
                                          itemBuilder: (context, index) {
                                            return Container(
                                              margin: const EdgeInsets.only(
                                                  bottom: 10),
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                      color: Colors
                                                          .grey.shade200)),
                                              child: Row(
                                                children: [
                                                  const Icon(
                                                      Icons
                                                          .sticky_note_2_outlined,
                                                      color: Colors.amber,
                                                      size: 20),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: Text(_notes[index],
                                                        style:
                                                            GoogleFonts.poppins(
                                                                fontSize: 13)),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(
                                                        Icons.close,
                                                        size: 18,
                                                        color: Colors.grey),
                                                    padding: EdgeInsets.zero,
                                                    constraints:
                                                        const BoxConstraints(),
                                                    onPressed: () =>
                                                        _deleteNoteFromHive(
                                                            index),
                                                  )
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      const SizedBox(height: 10),
                                      SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton.icon(
                                          onPressed: _showAddNoteDialog,
                                          icon: const Icon(Icons.add, size: 18),
                                          label: Text("Agregar nota",
                                              style: GoogleFonts.poppins(
                                                  fontWeight: FontWeight.bold)),
                                          style: OutlinedButton.styleFrom(
                                              foregroundColor: kPrimaryColor,
                                              side: const BorderSide(
                                                  color: kPrimaryColor),
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          12)),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 12)),
                                        ),
                                      )
                                    ],
                                  ),
                                ),
                              ),
                      ],
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

// --- WIDGETS AUXILIARES ---
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  const _ActionButton(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.color = const Color.fromRGBO(17, 48, 73, 1)});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(children: [
        Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: color.withAlpha((0.1 * 255).round()),
                shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 24)),
        const SizedBox(height: 6),
        Text(label,
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700]))
      ]),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  const _StatItem(
      {required this.label,
      required this.value,
      this.valueColor = Colors.black});
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value,
          style: GoogleFonts.poppins(
              fontSize: 18, fontWeight: FontWeight.bold, color: valueColor)),
      Text(label, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
    ]);
  }
}

class _HistoryItem extends StatelessWidget {
  final String title;
  final String date;
  final String status;
  final String price;
  const _HistoryItem(
      {required this.title,
      required this.date,
      required this.status,
      required this.price});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withAlpha((0.03 * 255).round()),
                blurRadius: 5,
                offset: const Offset(0, 2))
          ]),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600, fontSize: 14)),
          Text(date,
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
        ]),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(price,
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold, fontSize: 14)),
          Text(status,
              style: GoogleFonts.poppins(
                  fontSize: 11,
                  color:
                      status == 'Confirmado' ? Colors.green : Colors.orange)),
        ])
      ]),
    );
  }
}
