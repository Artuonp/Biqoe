// Importaciones necesarias para el funcionamiento de la aplicación
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'destinations_screen.dart';
import 'filter_screen.dart';
import 'bookings_screen.dart';
import 'saved_destinations_screen.dart';
import 'settings_screen.dart';
import 'search_results_screen.dart';
import 'destination_detail_screen.dart';
import 'package:hugeicons/hugeicons.dart';

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

  @override
  void initState() {
    super.initState();

    // Otros inicializadores existentes
    FirebaseMessaging.instance.getToken().then((token) {
      // ignore: avoid_print
      print('Token del dispositivo: $token');
      // Aquí puedes guardar el token en Firestore si es necesario
    });

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      // ignore: avoid_print
      print('Token actualizado: $newToken');
      // Aquí puedes actualizar el token en Firestore si es necesario
    });

    requestNotificationPermission();
    fetchUserName();

    // Listener para actualizar el texto de búsqueda
    _searchController.addListener(() {
      setState(() {
        _searchText = _searchController.text;
      });
    });

    // Abre la caja de Hive específica para el usuario
    Hive.openBox<Map>('saved_destinations_${widget.userId}').then((box) {
      setState(() {
        savedDestinationsBox = box;
        savedDestinationIds = box.keys.cast<String>().toSet();
      });
    });
  }

  void toggleSaveDestination(
      String destinationId, Map<String, dynamic> destination) {
    final userBoxName = 'saved_destinations_${widget.userId}';
    Hive.openBox<Map>(userBoxName).then((userBox) {
      setState(() {
        if (isDestinationSaved(destinationId)) {
          userBox.delete(destinationId);
          savedDestinationIds.remove(destinationId);
        } else {
          userBox.put(destinationId, destination);
          savedDestinationIds.add(destinationId);
        }
      });
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Solicita permiso para notificaciones
  void requestNotificationPermission() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // ignore: avoid_print
      print('Permiso de notificación concedido');
    } else {
      // ignore: avoid_print
      print('Permiso de notificación denegado');
    }
  }

  /* // Configura Firebase Messaging
  void setupFirebaseMessaging() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        saveTokenToDatabase(token);
      }
    } catch (e) {
      print('Error obteniendo token de FCM: $e');
    }
  }*/

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
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => DestinationsScreen(
          userId: widget.userId,
          destinations: const [],
          initialCategories: [category],
          initialLocation: 'Todas',
          sortByPriceDescending: false,
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
                          'Hola, $userName 👋',
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
                                      sortByPriceDescending: false,
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
                            onTap: () => _navigateToCategory('Playa'),
                            child: _buildCategoryItem("Playa"),
                          ),
                          SizedBox(width: screenWidth * 0.02),
                          GestureDetector(
                            onTap: () => _navigateToCategory('Montaña'),
                            child: _buildCategoryItem("Montaña"),
                          ),
                          SizedBox(width: screenWidth * 0.02),
                          GestureDetector(
                            onTap: () => _navigateToCategory('Ciudad'),
                            child: _buildCategoryItem("Ciudad"),
                          ),
                          SizedBox(width: screenWidth * 0.02),
                          GestureDetector(
                            onTap: () => _navigateToCategory('Extremo'),
                            child: _buildCategoryItem("Extremo"),
                          ),
                          SizedBox(width: screenWidth * 0.02),
                          GestureDetector(
                            onTap: () => _navigateToCategory('Divertido'),
                            child: _buildCategoryItem("Divertido"),
                          ),
                          SizedBox(width: screenWidth * 0.02),
                          GestureDetector(
                            onTap: () => _navigateToCategory('Cultural'),
                            child: _buildCategoryItem("Cultural"),
                          ),
                          SizedBox(width: screenWidth * 0.02),
                          GestureDetector(
                            onTap: () => _navigateToCategory('Comida'),
                            child: _buildCategoryItem("Comida"),
                          ),
                          SizedBox(width: screenWidth * 0.02),
                          GestureDetector(
                            onTap: () => _navigateToCategory('Pernocta'),
                            child: _buildCategoryItem("Pernocta"),
                          ),
                          SizedBox(width: screenWidth * 0.02),
                          GestureDetector(
                            onTap: () => _navigateToCategory('Vida nocturna'),
                            child: _buildCategoryItem("Vida nocturna"),
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
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center();
                          }
                          if (snapshot.hasError) {
                            return const Center(
                                child: Text('Error al cargar destinos'));
                          }
                          if (!snapshot.hasData ||
                              snapshot.data!.docs.isEmpty) {
                            return const Center(
                                child: Text('No hay opciones destacados',
                                    style: TextStyle(
                                        color: Color.fromRGBO(17, 48, 73, 1),
                                        fontSize: 16,
                                        fontFamily: 'Poppins')));
                          }

                          final destinations = snapshot.data!.docs;

                          return ListView.builder(
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
                                  child: _buildDestinationCard(
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
        bottomNavigationBar: Container(
          height: screenHeight * 0.1,
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 255, 255, 255).withOpacity(1),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: screenHeight * 0.01),
            child: BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.transparent,
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
                    color: Color.fromRGBO(240, 169, 52, 1), // Color destacado
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
        color: const Color.fromRGBO(17, 48, 73, 1).withOpacity(1),
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
  Widget _buildDestinationCard({
    required List<String> images,
    required String title,
    required String location,
    required double price,
    required double screenWidth,
    required bool isSaved,
    required VoidCallback onFavoriteTap,
    required String place,
  }) {
    final PageController pageController = PageController();
    int currentPage = 0;

    return StatefulBuilder(
      builder: (context, setState) {
        return Container(
          width: screenWidth * 0.75,
          constraints: BoxConstraints(
            minHeight: screenWidth * 0.5,
            maxHeight: screenWidth * 0.75,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(screenWidth * 0.05),
          ),
          child: Stack(
            children: [
              // Carrusel de imágenes (desactivado el scroll manual)
              ClipRRect(
                borderRadius: BorderRadius.circular(screenWidth * 0.05),
                child: PageView.builder(
                  controller: pageController,
                  physics:
                      const NeverScrollableScrollPhysics(), // Desactiva el scroll
                  itemCount: images.length,
                  onPageChanged: (index) => setState(() => currentPage = index),
                  itemBuilder: (context, index) {
                    return Image.network(
                      images[index],
                      fit: BoxFit.cover,
                    );
                  },
                ),
              ),

              // Flechas de navegación
              if (images.length > 1)
                Positioned(
                  left: screenWidth * 0.02,
                  right: screenWidth * 0.02,
                  top: 0,
                  bottom: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Flecha izquierda
                      if (currentPage > 0)
                        GestureDetector(
                          onTap: () {
                            pageController.previousPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          },
                          child: Container(
                            padding: EdgeInsets.all(screenWidth * 0.015),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.4),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.chevron_left,
                              color: Colors.white,
                              size: screenWidth * 0.06,
                            ),
                          ),
                        ),
                      // Flecha derecha
                      if (currentPage < images.length - 1)
                        GestureDetector(
                          onTap: () {
                            pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          },
                          child: Container(
                            padding: EdgeInsets.all(screenWidth * 0.015),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.4),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.chevron_right,
                              color: Colors.white,
                              size: screenWidth * 0.06,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

              // Indicadores de página
              if (images.length > 1)
                Positioned(
                  bottom: screenWidth * 0.017,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(images.length, (index) {
                      return Container(
                        width: screenWidth * 0.02,
                        height: screenWidth * 0.02,
                        margin: EdgeInsets.symmetric(
                            horizontal: screenWidth * 0.01),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: currentPage == index
                              ? Colors.white
                              : Colors.white.withOpacity(0.5),
                        ),
                      );
                    }),
                  ),
                ),

              // Ícono de favorito
              Positioned(
                top: screenWidth * 0.025,
                right: screenWidth * 0.025,
                child: GestureDetector(
                  onTap: onFavoriteTap,
                  child: Container(
                    width: screenWidth * 0.08,
                    height: screenWidth * 0.08,
                    decoration: BoxDecoration(
                      color:
                          const Color.fromRGBO(17, 48, 73, 1).withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isSaved ? Icons.favorite : Icons.favorite_border,
                      color: Colors.white,
                      size: screenWidth * 0.05,
                    ),
                  ),
                ),
              ),

              // Recuadro inferior
              Positioned(
                bottom: screenWidth * 0.05,
                left: screenWidth * 0.075,
                right: screenWidth * 0.075,
                child: Container(
                  padding: EdgeInsets.all(screenWidth * 0.05),
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(17, 48, 73, 1).withOpacity(0.5),
                    borderRadius: BorderRadius.circular(screenWidth * 0.05),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: screenWidth * 0.04,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      SizedBox(height: screenWidth * 0.01),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                color: Colors.white,
                                size: screenWidth * 0.035,
                              ),
                              SizedBox(width: screenWidth * 0.01),
                              Text(
                                location,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: screenWidth * 0.03,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '€$price',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: screenWidth * 0.03,
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
      },
    );
  }
}
