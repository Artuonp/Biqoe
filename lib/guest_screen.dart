import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hugeicons/hugeicons.dart';
import 'register_screen.dart';

class GuestScreen extends StatefulWidget {
  const GuestScreen({super.key});

  @override
  GuestScreenState createState() => GuestScreenState();
}

class GuestScreenState extends State<GuestScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';

  @override
  void initState() {
    super.initState();
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

  void _showCreateAccountDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color.fromARGB(255, 243, 247, 254),
        title: const Center(
            child: Text('Crea una cuenta',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    color: Color.fromRGBO(17, 48, 73, 1)))),
        content: const Text('Si deseas continuar debes crear una cuenta',
            style: TextStyle(
                fontFamily: 'Poppins', color: Color.fromRGBO(17, 48, 73, 1))),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    color: Color.fromRGBO(17, 48, 73, 1))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 255, 255, 255),
            ),
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const RegisterScreen()),
              );
            },
            child: const Text('Crear',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    color: Color.fromRGBO(17, 48, 73, 1),
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  List<String> _normalizeImages(dynamic imageField) {
    if (imageField == null) {
      return [];
    } else if (imageField is String) {
      return [imageField];
    } else if (imageField is List<dynamic>) {
      return imageField.cast<String>();
    } else {
      return [];
    }
  }

  Widget _buildDestinationCard({
    required List<String> images,
    required String title,
    required String location,
    required String place,
    required double price,
    required double screenWidth,
  }) {
    final PageController pageController = PageController();
    int currentPage = 0;

    return StatefulBuilder(
      builder: (context, setState) {
        return GestureDetector(
          onTap: _showCreateAccountDialog,
          child: Container(
            width: screenWidth * 0.7,
            constraints: BoxConstraints(
              minHeight: screenWidth * 0.45,
              maxHeight: screenWidth * 0.7,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(screenWidth * 0.05),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(screenWidth * 0.05),
              child: Stack(
                children: [
                  // Carrusel de imágenes
                  if (images.isNotEmpty)
                    PageView.builder(
                      controller: pageController,
                      itemCount: images.length,
                      onPageChanged: (index) {
                        setState(() => currentPage = index);
                      },
                      itemBuilder: (context, index) {
                        return CachedNetworkImage(
                          imageUrl: images[index],
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
                  if (images.length > 1)
                    Positioned(
                      bottom: screenWidth * 0.02,
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
                                  : const Color.fromARGB(100, 255, 255, 255),
                            ),
                          );
                        }),
                      ),
                    ),

                  // Información del destino
                  Positioned(
                    bottom: screenWidth * 0.05,
                    left: screenWidth * 0.075,
                    right: screenWidth * 0.075,
                    child: Container(
                      padding: EdgeInsets.all(screenWidth * 0.05),
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(100, 17, 48, 73),
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
                                  Icon(Icons.location_on,
                                      color: Colors.white,
                                      size: screenWidth * 0.035),
                                  SizedBox(width: screenWidth * 0.01),
                                  Text(
                                    '$location, $place',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: screenWidth * 0.03,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '€${price.toStringAsFixed(2)}',
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
            ),
          ),
        );
      },
    );
  }

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
                    onPressed: () => Navigator.pop(context),
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
                                  onTap: _showCreateAccountDialog,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.search,
                                    color: Colors.grey),
                                onPressed: _showCreateAccountDialog,
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: screenWidth * 0.02),
                      IconButton(
                        icon: const Icon(Icons.tune, color: Colors.grey),
                        onPressed: _showCreateAccountDialog,
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
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('destinos').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
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
              final name = data['nombre'] ?? '';
              return _searchText.isEmpty ||
                  name.toLowerCase().contains(_searchText.toLowerCase());
            }).toList();

            return ListView.builder(
              itemCount: destinations.length,
              itemBuilder: (context, index) {
                final data =
                    destinations[index].data() as Map<String, dynamic>? ?? {};
                final images = _normalizeImages(data['imagen']);
                final title = data['nombre'] ?? '';
                final location = data['ubicacion'] ?? '';
                final place = data['lugar'] ?? 'Lugar no disponible';
                final price = 0.0; // No mostrar precios reales

                return Padding(
                  padding: EdgeInsets.only(bottom: screenHeight * 0.02),
                  child: _buildDestinationCard(
                    images: images,
                    title: title,
                    location: location,
                    place: place,
                    price: price,
                    screenWidth: screenWidth,
                  ),
                );
              },
            );
          },
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
          onTap: (_) => _showCreateAccountDialog(),
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
