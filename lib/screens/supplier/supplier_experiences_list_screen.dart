import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'create_event/create_event_screen.dart'; // Importar el Wizard

const Color kPrimaryColor = Color.fromRGBO(17, 48, 73, 1);

class SupplierExperiencesListScreen extends StatelessWidget {
  final String supplierId; // <--- AGREGAR ESTO

  // Actualizar constructor
  const SupplierExperiencesListScreen({super.key, required this.supplierId});

  @override
  Widget build(BuildContext context) {
    // ELIMINAR ESTA LÍNEA:
    // final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 243, 248, 255),
      appBar: AppBar(
        title: Text("Mi experiencias",
            style: GoogleFonts.poppins(
                color: kPrimaryColor, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('destinos')
            .where('supplierId',
                isEqualTo: supplierId) // <--- USAR supplierId AQUÍ
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center();
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.layers_clear, size: 60, color: Colors.grey[300]),
                  const SizedBox(height: 10),
                  Text("No tienes experiencias publicadas",
                      style: GoogleFonts.poppins(color: Colors.grey)),
                ],
              ),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final String docId = doc.id;

              // Obtener datos seguros
              final String nombre = data['nombre'] ?? 'Sin nombre';
              final String imagen = (data['imagenes'] != null &&
                      (data['imagenes'] as List).isNotEmpty)
                  ? data['imagenes'][0]
                  : 'https://via.placeholder.com/150'; // Placeholder si no hay foto
              final String status = data['status'] ?? 'active';

              return Card(
                elevation: 0,
                color: Colors.white,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.grey.shade200)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    // AL TOCAR LA TARJETA: Editar (Pasamos el ID también)
                    _navigateToEdit(context, data, docId);
                  },
                  child: Column(
                    children: [
                      // IMAGEN Y ESTADO
                      Stack(
                        children: [
                          Container(
                            height: 150,
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(16)),
                              image: DecorationImage(
                                image: NetworkImage(imagen),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 10,
                            right: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                  color: status == 'active'
                                      ? Colors.green
                                      : Colors.orange,
                                  borderRadius: BorderRadius.circular(20)),
                              child: Text(
                                status == 'active' ? 'Activo' : 'Borrador',
                                style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          )
                        ],
                      ),

                      // INFO
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(nombre,
                                style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: kPrimaryColor)),
                            const SizedBox(height: 10),
                            const Divider(),

                            // BOTONES DE ACCIÓN
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                // EDITAR
                                _ActionButton(
                                  icon: Icons.edit_outlined,
                                  label: "Editar",
                                  color: Color.fromRGBO(17, 48, 73, 1),
                                  onTap: () =>
                                      _navigateToEdit(context, data, docId),
                                ),
                                // ELIMINAR
                                _ActionButton(
                                  icon: Icons.delete_outline,
                                  label: "Eliminar",
                                  color: Color.fromRGBO(17, 48, 73, 1),
                                  onTap: () =>
                                      _confirmDelete(context, docId, nombre),
                                ),
                              ],
                            )
                          ],
                        ),
                      )
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

  void _navigateToEdit(
      BuildContext context, Map<String, dynamic> data, String docId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateEventScreen(
          eventToEdit: data,
          eventId: docId,
          supplierId: supplierId, // <--- PASAR EL ID
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, String docId, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text("¿Eliminar $name?",
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold, color: kPrimaryColor)),
        content: Text(
            "Esta acción no se puede deshacer. Se borrará toda la información del evento.",
            style: GoogleFonts.poppins(color: kPrimaryColor)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancelar",
                  style: GoogleFonts.poppins(color: kPrimaryColor))),
          ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white, // botón blanco
                side: const BorderSide(color: Color.fromRGBO(17, 48, 73, 1)),
                elevation: 0,
              ),
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('destinos')
                    .doc(docId)
                    .delete();
                if (context.mounted) Navigator.pop(context);
              },
              child: Text("Eliminar",
                  style: GoogleFonts.poppins(
                      color: Color.fromRGBO(17, 48, 73, 1),
                      fontWeight: FontWeight.bold)))
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 11, color: color, fontWeight: FontWeight.w500))
          ],
        ),
      ),
    );
  }
}
