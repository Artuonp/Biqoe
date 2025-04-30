import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ModifyDestinationScreen extends StatefulWidget {
  const ModifyDestinationScreen({super.key});

  @override
  ModifyDestinationScreenState createState() => ModifyDestinationScreenState();
}

class ModifyDestinationScreenState extends State<ModifyDestinationScreen> {
  Future<void> _updateDestination(
      String documentId, Map<String, dynamic> updatedData) async {
    try {
      await FirebaseFirestore.instance
          .collection('destinos')
          .doc(documentId)
          .update(updatedData);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Destino actualizado exitosamente')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar destino: $e')),
        );
      }
    }
  }

  void _showEditDialog(
      String documentId, Map<String, dynamic> destinationData) {
    final formKey = GlobalKey<FormState>();

    // Controladores
    final nombreController =
        TextEditingController(text: destinationData['nombre']);
    final ubicacionController =
        TextEditingController(text: destinationData['ubicacion']);
    final lugarController =
        TextEditingController(text: destinationData['lugar']);
    final supplierController =
        TextEditingController(text: destinationData['supplier']);
    final isHighlighted =
        ValueNotifier<bool>(destinationData['IsHighlighted'] ?? false);
    final coordenadasController =
        TextEditingController(text: destinationData['coordenadas']);
    final imagenesController = TextEditingController(
        text: (destinationData['imagen'] as List<dynamic>?)?.join(', ') ?? '');
    final paquetes =
        List<Map<String, dynamic>>.from(destinationData['paquetes'] ?? []);
    final payments =
        List<Map<String, dynamic>>.from(destinationData['pagos'] ?? []);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Modificar destino',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      color: Color.fromRGBO(17, 48, 73, 1))),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    children: [
                      _buildBasicFields(
                        nombreController,
                        ubicacionController,
                        lugarController,
                        supplierController,
                        isHighlighted,
                        coordenadasController,
                      ),
                      _buildImageEditor(imagenesController, setState),
                      _buildPaqueteEditor(paquetes, setState),
                      _buildPaymentEditor(payments, setState),
                      ValueListenableBuilder<bool>(
                        valueListenable: isHighlighted,
                        builder: (context, value, child) {
                          return SwitchListTile(
                            title: const Text('Destacado'),
                            value: value,
                            onChanged: (bool newValue) =>
                                isHighlighted.value = newValue,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () => _saveChanges(
                    documentId,
                    nombreController,
                    ubicacionController,
                    lugarController,
                    supplierController,
                    isHighlighted,
                    imagenesController,
                    paquetes,
                    coordenadasController,
                    payments, // Agregar el argumento faltante
                  ),
                  child: const Text('Guardar'),
                ),
              ],
              backgroundColor: Colors.white,
            );
          },
        );
      },
    );
  }

  Widget _buildPaqueteEditor(
      List<Map<String, dynamic>> paquetes, StateSetter setStateDialog) {
    return ExpansionTile(
      title: const Text('Paquetes',
          style: TextStyle(
              fontSize: 16,
              fontFamily: 'Poppins',
              color: Color.fromRGBO(17, 48, 73, 1))),
      children: paquetes.asMap().entries.map((entry) {
        final index = entry.key;
        final paquete = entry.value;

        final descripcionController =
            TextEditingController(text: paquete['descripcion']);
        final miniDescripcionController =
            TextEditingController(text: paquete['miniDescripcion']);
        final disponibilidades =
            List<Map<String, dynamic>>.from(paquete['disponibilidad'] ?? []);

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Paquete ${index + 1}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                        color: Color.fromRGBO(17, 48, 73, 1))),
                const SizedBox(height: 8),
                TextFormField(
                  controller: descripcionController,
                  decoration: const InputDecoration(
                    labelText: 'Descripción (Markdown permitido)',
                    labelStyle: TextStyle(
                        fontFamily: 'Poppins',
                        color: Color.fromRGBO(17, 48, 73, 1)),
                  ),
                  maxLines: 5,
                  onChanged: (value) {
                    setStateDialog(() {
                      paquete['descripcion'] = value;
                    });
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: miniDescripcionController,
                  decoration: const InputDecoration(
                    labelText: 'Mini descripción',
                    labelStyle: TextStyle(
                        fontFamily: 'Poppins',
                        color: Color.fromRGBO(17, 48, 73, 1)),
                  ),
                  maxLines: 3,
                  onChanged: (value) {
                    setStateDialog(() {
                      paquete['miniDescripcion'] = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                _buildDisponibilidadEditor(
                    disponibilidades, setStateDialog, paquete),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => _addDisponibilidadDialog(
                      context, disponibilidades, paquete, setStateDialog),
                  child: const Text('Agregar Disponibilidad'),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDisponibilidadEditor(List<Map<String, dynamic>> disponibilidades,
      StateSetter setStateDialog, Map<String, dynamic> paquete) {
    // Inicializar controladores de texto para cada campo de las disponibilidades
    final fechaControllers = disponibilidades
        .map((disponibilidad) =>
            TextEditingController(text: disponibilidad['fecha']))
        .toList();
    final inicioControllers = disponibilidades
        .map((disponibilidad) =>
            TextEditingController(text: disponibilidad['inicio']))
        .toList();
    final finControllers = disponibilidades
        .map((disponibilidad) =>
            TextEditingController(text: disponibilidad['fin']))
        .toList();
    final cuposControllers = disponibilidades
        .map((disponibilidad) =>
            TextEditingController(text: disponibilidad['cupos'].toString()))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: disponibilidades.asMap().entries.map((entry) {
        final index = entry.key;
        final disponibilidad = entry.value;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Disponibilidad ${index + 1}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                        color: Color.fromRGBO(17, 48, 73, 1))),
                const SizedBox(height: 8),
                TextFormField(
                  controller: fechaControllers[index],
                  decoration: const InputDecoration(
                    labelText: 'Fecha (YYYY-MM-DD)',
                    labelStyle: TextStyle(
                        fontFamily: 'Poppins',
                        color: Color.fromRGBO(17, 48, 73, 1)),
                  ),
                  onChanged: (value) {
                    disponibilidad['fecha'] = value;
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: inicioControllers[index],
                  decoration: const InputDecoration(
                    labelText: 'Hora de Inicio (HH:MM AM/PM)',
                    labelStyle: TextStyle(
                        fontFamily: 'Poppins',
                        color: Color.fromRGBO(17, 48, 73, 1)),
                  ),
                  onChanged: (value) {
                    disponibilidad['inicio'] = value;
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: finControllers[index],
                  decoration: const InputDecoration(
                    labelText: 'Hora de Fin (HH:MM AM/PM)',
                    labelStyle: TextStyle(
                        fontFamily: 'Poppins',
                        color: Color.fromRGBO(17, 48, 73, 1)),
                  ),
                  onChanged: (value) {
                    disponibilidad['fin'] = value;
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: cuposControllers[index],
                  decoration: const InputDecoration(
                    labelText: 'Cupos',
                    labelStyle: TextStyle(
                        fontFamily: 'Poppins',
                        color: Color.fromRGBO(17, 48, 73, 1)),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    disponibilidad['cupos'] = int.tryParse(value) ?? 0;
                  },
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    setStateDialog(() {
                      disponibilidades.removeAt(index);
                      paquete['disponibilidad'] = disponibilidades;
                    });
                  },
                  child: const Text('Eliminar Disponibilidad',
                      style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  void _addDisponibilidadDialog(
      BuildContext context,
      List<Map<String, dynamic>> disponibilidades,
      Map<String, dynamic> paquete,
      StateSetter setStateDialog) {
    DateTime? selectedDate;
    TimeOfDay? startTime;
    TimeOfDay? endTime;
    final TextEditingController slotsController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
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
                        setStateDialog(() {
                          // 1) Añadimos a la copia local de disponibilidades
                          disponibilidades.add({
                            'fecha': date,
                            'inicio': start,
                            'fin': end,
                            'cupos': slots,
                          });

                          // 2) Reasignamos esa lista al paquete original
                          paquete['disponibilidad'] =
                              List.from(disponibilidades);
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

  void _addPaymentDialog(BuildContext context,
      List<Map<String, dynamic>> payments, StateSetter setStateDialog) {
    String? selectedPaymentMethod;
    final TextEditingController emailController = TextEditingController();
    final TextEditingController nameController = TextEditingController();
    final TextEditingController idController = TextEditingController();
    final TextEditingController numberController = TextEditingController();
    final TextEditingController bankController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Agregar Método de Pago'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedPaymentMethod,
                decoration: const InputDecoration(labelText: 'Método de Pago'),
                items: ['Pago móvil', 'Zelle', 'Zinli', 'Binance', 'Efectivo']
                    .map((method) => DropdownMenuItem<String>(
                          value: method,
                          child: Text(method),
                        ))
                    .toList(),
                onChanged: (value) {
                  setStateDialog(() {
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

                  setStateDialog(() {
                    payments.add(paymentMethod);
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
  }

  Widget _buildBasicFields(
    TextEditingController nombre,
    TextEditingController ubicacion,
    TextEditingController lugar,
    TextEditingController supplier,
    ValueNotifier<bool> isHighlighted,
    TextEditingController coordenadas,
  ) {
    return Column(
      children: [
        TextFormField(
          controller: nombre,
          decoration: const InputDecoration(
              labelText: 'Nombre',
              labelStyle: TextStyle(
                  fontFamily: 'Poppins', color: Color.fromRGBO(17, 48, 73, 1))),
        ),
        TextFormField(
          controller: ubicacion,
          decoration: const InputDecoration(
              labelText: 'Ubicación',
              labelStyle: TextStyle(
                  fontFamily: 'Poppins', color: Color.fromRGBO(17, 48, 73, 1))),
        ),
        TextFormField(
          controller: lugar,
          decoration: const InputDecoration(
              labelText: 'Lugar',
              labelStyle: TextStyle(
                  fontFamily: 'Poppins', color: Color.fromRGBO(17, 48, 73, 1))),
        ),
        TextFormField(
          controller: supplier,
          decoration: const InputDecoration(
              labelText: 'Supplier',
              labelStyle: TextStyle(
                  fontFamily: 'Poppins', color: Color.fromRGBO(17, 48, 73, 1))),
        ),
        TextFormField(
          controller: coordenadas,
          decoration: const InputDecoration(
              labelText: 'Coordenadas (URL)',
              labelStyle: TextStyle(
                  fontFamily: 'Poppins', color: Color.fromRGBO(17, 48, 73, 1))),
        ),
      ],
    );
  }

  Widget _buildImageEditor(
      TextEditingController controller, StateSetter setStateDialog) {
    final images = controller.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final newImageController = TextEditingController();

    return ExpansionTile(
      title: const Text('Imágenes',
          style: TextStyle(
              fontSize: 16,
              fontFamily: 'Poppins',
              color: Color.fromRGBO(17, 48, 73, 1))),
      children: [
        Column(
          children: [
            // Lista de imágenes existentes
            ...images
                .map((url) => _buildImageRow(url, controller, setStateDialog)),

            // Nuevo campo para agregar imágenes
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: newImageController,
                      decoration: InputDecoration(
                        labelText: 'Nueva imagen',
                        labelStyle: const TextStyle(
                            fontFamily: 'Poppins',
                            color: Color.fromRGBO(17, 48, 73, 1)),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.check_circle,
                              color: Color.fromRGBO(17, 48, 73, 1)),
                          onPressed: () {
                            if (newImageController.text.trim().isNotEmpty) {
                              setStateDialog(() {
                                images.add(newImageController.text.trim());
                                controller.text = images.join(',');
                                newImageController.clear();
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Previsualización de la nueva imagen
            if (newImageController.text.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Image.network(
                  newImageController.text.trim(),
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.broken_image,
                    size: 50,
                    color: Color.fromRGBO(17, 48, 73, 1),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildImageRow(String url, TextEditingController mainController,
      StateSetter setStateDialog) {
    final controller = TextEditingController(text: url);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'URL de imagen',
                labelStyle: const TextStyle(
                    fontFamily: 'Poppins',
                    color: Color.fromRGBO(17, 48, 73, 1)),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check, color: Colors.green),
                      onPressed: () {
                        final newUrl = controller.text.trim();
                        if (newUrl.isNotEmpty) {
                          setStateDialog(() {
                            final index =
                                mainController.text.split(',').indexOf(url);
                            if (index != -1) {
                              final images = mainController.text.split(',');
                              images[index] = newUrl;
                              mainController.text = images.join(',');
                            }
                          });
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete,
                          color: Color.fromRGBO(17, 48, 73, 1)),
                      onPressed: () {
                        setStateDialog(() {
                          final images = mainController.text.split(',');
                          images.remove(url);
                          mainController.text = images.join(',');
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          if (url.isNotEmpty)
            Image.network(
              url,
              width: 50,
              height: 50,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.broken_image,
                size: 30,
                color: Color.fromRGBO(17, 48, 73, 1),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPaymentEditor(
      List<Map<String, dynamic>> payments, StateSetter setStateDialog) {
    // Inicializar controladores de texto para cada campo de los métodos de pago
    final metodoControllers = payments
        .map((payment) => TextEditingController(text: payment['metodo']))
        .toList();
    final correoControllers = payments
        .map((payment) => TextEditingController(text: payment['correo'] ?? ''))
        .toList();
    final nombreControllers = payments
        .map((payment) => TextEditingController(text: payment['nombre'] ?? ''))
        .toList();
    final cedulaControllers = payments
        .map((payment) => TextEditingController(text: payment['cedula'] ?? ''))
        .toList();
    final numeroControllers = payments
        .map((payment) => TextEditingController(text: payment['numero'] ?? ''))
        .toList();
    final bancoControllers = payments
        .map((payment) => TextEditingController(text: payment['banco'] ?? ''))
        .toList();

    return ExpansionTile(
      title: const Text('Métodos de Pago',
          style: TextStyle(
              fontSize: 16,
              fontFamily: 'Poppins',
              color: Color.fromRGBO(17, 48, 73, 1))),
      children: [
        ...payments.asMap().entries.map((entry) {
          final index = entry.key;
          final payment = entry.value;

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Método de Pago ${index + 1}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                          color: Color.fromRGBO(17, 48, 73, 1))),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: metodoControllers[index],
                    decoration: const InputDecoration(
                      labelText: 'Método',
                      labelStyle: TextStyle(
                          fontFamily: 'Poppins',
                          color: Color.fromRGBO(17, 48, 73, 1)),
                    ),
                    onChanged: (value) {
                      payment['metodo'] = value;
                    },
                  ),
                  if (payment['metodo'] == 'Zelle' ||
                      payment['metodo'] == 'Zinli' ||
                      payment['metodo'] == 'Binance') ...[
                    TextFormField(
                      controller: correoControllers[index],
                      decoration: const InputDecoration(
                        labelText: 'Correo',
                        labelStyle: TextStyle(
                            fontFamily: 'Poppins',
                            color: Color.fromRGBO(17, 48, 73, 1)),
                      ),
                      onChanged: (value) {
                        payment['correo'] = value;
                      },
                    ),
                    TextFormField(
                      controller: nombreControllers[index],
                      decoration: const InputDecoration(
                        labelText: 'Nombre del Beneficiario',
                        labelStyle: TextStyle(
                            fontFamily: 'Poppins',
                            color: Color.fromRGBO(17, 48, 73, 1)),
                      ),
                      onChanged: (value) {
                        payment['nombre'] = value;
                      },
                    ),
                  ],
                  if (payment['metodo'] == 'Pago móvil') ...[
                    TextFormField(
                      controller: cedulaControllers[index],
                      decoration: const InputDecoration(
                        labelText: 'Cédula',
                        labelStyle: TextStyle(
                            fontFamily: 'Poppins',
                            color: Color.fromRGBO(17, 48, 73, 1)),
                      ),
                      onChanged: (value) {
                        payment['cedula'] = value;
                      },
                    ),
                    TextFormField(
                      controller: numeroControllers[index],
                      decoration: const InputDecoration(
                        labelText: 'Número',
                        labelStyle: TextStyle(
                            fontFamily: 'Poppins',
                            color: Color.fromRGBO(17, 48, 73, 1)),
                      ),
                      onChanged: (value) {
                        payment['numero'] = value;
                      },
                    ),
                    TextFormField(
                      controller: bancoControllers[index],
                      decoration: const InputDecoration(
                        labelText: 'Banco',
                        labelStyle: TextStyle(
                            fontFamily: 'Poppins',
                            color: Color.fromRGBO(17, 48, 73, 1)),
                      ),
                      onChanged: (value) {
                        payment['banco'] = value;
                      },
                    ),
                  ],
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      setStateDialog(() {
                        payments.removeAt(index);
                      });
                    },
                    child: const Text('Eliminar Método de Pago',
                        style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ),
          );
        }),
        ElevatedButton(
          onPressed: () => _addPaymentDialog(context, payments, setStateDialog),
          child: const Text('Agregar Método de Pago'),
        ),
      ],
    );
  }

  void _saveChanges(
    String documentId,
    TextEditingController nombre,
    TextEditingController ubicacion,
    TextEditingController lugar,
    TextEditingController supplier,
    ValueNotifier<bool> isHighlighted,
    TextEditingController imagenes,
    List<Map<String, dynamic>> paquetes,
    TextEditingController coordenadas,
    List<Map<String, dynamic>> payments, // Agregar los métodos de pago
  ) {
    final updatedData = {
      'nombre': nombre.text,
      'ubicacion': ubicacion.text,
      'lugar': lugar.text,
      'supplier': supplier.text,
      'IsHighlighted': isHighlighted.value,
      'coordenadas': coordenadas.text,
      'imagen': imagenes.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      'paquetes': paquetes,
      'pagos': payments, // Guardar los métodos de pago
    };

    _updateDestination(documentId, updatedData);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 243, 248, 255),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('destinos').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No hay destinos disponibles'));
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final destination = snapshot.data!.docs[index];
              final data = destination.data() as Map<String, dynamic>;

              return Card(
                color: Colors.white,
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  title: Text(data['nombre'],
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          color: Color.fromRGBO(17, 48, 73, 1),
                          fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ubicación: ${data['ubicacion']}',
                          style: const TextStyle(
                              fontFamily: 'Poppins',
                              color: Color.fromRGBO(17, 48, 73, 1))),
                      Text(
                          'Destacado: ${data['IsHighlighted'] ?? false ? 'Sí' : 'No'}',
                          style: const TextStyle(
                              fontFamily: 'Poppins',
                              color: Color.fromRGBO(17, 48, 73, 1))),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _showEditDialog(destination.id, data),
                  ),
                ),
              );
            },
          );
        },
      ),
      backgroundColor: const Color.fromARGB(255, 243, 248, 255),
    );
  }
}
