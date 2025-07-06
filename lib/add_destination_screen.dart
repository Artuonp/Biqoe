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
  final List<String> _images = [];
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _coordinatesController = TextEditingController();
  final TextEditingController _placeController = TextEditingController();
  String? _selectedSupplier;
  List<Map<String, dynamic>> _suppliers = [];
  final List<Map<String, dynamic>> _payments = [];
  final List<Map<String, dynamic>> _paquetes = [];
  bool _isRestaurante = false;
  final Set<String> _cocinaSeleccionada = {};
  final List<String> _predefinedCategories = [
    'Playa',
    'Montaña',
    'Eventos',
    'Ciudad',
    'Extremo',
    'Divertido',
    'Cultura',
    'Bienestar',
    'Talleres',
    'Arte',
    'Restaurantes',
    'Hospedaje',
    'Online',
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
    _placeController.dispose();
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
          return {'id': doc.id, 'email': doc['email']};
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
      if (_selectedSupplier == null) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Por favor seleccione un proveedor')));
        return;
      }
      if (_paquetes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Debe agregar al menos un paquete')));
        return;
      }
      // NUEVA VALIDACIÓN
      if (_isRestaurante && _cocinaSeleccionada.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Si es un restaurante, debe seleccionar al menos un tipo de cocina')));
        return;
      }

      try {
        await FirebaseFirestore.instance
            .collection('destinos')
            .doc(_nameController.text)
            .set({
          'categorias': _categories,
          'imagen': _images,
          'nombre': _nameController.text,
          'ubicacion': _locationController.text,
          'coordenadas': _coordinatesController.text,
          'supplier': _selectedSupplier,
          'pagos': _payments,
          'paquetes': _paquetes,
          'IsHide': false,
          'IsHighlighted': false,
          'lugar': _placeController.text,
          // --- NUEVOS CAMPOS A GUARDAR ---
          'isRestaurante': _isRestaurante,
          'cocina': _cocinaSeleccionada.toList(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Destino agregado exitosamente')));
        }

        _formKey.currentState!.reset();
        _nameController.clear();
        _locationController.clear();
        _coordinatesController.clear();
        _placeController.clear();
        setState(() {
          _selectedSupplier = null;
          _paquetes.clear();
          _payments.clear();
          _images.clear();
          _categories.clear();
          // Limpiar nuevos campos también
          _isRestaurante = false;
          _cocinaSeleccionada.clear();
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error al agregar destino: $e')));
        }
      }
    }
  }

  void _addPaquete() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        // Controladores comunes
        final TextEditingController precioController = TextEditingController();
        final TextEditingController descripcionController =
            TextEditingController();
        final TextEditingController miniDescripcionController =
            TextEditingController();

        // Controladores específicos
        final List<Map<String, dynamic>> disponibilidad = [];
        bool requiereInstrucciones = false;
        // NUEVO: Controlador para los cupos de Tickets y Suscripciones
        final TextEditingController cuposTotalesController =
            TextEditingController();

        String? selectedBookingType;

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Nuevo Paquete'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedBookingType,
                      hint: const Text('Seleccione el tipo de reserva'),
                      onChanged: (String? newValue) {
                        setStateDialog(() {
                          selectedBookingType = newValue;
                        });
                      },
                      items: <String>[
                        'Reserva',
                        'Ticket',
                        'Reserva Flexible',
                        'Suscripción'
                      ].map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                            value: value, child: Text(value));
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    if (selectedBookingType != null) ...[
                      TextFormField(
                        controller: precioController,
                        decoration:
                            const InputDecoration(labelText: 'Precio (€)'),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                      ),
                      TextFormField(
                        controller: descripcionController,
                        decoration: const InputDecoration(
                            labelText: 'Descripción Completa'),
                        maxLines: 3,
                      ),
                      TextFormField(
                        controller: miniDescripcionController,
                        decoration: const InputDecoration(
                            labelText: 'Mini Descripción (General)'),
                        maxLines: 2,
                      ),
                    ],

                    // --- CAMPOS CONDICIONALES ---

                    if (selectedBookingType == 'Reserva')
                      Column(
                        children: [
                          const SizedBox(height: 20),
                          const Text("Disponibilidad (Fecha y Hora)",
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          ElevatedButton(
                            onPressed: () => _addDisponibilidad(
                                context, disponibilidad, setStateDialog),
                            child: const Text('Agregar Disponibilidad'),
                          ),
                          ...disponibilidad.map((dispo) => ListTile(
                                title: Text(
                                    "${dispo['fecha']} - ${dispo['inicio']} a ${dispo['fin']}"),
                                subtitle: Text("Cupos: ${dispo['cupos']}"),
                              )),
                        ],
                      ),

                    if (selectedBookingType == 'Reserva Flexible')
                      SwitchListTile(
                        title: const Text("Requiere Instrucciones"),
                        value: requiereInstrucciones,
                        onChanged: (bool value) {
                          setStateDialog(() {
                            requiereInstrucciones = value;
                          });
                        },
                      ),

                    // NUEVO: Campo para agregar cupos a Tickets y Suscripciones
                    if (selectedBookingType == 'Ticket' ||
                        selectedBookingType == 'Suscripción')
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: TextFormField(
                          controller: cuposTotalesController,
                          decoration: const InputDecoration(
                              labelText: 'Cupos Totales Disponibles'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
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
                    if (selectedBookingType == null ||
                        precioController.text.isEmpty ||
                        descripcionController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text(
                              'Tipo, precio y descripción son obligatorios')));
                      return;
                    }

                    Map<String, dynamic> newPackage = {
                      'numero': _paquetes.length + 1,
                      'tipoDeReserva': selectedBookingType,
                      'precio': double.tryParse(precioController.text) ?? 0.0,
                      'descripcion': descripcionController.text,
                      'miniDescripcion': miniDescripcionController.text,
                    };

                    bool isValid = false;
                    // MODIFICADO: Lógica de guardado para incluir los cupos
                    switch (selectedBookingType) {
                      case 'Reserva':
                        if (disponibilidad.isNotEmpty) {
                          newPackage['disponibilidad'] =
                              List.from(disponibilidad);
                          isValid = true;
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text(
                                  'Debe agregar al menos una disponibilidad para una Reserva.')));
                        }
                        break;
                      case 'Reserva Flexible':
                        newPackage['instrucciones'] = requiereInstrucciones;
                        isValid = true;
                        break;
                      case 'Ticket':
                      case 'Suscripción':
                        if (cuposTotalesController.text.isNotEmpty) {
                          newPackage['cuposDisponibles'] =
                              int.tryParse(cuposTotalesController.text) ?? 0;
                          isValid = true;
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text(
                                  'Debe ingresar los cupos totales para este tipo de paquete.')));
                        }
                        break;
                    }

                    if (isValid) {
                      setState(() {
                        _paquetes.add(newPackage);
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
      List<Map<String, dynamic>> disponibilidad, StateSetter setStateDialog) {
    DateTime? selectedDate;
    TimeOfDay? startTime;
    TimeOfDay? endTime;
    final TextEditingController slotsController = TextEditingController();
    final TextEditingController cantidadController =
        TextEditingController(); // NUEVO

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            return AlertDialog(
              title: const Text('Agregar Disponibilidad'),
              content: SingleChildScrollView(
                // Para evitar overflow
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        final DateTime? pickedDate = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2100));
                        if (pickedDate != null) {
                          dialogSetState(() => selectedDate = pickedDate);
                        }
                      },
                      child: Text(selectedDate == null
                          ? 'Seleccionar Día'
                          : DateFormat('EEEE, dd/MM/yyyy')
                              .format(selectedDate!)),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        final TimeOfDay? pickedStartTime = await showTimePicker(
                            context: context, initialTime: TimeOfDay.now());
                        if (pickedStartTime != null) {
                          dialogSetState(() => startTime = pickedStartTime);
                        }
                      },
                      child: Text(startTime == null
                          ? 'Seleccionar Hora de Inicio'
                          : startTime!.format(context)),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        final TimeOfDay? pickedEndTime = await showTimePicker(
                            context: context, initialTime: TimeOfDay.now());
                        if (pickedEndTime != null) {
                          dialogSetState(() => endTime = pickedEndTime);
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
                    // --- NUEVO CAMPO ---
                    TextFormField(
                      controller: cantidadController,
                      decoration: const InputDecoration(
                          labelText: 'Cantidad (Opcional)'),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar')),
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

                      // Lógica para el nuevo campo opcional
                      final int? cantidad = cantidadController.text.isNotEmpty
                          ? int.tryParse(cantidadController.text)
                          : null;

                      if (slots > 0) {
                        setStateDialog(() {
                          disponibilidad.add({
                            'fecha': date,
                            'inicio': start,
                            'fin': end,
                            'cupos': slots,
                            if (cantidad != null)
                              'cantidad':
                                  cantidad, // Se añade solo si no es nulo
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
        title: const Text('Agregar imagen'),
        content: TextFormField(
          controller: controller,
          decoration: const InputDecoration(
              hintText: 'Ingresa el link', prefixIcon: Icon(Icons.link)),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                setState(() => _images.add(controller.text));
                Navigator.pop(context);
              }
            },
            child: const Text('Agregar'),
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
                            value: method, child: Text(method)))
                        .toList(),
                    onChanged: (value) =>
                        setState(() => selectedPaymentMethod = value),
                  ),
                  if (['Zelle', 'Zinli', 'Binance']
                      .contains(selectedPaymentMethod)) ...[
                    TextFormField(
                        controller: emailController,
                        decoration: const InputDecoration(labelText: 'Correo')),
                    TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                            labelText: 'Nombre del Beneficiario')),
                  ],
                  if (selectedPaymentMethod == 'Pago móvil') ...[
                    TextFormField(
                        controller: idController,
                        decoration: const InputDecoration(labelText: 'Cédula')),
                    TextFormField(
                        controller: numberController,
                        decoration: const InputDecoration(labelText: 'Número')),
                    TextFormField(
                        controller: bankController,
                        decoration: const InputDecoration(labelText: 'Banco')),
                  ],
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar')),
                TextButton(
                  onPressed: () {
                    if (selectedPaymentMethod != null) {
                      final paymentMethod = {'metodo': selectedPaymentMethod};
                      if (['Zelle', 'Zinli', 'Binance']
                          .contains(selectedPaymentMethod)) {
                        paymentMethod['correo'] = emailController.text;
                        paymentMethod['nombre'] = nameController.text;
                      } else if (selectedPaymentMethod == 'Pago móvil') {
                        paymentMethod['cedula'] = idController.text;
                        paymentMethod['numero'] = numberController.text;
                        paymentMethod['banco'] = bankController.text;
                      }
                      setState(() => _payments.add(paymentMethod));
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
        title: const Text("Agregar Destino",
            style: TextStyle(
                fontFamily: 'Poppins', color: Color.fromRGBO(17, 48, 73, 1))),
        backgroundColor: const Color.fromARGB(255, 243, 248, 255),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const Text('Categorías:',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins')),
              Wrap(
                spacing: 8,
                children: _predefinedCategories
                    .map((category) => FilterChip(
                          backgroundColor: Colors.white,
                          selected: _categories.contains(category),
                          selectedColor:
                              const Color.fromARGB(255, 243, 248, 255),
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
                        ))
                    .toList(),
              ),
              const SizedBox(height: 20),
              const Text('Imágenes:',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color.fromRGBO(17, 48, 73, 1),
                      fontFamily: 'Poppins')),
              Wrap(
                spacing: 8,
                children: _images
                    .map((url) => Chip(
                          label: Text(url, overflow: TextOverflow.ellipsis),
                          deleteIcon: const Icon(Icons.close, size: 18),
                          onDeleted: () => setState(() => _images.remove(url)),
                        ))
                    .toList(),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
                icon: const Icon(Icons.image,
                    color: Color.fromRGBO(17, 48, 73, 1)),
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
                validator: (value) =>
                    value == null || value.isEmpty ? 'Ingrese un nombre' : null,
              ),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                    labelText: 'Ubicación:',
                    labelStyle: TextStyle(
                        color: Color.fromRGBO(17, 48, 73, 1),
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.bold)),
                validator: (value) => value == null || value.isEmpty
                    ? 'Ingrese una ubicación'
                    : null,
              ),
              TextFormField(
                controller: _placeController,
                decoration: const InputDecoration(
                    labelText: 'Lugar:',
                    labelStyle: TextStyle(
                        color: Color.fromRGBO(17, 48, 73, 1),
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.bold)),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Ingrese el lugar' : null,
              ),
              TextFormField(
                controller: _coordinatesController,
                decoration: const InputDecoration(
                    labelText: 'Link de Google maps:',
                    labelStyle: TextStyle(
                        color: Color.fromRGBO(17, 48, 73, 1),
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.bold)),
                validator: (value) => value == null || value.isEmpty
                    ? 'Ingrese el link de Google maps'
                    : null,
              ),
              DropdownButtonFormField<String>(
                value: _selectedSupplier,
                decoration: const InputDecoration(
                    labelText: 'Proveedor:',
                    labelStyle: TextStyle(
                        color: Color.fromRGBO(17, 48, 73, 1),
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.bold)),
                items: _suppliers
                    .map((supplier) => DropdownMenuItem<String>(
                          value: supplier['id'],
                          child: Text(supplier['email']),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => _selectedSupplier = value),
                validator: (value) =>
                    value == null ? 'Seleccione un proveedor' : null,
              ),
              const SizedBox(height: 20),
              SwitchListTile(
                title: const Text('¿Es un restaurante?',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.bold,
                        color: Color.fromRGBO(17, 48, 73, 1))),
                value: _isRestaurante,
                onChanged: (bool value) {
                  setState(() {
                    _isRestaurante = value;
                    if (!value) {
                      // Si se desactiva, se limpian los filtros de cocina seleccionados
                      _cocinaSeleccionada.clear();
                    }
                  });
                },
                activeColor: const Color.fromRGBO(17, 48, 73, 1),
              ),

              // 2. Sección de filtros de cocina (aparece condicionalmente)
              if (_isRestaurante) _buildCocinaFilterSection(),

              // ----------------------------------------

              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
                onPressed: _addPaquete,
                child: const Text('Agregar Paquete',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.bold,
                        color: Color.fromRGBO(17, 48, 73, 1))),
              ),
              // MODIFICADO: Muestra la información del paquete según su tipo, incluyendo los cupos.
              ..._paquetes.map((paquete) {
                Widget subtitle;
                switch (paquete['tipoDeReserva']) {
                  case 'Reserva Flexible':
                    subtitle = Text(
                        'Pase Flexible - Requiere Instrucciones: ${paquete['instrucciones'] ? 'Sí' : 'No'}');
                    break;
                  case 'Ticket':
                    subtitle = Text(
                        'Tipo: Ticket - Cupos: ${paquete['cuposDisponibles']}');
                    break;
                  case 'Suscripción':
                    subtitle = Text(
                        'Tipo: Suscripción - Cupos: ${paquete['cuposDisponibles']}');
                    break;
                  case 'Reserva':
                  default:
                    subtitle = Text(
                        'Reserva con Fecha y Hora (${paquete['disponibilidad']?.length ?? 0} disponibilidades)');
                    break;
                }
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: ListTile(
                    title: Text(
                        'Paquete ${paquete['numero']}: ${paquete['miniDescripcion']} - €${paquete['precio']}'),
                    subtitle: subtitle,
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _paquetes.remove(paquete);
                          for (int i = 0; i < _paquetes.length; i++) {
                            _paquetes[i]['numero'] = i + 1;
                          }
                        });
                      },
                    ),
                  ),
                );
              }),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
                onPressed: _addPaymentMethod,
                child: const Text('Agregar método de pago',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                        color: Color.fromRGBO(17, 48, 73, 1))),
              ),
              ..._payments.map((payment) => ListTile(
                    title: Text(payment['metodo']),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () =>
                          setState(() => _payments.remove(payment)),
                    ),
                  )),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _addDestination,
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16)),
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

  Widget _buildCocinaFilterSection() {
    const Map<String, List<String>> categoriasCocina = {
      'Por País': [
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
      'Por Región': [
        'Mediterránea',
        'Asiática',
        'Latinoamericana',
        'Europea del este',
        'Norteafricana',
        'Caribeña',
        'Sudamericana'
      ],
      'Por Ingrediente Principal': ['Mariscos', 'Carnes', 'Vegetales'],
      'Por Estilo': [
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
        'Deconstrucción'
      ],
      'Por Momento': ['Desayuno', 'Brunch', 'Almuerzo', 'Cena'],
      'Por Dieta': [
        'Sin gluten',
        'Sin lactosa',
        'Keto',
        'Paleo',
        'Halal',
        'Kosher'
      ],
    };

    return Container(
      margin: const EdgeInsets.only(top: 16.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Tipos de Cocina",
              style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color.fromRGBO(17, 48, 73, 1))),
          const Divider(),
          ...categoriasCocina.entries.map((entry) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
                  child: Text(entry.key,
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                ),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 4.0,
                  children: entry.value.map((cocina) {
                    return FilterChip(
                      label: Text(cocina),
                      selected: _cocinaSeleccionada.contains(cocina),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _cocinaSeleccionada.add(cocina);
                          } else {
                            _cocinaSeleccionada.remove(cocina);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}
