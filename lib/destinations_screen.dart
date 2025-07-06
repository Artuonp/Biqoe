import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'filter_screen.dart';
import 'destination_detail_screen.dart';
import 'search_screen.dart';
import 'bookings_screen.dart';
import 'saved_destinations_screen.dart';
import 'settings_screen.dart';
import 'package:hugeicons/hugeicons.dart';

class DestinationsScreen extends StatefulWidget {
  final String userId;
  final List<String> destinations;
  final List<String> initialCategories;
  final String initialLocation;
  final int sortOption; // <-- Cambia aquí
  final String searchText;

  const DestinationsScreen({
    super.key,
    required this.userId,
    required this.destinations,
    required this.initialCategories,
    required this.initialLocation,
    required this.sortOption, // <-- Cambia aquí
    required this.searchText,
  });

  @override
  DestinationsScreenState createState() => DestinationsScreenState();
}

class DestinationsScreenState extends State<DestinationsScreen> {
  late List<String> selectedCategories;
  List<QueryDocumentSnapshot>? _displayedDestinations;
  late String selectedLocation;
  late int sortOption; // <-- Cambia aquí
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  late Box<Map> savedDestinationsBox;
  Set<String> savedDestinationIds = {};
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    selectedCategories = widget.initialCategories;
    selectedLocation = widget.initialLocation;
    sortOption = widget.sortOption; // <-- Cambia aquí
    _searchText = widget.searchText;
    _searchController.text = widget.searchText;
    _searchController.addListener(() {
      setState(() {
        _searchText = _searchController.text;
      });
    });

    Hive.openBox<Map>('saved_destinations_${widget.userId}').then((box) {
      setState(() {
        savedDestinationsBox = box;
        savedDestinationIds = box.keys.cast<String>().toSet();
      });
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

  void toggleSaveDestination(
      String destinationId, Map<String, dynamic> destination) {
    final userBoxName = 'saved_destinations_${widget.userId}';
    Hive.openBox<Map>(userBoxName).then((userBox) {
      if (isDestinationSaved(destinationId, userBox)) {
        userBox.delete(destinationId);
        savedDestinationIds.remove(destinationId);
      } else {
        userBox.put(destinationId, destination);
        savedDestinationIds.add(destinationId);
      }
      // No llames a setState aquí
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

  List<String> _normalizeImages(dynamic imageField) {
    if (imageField == null) {
      return []; // Si no hay imágenes, retorna una lista vacía
    } else if (imageField is String) {
      return [imageField]; // Si es un String, lo convierte en una lista
    } else if (imageField is List<dynamic>) {
      return imageField
          .cast<String>(); // Si es una lista, la convierte a List<String>
    } else {
      return []; // Si es otro tipo, retorna una lista vacía
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  } // Código existente

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 243, 247, 254),
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(screenHeight * 0.15),
        child: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: const Color.fromARGB(255, 243, 247, 254),
          elevation: 0,
          flexibleSpace: SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back,
                        color: Colors.black, size: 25),
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SearchScreen(
                            destinations: widget.destinations,
                            userId: widget.userId,
                          ),
                        ),
                      );
                    },
                  ),
                  SizedBox(height: screenHeight * 0.0001),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
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
                                child: TextField(
                                  controller: _searchController,
                                  decoration: const InputDecoration(
                                    hintText: 'Encuentra un nuevo plan',
                                    border: InputBorder.none,
                                    contentPadding:
                                        EdgeInsets.fromLTRB(16, 0, 8, 0),
                                    hintStyle: TextStyle(
                                        color: Colors.grey,
                                        fontFamily: 'Poppins'),
                                  ),
                                  style: const TextStyle(
                                      color: Colors.grey,
                                      fontFamily: 'Poppins'),
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.only(right: 8.0),
                                child: Icon(Icons.search, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: screenWidth * 0.02),
                      IconButton(
                        icon: const Icon(Icons.tune, color: Colors.grey),
                        onPressed: () async {
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
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
        child: Column(
          children: [
            SizedBox(height: screenHeight * 0.02),
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
                    final location = data['ubicacion'] ?? 'Todas';
                    final name = data['nombre'] ?? '';

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

                  // Mezclar los destinos en un orden aleatorio
                  if (sortOption == 0) {
                    destinations.shuffle();
                  } else if (sortOption == 1) {
                    destinations.sort((a, b) {
                      final aData = a.data() as Map<String, dynamic>;
                      final bData = b.data() as Map<String, dynamic>;
                      final aPrice = _getMinPrice(aData['paquetes'] ?? []);
                      final bPrice = _getMinPrice(bData['paquetes'] ?? []);
                      return aPrice.compareTo(bPrice);
                    });
                  } else if (sortOption == 2) {
                    destinations.sort((a, b) {
                      final aData = a.data() as Map<String, dynamic>;
                      final bData = b.data() as Map<String, dynamic>;
                      final aPrice = _getMinPrice(aData['paquetes'] ?? []);
                      final bPrice = _getMinPrice(bData['paquetes'] ?? []);
                      return bPrice.compareTo(aPrice);
                    });
                  }

                  if (_displayedDestinations == null ||
                      _displayedDestinations!.length != destinations.length) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _updateDisplayedDestinations(destinations);
                    });
                    return const Center(); // Espera a que se actualice la lista
                  }

                  return ListView.builder(
                    controller: _scrollController, // <-- Agrega esto
                    itemCount: _displayedDestinations!.length,
                    itemBuilder: (context, index) {
                      final destination = _displayedDestinations![index];
                      final data =
                          destination.data() as Map<String, dynamic>? ?? {};
                      final paquetes = data['paquetes'] as List<dynamic>? ?? [];
                      final minPrice = _getMinPrice(paquetes);
                      final destinationId = destination.id;
                      final isSaved = isDestinationSaved(
                          destinationId, savedDestinationsBox);

                      return Padding(
                        padding: EdgeInsets.only(bottom: screenHeight * 0.02),
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DestinationDetailScreen(
                                  destino: data,
                                  userId: widget.userId,
                                ),
                              ),
                            );
                          },
                          child: DestinationCard(
                            images: _normalizeImages(data['imagen']),
                            title: data['nombre'] ?? '',
                            location: data['ubicacion'] ?? '',
                            place: data['lugar'] ?? 'Lugar no disponible',
                            price: minPrice,
                            screenWidth: screenWidth,
                            isSaved: isSaved,
                            userId: widget.userId,
                            destinationId: destinationId,
                            data: data,
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
                  MaterialPageRoute(
                    builder: (context) => SearchScreen(
                      destinations: widget.destinations,
                      userId: widget.userId,
                    ),
                  ),
                );
                break;
              case 1:
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BookingsScreen(userId: widget.userId),
                  ),
                );
                break;
              case 2:
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        SavedDestinationsScreen(userId: widget.userId),
                  ),
                );
                break;
              case 3:
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SettingsScreen(
                      userId: widget.userId,
                      savedDestinations: const [],
                    ),
                  ),
                );
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
}

class DestinationCard extends StatefulWidget {
  final List<dynamic> images;
  final String title;
  final String location;
  final String place;
  final double price;
  final double screenWidth;
  final bool isSaved;
  final String userId;
  final String destinationId;
  final Map<String, dynamic> data;

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
    return SizedBox(
      height: widget.screenWidth * 0.7,
      width: widget.screenWidth * 0.7,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(widget.screenWidth * 0.05),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DestinationDetailScreen(
                  destino: widget.data,
                  userId: widget.userId,
                ),
              ),
            );
          },
          child: Card(
            clipBehavior: Clip.antiAlias,
            elevation: 4.0, // sombra
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(widget.screenWidth * 0.05),
            ),
            child: Stack(
              children: [
                // Carrusel de imágenes
                if (widget.images.isNotEmpty)
                  PageView.builder(
                    controller: pageController,
                    itemCount: widget.images.length,
                    onPageChanged: (index) {
                      setState(() {
                        currentPage = index;
                      });
                    },
                    itemBuilder: (context, index) {
                      return CachedNetworkImage(
                        imageUrl: widget.images[index],
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[200],
                          child: const Center(),
                        ),
                        errorWidget: (context, url, error) =>
                            const Icon(Icons.error),
                      );
                    },
                  )
                else
                  Container(
                    color: Colors.grey[200],
                    child: const Center(child: Text('Sin imágenes')),
                  ),

                // Indicadores de posición
                if (widget.images.length > 1)
                  Positioned(
                    bottom: widget.screenWidth * 0.02,
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
                                : const Color.fromARGB(100, 255, 255, 255),
                          ),
                        );
                      }),
                    ),
                  ),

                // Botón de favorito
                Positioned(
                  top: widget.screenWidth * 0.025,
                  right: widget.screenWidth * 0.025,
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
                    child: Container(
                      width: widget.screenWidth * 0.08,
                      height: widget.screenWidth * 0.08,
                      decoration: const BoxDecoration(
                        color: Color.fromARGB(100, 17, 48, 73),
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

                // Información del destino
                Positioned(
                  bottom: widget.screenWidth * 0.05,
                  left: widget.screenWidth * 0.075,
                  right: widget.screenWidth * 0.075,
                  child: Container(
                    padding: EdgeInsets.all(widget.screenWidth * 0.05),
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(100, 17, 48, 73),
                      borderRadius:
                          BorderRadius.circular(widget.screenWidth * 0.05),
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
                                Icon(Icons.location_on,
                                    color: Colors.white,
                                    size: widget.screenWidth * 0.035),
                                SizedBox(width: widget.screenWidth * 0.01),
                                Text(
                                  '${widget.location}, ${widget.place}',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: widget.screenWidth * 0.03,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '€${widget.price.toStringAsFixed(2)}',
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
          ),
        ),
      ),
    );
  }
}
