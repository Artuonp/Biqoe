// Importaciones necesarias para el funcionamiento de la aplicación
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:io' show Platform;
import 'destinations_screen.dart';
import 'filter_screen.dart';
import 'bookings_screen.dart';
import 'saved_destinations_screen.dart';
import 'settings_screen.dart';
import 'search_results_screen.dart';
import 'destination_detail_screen.dart';
import 'package:hugeicons/hugeicons.dart';
import 'restaurants_screen.dart'; // Agrega este import si no lo tienes

// Clase principal de la pantalla de búsqueda
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

// Estado de la pantalla de búsqueda
class SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  List<Map<String, dynamic>> savedDestinations = [];
  String userName = '';
  late Box<Map> savedDestinationsBox;
  Set<String> savedDestinationIds = {};
  late final ScrollController _highlightedScrollController;
  List<QueryDocumentSnapshot>? _displayedDestinations;

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

    _initNotificationsAndData();
  }

  @override
  void dispose() {
    _highlightedScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initNotificationsAndData() async {
    await requestNotificationPermission();
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      debugPrint('Token actualizado: $newToken');
      _saveTokenToDatabase(newToken);
    });
    fetchUserName();
    Hive.openBox<Map>('saved_destinations_${widget.userId}').then((box) {
      if (mounted) {
        setState(() {
          savedDestinationsBox = box;
          savedDestinationIds = box.keys.cast<String>().toSet();
        });
      }
    });
  }

  Future<void> requestNotificationPermission() async {
    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;

      // Configuración específica para iOS
      if (Platform.isIOS) {
        await messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      // Solicitar permisos
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('Permiso de notificación concedido');
        await _handleTokenRegistration();
      } else {
        debugPrint('Permiso de notificación denegado');
      }
    } catch (e) {
      debugPrint('Error en permisos: $e');
      if (e.toString().contains('apns-token-not-set')) {
        debugPrint('Reintentando en 3 segundos...');
        await Future.delayed(const Duration(seconds: 3));
        await requestNotificationPermission();
      }
    }
  }

  Future<void> _handleTokenRegistration() async {
    try {
      final messaging = FirebaseMessaging.instance;

      // Manejo especial para iOS
      if (Platform.isIOS) {
        String? apnsToken = await _getAPNSTokenWithRetry();
        debugPrint('APNS Token obtenido: $apnsToken');
      }

      // Obtener y guardar FCM Token
      String? fcmToken = await messaging.getToken();
      debugPrint('FCM Token: $fcmToken');

      if (fcmToken != null) {
        await _saveTokenToDatabase(fcmToken);
      }
    } catch (e) {
      debugPrint('Error registrando token: $e');
      if (e.toString().contains('apns-token-not-set')) {
        await Future.delayed(const Duration(seconds: 2));
        await _handleTokenRegistration();
      }
    }
  }

  Future<String?> _getAPNSTokenWithRetry() async {
    try {
      String? apnsToken = await FirebaseMessaging.instance.getAPNSToken();
      if (apnsToken == null) {
        debugPrint('APNS Token no disponible, reintentando...');
        await Future.delayed(const Duration(seconds: 2));
        return _getAPNSTokenWithRetry();
      }
      return apnsToken;
    } catch (e) {
      debugPrint('Error obteniendo APNS Token: $e');
      return null;
    }
  }

  Future<void> _saveTokenToDatabase(String token) async {
    try {
      // Guardar el token en Firestore
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(widget.userId)
          .update({
        'deviceToken': token,
        'tokenActualizado': FieldValue.serverTimestamp(),
      });
      debugPrint('Token guardado exitosamente');
    } catch (e) {
      debugPrint('Error guardando token: $e');
    }
  }

  void toggleSaveDestination(
      String destinationId, Map<String, dynamic> destination) {
    final userBoxName = 'saved_destinations_${widget.userId}';
    Hive.openBox<Map>(userBoxName).then((userBox) {
      if (isDestinationSaved(destinationId)) {
        userBox.delete(destinationId);
        savedDestinationIds.remove(destinationId);
      } else {
        userBox.put(destinationId, destination);
        savedDestinationIds.add(destinationId);
      }
      // No llames a setState aquí
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

  // Obtiene el nombre del usuario desde Firestore
  void fetchUserName() async {
    final userDoc = await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(widget.userId)
        .get();
    if (userDoc.exists) {
      final fullName = userDoc.data()?['name'] ?? '';
      if (mounted) {
        setState(() {
          userName = fullName.split(' ')[0]; // Usa solo el primer nombre
        });
      }
    }
  }

  // Navega a la pantalla de una categoría específica
  void _navigateToCategory(String category) {
    if (category == "Restaurantes") {
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => RestaurantsScreen(
            userId: widget.userId,
          ),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
      return;
    }
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => DestinationsScreen(
          userId: widget.userId,
          destinations: const [],
          initialCategories: [category],
          initialLocation: 'Todas',
          sortOption: 0,
          searchText: _searchText,
        ),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color.fromARGB(255, 243, 247, 254),
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sección superior: saludo, avatar, buscador (con padding simétrico)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: screenHeight * 0.1),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          userName.isNotEmpty
                              ? 'Hola, $userName 👋'
                              : 'Hola 👋',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: screenWidth * 0.08,
                            fontWeight: FontWeight.bold,
                            color: const Color.fromRGBO(17, 48, 73, 1),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: screenHeight * 0.01),
                    Text(
                      'Explora Venezuela',
                      style: TextStyle(
                        fontSize: screenWidth * 0.05,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.03),
                    // Buscador
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          PageRouteBuilder(
                            pageBuilder: (_, __, ___) => SearchResultsScreen(
                              userId: widget.userId,
                            ),
                            transitionsBuilder: (_, animation, __, child) {
                              return FadeTransition(
                                opacity: animation,
                                child: child,
                              );
                            },
                            transitionDuration:
                                const Duration(milliseconds: 600),
                          ),
                        );
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: screenWidth * 0.04),
                        height: screenHeight * 0.06,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey),
                          borderRadius:
                              BorderRadius.circular(screenWidth * 0.08),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Encuentra un nuevo plan',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: screenWidth * 0.04,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ),
                            VerticalDivider(
                              thickness: 1,
                              color: Colors.grey,
                              width: screenWidth * 0.02,
                            ),
                            IconButton(
                              icon: const Icon(Icons.tune, color: Colors.grey),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  PageRouteBuilder(
                                    pageBuilder: (_, __, ___) => FilterScreen(
                                      selectedCategories: const ['Todas'],
                                      selectedLocation: 'Todas',
                                      userId: widget.userId,
                                      destinations: widget.destinations,
                                      searchText: _searchText,
                                    ),
                                    transitionsBuilder:
                                        (_, animation, __, child) {
                                      return FadeTransition(
                                        opacity: animation,
                                        child: child,
                                      );
                                    },
                                    transitionDuration:
                                        const Duration(milliseconds: 600),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.02),
                  ],
                ),
              ),
              // Sección de Categorías: solo margen a la izquierda, no a la derecha
              Padding(
                padding: EdgeInsets.only(left: screenWidth * 0.04, right: 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Categorías',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: screenWidth * 0.045,
                            fontWeight: FontWeight.bold,
                            color: const Color.fromRGBO(17, 48, 73, 1),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _navigateToCategory('Todas'),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: screenWidth * 0.04),
                            child: Text(
                              'Ver todo',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: screenWidth * 0.03,
                                color: Colors.grey,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: screenHeight * 0.01),
                    SizedBox(
                      height: screenHeight * 0.05,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          GestureDetector(
                            onTap: () => _navigateToCategory('Ciudad'),
                            child: _buildCategoryItem("Ciudad"),
                          ),
                          SizedBox(width: screenWidth * 0.02),
                          GestureDetector(
                            onTap: () => _navigateToCategory('Playa'),
                            child: _buildCategoryItem("Playa"),
                          ),
                          SizedBox(width: screenWidth * 0.02),
                          GestureDetector(
                            onTap: () => _navigateToCategory('Restaurantes'),
                            child: _buildCategoryItem("Restaurantes"),
                          ),
                          SizedBox(width: screenWidth * 0.02),
                          GestureDetector(
                            onTap: () => _navigateToCategory('Eventos'),
                            child: _buildCategoryItem("Eventos"),
                          ),
                          SizedBox(width: screenWidth * 0.02),
                          GestureDetector(
                            onTap: () => _navigateToCategory('Hospedaje'),
                            child: _buildCategoryItem("Hospedaje"),
                          ),
                          SizedBox(width: screenWidth * 0.02),
                          GestureDetector(
                            onTap: () => _navigateToCategory('Talleres'),
                            child: _buildCategoryItem("Talleres"),
                          ),
                          SizedBox(width: screenWidth * 0.02),
                          GestureDetector(
                            onTap: () => _navigateToCategory('Bienestar'),
                            child: _buildCategoryItem("Bienestar"),
                          ),
                          SizedBox(width: screenWidth * 0.02),
                          GestureDetector(
                            onTap: () => _navigateToCategory('Cultura'),
                            child: _buildCategoryItem("Cultura"),
                          ),
                          SizedBox(width: screenWidth * 0.02),
                          GestureDetector(
                            onTap: () => _navigateToCategory('Arte'),
                            child: _buildCategoryItem("Arte"),
                          ),
                          SizedBox(width: screenWidth * 0.02),
                          GestureDetector(
                            onTap: () => _navigateToCategory('Vida nocturna'),
                            child: _buildCategoryItem("Vida nocturna"),
                          ),
                          SizedBox(width: screenWidth * 0.02),
                          GestureDetector(
                            onTap: () => _navigateToCategory('Extremo'),
                            child: _buildCategoryItem("Extremo"),
                          ),
                          SizedBox(width: screenWidth * 0.02),
                          GestureDetector(
                            onTap: () => _navigateToCategory('Montaña'),
                            child: _buildCategoryItem("Montaña"),
                          ),
                          SizedBox(width: screenWidth * 0.02),
                          GestureDetector(
                            onTap: () => _navigateToCategory('Divertido'),
                            child: _buildCategoryItem("Divertido"),
                          ),
                          SizedBox(width: screenWidth * 0.02),
                          GestureDetector(
                            onTap: () => _navigateToCategory('Online'),
                            child: _buildCategoryItem("Online"),
                          ),
                          SizedBox(width: screenWidth * 0.02),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: screenHeight * 0.02),
              // Sección de Opciones Destacadas: margen izquierdo personalizado y 0 a la derecha
              Padding(
                padding: EdgeInsets.only(left: screenWidth * 0.04, right: 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Opciones destacadas',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: screenWidth * 0.045,
                        fontWeight: FontWeight.bold,
                        color: const Color.fromRGBO(17, 48, 73, 1),
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.01),
                    SizedBox(
                      height: screenHeight * 0.4,
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('destinos')
                            .where('IsHighlighted', isEqualTo: true)
                            .orderBy(
                                'highlightOrder') // <-- Orden personalizado
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                                  ConnectionState.waiting &&
                              (_displayedDestinations == null ||
                                  _displayedDestinations!.isEmpty)) {
                            // No muestres nada mientras carga por primera vez
                            return SizedBox.shrink();
                          }
                          if (snapshot.hasData &&
                              snapshot.data!.docs.isNotEmpty) {
                            _displayedDestinations = snapshot.data!.docs;
                          }

                          // Si no hay datos y tampoco hay guardados, muestra mensaje
                          if (_displayedDestinations == null ||
                              _displayedDestinations!.isEmpty) {
                            return const Center(
                              child: Text('No hay opciones destacados',
                                  style: TextStyle(
                                      color: Color.fromRGBO(17, 48, 73, 1),
                                      fontSize: 16,
                                      fontFamily: 'Poppins')),
                            );
                          }

                          final destinations = _displayedDestinations!;

                          return ListView.builder(
                            controller:
                                _highlightedScrollController, // <-- Agrega esto
                            scrollDirection: Axis.horizontal,
                            itemCount: destinations.length,
                            itemBuilder: (context, index) {
                              final destination = destinations[index];
                              final data =
                                  destination.data() as Map<String, dynamic>;
                              final destinationId = destination.id;
                              final isSaved = isDestinationSaved(destinationId);

                              return Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: screenWidth * 0.02,
                                ),
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      PageRouteBuilder(
                                        pageBuilder: (_, __, ___) =>
                                            DestinationDetailScreen(
                                          destino: data,
                                          userId: widget.userId,
                                        ),
                                        transitionsBuilder:
                                            (_, animation, __, child) {
                                          return FadeTransition(
                                            opacity: animation,
                                            child: child,
                                          );
                                        },
                                        transitionDuration:
                                            const Duration(milliseconds: 600),
                                      ),
                                    );
                                  },
                                  child: DestinationCard(
                                    key: ValueKey(
                                        destinationId), // Importante para evitar parpadeos
                                    images: (data['imagen'] is List)
                                        ? (data['imagen'] as List<dynamic>)
                                            .cast<String>()
                                        : [data['imagen']?.toString() ?? ''],
                                    title: data['nombre'],
                                    location: data['ubicacion'],
                                    price: _getMinPrice(data['paquetes'] ?? []),
                                    place:
                                        data['lugar'] ?? 'Lugar no disponible',
                                    screenWidth: screenWidth,
                                    isSaved: isSaved,
                                    onFavoriteTap: () {
                                      toggleSaveDestination(
                                          destinationId, data);
                                    },
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: screenHeight * 0.02),
            ],
          ),
        ),
        bottomNavigationBar: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
          child: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            elevation: 0,
            selectedItemColor: const Color.fromRGBO(17, 48, 73, 1),
            unselectedItemColor: const Color.fromRGBO(17, 48, 73, 1),
            showSelectedLabels: false,
            showUnselectedLabels: false,
            onTap: (index) {
              switch (index) {
                case 0:
                  Navigator.pushReplacement(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (_, __, ___) => SearchScreen(
                        destinations: widget.destinations,
                        userId: widget.userId,
                      ),
                      transitionsBuilder: (_, a, __, c) => FadeTransition(
                        opacity: a,
                        child: c,
                      ),
                      transitionDuration: const Duration(milliseconds: 600),
                    ),
                  );
                  break;
                case 1:
                  Navigator.pushReplacement(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (_, __, ___) => BookingsScreen(
                        userId: widget.userId,
                      ),
                      transitionsBuilder: (_, a, __, c) => FadeTransition(
                        opacity: a,
                        child: c,
                      ),
                      transitionDuration: const Duration(milliseconds: 600),
                    ),
                  );
                  break;
                case 2:
                  Navigator.pushReplacement(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (_, __, ___) => SavedDestinationsScreen(
                        userId: widget.userId,
                      ),
                      transitionsBuilder: (_, a, __, c) => FadeTransition(
                        opacity: a,
                        child: c,
                      ),
                      transitionDuration: const Duration(milliseconds: 600),
                    ),
                  );
                  break;
                case 3:
                  Navigator.pushReplacement(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (_, __, ___) => SettingsScreen(
                        userId: widget.userId,
                        savedDestinations: savedDestinations,
                      ),
                      transitionsBuilder: (_, a, __, c) => FadeTransition(
                        opacity: a,
                        child: c,
                      ),
                      transitionDuration: const Duration(milliseconds: 600),
                    ),
                  );
                  break;
              }
            },
            items: [
              BottomNavigationBarItem(
                icon: HugeIcon(
                  icon: HugeIcons.strokeRoundedHome02,
                  color: Color.fromRGBO(240, 169, 52, 1),
                  size: 24.0,
                ),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: HugeIcon(
                  icon: HugeIcons.strokeRoundedTicket03,
                  color: Color.fromRGBO(17, 48, 73, 1),
                  size: 24.0,
                ),
                label: 'Bookings',
              ),
              BottomNavigationBarItem(
                icon: HugeIcon(
                  icon: HugeIcons.strokeRoundedFavourite,
                  color: Color.fromRGBO(17, 48, 73, 1),
                  size: 24.0,
                ),
                label: 'Saved',
              ),
              BottomNavigationBarItem(
                icon: HugeIcon(
                  icon: HugeIcons.strokeRoundedSettings01,
                  color: Color.fromRGBO(17, 48, 73, 1),
                  size: 24.0,
                ),
                label: 'Settings',
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Construye un ítem de categoría
  Widget _buildCategoryItem(String label) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Container(
      padding:
          EdgeInsets.symmetric(horizontal: screenWidth * 0.05, vertical: 2),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(17, 48, 73, 1),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: screenWidth * 0.035,
              color: const Color.fromARGB(255, 255, 255, 255),
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Construye una tarjeta de destino
}

class DestinationCard extends StatefulWidget {
  final List<String> images;
  final String title;
  final String location;
  final String place;
  final double price;
  final double screenWidth;
  final bool isSaved;
  final VoidCallback onFavoriteTap;

  const DestinationCard({
    super.key,
    required this.images,
    required this.title,
    required this.location,
    required this.place,
    required this.price,
    required this.screenWidth,
    required this.isSaved,
    required this.onFavoriteTap,
  });

  @override
  State<DestinationCard> createState() => _DestinationCardState();
}

class _DestinationCardState extends State<DestinationCard> {
  late bool localIsSaved;
  int currentPage = 0;
  late final PageController pageController;

  @override
  void initState() {
    super.initState();
    localIsSaved = widget.isSaved;
    pageController = PageController();
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.screenWidth * 0.75,
      constraints: BoxConstraints(
        minHeight: widget.screenWidth * 0.5,
        maxHeight: widget.screenWidth * 0.75,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.screenWidth * 0.05),
      ),
      child: Stack(
        children: [
          // Carrusel de imágenes
          ClipRRect(
            borderRadius: BorderRadius.circular(widget.screenWidth * 0.05),
            child: PageView.builder(
              controller: pageController,
              itemCount: widget.images.length,
              physics: const NeverScrollableScrollPhysics(), // <-- Solo flechas
              onPageChanged: (index) {
                setState(() {
                  currentPage = index;
                });
              },
              itemBuilder: (context, index) {
                return Image.network(
                  widget.images[index],
                  fit: BoxFit.cover,
                );
              },
            ),
          ),

          // Flechas de navegación
          if (widget.images.length > 1)
            Positioned(
              left: widget.screenWidth * 0.02,
              right: widget.screenWidth * 0.02,
              top: 0,
              bottom: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (currentPage > 0)
                    GestureDetector(
                      onTap: () {
                        pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: Container(
                        padding: EdgeInsets.all(widget.screenWidth * 0.015),
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(128, 17, 48, 73),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.chevron_left,
                          color: Colors.white,
                          size: widget.screenWidth * 0.06,
                        ),
                      ),
                    ),
                  if (currentPage < widget.images.length - 1)
                    GestureDetector(
                      onTap: () {
                        pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: Container(
                        padding: EdgeInsets.all(widget.screenWidth * 0.015),
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(128, 17, 48, 73),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.chevron_right,
                          color: Colors.white,
                          size: widget.screenWidth * 0.06,
                        ),
                      ),
                    ),
                ],
              ),
            ),

          // Indicadores de página
          if (widget.images.length > 1)
            Positioned(
              bottom: widget.screenWidth * 0.017,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.images.length, (index) {
                  return Container(
                    width: widget.screenWidth * 0.02,
                    height: widget.screenWidth * 0.02,
                    margin: EdgeInsets.symmetric(
                        horizontal: widget.screenWidth * 0.01),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: currentPage == index
                          ? Colors.white
                          : const Color.fromARGB(128, 255, 255, 255),
                    ),
                  );
                }),
              ),
            ),

          // Ícono de favorito
          Positioned(
            top: widget.screenWidth * 0.025,
            right: widget.screenWidth * 0.025,
            child: GestureDetector(
              onTap: () async {
                widget.onFavoriteTap();
                setState(() {
                  localIsSaved = !localIsSaved;
                });
              },
              child: Container(
                width: widget.screenWidth * 0.08,
                height: widget.screenWidth * 0.08,
                decoration: BoxDecoration(
                  color: const Color.fromARGB(128, 17, 48, 73),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  localIsSaved ? Icons.favorite : Icons.favorite_border,
                  color: Colors.white,
                  size: widget.screenWidth * 0.05,
                ),
              ),
            ),
          ),

          // Recuadro inferior
          Positioned(
            bottom: widget.screenWidth * 0.05,
            left: widget.screenWidth * 0.075,
            right: widget.screenWidth * 0.075,
            child: Container(
              padding: EdgeInsets.all(widget.screenWidth * 0.05),
              decoration: BoxDecoration(
                color: const Color.fromARGB(128, 17, 48, 73),
                borderRadius: BorderRadius.circular(widget.screenWidth * 0.05),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: widget.screenWidth * 0.04,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  SizedBox(height: widget.screenWidth * 0.01),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            color: Colors.white,
                            size: widget.screenWidth * 0.035,
                          ),
                          SizedBox(width: widget.screenWidth * 0.01),
                          Text(
                            widget.location,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: widget.screenWidth * 0.03,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '€${widget.price}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: widget.screenWidth * 0.03,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
