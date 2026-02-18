import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:hive_flutter/hive_flutter.dart'; // Importante para Seguir

// --- IMPORTS NECESARIOS ---
import 'destination_detail_screen.dart';
import '../../services/chat_service.dart';
import '../chat_detail_screen.dart';
import '../../login_screen.dart';

class ProviderProfileScreen extends StatefulWidget {
  final String slug;
  final String currentUserId;

  const ProviderProfileScreen({
    super.key,
    required this.slug,
    this.currentUserId = 'guest',
  });

  @override
  State<ProviderProfileScreen> createState() => _ProviderProfileScreenState();
}

class _ProviderProfileScreenState extends State<ProviderProfileScreen> {
  final Color primaryColor = const Color.fromRGBO(17, 48, 73, 1);
  final Color backgroundColor = const Color(0xFFF3F7FE);

  Box? _followedProvidersBox;
  late Future<QuerySnapshot> _profileFuture;

  @override
  void initState() {
    super.initState();
    _initHive();

    // 1. Guardamos la consulta (Igual que antes)
    _profileFuture = FirebaseFirestore.instance
        .collection('usuarios')
        .where('slug', isEqualTo: widget.slug)
        .limit(1)
        .get();

    // 2. NUEVO: Llamamos a la función de conteo
    // No usamos 'await' aquí para no bloquear la interfaz (Fire & Forget)
    _incrementViewCount();
  }

  // --- NUEVA FUNCIÓN PARA CONTAR LA VISITA ---
  Future<void> _incrementViewCount() async {
    try {
      // Esperamos el resultado de la consulta que ya se lanzó arriba
      final snapshot = await _profileFuture;

      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;

        // (Opcional) No contar si es el propio dueño visitando su perfil
        if (doc.id == widget.currentUserId) return;

        // Actualización atómica en Firestore
        await doc.reference.update({
          'profileViews': FieldValue.increment(1),
          // Opcional: Guardar fecha de última vista para analíticas futuras
          'lastViewedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      // Silenciamos errores aquí para no molestar al usuario si falla el contador
      debugPrint("Error actualizando contador de visitas: $e");
    }
  }

  // --- HIVE: SEGUIR PROVEEDOR ---
  Future<void> _initHive() async {
    if (widget.currentUserId.isNotEmpty && widget.currentUserId != 'guest') {
      try {
        _followedProvidersBox =
            await Hive.openBox('followed_providers_${widget.currentUserId}');
        // Solo hacemos setState una vez al cargar la caja
        if (mounted) setState(() {});
      } catch (e) {
        debugPrint("Error abriendo Hive: $e");
      }
    }
  }

  // --- LÓGICA DE BÚSQUEDA DE RESERVA ---
  void _showBookingSearchDialog(String providerId) {
    final TextEditingController searchCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Buscar Reserva",
            style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.bold,
                color: primaryColor)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Ingresa tu código de reserva para ver los detalles.",
              style: TextStyle(fontFamily: 'Poppins', fontSize: 13),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: searchCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: "Ej: A1B2C3D4",
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancelar", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final code = searchCtrl.text.trim();
              if (code.isEmpty) return;

              // 1. Cerrar el diálogo de input
              Navigator.pop(dialogContext);

              // 2. Mostrar carga
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (loadingContext) => const Center(),
              );

              try {
                final query = await FirebaseFirestore.instance
                    .collection('reservaciones')
                    .doc(providerId)
                    .collection('reservas')
                    .where('code', isEqualTo: code)
                    .limit(1)
                    .get();

                // 3. Cerrar carga (Usamos el context del State, es lo más seguro aquí)
                if (mounted) Navigator.pop(context);

                if (query.docs.isNotEmpty) {
                  final data = query.docs.first.data();
                  // 4. Mostrar detalle (Sin rootNavigator forzado)
                  if (mounted) _showReservationDetail(context, data);
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content:
                              Text("No se encontró reserva con ese código.")),
                    );
                  }
                }
              } catch (e) {
                // Si falla, intentamos cerrar la carga
                if (mounted) Navigator.pop(context);
                debugPrint("Error búsqueda: $e");
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("Buscar", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- DIÁLOGO DE DETALLE ---
  void _showReservationDetail(BuildContext context, Map<String, dynamic> data) {
    // Calculamos datos básicos
    final double total = (data['totalPlanPrice'] ?? 0).toDouble();
    final double paid = (data['amountPaid'] ?? 0).toDouble();
    final String status = data['estado'] ?? 'pendiente';
    final bool isVerified = status == 'verificado';
    final String qrData = data['code'] ?? '';

    // API para QR
    final String qrUrl =
        "https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=$qrData&color=113049";

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        // Usamos 'ctx' para el contexto del diálogo
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          // Importante: Clip para que el contenido no se salga de los bordes redondeados
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // --- HEADER CON BOTÓN DE CERRAR ---
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 20, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Detalle de Reserva",
                          style: TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: primaryColor)),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        // Acción simple: cerrar este contexto (el diálogo)
                        onPressed: () => Navigator.pop(ctx),
                      )
                    ],
                  ),
                ),
                const Divider(height: 1),

                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      // Status
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isVerified
                              ? Colors.green.withValues(alpha: (0.1))
                              : Colors.orange.withValues(alpha: (0.1)),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isVerified ? "VERIFICADO" : "PENDIENTE",
                          style: TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: isVerified ? Colors.green : Colors.orange),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Info Principal
                      Text(data['planName'] ?? 'Actividad',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 5),
                      Text(data['planLocation'] ?? '',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              color: Colors.grey[600])),

                      const SizedBox(height: 20),

                      // QR Code
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4))
                            ]),
                        child: Column(
                          children: [
                            Image.network(
                              qrUrl,
                              width: 140,
                              height: 140,
                              loadingBuilder: (c, child, p) {
                                if (p == null) return child;
                                return const SizedBox(
                                    width: 140, height: 140, child: Center());
                              },
                              errorBuilder: (c, o, s) =>
                                  const Icon(Icons.error),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              qrData,
                              style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                  letterSpacing: 3,
                                  color: primaryColor),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              "Muestra este código al llegar",
                              style:
                                  TextStyle(fontSize: 10, color: Colors.grey),
                            )
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Finanzas
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12)),
                        child: Column(
                          children: [
                            _detailRow(
                                "Total:", "\$${total.toStringAsFixed(2)}"),
                            const SizedBox(height: 8),
                            _detailRow(
                                "Abonado:", "\$${paid.toStringAsFixed(2)}",
                                isBold: true, color: Colors.green),
                            const Divider(height: 20),
                            _detailRow("Restante:",
                                "\$${(total - paid).toStringAsFixed(2)}",
                                isBold: true,
                                color: (total - paid) > 1
                                    ? Colors.red
                                    : Colors.grey),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value,
      {bool isBold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontFamily: 'Poppins', fontSize: 13, color: Colors.grey[700])),
        Text(value,
            style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: color ?? Colors.black87)),
      ],
    );
  }

  void _toggleFollow(String providerId, Map<String, dynamic> providerData) {
    // 1. Caso Invitado
    if (widget.currentUserId == 'guest' || widget.currentUserId.isEmpty) {
      _showLoginDialog();
      return;
    }

    if (_followedProvidersBox == null) return;

    // NOTA: NO USAMOS setState() AQUÍ.
    // Usamos ValueListenableBuilder en el botón para evitar reconstruir toda la pantalla.
    if (_followedProvidersBox!.containsKey(providerId)) {
      _followedProvidersBox!.delete(providerId);
    } else {
      _followedProvidersBox!.put(providerId, {
        'id': providerId,
        'name': providerData['name'],
        'imagen': providerData['imagen'],
        'verified': providerData['verified'],
      });
    }
  }

  // --- LÓGICA DE MENSAJERÍA (ROBUSTA) ---
  void _handleMessageTap(
      String providerId, Map<String, dynamic> providerData) async {
    // 1. Caso INVITADO
    if (widget.currentUserId == 'guest' || widget.currentUserId.isEmpty) {
      _showLoginDialog();
      return;
    }

    // 2. Indicador de carga
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(),
    );

    try {
      final chatService = ChatService();

      // Obtener datos usuario
      final currentUserDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(widget.currentUserId)
          .get();

      if (!currentUserDoc.exists) throw "Usuario no encontrado";

      final currentUserData = currentUserDoc.data() ?? {};

      // Crear Chat con Timeout
      final chatId = await chatService.getOrCreateChat(
        userId: widget.currentUserId,
        supplierId: providerId,
        userData: {
          'nombre': currentUserData['name'] ?? 'Usuario',
          'imagen': currentUserData['imagen'] ?? '',
        },
        supplierData: {
          'nombre': providerData['name'] ?? 'Proveedor',
          'imagen': providerData['imagen'] ?? '',
        },
      ).timeout(const Duration(seconds: 10));

      // 3. Cerrar Diálogo (ROOT NAVIGATOR)
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      // 4. Navegar
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatDetailScreen(
              chatId: chatId,
              otherName: providerData['name'] ?? 'Proveedor',
              otherImage: providerData['imagen'] ?? '',
              currentUserId: widget.currentUserId,
            ),
          ),
        );
      }
    } catch (e) {
      // Cerrar diálogo si hay error
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al abrir el chat: $e")),
        );
      }
    }
  }

  void _showLoginDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(25.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(HugeIcons.strokeRoundedUserCircle,
                  size: 50, color: Color.fromRGBO(17, 48, 73, 1)),
              const SizedBox(height: 15),
              const Text(
                "Inicia Sesión",
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color.fromRGBO(17, 48, 73, 1),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "Para contactar o seguir al proveedor necesitas una cuenta en Biqoe.",
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Poppins', color: Colors.grey),
              ),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Cerrar diálogo
                    // Navegar al Login
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const LoginFormScreen()));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromRGBO(17, 48, 73, 1),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Ir al Login",
                      style: TextStyle(
                          color: Colors.white, fontFamily: 'Poppins')),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancelar",
                    style:
                        TextStyle(color: Colors.grey, fontFamily: 'Poppins')),
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return FutureBuilder<QuerySnapshot>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Scaffold(
            appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: const BackButton(color: Colors.black)),
            body: _buildNotFoundState(),
          );
        }

        // DATOS DEL PROVEEDOR
        final userDoc = snapshot.data!.docs.first;
        final userData = userDoc.data() as Map<String, dynamic>;
        final String realProviderId = userDoc.id;

        return Scaffold(
          backgroundColor: backgroundColor,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: Padding(
              padding: const EdgeInsets.only(left: 10, top: 10),
              child: _buildCircleButton(
                icon: Icons.arrow_back,
                color: Colors.black,
                onPressed: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                },
              ),
            ),
            actions: [
              // --- BOTÓN SEGUIR (OPTIMIZADO CON ValueListenableBuilder) ---
              if (_followedProvidersBox != null)
                ValueListenableBuilder(
                  valueListenable: _followedProvidersBox!.listenable(),
                  builder: (context, Box box, child) {
                    final bool isFollowing = box.containsKey(realProviderId);

                    return Padding(
                      padding: const EdgeInsets.only(top: 10, right: 10),
                      child: _buildCircleButton(
                        // Íconos iguales a la lista de proveedores
                        icon: isFollowing
                            ? Icons.how_to_reg // Check azul
                            : Icons.person_add_alt_1, // Agregar gris
                        // Colores iguales a la lista
                        color: isFollowing ? primaryColor : Colors.grey,
                        onPressed: () =>
                            _toggleFollow(realProviderId, userData),
                      ),
                    );
                  },
                ),

              // BOTÓN MENSAJE
              Padding(
                padding: const EdgeInsets.only(right: 20, top: 10),
                child: _buildCircleButton(
                  icon: HugeIcons.strokeRoundedMessage01,
                  color: Colors.black,
                  onPressed: () => _handleMessageTap(realProviderId, userData),
                ),
              ),
            ],
          ),
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                _buildProviderHeader(screenWidth, userData, realProviderId),
                const SizedBox(height: 20),
                _buildProviderActivities(screenWidth, realProviderId),
                const SizedBox(height: 50),
                Padding(
                  padding: const EdgeInsets.only(bottom: 40),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Experiencia facilitada por ",
                          style: TextStyle(
                              color: Colors.grey[400],
                              fontFamily: 'Poppins',
                              fontSize: 12)),
                      const Text("Biqoe",
                          style: TextStyle(
                              color: Color.fromRGBO(17, 48, 73, 1),
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                    ],
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  // --- WIDGET BOTÓN CIRCULAR ---
  Widget _buildCircleButton(
      {required IconData icon,
      required VoidCallback onPressed,
      required Color color}) {
    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.1 * 200).round()),
            blurRadius: 2,
            spreadRadius: 0.01,
            offset: const Offset(0, 0.001),
          )
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: color, size: 22),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildNotFoundState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(HugeIcons.strokeRoundedSad01, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 20),
          Text(
            "Proveedor no encontrado",
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderHeader(
      double screenWidth, Map<String, dynamic> data, String providerId) {
    final String name = data['name'] ?? 'Proveedor';
    final String imageUrl = data['imagen'] ?? '';
    final String description = data['descripcion'] ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(25, 100, 25, 30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(35),
          bottomRight: Radius.circular(35),
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // --- AVATAR ---
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: primaryColor.withValues(alpha: 0.1), width: 1),
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 15,
                      offset: const Offset(0, 5))
                ]),
            child: ClipOval(
              child: SizedBox(
                width: 90,
                height: 90,
                child: imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) =>
                            Container(color: Colors.grey[100]),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[100],
                          child: Icon(Icons.person,
                              size: 40, color: Colors.grey[300]),
                        ),
                      )
                    : Container(
                        color: Colors.grey[100],
                        child: Center(
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: TextStyle(
                                fontSize: 35,
                                color: primaryColor,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 15),

          // --- NOMBRE Y VERIFICADO ---
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color.fromRGBO(17, 48, 73, 1),
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              if (data['verified'] == true) ...[
                const SizedBox(width: 5),
                const Icon(Icons.verified, color: Colors.blueAccent, size: 20),
              ]
            ],
          ),
          const SizedBox(height: 10),

          // --- DESCRIPCIÓN ---
          if (description.isNotEmpty)
            MarkdownBody(
              data: description,
              styleSheet: MarkdownStyleSheet(
                p: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    color: Colors.grey[600],
                    height: 1.5),
                strong: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800]),
                textAlign: WrapAlignment.center,
                pPadding: EdgeInsets.zero,
              ),
            ),

          // --- BARRA DE BÚSQUEDA DE RESERVA ---
          const SizedBox(height: 20),
          GestureDetector(
            // USAMOS EL providerId QUE PASAMOS COMO ARGUMENTO
            onTap: () => _showBookingSearchDialog(providerId),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: const Color(0xFFEEEEEE)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(HugeIcons.strokeRoundedSearch01,
                      size: 18, color: Colors.grey[500]),
                  const SizedBox(width: 8),
                  Text(
                    "¿Ya reservaste? Busca tu código aquí",
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderActivities(double screenWidth, String providerId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 10),
              Text(
                "Actividades disponibles",
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800]),
              ),
            ],
          ),
        ),
        const SizedBox(height: 15),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('destinos')
              .where('supplierId', isEqualTo: providerId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: Padding(
                padding: EdgeInsets.all(20),
              ));
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 40, horizontal: 30),
                child: Center(
                  child: Column(
                    children: [
                      Icon(HugeIcons.strokeRoundedTicket01,
                          size: 40, color: Colors.grey[300]),
                      const SizedBox(height: 10),
                      Text("No hay actividades activas.",
                          style: TextStyle(
                              fontFamily: 'Poppins', color: Colors.grey[400])),
                    ],
                  ),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: snapshot.data!.docs.length,
              separatorBuilder: (context, index) => const SizedBox(height: 20),
              itemBuilder: (context, index) {
                final doc = snapshot.data!.docs[index];
                final data = doc.data() as Map<String, dynamic>;

                // AGREGAR ESTA LÍNEA AQUÍ
                data['id'] = doc.id; // <--- ESTA ES LA CORRECCIÓN CRÍTICA

                final paquetes = data['paquetes'] as List<dynamic>? ?? [];
                double minPrice = 0.0;
                if (paquetes.isNotEmpty) {
                  final precios = paquetes
                      .where((p) => p['precio'] != null)
                      .map<double>((p) => (p['precio'] as num).toDouble())
                      .toList();
                  if (precios.isNotEmpty) {
                    minPrice = precios.reduce((a, b) => a < b ? a : b);
                  }
                }
                String displayImage = '';
                if (data['imagenes'] is List &&
                    (data['imagenes'] as List).isNotEmpty) {
                  displayImage = data['imagenes'][0];
                } else if (data['imagen'] is String) {
                  displayImage = data['imagen'];
                } else if (data['imagen'] is List &&
                    (data['imagen'] as List).isNotEmpty) {
                  displayImage = data['imagen'][0];
                }

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DestinationDetailScreen(
                          destino: data,
                          userId: widget.currentUserId,
                        ),
                      ),
                    );
                  },
                  child: ProviderActivityCard(
                    imageUrl: displayImage,
                    title: data['nombre'] ?? 'Actividad sin nombre',
                    location: data['lugar'] ?? (data['estado'] ?? ''),
                    price: minPrice,
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class ProviderActivityCard extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String location;
  final double price;

  const ProviderActivityCard(
      {super.key,
      required this.imageUrl,
      required this.title,
      required this.location,
      required this.price});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha((0.06 * 255).round()),
              blurRadius: 15,
              offset: const Offset(0, 5))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned.fill(
              child: imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (c, u) => Container(color: Colors.grey[100]),
                      errorWidget: (c, u, e) =>
                          Container(color: Colors.grey[200]))
                  : Container(color: Colors.grey[200]),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withAlpha((0.1 * 255).round()),
                      Colors.black.withAlpha((0.8 * 255).round())
                    ],
                    stops: const [0.5, 0.7, 1.0],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 15,
              left: 15,
              right: 15,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Poppins',
                                height: 1.1)),
                        const SizedBox(height: 4),
                        Row(children: [
                          const Icon(HugeIcons.strokeRoundedLocation01,
                              color: Colors.white70, size: 14),
                          const SizedBox(width: 4),
                          Expanded(
                              child: Text(location,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      fontFamily: 'Poppins')))
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10)),
                      child: Text('€${price.toStringAsFixed(0)}',
                          style: const TextStyle(
                              color: Color.fromRGBO(17, 48, 73, 1),
                              fontWeight: FontWeight.w800,
                              fontFamily: 'Poppins',
                              fontSize: 13))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
