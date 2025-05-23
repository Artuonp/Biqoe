import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

class AddScreen extends StatefulWidget {
  const AddScreen({super.key});

  @override
  AddScreenState createState() => AddScreenState();
}

class AddScreenState extends State<AddScreen> {
  final _formKey = GlobalKey<FormState>();
  final List<String> _categories = [];
  final List<String> _images = []; // Lista para múltiples imágenes
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _coordinatesController = TextEditingController();
  final TextEditingController _placeController = TextEditingController();
  String? _selectedSupplier;
  List<Map<String, dynamic>> _suppliers = [];
  final List<Map<String, dynamic>> _payments = [];
  final List<Map<String, dynamic>> _paquetes = [];
  final List<String> _predefinedCategories = [
    'Playa',
    'Montaña',
    'Ciudad',
    'Extremo',
    'Divertido',
    'Cultural',
    'Comida',
    'Pernocta',
    'Vida nocturna'
  ];

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _coordinatesController.dispose();
    super.dispose();
  }

  Future<void> _loadSuppliers() async {
    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('usuarios')
          .where('isSupplier', isEqualTo: true)
          .get();

      setState(() {
        _suppliers = querySnapshot.docs.map((doc) {
          return {
            'id': doc.id,
            'email': doc['email'],
          };
        }).toList();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar proveedores: $e')),
        );
      }
    }
  }

  Future<void> _addDestination() async {
    if (_formKey.currentState!.validate()) {
      final name = _nameController.text;
      final location = _locationController.text;
      final coordinates = _coordinatesController.text;
      final supplier = _selectedSupplier;

      if (supplier == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor seleccione un proveedor')),
        );
        return;
      }

      if (_paquetes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Debe agregar al menos un paquete')),
        );
        return;
      }

      try {
        await FirebaseFirestore.instance.collection('destinos').doc(name).set({
          'categorias': _categories,
          'imagen': _images,
          'nombre': name,
          'ubicacion': location,
          'coordenadas': coordinates,
          'supplier': supplier,
          'pagos': _payments,
          'paquetes': _paquetes,
          'IsHide': false,
          'IsHighlighted': false,
          'lugar': _placeController.text
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Destino agregado exitosamente')),
          );
        }

        _formKey.currentState!.reset();
        setState(() {
          _selectedSupplier = null;
          _paquetes.clear();
          _payments.clear();
          _images.clear();
          _categories.clear();
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al agregar destino: $e')),
          );
        }
      }
    }
  }

  void _addPaquete() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final TextEditingController precioController = TextEditingController();
        final TextEditingController descripcionController =
            TextEditingController();
        final TextEditingController miniDescripcionController =
            TextEditingController();
        final List<Map<String, dynamic>> disponibilidad = [];

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Nuevo Paquete'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: precioController,
                      decoration: const InputDecoration(labelText: 'Precio'),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Ingrese un precio válido';
                        }
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: descripcionController,
                      decoration: const InputDecoration(
                          labelText:
                              'Descripción (usa Markdown: **negrita**, *viñetas*)'),
                      maxLines: 5,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Ingrese una descripción';
                        }
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: miniDescripcionController,
                      decoration:
                          const InputDecoration(labelText: 'Mini descripción'),
                      maxLines: 3,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Ingrese una mini descripción';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () =>
                          _addDisponibilidad(context, disponibilidad, setState),
                      child: const Text('Agregar Disponibilidad'),
                    ),
                    ...disponibilidad.map((dispo) {
                      return ListTile(
                        title: Text(
                            "${dispo['fecha']} - ${dispo['inicio']} a ${dispo['fin']}"),
                        subtitle: Text("Cupos: ${dispo['cupos']}"),
                      );
                    }),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () {
                    if (precioController.text.isNotEmpty &&
                        descripcionController.text.isNotEmpty &&
                        miniDescripcionController.text.isNotEmpty &&
                        disponibilidad.isNotEmpty) {
                      setState(() {
                        _paquetes.add({
                          'numero': _paquetes.length + 1, // Agrega esta línea
                          'precio': double.parse(precioController.text),
                          'descripcion': descripcionController.text,
                          'miniDescripcion': miniDescripcionController.text,
                          'disponibilidad': List.from(disponibilidad),
                        });
                      });
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Guardar Paquete'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _addDisponibilidad(BuildContext context,
      List<Map<String, dynamic>> disponibilidad, StateSetter setState) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        DateTime? selectedDate;
        TimeOfDay? startTime;
        TimeOfDay? endTime;
        final TextEditingController slotsController = TextEditingController();

        return StatefulBuilder(
          builder: (context, dialogSetState) {
            return AlertDialog(
              title: const Text('Agregar Disponibilidad'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      final DateTime? pickedDate = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2100),
                      );
                      if (pickedDate != null) {
                        dialogSetState(() {
                          selectedDate = pickedDate;
                        });
                      }
                    },
                    child: Text(selectedDate == null
                        ? 'Seleccionar Día'
                        : DateFormat('EEEE, dd/MM/yyyy').format(selectedDate!)),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      final TimeOfDay? pickedStartTime = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (pickedStartTime != null) {
                        dialogSetState(() {
                          startTime = pickedStartTime;
                        });
                      }
                    },
                    child: Text(startTime == null
                        ? 'Seleccionar Hora de Inicio'
                        : startTime!.format(context)),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      final TimeOfDay? pickedEndTime = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (pickedEndTime != null) {
                        dialogSetState(() {
                          endTime = pickedEndTime;
                        });
                      }
                    },
                    child: Text(endTime == null
                        ? 'Seleccionar Hora de Fin'
                        : endTime!.format(context)),
                  ),
                  TextFormField(
                    controller: slotsController,
                    decoration: const InputDecoration(labelText: 'Cupos'),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () {
                    if (selectedDate != null &&
                        startTime != null &&
                        endTime != null &&
                        slotsController.text.isNotEmpty) {
                      final date =
                          DateFormat('yyyy-MM-dd').format(selectedDate!);
                      final start = startTime!.format(context);
                      final end = endTime!.format(context);
                      final slots = int.tryParse(slotsController.text) ?? 0;

                      if (slots > 0) {
                        setState(() {
                          disponibilidad.add({
                            'fecha': date,
                            'inicio': start,
                            'fin': end,
                            'cupos': slots,
                          });
                        });
                        Navigator.pop(context);
                      }
                    }
                  },
                  child: const Text('Agregar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _addImageDialog(BuildContext context) {
    final TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        iconColor: Colors.white,
        title: const Text('Agregar imagen',
            style: TextStyle(
                color: Color.fromRGBO(17, 48, 73, 1), fontFamily: 'Poppins')),
        content: TextFormField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Ingresa el link',
            hintStyle: TextStyle(
                color: Color.fromRGBO(17, 48, 73, 1), fontFamily: 'Poppins'),
            prefixIcon: Icon(Icons.link),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    color: Color.fromRGBO(17, 48, 73, 1),
                    fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                setState(() => _images.add(controller.text));
                Navigator.pop(context);
              }
            },
            child: const Text(
              'Agregar',
              style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Color.fromRGBO(17, 48, 73, 1),
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _addPaymentMethod() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String? selectedPaymentMethod;
        final TextEditingController emailController = TextEditingController();
        final TextEditingController nameController = TextEditingController();
        final TextEditingController idController = TextEditingController();
        final TextEditingController numberController = TextEditingController();
        final TextEditingController bankController = TextEditingController();

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Agregar Método de Pago'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedPaymentMethod,
                    decoration:
                        const InputDecoration(labelText: 'Método de Pago'),
                    items: [
                      'Pago móvil',
                      'Zelle',
                      'Zinli',
                      'Binance',
                      'Efectivo',
                      'Gratis'
                    ]
                        .map((method) => DropdownMenuItem<String>(
                              value: method,
                              child: Text(method),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedPaymentMethod = value;
                      });
                    },
                  ),
                  if (selectedPaymentMethod == 'Zelle' ||
                      selectedPaymentMethod == 'Zinli' ||
                      selectedPaymentMethod == 'Binance') ...[
                    TextFormField(
                      controller: emailController,
                      decoration: const InputDecoration(labelText: 'Correo'),
                    ),
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                          labelText: 'Nombre del Beneficiario'),
                    ),
                  ],
                  if (selectedPaymentMethod == 'Pago móvil') ...[
                    TextFormField(
                      controller: idController,
                      decoration: const InputDecoration(labelText: 'Cédula'),
                    ),
                    TextFormField(
                      controller: numberController,
                      decoration: const InputDecoration(labelText: 'Número'),
                    ),
                    TextFormField(
                      controller: bankController,
                      decoration: const InputDecoration(labelText: 'Banco'),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () {
                    if (selectedPaymentMethod != null) {
                      final paymentMethod = {
                        'metodo': selectedPaymentMethod,
                        if (selectedPaymentMethod == 'Zelle' ||
                            selectedPaymentMethod == 'Zinli' ||
                            selectedPaymentMethod == 'Binance') ...{
                          'correo': emailController.text,
                          'nombre': nameController.text,
                        },
                        if (selectedPaymentMethod == 'Pago móvil') ...{
                          'cedula': idController.text,
                          'numero': numberController.text,
                          'banco': bankController.text,
                        },
                      };

                      setState(() {
                        _payments.add(paymentMethod);
                      });

                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Agregar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 243, 248, 255),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Campo para agregar categorías
              const SizedBox(height: 16),
              const Text('Categorías:',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins')),
              Wrap(
                spacing: 8,
                children: _predefinedCategories.map((category) {
                  return FilterChip(
                    backgroundColor: Colors.white,
                    selected: _categories.contains(category),
                    selectedColor: const Color.fromARGB(255, 243, 248, 255),
                    checkmarkColor: const Color.fromRGBO(17, 48, 73, 1),
                    label: Text(category,
                        style: GoogleFonts.poppins(
                            color: const Color.fromRGBO(17, 48, 73, 1))),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _categories.add(category);
                        } else {
                          _categories.remove(category);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              if (_categories.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                ),
              const SizedBox(height: 20),
              // Campo para agregar imágenes
              const Text('Imágenes:',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color.fromRGBO(17, 48, 73, 1),
                      fontFamily: 'Poppins')),
// Visualización de imágenes agregadas
              Wrap(
                spacing: 8,
                children: _images
                    .map((url) => Chip(
                          label: Text(url),
                          deleteIcon: const Icon(Icons.close, size: 18),
                          onDeleted: () => setState(() => _images.remove(url)),
                        ))
                    .toList(),
              ),
// Botón para agregar más imágenes
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                ),
                icon: const Icon(
                  Icons.image,
                  color: Color.fromRGBO(17, 48, 73, 1),
                ),
                label: const Text('Agregar imagen',
                    style: TextStyle(
                        color: Color.fromRGBO(17, 48, 73, 1),
                        fontFamily: 'Poppins')),
                onPressed: () => _addImageDialog(context),
              ),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                    labelText: 'Nombre:',
                    labelStyle: TextStyle(
                        color: Color.fromRGBO(17, 48, 73, 1),
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.bold)),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Ingrese un nombre';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Ubicación:',
                  labelStyle: TextStyle(
                      color: Color.fromRGBO(17, 48, 73, 1),
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.bold),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Ingrese una ubicación';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _placeController,
                decoration: const InputDecoration(
                    labelText: 'Lugar:',
                    labelStyle: TextStyle(
                        color: Color.fromRGBO(17, 48, 73, 1),
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.bold)),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Ingrese el lugar';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _coordinatesController,
                decoration: const InputDecoration(
                    labelText: 'Link de Google maps:',
                    labelStyle: TextStyle(
                        color: Color.fromRGBO(17, 48, 73, 1),
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.bold)),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Ingrese el link de Google maps';
                  }
                  return null;
                },
              ),
              DropdownButtonFormField<String>(
                value: _selectedSupplier,
                decoration: const InputDecoration(
                    labelText: 'Proveedor:',
                    labelStyle: TextStyle(
                        color: Color.fromRGBO(17, 48, 73, 1),
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.bold)),
                items: _suppliers.map((supplier) {
                  return DropdownMenuItem<String>(
                    value: supplier['id'],
                    child: Text(supplier['email']),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedSupplier = value;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return 'Seleccione un proveedor';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                ),
                onPressed: _addPaquete,
                child: const Text('Agregar Paquete',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.bold,
                        color: Color.fromRGBO(17, 48, 73, 1))),
              ),
              ..._paquetes.map((paquete) {
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Precio: \$${paquete['precio']}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text('Descripción: ${paquete['descripcion']}'),
                        Text('Mini descripción: ${paquete['miniDescripcion']}'),
                        const Text('Disponibilidad:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        ...paquete['disponibilidad'].map<Widget>((dispo) {
                          return ListTile(
                            title: Text("${dispo['fecha']}"),
                            subtitle: Text(
                                "${dispo['inicio']} a ${dispo['fin']} - Cupos: ${dispo['cupos']}"),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                ),
                onPressed: _addPaymentMethod,
                child: const Text('Agregar método de pago',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                        color: Color.fromRGBO(17, 48, 73, 1))),
              ),
              ..._payments.map((payment) {
                return ListTile(
                  title: Text(payment['metodo']),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (payment.containsKey('correo'))
                        Text('Correo: ${payment['correo']}'),
                      if (payment.containsKey('nombre'))
                        Text('Nombre: ${payment['nombre']}'),
                      if (payment.containsKey('cedula'))
                        Text('Cédula: ${payment['cedula']}'),
                      if (payment.containsKey('numero'))
                        Text('Número: ${payment['numero']}'),
                      if (payment.containsKey('banco'))
                        Text('Banco: ${payment['banco']}'),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _addDestination,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                ),
                child: const Text('Guardar Destino',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        color: Color.fromRGBO(17, 48, 73, 1),
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
      backgroundColor: const Color.fromARGB(255, 243, 248, 255),
    );
  }
}
