import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';

import 'destination_detail_screen.dart';
import 'search_screen.dart';
import 'bookings_screen.dart';
import 'saved_destinations_screen.dart';
import 'settings_screen.dart';

class RestaurantsScreen extends StatefulWidget {
  final String userId;

  const RestaurantsScreen({super.key, required this.userId});

  @override
  State<RestaurantsScreen> createState() => _RestaurantsScreenState();
}

class _RestaurantsScreenState extends State<RestaurantsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  String? _selectedUbicacion;

  late Box<Map> _savedDestinationsBox;
  final ValueNotifier<Set<String>> _savedDestinationIdsNotifier =
      ValueNotifier({});
  bool _isHiveReady = false;

  List<DocumentSnapshot>? _shuffledRestaurants; // NUEVO
  DateTime? _selectedFecha;
  int? _selectedCantidad;
  Set<String>? _selectedCocinas;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (mounted) setState(() => _searchText = _searchController.text);
    });
    _initHive();
  }

  Future<void> _initHive() async {
    _savedDestinationsBox =
        await Hive.openBox<Map>('saved_destinations_${widget.userId}');
    if (mounted) {
      _savedDestinationIdsNotifier.value =
          _savedDestinationsBox.keys.cast<String>().toSet();
      setState(() => _isHiveReady = true);
    }
  }

  Future<void> _showCocinaDialog() async {
    // Listas organizadas por categorías
    final List<Map<String, List<String>>> secciones = [
      {
        'Por país:': [
          'Alemana',
          'Argentina',
          'Brasileña',
          'China',
          'Egipcia',
          'Española',
          'Francesa',
          'Griega',
          'India',
          'Iraquí',
          'Italiana',
          'Japonesa',
          'Jordana',
          'Libanesa',
          'Marroquí',
          'Mexicana',
          'Peruana',
          'Tailandesa',
          'Turca',
          'Uruguaya',
          'Venezolana',
          'Vietnamita'
        ],
      },
      {
        'Por región:': [
          'Mediterránea',
          'Asiática',
          'Latinoamericana',
          'Europea del este',
          'Norteafricana',
          'Caribeña',
          'Sudamericana',
        ],
      },
      {
        'Por ingrediente principal:': [
          'Mariscos',
          'Carnes',
          'Vegetales',
        ],
      },
      {
        'Por estilo:': [
          'Fusión',
          'Gourmet',
          'Tradicional',
          'De autor',
          'Rápida',
          'Saludable',
          'Familiar',
          'Temática',
          'Tapas',
          'Buffet',
          'Deconstrucción',
        ],
      },
      {
        'Por momento:': [
          'Desayuno',
          'Brunch',
          'Almuerzo',
          'Cena',
        ],
      },
      {
        'Por dieta:': [
          'Sin gluten',
          'Sin lactosa',
          'Keto',
          'Paleo',
          'Halal',
          'Kosher',
        ],
      },
    ];

    // Copia temporal de la selección
    Set<String> tempSelected = Set<String>.from(_selectedCocinas ?? {});

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return StatefulBuilder(
              // Importante: este StatefulBuilder permite que se actualice en tiempo real
              builder: (context, setModalState) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        'Selecciona tipos de cocina',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: const Color.fromRGBO(17, 48, 73, 1),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: secciones.length,
                          itemBuilder: (context, sectionIndex) {
                            final section = secciones[sectionIndex];
                            final sectionTitle = section.keys.first;
                            final filters = section.values.first;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12.0,
                                  ),
                                  child: Text(
                                    sectionTitle,
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          const Color.fromRGBO(17, 48, 73, 1),
                                    ),
                                  ),
                                ),
                                ...filters.map((cocina) {
                                  final isSelected =
                                      tempSelected.contains(cocina);
                                  return CheckboxListTile(
                                    title: Text(
                                      cocina,
                                      style: GoogleFonts.poppins(
                                        color:
                                            const Color.fromRGBO(17, 48, 73, 1),
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                    value: isSelected,
                                    activeColor:
                                        const Color.fromRGBO(17, 48, 73, 1),
                                    onChanged: (selected) {
                                      if (selected == null) return;
                                      setModalState(() {
                                        if (selected) {
                                          tempSelected.add(cocina);
                                        } else {
                                          tempSelected.remove(cocina);
                                        }
                                      });
                                      // Además actualiza la variable global al instante
                                      setState(() {
                                        _selectedCocinas = tempSelected;
                                      });
                                    },
                                  );
                                }),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () {
                                setModalState(() {
                                  tempSelected.clear();
                                });
                                setState(() {
                                  _selectedCocinas = {};
                                });
                              },
                              child: Text(
                                'Limpiar',
                                style: GoogleFonts.poppins(
                                  color: const Color.fromRGBO(17, 48, 73, 1),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    const Color.fromRGBO(17, 48, 73, 1),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              child: Text(
                                'Aplicar',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _showCantidadDialog() async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      isScrollControlled: true,
      builder: (context) {
        int tempCantidad = _selectedCantidad ?? 1; // Inicializa en 1 si es null
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Selecciona la cantidad de personas',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color.fromRGBO(17, 48, 73, 1),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove),
                        onPressed: () {
                          if (tempCantidad > 1) {
                            setModalState(() {
                              tempCantidad--;
                            });
                            setState(() {
                              _selectedCantidad = tempCantidad;
                            });
                          }
                        },
                      ),
                      Text(
                        '$tempCantidad',
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: const Color.fromRGBO(17, 48, 73, 1),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () {
                          setModalState(() {
                            tempCantidad++;
                          });
                          setState(() {
                            _selectedCantidad = tempCantidad;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromRGBO(17, 48, 73, 1),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Aplicar',
                      style: TextStyle(color: Colors.white),
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showFechaDialog() async {
    DateTime tempSelectedDate = _selectedFecha ?? DateTime.now();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 16,
            left: 16,
            right: 16,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Selecciona una fecha',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color.fromRGBO(17, 48, 73, 1),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: ColorScheme.light(
                        primary: const Color.fromRGBO(
                            17, 48, 73, 1), // Aquí cambia el color
                        onPrimary: Colors.white,
                        onSurface: const Color.fromRGBO(17, 48, 73, 1),
                      ),
                    ),
                    child: CalendarDatePicker(
                      initialDate: tempSelectedDate,
                      firstDate: DateTime.now(),
                      lastDate:
                          DateTime.now().add(const Duration(days: 365 * 2)),
                      onDateChanged: (date) {
                        setModalState(() {
                          tempSelectedDate = date;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color.fromRGBO(17, 48, 73, 1),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            // "Cualquier fecha"
                            setState(() {
                              _selectedFecha = null;
                            });
                            Navigator.pop(context);
                          },
                          child: Text(
                            'Cualquiera',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            // Cancelar
                            Navigator.pop(context);
                          },
                          child: Text(
                            'Cancelar',
                            style: GoogleFonts.poppins(
                              color: const Color.fromRGBO(17, 48, 73, 1),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color.fromRGBO(17, 48, 73, 1),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            // Aceptar
                            setState(() {
                              _selectedFecha = tempSelectedDate;
                            });
                            Navigator.pop(context);
                          },
                          child: Text(
                            'Aceptar',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _showUbicacionDialog() async {
    final List<String> ubicaciones = [
      'Todas',
      'Caracas',
      'Miranda',
      'Zulia', // Nueva opción que quita el filtro
      'Amazonas',
      'Anzoátegui',
      'Apure',
      'Aragua',
      'Barinas',
      'Bolívar',
      'Carabobo',
      'Cojedes',
      'Delta Amacuro',
      'Falcón',
      'Guárico',
      'La Guaira',
      'Lara',
      'Mérida',
      'Monagas',
      'Nueva Esparta',
      'Portuguesa',
      'Sucre',
      'Táchira',
      'Trujillo',
      'Yaracuy'
    ];

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      isScrollControlled: true, // 🔥 permite que sea scrollable
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6, // tamaño inicial
          minChildSize: 0.4, // tamaño mínimo al contraer
          maxChildSize: 0.9, // tamaño máximo al expandir
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    'Selecciona la ubicación',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color.fromRGBO(17, 48, 73, 1),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: ubicaciones.length,
                      itemBuilder: (context, index) {
                        final ubicacion = ubicaciones[index];
                        final isSelected =
                            ubicacion == (_selectedUbicacion ?? 'Todas');

                        return ListTile(
                          title: Text(
                            ubicacion,
                            style: GoogleFonts.poppins(
                              color: const Color.fromRGBO(17, 48, 73, 1),
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          trailing: isSelected
                              ? const Icon(Icons.check,
                                  color: Color.fromRGBO(17, 48, 73, 1))
                              : null,
                          onTap: () {
                            setState(() {
                              _selectedUbicacion =
                                  ubicacion == 'Todas' ? null : ubicacion;
                            });
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void toggleSaveDestination(
      String destinationId, Map<String, dynamic> destination) {
    if (!_isHiveReady) return;

    final currentIds = Set<String>.from(_savedDestinationIdsNotifier.value);
    if (currentIds.contains(destinationId)) {
      _savedDestinationsBox.delete(destinationId);
      currentIds.remove(destinationId);
    } else {
      _savedDestinationsBox.put(destinationId, destination);
      currentIds.add(destinationId);
    }
    _savedDestinationIdsNotifier.value = currentIds;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 243, 247, 254),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 243, 247, 254),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back,
              color: Color.fromRGBO(17, 48, 73, 1)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          _buildSearchAndFilterBar(),
          Expanded(
            child: _isHiveReady
                ? _buildRestaurantsList()
                : const SizedBox(), // Quitado el CircularProgressIndicator
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavBar(context),
    );
  }

  Widget _buildSearchAndFilterBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          // Barra de Búsqueda
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Buscar restaurante',
              hintStyle: GoogleFonts.poppins(
                color: const Color.fromRGBO(17, 48, 73, 1),
              ),
              prefixIcon: Icon(
                Icons.search,
                color: const Color.fromRGBO(17, 48, 73, 1),
              ),
              filled: true,
              fillColor: Colors.white,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30.0),
                borderSide: BorderSide(
                  color: const Color.fromRGBO(17, 48, 73, 1)
                      .withAlpha((0.3 * 255).toInt()),
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30.0),
                borderSide: BorderSide(
                  color: const Color.fromRGBO(17, 48, 73, 1),
                  width: 2,
                ),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
            ),
          ),
          const SizedBox(height: 16),
          // Barra de Filtros
          Row(
            children: [
              const Icon(Icons.filter_list,
                  color: Color.fromRGBO(17, 48, 73, 1)),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('Todo', Icons.check_circle),
                      _buildFilterChip('Cocina', Icons.restaurant_menu),
                      _buildFilterChip('Ubicación', Icons.location_on_outlined),
                      _buildFilterChip('Fecha', Icons.calendar_today_outlined),
                      _buildFilterChip('Cantidad', Icons.person_outline),
                    ],
                  ),
                ),
              )
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: ActionChip(
        avatar:
            Icon(icon, size: 18, color: const Color.fromRGBO(17, 48, 73, 1)),
        label: Text(
          label,
          style: GoogleFonts.poppins(
            color: const Color.fromRGBO(17, 48, 73, 1),
          ),
        ),
        onPressed: () async {
          if (label == 'Todo') {
            setState(() {
              // Borra todo
              _selectedUbicacion = null;
              _selectedCocinas?.clear();
              _selectedFecha = null;
              _selectedCantidad = null;
            });
          } else if (label == 'Cocina') {
            await _showCocinaDialog();
          } else if (label == 'Ubicación') {
            await _showUbicacionDialog();
          } else if (label == 'Fecha') {
            await _showFechaDialog();
          } else if (label == 'Cantidad') {
            await _showCantidadDialog();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Filtro "$label" aún no implementado.'),
              ),
            );
          }
        },
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.black26),
        ),
      ),
    );
  }

  Widget _buildRestaurantsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('destinos')
          .where('isRestaurante', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Error al cargar restaurantes'));
        }
        if (!snapshot.hasData) {
          return _shuffledRestaurants == null
              ? const Center(child: CircularProgressIndicator())
              : const SizedBox.shrink();
        }

        // El shuffle se ejecuta solo una vez cuando llegan datos nuevos
        if (_shuffledRestaurants == null ||
            snapshot.data!.docs.length != _shuffledRestaurants!.length) {
          _shuffledRestaurants = snapshot.data!.docs.toList();
          _shuffledRestaurants!.shuffle();
        }

        final allRestaurants = _shuffledRestaurants ?? [];
        if (allRestaurants.isEmpty) {
          return const Center(
              child: Text(
            'No hay restaurantes disponibles',
            style: TextStyle(
                fontFamily: 'Poppins',
                color: Color.fromRGBO(17, 48, 73, 1),
                fontWeight: FontWeight.bold,
                fontSize: 16),
          ));
        }

        var restaurants = allRestaurants.where((doc) {
          final data = doc.data() as Map<String, dynamic>;

          // --- Filtro por Nombre ---
          final name = data['nombre']?.toString().toLowerCase() ?? '';
          if (_searchText.isNotEmpty &&
              !name.contains(_searchText.toLowerCase())) {
            return false;
          }

          // --- Filtro por Ubicación ---
          if (_selectedUbicacion != null &&
              data['ubicacion'] != _selectedUbicacion) {
            return false;
          }

          // --- Filtro por Tipo de Cocina (Y) ---
          if (_selectedCocinas != null && _selectedCocinas!.isNotEmpty) {
            final cocinaTags = data['cocina'] as List<dynamic>? ?? [];
            if (!_selectedCocinas!
                .every((filter) => cocinaTags.contains(filter))) {
              return false;
            }
          }

          final paquetes = data['paquetes'] as List<dynamic>? ?? [];

          // Si no hay filtros de fecha o cantidad, el restaurante pasa
          if (_selectedFecha == null && _selectedCantidad == null) {
            return true;
          }

          // Si tiene al menos un paquete de Reserva Flexible, pasa
          if (paquetes.any((p) => p['tipoDeReserva'] == 'Reserva Flexible')) {
            return true;
          }

          // Para otros paquetes, validar disponibilidad
          return paquetes.any((paquete) {
            if (paquete['tipoDeReserva'] != 'Reserva') return false;

            final disponibilidad =
                paquete['disponibilidad'] as List<dynamic>? ?? [];

            return disponibilidad.any((dispo) {
              bool fechaCoincide = true;
              if (_selectedFecha != null) {
                final fechaStr = dispo['fecha']?.toString();
                fechaCoincide = fechaStr ==
                    _selectedFecha!.toIso8601String().substring(0, 10);
              }

              // Si cantidad no está definida o es vacío, siempre pasa
              final cantidadRaw = dispo['cantidad'];
              if (cantidadRaw == null ||
                  cantidadRaw.toString().trim().isEmpty) {
                return fechaCoincide;
              }

              bool cantidadCoincide = true;
              if (_selectedCantidad != null) {
                final int? cantidad = int.tryParse(cantidadRaw.toString());
                cantidadCoincide =
                    cantidad != null && cantidad >= _selectedCantidad!;
              }

              return fechaCoincide && cantidadCoincide;
            });
          });
        }).toList();

        if (restaurants.isEmpty) {
          return const Center(
              child: Text("No hay restaurantes con esos filtros",
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 16)));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: restaurants.length,
          itemBuilder: (context, index) {
            final destination = restaurants[index];
            final data = destination.data() as Map<String, dynamic>;

            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: DestinationCard(
                key: ValueKey(destination.id),
                data: data,
                destinationId: destination.id,
                userId: widget.userId,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBottomNavBar(BuildContext context) {
    return ClipRRect(
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
                    destinations: const [],
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
    );
  }
}

// Sigue en el próximo bloque por límite de longitud
class DestinationCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final String destinationId;
  final String userId;

  const DestinationCard({
    required super.key,
    required this.data,
    required this.destinationId,
    required this.userId,
  });

  @override
  State<DestinationCard> createState() => _DestinationCardState();
}

class _DestinationCardState extends State<DestinationCard> {
  late PageController _pageController;
  late Box<Map> _savedDestinationsBox;
  bool _isHiveReady = false;
  int _currentPage = 0; // NUEVO

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _initHive();
  }

  Future<void> _initHive() async {
    _savedDestinationsBox =
        await Hive.openBox<Map>('saved_destinations_${widget.userId}');
    if (mounted) setState(() => _isHiveReady = true);
  }

  void _toggleSave() {
    if (!_isHiveReady) return;

    if (_savedDestinationsBox.containsKey(widget.destinationId)) {
      _savedDestinationsBox.delete(widget.destinationId);
    } else {
      _savedDestinationsBox.put(widget.destinationId, widget.data);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  double _getMinPrice(List<dynamic>? paquetes) {
    if (paquetes == null || paquetes.isEmpty) return 0.0;
    final precios = paquetes
        .where((p) => p['precio'] != null)
        .map<double>((p) => (p['precio'] as num).toDouble())
        .toList();
    return precios.isNotEmpty ? precios.reduce((a, b) => a < b ? a : b) : 0.0;
  }

  @override
  Widget build(BuildContext context) {
    if (!_isHiveReady) {
      return const SizedBox(height: 200);
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final images = (widget.data['imagen'] is List)
        ? (widget.data['imagen'] as List<dynamic>).cast<String>()
        : [widget.data['imagen']?.toString() ?? ''];
    final title = widget.data['nombre'] ?? 'Sin nombre';
    final location = widget.data['ubicacion'] ?? '';
    final price = _getMinPrice(widget.data['paquetes']);

    return SizedBox(
      height: screenWidth * 0.7,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DestinationDetailScreen(
                destino: widget.data,
                userId: widget.userId,
              ),
            ),
          ),
          child: Card(
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 4.0,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Imágenes deslizables
                PageView.builder(
                  controller: _pageController,
                  itemCount: images.length,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    return CachedNetworkImage(
                      imageUrl: images[index],
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                          Container(color: Colors.grey[200]),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[200],
                        child: const Center(child: Icon(Icons.error)),
                      ),
                    );
                  },
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
                            color: _currentPage == index
                                ? Colors.white
                                : const Color.fromARGB(100, 255, 255, 255),
                          ),
                        );
                      }),
                    ),
                  ),

                // Botón de favorito
                Positioned(
                  top: 10,
                  right: 10,
                  child: ValueListenableBuilder(
                    valueListenable: _savedDestinationsBox
                        .listenable(keys: [widget.destinationId]),
                    builder: (context, Box<Map> box, __) {
                      final isSaved = box.containsKey(widget.destinationId);
                      return GestureDetector(
                        onTap: _toggleSave,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Color.fromARGB(128, 17, 48, 73),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isSaved ? Icons.favorite : Icons.favorite_border,
                            color: Colors.white,
                            size: screenWidth * 0.05,
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Recuadro inferior con la información
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
      ),
    );
  }
}
