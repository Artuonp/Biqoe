import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const Color kPrimaryColor = Color.fromRGBO(17, 48, 73, 1);

class Step3Location extends StatefulWidget {
  final Map<String, dynamic> initialData;
  final Function(Map<String, dynamic>) onNext;

  const Step3Location({
    super.key,
    required this.initialData,
    required this.onNext,
  });

  @override
  State<Step3Location> createState() => _Step3LocationState();
}

class _Step3LocationState extends State<Step3Location> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedState;
  late TextEditingController _zoneController; // Antes 'specificPlace'
  late TextEditingController _mapsLinkController;

  // Lista de Estados (Venezuela)
  final List<String> _venezuelaStates = [
    'Amazonas',
    'Anzoátegui',
    'Apure',
    'Aragua',
    'Barinas',
    'Bolívar',
    'Carabobo',
    'Cojedes',
    'Delta Amacuro',
    'Distrito Capital',
    'Dependencias Federales',
    'Falcón',
    'Guárico',
    'Lara',
    'Mérida',
    'Miranda',
    'Monagas',
    'Nueva Esparta',
    'Portuguesa',
    'Sucre',
    'Táchira',
    'Trujillo',
    'La Guaira',
    'Yaracuy',
    'Zulia'
  ];

  @override
  void initState() {
    super.initState();
    _selectedState = widget.initialData['estado'];
    // Usamos 'lugar' para la Zona/Lugar unificado
    _zoneController = TextEditingController(text: widget.initialData['lugar']);
    _mapsLinkController =
        TextEditingController(text: widget.initialData['googleMapsLink']);
  }

  @override
  void dispose() {
    _zoneController.dispose();
    _mapsLinkController.dispose();
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
      widget.onNext({
        'estado': _selectedState,
        'lugar': _zoneController.text.trim(), // Guardamos Zona/Lugar aquí
        'googleMapsLink': _mapsLinkController.text.trim(),
        // Eliminamos 'ubicacion' antigua si ya no se usa
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
              "Ubicación y zona",
              style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: kPrimaryColor),
            ),
            Text(
              "Indica dónde se realizará la actividad.",
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
            const SizedBox(height: 25),

            // --- SELECTOR DE ESTADO (Diseño Corregido) ---
            Theme(
              data: Theme.of(context).copyWith(
                canvasColor:
                    Colors.white, // Fondo blanco para el menú desplegable
              ),
              child: DropdownButtonFormField<String>(
                initialValue: _selectedState,
                decoration: _buildInputDecoration(
                  label: "Estado",
                  hint: "Selecciona el estado",
                  icon: Icons.map,
                ),
                // Limitamos la altura para que no cubra toda la pantalla
                menuMaxHeight: 300,
                borderRadius:
                    BorderRadius.circular(12), // Bordes redondeados en el menú
                items: _venezuelaStates.map((state) {
                  return DropdownMenuItem(
                    value: state,
                    child: Text(state,
                        style: GoogleFonts.poppins(
                            fontSize: 14, color: Colors.black87)),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedState = val),
                validator: (val) => val == null ? 'Selecciona un estado' : null,
                icon:
                    const Icon(Icons.keyboard_arrow_down, color: kPrimaryColor),
              ),
            ),

            const SizedBox(height: 20),

            // --- ZONA O LUGAR ---
            TextFormField(
              controller: _zoneController,
              style: GoogleFonts.poppins(fontSize: 14),
              decoration: _buildInputDecoration(
                label: "Zona o lugar",
                hint: "Ej: Morrocoy, Parque del Este, etc...",
                icon: Icons.place,
              ),
              validator: (val) =>
                  val == null || val.isEmpty ? 'Requerido' : null,
            ),
            const SizedBox(height: 20),

            // --- GOOGLE MAPS LINK ---
            TextFormField(
              controller: _mapsLinkController,
              style: GoogleFonts.poppins(fontSize: 14),
              decoration: _buildInputDecoration(
                label: "Link de Google Maps",
                hint: "Pega el enlace de ubicación aquí",
                icon: Icons.link,
              ),
              validator: (val) {
                if (val == null || val.isEmpty) return 'Requerido';
                if (!val.contains('http')) return 'Ingresa un enlace válido';
                return null;
              },
            ),

            const SizedBox(height: 10),

            // --- TIP ---
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment
                    .start, // Alineación superior para textos largos
                children: [
                  const Icon(Icons.info_outline,
                      color: Colors.orange, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Ve a Google Maps, busca el lugar exacto, selecciona 'Compartir', luego 'Copiar vínculo' y pégalo arriba.",
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: Colors.black87),
                    ),
                  )
                ],
              ),
            ),

            const SizedBox(height: 40),

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
          ],
        ),
      ),
    );
  }
}
