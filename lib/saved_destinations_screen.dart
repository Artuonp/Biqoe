import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'search_screen.dart';
import 'destination_detail_screen.dart';
import 'bookings_screen.dart';
import 'settings_screen.dart';
import 'package:hugeicons/hugeicons.dart';

class SavedDestinationsScreen extends StatefulWidget {
  final String userId;

  const SavedDestinationsScreen({super.key, required this.userId});

  @override
  SavedDestinationsScreenState createState() => SavedDestinationsScreenState();
}

class SavedDestinationsScreenState extends State<SavedDestinationsScreen> {
  late Box<Map> savedDestinationsBox;
  bool isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';

  @override
  void initState() {
    super.initState();
    Hive.openBox<Map>('saved_destinations_${widget.userId}').then((box) {
      setState(() {
        savedDestinationsBox = box;
        isLoading = false;
      });
    });

    _searchController.addListener(() {
      setState(() {
        _searchText = _searchController.text;
      });
    });
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: const Color.fromARGB(255, 243, 247, 254),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Column(
          children: [
            Padding(
              padding: EdgeInsets.only(
                top: screenHeight * 0.08,
                left: screenWidth * 0.04,
                right: screenWidth * 0.04,
              ),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
                height: screenHeight * 0.06,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(screenWidth * 0.08),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: 'Buscar planes guardados',
                          border: InputBorder.none,
                          hintStyle: TextStyle(
                            color: Colors.grey,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        style: GoogleFonts.poppins(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
                height: screenHeight *
                    0.00), // Espacio entre la barra de búsqueda y el primer destino guardado
            Expanded(
              child: ValueListenableBuilder(
                valueListenable: savedDestinationsBox.listenable(),
                builder: (context, Box<Map> box, _) {
                  final savedDestinations = box.values.where((destination) {
                    final name = destination['nombre'] ?? '';
                    return _searchText.isEmpty ||
                        name.toLowerCase().contains(_searchText.toLowerCase());
                  }).toList();

                  if (savedDestinations.isEmpty) {
                    return const Center(
                      child: Text(
                        'No hay planes guardados',
                        style: TextStyle(
                            fontSize: 18.0,
                            color: Color.fromRGBO(17, 48, 73, 1),
                            fontFamily: 'Poppins'),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: savedDestinations.length,
                    itemBuilder: (context, index) {
                      final destination = savedDestinations[index];

                      // Convertir Map<dynamic, dynamic> a Map<String, dynamic>
                      final Map<String, dynamic> destinationMap = destination
                          .map((key, value) => MapEntry(key.toString(), value));

// Conversión recursiva para 'paquetes'
                      if (destinationMap.containsKey('paquetes') &&
                          destinationMap['paquetes'] is List) {
                        final paquetes = destinationMap['paquetes'] as List;
                        destinationMap['paquetes'] = paquetes.map((e) {
                          if (e is Map) {
                            return Map<String, dynamic>.from(e);
                          }
                          return e;
                        }).toList();
                      }

                      return Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: screenHeight *
                              0.01, // Espacio entre los recuadros
                          horizontal: screenWidth * 0.05, // Espacio a los lados
                        ),
                        child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => DestinationDetailScreen(
                                    destino: destinationMap,
                                    userId: widget.userId,
                                  ),
                                ),
                              );
                            },
                            child: _buildDestinationCard(
                              images: (destinationMap['imagen'] is List)
                                  ? (destinationMap['imagen'] as List<dynamic>)
                                      .cast<String>()
                                  : [
                                      destinationMap['imagen']?.toString() ?? ''
                                    ],
                              title: destinationMap['nombre'] ??
                                  'Nombre no disponible',
                              location: destinationMap['ubicacion'] ??
                                  'Ubicación no disponible',
                              place:
                                  destinationMap['lugar'] ?? '', // Nuevo campo
                              price: (destinationMap['paquetes'] != null &&
                                      (destinationMap['paquetes'] as List)
                                          .isNotEmpty)
                                  ? _getMinPrice(destinationMap['paquetes'])
                                  : 0.0, // Asegúrate de que sea un double
                              screenWidth: screenWidth,
                              isSaved: true,
                              onFavoriteTap: () {
                                setState(() {
                                  savedDestinationsBox.deleteAt(index);
                                });
                              },
                            )),
                      );
                    },
                  );
                },
              ),
            ),
          ],
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
                          destinations: const [],
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
                    // Ya estamos en SavedDestinationsScreen, no necesita navegación
                    break;
                  case 3:
                    Navigator.pushReplacement(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (_, __, ___) => SettingsScreen(
                          userId: widget.userId,
                          savedDestinations: const [],
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
                    color: Color.fromRGBO(17, 48, 73, 1), // Color normal
                    size: 24.0,
                  ),
                  label: 'Buscar',
                ),
                BottomNavigationBarItem(
                  icon: HugeIcon(
                    icon: HugeIcons.strokeRoundedTicket03,
                    color: Color.fromRGBO(17, 48, 73, 1),
                    size: 24.0,
                  ),
                  label: 'Booked',
                ),
                BottomNavigationBarItem(
                  icon: HugeIcon(
                    icon: HugeIcons.strokeRoundedFavourite,
                    color: Color.fromRGBO(240, 169, 52, 1), // Color activo
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
                  label: 'Configuración',
                ),
              ],
            ),
          ),
        ),
        backgroundColor: const Color.fromARGB(255, 243, 247, 254),
      ),
    );
  }

  Widget _buildDestinationCard({
    required List<String> images, // Cambiar de String a List<String>
    required String title,
    required String location,
    required String place, // Nuevo parámetro
    required double price,
    required double screenWidth,
    required bool isSaved,
    required VoidCallback onFavoriteTap,
  }) {
    final PageController pageController = PageController();
    int currentPage = 0;

    return StatefulBuilder(
      builder: (context, setState) {
        return Container(
          width: screenWidth * 0.8, // Ajustar el ancho del recuadro
          constraints: BoxConstraints(
            minHeight:
                screenWidth * 0.45, // Ajustar la altura mínima del recuadro
            maxHeight:
                screenWidth * 0.6, // Ajustar la altura máxima del recuadro
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(screenWidth * 0.05),
          ),
          child: Stack(
            children: [
              // Carrusel de imágenes
              ClipRRect(
                borderRadius: BorderRadius.circular(screenWidth * 0.05),
                child: PageView.builder(
                  controller: pageController,
                  itemCount: images.length,
                  onPageChanged: (index) => setState(() => currentPage = index),
                  itemBuilder: (context, index) {
                    return CachedNetworkImage(
                      imageUrl: images[index],
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[200],
                      ),
                      errorWidget: (context, url, error) =>
                          const Icon(Icons.error),
                    );
                  },
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
                                // Mostrar ubicación y lugar
                                '$location${place.isNotEmpty ? ', $place' : ''}',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: screenWidth * 0.03,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '\$$price',
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
