import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../reservation_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const Color kPrimaryColor = Color.fromRGBO(17, 48, 73, 1);
const Color kBackgroundColor = Color(0xFFF8F9FD);

class DestinationDetailScreen extends StatefulWidget {
  final Map<String, dynamic> destino;
  final String userId;

  const DestinationDetailScreen({
    super.key,
    required this.destino,
    required this.userId,
  });

  @override
  DestinationDetailScreenState createState() => DestinationDetailScreenState();
}

class DestinationDetailScreenState extends State<DestinationDetailScreen> {
  final PageController _pageController = PageController();
  int _currentImageIndex = 0;

  List<Map<String, dynamic>> selectedPackages = [];
  late Box<Map> savedDestinationsBox;
  bool isSaved = false;

  // --- ELIMINÉ _sessionViews TEMPORALMENTE PARA QUE PUEDAS PROBAR VARIAS VECES ---

  @override
  void initState() {
    super.initState();
    _initSavedBox();

    // Ejecutamos el diagnóstico
    _debugIncrementViewCount();
  }

  // --- LÓGICA DE VISITAS CON DIAGNÓSTICO ---
  void _debugIncrementViewCount() {
    if (kDebugMode) {
      print("\n🔵 --- INICIO DIAGNÓSTICO DE VISTAS ---");
    }

    // 1. Ver qué datos llegaron realmente
    final String? docIdFromMap = widget.destino['id'];
    final String? nameFromMap = widget.destino['nombre'];
    final String supplierId =
        widget.destino['supplierId'] ?? widget.destino['supplier'] ?? '';

    if (kDebugMode) {
      print("1. Datos recibidos:");
    }
    if (kDebugMode) {
      print("   - ID en el mapa (widget.destino['id']): $docIdFromMap");
    }
    if (kDebugMode) {
      print("   - Nombre: $nameFromMap");
    }
    if (kDebugMode) {
      print("   - Supplier ID (Dueño): $supplierId");
    }
    if (kDebugMode) {
      print("   - Tu User ID actual: ${widget.userId}");
    }

    // 2. Determinar qué ID vamos a usar
    // Si docIdFromMap es nulo, usará el nombre, y ESE ES EL ERROR COMÚN.
    // Firestore necesita el ID "raro" (ej: 'ABC123xyz'), no el nombre "Playa".
    final String targetDocId = docIdFromMap ?? '';

    if (targetDocId.isEmpty) {
      if (kDebugMode) {
        print("❌ ERROR CRÍTICO: No se recibió un ID de documento válido.");
      }
      if (kDebugMode) {
        print(
            "   Solución: Revisa la pantalla ANTERIOR (donde haces el push).");
      }
      if (kDebugMode) {
        print(
            "   Asegúrate de hacer: data['id'] = doc.id; antes de enviar los datos.");
      }
      return;
    }

    // 3. Validación de Dueño
    if (widget.userId == supplierId) {
      if (kDebugMode) {
        print(
            "⚠️ AVISO: Eres el dueño de la actividad. No se contará la vista.");
      }
      return;
    }

    if (kDebugMode) {
      print("2. Intentando actualizar Firestore...");
    }
    if (kDebugMode) {
      print("   - Colección: destinos");
    }
    if (kDebugMode) {
      print("   - Documento ID: $targetDocId");
    }

    // 4. Ejecutar escritura
    // Usamos SET con MERGE para asegurar que si el campo no existe, lo cree.
    FirebaseFirestore.instance.collection('destinos').doc(targetDocId).set({
      'profileViews': FieldValue.increment(1),
    }, SetOptions(merge: true)).then((_) {
      if (kDebugMode) {
        print("✅ ÉXITO TOTAL: Contador incrementado en la base de datos.");
      }
      if (kDebugMode) {
        print("   Revisa tu consola de Firebase ahora.");
      }
    }).catchError((error) {
      if (kDebugMode) {
        print("❌ ERROR DE FIREBASE: $error");
      }
      if (error.toString().contains("permission-denied")) {
        if (kDebugMode) {
          print(
              "   -> CAUSA: Reglas de seguridad. El usuario actual no tiene permiso de escritura.");
        }
      } else if (error.toString().contains("not-found")) {
        if (kDebugMode) {
          print(
              "   -> CAUSA: El documento con ID '$targetDocId' no existe en la colección 'destinos'.");
        }
      }
    });
  }

  Future<void> _initSavedBox() async {
    savedDestinationsBox =
        await Hive.openBox<Map>('saved_destinations_${widget.userId}');
    final key = widget.destino['id'] ?? widget.destino['nombre'];
    if (mounted) {
      setState(() {
        isSaved = savedDestinationsBox.containsKey(key);
      });
    }
  }

  void _toggleSaveDestination() {
    final destinationId = widget.destino['id'] ?? widget.destino['nombre'];
    setState(() {
      if (savedDestinationsBox.containsKey(destinationId)) {
        savedDestinationsBox.delete(destinationId);
        isSaved = false;
      } else {
        savedDestinationsBox.put(destinationId, widget.destino);
        isSaved = true;
      }
    });
  }

  void _togglePackageSelection(Map<String, dynamic> paquete) {
    setState(() {
      if (selectedPackages.contains(paquete)) {
        selectedPackages.remove(paquete);
      } else {
        selectedPackages.add(paquete);
      }
    });
  }

  void _openLink(String? url) async {
    if (url == null || url.isEmpty) return;
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    // --- DATOS SEGUROS ---
    final List<String> images =
        (widget.destino['imagenes'] as List?)?.cast<String>() ??
            (widget.destino['imagen'] as List?)?.cast<String>() ??
            [];

    // --- CORRECCIÓN DE UBICACIÓN (ZONA + ESTADO) ---
    String locationText = "Ubicación por definir";
    List<String> locParts = [];

    // Validamos que existan y no estén vacíos ni sean "null" string
    if (widget.destino['lugar'] != null &&
        widget.destino['lugar'].toString().isNotEmpty &&
        widget.destino['lugar'].toString() != 'null') {
      locParts.add(widget.destino['lugar']);
    }
    if (widget.destino['estado'] != null &&
        widget.destino['estado'].toString().isNotEmpty &&
        widget.destino['estado'].toString() != 'null') {
      locParts.add(widget.destino['estado']);
    }

    if (locParts.isNotEmpty) {
      locationText = locParts.join(", ");
    } else if (widget.destino['ubicacion'] != null) {
      locationText = widget.destino['ubicacion'];
    }

    final String mapsLink =
        widget.destino['googleMapsLink'] ?? widget.destino['coordenadas'] ?? '';
    final String supplierId =
        widget.destino['supplierId'] ?? widget.destino['supplier'] ?? '';
    final List paquetes = widget.destino['paquetes'] ?? [];

    // OBTENEMOS EL ID PARA LA RESERVA
    // Si el mapa no trae 'id', usamos el nombre como fallback (aunque lo ideal es siempre tener ID)
    final String docId = widget.destino['id'] ?? widget.destino['nombre'] ?? '';

    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // --- 1. HEADER PARALLAX ---
              SliverAppBar(
                expandedHeight: 350.0,
                pinned: true,
                stretch: true,
                backgroundColor: kPrimaryColor,
                elevation: 0,
                leading: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back,
                        color: Colors.black, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                actions: [
                  Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(
                        isSaved ? Icons.favorite : Icons.favorite_border,
                        color: isSaved
                            ? Color.fromRGBO(17, 48, 73, 1)
                            : Colors.black,
                        size: 22,
                      ),
                      onPressed: _toggleSaveDestination,
                    ),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  stretchModes: const [StretchMode.zoomBackground],
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (images.isNotEmpty)
                        PageView.builder(
                          // FIX: AlwaysScrollableScrollPhysics para que funcione el swipe
                          physics: const AlwaysScrollableScrollPhysics(),
                          controller: _pageController,
                          itemCount: images.length,
                          onPageChanged: (idx) =>
                              setState(() => _currentImageIndex = idx),
                          itemBuilder: (ctx, idx) {
                            return CachedNetworkImage(
                              imageUrl: images[idx],
                              fit: BoxFit.cover,
                              placeholder: (context, url) =>
                                  Container(color: Colors.grey[200]),
                              errorWidget: (context, url, error) => Container(
                                color: Colors.grey[300],
                                child: const Icon(Icons.broken_image,
                                    color: Colors.grey),
                              ),
                            );
                          },
                        )
                      else
                        Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.image_not_supported,
                              size: 60, color: Colors.grey),
                        ),

                      // Gradiente (IgnorePointer para no bloquear swipe)
                      IgnorePointer(
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black54],
                              stops: [0.6, 1.0],
                            ),
                          ),
                        ),
                      ),

                      // Puntos indicadores (IgnorePointer para no bloquear swipe)
                      if (images.length > 1)
                        Positioned(
                          bottom: 60,
                          left: 0,
                          right: 0,
                          child: IgnorePointer(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(images.length, (index) {
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  width: _currentImageIndex == index ? 24 : 8,
                                  height: 8,
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 4),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(4),
                                    color: _currentImageIndex == index
                                        ? Colors.white
                                        : Colors.white.withValues(alpha: 0.5),
                                  ),
                                );
                              }),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // --- 2. CONTENIDO PRINCIPAL ---
              SliverToBoxAdapter(
                child: Container(
                  transform: Matrix4.translationValues(0, -30, 0),
                  decoration: const BoxDecoration(
                    color: kBackgroundColor,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(30)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 35, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // TÍTULO Y UBICACIÓN
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.destino['nombre'] ?? 'Sin nombre',
                                    style: GoogleFonts.poppins(
                                        fontSize: 26,
                                        fontWeight: FontWeight.bold,
                                        color: kPrimaryColor,
                                        height: 1.2),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(Icons.location_on_outlined,
                                          color: Colors.grey, size: 18),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          locationText,
                                          style: GoogleFonts.poppins(
                                              fontSize: 14,
                                              color: Colors.grey[700],
                                              fontWeight: FontWeight.w500),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (mapsLink.isNotEmpty)
                              GestureDetector(
                                onTap: () => _openLink(mapsLink),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(
                                            color: Colors.black
                                                .withValues(alpha: 0.08),
                                            blurRadius: 15,
                                            offset: const Offset(0, 5))
                                      ]),
                                  child: const Icon(Icons.map_outlined,
                                      color: Colors.blueAccent),
                                ),
                              )
                          ],
                        ),

                        const SizedBox(height: 30),

                        // TÍTULO DE PAQUETES
                        Text(
                          "Selecciona tu experiencia",
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: kPrimaryColor,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          "Presiona 'Ver detalles' para conocer más.",
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 20),

                        // LISTA DE PAQUETES
                        if (paquetes.isEmpty)
                          _buildEmptyState()
                        else
                          ListView.separated(
                            padding: EdgeInsets.zero,
                            physics: const NeverScrollableScrollPhysics(),
                            shrinkWrap: true,
                            itemCount: paquetes.length,
                            separatorBuilder: (c, i) =>
                                const SizedBox(height: 15),
                            itemBuilder: (context, index) {
                              final paquete =
                                  paquetes[index] as Map<String, dynamic>;
                              final isSelected =
                                  selectedPackages.contains(paquete);

                              return _ExpandablePackageCard(
                                paquete: paquete,
                                isSelected: isSelected,
                                onToggleSelection: () =>
                                    _togglePackageSelection(paquete),
                              );
                            },
                          ),

                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // --- 3. BARRA INFERIOR ---
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  )
                ],
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Total estimado",
                            style: GoogleFonts.poppins(
                                fontSize: 12, color: Colors.grey),
                          ),
                          Text(
                            selectedPackages.isEmpty
                                ? "\$0.00"
                                : "\$${selectedPackages.fold<double>(0, (accumulator, item) => accumulator + (item['precio'] ?? 0)).toStringAsFixed(2)}",
                            style: GoogleFonts.poppins(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: kPrimaryColor),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    ElevatedButton(
                      onPressed: selectedPackages.isNotEmpty
                          ? () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ReservationScreen(
                                    userId: widget.userId,
                                    selectedPackages: selectedPackages,
                                    planName:
                                        widget.destino['nombre'] ?? 'Reserva',
                                    location: locationText,
                                    supplier: supplierId,
                                    // --- FIX CRÍTICO: PASAMOS EL ID CORRECTO ---
                                    destinationId: docId,
                                    // ------------------------------------------
                                  ),
                                ),
                              );
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryColor,
                        disabledBackgroundColor: Colors.grey[300],
                        padding: const EdgeInsets.symmetric(
                            horizontal: 35, vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: selectedPackages.isNotEmpty ? 5 : 0,
                      ),
                      child: Text(
                        "Continuar",
                        style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        children: [
          Icon(Icons.sentiment_dissatisfied, size: 40, color: Colors.grey[300]),
          const SizedBox(height: 10),
          Text("No hay paquetes disponibles",
              style: GoogleFonts.poppins(color: Colors.grey)),
        ],
      ),
    );
  }
}

// =============================================================================
// WIDGET: TARJETA DE PAQUETE EXPANDIBLE
// =============================================================================

class _ExpandablePackageCard extends StatefulWidget {
  final Map<String, dynamic> paquete;
  final bool isSelected;
  final VoidCallback onToggleSelection;

  const _ExpandablePackageCard({
    required this.paquete,
    required this.isSelected,
    required this.onToggleSelection,
  });

  @override
  State<_ExpandablePackageCard> createState() => _ExpandablePackageCardState();
}

class _ExpandablePackageCardState extends State<_ExpandablePackageCard>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    IconData iconType = Icons.local_activity_outlined;
    if (widget.paquete['tipo'] == 'dated') {
      iconType = Icons.calendar_month_outlined;
    } else if (widget.paquete['tipo'] == 'flexible') {
      iconType = Icons.confirmation_number_outlined;
    }

    // --- CÁLCULO SEGURO DE CUOTAS ---
    int cuotasCount = 0;
    if (widget.paquete['cantidadCuotas'] != null) {
      cuotasCount = widget.paquete['cantidadCuotas'];
    } else if (widget.paquete['configuracionCuotas'] is List) {
      cuotasCount = (widget.paquete['configuracionCuotas'] as List).length;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isSelected ? kPrimaryColor : Colors.grey.shade200,
          width: widget.isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(alpha: widget.isSelected ? 0.08 : 0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Column(
        children: [
          // --- HEADER ---
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: kPrimaryColor.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(iconType, color: kPrimaryColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.paquete['miniDescripcion'] ?? 'Paquete',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.black87),
                        ),
                        Text(
                          widget.paquete['tipo'] == 'dated'
                              ? 'Reserva por fecha'
                              : 'Ticket / Pase',
                          style: GoogleFonts.poppins(
                              fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "\$${widget.paquete['precio']}",
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.green[700]),
                      ),
                      const SizedBox(height: 5),
                      InkWell(
                        onTap: widget.onToggleSelection,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: widget.isSelected
                                  ? kPrimaryColor
                                  : Colors.transparent,
                              border: Border.all(
                                  color: widget.isSelected
                                      ? kPrimaryColor
                                      : Colors.grey.shade400,
                                  width: 2)),
                          child: widget.isSelected
                              ? const Icon(Icons.check,
                                  size: 16, color: Colors.white)
                              : null,
                        ),
                      )
                    ],
                  )
                ],
              ),
            ),
          ),

          // --- CUERPO ---
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _isExpanded
                ? Column(
                    children: [
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Detalles:",
                                style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: Colors.grey[700])),
                            const SizedBox(height: 8),
                            MarkdownBody(
                              data: widget.paquete['descripcion'] ??
                                  'Sin descripción detallada.',
                              styleSheet: MarkdownStyleSheet(
                                p: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: Colors.grey[800],
                                    height: 1.5),
                                strong: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold),
                                listBullet:
                                    const TextStyle(color: kPrimaryColor),
                              ),
                            ),
                            if (widget.paquete['tieneCuotas'] == true) ...[
                              const SizedBox(height: 15),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                    color: Colors.blue.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(8)),
                                child: Row(
                                  children: [
                                    const Icon(Icons.pie_chart_outline,
                                        size: 16, color: Colors.blue),
                                    const SizedBox(width: 8),
                                    Text(
                                        "Pago disponible en $cuotasCount cuotas",
                                        style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: Colors.blue[800],
                                            fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              )
                            ]
                          ],
                        ),
                      ),
                      InkWell(
                        onTap: () => setState(() => _isExpanded = false),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: const BorderRadius.vertical(
                                  bottom: Radius.circular(16))),
                          child: const Icon(Icons.keyboard_arrow_up,
                              color: Colors.grey),
                        ),
                      )
                    ],
                  )
                : InkWell(
                    onTap: () => setState(() => _isExpanded = true),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(16))),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("Ver detalles",
                              style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: kPrimaryColor,
                                  fontWeight: FontWeight.w500)),
                          const SizedBox(width: 4),
                          const Icon(Icons.keyboard_arrow_down,
                              size: 16, color: kPrimaryColor)
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
