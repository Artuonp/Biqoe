import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui'; // Para BackdropFilter

import 'filter_screen.dart';

class DestinationsScreen extends StatefulWidget {
  final String userId;
  final List<String> destinations;
  final List<String> initialCategories;
  final String initialLocation;
  final int sortOption;
  final String searchText;

  const DestinationsScreen({
    super.key,
    required this.userId,
    required this.destinations,
    required this.initialCategories,
    required this.initialLocation,
    required this.sortOption,
    required this.searchText,
  });

  @override
  DestinationsScreenState createState() => DestinationsScreenState();
}

class DestinationsScreenState extends State<DestinationsScreen> {
  late List<String> selectedCategories;
  List<QueryDocumentSnapshot>? _displayedDestinations;
  late String selectedLocation;
  late int sortOption;
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  late Box<Map> savedDestinationsBox;
  Set<String> savedDestinationIds = {};
  late final ScrollController _scrollController;

  final Color primaryColor = const Color.fromRGBO(17, 48, 73, 1);
  final Color backgroundColor = const Color(0xFFF3F7FE);

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    selectedCategories = widget.initialCategories;
    selectedLocation = widget.initialLocation;
    sortOption = widget.sortOption;
    _searchText = widget.searchText;
    _searchController.text = widget.searchText;
    _searchController.addListener(() {
      setState(() {
        _searchText = _searchController.text;
      });
    });

    Hive.openBox<Map>('saved_destinations_${widget.userId}').then((box) {
      if (mounted) {
        setState(() {
          savedDestinationsBox = box;
          savedDestinationIds = box.keys.cast<String>().toSet();
        });
      }
    });
  }

  void applyFilters(
      List<String> categories, String location, int newSortOption) {
    setState(() {
      selectedCategories = categories;
      selectedLocation = location;
      sortOption = newSortOption;
    });
  }

  void _updateDisplayedDestinations(List<QueryDocumentSnapshot> docs) {
    setState(() {
      _displayedDestinations = List<QueryDocumentSnapshot>.from(docs);
      if (sortOption == 0) {
        _displayedDestinations!.shuffle();
      } else if (sortOption == 1) {
        _displayedDestinations!.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aPrice = _getMinPrice(aData['paquetes'] ?? []);
          final bPrice = _getMinPrice(bData['paquetes'] ?? []);
          return aPrice.compareTo(bPrice);
        });
      } else if (sortOption == 2) {
        _displayedDestinations!.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aPrice = _getMinPrice(aData['paquetes'] ?? []);
          final bPrice = _getMinPrice(bData['paquetes'] ?? []);
          return bPrice.compareTo(aPrice);
        });
      }
    });
  }

  bool isDestinationSaved(String destinationId, Box<Map> userBox) {
    return userBox.keys.contains(destinationId);
  }

  double _getMinPrice(List<dynamic> paquetes) {
    if (paquetes.isEmpty) return 0.0;
    final precios = paquetes
        .where((p) => p['precio'] != null)
        .map<double>((p) => (p['precio'] as num).toDouble())
        .toList();
    return precios.isNotEmpty ? precios.reduce((a, b) => a < b ? a : b) : 0.0;
  }

  // --- LÓGICA DE EXTRACCIÓN DE IMÁGENES ---
  List<String> _extractImages(Map<String, dynamic> data, String id) {
    List<String> images = [];

    // 1. Intento: Campo 'imagenes' (Array Real - Formato Nuevo)
    if (data['imagenes'] != null && data['imagenes'] is List) {
      images = List<String>.from(data['imagenes'])
          .where((e) => e.isNotEmpty)
          .toList();
    }

    // 2. Intento: Campo 'imagen' (Formato Antiguo o String Sucio)
    if (images.isEmpty && data['imagen'] != null) {
      var rawImg = data['imagen'];

      if (rawImg is List) {
        images = List<String>.from(rawImg);
      } else if (rawImg is String) {
        String imgStr = rawImg;
        // Limpieza de caracteres basura
        String cleaned = imgStr
            .replaceAll('[', '')
            .replaceAll(']', '')
            .replaceAll('"', '')
            .replaceAll("'", "");

        if (cleaned.contains(',')) {
          // Lista en string
          images = cleaned
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
        } else {
          // Una sola URL
          if (cleaned.trim().isNotEmpty) {
            images = [cleaned.trim()];
          }
        }
      }
    }
    return images;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // --- LÓGICA RESPONSIVA ---
    // Si el ancho es mayor a 900px, consideramos que es Desktop/Web grande
    final bool isDesktop = screenWidth > 900;

    return Scaffold(
      backgroundColor: backgroundColor,
      // ELIMINADO APPBAR ESTÁNDAR, USAMOS SAFEAREA + COLUMN PARA HEADER PERSONALIZADO
      body: SafeArea(
        child: Column(
          children: [
            // --- HEADER PERSONALIZADO ---
            Padding(
              padding: EdgeInsets.fromLTRB(
                  screenWidth * 0.05, 20, screenWidth * 0.05, 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Fila Superior: Título "Explora" + Botón Filtro
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Explora",
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color.fromRGBO(17, 48, 73, 1),
                        ),
                      ),
                      InkWell(
                        onTap: () async {
                          final filters = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FilterScreen(
                                selectedCategories: selectedCategories,
                                selectedLocation: selectedLocation,
                                userId: widget.userId,
                                destinations: widget.destinations,
                                searchText: _searchText,
                              ),
                            ),
                          );
                          if (filters != null) {
                            applyFilters(
                              filters['category']
                                  .split(',')
                                  .map((e) => e.trim())
                                  .toList(),
                              filters['location'],
                              filters['sortOption'],
                            );
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.tune_rounded,
                              color: Color.fromRGBO(17, 48, 73, 1), size: 24),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Barra de Búsqueda
                  Container(
                    height: 55,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color.fromRGBO(17, 48, 73, 0.08),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Botón de Atrás
                        IconButton(
                          icon: Icon(Icons.arrow_back,
                              color: Colors.grey.shade400),
                          onPressed: () => context.pop(),
                        ),

                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Encuentra tu próximo destino',
                              hintStyle: TextStyle(
                                fontFamily: 'Poppins',
                                color: Colors.grey.shade400,
                                fontSize: 15,
                              ),
                              border: InputBorder.none,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 12),
                            ),
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              color: Color.fromRGBO(17, 48, 73, 1),
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(right: 30.0),
                          child: Icon(HugeIcons.strokeRoundedSearch01,
                              color: Colors.grey, size: 24),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // --- LISTA DE DESTINOS (RESPONSIVA) ---
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('destinos')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      (_displayedDestinations == null ||
                          _displayedDestinations!.isEmpty)) {
                    return const Center();
                  }

                  if (snapshot.hasError) {
                    debugPrint("Error Stream: ${snapshot.error}");
                    return const Center(
                      child: Text('Error al cargar los destinos',
                          style: TextStyle(fontFamily: 'Poppins')),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text('No hay destinos disponibles',
                          style: TextStyle(
                              fontFamily: 'Poppins',
                              color: Color.fromRGBO(17, 48, 73, 1),
                              fontSize: 16)),
                    );
                  }

                  var destinations = snapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final categories =
                        data['categorias'] as List<dynamic>? ?? [];
                    final location = data['estado'] ?? 'Todas';
                    final name = data['nombre'] ?? '';

                    // Excluir destinos privados (isPrivate == true)
                    // Si el campo no existe o es false → se muestra
                    if (data['isPrivate'] == true) return false;

                    // Excluir destinos con isInApp == false
                    // Si el campo no existe o es true → se muestra
                    if (data['isInApp'] == false) return false;

                    final matchesCategory =
                        selectedCategories.contains('Todas') ||
                            selectedCategories
                                .any((cat) => categories.contains(cat));
                    final matchesLocation = selectedLocation == 'Todas' ||
                        selectedLocation == location;
                    final matchesSearchText = _searchText.isEmpty ||
                        name.toLowerCase().contains(_searchText.toLowerCase());

                    return matchesCategory &&
                        matchesLocation &&
                        matchesSearchText;
                  }).toList();

                  // Logica de ordenamiento
                  if (sortOption == 0) {
                    destinations.shuffle();
                  } else if (sortOption == 1) {
                    destinations.sort((a, b) {
                      final aData = a.data() as Map<String, dynamic>;
                      final bData = b.data() as Map<String, dynamic>;
                      return _getMinPrice(aData['paquetes'] ?? [])
                          .compareTo(_getMinPrice(bData['paquetes'] ?? []));
                    });
                  } else if (sortOption == 2) {
                    destinations.sort((a, b) {
                      final aData = a.data() as Map<String, dynamic>;
                      final bData = b.data() as Map<String, dynamic>;
                      return _getMinPrice(bData['paquetes'] ?? [])
                          .compareTo(_getMinPrice(aData['paquetes'] ?? []));
                    });
                  }

                  if (_displayedDestinations == null ||
                      _displayedDestinations!.length != destinations.length) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _updateDisplayedDestinations(destinations);
                    });
                    if (_displayedDestinations == null) {
                      return const Center();
                    }
                  }

                  // -----------------------------------------------------------
                  // AQUÍ ESTÁ EL CAMBIO RESPONSIVO
                  // -----------------------------------------------------------

                  // CASO: DESKTOP / WEB (GRID VIEW)
                  if (isDesktop) {
                    return GridView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.fromLTRB(
                          screenWidth * 0.05, 0, screenWidth * 0.05, 20),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 400, // Ancho máximo de la tarjeta
                        childAspectRatio:
                            0.85, // Relación de aspecto para que no se vea estirada
                        crossAxisSpacing: 20,
                        mainAxisSpacing: 20,
                      ),
                      itemCount: _displayedDestinations!.length,
                      itemBuilder: (context, index) {
                        // Usamos el builder de items común
                        return _buildDestinationItem(
                          _displayedDestinations![index],
                          screenWidth,
                          screenHeight,
                          isDesktop:
                              true, // Flag para indicar que estamos en desktop
                        );
                      },
                    );
                  }

                  // CASO: MÓVIL (LIST VIEW ORIGINAL)
                  return ListView.builder(
                    controller: _scrollController,
                    itemCount: _displayedDestinations!.length,
                    padding: EdgeInsets.fromLTRB(
                        screenWidth * 0.05, 0, screenWidth * 0.05, 20),
                    itemBuilder: (context, index) {
                      return _buildDestinationItem(
                        _displayedDestinations![index],
                        screenWidth,
                        screenHeight,
                        isDesktop: false,
                      );
                    },
                  );
                },
              ),
            ),
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
          currentIndex: 0,
          onTap: (index) {
            switch (index) {
              case 0:
                context.go('/');
                break;
              case 1:
                context.go('/bookings');
                break;
              case 2:
                context.go('/saved');
                break;
              case 3:
                context.go('/settings');
                break;
            }
          },
          items: [
            BottomNavigationBarItem(
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedHome02,
                color: Color.fromRGBO(17, 48, 73, 1),
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
    );
  }

  // --- MÉTODO HELPER PARA CONSTRUIR LA TARJETA ---
  // Esto evita repetir código entre ListView y GridView
  Widget _buildDestinationItem(QueryDocumentSnapshot destination,
      double screenWidth, double screenHeight,
      {required bool isDesktop}) {
    final data = destination.data() as Map<String, dynamic>? ?? {};
    final paquetes = data['paquetes'] as List<dynamic>? ?? [];
    final minPrice = _getMinPrice(paquetes);
    final destinationId = destination.id;
    final isSaved = isDestinationSaved(destinationId, savedDestinationsBox);
    final images = _extractImages(data, destinationId);

    // Si es Desktop, usamos un LayoutBuilder para que la tarjeta use el ancho de su celda, no de la pantalla
    // Si es Móvil, usamos el padding original

    Widget card = LayoutBuilder(builder: (context, constraints) {
      // En desktop, 'screenWidth' para la tarjeta será el ancho de la celda (constraints.maxWidth)
      // En móvil, sigue siendo el ancho de pantalla.
      final cardWidth = isDesktop ? constraints.maxWidth : screenWidth;

      return DestinationCard(
        images: images,
        title: data['nombre'] ?? '',
        location: data['estado'] ?? '',
        place: data['lugar'] ?? 'Lugar no disponible',
        price: minPrice,
        screenWidth: cardWidth, // <--- AQUÍ ESTÁ EL TRUCO
        isSaved: isSaved,
        userId: widget.userId,
        destinationId: destinationId,
        data: data,
        currencySymbol: data['divisa']?.toString() == 'eur' ? '€' : '\$',
        onTap: () {
          // CORRECCIÓN: Agregar ID al mapa data antes de enviar
          data['id'] = destinationId;

          context.push('/d/$destinationId', extra: data);
        },
      );
    });

    if (isDesktop) {
      return card; // En GridView no necesitamos Padding inferior extra, el grid lo maneja con mainAxisSpacing
    } else {
      return Padding(
        padding: EdgeInsets.only(bottom: screenHeight * 0.025),
        child: card,
      );
    }
  }
}

class DestinationCard extends StatefulWidget {
  final List<String> images;
  final String title;
  final String location;
  final String place;
  final double price;
  final double screenWidth;
  final bool isSaved;
  final String userId;
  final String destinationId;
  final Map<String, dynamic> data;
  final VoidCallback onTap;
  // Símbolo de moneda: '$' para USD (por defecto) o '€' para EUR
  final String currencySymbol;

  const DestinationCard({
    super.key,
    required this.images,
    required this.title,
    required this.location,
    required this.place,
    required this.price,
    required this.screenWidth,
    required this.isSaved,
    required this.userId,
    required this.destinationId,
    required this.data,
    required this.onTap,
    this.currencySymbol = '\$',
  });

  @override
  State<DestinationCard> createState() => _DestinationCardState();
}

class _DestinationCardState extends State<DestinationCard> {
  late bool localIsSaved;
  late PageController pageController;
  int currentPage = 0;

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
    // Definimos una altura fija proporcional
    final cardHeight = widget.screenWidth * 0.7;

    return SizedBox(
      height: cardHeight,
      width: widget.screenWidth,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // 1. Carrusel de Imágenes
              Positioned.fill(
                child: widget.images.isNotEmpty
                    ? PageView.builder(
                        controller: pageController,
                        itemCount: widget.images.length,
                        onPageChanged: (index) {
                          setState(() {
                            currentPage = index;
                          });
                        },
                        itemBuilder: (context, index) {
                          return GestureDetector(
                            onTap: widget.onTap,
                            child: CachedNetworkImage(
                              imageUrl: widget.images[index],
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: Colors.grey[200],
                                child: const Center(),
                              ),
                              errorWidget: (context, url, error) {
                                return Container(
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.broken_image,
                                      color: Colors.grey),
                                );
                              },
                            ),
                          );
                        },
                      )
                    : GestureDetector(
                        onTap: widget.onTap,
                        child: Container(
                          color: Colors.grey[300],
                          child: const Center(child: Text('Sin imágenes')),
                        ),
                      ),
              ),

              // 2. Gradiente
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.2),
                          Colors.black.withValues(alpha: 0.7),
                          Colors.black.withValues(alpha: 0.9),
                        ],
                        stops: const [0.0, 0.4, 0.6, 0.85, 1.0],
                      ),
                    ),
                  ),
                ),
              ),

              // 3. Indicadores de posición
              if (widget.images.length > 1)
                Positioned(
                  top: 20,
                  left: 20,
                  child: IgnorePointer(
                    child: Row(
                      children: List.generate(widget.images.length, (index) {
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.only(right: 6),
                          width: currentPage == index ? 20 : 6,
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
                ),

              // 4. Botón de favorito
              Positioned(
                top: 16,
                right: 16,
                child: GestureDetector(
                  onTap: () async {
                    final userBoxName = 'saved_destinations_${widget.userId}';
                    final userBox = await Hive.openBox<Map>(userBoxName);
                    if (localIsSaved) {
                      await userBox.delete(widget.destinationId);
                    } else {
                      await userBox.put(widget.destinationId, widget.data);
                    }
                    setState(() {
                      localIsSaved = !localIsSaved;
                    });
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(50),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                              width: 1),
                        ),
                        child: Center(
                          child: Icon(
                            localIsSaved
                                ? Icons.favorite
                                : Icons.favorite_border_rounded,
                            color: localIsSaved
                                ? const Color.fromARGB(255, 255, 255, 255)
                                : Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // 5. Información del destino
              Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: GestureDetector(
                  onTap: widget.onTap,
                  behavior: HitTestBehavior.translucent,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.place.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1)),
                          ),
                          child: Text(
                            widget.place.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Text(
                              widget.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                height: 1.2,
                                fontFamily: 'Poppins',
                                shadows: [
                                  Shadow(
                                    offset: Offset(0, 1),
                                    blurRadius: 4,
                                    color: Colors.black45,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${widget.currencySymbol}${widget.price.toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: Color.fromRGBO(17, 48, 73, 1),
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(HugeIcons.strokeRoundedLocation01,
                              color: Colors.white70, size: 16),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              widget.location,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                fontFamily: 'Poppins',
                              ),
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
        ),
      ),
    );
  }
}
