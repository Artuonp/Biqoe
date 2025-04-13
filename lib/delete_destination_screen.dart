import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DeleteDestinationScreen extends StatefulWidget {
  const DeleteDestinationScreen({super.key});

  @override
  DeleteDestinationScreenState createState() => DeleteDestinationScreenState();
}

class DeleteDestinationScreenState extends State<DeleteDestinationScreen> {
  Future<void> _deleteDestination(String documentId) async {
    final context = this
        .context; // Guarda el contexto antes de llamar a la función asíncrona
    try {
      await FirebaseFirestore.instance
          .collection('destinos')
          .doc(documentId)
          .delete();
      if (context.mounted) {
        // Verifica si el contexto sigue montado
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Destino eliminado exitosamente')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        // Verifica si el contexto sigue montado
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar destino: $e')),
        );
      }
    }
  }

  void _confirmDelete(String documentId, String destinationName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Confirmar eliminación',
              style: TextStyle(
                  fontFamily: 'Poppins', color: Color.fromRGBO(17, 48, 73, 1))),
          content: Text(
              '¿Estás seguro de que deseas eliminar el destino "$destinationName"?',
              style: const TextStyle(
                  fontFamily: 'Poppins', color: Color.fromRGBO(17, 48, 73, 1))),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancelar',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      color: Color.fromRGBO(17, 48, 73, 1),
                      fontWeight: FontWeight.bold)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteDestination(documentId);
              },
              child: const Text('Eliminar',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      color: Color.fromRGBO(17, 48, 73, 1),
                      fontWeight: FontWeight.bold)),
            ),
          ],
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
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('destinos').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return const Center(child: Text('Error al cargar destinos'));
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text('No hay destinos disponibles'));
            }

            final destinations = snapshot.data!.docs;

            return ListView.builder(
              itemCount: destinations.length,
              itemBuilder: (context, index) {
                final destination = destinations[index];
                final data = destination.data() as Map<String, dynamic>;
                final documentId = destination.id;

                return Card(
                  color: Colors.white,
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListTile(
                    title: Text(data['nombre'] ?? 'Nombre no disponible',
                        style: const TextStyle(
                            fontFamily: 'Poppins',
                            color: Color.fromRGBO(17, 48, 73, 1))),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete,
                          color: Color.fromRGBO(17, 48, 73, 1)),
                      onPressed: () => _confirmDelete(
                          documentId, data['nombre'] ?? 'Nombre no disponible'),
                    ),
                  ),
                );
              },
            );
          },
        ),
        backgroundColor: const Color.fromARGB(255, 243, 248, 255));
  }
}
