import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

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
    // No necesitamos screenWidth/Height para el diseño responsivo de la barra,
    // usamos constraints flexibles.

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 243, 247, 254),
      // Usamos SafeArea en lugar de AppBar para el diseño personalizado
      body: SafeArea(
        child: Column(
          children: [
            // --- BARRA DE BÚSQUEDA PERSONALIZADA ---
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 15),
              child: Container(
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
                    // Botón de Atrás integrado
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: Colors.grey.shade400),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Encuentra una nueva actividad',
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
                      padding: EdgeInsets.only(right: 16.0),
                      child: Icon(Icons.search, color: Colors.grey, size: 24),
                    ),
                  ],
                ),
              ),
            ),

            // --- RESULTADOS (Lógica original intacta) ---
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('destinos')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(); // Spinner removido para limpieza visual, o pon CircularProgressIndicator()
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

                    // Excluir destinos privados
                    if (data['isPrivate'] == true) return false;

                    return _searchText.isEmpty ||
                        name.toLowerCase().contains(_searchText.toLowerCase());
                  }).toList();

                  return ListView.builder(
                    itemCount: destinations.length,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
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
                            data['estado'] ?? 'Ubicación no disponible',
                            style: const TextStyle(
                                fontFamily: 'Poppins',
                                color: Color.fromRGBO(17, 48, 73, 1))),
                        onTap: () {
                          // Mismo patrón que destinations_screen:
                          // inyectar el id en data y navegar por GoRouter
                          data['id'] = destination.id;
                          context.push('/d/${destination.id}', extra: data);
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
