import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

const Color kPrimaryColor = Color.fromRGBO(17, 48, 73, 1);

class Step6Review extends StatelessWidget {
  final Map<String, dynamic> formData;
  final VoidCallback onSubmit;
  final bool isSubmitting;

  const Step6Review({
    super.key,
    required this.formData,
    required this.onSubmit,
    required this.isSubmitting,
  });

  @override
  Widget build(BuildContext context) {
    final String nombre = formData['nombre'] ?? '';
    final String ubicacion = "${formData['lugar']}, ${formData['estado']}";
    final List images = formData['imagenes'] ?? [];
    final List packages = formData['paquetes'] ?? [];
    final List pagos = formData['metodosPago'] ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Resumen final",
            style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: kPrimaryColor),
          ),
          Text(
            "Revisa que todo esté correcto antes de publicar.",
            style: GoogleFonts.poppins(color: Colors.grey),
          ),
          const SizedBox(height: 25),

          // --- 1. PORTADA ---
          if (images.isNotEmpty)
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                image: DecorationImage(
                  image: NetworkImage(images.first),
                  fit: BoxFit.cover,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.7),
                      Colors.transparent
                    ],
                  ),
                ),
                padding: const EdgeInsets.all(16),
                alignment: Alignment.bottomLeft,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nombre,
                        style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                    Text(ubicacion,
                        style: GoogleFonts.poppins(
                            color: Colors.white70, fontSize: 14)),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 25),

          // --- 2. DETALLES ---
          _SectionTitle(title: "Detalles generales"),
          _InfoRow(
              label: "Categorías",
              value: (formData['categorias'] as List? ?? []).join(', ')),
          _InfoRow(
              label: "Maps",
              value: formData['googleMapsLink'] ?? 'No especificado'),
          const SizedBox(height: 20),

          // --- 3. INVENTARIO (PAQUETES COMPLETOS) ---
          _SectionTitle(title: "Paquetes (${packages.length})"),
          ...packages.map((pkg) => Container(
                margin: const EdgeInsets.only(bottom: 15),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 5,
                          offset: const Offset(0, 2))
                    ]),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cabecera: Nombre y Precio
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                            child: Text(pkg['nombre'],
                                style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: kPrimaryColor))),
                        Text("\$${pkg['precio']}",
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700],
                                fontSize: 18)),
                      ],
                    ),
                    const Divider(height: 20),

                    // Mini Descripción
                    Text("Mini descripción:",
                        style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600])),
                    MarkdownBody(
                      data: pkg['miniDescripcion'] ?? '',
                      styleSheet:
                          MarkdownStyleSheet.fromTheme(Theme.of(context))
                              .copyWith(
                        p: GoogleFonts.poppins(
                            fontSize: 13, fontStyle: FontStyle.italic),
                        strong: GoogleFonts.poppins(
                            fontSize: 13, fontWeight: FontWeight.w600),
                        listBullet: GoogleFonts.poppins(fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Descripción Completa (Expandida)
                    Text("Descripción Completa:",
                        style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600])),
                    MarkdownBody(
                      data: pkg['descripcion'] ?? '',
                      styleSheet:
                          MarkdownStyleSheet.fromTheme(Theme.of(context))
                              .copyWith(
                        p: GoogleFonts.poppins(fontSize: 13),
                        strong: GoogleFonts.poppins(
                            fontSize: 13, fontWeight: FontWeight.w600),
                        listBullet: GoogleFonts.poppins(fontSize: 13),
                      ),
                    ),

                    const SizedBox(height: 10),
                    // Datos Técnicos
                    Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 5),
                        Text(
                            pkg['tipo'] == 'dated'
                                ? "Tipo: Calendario (${pkg['disponibilidad']?.length ?? 0} fechas)"
                                : "Tipo: ${pkg['tipo']} (Cupos: ${pkg['cuposDisponibles']})",
                            style: GoogleFonts.poppins(
                                fontSize: 11, color: Colors.grey[600])),
                      ],
                    )
                  ],
                ),
              )),
          const SizedBox(height: 20),

          // --- 4. PAGOS ---
          _SectionTitle(title: "Métodos de pago aceptados"),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: pagos
                .map((p) => Chip(
                      label: Text(p['metodo']),
                      backgroundColor: Colors.white, // fondo blanco
                      labelStyle: TextStyle(
                          color: kPrimaryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                      side: BorderSide(
                          color: kPrimaryColor.withValues(alpha: 0.2)),
                    ))
                .toList(),
          ),

          const SizedBox(height: 40),

          // --- BOTÓN PUBLICAR ---
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 4,
              ),
              onPressed: isSubmitting ? null : onSubmit,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isSubmitting ? "" : "¡Publicar evento!",
                    style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  const Icon(Icons.rocket_launch, color: Colors.white)
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

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(title,
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold, fontSize: 16, color: kPrimaryColor)),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: GoogleFonts.poppins(color: Colors.grey, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w500, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
