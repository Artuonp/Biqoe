import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
  List<String> _selectedCategories = [];

  // DATOS FIJOS
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
    'Vida nocturna'
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialData['nombre']);

    if (widget.initialData['categorias'] != null) {
      _selectedCategories = List<String>.from(widget.initialData['categorias']);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
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
        // Eliminadas descripciones e información de restaurante
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

            // --- NOMBRE DEL EVENTO ---
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

            // --- CATEGORÍAS ---
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

            const SizedBox(height: 50),

            // --- BOTÓN SIGUIENTE ---
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
}
