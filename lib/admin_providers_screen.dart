import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

const Color kPrimary = Color.fromRGBO(17, 48, 73, 1);
const Color kBg = Color(0xFFF3F7FE);

// ─────────────────────────────────────────────────────────────────────────────
// Pantalla principal: lista/búsqueda de todos los usuarios (proveedores)
// ─────────────────────────────────────────────────────────────────────────────
class AdminProvidersScreen extends StatefulWidget {
  const AdminProvidersScreen({super.key});

  @override
  State<AdminProvidersScreen> createState() => _AdminProvidersScreenState();
}

class _AdminProvidersScreenState extends State<AdminProvidersScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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
        title: Text('Proveedores / Usuarios',
            style: GoogleFonts.poppins(
                color: kPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
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
                hintText: 'Buscar por correo o nombre…',
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

          // ── Lista ──────────────────────────────────────────────────────
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('usuarios')
                  .orderBy('name')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: kPrimary));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text('No hay usuarios',
                        style: GoogleFonts.poppins(color: Colors.grey)),
                  );
                }

                final docs = snapshot.data!.docs.where((doc) {
                  if (_query.isEmpty) return true;
                  final d = doc.data() as Map<String, dynamic>;
                  final name = d['name']?.toString().toLowerCase() ?? '';
                  final email = d['email']?.toString().toLowerCase() ?? '';
                  return name.contains(_query) || email.contains(_query);
                }).toList();

                if (docs.isEmpty) {
                  return Center(
                    child: Text('Sin resultados para "$_query"',
                        style: GoogleFonts.poppins(color: Colors.grey)),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                  itemCount: docs.length,
                  itemBuilder: (ctx, i) {
                    final data = docs[i].data() as Map<String, dynamic>;
                    return _UserCard(
                      docId: docs[i].id,
                      data: data,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AdminProviderDetailScreen(
                            docId: docs[i].id,
                            data: data,
                          ),
                        ),
                      ),
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
}

// ── Card resumida de usuario ──────────────────────────────────────────────────
class _UserCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  const _UserCard(
      {required this.docId, required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final img = data['imagen']?.toString() ?? '';
    final name = data['name']?.toString() ?? 'Sin nombre';
    final email = data['email']?.toString() ?? '';
    final isSupplier = data['isSupplier'] == true;
    final isAdmin = data['isAdmin'] == true;
    final verified = data['verified'] == true;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3))
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: kPrimary.withValues(alpha: 0.08),
              backgroundImage: img.isNotEmpty ? NetworkImage(img) : null,
              child: img.isEmpty
                  ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(
                          color: kPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 18))
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: kPrimary)),
                      ),
                      if (verified)
                        const Icon(Icons.verified,
                            color: Colors.blueAccent, size: 16),
                    ],
                  ),
                  Text(email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: Colors.grey[600])),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 5,
                    children: [
                      if (isSupplier)
                        _SmallBadge(label: 'Proveedor', color: kPrimary),
                      if (isAdmin)
                        _SmallBadge(label: 'Admin', color: Colors.red),
                      if (!isSupplier && !isAdmin)
                        _SmallBadge(label: 'Cliente', color: Colors.grey),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pantalla de detalle/edición completa del proveedor/usuario
// ─────────────────────────────────────────────────────────────────────────────
class AdminProviderDetailScreen extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;

  const AdminProviderDetailScreen(
      {super.key, required this.docId, required this.data});

  @override
  State<AdminProviderDetailScreen> createState() =>
      _AdminProviderDetailScreenState();
}

class _AdminProviderDetailScreenState extends State<AdminProviderDetailScreen> {
  bool _isSaving = false;
  bool _isUploadingImage = false;

  // Controladores de texto
  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _celularCtrl;
  late TextEditingController _descripcionCtrl;
  late TextEditingController _slugCtrl;
  late TextEditingController _imagenCtrl;
  late TextEditingController
      _assocSupplierCtrl; // associatedSupplierId por correo

  // Booleanos
  late bool _isSupplier;
  late bool _isAdmin;
  late bool _verified;
  late bool _isPrivate;

  // Cloudinary config (igual que step_2_multimedia)
  final String _cloudName = "dovz4vf2e";
  final String _uploadPreset = "ml_default";

  @override
  void initState() {
    super.initState();
    final d = widget.data;
    _nameCtrl = TextEditingController(text: d['name']?.toString() ?? '');
    _emailCtrl = TextEditingController(text: d['email']?.toString() ?? '');
    _celularCtrl = TextEditingController(text: d['celular']?.toString() ?? '');
    _descripcionCtrl =
        TextEditingController(text: d['descripcion']?.toString() ?? '');
    _slugCtrl = TextEditingController(text: d['slug']?.toString() ?? '');
    _imagenCtrl = TextEditingController(text: d['imagen']?.toString() ?? '');
    _assocSupplierCtrl = TextEditingController(
        text: d['associatedSupplierId']?.toString() ?? '');
    _isSupplier = d['isSupplier'] == true;
    _isAdmin = d['isAdmin'] == true;
    _verified = d['verified'] == true;
    _isPrivate = d['isPrivate'] == true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _celularCtrl.dispose();
    _descripcionCtrl.dispose();
    _slugCtrl.dispose();
    _imagenCtrl.dispose();
    _assocSupplierCtrl.dispose();
    super.dispose();
  }

  // ── Guardar cambios en Firestore ─────────────────────────────────────────
  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    try {
      final newSlug = _slugCtrl.text.trim().toLowerCase();
      final oldSlug = widget.data['slug']?.toString().toLowerCase() ?? '';

      // 1. Actualizar documento del usuario
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(widget.docId)
          .update({
        'name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'celular': _celularCtrl.text.trim(),
        'descripcion': _descripcionCtrl.text.trim(),
        'slug': newSlug,
        'imagen': _imagenCtrl.text.trim(),
        'isSupplier': _isSupplier,
        'isAdmin': _isAdmin,
        'verified': _verified,
        'isPrivate': _isPrivate,
        if (_assocSupplierCtrl.text.trim().isNotEmpty)
          'associatedSupplierId': _assocSupplierCtrl.text.trim(),
      });

      // 2. Actualizar metadata/slugs si el slug cambió o es nuevo
      if (newSlug.isNotEmpty) {
        final slugsRef =
            FirebaseFirestore.instance.collection('metadata').doc('slugs');
        final slugsSnap = await slugsRef.get();
        Map<String, dynamic> mapping = {};
        if (slugsSnap.exists) {
          mapping =
              Map<String, dynamic>.from(slugsSnap.data()?['mapping'] ?? {});
        }
        // Eliminar el slug viejo si cambió
        if (oldSlug.isNotEmpty && oldSlug != newSlug) {
          mapping.remove(oldSlug);
        }
        // Agregar el nuevo slug
        mapping[newSlug] = widget.docId;
        await slugsRef.set({'mapping': mapping}, SetOptions(merge: true));
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cambios guardados',
              style: GoogleFonts.poppins(color: Colors.white)),
          backgroundColor: kPrimary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e',
              style: GoogleFonts.poppins(color: Colors.white)),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Subir imagen a Cloudinary (igual que step_2_multimedia) ──────────────
  Future<void> _pickAndUploadImage() async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 80,
          maxWidth: 800,
          maxHeight: 800);
      if (file == null) return;
      setState(() => _isUploadingImage = true);
      final bytes = await file.readAsBytes();
      final base64Img = base64Encode(bytes);
      final dataUri = 'data:image/jpeg;base64,$base64Img';
      final response = await http.post(
        Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/image/upload'),
        body: {'upload_preset': _uploadPreset, 'file': dataUri},
      );
      if (response.statusCode == 200) {
        final url = jsonDecode(response.body)['secure_url'];
        setState(() => _imagenCtrl.text = url);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error al subir imagen')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error subiendo imagen: $e');
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  // ── Asociar por correo: busca uid del usuario con ese correo ─────────────
  // ignore: unused_element
  Future<void> _associateByEmail(String email) async {
    if (email.isEmpty) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('usuarios')
          .where('email', isEqualTo: email.trim())
          .limit(1)
          .get();
      if (snap.docs.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('No se encontró usuario con ese correo')),
        );
        return;
      }
      final uid = snap.docs.first.id;
      setState(() => _assocSupplierCtrl.text = uid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Proveedor encontrado: $uid',
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 11)),
          backgroundColor: kPrimary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      debugPrint('Error buscando por correo: $e');
    }
  }

  // ── Agregar este usuario como associated supplier al proveedor principal ──
  Future<void> _linkToMainSupplier(String mainEmail) async {
    if (mainEmail.isEmpty) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('usuarios')
          .where('email', isEqualTo: mainEmail.trim())
          .limit(1)
          .get();
      if (snap.docs.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('No se encontró el proveedor principal')),
        );
        return;
      }
      final mainUid = snap.docs.first.id;
      // Actualiza en este usuario el campo associatedSupplierId
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(widget.docId)
          .update({'associatedSupplierId': mainUid});
      setState(() => _assocSupplierCtrl.text = mainUid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Vinculado al proveedor $mainUid',
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 11)),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      debugPrint('Error vinculando: $e');
    }
  }

  // ── Agrega usuario secundario al proveedor principal ─────────────────────
  Future<void> _addSecondaryToMainSupplier(String secondaryEmail) async {
    if (secondaryEmail.isEmpty) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('usuarios')
          .where('email', isEqualTo: secondaryEmail.trim())
          .limit(1)
          .get();
      if (snap.docs.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('No se encontró usuario con ese correo')),
        );
        return;
      }
      final secondaryUid = snap.docs.first.id;
      // Actualiza el usuario secundario con el UID de este proveedor
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(secondaryUid)
          .update({'associatedSupplierId': widget.docId});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Usuario $secondaryEmail ahora es asociado de este proveedor.',
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 12)),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final slug = _slugCtrl.text.trim();
    final profileLink =
        slug.isNotEmpty ? 'https://biqoe.com/$slug' : 'Sin slug asignado';

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Editar usuario',
            style: GoogleFonts.poppins(
                color: kPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _isSaving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: kPrimary, strokeWidth: 2))
                : TextButton(
                    onPressed: _saveChanges,
                    child: Text('Guardar',
                        style: GoogleFonts.poppins(
                            color: kPrimary, fontWeight: FontWeight.bold)),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── UID (no editable) ─────────────────────────────────
                _SectionHeader(title: 'Identificador'),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200)),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('UID de Firestore',
                                style: GoogleFonts.poppins(
                                    fontSize: 11, color: Colors.grey)),
                            Text(widget.docId,
                                style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: kPrimary)),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Copiar UID',
                        icon: const Icon(Icons.copy, color: kPrimary, size: 18),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: widget.docId));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('UID copiado'),
                                duration: Duration(seconds: 1)),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── Imagen de perfil ──────────────────────────────────
                _SectionHeader(title: 'Imagen de perfil'),
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(50),
                      child: SizedBox(
                        width: 72,
                        height: 72,
                        child: _imagenCtrl.text.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: _imagenCtrl.text,
                                fit: BoxFit.cover,
                                errorWidget: (c, u, e) => _avatarPlaceholder(),
                              )
                            : _avatarPlaceholder(),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTextField(
                            controller: _imagenCtrl,
                            label: 'URL de imagen (Cloudinary)',
                            hint: 'https://res.cloudinary.com/…',
                            icon: Icons.link,
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed:
                                _isUploadingImage ? null : _pickAndUploadImage,
                            icon: _isUploadingImage
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: kPrimary))
                                : const Icon(Icons.upload,
                                    size: 16, color: kPrimary),
                            label: Text(
                                _isUploadingImage
                                    ? 'Subiendo…'
                                    : 'Subir imagen',
                                style: GoogleFonts.poppins(
                                    fontSize: 12, color: kPrimary)),
                            style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: kPrimary),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8))),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Datos de identidad y contacto ─────────────────────
                _SectionHeader(title: 'Identidad y Contacto'),
                _buildTextField(
                    controller: _nameCtrl,
                    label: 'Nombre',
                    hint: 'Nombre del proveedor o usuario',
                    icon: Icons.person_outline),
                const SizedBox(height: 14),
                _buildTextField(
                    controller: _emailCtrl,
                    label: 'Correo electrónico',
                    hint: 'correo@ejemplo.com',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 14),
                _buildTextField(
                    controller: _celularCtrl,
                    label: 'Celular / WhatsApp',
                    hint: '04XXXXXXXXX',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone),
                const SizedBox(height: 14),
                _buildTextField(
                    controller: _descripcionCtrl,
                    label: 'Descripción / Bio',
                    hint: 'Descripción pública del proveedor',
                    icon: Icons.notes_outlined,
                    maxLines: 3),
                const SizedBox(height: 24),

                // ── Roles y permisos ──────────────────────────────────
                _SectionHeader(title: 'Roles y Permisos'),
                _BoolTile(
                  label: 'Es proveedor (isSupplier)',
                  subtitle: 'Acceso al dashboard de proveedor',
                  icon: Icons.store_outlined,
                  value: _isSupplier,
                  onChanged: (v) => setState(() => _isSupplier = v),
                ),
                _BoolTile(
                  label: 'Es administrador (isAdmin)',
                  subtitle: 'Acceso al panel de Biqoe Team',
                  icon: Icons.admin_panel_settings_outlined,
                  value: _isAdmin,
                  onChanged: (v) => setState(() => _isAdmin = v),
                ),
                _BoolTile(
                  label: 'Verificado',
                  subtitle: 'Muestra la insignia azul ✔️ en el perfil',
                  icon: Icons.verified_outlined,
                  value: _verified,
                  onChanged: (v) => setState(() => _verified = v),
                ),
                _BoolTile(
                  label: 'Privado (isPrivate)',
                  subtitle: 'Perfil no visible públicamente',
                  icon: Icons.lock_outline,
                  value: _isPrivate,
                  onChanged: (v) => setState(() => _isPrivate = v),
                ),
                const SizedBox(height: 24),

                // ── Slug y link público ───────────────────────────────
                _SectionHeader(title: 'URL pública (Slug)'),
                _buildTextField(
                  controller: _slugCtrl,
                  label: 'Slug',
                  hint: 'ej: accesovenezuela',
                  icon: Icons.link,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: kPrimary.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: kPrimary.withValues(alpha: 0.15))),
                  child: Row(
                    children: [
                      const Icon(Icons.public, color: kPrimary, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(profileLink,
                            style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: kPrimary,
                                fontWeight: FontWeight.w500)),
                      ),
                      if (slug.isNotEmpty)
                        IconButton(
                          tooltip: 'Copiar link',
                          icon:
                              const Icon(Icons.copy, color: kPrimary, size: 16),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: profileLink));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Link copiado'),
                                  duration: Duration(seconds: 1)),
                            );
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── Cuenta asociada (associatedSupplierId) ────────────
                _SectionHeader(title: 'Vinculación de negocio'),
                Text(
                  'associatedSupplierId actual:',
                  style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                _buildTextField(
                  controller: _assocSupplierCtrl,
                  label: 'UID del proveedor principal',
                  hint: 'TpbVn9gqPtfjB0svfs…',
                  icon: Icons.link_outlined,
                ),
                const SizedBox(height: 10),
                // Buscar UID por correo del proveedor principal
                _EmailLookupField(
                  labelButton: 'Buscar por correo y vincular como asociado',
                  hintEmail: 'correo del proveedor principal…',
                  onSearch: _linkToMainSupplier,
                ),
                const SizedBox(height: 14),
                // Agregar usuario secundario desde aquí (si es proveedor principal)
                _EmailLookupField(
                  labelButton: 'Agregar usuario secundario (por correo)',
                  hintEmail: 'correo del usuario secundario a vincular…',
                  onSearch: _addSecondaryToMainSupplier,
                ),
                const SizedBox(height: 40),

                // ── Botón guardar ─────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isSaving ? null : _saveChanges,
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Text('Guardar cambios',
                            style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15)),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _avatarPlaceholder() {
    final name = _nameCtrl.text;
    return Container(
      color: kPrimary.withValues(alpha: 0.08),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
              color: kPrimary, fontWeight: FontWeight.bold, fontSize: 28),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    ValueChanged<String>? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      onChanged: onChanged,
      style: GoogleFonts.poppins(fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: kPrimary, size: 18),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kPrimary, width: 1.5)),
        labelStyle: GoogleFonts.poppins(color: Colors.grey),
        hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
      ),
    );
  }
}

// ── Widget de búsqueda por correo para vincular ───────────────────────────────
class _EmailLookupField extends StatefulWidget {
  final String labelButton;
  final String hintEmail;
  final Future<void> Function(String email) onSearch;

  const _EmailLookupField({
    required this.labelButton,
    required this.hintEmail,
    required this.onSearch,
  });

  @override
  State<_EmailLookupField> createState() => _EmailLookupFieldState();
}

class _EmailLookupFieldState extends State<_EmailLookupField> {
  final _ctrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _ctrl,
            keyboardType: TextInputType.emailAddress,
            style: GoogleFonts.poppins(fontSize: 12),
            decoration: InputDecoration(
              hintText: widget.hintEmail,
              hintStyle: GoogleFonts.poppins(fontSize: 11, color: Colors.grey),
              prefixIcon:
                  const Icon(Icons.email_outlined, color: kPrimary, size: 16),
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade200)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade200)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: kPrimary)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 44,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            onPressed: _loading
                ? null
                : () async {
                    if (_ctrl.text.trim().isEmpty) return;
                    setState(() => _loading = true);
                    await widget.onSearch(_ctrl.text.trim());
                    if (mounted) setState(() => _loading = false);
                  },
            child: _loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : Text(widget.labelButton,
                    style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}

// ── Helpers de UI ─────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
              width: 4,
              height: 18,
              decoration: BoxDecoration(
                  color: kPrimary, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(title,
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold, fontSize: 14, color: kPrimary)),
        ],
      ),
    );
  }
}

class _BoolTile extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _BoolTile({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: value ? kPrimary.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: value
                ? kPrimary.withValues(alpha: 0.25)
                : Colors.grey.shade200),
      ),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        secondary: Icon(icon, color: value ? kPrimary : Colors.grey, size: 20),
        title: Text(label,
            style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: value ? kPrimary : Colors.black87)),
        subtitle: Text(subtitle,
            style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
        value: value,
        activeThumbColor: kPrimary,
        onChanged: onChanged,
      ),
    );
  }
}

class _SmallBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _SmallBadge({required this.label, required this.color});

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
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color.withValues(alpha: 0.85))),
    );
  }
}
