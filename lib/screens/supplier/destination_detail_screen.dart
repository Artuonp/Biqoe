import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../reservation_screen.dart';

const Color kPrimaryColor = Color.fromRGBO(17, 48, 73, 1);
const Color kBackgroundColor = Color(0xFFF8F9FD);

class DestinationDetailScreen extends StatefulWidget {
  final String destinationId;
  final String userId;

  const DestinationDetailScreen({
    super.key,
    required this.destinationId,
    required this.userId,
  });

  @override
  DestinationDetailScreenState createState() => DestinationDetailScreenState();
}

class DestinationDetailScreenState extends State<DestinationDetailScreen> {
  final PageController _pageController = PageController();
  int _currentImageIndex = 0;

  // 🔥 SOLUCIÓN: Usamos List dinámico para los paquetes seleccionados
  List<dynamic> selectedPackages = [];

  // 🔥 SOLUCIÓN: Box sin tipado genérico estricto para evitar crash en Hive Web
  Box? savedDestinationsBox;
  Map<String, dynamic> fallbackSaved = {}; // Por si Hive falla
  bool isSaved = false;

  Map<String, dynamic>? _destino;
  bool _isLoading = true;
  String? _error;

  final String _projectId = 'biqoe-app';

  @override
  void initState() {
    super.initState();
    _initSavedBox().then((_) {
      _loadDestination();
    });
  }

  Future<void> _initSavedBox() async {
    try {
      savedDestinationsBox =
          await Hive.openBox('saved_destinations_${widget.userId}');
    } catch (e) {
      debugPrint('Hive no disponible en este entorno: $e');
    }
  }

  Future<void> _loadDestination() async {
    try {
      setState(() => _isLoading = true);

      final url =
          'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents/destinos/${widget.destinationId}';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        // Obtenemos los datos puros sin forzar tipos
        final dynamic data = jsonDecode(response.body);

        // Lo pasamos a nuestro convertidor inmune a JS
        final Map<String, dynamic> destino = _convertFirestoreMap(data);

        if (mounted) {
          setState(() {
            _destino = destino;
            _isLoading = false;

            final key = destino['id']?.toString() ??
                destino['nombre']?.toString() ??
                '';
            if (savedDestinationsBox != null) {
              isSaved = savedDestinationsBox!.containsKey(key);
            } else {
              isSaved = fallbackSaved.containsKey(key);
            }
          });
          _debugIncrementViewCount(); // fire-and-forget — no bloqueamos la UI
        }
      } else {
        if (mounted) {
          setState(() {
            _error = 'Error HTTP: ${response.statusCode}';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error procesando datos: $e';
          _isLoading = false;
        });
      }
    }
  }

  // =====================================================================
  // 🔥 EL CONVERTIDOR DEFINITIVO: 100% INMUNE A "MINIFIED ERRORS"
  // Recibe un 'dynamic' y analiza paso por paso sin usar 'as Map' en la cabecera
  // =====================================================================
  Map<String, dynamic> _convertFirestoreMap(dynamic firestoreDoc) {
    final result = <String, dynamic>{};

    if (firestoreDoc == null || firestoreDoc is! Map) {
      return result;
    }

    final fields = firestoreDoc['fields'];
    if (fields is Map) {
      for (final keyObj in fields.keys) {
        final String keyStr = keyObj.toString();
        final valueObj = fields[keyObj];

        if (valueObj is Map) {
          if (valueObj.containsKey('stringValue')) {
            result[keyStr] = valueObj['stringValue'];
          } else if (valueObj.containsKey('integerValue')) {
            result[keyStr] =
                int.tryParse(valueObj['integerValue'].toString()) ?? 0;
          } else if (valueObj.containsKey('doubleValue')) {
            var dv = valueObj['doubleValue'];
            result[keyStr] = (dv is num)
                ? dv.toDouble()
                : double.tryParse(dv.toString()) ?? 0.0;
          } else if (valueObj.containsKey('booleanValue')) {
            result[keyStr] = valueObj['booleanValue'] == true;
          } else if (valueObj.containsKey('timestampValue')) {
            result[keyStr] = valueObj['timestampValue'];
          } else if (valueObj.containsKey('arrayValue')) {
            var arrVal = valueObj['arrayValue'];
            if (arrVal is Map && arrVal.containsKey('values')) {
              var values = arrVal['values'];
              if (values is Iterable) {
                List<dynamic> list = [];
                for (var item in values) {
                  if (item is Map) {
                    if (item.containsKey('mapValue')) {
                      var mapVal = item['mapValue'];
                      if (mapVal is Map && mapVal.containsKey('fields')) {
                        list.add(
                            _convertFirestoreMap({'fields': mapVal['fields']}));
                      } else {
                        list.add(item);
                      }
                    } else {
                      list.add(_extractPrimitiveValue(item));
                    }
                  } else {
                    list.add(item);
                  }
                }
                result[keyStr] = list;
              } else {
                result[keyStr] = [];
              }
            } else {
              result[keyStr] = [];
            }
          } else if (valueObj.containsKey('mapValue')) {
            var mapVal = valueObj['mapValue'];
            if (mapVal is Map && mapVal.containsKey('fields')) {
              result[keyStr] =
                  _convertFirestoreMap({'fields': mapVal['fields']});
            } else {
              result[keyStr] = valueObj;
            }
          } else {
            result[keyStr] = valueObj;
          }
        } else {
          result[keyStr] = valueObj;
        }
      }
    }

    var name = firestoreDoc['name'];
    if (name is String) {
      final nameParts = name.split('/');
      result['id'] = nameParts.isNotEmpty ? nameParts.last : '';
    } else {
      result['id'] = '';
    }

    return result;
  }

  dynamic _extractPrimitiveValue(dynamic element) {
    if (element is Map) {
      if (element.containsKey('stringValue')) return element['stringValue'];
      if (element.containsKey('integerValue')) {
        return int.tryParse(element['integerValue'].toString()) ?? 0;
      }
      if (element.containsKey('doubleValue')) {
        var dv = element['doubleValue'];
        return (dv is num)
            ? dv.toDouble()
            : double.tryParse(dv.toString()) ?? 0.0;
      }
      if (element.containsKey('booleanValue')) {
        return element['booleanValue'] == true;
      }
    }
    return element;
  }

  // Incrementa las vistas del destino via REST — funciona en Safari/web
  // porque no depende del SDK de Firestore (que usa IndexedDB, bloqueado por Safari).
  // Usa el endpoint :commit con una transformación INCREMENT que es atómica.
  Future<void> _debugIncrementViewCount() async {
    if (_destino == null) return;

    final String? docId = _destino!['id']?.toString();
    final String supplierId = _destino!['supplierId']?.toString() ??
        _destino!['supplier']?.toString() ??
        '';

    if (docId == null || docId.isEmpty) return;
    if (widget.userId == supplierId) {
      return; // El proveedor no cuenta su propia visita
    }

    const String apiKey = 'AIzaSyD6gvIVnsBg9QSdP04gM3qgzEjKI5FjEEU';
    const String projectId = 'biqoe-app';

    try {
      // :commit con fieldTransform INCREMENT — idéntico a FieldValue.increment(1)
      // pero vía HTTP REST, compatible con Safari y cualquier navegador.
      final commitUrl =
          'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents:commit?key=$apiKey';

      final body = jsonEncode({
        'writes': [
          {
            'transform': {
              'document':
                  'projects/$projectId/databases/(default)/documents/destinos/$docId',
              'fieldTransforms': [
                {
                  'fieldPath': 'profileViews',
                  'increment': {'integerValue': '1'},
                }
              ],
            }
          }
        ]
      });

      final response = await http
          .post(
            Uri.parse(commitUrl),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 8));

      debugPrint(
          '[Views] increment destino=$docId status=${response.statusCode}');
    } catch (e) {
      debugPrint('[Views] error incrementando vistas: $e');
    }
  }

  void _toggleSaveDestination() {
    if (_destino == null) return;

    final destinationId =
        _destino!['id']?.toString() ?? _destino!['nombre']?.toString() ?? '';
    setState(() {
      if (savedDestinationsBox != null) {
        if (savedDestinationsBox!.containsKey(destinationId)) {
          savedDestinationsBox!.delete(destinationId);
          isSaved = false;
        } else {
          savedDestinationsBox!.put(destinationId, _destino!);
          isSaved = true;
        }
      } else {
        if (fallbackSaved.containsKey(destinationId)) {
          fallbackSaved.remove(destinationId);
          isSaved = false;
        } else {
          fallbackSaved[destinationId] = _destino!;
          isSaved = true;
        }
      }
    });
  }

  void _togglePackageSelection(dynamic paquete) {
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
    if (_isLoading) {
      return const Scaffold(
        body: Center(),
      );
    }

    if (_error != null || _destino == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: kBackgroundColor,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SelectableText(
              _error ?? 'Destino no encontrado\nID: ${widget.destinationId}',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ),
      );
    }

    final destino = _destino!;

    // Extracción de imágenes sin casteos forzados
    final List<String> images = [];
    final rawImages = destino['imagenes'] ?? destino['imagen'];
    if (rawImages is Iterable) {
      for (var img in rawImages) {
        images.add(img.toString());
      }
    } else if (rawImages is String) {
      images.add(rawImages);
    }

    String locationText = "Ubicación por definir";
    List<String> locParts = [];

    if (destino['lugar'] != null &&
        destino['lugar'].toString().isNotEmpty &&
        destino['lugar'].toString() != 'null') {
      locParts.add(destino['lugar'].toString());
    }
    if (destino['estado'] != null &&
        destino['estado'].toString().isNotEmpty &&
        destino['estado'].toString() != 'null') {
      locParts.add(destino['estado'].toString());
    }

    if (locParts.isNotEmpty) {
      locationText = locParts.join(", ");
    } else if (destino['ubicacion'] != null) {
      locationText = destino['ubicacion'].toString();
    }

    final String mapsLink = destino['googleMapsLink']?.toString() ??
        destino['coordenadas']?.toString() ??
        '';
    final String supplierId = destino['supplierId']?.toString() ??
        destino['supplier']?.toString() ??
        '';

    final rawPaquetes = destino['paquetes'];
    final List<dynamic> paquetes =
        rawPaquetes is Iterable ? rawPaquetes.toList() : [];
    final String docId =
        destino['id']?.toString() ?? destino['nombre']?.toString() ?? '';

    // Cálculo seguro del total a pagar
    double totalPrice = 0.0;
    for (var item in selectedPackages) {
      if (item is Map) {
        var p = item['precio'];
        if (p is num) {
          totalPrice += p.toDouble();
          // ignore: curly_braces_in_flow_control_structures
        } else if (p is String) totalPrice += (double.tryParse(p) ?? 0.0);
      }
    }

    // Símbolo de divisa según configuración del destino
    final String currencySymbol =
        destino['divisa']?.toString() == 'eur' ? '€' : '\$';

    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
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
                      shape: BoxShape.circle),
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
                        shape: BoxShape.circle),
                    child: IconButton(
                      icon: Icon(
                        isSaved ? Icons.favorite : Icons.favorite_border,
                        color: isSaved ? kPrimaryColor : Colors.black,
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
                      if (images.length > 1)
                        Positioned(
                          bottom: 16,
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
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
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
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        destino['nombre']?.toString() ??
                                            'Sin nombre',
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
                                          borderRadius:
                                              BorderRadius.circular(14),
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
                            Text(
                              "Selecciona tu experiencia",
                              style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: kPrimaryColor),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              "Presiona 'Ver detalles' para conocer más.",
                              style: GoogleFonts.poppins(
                                  fontSize: 12, color: Colors.grey),
                            ),
                            const SizedBox(height: 20),
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
                                  final paquete = paquetes[index] is Map
                                      ? paquetes[index]
                                      : {};
                                  final isSelected =
                                      selectedPackages.contains(paquete);

                                  return _ExpandablePackageCard(
                                    paquete: paquete,
                                    isSelected: isSelected,
                                    onToggleSelection: () =>
                                        _togglePackageSelection(paquete),
                                    currencySymbol: currencySymbol,
                                  );
                                },
                              ),
                            const SizedBox(height: 100),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 20,
                          offset: const Offset(0, -5))
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
                              Text("Total estimado",
                                  style: GoogleFonts.poppins(
                                      fontSize: 12, color: Colors.grey)),
                              Text(
                                "$currencySymbol${totalPrice.toStringAsFixed(2)}",
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
                                        selectedPackages:
                                            selectedPackages.map((e) {
                                          final safeMap = <String, dynamic>{};
                                          if (e is Map) {
                                            for (var k in e.keys) {
                                              safeMap[k.toString()] = e[k];
                                            }
                                          }
                                          return safeMap;
                                        }).toList(),
                                        planName:
                                            destino['nombre']?.toString() ??
                                                'Reserva',
                                        location: locationText,
                                        supplier: supplierId,
                                        destinationId: docId,
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
                          child: Text("Continuar",
                              style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
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

class _ExpandablePackageCard extends StatefulWidget {
  final dynamic paquete;
  final bool isSelected;
  final VoidCallback onToggleSelection;
  final String currencySymbol;

  const _ExpandablePackageCard({
    required this.paquete,
    required this.isSelected,
    required this.onToggleSelection,
    this.currencySymbol = '\$',
  });

  @override
  State<_ExpandablePackageCard> createState() => _ExpandablePackageCardState();
}

class _ExpandablePackageCardState extends State<_ExpandablePackageCard>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final Map pq = widget.paquete is Map ? widget.paquete as Map : {};

    IconData iconType = Icons.local_activity_outlined;
    if (pq['tipo'] == 'dated') {
      iconType = Icons.calendar_month_outlined;
    } else if (pq['tipo'] == 'flexible')
      // ignore: curly_braces_in_flow_control_structures
      iconType = Icons.confirmation_number_outlined;

    int cuotasCount = 0;
    if (pq['cantidadCuotas'] != null) {
      final cq = pq['cantidadCuotas'];
      if (cq is num) {
        cuotasCount = cq.toInt();
        // ignore: curly_braces_in_flow_control_structures
      } else if (cq is String) cuotasCount = int.tryParse(cq) ?? 0;
    } else if (pq['configuracionCuotas'] is Iterable) {
      cuotasCount = (pq['configuracionCuotas'] as Iterable).length;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: widget.isSelected ? kPrimaryColor : Colors.grey.shade200,
            width: widget.isSelected ? 2 : 1),
        boxShadow: [
          BoxShadow(
              color: Colors.black
                  .withValues(alpha: widget.isSelected ? 0.08 : 0.03),
              blurRadius: 15,
              offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        children: [
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
                        borderRadius: BorderRadius.circular(10)),
                    child: Icon(iconType, color: kPrimaryColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pq['miniDescripcion']?.toString() ?? 'Paquete',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.black87),
                        ),
                        Text(
                          pq['tipo'] == 'dated'
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
                        "${widget.currencySymbol}${pq['precio'] ?? '0'}",
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
                              data: pq['descripcion']?.toString() ??
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
                            if (pq['tieneCuotas'] == true) ...[
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
