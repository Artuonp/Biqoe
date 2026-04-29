import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/supplier/create_event/create_event_screen.dart';

const Color kPrimary = Color.fromRGBO(17, 48, 73, 1);
const Color kBg = Color(0xFFF3F7FE);

// ─────────────────────────────────────────────────────────────────────────────
// Pantalla principal: lista de TODAS las actividades con búsqueda
// ─────────────────────────────────────────────────────────────────────────────
class AdminActivitiesScreen extends StatefulWidget {
  const AdminActivitiesScreen({super.key});

  @override
  State<AdminActivitiesScreen> createState() => _AdminActivitiesScreenState();
}

class _AdminActivitiesScreenState extends State<AdminActivitiesScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  // Cache de nombres de proveedores  {uid: name}
  final Map<String, String> _supplierNames = {};

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // Obtiene el nombre del proveedor desde cache o Firestore
  Future<String> _getSupplierName(String supplierId) async {
    if (supplierId.isEmpty) return 'Sin proveedor';
    if (_supplierNames.containsKey(supplierId)) {
      return _supplierNames[supplierId]!;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(supplierId)
          .get();
      final name = doc.data()?['name']?.toString() ?? supplierId;
      _supplierNames[supplierId] = name;
      return name;
    } catch (_) {
      return supplierId;
    }
  }

  Future<void> _deleteActivity(String docId, String nombre) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Eliminar actividad',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold, color: kPrimary)),
        content: Text(
            '¿Seguro que deseas eliminar "$nombre"?\nEsta acción no se puede deshacer.',
            style: GoogleFonts.poppins(fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancelar',
                  style: GoogleFonts.poppins(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Eliminar',
                style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await FirebaseFirestore.instance.collection('destinos').doc(docId).delete();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Actividad eliminada',
              style: GoogleFonts.poppins(color: Colors.white)),
          backgroundColor: kPrimary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Actividades',
            style: GoogleFonts.poppins(
                color: kPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kPrimary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('Nueva actividad',
            style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.w600)),
        onPressed: () async {
          final buildContext = context;
          // Selector de proveedor antes de crear
          final supplierId = await _showProviderPickerDialog(buildContext);
          if (supplierId == null || !buildContext.mounted) return;
          Navigator.push(
            buildContext,
            MaterialPageRoute(
              builder: (_) => CreateEventScreen(supplierId: supplierId),
            ),
          );
        },
      ),
      body: Column(
        children: [
          // ── Barra de búsqueda ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Buscar por nombre o proveedor…',
                hintStyle:
                    GoogleFonts.poppins(fontSize: 13, color: Colors.grey),
                prefixIcon: const Icon(Icons.search, color: kPrimary, size: 20),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close,
                            color: Colors.grey, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        })
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none),
              ),
            ),
          ),

          // ── Lista de actividades ───────────────────────────────────────
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('destinos')
                  .orderBy('nombre')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: kPrimary));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.explore_off,
                            size: 60, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text('No hay actividades',
                            style: GoogleFonts.poppins(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                final allDocs = snapshot.data!.docs;

                return FutureBuilder<List<_ActivityItem>>(
                  future: _buildItems(allDocs),
                  builder: (context, itemSnap) {
                    if (!itemSnap.hasData) {
                      return const Center(
                          child: CircularProgressIndicator(color: kPrimary));
                    }
                    final items = itemSnap.data!.where((item) {
                      if (_query.isEmpty) return true;
                      return item.nombre.toLowerCase().contains(_query) ||
                          item.supplierName.toLowerCase().contains(_query);
                    }).toList();

                    if (items.isEmpty) {
                      return Center(
                        child: Text('Sin resultados para "$_query"',
                            style: GoogleFonts.poppins(color: Colors.grey)),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                      itemCount: items.length,
                      itemBuilder: (ctx, i) => _ActivityCard(
                          item: items[i],
                          onDelete: () {
                            _deleteActivity(items[i].docId, items[i].nombre);
                          },
                          onEdit: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CreateEventScreen(
                                  eventToEdit: items[i].data,
                                  eventId: items[i].docId,
                                  supplierId: items[i].supplierId,
                                ),
                              ),
                            );
                          }),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<List<_ActivityItem>> _buildItems(
      List<QueryDocumentSnapshot> docs) async {
    final List<_ActivityItem> result = [];
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final supplierId =
          data['supplierId']?.toString() ?? data['supplier']?.toString() ?? '';
      final supplierName = await _getSupplierName(supplierId);
      result.add(_ActivityItem(
        docId: doc.id,
        data: data,
        nombre: data['nombre']?.toString() ?? 'Sin nombre',
        supplierId: supplierId,
        supplierName: supplierName,
        imageUrl: _extractFirstImage(data),
        isHighlighted: data['IsHighlighted'] == true,
        highlightOrder:
            data['highlightOrder'] is int ? data['highlightOrder'] : 99999,
        // Si el campo no existe se asume true (visible por defecto)
        isInApp: data['isInApp'] != false,
      ));
    }
    return result;
  }

  String _extractFirstImage(Map<String, dynamic> data) {
    final imgs = data['imagenes'];
    if (imgs is List && imgs.isNotEmpty) return imgs[0].toString();
    final img = data['imagen'];
    if (img is List && img.isNotEmpty) return img[0].toString();
    if (img is String) return img;
    return '';
  }
}

// ── Selector de proveedor para asignar al crear ───────────────────────────────
Future<String?> _showProviderPickerDialog(BuildContext context) async {
  final ctrl = TextEditingController();
  String query = '';

  return showDialog<String>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(builder: (ctx, setS) {
        return Dialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Seleccionar proveedor',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: kPrimary)),
                const SizedBox(height: 12),
                TextField(
                  controller: ctrl,
                  onChanged: (v) => setS(() => query = v.toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Buscar por nombre…',
                    hintStyle:
                        GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                    prefixIcon:
                        const Icon(Icons.search, color: kPrimary, size: 18),
                    filled: true,
                    fillColor: const Color(0xFFF3F7FE),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 300,
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('usuarios')
                        .where('isSupplier', isEqualTo: true)
                        .snapshots(),
                    builder: (context, snap) {
                      if (!snap.hasData) {
                        return const Center(
                            child: CircularProgressIndicator(color: kPrimary));
                      }
                      final docs = snap.data!.docs.where((d) {
                        if (query.isEmpty) return true;
                        final n = (d.data() as Map)['name']
                                ?.toString()
                                .toLowerCase() ??
                            '';
                        return n.contains(query);
                      }).toList();

                      if (docs.isEmpty) {
                        return Center(
                            child: Text('Sin resultados',
                                style:
                                    GoogleFonts.poppins(color: Colors.grey)));
                      }
                      return ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (c, i) {
                          final d = docs[i].data() as Map<String, dynamic>;
                          final img = d['imagen']?.toString() ?? '';
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 2),
                            leading: CircleAvatar(
                              backgroundColor: kPrimary.withValues(alpha: 0.1),
                              backgroundImage:
                                  img.isNotEmpty ? NetworkImage(img) : null,
                              child: img.isEmpty
                                  ? Text(
                                      (d['name']?.toString() ?? '?')
                                          .substring(0, 1)
                                          .toUpperCase(),
                                      style: const TextStyle(
                                          color: kPrimary,
                                          fontWeight: FontWeight.bold))
                                  : null,
                            ),
                            title: Text(d['name']?.toString() ?? 'Sin nombre',
                                style: GoogleFonts.poppins(
                                    fontSize: 13, fontWeight: FontWeight.w600)),
                            subtitle: Text(d['email']?.toString() ?? '',
                                style: GoogleFonts.poppins(
                                    fontSize: 11, color: Colors.grey)),
                            onTap: () => Navigator.pop(ctx, docs[i].id),
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancelar',
                      style: GoogleFonts.poppins(color: Colors.grey)),
                ),
              ],
            ),
          ),
        );
      });
    },
  );
}

// ── Modelo de item ────────────────────────────────────────────────────────────
class _ActivityItem {
  final String docId;
  final Map<String, dynamic> data;
  final String nombre;
  final String supplierId;
  final String supplierName;
  final String imageUrl;
  final bool isHighlighted;
  final int highlightOrder;
  // isInApp: true o sin campo → visible; false → oculta en la app
  final bool isInApp;

  _ActivityItem({
    required this.docId,
    required this.data,
    required this.nombre,
    required this.supplierId,
    required this.supplierName,
    required this.imageUrl,
    required this.isHighlighted,
    required this.highlightOrder,
    required this.isInApp,
  });
}

// ── Card de actividad ─────────────────────────────────────────────────────────
class _ActivityCard extends StatefulWidget {
  final _ActivityItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ActivityCard(
      {required this.item, required this.onEdit, required this.onDelete});

  @override
  State<_ActivityCard> createState() => _ActivityCardState();
}

class _ActivityCardState extends State<_ActivityCard> {
  late bool _isInApp;
  bool _togglingInApp = false;

  @override
  void initState() {
    super.initState();
    _isInApp = widget.item.isInApp;
  }

  Future<void> _toggleIsInApp(bool value) async {
    setState(() {
      _isInApp = value;
      _togglingInApp = true;
    });
    try {
      await FirebaseFirestore.instance
          .collection('destinos')
          .doc(widget.item.docId)
          .update({'isInApp': value});
    } catch (e) {
      // Revertir si falla
      if (mounted) setState(() => _isInApp = !value);
      debugPrint('Error actualizando isInApp: $e');
    } finally {
      if (mounted) setState(() => _togglingInApp = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          // ── Fila principal ───────────────────────────────────────────
          Row(
            children: [
              // Imagen
              ClipRRect(
                borderRadius:
                    const BorderRadius.horizontal(left: Radius.circular(16)),
                child: SizedBox(
                  width: 90,
                  height: 90,
                  child: widget.item.imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: widget.item.imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (c, u) =>
                              Container(color: Colors.grey[100]),
                          errorWidget: (c, u, e) =>
                              Container(color: Colors.grey[200]))
                      : Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.image_not_supported,
                              color: Colors.grey)),
                ),
              ),

              // Info
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nombre actividad
                      Text(widget.item.nombre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: kPrimary)),
                      const SizedBox(height: 3),
                      // Nombre proveedor
                      Row(children: [
                        const Icon(Icons.person_outline,
                            size: 12, color: Colors.grey),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(widget.item.supplierName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                  fontSize: 11, color: Colors.grey[600])),
                        ),
                      ]),
                      const SizedBox(height: 6),
                      // Badges
                      Row(children: [
                        if (widget.item.isHighlighted) ...[
                          _Badge(
                              label:
                                  'Destacado #${widget.item.highlightOrder == 99999 ? '–' : widget.item.highlightOrder}',
                              color: Colors.amber),
                          const SizedBox(width: 6),
                        ],
                        _Badge(
                            label: (widget.item.data['status']?.toString() ??
                                        'active') ==
                                    'active'
                                ? 'Activo'
                                : 'Inactivo',
                            color: (widget.item.data['status'] ?? 'active') ==
                                    'active'
                                ? Colors.green
                                : Colors.grey),
                      ]),
                    ],
                  ),
                ),
              ),

              // Botones de acción
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    tooltip: 'Editar',
                    icon: const Icon(Icons.edit_outlined,
                        color: kPrimary, size: 20),
                    onPressed: widget.onEdit,
                  ),
                  IconButton(
                    tooltip: 'Eliminar',
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.red, size: 20),
                    onPressed: widget.onDelete,
                  ),
                ],
              ),
              const SizedBox(width: 4),
            ],
          ),

          // ── Franja inferior: switch isInApp ──────────────────────────
          Container(
            decoration: BoxDecoration(
              color:
                  _isInApp ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(16)),
              border: Border(
                top: BorderSide(
                  color: _isInApp
                      ? Colors.green.withValues(alpha: 0.2)
                      : Colors.orange.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Row(
              children: [
                Icon(
                  _isInApp
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 15,
                  color: _isInApp ? Colors.green[700] : Colors.orange[700],
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    _isInApp ? 'Visible en la app' : 'Oculta en la app',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _isInApp ? Colors.green[700] : Colors.orange[700],
                    ),
                  ),
                ),
                if (_togglingInApp)
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: kPrimary),
                  )
                else
                  Transform.scale(
                    scale: 0.82,
                    child: Switch(
                      value: _isInApp,
                      onChanged: _toggleIsInApp,
                      activeThumbColor: Colors.green[700],
                      inactiveThumbColor: Colors.orange[400],
                      inactiveTrackColor: Colors.orange.withValues(alpha: 0.3),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 0.8)),
      child: Text(label,
          style: GoogleFonts.poppins(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: color.withValues(alpha: 0.85))),
    );
  }
}
