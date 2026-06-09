import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';

const Color kPrimaryColor = Color.fromRGBO(17, 48, 73, 1);

class Step1BasicInfo extends StatefulWidget {
  final Map<String, dynamic> initialData;
  final Function(Map<String, dynamic>) onNext;

  const Step1BasicInfo({
    super.key,
    required this.initialData,
    required this.onNext,
  });

  @override
  State<Step1BasicInfo> createState() => _Step1BasicInfoState();
}

class _Step1BasicInfoState extends State<Step1BasicInfo> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _sectionInputCtrl;
  List<String> _selectedCategories = [];

  // 'ocultar' reemplaza a 'isPrivate'.
  // true = la actividad NO aparece en destinations_screen ni en provider_profile_screen
  bool _ocultar = false;

  // Sección libre que escribe el proveedor
  String? _selectedSection;

  // Secciones guardadas localmente (persistidas con Hive)
  List<String> _savedSections = [];
  Box? _sectionsBox;

  // DATOS FIJOS — categorías
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
    'Hospedaje',
    'Online',
    'Vida nocturna',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialData['nombre']);
    _sectionInputCtrl = TextEditingController();

    if (widget.initialData['categorias'] != null) {
      _selectedCategories = List<String>.from(widget.initialData['categorias']);
    }

    // Cargamos 'ocultar'. Si el dato venía del campo antiguo 'isPrivate',
    // lo migramos silenciosamente. isInApp == false también implica ocultar.
    _ocultar = widget.initialData['ocultar'] == true ||
        widget.initialData['isPrivate'] == true ||
        widget.initialData['isInApp'] == false;

    // Sección guardada previamente (modo edición)
    final savedSec = widget.initialData['seccion']?.toString();
    if (savedSec != null && savedSec.isNotEmpty) {
      _selectedSection = savedSec;
    }

    _loadSections();
  }

  Future<void> _loadSections() async {
    try {
      final box = await Hive.openBox('supplier_sections');
      _sectionsBox = box;
      final loaded = box.values.cast<String>().toList();
      if (mounted) {
        setState(() {
          _savedSections = loaded;
          // Si la sección actual no está en la lista, la agregamos localmente
          if (_selectedSection != null &&
              !_savedSections.contains(_selectedSection)) {
            _savedSections.insert(0, _selectedSection!);
          }
        });
      }
    } catch (e) {
      debugPrint('[Secciones] Error cargando: $e');
    }
  }

  Future<void> _addSection(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || _savedSections.contains(trimmed)) return;
    try {
      final box = _sectionsBox ?? await Hive.openBox('supplier_sections');
      await box.put(trimmed, trimmed);
      if (mounted) {
        setState(() {
          _savedSections.add(trimmed);
          _selectedSection = trimmed;
        });
      }
    } catch (e) {
      debugPrint('[Secciones] Error guardando: $e');
    }
  }

  Future<void> _deleteSection(String name) async {
    try {
      final box = _sectionsBox ?? await Hive.openBox('supplier_sections');
      await box.delete(name);
      if (mounted) {
        setState(() {
          _savedSections.remove(name);
          if (_selectedSection == name) _selectedSection = null;
        });
      }
    } catch (e) {
      debugPrint('[Secciones] Error eliminando: $e');
    }
  }

  Future<void> _renameSection(String oldName) async {
    final ctrl = TextEditingController(text: oldName);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Renombrar sección',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Nuevo nombre',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancelar', style: GoogleFonts.poppins())),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text('Guardar',
                style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
    if (newName == null || newName.isEmpty || newName == oldName) return;
    try {
      final box = _sectionsBox ?? await Hive.openBox('supplier_sections');
      await box.delete(oldName);
      await box.put(newName, newName);
      if (mounted) {
        setState(() {
          final idx = _savedSections.indexOf(oldName);
          if (idx >= 0) _savedSections[idx] = newName;
          if (_selectedSection == oldName) _selectedSection = newName;
        });
      }
    } catch (e) {
      debugPrint('[Secciones] Error renombrando: $e');
    }
  }

  void _showAddSectionDialog() {
    _sectionInputCtrl.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Nueva sección',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: _sectionInputCtrl,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: 'Ej: Transporte, Internacional…',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onSubmitted: (v) {
            _addSection(v);
            Navigator.pop(ctx);
          },
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancelar', style: GoogleFonts.poppins())),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor),
            onPressed: () {
              _addSection(_sectionInputCtrl.text);
              Navigator.pop(ctx);
            },
            child: Text('Agregar',
                style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _sectionInputCtrl.dispose();
    super.dispose();
  }

  InputDecoration _buildInputDecoration({
    required String label,
    required String hint,
    IconData? icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon != null ? Icon(icon, color: kPrimaryColor) : null,
      filled: true,
      fillColor: Colors.grey[50],
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kPrimaryColor, width: 2),
      ),
      labelStyle: GoogleFonts.poppins(color: Colors.grey[700]),
      hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
    );
  }

  void _validateAndContinue() {
    if (_formKey.currentState!.validate()) {
      if (_selectedCategories.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecciona al menos una categoría')),
        );
        return;
      }

      widget.onNext({
        'nombre': _nameController.text.trim(),
        'categorias': _selectedCategories,
        // 'ocultar' es el nuevo campo principal
        'ocultar': _ocultar,
        // isInApp es el campo que usa destinations_screen para filtrar
        // ocultar=true  → isInApp=false (no aparece en app)
        // ocultar=false → isInApp=true  (sí aparece)
        'isInApp': !_ocultar,
        // Mantenemos isPrivate en sync para retrocompatibilidad
        'isPrivate': _ocultar,
        // Sección libre
        'seccion': _selectedSection ?? '',
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "¿Qué vas a ofrecer?",
              style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: kPrimaryColor),
            ),
            Text(
              "Comencemos con el nombre y la categoría.",
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
            const SizedBox(height: 30),

            // ── Nombre ────────────────────────────────────────────────────
            TextFormField(
              controller: _nameController,
              style: GoogleFonts.poppins(fontSize: 14),
              decoration: _buildInputDecoration(
                  label: "Nombre de la experiencia",
                  hint: "Ej: Tour por Mérida / Taller de pintura",
                  icon: Icons.label_outline),
              validator: (val) => val == null || val.isEmpty
                  ? 'El nombre es obligatorio'
                  : null,
            ),

            const SizedBox(height: 30),

            // ── Sección ───────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Sección",
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: kPrimaryColor)),
                TextButton.icon(
                  onPressed: _showAddSectionDialog,
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: Text("Nueva sección",
                      style: GoogleFonts.poppins(fontSize: 12)),
                  style: TextButton.styleFrom(foregroundColor: kPrimaryColor),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              "Agrupa tus actividades por categoría propia (ej: Transporte, Tours).",
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 10),

            if (_savedSections.isEmpty)
              GestureDetector(
                onTap: _showAddSectionDialog,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: Colors.grey.shade200,
                          style: BorderStyle.solid)),
                  child: Row(
                    children: [
                      Icon(Icons.folder_open_outlined,
                          color: Colors.grey.shade400),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                            "Ninguna sección creada. Toca '+ Nueva sección' para agregar.",
                            style: GoogleFonts.poppins(
                                fontSize: 12, color: Colors.grey)),
                      ),
                    ],
                  ),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  // Chip "Sin sección"
                  GestureDetector(
                    onTap: () => setState(() => _selectedSection = null),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                          color: _selectedSection == null
                              ? kPrimaryColor
                              : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: _selectedSection == null
                                  ? kPrimaryColor
                                  : Colors.grey.shade300)),
                      child: Text('Sin sección',
                          style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: _selectedSection == null
                                  ? Colors.white
                                  : Colors.grey[700])),
                    ),
                  ),
                  // Chips de secciones guardadas
                  ..._savedSections.map((sec) {
                    final isSelected = _selectedSection == sec;
                    return GestureDetector(
                      onLongPress: () => _showSectionContextMenu(sec),
                      onTap: () => setState(() => _selectedSection = sec),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                            color: isSelected ? kPrimaryColor : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: isSelected
                                    ? kPrimaryColor
                                    : Colors.grey.shade300)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(sec,
                                style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.grey[700])),
                            const SizedBox(width: 4),
                            Icon(Icons.more_vert,
                                size: 14,
                                color: isSelected
                                    ? Colors.white70
                                    : Colors.grey[400]),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),

            const SizedBox(height: 30),

            // ── Categorías ────────────────────────────────────────────────
            Text("Categorías",
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: kPrimaryColor)),
            const SizedBox(height: 5),
            Text("Selecciona todas las que apliquen",
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 12),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _predefinedCategories.map((cat) {
                final isSelected = _selectedCategories.contains(cat);
                return FilterChip(
                  label: Text(cat),
                  selected: isSelected,
                  backgroundColor: Colors.white,
                  selectedColor: kPrimaryColor.withValues(alpha: 0.1),
                  checkmarkColor: kPrimaryColor,
                  side: BorderSide(
                      color: isSelected ? kPrimaryColor : Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  labelStyle: GoogleFonts.poppins(
                    color: isSelected ? kPrimaryColor : Colors.black87,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 13,
                  ),
                  onSelected: (bool selected) {
                    setState(() {
                      selected
                          ? _selectedCategories.add(cat)
                          : _selectedCategories.remove(cat);
                    });
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 40),

            // ── Switch Ocultar ────────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: _ocultar
                    ? Colors.orange.withValues(alpha: 0.06)
                    : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _ocultar
                      ? Colors.orange.withValues(alpha: 0.4)
                      : Colors.grey.shade200,
                ),
              ),
              child: SwitchListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                title: Text(
                  'Ocultar actividad',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: _ocultar ? Colors.orange[800] : Colors.black87,
                  ),
                ),
                subtitle: Text(
                  _ocultar
                      ? 'No aparecerá en la app ni en el perfil del proveedor.'
                      : 'Visible en la app y en el perfil del proveedor.',
                  style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: _ocultar ? Colors.orange[700] : Colors.grey),
                ),
                secondary: Icon(
                  _ocultar
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: _ocultar ? Colors.orange[700] : Colors.grey,
                ),
                value: _ocultar,
                activeThumbColor: Colors.orange[700],
                activeTrackColor: Colors.orange.withValues(alpha: 0.35),
                onChanged: (val) => setState(() => _ocultar = val),
              ),
            ),

            const SizedBox(height: 30),

            // ── Botón Siguiente ───────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 3,
                  shadowColor: kPrimaryColor.withValues(alpha: 0.4),
                ),
                onPressed: _validateAndContinue,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Siguiente paso",
                        style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    const SizedBox(width: 10),
                    const Icon(Icons.arrow_forward_rounded, color: Colors.white)
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // Menú contextual al hacer long-press en una sección
  void _showSectionContextMenu(String section) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('"$section"',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: kPrimaryColor)),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: kPrimaryColor),
              title:
                  Text('Renombrar', style: GoogleFonts.poppins(fontSize: 14)),
              onTap: () {
                Navigator.pop(context);
                _renameSection(section);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: Text('Eliminar',
                  style: GoogleFonts.poppins(fontSize: 14, color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deleteSection(section);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
