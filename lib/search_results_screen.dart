import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'destination_detail_screen.dart';

class SearchResultsScreen extends StatefulWidget {
  final String userId;

  const SearchResultsScreen({super.key, required this.userId});

  @override
  SearchResultsScreenState createState() => SearchResultsScreenState();
}

class SearchResultsScreenState extends State<SearchResultsScreen> {
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 243, 247, 254),
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(screenWidth * 0.04),
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
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Encuentra un nuevo destino',
                        border: InputBorder.none,
                        hintStyle: TextStyle(
                            color: Colors.grey, fontFamily: 'Poppins'),
                      ),
                      style: const TextStyle(
                          color: Colors.grey, fontFamily: 'Poppins'),
                    ),
                  ),
                  const Icon(Icons.search, color: Colors.grey),
                ],
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance.collection('destinos').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center();
                }

                if (snapshot.hasError) {
                  return const Center(
                      child: Text('Error al cargar los destinos',
                          style: TextStyle(fontFamily: 'Poppins')));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                      child: Text('No hay destinos disponibles',
                          style: TextStyle(fontFamily: 'Poppins')));
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
                    final destination = destinations[index];
                    final data = destination.data() as Map<String, dynamic>?;

                    if (data == null) {
                      return const SizedBox.shrink();
                    }

                    return ListTile(
                      title: Text(data['nombre'] ?? 'Nombre no disponible',
                          style: const TextStyle(
                              fontFamily: 'Poppins',
                              color: Color.fromRGBO(17, 48, 73, 1))),
                      subtitle: Text(
                          data['ubicacion'] ?? 'Ubicación no disponible',
                          style: const TextStyle(
                              fontFamily: 'Poppins',
                              color: Color.fromRGBO(17, 48, 73, 1))),
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
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      backgroundColor: const Color.fromARGB(255, 243, 247, 254),
    );
  }
}
