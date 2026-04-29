import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

const Color kPrimaryColor = Color.fromRGBO(17, 48, 73, 1);

class Step2Multimedia extends StatefulWidget {
  final Map<String, dynamic> initialData;
  final Function(Map<String, dynamic>) onNext;

  const Step2Multimedia({
    super.key,
    required this.initialData,
    required this.onNext,
  });

  @override
  State<Step2Multimedia> createState() => _Step2MultimediaState();
}

class _Step2MultimediaState extends State<Step2Multimedia> {
  final ImagePicker _picker = ImagePicker();
  List<String> _uploadedImageUrls = [];
  bool _isUploading = false;

  // --- CONFIGURACIÓN DE CLOUDINARY ---
  final String _cloudName = "dovz4vf2e";
  final String _uploadPreset = "ml_default";

  @override
  void initState() {
    super.initState();
    if (widget.initialData['imagenes'] != null) {
      _uploadedImageUrls = List<String>.from(widget.initialData['imagenes']);
    }
  }

  // 1. Seleccionar y Subir
  Future<void> _pickAndUploadImage(ImageSource source) async {
    try {
      // Usamos el compresor nativo del ImagePicker
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 80, // Calidad 80% para ahorrar espacio
        maxWidth: 1280, // Redimensionar a HD
        maxHeight: 1280,
      );

      if (pickedFile == null) return;

      setState(() => _isUploading = true);

      // Leemos la imagen como Bytes (memoria)
      final bytes = await pickedFile.readAsBytes();

      // Subir a Cloudinary
      String? url = await _uploadToCloudinary(bytes);

      if (url != null) {
        setState(() {
          _uploadedImageUrls.add(url);
        });
      }
    } catch (e) {
      debugPrint("Error interno al seleccionar imagen: $e");
      _showMaintenanceError();
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // 🔥 FIX DEFINITIVO: Subida a Cloudinary usando Base64 (A prueba de Web/CORS)
  Future<String?> _uploadToCloudinary(List<int> imageBytes) async {
    try {
      final url =
          Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/image/upload');

      // Convertimos los bytes de la imagen a un String Base64
      final String base64Image = base64Encode(imageBytes);
      // Le agregamos el encabezado para que Cloudinary sepa que es una imagen JPEG
      final String dataUri = 'data:image/jpeg;base64,$base64Image';

      // Hacemos un POST normal (esto no falla nunca en Web)
      final response = await http.post(
        url,
        body: {
          'upload_preset': _uploadPreset,
          'file': dataUri,
        },
      );

      if (response.statusCode == 200) {
        final jsonMap = jsonDecode(response.body);
        return jsonMap['secure_url'];
      } else {
        // Esto se imprimirá en tu consola (oculto al usuario) para saber por qué falló
        debugPrint(
            "❌ Error Cloudinary [${response.statusCode}]: ${response.body}");
        _showMaintenanceError();
        return null;
      }
    } catch (e) {
      debugPrint("❌ Error de red con Cloudinary: $e");
      _showMaintenanceError();
      return null;
    }
  }

  void _showMaintenanceError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text("Función en mantenimiento, por favor contactar a soporte."),
      backgroundColor: Colors.red,
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _validateAndContinue() {
    if (_uploadedImageUrls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes subir al menos una imagen'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    // Guardamos y seguimos
    widget.onNext({
      'imagenes': _uploadedImageUrls,
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Galería de fotos",
            style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: kPrimaryColor),
          ),
          const SizedBox(height: 10),

          // --- CONSEJOS DE CALIDAD (Tips Visuales) ---
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.tips_and_updates,
                    color: Colors.blue, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Consejos para vender más:",
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.blue[800])),
                      const SizedBox(height: 5),
                      Text("• Usa fotos con buena iluminación (luz natural).",
                          style: GoogleFonts.poppins(fontSize: 11)),
                      Text("• Evita fotos borrosas o con texto encima.",
                          style: GoogleFonts.poppins(fontSize: 11)),
                      Text("• Muestra personas disfrutando la experiencia.",
                          style: GoogleFonts.poppins(fontSize: 11)),
                      const SizedBox(height: 5),
                      Text(
                          "Nota: Optimizaremos tus fotos automáticamente para que carguen rápido.",
                          style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontStyle: FontStyle.italic,
                              color: Colors.grey[600])),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 25),

          // --- BOTONES DE CARGA ---
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: kPrimaryColor,
                    elevation: 0,
                    side: const BorderSide(color: kPrimaryColor),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _isUploading
                      ? null
                      : () => _pickAndUploadImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: Text("Galería",
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: kPrimaryColor,
                    elevation: 0,
                    side: const BorderSide(color: kPrimaryColor),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _isUploading
                      ? null
                      : () => _pickAndUploadImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: Text("Cámara",
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),

          if (_isUploading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Column(
                  children: [
                    const CircularProgressIndicator(color: kPrimaryColor),
                    const SizedBox(height: 10),
                    Text("Optimizando y subiendo...",
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 20),

          // --- GRILLA DE IMÁGENES ---
          if (_uploadedImageUrls.isNotEmpty)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1, // Cuadradas
              ),
              itemCount: _uploadedImageUrls.length,
              itemBuilder: (context, index) {
                return Stack(
                  children: [
                    // Imagen
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        image: DecorationImage(
                          image: NetworkImage(_uploadedImageUrls[index]),
                          fit: BoxFit.cover,
                        ),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4)
                        ],
                      ),
                    ),
                    // Botón Borrar
                    Positioned(
                      top: 5,
                      right: 5,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _uploadedImageUrls.removeAt(index);
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.delete,
                              color: Colors.red, size: 18),
                        ),
                      ),
                    ),
                    // Etiqueta "Portada" (la primera)
                    if (index == 0)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          decoration: const BoxDecoration(
                            color: kPrimaryColor,
                            borderRadius: BorderRadius.vertical(
                                bottom: Radius.circular(12)),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            "Portada",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      )
                  ],
                );
              },
            )
          else if (!_isUploading)
            Center(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Icon(Icons.image_not_supported_outlined,
                      size: 60, color: Colors.grey[300]),
                  const SizedBox(height: 10),
                  Text("Aún no has subido fotos",
                      style: GoogleFonts.poppins(color: Colors.grey)),
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
              onPressed: _isUploading ? null : _validateAndContinue,
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
    );
  }
}
