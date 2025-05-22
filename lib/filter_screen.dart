import 'package:flutter/material.dart';
import 'destinations_screen.dart';

class FilterScreen extends StatefulWidget {
  final List<String> selectedCategories;
  final String selectedLocation;
  final String userId;
  final List<String> destinations;
  final String searchText;

  const FilterScreen({
    super.key,
    required this.selectedCategories,
    required this.selectedLocation,
    required this.userId,
    required this.destinations,
    required this.searchText,
  });

  @override
  FilterScreenState createState() => FilterScreenState();
}

class FilterScreenState extends State<FilterScreen> {
  late List<String> selectedCategories;
  late String location;
  int sortOption = 0; // 0: Aleatorio, 1: Ascendente, 2: Descendente

  @override
  void initState() {
    super.initState();
    selectedCategories = List<String>.from(widget.selectedCategories);
    location = widget.selectedLocation;
    sortOption = 0;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 243, 247, 254),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(screenWidth * 0.04),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Categorías',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                  color: Color.fromRGBO(17, 48, 73, 1)),
            ),
            Wrap(
              spacing: 8.0,
              children: [
                FilterChip(
                  label: const Text('Todas',
                      style: TextStyle(
                          fontFamily: 'Poppins', color: Colors.white)),
                  selected: selectedCategories.contains('Todas'),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        selectedCategories = ['Todas'];
                      } else {
                        selectedCategories.remove('Todas');
                      }
                    });
                  },
                  backgroundColor: const Color.fromRGBO(17, 48, 73, 1),
                  selectedColor: const Color.fromRGBO(17, 48, 73, 1),
                  checkmarkColor: const Color.fromRGBO(240, 169, 52, 1),
                ),
                FilterChip(
                  label: const Text('Vida nocturna',
                      style: TextStyle(
                          fontFamily: 'Poppins', color: Colors.white)),
                  selected: selectedCategories.contains('Vida nocturna'),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        selectedCategories.add('Vida nocturna');
                      } else {
                        selectedCategories.remove('Vida nocturna');
                      }
                    });
                  },
                  backgroundColor: const Color.fromRGBO(17, 48, 73, 1),
                  selectedColor: const Color.fromRGBO(17, 48, 73, 1),
                  checkmarkColor: const Color.fromRGBO(240, 169, 52, 1),
                ),
                FilterChip(
                  label: const Text('Divertido',
                      style: TextStyle(
                          fontFamily: 'Poppins', color: Colors.white)),
                  selected: selectedCategories.contains('Divertido'),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        selectedCategories.add('Divertido');
                      } else {
                        selectedCategories.remove('Divertido');
                      }
                    });
                  },
                  backgroundColor: const Color.fromRGBO(17, 48, 73, 1),
                  selectedColor: const Color.fromRGBO(17, 48, 73, 1),
                  checkmarkColor: const Color.fromRGBO(240, 169, 52, 1),
                ),
                FilterChip(
                  label: const Text('Ciudad',
                      style: TextStyle(
                          fontFamily: 'Poppins', color: Colors.white)),
                  selected: selectedCategories.contains('Ciudad'),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        selectedCategories.add('Ciudad');
                      } else {
                        selectedCategories.remove('Ciudad');
                      }
                    });
                  },
                  backgroundColor: const Color.fromRGBO(17, 48, 73, 1),
                  selectedColor: const Color.fromRGBO(17, 48, 73, 1),
                  checkmarkColor: const Color.fromRGBO(240, 169, 52, 1),
                ),
                FilterChip(
                  label: const Text('Montaña',
                      style: TextStyle(
                          fontFamily: 'Poppins', color: Colors.white)),
                  selected: selectedCategories.contains('Montaña'),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        selectedCategories.add('Montaña');
                      } else {
                        selectedCategories.remove('Montaña');
                      }
                    });
                  },
                  backgroundColor: const Color.fromRGBO(17, 48, 73, 1),
                  selectedColor: const Color.fromRGBO(17, 48, 73, 1),
                  checkmarkColor: const Color.fromRGBO(240, 169, 52, 1),
                ),
                FilterChip(
                  label: const Text('Extremo',
                      style: TextStyle(
                          fontFamily: 'Poppins', color: Colors.white)),
                  selected: selectedCategories.contains('Extremo'),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        selectedCategories.add('Extremo');
                      } else {
                        selectedCategories.remove('Extremo');
                      }
                    });
                  },
                  backgroundColor: const Color.fromRGBO(17, 48, 73, 1),
                  selectedColor: const Color.fromRGBO(17, 48, 73, 1),
                  checkmarkColor: const Color.fromRGBO(240, 169, 52, 1),
                ),
                FilterChip(
                  label: const Text('Playa',
                      style: TextStyle(
                          fontFamily: 'Poppins', color: Colors.white)),
                  selected: selectedCategories.contains('Playa'),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        selectedCategories.add('Playa');
                      } else {
                        selectedCategories.remove('Playa');
                      }
                    });
                  },
                  backgroundColor: const Color.fromRGBO(17, 48, 73, 1),
                  selectedColor: const Color.fromRGBO(17, 48, 73, 1),
                  checkmarkColor: const Color.fromRGBO(240, 169, 52, 1),
                ),
                FilterChip(
                  label: const Text('Cultural',
                      style: TextStyle(
                          fontFamily: 'Poppins', color: Colors.white)),
                  selected: selectedCategories.contains('Cultural'),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        selectedCategories.add('Cultural');
                      } else {
                        selectedCategories.remove('Cultural');
                      }
                    });
                  },
                  backgroundColor: const Color.fromRGBO(17, 48, 73, 1),
                  selectedColor: const Color.fromRGBO(17, 48, 73, 1),
                  checkmarkColor: const Color.fromRGBO(240, 169, 52, 1),
                ),
                FilterChip(
                  label: const Text('Comida',
                      style: TextStyle(
                          fontFamily: 'Poppins', color: Colors.white)),
                  selected: selectedCategories.contains('Comida'),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        selectedCategories.add('Comida');
                      } else {
                        selectedCategories.remove('Comida');
                      }
                    });
                  },
                  backgroundColor: const Color.fromRGBO(17, 48, 73, 1),
                  selectedColor: const Color.fromRGBO(17, 48, 73, 1),
                  checkmarkColor: const Color.fromRGBO(240, 169, 52, 1),
                ),
                FilterChip(
                  label: const Text('Pernocta',
                      style: TextStyle(
                          fontFamily: 'Poppins', color: Colors.white)),
                  selected: selectedCategories.contains('Pernocta'),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        selectedCategories.add('Pernocta');
                      } else {
                        selectedCategories.remove('Pernocta');
                      }
                    });
                  },
                  backgroundColor: const Color.fromRGBO(17, 48, 73, 1),
                  selectedColor: const Color.fromRGBO(17, 48, 73, 1),
                  checkmarkColor: const Color.fromRGBO(240, 169, 52, 1),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Ubicación',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                  color: Color.fromRGBO(17, 48, 73, 1)),
            ),
            DropdownButton<String>(
              value: location,
              dropdownColor: const Color.fromARGB(255, 255, 255, 255),
              items: const [
                DropdownMenuItem(
                    value: 'Todas',
                    child: Text('Todas',
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            color: Color.fromRGBO(17, 48, 73, 1)))),
                DropdownMenuItem(
                    value: 'Caracas',
                    child: Text('Caracas',
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            color: Color.fromRGBO(17, 48, 73, 1)))),
                DropdownMenuItem(
                    value: 'Miranda',
                    child: Text('Miranda',
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            color: Color.fromRGBO(17, 48, 73, 1)))),
                DropdownMenuItem(
                    value: 'Falcón',
                    child: Text('Falcón',
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            color: Color.fromRGBO(17, 48, 73, 1)))),
                DropdownMenuItem(
                    value: 'Yaracuy',
                    child: Text('Yaracuy',
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            color: Color.fromRGBO(17, 48, 73, 1)))),
                DropdownMenuItem(
                    value: 'Zulia',
                    child: Text('Zulia',
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            color: Color.fromRGBO(17, 48, 73, 1)))),
                DropdownMenuItem(
                    value: 'Apure',
                    child: Text('Apure',
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            color: Color.fromRGBO(17, 48, 73, 1)))),
                DropdownMenuItem(
                    value: 'Los Roques',
                    child: Text('Los Roques',
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            color: Color.fromRGBO(17, 48, 73, 1)))),
                DropdownMenuItem(
                    value: 'Sucre',
                    child: Text('Sucre',
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            color: Color.fromRGBO(17, 48, 73, 1)))),
                DropdownMenuItem(
                    value: 'Bolívar',
                    child: Text('Bolívar',
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            color: Color.fromRGBO(17, 48, 73, 1)))),
                DropdownMenuItem(
                    value: 'Amazonas',
                    child: Text('Amazonas',
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            color: Color.fromRGBO(17, 48, 73, 1)))),
                DropdownMenuItem(
                    value: 'La Guaira',
                    child: Text('La Guaira',
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            color: Color.fromRGBO(17, 48, 73, 1)))),
                DropdownMenuItem(
                    value: 'Nueva Esparta',
                    child: Text('Nueva Esparta',
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            color: Color.fromRGBO(17, 48, 73, 1)))),
                DropdownMenuItem(
                    value: 'Mérida',
                    child: Text('Mérida',
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            color: Color.fromRGBO(17, 48, 73, 1)))),
                DropdownMenuItem(
                    value: 'Barinas',
                    child: Text('Barinas',
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            color: Color.fromRGBO(17, 48, 73, 1)))),
                DropdownMenuItem(
                    value: 'Carabobo',
                    child: Text('Carabobo',
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            color: Color.fromRGBO(17, 48, 73, 1)))),
              ],
              onChanged: (value) {
                setState(() {
                  location = value!;
                });
              },
            ),
            const SizedBox(height: 16),
            const Text(
              'Ordenar por precio',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                  color: Color.fromRGBO(17, 48, 73, 1)),
            ),
            Row(
              children: [
                Expanded(
                  child: IconButton(
                    icon: const Icon(Icons.arrow_upward),
                    onPressed: () {
                      setState(() {
                        sortOption = 1;
                      });
                    },
                    color: sortOption == 1
                        ? const Color.fromRGBO(17, 48, 73, 1)
                        : Colors.grey,
                    tooltip: 'Precio ascendente',
                  ),
                ),
                Expanded(
                  child: IconButton(
                    icon: const Icon(Icons.arrow_downward),
                    onPressed: () {
                      setState(() {
                        sortOption = 2;
                      });
                    },
                    color: sortOption == 2
                        ? const Color.fromRGBO(17, 48, 73, 1)
                        : Colors.grey,
                    tooltip: 'Precio descendente',
                  ),
                ),
                Expanded(
                  child: IconButton(
                    icon: const Icon(Icons.shuffle),
                    onPressed: () {
                      setState(() {
                        sortOption = 0;
                      });
                    },
                    color: sortOption == 0
                        ? const Color.fromRGBO(17, 48, 73, 1)
                        : Colors.grey,
                    tooltip: 'Aleatorio',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DestinationsScreen(
                        userId: widget.userId,
                        destinations: widget.destinations,
                        initialCategories: selectedCategories,
                        initialLocation: location,
                        sortOption: sortOption, // <-- Nuevo parámetro
                        searchText: widget.searchText,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  iconColor: const Color.fromARGB(255, 243, 247, 254),
                  backgroundColor: const Color.fromRGBO(17, 48, 73, 1),
                ),
                child: const Text(
                  'Aplicar',
                  style: TextStyle(fontFamily: 'Poppins', color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
      backgroundColor: const Color.fromARGB(255, 243, 247, 254),
    );
  }
}
