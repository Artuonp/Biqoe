import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hugeicons/hugeicons.dart';

// --- IMPORTS ---
import 'provider_profile_screen.dart';
import '../chat_detail_screen.dart';
import '../../services/chat_service.dart';
import '../../login_screen.dart';

const Color kPrimaryColor = Color.fromRGBO(17, 48, 73, 1);
const Color kBackgroundColor = Color(0xFFF3F7FE);

class ProvidersListScreen extends StatefulWidget {
  final String currentUserId;

  const ProvidersListScreen({super.key, required this.currentUserId});

  @override
  State<ProvidersListScreen> createState() => _ProvidersListScreenState();
}

class _ProvidersListScreenState extends State<ProvidersListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchText = "";
  Box? _followedProvidersBox;
  bool _isHiveLoading = true;

  @override
  void initState() {
    super.initState();
    _initHive();
    _searchController.addListener(() {
      setState(() {
        _searchText = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // --- INICIALIZAR HIVE ---
  Future<void> _initHive() async {
    if (widget.currentUserId.isNotEmpty && widget.currentUserId != 'guest') {
      try {
        _followedProvidersBox =
            await Hive.openBox('followed_providers_${widget.currentUserId}');
      } catch (e) {
        debugPrint("Error abriendo Hive Providers: $e");
      }
    }
    if (mounted) {
      setState(() {
        _isHiveLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: kBackgroundColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: kPrimaryColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Proveedores",
          style: GoogleFonts.poppins(
            color: kPrimaryColor,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: Column(
        children: [
          // --- BARRA DE BÚSQUEDA ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha((0.05 * 255).round()),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                style: GoogleFonts.poppins(color: Colors.black87),
                decoration: InputDecoration(
                  hintText: "Buscar proveedor",
                  hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
          ),

          // --- LISTA ---
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('usuarios')
                  .where('isSupplier', isEqualTo: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}"));
                }

                if (snapshot.connectionState == ConnectionState.waiting ||
                    _isHiveLoading) {
                  return const Center();
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline,
                            size: 60, color: Colors.grey[300]),
                        const SizedBox(height: 10),
                        Text("No hay proveedores disponibles",
                            style: GoogleFonts.poppins(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                // Filtrado local
                final docs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['name'] ?? '').toString().toLowerCase();
                  final search = _searchText.toLowerCase();

                  // Excluir empleados
                  final isEmployee = data['associatedSupplierId'] != null &&
                      data['associatedSupplierId'].toString().isNotEmpty;

                  // Excluir proveedores privados (isPrivate == true)
                  // Si el campo no existe o es false → se muestra
                  final isPrivate = data['isPrivate'] == true;

                  return name.contains(search) && !isEmployee && !isPrivate;
                }).toList();

                if (docs.isEmpty) {
                  return Center(
                      child: Text("No se encontraron resultados",
                          style: GoogleFonts.poppins(color: Colors.grey)));
                }

                return ListView.builder(
                  key: const PageStorageKey('providers_list_key'),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final supplierId = docs[index].id;

                    return ProviderCard(
                      key: ValueKey(supplierId),
                      data: data,
                      supplierId: supplierId,
                      currentUserId: widget.currentUserId,
                      followedBox: _followedProvidersBox,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// --- WIDGET TARJETA DE PROVEEDOR (STATEFUL) ---
class ProviderCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final String supplierId;
  final String currentUserId;
  final Box? followedBox;

  const ProviderCard({
    super.key,
    required this.data,
    required this.supplierId,
    required this.currentUserId,
    required this.followedBox,
  });

  @override
  State<ProviderCard> createState() => _ProviderCardState();
}

class _ProviderCardState extends State<ProviderCard> {
  late bool isFollowing;

  @override
  void initState() {
    super.initState();
    _checkIsFollowing();
  }

  void _checkIsFollowing() {
    if (widget.followedBox != null) {
      setState(() {
        isFollowing = widget.followedBox!.containsKey(widget.supplierId);
      });
    } else {
      isFollowing = false;
    }
  }

  // --- LOGICA SEGUIR (LOCAL) ---
  void _toggleFollow() {
    if (widget.currentUserId == 'guest' || widget.currentUserId.isEmpty) {
      _showLoginDialog(context);
      return;
    }

    if (widget.followedBox == null) return;

    setState(() {
      if (isFollowing) {
        widget.followedBox!.delete(widget.supplierId);
        isFollowing = false;
      } else {
        widget.followedBox!.put(widget.supplierId, {
          'id': widget.supplierId,
          'name': widget.data['name'],
          'imagen': widget.data['imagen'],
          'verified': widget.data['verified'],
        });
        isFollowing = true;
      }
    });
  }

  // --- LOGICA CHAT (CORREGIDA Y ROBUSTA) ---
  void _handleChat() async {
    // 1. Invitado
    if (widget.currentUserId == 'guest' || widget.currentUserId.isEmpty) {
      _showLoginDialog(context);
      return;
    }

    // 2. Mostrar Carga
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(),
    );

    String? chatIdResult;
    String? errorMessage;

    try {
      final chatService = ChatService();

      // Obtener datos usuario
      final currentUserDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(widget.currentUserId)
          .get();

      if (!currentUserDoc.exists) throw "Usuario no encontrado";

      final currentUserData = currentUserDoc.data() ?? {};

      // Crear/Obtener Chat
      chatIdResult = await chatService.getOrCreateChat(
        userId: widget.currentUserId,
        supplierId: widget.supplierId,
        userData: {
          'nombre': currentUserData['name'] ?? 'Usuario',
          'imagen': currentUserData['imagen'] ?? '',
        },
        supplierData: {
          'nombre': widget.data['name'] ?? 'Proveedor',
          'imagen': widget.data['imagen'] ?? '',
        },
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      errorMessage = e.toString();
    }

    // 3. Cerrar Diálogo (Siempre cerramos primero)
    if (mounted) {
      // Usamos el navegador raíz para asegurar el cierre del diálogo
      Navigator.of(context, rootNavigator: true).pop();
    }

    // 4. Procesar resultado
    if (mounted) {
      if (chatIdResult != null) {
        // ÉXITO: Navegar al chat
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatDetailScreen(
              chatId: chatIdResult!,
              otherName: widget.data['name'] ?? 'Proveedor',
              otherImage: widget.data['imagen'] ?? '',
              currentUserId: widget.currentUserId,
            ),
          ),
        );
      } else if (errorMessage != null) {
        // ERROR: Mostrar snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: $errorMessage"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showLoginDialog(BuildContext context) {
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
                  size: 50, color: kPrimaryColor),
              const SizedBox(height: 15),
              Text(
                "Inicia Sesión",
                style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: kPrimaryColor),
              ),
              const SizedBox(height: 10),
              Text(
                "Necesitas una cuenta para realizar esta acción.",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(color: Colors.grey),
              ),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const LoginFormScreen()));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text("Ir al Login",
                      style: GoogleFonts.poppins(color: Colors.white)),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("Cancelar",
                    style: GoogleFonts.poppins(color: Colors.grey)),
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String name = widget.data['name'] ?? 'Proveedor';
    final String image = widget.data['imagen'] ?? '';
    final bool isVerified = widget.data['verified'] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.04 * 255).round()),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () {
            // Ir al Perfil
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProviderProfileScreen(
                  slug: widget.data['slug'] ?? '',
                  currentUserId: widget.currentUserId,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // --- AVATAR ---
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade100, width: 1),
                  ),
                  child: ClipOval(
                    child: image.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: image,
                            fit: BoxFit.cover,
                            placeholder: (context, url) =>
                                Container(color: Colors.grey[100]),
                            errorWidget: (context, url, error) =>
                                const Icon(Icons.person),
                          )
                        : Container(
                            color: Colors.grey[100],
                            child: const Icon(Icons.person, color: Colors.grey),
                          ),
                  ),
                ),

                const SizedBox(width: 14),

                // --- INFO ---
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: kPrimaryColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isVerified) ...[
                            const SizedBox(width: 5),
                            const Icon(Icons.verified,
                                size: 18, color: Colors.blue),
                          ]
                        ],
                      ),
                    ],
                  ),
                ),

                // --- ACCIONES ---
                Row(
                  children: [
                    // Botón Mensaje
                    GestureDetector(
                      onTap: _handleChat,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                            color: kPrimaryColor.withAlpha((0.1 * 255).round()),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                  color: kPrimaryColor
                                      .withAlpha((0.1 * 255).round()),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2))
                            ]),
                        child: const Icon(
                          HugeIcons.strokeRoundedMessage01,
                          size: 20,
                          color: kPrimaryColor,
                        ),
                      ),
                    ),

                    // Botón Seguir
                    GestureDetector(
                      onTap: _toggleFollow,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                            color: isFollowing
                                ? kPrimaryColor.withAlpha((0.1 * 255).round())
                                : Colors.grey.withAlpha((0.1 * 255).round()),
                            shape: BoxShape.circle,
                            boxShadow: [
                              if (!isFollowing)
                                BoxShadow(
                                    color: Colors.black
                                        .withAlpha((0.05 * 255).round()),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2))
                            ]),
                        child: Icon(
                          isFollowing
                              ? Icons.how_to_reg // Check
                              : Icons.person_add_alt_1, // Agregar Usuario
                          size: 22,
                          color: isFollowing ? kPrimaryColor : Colors.grey,
                        ),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
