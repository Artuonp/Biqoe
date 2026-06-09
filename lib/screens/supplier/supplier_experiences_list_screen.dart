import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'create_event/create_event_screen.dart';

const Color kPrimaryColor = Color.fromRGBO(17, 48, 73, 1);

/// Normaliza un texto a slug URL-safe (sin tildes, sin especiales, sin espacios).
String _toActivitySlug(String text) {
  const Map<String, String> accents = {
    'á': 'a',
    'é': 'e',
    'í': 'i',
    'ó': 'o',
    'ú': 'u',
    'à': 'a',
    'è': 'e',
    'ì': 'i',
    'ò': 'o',
    'ù': 'u',
    'ä': 'a',
    'ë': 'e',
    'ï': 'i',
    'ö': 'o',
    'ü': 'u',
    'â': 'a',
    'ê': 'e',
    'î': 'i',
    'ô': 'o',
    'û': 'u',
    'ã': 'a',
    'õ': 'o',
    'ñ': 'n',
    'Á': 'a',
    'É': 'e',
    'Í': 'i',
    'Ó': 'o',
    'Ú': 'u',
    'À': 'a',
    'È': 'e',
    'Ì': 'i',
    'Ò': 'o',
    'Ù': 'u',
    'Ä': 'a',
    'Ë': 'e',
    'Ï': 'i',
    'Ö': 'o',
    'Ü': 'u',
    'Â': 'a',
    'Ê': 'e',
    'Î': 'i',
    'Ô': 'o',
    'Û': 'u',
    'Ã': 'a',
    'Õ': 'o',
    'Ñ': 'n',
  };
  String result = text;
  accents.forEach((k, v) => result = result.replaceAll(k, v));
  return result
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), '')
      .replaceAll(RegExp(r'[^a-z0-9]'), '');
}

class SupplierExperiencesListScreen extends StatefulWidget {
  final String supplierId;

  const SupplierExperiencesListScreen({super.key, required this.supplierId});

  @override
  State<SupplierExperiencesListScreen> createState() =>
      _SupplierExperiencesListScreenState();
}

class _SupplierExperiencesListScreenState
    extends State<SupplierExperiencesListScreen> {
  String? _providerSlug;

  @override
  void initState() {
    super.initState();
    _loadProviderSlug();
  }

  Future<void> _loadProviderSlug() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(widget.supplierId)
          .get();
      final slug = doc.data()?['slug']?.toString() ?? '';
      if (slug.isNotEmpty && mounted) {
        setState(() => _providerSlug = slug);
      }
    } catch (e) {
      debugPrint('Error cargando slug: $e');
    }
  }

  String _buildShareLink(String activityName) {
    final actSlug = _toActivitySlug(activityName);
    final provSlug = _providerSlug ?? '';
    if (provSlug.isEmpty) return 'Biqoe.com/$actSlug';
    return 'Biqoe.com/$provSlug/$actSlug';
  }

  void _shareLink(BuildContext context, String activityName) {
    final link = _buildShareLink(activityName);
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline,
                color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '¡Link copiado! $link',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ],
        ),
        backgroundColor: kPrimaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 243, 248, 255),
      appBar: AppBar(
        title: Text("Mis actividades",
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
            .where('supplierId', isEqualTo: widget.supplierId)
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

              final String nombre = data['nombre'] ?? 'Sin nombre';
              final String imagen = (data['imagenes'] != null &&
                      (data['imagenes'] as List).isNotEmpty)
                  ? data['imagenes'][0]
                  : 'https://via.placeholder.com/150';
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
                  onTap: () => _navigateToEdit(context, data, docId),
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
                                  color: kPrimaryColor,
                                  onTap: () =>
                                      _navigateToEdit(context, data, docId),
                                ),
                                // COMPARTIR (entre Editar y Eliminar)
                                _ActionButton(
                                  icon: Icons.share_outlined,
                                  label: "Compartir",
                                  color: kPrimaryColor,
                                  onTap: () => _shareLink(context, nombre),
                                ),
                                // ELIMINAR
                                _ActionButton(
                                  icon: Icons.delete_outline,
                                  label: "Eliminar",
                                  color: kPrimaryColor,
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
          supplierId: widget.supplierId,
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
                backgroundColor: Colors.white,
                side: const BorderSide(color: kPrimaryColor),
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
                      color: kPrimaryColor, fontWeight: FontWeight.bold)))
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
