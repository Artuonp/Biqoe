import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui';

const Color kPrimaryColor = Color.fromRGBO(17, 48, 73, 1);
const Color kBackgroundColor = Color(0xFFF3F7FE);

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
    _initHive();
    _searchController.addListener(() {
      setState(() {
        _searchText = _searchController.text;
      });
    });
  }

  Future<void> _initHive() async {
    final box = await Hive.openBox<Map>('saved_destinations_${widget.userId}');
    if (mounted) {
      setState(() {
        savedDestinationsBox = box;
        isLoading = false;
      });
    }
  }

  double _getMinPrice(List<dynamic> paquetes) {
    if (paquetes.isEmpty) return 0.0;
    final precios = paquetes
        .where((p) => p['precio'] != null)
        .map<double>((p) => (p['precio'] as num).toDouble())
        .toList();
    return precios.isNotEmpty ? precios.reduce((a, b) => a < b ? a : b) : 0.0;
  }

  List<String> _extractImages(Map<dynamic, dynamic> rawData) {
    List<String> images = [];
    final data = rawData.map((k, v) => MapEntry(k.toString(), v));

    try {
      if (data['imagenes'] != null && data['imagenes'] is List) {
        List<dynamic> rawList = data['imagenes'];
        images = rawList
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
      if (images.isEmpty && data['imagen'] != null) {
        var rawImg = data['imagen'];
        if (rawImg is List) {
          images = rawImg.map((e) => e.toString().trim()).toList();
        } else if (rawImg is String) {
          String cleaned = rawImg
              .replaceAll('[', '')
              .replaceAll(']', '')
              .replaceAll('"', '')
              .replaceAll("'", "");
          if (cleaned.contains(',')) {
            images = cleaned
                .split(',')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList();
          } else if (cleaned.trim().isNotEmpty) {
            images = [cleaned.trim()];
          }
        }
      }
    } catch (e) {
      debugPrint("Error extrayendo imágenes: $e");
    }
    return images;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    if (isLoading) {
      return const Scaffold(
        backgroundColor: kBackgroundColor,
        body: Center(),
      );
    }

    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // --- HEADER CENTRADO ---
            Padding(
              padding: EdgeInsets.fromLTRB(
                  screenWidth * 0.05, 10, screenWidth * 0.05, 15),
              child: Column(
                children: [
                  const Center(
                    child: Text(
                      "Guardados",
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                        color: kPrimaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
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
                        const SizedBox(width: 16),
                        Icon(HugeIcons.strokeRoundedSearch01,
                            color: Colors.grey.shade400, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Busca en tus guardados',
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
                              color: kPrimaryColor,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // --- LISTA DE FAVORITOS (ValueListenable para actualizar al borrar) ---
            Expanded(
              child: ValueListenableBuilder(
                valueListenable: savedDestinationsBox.listenable(),
                builder: (context, Box<Map> box, _) {
                  final allDestinations = box.toMap().entries.toList();

                  // Filtro de búsqueda local
                  final filteredDestinations = allDestinations.where((entry) {
                    final data = entry.value;
                    final name = data['nombre'] ?? '';
                    return _searchText.isEmpty ||
                        name.toLowerCase().contains(_searchText.toLowerCase());
                  }).toList();

                  if (filteredDestinations.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(HugeIcons.strokeRoundedFavourite,
                              size: 50, color: Colors.grey[300]),
                          const SizedBox(height: 10),
                          const Text(
                            'No tienes guardados',
                            style: TextStyle(
                              fontSize: 16.0,
                              color: Colors.grey,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: EdgeInsets.symmetric(
                        horizontal: screenWidth * 0.05, vertical: 10),
                    itemCount: filteredDestinations.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 20),
                    itemBuilder: (context, index) {
                      final entry = filteredDestinations[index];
                      final key = entry.key;
                      final rawData = entry.value;

                      final Map<String, dynamic> data =
                          rawData.map((k, v) => MapEntry(k.toString(), v));

                      if (!data.containsKey('id')) {
                        data['id'] = key.toString();
                      }

                      final paquetes = data['paquetes'] as List<dynamic>? ?? [];
                      final minPrice = _getMinPrice(paquetes);
                      final images = _extractImages(rawData);

                      return DestinationCard(
                        images: images,
                        title: data['nombre'] ?? 'Sin nombre',
                        location: data['ubicacion'] ?? 'Desconocida',
                        place: data['lugar'] ?? '',
                        price: minPrice,
                        screenWidth: screenWidth,
                        isSaved: true,
                        onFavoriteTap: () {
                          // Borra inmediatamente de Hive
                          savedDestinationsBox.delete(key);
                        },
                        onTap: () {
                          context.push('/d/${data['id']}', extra: data);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// DestinationCard DEBE SER IGUAL A LA DE DESTINATIONS_SCREEN
class DestinationCard extends StatefulWidget {
  final List<String> images;
  final String title;
  final String location;
  final String place;
  final double price;
  final double screenWidth;
  final bool isSaved;
  final VoidCallback onFavoriteTap;
  final VoidCallback onTap;

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
    required this.onTap,
  });

  @override
  State<DestinationCard> createState() => _DestinationCardState();
}

class _DestinationCardState extends State<DestinationCard> {
  late PageController pageController;
  int currentPage = 0;

  @override
  void initState() {
    super.initState();
    pageController = PageController();
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              Positioned.fill(
                child: widget.images.isNotEmpty
                    ? PageView.builder(
                        controller: pageController,
                        itemCount: widget.images.length,
                        onPageChanged: (index) =>
                            setState(() => currentPage = index),
                        itemBuilder: (context, index) {
                          return GestureDetector(
                            onTap: widget.onTap,
                            child: CachedNetworkImage(
                              imageUrl: widget.images[index],
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                  color: Colors.grey[200],
                                  child: const Center()),
                              errorWidget: (context, url, error) => Container(
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.broken_image,
                                      color: Colors.grey)),
                            ),
                          );
                        },
                      )
                    : GestureDetector(
                        onTap: widget.onTap,
                        child: Container(
                            color: Colors.grey[300],
                            child: const Center(
                                child: Icon(Icons.image_not_supported,
                                    color: Colors.grey))),
                      ),
              ),
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
              Positioned(
                top: 16,
                right: 16,
                child: GestureDetector(
                  onTap: widget.onFavoriteTap,
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
                              color: const Color.fromARGB(255, 255, 255, 255)
                                  .withValues(alpha: 0.2),
                              width: 1),
                        ),
                        child: Center(
                          child: Icon(
                            Icons
                                .favorite, // Siempre lleno porque es la lista de favoritos
                            color: const Color.fromARGB(255, 255, 255, 255),
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
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
                                      color: Colors.black45)
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
                              '€${widget.price.toStringAsFixed(0)}',
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
