import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HighlitedOrderScreen extends StatefulWidget {
  const HighlitedOrderScreen({super.key});

  @override
  State<HighlitedOrderScreen> createState() => _HighlitedOrderScreenState();
}

class _HighlitedOrderScreenState extends State<HighlitedOrderScreen> {
  final Map<String, TextEditingController> _controllers = {};

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _guardarOrden(String id, String valueText) async {
    final value = int.tryParse(valueText);
    if (value != null) {
      await FirebaseFirestore.instance
          .collection('destinos')
          .doc(id)
          .update({'highlightOrder': value});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Orden actualizado'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ordenar Destacados'),
        backgroundColor: const Color.fromRGBO(17, 48, 73, 1),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('destinos')
            .where('IsHighlighted', isEqualTo: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          docs.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aOrder = aData['highlightOrder'] is int
                ? aData['highlightOrder']
                : 99999;
            final bOrder = bData['highlightOrder'] is int
                ? bData['highlightOrder']
                : 99999;
            return aOrder.compareTo(bOrder);
          });
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final name = doc['nombre'] ?? 'Sin nombre';
              final order =
                  (doc.data() as Map<String, dynamic>)['highlightOrder']
                          ?.toString() ??
                      '';
              final id = doc.id;

              _controllers.putIfAbsent(
                  id, () => TextEditingController(text: order));

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 60,
                        child: TextField(
                          controller: _controllers[id],
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Orden',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          _guardarOrden(id, _controllers[id]!.text);
                        },
                        child: const Text('Guardar'),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
