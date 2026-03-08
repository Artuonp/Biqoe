import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Para kIsWeb y defaultTargetPlatform
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'chat_list_screen.dart'; // Ajusta la ruta según tu proyecto
import 'supplier/providers_list_screen.dart'; // Ajusta la ruta según tu proyecto
import '../main_screen.dart'; // Ajusta la ruta según tu proyecto

// Colores del tema
const Color kPrimaryColor = Color.fromRGBO(17, 48, 73, 1);
const Color kAccentColor = Color(0xFF3B82F6);
const Color kBackgroundColor = Color(0xFFF8F9FD);
const Color kTextColor = Color(0xFF1F2937);

class SearchScreen extends StatefulWidget {
  final String userId;
  final List<String> destinations;

  const SearchScreen({
    super.key,
    required this.destinations,
    required this.userId,
  });

  @override
  SearchScreenState createState() => SearchScreenState();
}

class SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  String userName = '';
  Box<Map>? savedDestinationsBox;
  Box? followedProvidersBox;
  Set<String> savedDestinationIds = {};
  late final ScrollController _highlightedScrollController;

// 🔥 SOLUCIÓN SAFARI: Lo hacemos opcional (?) para evitar crash al declararlo
  Stream<QuerySnapshot>? _highlightsStream;

  // SOLUCIÓN SAFARI: Banderas para saber qué bloqueó Safari
  bool _hiveError = false;
  bool _firestoreError = false;

  @override
  void initState() {
    super.initState();
    _highlightedScrollController = ScrollController();

    _searchController.addListener(() {
      if (mounted) {
        setState(() {
          _searchText = _searchController.text;
        });
      }
    });

// Inicializamos el Stream UNA SOLA VEZ aquí
    try {
      _highlightsStream = FirebaseFirestore.instance
          .collection('destinos')
          .where('IsHighlighted', isEqualTo: true)
          .orderBy('highlightOrder')
          .snapshots();
    } catch (e) {
      debugPrint("Safari bloqueó Firestore: $e");
      _firestoreError = true;
    }

    // Iniciamos datos sin bloquear el hilo principal
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initNotificationsAndData();
    });
  }

  @override
  void dispose() {
    _highlightedScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // --- LÓGICA DE NEGOCIO ---
  Future<void> _initNotificationsAndData() async {
    // Notificaciones (Solo móvil)
    if (!kIsWeb) {
      requestNotificationPermission();
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        debugPrint('Token actualizado: $newToken');
        _saveTokenToDatabase(newToken);
      });
    }

    // Cargar Nombre
    fetchUserName();

    // Cargar Favoritos (Hive)
    try {
      // 1. Cargar Destinos Guardados
      final box =
          await Hive.openBox<Map>('saved_destinations_${widget.userId}');

      // 2. Cargar Proveedores Seguidos (NUEVO)
      Box? providersBox;
      if (widget.userId.isNotEmpty && widget.userId != 'guest') {
        providersBox =
            await Hive.openBox('followed_providers_${widget.userId}');
      }

      if (mounted) {
        setState(() {
          savedDestinationsBox = box;
          savedDestinationIds = box.keys.cast<String>().toSet();
          followedProvidersBox = providersBox; // Asignamos la caja
        });
      }
    } catch (e) {
      debugPrint("Error abriendo Hive (Modo incógnito Safari): $e");
      if (mounted) {
        setState(() {
          _hiveError = true; // Activamos el modo seguro sin Hive
        });
      }
    }
  }

  Future<void> requestNotificationPermission() async {
    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        await messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        _handleTokenRegistration();
      }
    } catch (e) {
      debugPrint('Error en permisos: $e');
    }
  }

  Future<void> _handleTokenRegistration() async {
    try {
      final messaging = FirebaseMessaging.instance;
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        await _getAPNSTokenWithRetry();
      }
      String? fcmToken = await messaging.getToken();
      if (fcmToken != null) await _saveTokenToDatabase(fcmToken);
    } catch (e) {
      debugPrint('Error registrando token: $e');
    }
  }

  Future<String?> _getAPNSTokenWithRetry() async {
    try {
      String? apnsToken = await FirebaseMessaging.instance.getAPNSToken();
      if (apnsToken == null) {
        await Future.delayed(const Duration(seconds: 2));
        return _getAPNSTokenWithRetry();
      }
      return apnsToken;
    } catch (e) {
      return null;
    }
  }

  Future<void> _saveTokenToDatabase(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return;
    try {
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(widget.userId)
          .update({
        'deviceToken': token,
        'tokenActualizado': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error guardando token: $e');
    }
  }

  void toggleSaveDestination(
      String destinationId, Map<String, dynamic> destination) {
    final userBoxName = 'saved_destinations_${widget.userId}';

    // Limpiamos los datos antes de guardar
    final cleanDestination = _cleanDataForHive(destination);

    Hive.openBox<Map>(userBoxName).then((userBox) {
      if (userBox.containsKey(destinationId)) {
        userBox.delete(destinationId);
        savedDestinationIds.remove(destinationId);
      } else {
        userBox.put(destinationId, cleanDestination);
        savedDestinationIds.add(destinationId);
      }
      // NOTA: Ya no hacemos setState() aquí para evitar el parpadeo blanco.
      // El ValueListenableBuilder se encargará de actualizar el ícono.
    });
  }

  bool isDestinationSaved(String destinationId) {
    return savedDestinationIds.contains(destinationId);
  }

  double _getMinPrice(List<dynamic> paquetes) {
    if (paquetes.isEmpty) return 0.0;
    final precios = paquetes
        .where((p) => p['precio'] != null)
        .map<double>((p) => (p['precio'] as num).toDouble())
        .toList();
    return precios.isNotEmpty ? precios.reduce((a, b) => a < b ? a : b) : 0.0;
  }

  void fetchUserName() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.isAnonymous) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .get();
      if (userDoc.exists && mounted) {
        final fullName = userDoc.data()?['name'] ?? '';
        setState(() {
          userName = fullName.split(' ')[0];
        });
      }
    } catch (e) {
      debugPrint("Error obteniendo nombre (Seguro en Safari): $e");
    }
  }

  void _navigateToCategory(String category) {
    if (category == "Restaurantes") {
      context.push('/restaurants');
      return;
    }
    context.push(
      '/destinations-list',
      extra: {
        'userId': widget.userId,
        'destinations': <String>[],
        'initialCategories': [category],
        'initialLocation': 'Todas',
        'sortOption': 0,
        'searchText': _searchText,
      },
    );
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
                "Necesitas una cuenta para acceder a mensajes y seguir guías.",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(color: Colors.grey),
              ),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text("Ir al login",
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

  // --- AYUDANTE: LIMPIAR DATOS PARA HIVE (EVITA CRASH) ---
  Map<String, dynamic> _cleanDataForHive(Map<dynamic, dynamic> data) {
    final Map<String, dynamic> clean = {};
    data.forEach((key, value) {
      if (value is Timestamp) {
        clean[key.toString()] = value.toDate().toIso8601String();
      } else if (value is Map) {
        clean[key.toString()] = _cleanDataForHive(value);
      } else if (value is List) {
        clean[key.toString()] = value.map((e) {
          if (e is Map) return _cleanDataForHive(e);
          if (e is Timestamp) return e.toDate().toIso8601String();
          return e;
        }).toList();
      } else {
        clean[key.toString()] = value;
      }
    });
    return clean;
  }

  // --- UI START ---
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: kBackgroundColor,
        body: SafeArea(
          bottom: false,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // 1. Header & Search
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 25),
                      _buildModernSearchBar(),
                    ],
                  ),
                ),
              ),

              // 2. Categorías
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Categorías',
                                style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: kTextColor)),
                            GestureDetector(
                              onTap: () => _navigateToCategory('Todas'),
                              child: Text('Ver todo',
                                  style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: kAccentColor)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 15),
                      _buildCategoriesList(),
                    ],
                  ),
                ),
              ),

              // 3. Destacados
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 15),
                      child: Text('Opciones destacadas',
                          style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: kTextColor)),
                    ),
                    _buildHighlightsStream(),
                  ],
                ),
              ),

              // 4. Seguidos
              // 4. Seguidos
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(0, 10, 0, 100),
                sliver: SliverToBoxAdapter(
                  child: _buildFollowedSection(), // El título ahora está dentro
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGETS AUXILIARES DE DISEÑO ---

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              userName.isNotEmpty ? 'Hola, $userName 👋' : 'Hola 👋',
              style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: kPrimaryColor),
            ),
            Text(
              'Explora lo mejor de Venezuela',
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),

        // --- NUEVO ÍCONO DE MENSAJES ---
        GestureDetector(
          onTap: () {
            // Validación de Invitado
            if (widget.userId == 'guest' || widget.userId.isEmpty) {
              _showLoginDialog();
            } else {
              // Navegar a ChatListScreen
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ChatListScreen(currentUserId: widget.userId),
                ),
              );
            }
          },
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ],
                border: Border.all(color: Colors.grey.shade100)),
            child: const Icon(
              HugeIcons.strokeRoundedMessage01,
              color: kPrimaryColor,
              size: 24,
            ),
          ),
        )
      ],
    );
  }

  Widget _buildModernSearchBar() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 15,
                    offset: const Offset(0, 5)),
              ],
            ),
            child: TextField(
              controller: _searchController,
              readOnly: true,
              onTap: () {
                context.push('/search-results');
              },
              style: GoogleFonts.poppins(fontSize: 14),
              decoration: InputDecoration(
                hintText: '¿A dónde quieres ir?',
                hintStyle:
                    GoogleFonts.poppins(color: Colors.grey[400], fontSize: 14),
                prefixIcon:
                    const Icon(Icons.search_rounded, color: kPrimaryColor),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: () {
            context.push('/filter', extra: {
              'userId': widget.userId,
              'destinations': widget.destinations,
              'selectedCategories': const ['Todas'],
              'selectedLocation': 'Todas',
              'searchText': _searchText,
            });
          },
          child: Container(
            height: 52,
            width: 52,
            decoration: BoxDecoration(
              color: kPrimaryColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: kPrimaryColor.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4)),
              ],
            ),
            child:
                const Icon(Icons.tune_rounded, color: Colors.white, size: 24),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoriesList() {
    final Map<String, IconData> categoryIcons = {
      'Ciudad': Icons.location_city,
      'Playa': Icons.beach_access,
      'Restaurantes': Icons.restaurant,
      'Eventos': Icons.event,
      'Hospedaje': Icons.hotel,
      'Talleres': Icons.brush,
      'Bienestar': Icons.spa,
      'Cultura': Icons.museum,
      'Arte': Icons.palette,
      'Vida nocturna': Icons.nightlife,
      'Extremo': Icons.paragliding,
      'Montaña': Icons.landscape,
      'Divertido': Icons.sentiment_very_satisfied,
      'Online': Icons.computer,
    };

    final categories = categoryIcons.keys.toList();

    return SizedBox(
      height: 90,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (c, i) => const SizedBox(width: 15),
        itemBuilder: (context, index) {
          final category = categories[index];
          final icon = categoryIcons[category] ?? Icons.category;
          return _CategoryItem(
              label: category,
              icon: icon,
              onTap: () => _navigateToCategory(category));
        },
      ),
    );
  }

  Widget _buildFollowedSection() {
    final List<String> followingIds =
        followedProvidersBox?.keys.cast<String>().toList() ?? [];

    if (followingIds.isEmpty) {
      return Center(child: _buildEmptyFollowedState());
    }

    final idsToQuery = followingIds.take(10).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Tus proveedores',
                  style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: kTextColor)),
              GestureDetector(
                onTap: () {
                  if (widget.userId == 'guest' || widget.userId.isEmpty) {
                    _showLoginDialog();
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ProvidersListScreen(currentUserId: widget.userId),
                      ),
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: kPrimaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add, size: 20, color: kPrimaryColor),
                ),
              )
            ],
          ),
        ),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('destinos')
              .where('supplierId', whereIn: idsToQuery)
              .where('status', isEqualTo: 'active')
              .limit(10)
              .snapshots(),
          builder: (context, destSnap) {
            if (destSnap.connectionState == ConnectionState.waiting) {
              return const Center();
            }

            if (!destSnap.hasData || destSnap.data!.docs.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  width: double.infinity,
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Tus proveedores no tienen actividades activas.",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(color: Colors.grey),
                      ),
                      TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ProvidersListScreen(
                                    currentUserId: widget.userId),
                              ),
                            );
                          },
                          child: Text("Buscar otros",
                              style: GoogleFonts.poppins(color: kAccentColor)))
                    ],
                  ),
                ),
              );
            }

            final destinations = destSnap.data!.docs;

            // CAMBIO 3: Protección contra nulos en la lista de proveedores
            if (savedDestinationsBox == null) {
              return const Padding(
                padding: EdgeInsets.all(20.0),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            // Escuchamos Hive también aquí
            return ValueListenableBuilder(
                valueListenable:
                    savedDestinationsBox!.listenable(), // Usamos ! aquí
                builder: (context, Box<Map> box, _) {
                  return ListView.separated(
                    // KEY MÁGICA PARA EL SCROLL VERTICAL:
                    key: const PageStorageKey('followed_scroll_key'),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: destinations.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 25),
                    itemBuilder: (context, index) {
                      final destination = destinations[index];
                      final data = destination.data() as Map<String, dynamic>;
                      data['id'] = destination.id;

                      final isSaved = box.containsKey(destination.id);

                      // Imágenes
                      List<String> images = [];
                      if (data['imagenes'] != null &&
                          data['imagenes'] is List) {
                        images = List<String>.from(data['imagenes'])
                            .where((e) => e.isNotEmpty)
                            .toList();
                      } else if (data['imagen'] != null &&
                          data['imagen'] is String) {
                        String cleaned = data['imagen']
                            .toString()
                            .replaceAll('[', '')
                            .replaceAll(']', '');
                        images = cleaned
                            .split(',')
                            .map((e) => e.trim())
                            .where((e) => e.isNotEmpty)
                            .toList();
                      }

                      // Ubicación
                      String location = 'Venezuela';
                      if (data['ubicacion'] != null &&
                          data['ubicacion'].toString().isNotEmpty) {
                        location = data['ubicacion'];
                      } else {
                        location =
                            data['lugar'] ?? data['estado'] ?? 'Venezuela';
                      }

                      return GestureDetector(
                        onTap: () =>
                            context.push('/d/${destination.id}', extra: data),
                        child: SizedBox(
                          // ALTURA AUMENTADA PARA QUE SEA MÁS "CUADRADO/ALARGADO"
                          height: 320,
                          width: double.infinity,
                          // Reutilizamos DestinationCard para tener carrusel de fotos
                          child: DestinationCard(
                            key: ValueKey(destination.id),
                            images: images,
                            title: data['nombre'] ?? 'Sin nombre',
                            location: location,
                            place: data['lugar'] ?? '',
                            price: _getMinPrice(data['paquetes'] ?? []),
                            isSaved: isSaved,
                            onFavoriteTap: () =>
                                toggleSaveDestination(destination.id, data),
                            onTap: () => context.push('/d/${destination.id}',
                                extra: data),
                            screenWidth: double.infinity, // Ocupa todo el ancho
                          ),
                        ),
                      );
                    },
                  );
                });
          },
        ),
      ],
    );
  }

  Widget _buildEmptyFollowedState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 15),
          child: Text('Tus proveedores',
              style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: kTextColor)),
        ),
        Center(
          // Centrado horizontal
          child: Container(
            width: double
                .infinity, // Ocupar todo el ancho disponible menos margenes
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 15,
                    offset: const Offset(0, 5))
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                      color: kPrimaryColor.withValues(alpha: 0.05),
                      shape: BoxShape.circle),
                  child: Icon(Icons.person_add_alt_1_rounded,
                      size: 30, color: kPrimaryColor),
                ),
                const SizedBox(height: 15),
                Text(
                  "Busca proveedores",
                  style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: kTextColor),
                ),
                const SizedBox(height: 8),
                Text(
                  "Sigue a tus proveedores favoritos para ver sus nuevas publicaciones aquí.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                      fontSize: 13, color: Colors.grey[600], height: 1.4),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (widget.userId == 'guest' || widget.userId.isEmpty) {
                        _showLoginDialog();
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProvidersListScreen(
                                currentUserId: widget.userId),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryColor,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                    ),
                    child: Text("Descubrir",
                        style: GoogleFonts.poppins(
                            color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                )
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- STREAM DESTACADOS (Con Scroll Persistente) ---
  Widget _buildHighlightsStream() {
    // Si Safari bloqueó Firestore, mostramos un mensaje vacío en lugar de explotar
    if (_firestoreError || _highlightsStream == null) {
      return SizedBox(
        height: 280,
        child: Center(
            child: Text('Inicia sesión para ver recomendaciones',
                style: GoogleFonts.poppins(color: Colors.grey))),
      );
    }

    return SizedBox(
      height: 280,
      child: StreamBuilder<QuerySnapshot>(
        stream: _highlightsStream!, // Ya estamos seguros de que no es nulo
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center();
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
                child: Text('No hay destacados por ahora',
                    style: GoogleFonts.poppins(color: Colors.grey)));
          }

          final destinations = snapshot.data!.docs;

          // CAMBIO: Si Hive no ha cargado y NO hay error, esperamos.
          // Si hay error (_hiveError = true), pasamos de largo y mostramos las tarjetas.
          if (savedDestinationsBox == null && !_hiveError) {
            return const Center(child: CircularProgressIndicator());
          }

          // Función interna para dibujar la lista, así no repetimos código
          Widget buildHighlightList(Box<Map>? box) {
            return ListView.builder(
              key: const PageStorageKey('highlights_scroll_key'),
              controller: _highlightedScrollController,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: destinations.length,
              itemBuilder: (context, index) {
                final destination = destinations[index];
                final data = destination.data() as Map<String, dynamic>;
                data['id'] = destination.id;

                // Si hay error en Hive, asumimos que no está guardado (false)
                final isSaved =
                    _hiveError ? false : box!.containsKey(destination.id);

                List<String> images = [];
                if (data['imagenes'] != null && data['imagenes'] is List) {
                  images = List<String>.from(data['imagenes'])
                      .where((e) => e.isNotEmpty)
                      .toList();
                } else if (data['imagen'] != null && data['imagen'] is String) {
                  String cleaned = data['imagen']
                      .toString()
                      .replaceAll('[', '')
                      .replaceAll(']', '');
                  images = cleaned
                      .split(',')
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toList();
                }

                String location = 'Venezuela';
                if (data['ubicacion'] != null &&
                    data['ubicacion'].toString().isNotEmpty) {
                  location = data['ubicacion'];
                } else {
                  location = data['lugar'] ?? data['estado'] ?? 'Venezuela';
                }

                return Padding(
                  padding: const EdgeInsets.only(right: 15),
                  child: GestureDetector(
                    onTap: () =>
                        context.push('/d/${destination.id}', extra: data),
                    child: DestinationCard(
                      key: ValueKey(destination.id),
                      images: images,
                      title: data['nombre'] ?? 'Sin nombre',
                      location: location,
                      place: data['lugar'] ?? '',
                      price: _getMinPrice(data['paquetes'] ?? []),
                      isSaved: isSaved,
                      onFavoriteTap: () {
                        if (!_hiveError) {
                          toggleSaveDestination(destination.id, data);
                        }
                      },
                      onTap: () =>
                          context.push('/d/${destination.id}', extra: data),
                      screenWidth: 280,
                    ),
                  ),
                );
              },
            );
          }

          // Si hay error de Hive, devolvemos la lista pasando null
          if (_hiveError) {
            return buildHighlightList(null);
          }

          // Si Hive funciona bien, usamos el ValueListenableBuilder
          return ValueListenableBuilder(
            valueListenable: savedDestinationsBox!.listenable(),
            builder: (context, Box<Map> box, _) => buildHighlightList(box),
          );
        },
      ),
    );
  }
}

// --- COMPONENTES VISUALES ---

class _CategoryItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _CategoryItem(
      {required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 55,
            width: 55,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2))
              ],
            ),
            child: Icon(icon, color: kPrimaryColor, size: 24),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: kTextColor)),
        ],
      ),
    );
  }
}

// --- TARJETA DE DESTINO (ACTUALIZADA) ---
class DestinationCard extends StatefulWidget {
  final List<String> images;
  final String title;
  final String location;
  final String place;
  final double price;
  final bool isSaved;
  final VoidCallback onFavoriteTap;

  // Estos son los dos parámetros que te faltaban:
  final double screenWidth;
  final VoidCallback onTap;

  const DestinationCard({
    super.key,
    required this.images,
    required this.title,
    required this.location,
    required this.place,
    required this.price,
    required this.isSaved,
    required this.onFavoriteTap,
    required this.screenWidth, // <--- Nuevo
    required this.onTap, // <--- Nuevo
  });

  @override
  State<DestinationCard> createState() => _DestinationCardState();
}

class _DestinationCardState extends State<DestinationCard> {
  late bool localIsSaved;
  final PageController pageController = PageController();
  int currentPage = 0;

  @override
  void initState() {
    super.initState();
    localIsSaved = widget.isSaved;
  }

  @override
  void didUpdateWidget(DestinationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isSaved != widget.isSaved) {
      localIsSaved = widget.isSaved;
    }
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Calculamos la altura basada en el ancho recibido
    // Si el ancho es infinito (lista vertical), usamos una altura fija segura
    double width = widget.screenWidth;
    double height = 320; // Altura fija estándar

    if (width != double.infinity) {
      // Ajuste para carrusel horizontal (width = 280)
      height = width * 1.1;
    }

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 15,
              offset: const Offset(0, 8))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // 1. Imagen Fondo Full (Carrusel)
            Positioned.fill(
              child: widget.images.isNotEmpty
                  ? PageView.builder(
                      controller: pageController,
                      itemCount: widget.images.length,
                      onPageChanged: (index) =>
                          setState(() => currentPage = index),
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          onTap: widget.onTap, // Usamos el onTap aquí
                          child: CachedNetworkImage(
                            imageUrl: widget.images[index],
                            fit: BoxFit.cover,
                            placeholder: (context, url) =>
                                Container(color: Colors.grey[200]),
                            errorWidget: (context, url, error) => Container(
                                color: Colors.grey[300],
                                child: const Icon(Icons.image_not_supported)),
                          ),
                        );
                      },
                    )
                  : GestureDetector(
                      onTap: widget.onTap,
                      child: Container(
                        color: Colors.grey[300],
                        child: const Center(
                            child: Icon(Icons.image_not_supported)),
                      ),
                    ),
            ),

            // 2. Gradiente Oscuro
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 140, // Un poco más alto para mejor lectura
              child: IgnorePointer(
                // Permite hacer click a través del gradiente
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.9),
                        Colors.black.withValues(alpha: 0.5),
                        Colors.transparent
                      ],
                      stops: const [0.0, 0.6, 1.0],
                    ),
                  ),
                ),
              ),
            ),

            // 3. Indicadores de página (Puntos)
            // 3. Indicadores de página (Puntos)
            if (widget.images.length > 1)
              Positioned(
                bottom: 20, // Cambiado de top a bottom
                right: 20, // Cambiado de left a right
                child: Row(
                  children: List.generate(widget.images.length, (index) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.only(
                          left:
                              6), // Margen a la izquierda para que crezcan hacia la izquierda visualmente
                      width: currentPage == index ? 24 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: currentPage == index
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
              ),

            // 4. Información (Título, Ubicación)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: GestureDetector(
                onTap: widget.onTap, // Permitir click en el texto también
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.place.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          widget.place.toUpperCase(),
                          style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                      ),
                    Text(
                      widget.title,
                      style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                                blurRadius: 4,
                                color: Colors.black.withValues(alpha: 0.5))
                          ]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            size: 14, color: Colors.white),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            widget.location,
                            style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.9)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // 5. Precio (Pill Glass Superior Izquierda)
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Desde ',
                      style: GoogleFonts.poppins(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 10),
                    ),
                    Text(
                      '\$${widget.price.toStringAsFixed(0)}',
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),

            // 6. Botón Favorito (Superior Derecha)
            Positioned(
              top: 16,
              right: 16,
              child: GestureDetector(
                onTap: () {
                  // Actualización optimista
                  setState(() => localIsSaved = !localIsSaved);
                  widget.onFavoriteTap();
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4)
                    ],
                  ),
                  child: Icon(
                    localIsSaved ? Icons.favorite : Icons.favorite_border,
                    color: localIsSaved
                        ? const Color.fromRGBO(17, 48, 73, 1)
                        : Colors.grey[800],
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
