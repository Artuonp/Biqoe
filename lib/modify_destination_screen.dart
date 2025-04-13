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
    final pagosController = TextEditingController(
        text: _formatPagos(destinationData['pagos'] as List<dynamic>?));
    final paquetesController = TextEditingController(
        text: _formatPaquetes(destinationData['paquetes'] as List<dynamic>?));

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
                        _buildPaymentEditor(documentId, pagosController),
                        _buildPackageEditor(documentId, paquetesController),
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
                      pagosController,
                      paquetesController,
                      coordenadasController,
                    ),
                    child: const Text('Guardar'),
                  ),
                ],
                backgroundColor: Colors.white);
          },
        );
      },
    );
  }

  void _showAddPaymentMethodDialog(
      String documentId, TextEditingController controller) {
    String selectedMethod = 'Pago móvil';
    final TextEditingController field1Controller = TextEditingController();
    final TextEditingController field2Controller = TextEditingController();
    final TextEditingController field3Controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Agregar Método de Pago'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedMethod,
                      items: [
                        'Pago móvil',
                        'Zelle',
                        'Zinli',
                        'Binance',
                        'Efectivo'
                      ]
                          .map((method) => DropdownMenuItem(
                                value: method,
                                child: Text(method),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setStateDialog(() {
                          selectedMethod = value!;
                          // Limpiar los campos al cambiar el tipo
                          field1Controller.clear();
                          field2Controller.clear();
                          field3Controller.clear();
                        });
                      },
                      decoration:
                          const InputDecoration(labelText: 'Tipo de Pago'),
                    ),
                    const SizedBox(height: 12),
                    if (selectedMethod == 'Pago móvil') ...[
                      TextFormField(
                        controller: field1Controller,
                        decoration: const InputDecoration(labelText: 'Cédula'),
                      ),
                      TextFormField(
                        controller: field2Controller,
                        decoration: const InputDecoration(labelText: 'Número'),
                        keyboardType: TextInputType.phone,
                      ),
                      TextFormField(
                        controller: field3Controller,
                        decoration: const InputDecoration(labelText: 'Banco'),
                      ),
                    ] else if (selectedMethod == 'Zelle' ||
                        selectedMethod == 'Zinli' ||
                        selectedMethod == 'Binance') ...[
                      TextFormField(
                        controller: field1Controller,
                        decoration: const InputDecoration(labelText: 'Correo'),
                        keyboardType: TextInputType.emailAddress,
                      ),
                    ],
                    // Para Efectivo, no se muestran campos.
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () async {
                    // Obtenemos la lista actual de métodos de pago
                    final payments = _parsePagos(controller.text);
                    // Creamos el nuevo método según el tipo seleccionado
                    Map<String, String> newPayment;
                    if (selectedMethod == 'Pago móvil') {
                      newPayment = {
                        'metodo': selectedMethod,
                        'banco': field3Controller.text,
                        'numero': field2Controller.text,
                        'cedula': field1Controller.text,
                        'correo': '',
                      };
                    } else if (selectedMethod == 'Zelle' ||
                        selectedMethod == 'Zinli' ||
                        selectedMethod == 'Binance') {
                      newPayment = {
                        'metodo': selectedMethod,
                        'banco': '',
                        'numero': '',
                        'cedula': '',
                        'correo': field1Controller.text,
                      };
                    } else {
                      // Efectivo
                      newPayment = {
                        'metodo': selectedMethod,
                        'banco': '',
                        'numero': '',
                        'cedula': '',
                        'correo': '',
                      };
                    }
                    payments.add(newPayment);
                    // Actualizamos el controlador con el nuevo formato
                    controller.text = _formatPagos(payments);
                    // Actualizamos Firestore de inmediato
                    await FirebaseFirestore.instance
                        .collection('destinos')
                        .doc(documentId)
                        .update({
                      'pagos': payments,
                    });
                    if (context.mounted) {
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
      String documentId, TextEditingController controller) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, child) {
        final payments = _parsePagos(value.text);
        return ExpansionTile(
          title: const Text('Métodos de Pago', style: TextStyle(fontSize: 16)),
          children: [
            Column(
              children: [
                ...payments.asMap().entries.map((entry) {
                  final index = entry.key;
                  final payment = entry.value;
                  return Card(
                    margin: const EdgeInsets.all(4),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        children: [
                          DropdownButtonFormField<String>(
                            value: payment['metodo'],
                            items: [
                              'Pago móvil',
                              'Zelle',
                              'Zinli',
                              'Binance',
                              'Efectivo'
                            ]
                                .map((e) => DropdownMenuItem<String>(
                                      value: e,
                                      child: Text(e),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              payments[index]['metodo'] = value;
                              controller.text = _formatPagos(payments);
                            },
                            decoration:
                                const InputDecoration(labelText: 'Método'),
                          ),
                          if (payment['metodo'] == 'Pago móvil') ...[
                            TextFormField(
                              initialValue: payment['banco']?.toString(),
                              decoration:
                                  const InputDecoration(labelText: 'Banco'),
                              onChanged: (value) {
                                payments[index]['banco'] = value;
                                controller.text = _formatPagos(payments);
                              },
                            ),
                            TextFormField(
                              initialValue: payment['numero']?.toString(),
                              decoration:
                                  const InputDecoration(labelText: 'Número'),
                              keyboardType: TextInputType.phone,
                              onChanged: (value) {
                                payments[index]['numero'] = value;
                                controller.text = _formatPagos(payments);
                              },
                            ),
                            TextFormField(
                              initialValue: payment['cedula']?.toString(),
                              decoration:
                                  const InputDecoration(labelText: 'Cédula'),
                              keyboardType: TextInputType.phone,
                              onChanged: (value) {
                                payments[index]['cedula'] = value;
                                controller.text = _formatPagos(payments);
                              },
                            ),
                          ],
                          if (payment['metodo'] == 'Zelle' ||
                              payment['metodo'] == 'Zinli' ||
                              payment['metodo'] == 'Binance') ...[
                            TextFormField(
                              initialValue: payment['correo']?.toString(),
                              decoration:
                                  const InputDecoration(labelText: 'Correo'),
                              keyboardType: TextInputType.emailAddress,
                              onChanged: (value) {
                                payments[index]['correo'] = value;
                                controller.text = _formatPagos(payments);
                              },
                            ),
                            TextFormField(
                              initialValue: payment['nombre']?.toString(),
                              decoration:
                                  const InputDecoration(labelText: 'Nombre'),
                              onChanged: (value) {
                                payments[index]['nombre'] = value;
                                controller.text = _formatPagos(payments);
                              },
                            ),
                          ],
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () async {
                              // Eliminamos el método de pago de la lista.
                              payments.removeAt(index);
                              // Actualizamos el texto del controlador.
                              controller.text = _formatPagos(payments);
                              // Actualizamos Firestore.
                              await FirebaseFirestore.instance
                                  .collection('destinos')
                                  .doc(documentId)
                                  .update({
                                'pagos': payments,
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                ElevatedButton.icon(
                  icon: const Icon(Icons.payment),
                  label: const Text('Agregar Método de Pago'),
                  onPressed: () {
                    _showAddPaymentMethodDialog(documentId, controller);
                  },
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildPackageEditor(
      String documentId, TextEditingController controller) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, child) {
        final packages = _parsePaquetes(value.text);
        return ExpansionTile(
          title: const Text('Paquetes', style: TextStyle(fontSize: 16)),
          children: [
            Column(
              children: [
                ...packages.asMap().entries.map((entry) {
                  final index = entry.key;
                  final package = entry.value;
                  return Card(
                    margin: const EdgeInsets.all(4),
                    child: ExpansionTile(
                      title: Text('Paquete ${index + 1}'),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            children: [
                              // Campo de descripción con soporte para Markdown y múltiples líneas
                              TextFormField(
                                initialValue:
                                    package['descripcion']?.toString(),
                                decoration: const InputDecoration(
                                  labelText: 'Descripción (Markdown soportado)',
                                ),
                                maxLines: null,
                                keyboardType: TextInputType.multiline,
                                onChanged: (value) {
                                  packages[index]['descripcion'] = value;
                                  controller.text = _formatPaquetes(packages);
                                  FirebaseFirestore.instance
                                      .collection('destinos')
                                      .doc(documentId)
                                      .update({'paquetes': packages});
                                },
                              ),
                              // Nuevo campo para mini descripción
                              TextFormField(
                                initialValue:
                                    package['miniDescripcion']?.toString(),
                                decoration: const InputDecoration(
                                  labelText: 'Mini Descripción',
                                ),
                                maxLines: null,
                                keyboardType: TextInputType.multiline,
                                onChanged: (value) {
                                  packages[index]['miniDescripcion'] = value;
                                  controller.text = _formatPaquetes(packages);
                                  FirebaseFirestore.instance
                                      .collection('destinos')
                                      .doc(documentId)
                                      .update({'paquetes': packages});
                                },
                              ),
                              TextFormField(
                                initialValue: package['precio']?.toString(),
                                decoration:
                                    const InputDecoration(labelText: 'Precio'),
                                keyboardType: TextInputType.number,
                                onChanged: (value) {
                                  packages[index]['precio'] =
                                      double.tryParse(value) ?? 0;
                                  controller.text = _formatPaquetes(packages);
                                  FirebaseFirestore.instance
                                      .collection('destinos')
                                      .doc(documentId)
                                      .update({'paquetes': packages});
                                },
                              ),
                              const SizedBox(height: 16),
                              const Text('Disponibilidad:',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              ..._buildDisponibilidadEditor(package, index,
                                  controller, packages, documentId),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () {
                                  setState(() {
                                    packages.removeAt(index);
                                    controller.text = _formatPaquetes(packages);
                                  });
                                  FirebaseFirestore.instance
                                      .collection('destinos')
                                      .doc(documentId)
                                      .update({'paquetes': packages});
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                ElevatedButton.icon(
                  icon: const Icon(Icons.card_giftcard),
                  label: const Text('Agregar Paquete'),
                  onPressed: () {
                    setState(() {
                      // El número del paquete es la cantidad actual + 1.
                      final numeroPaquete = (packages.length + 1).toString();
                      packages.add({
                        'descripcion': 'Nuevo paquete',
                        'miniDescripcion': '',
                        'precio': 0.0,
                        'disponibilidad': [
                          {
                            'fecha':
                                DateFormat('yyyy-MM-dd').format(DateTime.now()),
                            'inicio': '12:00 PM',
                            'fin': '12:00 PM',
                            'cupos': 0,
                          }
                        ],
                        'numero': numeroPaquete,
                      });
                      controller.text = _formatPaquetes(packages);
                    });
                    // Se actualiza directamente en Firestore
                    FirebaseFirestore.instance
                        .collection('destinos')
                        .doc(documentId)
                        .update({'paquetes': packages});
                  },
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  List<Widget> _buildDisponibilidadEditor(
      Map<String, dynamic> package,
      int packageIndex,
      TextEditingController controller,
      List<Map<String, dynamic>> packages,
      String documentId) {
    final disponibilidad = (package['disponibilidad'] is List)
        ? package['disponibilidad'] as List<dynamic>
        : [package['disponibilidad']];

    return [
      ...disponibilidad.asMap().entries.map((entry) {
        final index = entry.key;
        final disp = entry.value as Map<String, dynamic>;
        return ListTile(
          title: Text('Disponibilidad ${index + 1}'),
          subtitle: Column(
            children: [
              TextFormField(
                initialValue: disp['fecha']?.toString(),
                decoration:
                    const InputDecoration(labelText: 'Fecha (YYYY-MM-DD)'),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2100),
                  );
                  if (date != null) {
                    disp['fecha'] = DateFormat('yyyy-MM-dd').format(date);
                    controller.text = _formatPaquetes(packages);
                    FirebaseFirestore.instance
                        .collection('destinos')
                        .doc(documentId)
                        .update({'paquetes': packages});
                  }
                },
              ),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: disp['inicio']?.toString(),
                      decoration:
                          const InputDecoration(labelText: 'Hora Inicio'),
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                        if (time != null && mounted) {
                          // Verificar si el widget sigue montado
                          disp['inicio'] = time.format(context);
                          controller.text = _formatPaquetes(packages);
                          FirebaseFirestore.instance
                              .collection('destinos')
                              .doc(documentId)
                              .update({'paquetes': packages});
                        }
                      },
                    ),
                  ),
                  Expanded(
                    child: TextFormField(
                      initialValue: disp['fin']?.toString(),
                      decoration: const InputDecoration(labelText: 'Hora Fin'),
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                        if (time != null && mounted) {
                          // Verificar si el widget sigue montado
                          disp['fin'] = time.format(context);
                          controller.text = _formatPaquetes(packages);
                          FirebaseFirestore.instance
                              .collection('destinos')
                              .doc(documentId)
                              .update({'paquetes': packages});
                        }
                      },
                    ),
                  ),
                ],
              ),
              TextFormField(
                initialValue: disp['cupos']?.toString(),
                decoration: const InputDecoration(labelText: 'Cupos'),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  disp['cupos'] = int.tryParse(value) ?? 0;
                  controller.text = _formatPaquetes(packages);
                  FirebaseFirestore.instance
                      .collection('destinos')
                      .doc(documentId)
                      .update({'paquetes': packages});
                },
              ),
            ],
          ),
        );
      }),
      ElevatedButton(
        child: const Text('Agregar Disponibilidad'),
        onPressed: () {
          setState(() {
            disponibilidad.add({
              'fecha': DateFormat('yyyy-MM-dd').format(DateTime.now()),
              'inicio': '12:00 PM',
              'fin': '12:00 PM',
              'cupos': 0,
            });
            controller.text = _formatPaquetes(packages);
          });
          FirebaseFirestore.instance
              .collection('destinos')
              .doc(documentId)
              .update({'paquetes': packages});
        },
      ),
    ];
  }

  // ignore: unused_element
  List<Widget> _buildPagoMovilFields(Map<String, dynamic> payment, int index,
      TextEditingController controller, List<Map<String, dynamic>> payments) {
    return [
      TextFormField(
        initialValue: payment['banco']?.toString(),
        decoration: const InputDecoration(labelText: 'Banco'),
        onChanged: (value) {
          payments[index]['banco'] = value;
          controller.text = _formatPagos(payments);
        },
      ),
      TextFormField(
        initialValue: payment['numero']?.toString(),
        decoration: const InputDecoration(labelText: 'Número'),
        keyboardType: TextInputType.phone,
        onChanged: (value) {
          payments[index]['numero'] = value;
          controller.text = _formatPagos(payments);
        },
      ),
      TextFormField(
        initialValue: payment['cedula']?.toString(),
        decoration: const InputDecoration(labelText: 'Cédula'),
        keyboardType: TextInputType.phone,
        onChanged: (value) {
          payments[index]['cedula'] = value;
          controller.text = _formatPagos(payments);
        },
      ),
    ];
  }

  // ignore: unused_element
  List<Widget> _buildTransferenciaFields(
      Map<String, dynamic> payment,
      int index,
      TextEditingController controller,
      List<Map<String, dynamic>> payments) {
    return [
      TextFormField(
        initialValue: payment['correo']?.toString(),
        decoration: const InputDecoration(labelText: 'Correo'),
        keyboardType: TextInputType.emailAddress,
        onChanged: (value) {
          payments[index]['correo'] = value;
          controller.text = _formatPagos(payments);
        },
      ),
      TextFormField(
        initialValue: payment['nombre']?.toString(),
        decoration: const InputDecoration(labelText: 'Nombre'),
        onChanged: (value) {
          payments[index]['nombre'] = value;
          controller.text = _formatPagos(payments);
        },
      ),
    ];
  }

  void _saveChanges(
    String documentId,
    TextEditingController nombre,
    TextEditingController ubicacion,
    TextEditingController lugar,
    TextEditingController supplier,
    ValueNotifier<bool> isHighlighted,
    TextEditingController imagenes,
    TextEditingController pagos,
    TextEditingController paquetes,
    TextEditingController coordenadas,
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
      'pagos': _parsePagos(pagos.text),
      'paquetes': _parsePaquetes(paquetes.text),
    };

    _updateDestination(documentId, updatedData);
    Navigator.pop(context);
  }

  List<Map<String, dynamic>> _parsePagos(String text) {
    if (text.isEmpty) return [];
    return text.split('\n').map((paymentString) {
      final parts = paymentString.split('|');
      return {
        'metodo': parts[0],
        'banco': parts.length > 1 ? parts[1] : '',
        'numero': parts.length > 2 ? parts[2] : '',
        'cedula': parts.length > 3 ? parts[3] : '',
        'correo': parts.length > 4 ? parts[4] : '',
      };
    }).toList();
  }

  String _formatPagos(List<dynamic>? pagos) {
    return pagos
            ?.map((p) =>
                '${p['metodo']}|${p['banco']}|${p['numero']}|${p['cedula']}|${p['correo']}')
            .join('\n') ??
        '';
  }

  List<Map<String, dynamic>> _parsePaquetes(String input) {
    return input
        .split('\n')
        .map<Map<String, dynamic>>((line) {
          final parts = line.split('|');
          if (parts.length < 8) {
            return {}; // Si no se tienen los 8 campos, se descarta.
          }
          return {
            'descripcion': parts[0].trim(),
            'miniDescripcion': parts[1].trim(),
            'disponibilidad': {
              'cupos': int.tryParse(parts[2].trim()) ?? 0,
              'fecha': parts[3].trim(),
              'inicio': parts[4].trim(),
              'fin': parts[5].trim(),
            },
            'numero': parts[6].trim(),
            'precio': double.tryParse(parts[7].trim()) ?? 0.0,
          };
        })
        .where((p) => p.isNotEmpty)
        .toList();
  }

  String _formatPaquetes(List<dynamic>? paquetes) {
    return paquetes
            ?.map<String>((p) {
              if (p is! Map<String, dynamic>) return '';
              // Se asume que 'disponibilidad' es una lista y tomamos el primer elemento
              final disp = p['disponibilidad'];
              if (disp is List<dynamic>) {
                if (disp.isEmpty) return '';
                final firstDisp = disp.first as Map<String, dynamic>?;
                return '${p['descripcion']}|${p['miniDescripcion']}|${firstDisp?['cupos']}|${firstDisp?['fecha']}|${firstDisp?['inicio']}|${firstDisp?['fin']}|${p['numero']}|${p['precio']}';
              } else if (disp is Map<String, dynamic>) {
                return '${p['descripcion']}|${p['miniDescripcion']}|${disp['cupos']}|${disp['fecha']}|${disp['inicio']}|${disp['fin']}|${p['numero']}|${p['precio']}';
              }
              return '';
            })
            .where((str) => str.isNotEmpty)
            .join('\n') ??
        '';
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
