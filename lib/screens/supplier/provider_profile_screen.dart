import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'dart:convert';

// --- IMPORTS NECESARIOS ---
import 'destination_detail_screen.dart';
import '../../services/chat_service.dart';
import '../chat_detail_screen.dart';
import '../../main_screen.dart';

class ProviderProfileScreen extends StatefulWidget {
  final String slug;
  final String currentUserId;

  const ProviderProfileScreen({
    super.key,
    required this.slug,
    this.currentUserId = 'guest',
  });

  @override
  State<ProviderProfileScreen> createState() => _ProviderProfileScreenState();
}

class _ProviderProfileScreenState extends State<ProviderProfileScreen> {
  final Color primaryColor = const Color.fromRGBO(17, 48, 73, 1);
  final Color backgroundColor = const Color(0xFFF3F7FE);

  Box? _followedProvidersBox;
  late Future<Map<String, dynamic>?> _profileFuture;
  String? _initError;

  // ID del proyecto Firebase (cámbialo por el tuyo)
  final String _projectId = 'biqoe-app';

  @override
  void initState() {
    super.initState();
    _initHive();

    try {
      if (widget.slug.isEmpty) {
        throw Exception('El slug está vacío');
      }

      debugPrint(
          'Slug original: "${widget.slug}" (${widget.slug.runtimeType})');

      _profileFuture = _getUserBySlugViaRest(widget.slug);

      _incrementViewCount();
    } catch (e, stack) {
      debugPrint('Error SÍNCRONO en initState: $e\n$stack');
      _initError =
          'Error al iniciar: $e\nSlug: "${widget.slug}"\nTipo: ${widget.slug.runtimeType}';
      _profileFuture = Future.error(e);
    }
  }

  // --- FUNCIONES HTTP REST ---

  Future<Map<String, dynamic>?> _getUserBySlugViaRest(String slug) async {
    try {
      // 1. Obtener el documento de slugs vía REST
      final slugsUrl =
          'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents/metadata/slugs';
      final slugsResponse = await http.get(Uri.parse(slugsUrl));

      if (slugsResponse.statusCode != 200) {
        debugPrint('Error obteniendo slugs: ${slugsResponse.body}');
        return null;
      }

      final slugsData = jsonDecode(slugsResponse.body);
      if (slugsData['fields'] == null ||
          slugsData['fields']['mapping'] == null ||
          slugsData['fields']['mapping']['mapValue'] == null ||
          slugsData['fields']['mapping']['mapValue']['fields'] == null) {
        debugPrint('Estructura de slugs inesperada: ${slugsData.toString()}');
        return null;
      }

      final mapping = slugsData['fields']['mapping']['mapValue']['fields'];

      final slugKey = slug.toLowerCase();
      if (!mapping.containsKey(slugKey)) {
        debugPrint('Slug no encontrado: $slugKey');
        return null;
      }

      final userId = mapping[slugKey]['stringValue'];

      // 2. Obtener el documento del usuario vía REST
      final userUrl =
          'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents/usuarios/$userId';
      final userResponse = await http.get(Uri.parse(userUrl));

      if (userResponse.statusCode != 200) {
        debugPrint('Error obteniendo usuario: ${userResponse.body}');
        return null;
      }

      final userData = jsonDecode(userResponse.body);
      return _convertFirestoreMap(userData);
    } catch (e, stack) {
      debugPrint('Error en _getUserBySlugViaRest: $e\n$stack');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> _getActivitiesBySupplierViaRest(
      String supplierId) async {
    try {
      final url =
          'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents:runQuery';
      final body = {
        'structuredQuery': {
          'from': [
            {'collectionId': 'destinos'}
          ],
          'where': {
            'fieldFilter': {
              'field': {'fieldPath': 'supplierId'},
              'op': 'EQUAL',
              'value': {'stringValue': supplierId}
            }
          }
        }
      };
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      if (response.statusCode != 200) {
        debugPrint('Error obteniendo actividades: ${response.body}');
        return [];
      }
      final List<dynamic> data = jsonDecode(response.body);
      final List<Map<String, dynamic>> activities = [];
      for (var item in data) {
        if (item['document'] != null) {
          activities.add(_convertFirestoreMap(item['document']));
        }
      }
      return activities;
    } catch (e, stack) {
      debugPrint('Error en _getActivitiesBySupplierViaRest: $e\n$stack');
      rethrow;
    }
  }

  // Conversor mejorado que maneja arrays de objetos correctamente
  Map<String, dynamic> _convertFirestoreMap(Map<String, dynamic> firestoreDoc) {
    final result = <String, dynamic>{};

    final fields = firestoreDoc['fields'];
    if (fields is Map) {
      fields.forEach((key, value) {
        if (value is Map) {
          if (value.containsKey('stringValue')) {
            result[key] = value['stringValue'];
          } else if (value.containsKey('integerValue')) {
            result[key] = int.tryParse(value['integerValue']) ?? 0;
          } else if (value.containsKey('doubleValue')) {
            result[key] = value['doubleValue'];
          } else if (value.containsKey('booleanValue')) {
            result[key] = value['booleanValue'];
          } else if (value.containsKey('timestampValue')) {
            result[key] = value['timestampValue'];
          } else if (value.containsKey('arrayValue')) {
            final arrayValues = value['arrayValue']['values'];
            if (arrayValues is List) {
              final List<dynamic> convertedList = [];
              for (var element in arrayValues) {
                if (element is Map) {
                  if (element.containsKey('mapValue')) {
                    final nestedFields = element['mapValue']?['fields'];
                    if (nestedFields is Map) {
                      convertedList
                          .add(_convertFirestoreMap({'fields': nestedFields}));
                    } else {
                      convertedList.add(element);
                    }
                  } else {
                    // Es un valor primitivo dentro del array
                    convertedList.add(_extractPrimitiveValue(element));
                  }
                } else {
                  // No es mapa, agregar tal cual
                  convertedList.add(element);
                }
              }
              result[key] = convertedList;
            } else {
              result[key] = [];
            }
          } else if (value.containsKey('mapValue')) {
            final nestedFields = value['mapValue']?['fields'];
            if (nestedFields is Map) {
              result[key] = _convertFirestoreMap({'fields': nestedFields});
            } else {
              result[key] = value;
            }
          } else {
            result[key] = value;
          }
        } else {
          debugPrint('Valor no es mapa para clave $key: $value');
          result[key] = value;
        }
      });
    } else {
      debugPrint('fields no es un mapa: $fields');
    }

    final name = firestoreDoc['name'];
    if (name is String) {
      final nameParts = name.split('/');
      result['id'] = nameParts.last;
    } else {
      result['id'] = '';
    }

    return result;
  }

  dynamic _extractPrimitiveValue(Map element) {
    // Acepta cualquier Map (claves dynamic, valores dynamic)
    if (element.containsKey('stringValue')) return element['stringValue'];
    if (element.containsKey('integerValue')) {
      return int.tryParse(element['integerValue']) ?? 0;
    }
    if (element.containsKey('doubleValue')) return element['doubleValue'];
    if (element.containsKey('booleanValue')) return element['booleanValue'];
    return element;
  }

  // --- CONTADOR DE VISTAS ---
  Future<void> _incrementViewCount() async {
    try {
      final userData = await _profileFuture;
      if (userData != null && userData['id'] != widget.currentUserId) {
        await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(userData['id'])
            .update({
          'profileViews': FieldValue.increment(1),
          'lastViewedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (_) {}
  }

  // --- HIVE: SEGUIR PROVEEDOR ---
  Future<void> _initHive() async {
    if (kIsWeb) return; // No usar Hive en web
    if (widget.currentUserId.isNotEmpty && widget.currentUserId != 'guest') {
      try {
        _followedProvidersBox =
            await Hive.openBox('followed_providers_${widget.currentUserId}');
        if (mounted) setState(() {});
      } catch (e) {
        debugPrint("Error abriendo Hive: $e");
      }
    }
  }

  // --- LÓGICA DE BÚSQUEDA DE RESERVA ---
  // Usa REST API en lugar de Firestore SDK para compatibilidad con Safari web.
  void _showBookingSearchDialog(String providerId) {
    final TextEditingController searchCtrl = TextEditingController();
    // Usamos StatefulBuilder para poder mostrar estado de carga DENTRO del diálogo
    // sin cerrarlo — esto es clave para Safari donde cerrar+abrir diálogos
    // en secuencia rápida causa que el segundo nunca aparezca.
    bool isSearching = false;
    String? errorMsg;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text("Buscar Reserva",
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.bold,
                  color: primaryColor)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Ingresa tu código de reserva para ver los detalles.",
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 13)),
              const SizedBox(height: 15),
              TextField(
                controller: searchCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: "Ej: A1B2C3D4",
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              if (errorMsg != null) ...[
                const SizedBox(height: 10),
                Text(errorMsg!,
                    style: const TextStyle(color: Colors.red, fontSize: 12)),
              ],
              if (isSearching) ...[
                const SizedBox(height: 16),
                const CircularProgressIndicator(),
              ],
            ],
          ),
          actions: [
            TextButton(
                onPressed:
                    isSearching ? null : () => Navigator.pop(dialogContext),
                child: const Text("Cancelar",
                    style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              onPressed: isSearching
                  ? null
                  : () async {
                      final code = searchCtrl.text.trim().toUpperCase();
                      if (code.isEmpty) return;

                      // 🔥 FIX: Capturamos el Navigator ANTES de cualquier await
                      final nav = Navigator.of(dialogContext);

                      setDialogState(() {
                        isSearching = true;
                        errorMsg = null;
                      });

                      try {
                        const String apiKey =
                            'AIzaSyD6gvIVnsBg9QSdP04gM3qgzEjKI5FjEEU';

                        debugPrint('[Reserva] Buscando código: $code');
                        debugPrint('[Reserva] ProviderId: $providerId');

                        // ── ESTRATEGIA ───────────────────────────────────────
                        // Ruta real: reservaciones/{supplierId}/reservas/{docId}
                        //
                        // Firestore REST runQuery para subcolecciones:
                        // - La URL debe apuntar al DOCUMENTO PADRE (reservaciones/{id}),
                        //   NO a la subcolección. El error 400 "lacks /" ocurre cuando
                        //   la URL apunta a la subcolección directamente.
                        // - El "from" en el body especifica la subcolección a buscar.
                        //
                        // URL correcta: .../documents/reservaciones/{providerId}:runQuery
                        // Body: from: [{collectionId: 'reservas'}]
                        final queryUrl =
                            'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents/reservaciones/$providerId:runQuery?key=$apiKey';

                        final queryBody = jsonEncode({
                          'structuredQuery': {
                            'from': [
                              {'collectionId': 'reservas'}
                            ],
                            'where': {
                              'fieldFilter': {
                                'field': {'fieldPath': 'code'},
                                'op': 'EQUAL',
                                'value': {'stringValue': code}
                              }
                            },
                            'limit': 1
                          }
                        });

                        debugPrint('[Reserva] URL: $queryUrl');
                        debugPrint('[Reserva] Body: $queryBody');

                        final response = await http
                            .post(
                              Uri.parse(queryUrl),
                              headers: {'Content-Type': 'application/json'},
                              body: queryBody,
                            )
                            .timeout(const Duration(seconds: 12));

                        debugPrint(
                            '[Reserva] HTTP status: ${response.statusCode}');
                        debugPrint('[Reserva] Response body: ${response.body}');

                        Map<String, dynamic>? foundData;

                        if (response.statusCode == 200) {
                          final List<dynamic> results =
                              jsonDecode(response.body);
                          debugPrint(
                              '[Reserva] Resultados count: ${results.length}');
                          for (int i = 0; i < results.length; i++) {
                            debugPrint(
                                '[Reserva] results[$i] keys: ${results[i].keys.toList()}');
                          }
                          if (results.isNotEmpty &&
                              results[0]['document'] != null) {
                            final doc = results[0]['document'];
                            final docId =
                                (doc['name'] as String).split('/').last;
                            foundData = _convertFirestoreMap(doc);
                            foundData['id'] = docId;
                            debugPrint(
                                '[Reserva] ✅ Encontrada: docId=$docId code=${foundData['code']}');
                          } else {
                            debugPrint(
                                '[Reserva] ❌ Sin resultados (document null en todos)');
                          }
                        } else {
                          debugPrint(
                              '[Reserva] ❌ runQuery falló con ${response.statusCode}');
                        }

                        // ── PLAN B: listDocuments ─────────────────────────────
                        // Si runQuery no encontró nada (por error o resultado vacío),
                        // listamos todos los docs de la subcolección y filtramos en cliente.
                        if (foundData == null) {
                          debugPrint('[Reserva] Plan B: GET listDocuments');
                          final listUrl =
                              'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents/reservaciones/$providerId/reservas?key=$apiKey&pageSize=300';
                          final listResponse = await http
                              .get(Uri.parse(listUrl))
                              .timeout(const Duration(seconds: 12));
                          debugPrint(
                              '[Reserva] Plan B status: ${listResponse.statusCode}');
                          if (listResponse.statusCode == 200) {
                            final listData = jsonDecode(listResponse.body);
                            final docs = listData['documents'] as List? ?? [];
                            debugPrint(
                                '[Reserva] Plan B docs count: ${docs.length}');
                            for (final doc in docs) {
                              final converted = _convertFirestoreMap(doc);
                              final docCode =
                                  converted['code']?.toString() ?? '';
                              debugPrint(
                                  '[Reserva] Plan B checking code=$docCode');
                              if (docCode == code) {
                                final docId =
                                    (doc['name'] as String).split('/').last;
                                foundData = converted;
                                foundData['id'] = docId;
                                debugPrint(
                                    '[Reserva] ✅ Plan B encontrado: docId=$docId');
                                break;
                              }
                            }
                            if (foundData == null) {
                              debugPrint(
                                  '[Reserva] ❌ Plan B: código no existe en ${docs.length} docs');
                            }
                          } else {
                            debugPrint(
                                '[Reserva] ❌ Plan B error: ${listResponse.body}');
                          }
                        }

                        if (!mounted) return;
                        nav.pop(); // 🔥 Usamos la variable segura que capturamos arriba

                        if (foundData != null) {
                          _showReservationDetail(context, foundData);
                        } else {
                          // Mensaje amigable — no un snackbar genérico
                          showDialog(
                            context: context,
                            builder: (ctx) => Dialog(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20)),
                              child: Padding(
                                padding: const EdgeInsets.all(28),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.search_off_rounded,
                                        size: 56, color: Colors.grey[400]),
                                    const SizedBox(height: 16),
                                    Text('Código no encontrado',
                                        style: TextStyle(
                                            fontFamily: 'Poppins',
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                            color: primaryColor)),
                                    const SizedBox(height: 10),
                                    Text(
                                        'No encontramos ninguna reserva con el código "$code". '
                                        'Verifica que lo hayas escrito correctamente.',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                            fontFamily: 'Poppins',
                                            color: Colors.black54,
                                            fontSize: 13)),
                                    const SizedBox(height: 24),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        style: ElevatedButton.styleFrom(
                                            backgroundColor: primaryColor,
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12)),
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 12)),
                                        child: const Text('Intentar de nuevo',
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontFamily: 'Poppins')),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }
                      } catch (e, stack) {
                        debugPrint('[Reserva] EXCEPCIÓN: $e');
                        debugPrint('[Reserva] Stack: $stack');
                        if (!mounted) return;
                        setDialogState(() {
                          isSearching = false;
                          errorMsg =
                              "Error de conexión. Verifica tu internet e intenta de nuevo.";
                        });
                      }
                    },
              style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              child:
                  const Text("Buscar", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // --- DIÁLOGO DE DETALLE DE RESERVA ---
  void _showReservationDetail(BuildContext context, Map<String, dynamic> data) {
    double total = 0.0;
    double paid = 0.0;

    if (data['totalPlanPrice'] is num) {
      total = (data['totalPlanPrice'] as num).toDouble();
    }
    if (data['amountPaid'] is num) {
      paid = (data['amountPaid'] as num).toDouble();
    }

    final String status = data['estado']?.toString() ?? 'pendiente';
    final bool isVerified = status == 'verificado';
    final String qrData = data['code']?.toString() ?? '';
    final String qrUrl =
        "https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=$qrData&color=113049";

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 20, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Detalle de reserva",
                          style: TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: primaryColor)),
                      IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: () => Navigator.pop(ctx))
                    ],
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                            color: isVerified
                                ? Colors.green.withValues(alpha: 0.1)
                                : Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20)),
                        child: Text(isVerified ? "VERIFICADO" : "PENDIENTE",
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color:
                                    isVerified ? Colors.green : Colors.orange)),
                      ),
                      const SizedBox(height: 20),
                      Text(data['planName']?.toString() ?? 'Actividad',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 5),
                      Text(data['planLocation']?.toString() ?? '',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              color: Colors.grey[600])),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4))
                            ]),
                        child: Column(
                          children: [
                            Image.network(qrUrl,
                                width: 140,
                                height: 140,
                                loadingBuilder: (c, child, p) => p == null
                                    ? child
                                    : const SizedBox(
                                        width: 140,
                                        height: 140,
                                        child: Center()),
                                errorBuilder: (c, o, s) =>
                                    const Icon(Icons.error)),
                            const SizedBox(height: 10),
                            Text(qrData,
                                style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                    letterSpacing: 3,
                                    color: primaryColor)),
                            const SizedBox(height: 4),
                            const Text("Muestra este código al llegar",
                                style:
                                    TextStyle(fontSize: 10, color: Colors.grey))
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12)),
                        child: Column(
                          children: [
                            _detailRow(
                                "Total:", "\$${total.toStringAsFixed(2)}"),
                            const SizedBox(height: 8),
                            _detailRow(
                                "Abonado:", "\$${paid.toStringAsFixed(2)}",
                                isBold: true, color: Colors.green),
                            const Divider(height: 20),
                            _detailRow("Restante:",
                                "\$${(total - paid).toStringAsFixed(2)}",
                                isBold: true,
                                color: (total - paid) > 1
                                    ? Colors.red
                                    : Colors.grey),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value,
      {bool isBold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontFamily: 'Poppins', fontSize: 13, color: Colors.grey[700])),
        Text(value,
            style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: color ?? Colors.black87)),
      ],
    );
  }

  // --- HELPER: detecta guest tanto en web ('guest' string) como en la app (anónimo) ---
  bool get _isGuest {
    if (widget.currentUserId == 'guest' || widget.currentUserId.isEmpty) {
      return true;
    }
    try {
      return FirebaseAuth.instance.currentUser?.isAnonymous ?? true;
    } catch (_) {
      return true;
    }
  }

  // --- SEGUIR PROVEEDOR ---
  void _toggleFollow(String providerId, Map<String, dynamic> providerData) {
    if (_isGuest) {
      _showLoginDialog();
      return;
    }
    if (_followedProvidersBox == null) return;

    if (_followedProvidersBox!.containsKey(providerId)) {
      _followedProvidersBox!.delete(providerId);
    } else {
      _followedProvidersBox!.put(providerId, {
        'id': providerId,
        'name': providerData['name'],
        'imagen': providerData['imagen'],
        'verified': providerData['verified'],
      });
    }
  }

  // --- INICIAR CHAT ---
  void _handleMessageTap(
      String providerId, Map<String, dynamic> providerData) async {
    if (_isGuest) {
      _showLoginDialog();
      return;
    }
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center());

    try {
      final chatService = ChatService();
      final currentUserDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(widget.currentUserId)
          .get();

      if (!currentUserDoc.exists) throw "Usuario no encontrado";

      final currentUserData = {...(currentUserDoc.data() ?? {})};

      final chatId = await chatService.getOrCreateChat(
        userId: widget.currentUserId,
        supplierId: providerId,
        userData: {
          'nombre': currentUserData['name']?.toString() ?? 'Usuario',
          'imagen': currentUserData['imagen']?.toString() ?? '',
        },
        supplierData: {
          'nombre': providerData['name']?.toString() ?? 'Proveedor',
          'imagen': providerData['imagen']?.toString() ?? '',
        },
      ).timeout(const Duration(seconds: 10));

      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (mounted) {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => ChatDetailScreen(
                    chatId: chatId,
                    otherName: providerData['name']?.toString() ?? 'Proveedor',
                    otherImage: providerData['imagen']?.toString() ?? '',
                    currentUserId: widget.currentUserId)));
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error al abrir el chat: $e")));
      }
    }
  }

  // --- DIÁLOGO DE LOGIN ---
  void _showLoginDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(25.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(HugeIcons.strokeRoundedUserCircle,
                  size: 50, color: Color.fromRGBO(17, 48, 73, 1)),
              const SizedBox(height: 15),
              const Text("Inicia sesión",
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color.fromRGBO(17, 48, 73, 1))),
              const SizedBox(height: 10),
              const Text(
                  "Para contactar o seguir al proveedor necesitas una cuenta en Biqoe.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Poppins', color: Colors.grey)),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()));
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromRGBO(17, 48, 73, 1),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  child: const Text("Ir al login",
                      style: TextStyle(
                          color: Colors.white, fontFamily: 'Poppins')),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancelar",
                      style:
                          TextStyle(color: Colors.grey, fontFamily: 'Poppins')))
            ],
          ),
        ),
      ),
    );
  }

  // --- BUILD PRINCIPAL ---
  @override
  Widget build(BuildContext context) {
    if (_initError != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SelectableText('Error: $_initError'),
          ),
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;

    return FutureBuilder<Map<String, dynamic>?>(
      future: _profileFuture,
      builder: (context, snapshot) {
        try {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
                body: Center(
                    child: CircularProgressIndicator(
                        color: Color.fromRGBO(17, 48, 73, 1))));
          }

          if (snapshot.hasError) {
            return Scaffold(
                appBar: AppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    leading: const BackButton(color: Colors.black)),
                body: Center(
                  child: Text('Error: ${snapshot.error}'),
                ));
          }

          final userData = snapshot.data;
          if (userData == null || userData.isEmpty) {
            return Scaffold(
                appBar: AppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    leading: const BackButton(color: Colors.black)),
                body: _buildNotFoundState());
          }

          final String realProviderId = userData['id'] ?? '';

          return Scaffold(
            backgroundColor: backgroundColor,
            extendBodyBehindAppBar: true,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: Padding(
                padding: const EdgeInsets.only(left: 10, top: 10),
                child: _buildCircleButton(
                  icon: Icons.arrow_back,
                  color: Colors.black,
                  onPressed: () {
                    // Si es guest, mostrar diálogo de login
                    if (_isGuest) {
                      _showLoginDialog();
                    } else {
                      if (Navigator.canPop(context)) Navigator.pop(context);
                    }
                  },
                ),
              ),
              actions: [
                if (_followedProvidersBox != null)
                  ValueListenableBuilder(
                    valueListenable: _followedProvidersBox!.listenable(),
                    builder: (context, box, child) {
                      final bool isFollowing =
                          _followedProvidersBox!.containsKey(realProviderId);
                      return Padding(
                        padding: const EdgeInsets.only(top: 10, right: 10),
                        child: _buildCircleButton(
                          icon: isFollowing
                              ? Icons.how_to_reg
                              : Icons.person_add_alt_1,
                          color: isFollowing ? primaryColor : Colors.grey,
                          onPressed: () =>
                              _toggleFollow(realProviderId, userData),
                        ),
                      );
                    },
                  ),
                Padding(
                  padding: const EdgeInsets.only(right: 20, top: 10),
                  child: _buildCircleButton(
                      icon: HugeIcons.strokeRoundedMessage01,
                      color: Colors.black,
                      onPressed: () =>
                          _handleMessageTap(realProviderId, userData)),
                ),
              ],
            ),
            body: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  _buildProviderHeader(screenWidth, userData, realProviderId),
                  const SizedBox(height: 20),
                  _buildProviderActivities(screenWidth, realProviderId),
                  const SizedBox(height: 50),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 40),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("Experiencia facilitada por ",
                            style: TextStyle(
                                color: Colors.grey[400],
                                fontFamily: 'Poppins',
                                fontSize: 12)),
                        const Text("Biqoe",
                            style: TextStyle(
                                color: Color.fromRGBO(17, 48, 73, 1),
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                      ],
                    ),
                  )
                ],
              ),
            ),
          );
        } catch (e, stack) {
          debugPrint('ERROR EN FUTUREBUILDER: $e\n$stack');
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: SelectableText('Error en FutureBuilder: $e'),
              ),
            ),
          );
        }
      },
    );
  }

  // --- BOTÓN CIRCULAR ---
  Widget _buildCircleButton(
      {required IconData icon,
      required VoidCallback onPressed,
      required Color color}) {
    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withAlpha((0.1 * 200).round()),
                blurRadius: 2,
                spreadRadius: 0.01,
                offset: const Offset(0, 0.001))
          ]),
      child: IconButton(
          icon: Icon(icon, color: color, size: 22), onPressed: onPressed),
    );
  }

  // --- ESTADO NO ENCONTRADO ---
  Widget _buildNotFoundState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(HugeIcons.strokeRoundedSad01, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 20),
          Text("Proveedor no encontrado",
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600])),
        ],
      ),
    );
  }

  // --- CABECERA DEL PROVEEDOR ---
  Widget _buildProviderHeader(
      double screenWidth, Map<String, dynamic> data, String providerId) {
    final String name = data['name']?.toString() ?? 'Proveedor';
    final String imageUrl = data['imagen']?.toString() ?? '';
    final String description = data['descripcion']?.toString() ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(25, 100, 25, 30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(35), bottomRight: Radius.circular(35)),
        boxShadow: [
          BoxShadow(
              color: primaryColor.withValues(alpha: 0.04),
              blurRadius: 20,
              offset: const Offset(0, 10))
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: primaryColor.withValues(alpha: 0.1), width: 1),
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 15,
                      offset: const Offset(0, 5))
                ]),
            child: ClipOval(
              child: SizedBox(
                width: 90,
                height: 90,
                child: imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) =>
                            Container(color: Colors.grey[100]),
                        errorWidget: (context, url, error) => Container(
                            color: Colors.grey[100],
                            child: Icon(Icons.person,
                                size: 40, color: Colors.grey[300])))
                    : Container(
                        color: Colors.grey[100],
                        child: Center(
                            child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: TextStyle(
                                    fontSize: 35,
                                    color: primaryColor,
                                    fontWeight: FontWeight.bold)))),
              ),
            ),
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                  child: Text(name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color.fromRGBO(17, 48, 73, 1),
                          letterSpacing: -0.5))),
              if (data['verified'] == true) ...[
                const SizedBox(width: 5),
                const Icon(Icons.verified, color: Colors.blueAccent, size: 20)
              ]
            ],
          ),
          const SizedBox(height: 10),
          if (description.isNotEmpty)
            MarkdownBody(
                data: description,
                styleSheet: MarkdownStyleSheet(
                    p: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        color: Colors.grey[600],
                        height: 1.5),
                    strong: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800]),
                    textAlign: WrapAlignment.center,
                    pPadding: EdgeInsets.zero)),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () => _showBookingSearchDialog(providerId),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                  color: const Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: const Color(0xFFEEEEEE))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(HugeIcons.strokeRoundedSearch01,
                      size: 18, color: Colors.grey[500]),
                  const SizedBox(width: 8),
                  Text("¿Ya reservaste? Busca tu código aquí",
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- LISTA DE ACTIVIDADES (USANDO HTTP) ---
  Widget _buildProviderActivities(double screenWidth, String providerId) {
    try {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: Row(
              children: [
                Container(
                    width: 4,
                    height: 24,
                    decoration: BoxDecoration(
                        color: primaryColor,
                        borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 10),
                Text("Actividades disponibles",
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800])),
              ],
            ),
          ),
          const SizedBox(height: 15),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _getActivitiesBySupplierViaRest(providerId),
            builder: (context, snapshot) {
              try {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator()));
                }
                if (snapshot.hasError) {
                  return Center(
                    child:
                        Text('Error al cargar actividades: ${snapshot.error}'),
                  );
                }
                final activities = snapshot.data ?? [];
                if (activities.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 40, horizontal: 30),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(HugeIcons.strokeRoundedTicket01,
                              size: 40, color: Colors.grey[300]),
                          const SizedBox(height: 10),
                          Text("No hay actividades activas.",
                              style: TextStyle(
                                  fontFamily: 'Poppins',
                                  color: Colors.grey[400])),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: activities.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 20),
                  itemBuilder: (context, index) {
                    try {
                      final data = activities[index];

                      // Calcular precio mínimo desde paquetes
                      double minPrice = 0.0;
                      final rawPaquetes = data['paquetes'];
                      if (rawPaquetes is List) {
                        List<double> precios = [];
                        for (var p in rawPaquetes) {
                          if (p is Map && p['precio'] != null) {
                            var val = p['precio'];
                            if (val is num) {
                              precios.add(val.toDouble());
                            } else if (val is String) {
                              precios.add(double.tryParse(val) ?? 0.0);
                            }
                          }
                        }
                        if (precios.isNotEmpty) {
                          minPrice = precios.reduce((a, b) => a < b ? a : b);
                        }
                      }

                      // Obtener imagen de portada
                      String displayImage = '';
                      final rawImagenes = data['imagenes'];
                      final rawImagen = data['imagen'];

                      if (rawImagenes is List && rawImagenes.isNotEmpty) {
                        displayImage = rawImagenes[0].toString();
                      } else if (rawImagen is String) {
                        displayImage = rawImagen;
                      } else if (rawImagen is List && rawImagen.isNotEmpty) {
                        displayImage = rawImagen[0].toString();
                      }

                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DestinationDetailScreen(
                                destinationId:
                                    data['id'] ?? '', // Pasamos solo el ID
                                userId: widget.currentUserId,
                              ),
                            ),
                          );
                        },
                        child: ProviderActivityCard(
                          imageUrl: displayImage,
                          title: data['nombre']?.toString() ??
                              'Actividad sin nombre',
                          location: data['lugar']?.toString() ??
                              (data['estado']?.toString() ?? ''),
                          price: minPrice,
                        ),
                      );
                    } catch (e, stack) {
                      debugPrint('ERROR EN ITEM BUILDER: $e\n$stack');
                      return Container(
                        height: 100,
                        color: Colors.red.shade100,
                        child: Center(
                          child: Text(
                            'Error al mostrar actividad: $e',
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      );
                    }
                  },
                );
              } catch (e, stack) {
                debugPrint('ERROR EN FUTUREBUILDER DE ACTIVIDADES: $e\n$stack');
                return Center(
                  child: Text('Error cargando actividades: $e'),
                );
              }
            },
          ),
        ],
      );
    } catch (e, stack) {
      debugPrint('ERROR EN _buildProviderActivities: $e\n$stack');
      return Center(
        child: Text('Error cargando actividades: $e'),
      );
    }
  }
}

// --- TARJETA DE ACTIVIDAD (SIN CAMBIOS) ---
class ProviderActivityCard extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String location;
  final double price;

  const ProviderActivityCard(
      {super.key,
      required this.imageUrl,
      required this.title,
      required this.location,
      required this.price});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 270,
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withAlpha((0.06 * 255).round()),
                blurRadius: 15,
                offset: const Offset(0, 5))
          ]),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned.fill(
                child: imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (c, u) =>
                            Container(color: Colors.grey[100]),
                        errorWidget: (c, u, e) =>
                            Container(color: Colors.grey[200]))
                    : Container(color: Colors.grey[200])),
            Positioned.fill(
                child: DecoratedBox(
                    decoration: BoxDecoration(
                        gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                  Colors.transparent,
                  Colors.black.withAlpha((0.1 * 255).round()),
                  Colors.black.withAlpha((0.75 * 255).round())
                ],
                            stops: const [
                  0.4,
                  0.65,
                  1.0
                ])))),
            Positioned(
              bottom: 15,
              left: 15,
              right: 15,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Poppins',
                                height: 1.1)),
                        const SizedBox(height: 4),
                        Row(children: [
                          const Icon(HugeIcons.strokeRoundedLocation01,
                              color: Colors.white70, size: 14),
                          const SizedBox(width: 4),
                          Expanded(
                              child: Text(location,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      fontFamily: 'Poppins')))
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10)),
                      child: Text('\$${price.toStringAsFixed(0)}',
                          style: const TextStyle(
                              color: Color.fromRGBO(17, 48, 73, 1),
                              fontWeight: FontWeight.w800,
                              fontFamily: 'Poppins',
                              fontSize: 13))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
