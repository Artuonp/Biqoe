import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'payment_details_screen.dart';

const Color kPrimaryColor = Color.fromRGBO(17, 48, 73, 1);
const Color kBackgroundColor = Color(0xFFF8F9FD);

class ReservationScreen extends StatefulWidget {
  final String userId;
  final List<Map<String, dynamic>> selectedPackages;
  final String planName;
  final String location;
  final String supplier;
  final String destinationId;

  const ReservationScreen({
    super.key,
    required this.userId,
    required this.selectedPackages,
    required this.planName,
    required this.location,
    required this.supplier,
    required this.destinationId,
  });

  @override
  ReservationScreenState createState() => ReservationScreenState();
}

class PackageReservationData {
  Map<String, dynamic> package;
  DateTime? selectedDate;
  Map<String, dynamic>? selectedTimeInterval;
  int numberOfPeople;
  List<Map<String, dynamic>> availability;
  List<Map<String, dynamic>> timeIntervalsForSelectedDate;

  PackageReservationData({
    required this.package,
    this.selectedDate,
    this.selectedTimeInterval,
    this.numberOfPeople = 1,
    required this.availability,
    this.timeIntervalsForSelectedDate = const [],
  });
}

class ReservationScreenState extends State<ReservationScreen>
    with TickerProviderStateMixin {
  List<PackageReservationData> packagesData = [];
  String? selectedPaymentMethod;
  List<String> paymentMethods = [];
  bool _isLoading = false;

  String? _realDocId;
  final String _projectId = 'biqoe-app';

  // --- PREGUNTAS PERSONALIZADAS DEL PROVEEDOR ---
  List<Map<String, dynamic>> _customQuestions = [];
  // Respuestas del cliente: {pregunta: respuesta}
  final Map<String, dynamic> _questionAnswers = {};

  // ── Scroll + highlight ──────────────────────────────────────────────────
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _paymentKey = GlobalKey();
  final Map<int, GlobalKey> _calendarKeys = {};
  final Map<int, GlobalKey> _timeslotKeys = {};
  final Map<String, GlobalKey> _questionKeys = {};
  String? _highlightField;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  Map<String, dynamic> _deepCleanMap(dynamic data) {
    final result = <String, dynamic>{};
    if (data is Map) {
      for (final k in data.keys) {
        final val = data[k];
        if (val is Map) {
          result[k.toString()] = _deepCleanMap(val);
        } else if (val is Iterable) {
          result[k.toString()] =
              val.map((e) => e is Map ? _deepCleanMap(e) : e).toList();
        } else {
          result[k.toString()] = val;
        }
      }
    }
    return result;
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _pulseAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    _initializePackagesData();
    _resolveIdAndLoadDataREST();
  }

  void _initializePackagesData() {
    packagesData = widget.selectedPackages.map((rawPackage) {
      final package = _deepCleanMap(rawPackage);

      final disp = package['disponibilidad'];
      String rawType = package['tipo']?.toString() ??
          package['tipoDeReserva']?.toString() ??
          'Reserva';
      String bookingType = 'Reserva';

      if (rawType == 'fixed' || rawType == 'Ticket') {
        bookingType = 'Ticket';
      } else if (rawType == 'flexible' || rawType == 'Reserva Flexible')
        // ignore: curly_braces_in_flow_control_structures
        bookingType = 'Reserva Flexible';
      else if (rawType == 'dated' || rawType == 'Reserva')
        // ignore: curly_braces_in_flow_control_structures
        bookingType = 'Reserva';
      // ignore: curly_braces_in_flow_control_structures
      else if (rawType == 'Suscripción') bookingType = 'Suscripción';

      package['internal_type'] = bookingType;

      List<Map<String, dynamic>> safeAvailability = [];
      if (bookingType == 'Reserva' && disp is Iterable) {
        for (var item in disp) {
          safeAvailability.add(_deepCleanMap(item));
        }
      }

      return PackageReservationData(
        package: package,
        availability: safeAvailability,
        numberOfPeople: 1,
      );
    }).toList();
  }

  Map<String, dynamic> _convertFirestoreMap(dynamic firestoreDoc) {
    final result = <String, dynamic>{};
    if (firestoreDoc == null || firestoreDoc is! Map) return result;

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

  Future<void> _resolveIdAndLoadDataREST() async {
    try {
      Map<String, dynamic>? parsedData;
      String? docId;

      if (widget.destinationId.isNotEmpty) {
        final url =
            'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents/destinos/${widget.destinationId}';
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          parsedData = _convertFirestoreMap(jsonDecode(response.body));
          docId = widget.destinationId;
        }
      }

      if (parsedData == null) {
        final queryUrl =
            'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents:runQuery';
        final body = {
          'structuredQuery': {
            'from': [
              {'collectionId': 'destinos'}
            ],
            'where': {
              'fieldFilter': {
                'field': {'fieldPath': 'nombre'},
                'op': 'EQUAL',
                'value': {'stringValue': widget.planName}
              }
            },
            'limit': 1
          }
        };
        final response = await http.post(Uri.parse(queryUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body));
        if (response.statusCode == 200) {
          final List<dynamic> data = jsonDecode(response.body);
          if (data.isNotEmpty && data[0]['document'] != null) {
            parsedData = _convertFirestoreMap(data[0]['document']);
            final name = data[0]['document']['name'] as String;
            docId = name.split('/').last;
          }
        }
      }

      if (parsedData != null && docId != null) {
        _realDocId = docId;
        final rawPagos = parsedData['metodosPago'] ?? parsedData['pagos'];

        // Cargar preguntas personalizadas del proveedor
        final rawPreguntas = parsedData['preguntas'];
        List<Map<String, dynamic>> loadedQuestions = [];
        if (rawPreguntas is Iterable) {
          for (var q in rawPreguntas) {
            if (q is Map) {
              loadedQuestions.add(Map<String, dynamic>.from(q));
            }
          }
        }

        if (mounted) {
          setState(() {
            paymentMethods = [];
            if (rawPagos is Iterable) {
              for (var item in rawPagos) {
                if (item is Map && item['metodo'] != null) {
                  paymentMethods.add(item['metodo'].toString());
                }
              }
            }
            _customQuestions = loadedQuestions;
          });
        }
      }
    } catch (e) {
      debugPrint("Error resolviendo ID y Pagos (REST): $e");
    }
  }

  void _pickDate(DateTime pickedDate, int packageIndex) {
    final package = packagesData[packageIndex];
    final formattedDate = DateFormat('yyyy-MM-dd').format(pickedDate);

    final availabilityForDate = package.availability.where((item) {
      bool matchesDate = false;
      if (item.containsKey('fecha')) {
        matchesDate = item['fecha'] == formattedDate;
      }
      if (item.containsKey('fechaInicio')) {
        matchesDate = item['fechaInicio'] == formattedDate;
      }

      int cupos = 0;
      var c = item['cupos'];
      if (c is num) {
        cupos = c.toInt();
        // ignore: curly_braces_in_flow_control_structures
      } else if (c is String) cupos = int.tryParse(c) ?? 0;

      return matchesDate && cupos >= package.numberOfPeople;
    }).map((item) {
      String inicio = item['hora']?.toString() ??
          item['horaInicio']?.toString() ??
          item['inicio']?.toString() ??
          "";
      String fin = item['horaFin']?.toString() ?? item['fin']?.toString() ?? "";
      return {...item, 'inicio': inicio, 'fin': fin, 'cupos': item['cupos']};
    }).toList();

    setState(() {
      package.selectedDate = pickedDate;
      package.timeIntervalsForSelectedDate = availabilityForDate;
      package.selectedTimeInterval = null;
    });
  }

  Map<String, dynamic> _encodeFirestoreValue(dynamic value) {
    if (value == null) {
      return {'nullValue': null};
    }
    if (value is String) {
      return {'stringValue': value};
    }
    if (value is int) {
      return {'integerValue': value.toString()};
    }
    if (value is double) {
      return {'doubleValue': value};
    }
    if (value is bool) {
      return {'booleanValue': value};
    }
    if (value is List) {
      final List<Map<String, dynamic>> values = [];
      for (var item in value) {
        values.add(_encodeFirestoreValue(item));
      }
      return {
        'arrayValue': {'values': values}
      };
    }
    if (value is Map) {
      final Map<String, Map<String, dynamic>> fields = {};
      value.forEach((key, val) {
        fields[key.toString()] = _encodeFirestoreValue(val);
      });
      return {
        'mapValue': {'fields': fields}
      };
    }
    // Si es DateTime, lo convertimos a timestamp (opcional)
    if (value is DateTime) {
      return {'timestampValue': value.toIso8601String()};
    }
    // Fallback: convertimos a string
    return {'stringValue': value.toString()};
  }

  // ==========================================================
  // 🔥 MODO DIAGNÓSTICO: UPDATE CUPOS
  // ==========================================================
  // ignore: non_constant_identifier_names
  Future<void> _updateCuposREST_Diagnostic() async {
    if (_realDocId == null) {
      throw Exception(
          "No se ha podido identificar el destino en la base de datos.");
    }

    Map<String, dynamic> parsedData;
    try {
      final url =
          'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents/destinos/$_realDocId';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        throw Exception("El destino ya no existe o no se pudo cargar.");
      }
      parsedData = _convertFirestoreMap(jsonDecode(response.body));
    } catch (e) {
      throw Exception("Sub-paso A (Lectura REST de Firestore falló): $e");
    }

    List<Map<String, dynamic>> paquetesRemotos = [];
    try {
      if (parsedData['paquetes'] is Iterable) {
        for (var p in parsedData['paquetes']) {
          paquetesRemotos.add(_deepCleanMap(p));
        }
      }

      for (var localPackageData in packagesData) {
        final paqueteIndex = paquetesRemotos.indexWhere((p) {
          return (p['miniDescripcion'] ==
                  localPackageData.package['miniDescripcion']) ||
              (p['nombre'] == localPackageData.package['nombre']);
        });

        if (paqueteIndex == -1) continue;

        Map<String, dynamic> paqueteRemoto = paquetesRemotos[paqueteIndex];
        String tipo =
            localPackageData.package['internal_type']?.toString() ?? '';

        if (tipo == 'Reserva') {
          if (localPackageData.selectedDate == null ||
              localPackageData.selectedTimeInterval == null) {
            continue;
          }

          List<Map<String, dynamic>> disponibilidad = [];
          if (paqueteRemoto['disponibilidad'] is Iterable) {
            for (var d in paqueteRemoto['disponibilidad']) {
              disponibilidad.add(_deepCleanMap(d));
            }
          }

          final dateStr =
              DateFormat('yyyy-MM-dd').format(localPackageData.selectedDate!);

          final dispIndex = disponibilidad.indexWhere((d) {
            bool matchDate =
                (d['fecha'] == dateStr) || (d['fechaInicio'] == dateStr);
            String dInicio = d['hora']?.toString() ??
                d['horaInicio']?.toString() ??
                d['inicio']?.toString() ??
                "";
            return matchDate &&
                dInicio == localPackageData.selectedTimeInterval!['inicio'];
          });

          if (dispIndex != -1) {
            Map<String, dynamic> dispItem = disponibilidad[dispIndex];

            int cuposActuales = 0;
            var c = dispItem['cupos'];
            if (c is num) {
              cuposActuales = c.toInt();
              // ignore: curly_braces_in_flow_control_structures
            } else if (c is String) cuposActuales = int.tryParse(c) ?? 0;

            if (cuposActuales < localPackageData.numberOfPeople) {
              throw Exception("No hay suficientes cupos.");
            }
            dispItem['cupos'] = cuposActuales - localPackageData.numberOfPeople;
            disponibilidad[dispIndex] = dispItem;
            paqueteRemoto['disponibilidad'] = disponibilidad;
          }
        } else if (tipo == 'Ticket' || tipo == 'Suscripción') {
          if (paqueteRemoto['cuposDisponibles'] != null) {
            int cuposActuales = 0;
            var c = paqueteRemoto['cuposDisponibles'];
            if (c is num) {
              cuposActuales = c.toInt();
              // ignore: curly_braces_in_flow_control_structures
            } else if (c is String) cuposActuales = int.tryParse(c) ?? 0;

            if (cuposActuales < localPackageData.numberOfPeople) {
              throw Exception("No hay suficientes cupos.");
            }
            paqueteRemoto['cuposDisponibles'] =
                cuposActuales - localPackageData.numberOfPeople;
          }
        }
        paquetesRemotos[paqueteIndex] = paqueteRemoto;
      }
    } catch (e) {
      throw Exception(
          "Sub-paso B (Cálculo y modificación del array local falló): $e");
    }

    // 🔥 NUEVO: Escritura usando HTTP REST en lugar del SDK
    try {
      // Primero, necesitamos construir el objeto en el formato que espera la API REST de Firestore.
      // La API espera un campo "fields" con la estructura de Firestore.
      // Pero como solo queremos actualizar el campo "paquetes", podemos usar una máscara de campos.
      // La forma más simple es usar la actualización con máscara: PATCH al documento con solo el campo modificado.

      final updateUrl =
          'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents/destinos/$_realDocId?updateMask.fieldPaths=paquetes';

      // Necesitamos convertir paquetesRemotos al formato de Firestore (fields).
      // Para ello, usamos una función auxiliar que convierte un mapa Dart a un mapa de Firestore.
      final firestorePaquetes = _encodeFirestoreValue(paquetesRemotos);
      final body = {
        'fields': {
          'paquetes': firestorePaquetes,
        }
      };

      final response = await http.patch(
        Uri.parse(updateUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode != 200) {
        throw Exception("Error HTTP ${response.statusCode}: ${response.body}");
      }
    } catch (e) {
      throw Exception("Sub-paso C (Escritura con REST falló): $e");
    }
  }

  void _showErrorDialog(String message) {
    // Convertir mensajes técnicos internos a mensajes claros para el usuario
    String userMessage = _humanizeError(message);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                userMessage,
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: kPrimaryColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // Traduce mensajes técnicos internos a frases claras para el usuario
  String _humanizeError(String raw) {
    final r = raw.toLowerCase();
    if (r.contains('método de pago') || r.contains('payment')) {
      return 'Por favor selecciona un método de pago antes de continuar.';
    }
    if (r.contains('preguntas')) {
      return 'Por favor responde todas las preguntas obligatorias antes de continuar.';
    }
    if (r.contains('fecha') && r.contains('horario')) {
      return 'Por favor selecciona una fecha y un horario para continuar.';
    }
    if (r.contains('fecha')) {
      return 'Por favor selecciona una fecha disponible para tu reserva.';
    }
    if (r.contains('horario') || r.contains('hora')) {
      return 'Por favor selecciona un horario disponible para continuar.';
    }
    if (r.contains('cupos') || r.contains('disponib')) {
      return 'No hay suficientes cupos disponibles para la fecha seleccionada.';
    }
    if (r.contains('http') ||
        r.contains('conexión') ||
        r.contains('network') ||
        r.contains('timeout')) {
      return 'Error de conexión. Verifica tu internet e intenta de nuevo.';
    }
    if (r.contains('paso 1') ||
        r.contains('firestore') ||
        r.contains('actualiz')) {
      return 'Hubo un problema al guardar tu reserva. Intenta de nuevo.';
    }
    if (r.contains('paso 2') || r.contains('empaquet')) {
      return 'Hubo un problema al procesar los datos. Intenta de nuevo.';
    }
    if (r.contains('paso 3') || r.contains('payment')) {
      return 'Hubo un problema al abrir el pago. Intenta de nuevo.';
    }
    // Si llegamos aquí, es un error genérico — no mostramos el técnico
    return 'Ocurrió un problema inesperado. Intenta de nuevo.';
  }

  // ==========================================================
  // 🔥 MODO DIAGNÓSTICO: VALIDATE AND PROCESS
  // ==========================================================
  Future<void> _validateAndProcessReservation() async {
    setState(() => _isLoading = true);

    // --- VALIDACIÓN INICIAL ---
    try {
      if (selectedPaymentMethod == null) {
        throw Exception('método de pago');
      }
      for (var packageData in packagesData) {
        if (packageData.package['internal_type'] == 'Reserva' &&
            packageData.selectedDate == null) {
          throw Exception('fecha');
        }
        if (packageData.package['internal_type'] == 'Reserva' &&
            packageData.selectedTimeInterval == null) {
          throw Exception('horario');
        }
      }
      // Validar preguntas obligatorias
      for (var q in _customQuestions) {
        if (q['requerido'] == true) {
          final String pregunta = q['pregunta']?.toString() ?? '';
          final val = _questionAnswers[pregunta];
          if (val == null || val.toString().trim().isEmpty) {
            throw Exception('preguntas');
          }
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorDialog(e.toString());
      final msg = e.toString().toLowerCase();
      if (msg.contains('método de pago')) {
        _triggerHighlight('payment');
      } else if (msg.contains('fecha')) {
        for (int i = 0; i < packagesData.length; i++) {
          if (packagesData[i].package['internal_type'] == 'Reserva' &&
              packagesData[i].selectedDate == null) {
            _triggerHighlight('calendar_$i');
            break;
          }
        }
      } else if (msg.contains('horario')) {
        for (int i = 0; i < packagesData.length; i++) {
          if (packagesData[i].package['internal_type'] == 'Reserva' &&
              packagesData[i].selectedTimeInterval == null &&
              packagesData[i].selectedDate != null) {
            _triggerHighlight('timeslot_$i');
            break;
          }
        }
      } else if (msg.contains('preguntas')) {
        for (var q in _customQuestions) {
          if (q['requerido'] == true) {
            final String pq = q['pregunta']?.toString() ?? '';
            final val = _questionAnswers[pq];
            if (val == null || val.toString().trim().isEmpty) {
              _triggerHighlight('question_$pq');
              break;
            }
          }
        }
      }
      return;
    }

    // --- PASO 1: ACTUALIZACIÓN DE FIRESTORE ---
    try {
      await _updateCuposREST_Diagnostic();
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorDialog('cupos');
      return;
    }

    // --- PASO 2: EMPAQUETAR DATOS PARA NAVEGACIÓN ---
    List<Map<String, dynamic>> cleanPackages = [];
    try {
      for (var p in packagesData) {
        Map<String, dynamic> packageDetails = {
          'numero': p.package['numero'] ?? 1,
          'miniDescripcion': p.package['miniDescripcion']?.toString() ??
              p.package['nombre']?.toString() ??
              '',
          'personas': p.numberOfPeople,
          'precio': p.package['precio'],
          'tipoDeReserva': p.package['internal_type']?.toString() ?? '',
        };

        if (p.package['internal_type'] == 'Reserva') {
          packageDetails.addAll({
            'fecha': p.selectedDate!.toIso8601String(),
            'hora': p.selectedTimeInterval!['fin'].toString().isEmpty
                ? p.selectedTimeInterval!['inicio'].toString()
                : '${p.selectedTimeInterval!['inicio']} - ${p.selectedTimeInterval!['fin']}',
          });
        }
        cleanPackages.add(_deepCleanMap(packageDetails));
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorDialog('paso 2');
      return;
    }

    // --- PASO 3: NAVEGAR A PAYMENT DETAILS SCREEN ---
    try {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentDetailsScreen(
              userId: widget.userId,
              paymentMethod: selectedPaymentMethod!,
              planName: widget.planName,
              planLocation: widget.location,
              totalPrice: totalCost,
              supplier: widget.supplier,
              destinationId: _realDocId ?? widget.destinationId,
              packagesData: cleanPackages,
              questionAnswers: Map<String, dynamic>.from(_questionAnswers),
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorDialog('paso 3');
      return;
    }

    if (mounted) setState(() => _isLoading = false);
  }

  double get totalCost {
    return packagesData.fold(0.0, (total, package) {
      var p = package.package['precio'];
      double price = 0.0;
      if (p is num) {
        price = p.toDouble();
        // ignore: curly_braces_in_flow_control_structures
      } else if (p is String) price = double.tryParse(p) ?? 0.0;

      return total + (price * package.numberOfPeople);
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _triggerHighlight(String field) async {
    setState(() => _highlightField = field);
    await Future.delayed(const Duration(milliseconds: 80));
    GlobalKey? key;
    if (field == 'payment') {
      key = _paymentKey;
    } else if (field.startsWith('calendar_')) {
      key = _calendarKeys[int.tryParse(field.split('_').last) ?? 0];
    } else if (field.startsWith('timeslot_')) {
      key = _timeslotKeys[int.tryParse(field.split('_').last) ?? 0];
    } else if (field.startsWith('question_')) {
      key = _questionKeys[field.substring('question_'.length)];
    }
    if (key?.currentContext != null) {
      await Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        alignment: 0.15,
      );
    }
    _pulseController.repeat(reverse: true);
    await Future.delayed(const Duration(milliseconds: 2400));
    if (mounted) {
      _pulseController.stop();
      _pulseController.reset();
      setState(() => _highlightField = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            bottom: 100,
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.planName,
                      style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: kPrimaryColor)),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined,
                          size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Expanded(
                          child: Text(widget.location,
                              style: GoogleFonts.poppins(
                                  color: Colors.grey[600], fontSize: 14),
                              overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                  const SizedBox(height: 25),
                  ListView.separated(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemCount: packagesData.length,
                    itemBuilder: (context, index) =>
                        _buildPackageWidget(packagesData[index], index),
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 5),
                  ),
                  const SizedBox(height: 1),
                  const Divider(),
                  const SizedBox(height: 10),

                  // ── SECCIÓN: PREGUNTAS DEL PROVEEDOR ──────────────────
                  if (_customQuestions.isNotEmpty) ...[
                    Text('Datos adicionales',
                        style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: kPrimaryColor)),
                    const SizedBox(height: 4),
                    Text(
                      'El proveedor necesita esta información para tu reserva.',
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 16),
                    _buildQuestionsSection(),
                    const SizedBox(height: 10),
                    const Divider(),
                    const SizedBox(height: 10),
                  ],

                  Text('Método de pago',
                      style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: kPrimaryColor)),
                  const SizedBox(height: 15),
                  if (paymentMethods.isEmpty)
                    Text("Cargando o sin métodos de pago...",
                        style: GoogleFonts.poppins(color: Colors.grey))
                  else
                    _HighlightBorder(
                      key: _paymentKey,
                      active: _highlightField == 'payment',
                      pulseAnim: _pulseAnim,
                      child: _buildPaymentOptions(),
                    ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
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
                          Text("Total a pagar",
                              style: GoogleFonts.poppins(
                                  fontSize: 12, color: Colors.grey)),
                          Text("\$${totalCost.toStringAsFixed(2)}",
                              style: GoogleFonts.poppins(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: kPrimaryColor)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    ElevatedButton(
                      onPressed:
                          _isLoading ? null : _validateAndProcessReservation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _isLoading ? Colors.grey.shade300 : kPrimaryColor,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 30, vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 5,
                      ),
                      child: Container(
                        alignment: Alignment.center,
                        child: Text("Reservar",
                            style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _isLoading
                                    ? Colors.transparent
                                    : Colors.white)),
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

  Widget _buildPackageWidget(PackageReservationData packageData, int index) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kPrimaryColor.withValues(alpha: 0.03),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade200)),
                  child: Text("${index + 1}",
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold, color: kPrimaryColor)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          packageData.package['miniDescripcion']?.toString() ??
                              packageData.package['nombre']?.toString() ??
                              'Paquete',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      Text("\$${packageData.package['precio']} x persona",
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                ),
                _buildModernQuantitySelector(packageData, index),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoUI(packageData),
                if (packageData.package['internal_type'] == 'Reserva') ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  _buildReservationUI(packageData, index),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernQuantitySelector(
      PackageReservationData packageData, int index) {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _quantityBtn(Icons.remove, () {
            if (packageData.numberOfPeople > 1) {
              setState(() {
                packageData.numberOfPeople--;
                if (packageData.package['internal_type'] == 'Reserva' &&
                    packageData.selectedDate != null) {
                  _pickDate(packageData.selectedDate!, index);
                }
              });
            }
          }),
          Container(
              width: 30,
              alignment: Alignment.center,
              child: Text("${packageData.numberOfPeople}",
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
          _quantityBtn(Icons.add, () {
            setState(() {
              packageData.numberOfPeople++;
              if (packageData.package['internal_type'] == 'Reserva' &&
                  packageData.selectedDate != null) {
                _pickDate(packageData.selectedDate!, index);
              }
            });
          }),
        ],
      ),
    );
  }

  Widget _quantityBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
        onTap: onTap,
        child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Icon(icon, size: 16, color: kPrimaryColor)));
  }

  Widget _buildInfoUI(PackageReservationData packageData) {
    String bookingType = packageData.package['internal_type'];

    int? cupos;
    var rawCupos = packageData.package['cuposDisponibles'];
    if (rawCupos is num) {
      cupos = rawCupos.toInt();
      // ignore: curly_braces_in_flow_control_structures
    } else if (rawCupos is String) cupos = int.tryParse(rawCupos);

    switch (bookingType) {
      case 'Ticket':
        return _buildInfoBox(
            title: "Ticket fijo",
            message: "Válido para la fecha del evento.",
            icon: Icons.confirmation_number_outlined,
            color: Colors.blue,
            cuposDisponibles: cupos);
      case 'Reserva Flexible':
        return _buildInfoBox(
            title: "Fecha flexible",
            message: "Coordina luego de la compra.",
            icon: Icons.all_inclusive_rounded,
            color: Colors.purple);
      case 'Suscripción':
        return _buildInfoBox(
            title: "Suscripción",
            message: "Acceso recurrente.",
            icon: Icons.autorenew_rounded,
            color: Colors.orange,
            cuposDisponibles: cupos);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildInfoBox(
      {required String title,
      required String message,
      required IconData icon,
      required Color color,
      int? cuposDisponibles}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Row(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.black87)),
          Text(message,
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.black54)),
          if (cuposDisponibles != null)
            Text("Cupos: $cuposDisponibles",
                style: GoogleFonts.poppins(
                    fontSize: 12, fontWeight: FontWeight.bold, color: color))
        ]))
      ]),
    );
  }

  Widget _buildReservationUI(PackageReservationData packageData, int index) {
    _calendarKeys.putIfAbsent(index, () => GlobalKey());
    _timeslotKeys.putIfAbsent(index, () => GlobalKey());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Selecciona una fecha",
            style:
                GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 10),
        _HighlightBorder(
          key: _calendarKeys[index],
          active: _highlightField == 'calendar_$index',
          pulseAnim: _pulseAnim,
          borderRadius: 12,
          child: Container(
            decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade200),
                borderRadius: BorderRadius.circular(12)),
            child: TableCalendar(
              locale: 'es_ES',
              firstDay: DateTime.now(),
              lastDay: DateTime.now().add(const Duration(days: 365)),
              focusedDay: packageData.selectedDate ?? DateTime.now(),
              selectedDayPredicate: (day) =>
                  isSameDay(packageData.selectedDate, day),
              onDaySelected: (selectedDay, focusedDay) =>
                  _pickDate(selectedDay, index),
              // Deshabilitamos los gestos de swipe del calendario para que el
              // SingleChildScrollView padre pueda recibir el scroll vertical.
              // Los meses se cambian con los chevrones (< >) del header.
              availableGestures: AvailableGestures.none,
              headerStyle: HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: kPrimaryColor),
                  leftChevronIcon: const Icon(Icons.chevron_left,
                      color: kPrimaryColor, size: 20),
                  rightChevronIcon: const Icon(Icons.chevron_right,
                      color: kPrimaryColor, size: 20),
                  titleTextFormatter: (date, locale) {
                    String raw = DateFormat.yMMMM(locale).format(date);
                    if (raw.isEmpty) return "";
                    return "${raw[0].toUpperCase()}${raw.substring(1)}";
                  }),
              calendarStyle: CalendarStyle(
                  outsideTextStyle: const TextStyle(color: Colors.grey),
                  defaultTextStyle: GoogleFonts.poppins(color: Colors.black87),
                  weekendTextStyle: GoogleFonts.poppins(color: Colors.black87),
                  todayDecoration: BoxDecoration(
                      color: kPrimaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle),
                  todayTextStyle: const TextStyle(color: kPrimaryColor),
                  selectedDecoration: const BoxDecoration(
                      color: kPrimaryColor, shape: BoxShape.circle)),
              calendarBuilders:
                  CalendarBuilders(defaultBuilder: (context, day, focusedDay) {
                final formattedDay = DateFormat('yyyy-MM-dd').format(day);
                bool isAvailable = packageData.availability.any((item) {
                  bool matchesDate = false;
                  if (item.containsKey('fecha')) {
                    matchesDate = item['fecha'] == formattedDay;
                  }
                  if (item.containsKey('fechaInicio')) {
                    matchesDate = item['fechaInicio'] == formattedDay;
                  }

                  int cupos = 0;
                  var c = item['cupos'];
                  if (c is num) {
                    cupos = c.toInt();
                    // ignore: curly_braces_in_flow_control_structures
                  } else if (c is String) cupos = int.tryParse(c) ?? 0;

                  return matchesDate && cupos >= packageData.numberOfPeople;
                });
                if (isAvailable) {
                  return Center(
                      child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              shape: BoxShape.circle),
                          alignment: Alignment.center,
                          child: Text('${day.day}',
                              style: GoogleFonts.poppins(
                                  color: Colors.green[700],
                                  fontWeight: FontWeight.bold))));
                }
                return null;
              }),
            ),
          ),
        ),
        if (packageData.selectedDate != null) ...[
          const SizedBox(height: 16),
          Text('Horarios disponibles:',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          if (packageData.timeIntervalsForSelectedDate.isEmpty)
            Text('No hay cupos suficientes.',
                style: GoogleFonts.poppins(color: Colors.red, fontSize: 12))
          else
            _HighlightBorder(
              key: _timeslotKeys[index],
              active: _highlightField == 'timeslot_$index',
              pulseAnim: _pulseAnim,
              padding: const EdgeInsets.all(8),
              child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      packageData.timeIntervalsForSelectedDate.map((interval) {
                    bool isSelected =
                        packageData.selectedTimeInterval == interval;
                    String labelText = interval['inicio']?.toString() ?? "";
                    if (interval['fin'] != null &&
                        interval['fin'].toString().isNotEmpty) {
                      labelText += " - ${interval['fin']}";
                    }
                    labelText += " (${interval['cupos']} cupos)";
                    return ChoiceChip(
                        label: Text(labelText,
                            style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: isSelected
                                    ? Colors.white
                                    : Colors.black87)),
                        selected: isSelected,
                        selectedColor: kPrimaryColor,
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                                color: isSelected
                                    ? kPrimaryColor
                                    : Colors.grey.shade300)),
                        onSelected: (selected) => setState(() => packageData
                            .selectedTimeInterval = selected ? interval : null),
                        showCheckmark: false);
                  }).toList()),
            ),
        ],
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SECCIÓN DE PREGUNTAS PERSONALIZADAS DEL PROVEEDOR
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildQuestionsSection() {
    return Column(
      children: _customQuestions.map((q) {
        final String pregunta = q['pregunta']?.toString() ?? '';
        final String tipo = q['tipo']?.toString() ?? 'Texto';
        final bool requerido = q['requerido'] == true;

        _questionKeys.putIfAbsent(pregunta, () => GlobalKey());
        return _HighlightBorder(
          key: _questionKeys[pregunta],
          active: _highlightField == 'question_$pregunta',
          pulseAnim: _pulseAnim,
          borderRadius: 14,
          margin: const EdgeInsets.only(bottom: 14),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                          color: kPrimaryColor.withValues(alpha: 0.08),
                          shape: BoxShape.circle),
                      child: const Icon(Icons.help_outline,
                          color: kPrimaryColor, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        pregunta + (requerido ? ' *' : ''),
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Colors.black87),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (tipo == 'Sí/No')
                  // Widget de Sí/No con dos botones tipo chip
                  Row(
                    children: ['Sí', 'No'].map((option) {
                      final bool isSelected =
                          _questionAnswers[pregunta]?.toString() == option;
                      return Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: GestureDetector(
                          onTap: () => setState(
                              () => _questionAnswers[pregunta] = option),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? kPrimaryColor
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: isSelected
                                      ? kPrimaryColor
                                      : Colors.grey.shade300),
                            ),
                            child: Text(
                              option,
                              style: GoogleFonts.poppins(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.black87,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  )
                else
                  // Texto libre o Número
                  TextField(
                    keyboardType: tipo == 'Número'
                        ? TextInputType.number
                        : TextInputType.text,
                    onChanged: (val) =>
                        setState(() => _questionAnswers[pregunta] = val),
                    decoration: InputDecoration(
                      hintText: tipo == 'Número'
                          ? 'Ingresa un número'
                          : 'Escribe tu respuesta',
                      hintStyle:
                          GoogleFonts.poppins(fontSize: 13, color: Colors.grey),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: kPrimaryColor, width: 1.5)),
                      isDense: true,
                    ),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPaymentOptions() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: paymentMethods.map((method) {
          bool isSelected = selectedPaymentMethod == method;
          return GestureDetector(
            onTap: () => setState(() => selectedPaymentMethod = method),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                  color: isSelected ? kPrimaryColor : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: isSelected ? kPrimaryColor : Colors.grey.shade300),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                              color: kPrimaryColor.withValues(alpha: 0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 4))
                        ]
                      : []),
              child: Row(children: [
                Icon(
                    method.contains('Zelle')
                        ? Icons.attach_money
                        : Icons.payment,
                    color: isSelected ? Colors.white : Colors.grey,
                    size: 18),
                const SizedBox(width: 8),
                Text(method,
                    style: GoogleFonts.poppins(
                        color: isSelected ? Colors.white : Colors.grey[800],
                        fontWeight: FontWeight.w500))
              ]),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── _HighlightBorder: pulsa un borde de color sobre la zona con error ────────
class _HighlightBorder extends StatelessWidget {
  final Widget child;
  final bool active;
  final Animation<double> pulseAnim;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const _HighlightBorder({
    super.key,
    required this.child,
    required this.active,
    required this.pulseAnim,
    this.borderRadius = 10,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    if (!active) return child;
    return AnimatedBuilder(
      animation: pulseAnim,
      builder: (context, _) {
        final double t = pulseAnim.value;
        final Color borderColor = Color.lerp(
          const Color.fromRGBO(17, 48, 73, 0.35),
          const Color.fromRGBO(17, 48, 73, 1.0),
          t,
        )!;
        return Container(
          margin: margin,
          padding: padding,
          decoration: BoxDecoration(
            color: const Color.fromRGBO(17, 48, 73, 1)
                .withValues(alpha: 0.04 + t * 0.06),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: borderColor, width: 1.0 + t * 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color.fromRGBO(17, 48, 73, 1)
                    .withValues(alpha: 0.13 * t),
                blurRadius: 8 + t * 10,
                spreadRadius: t * 3,
              ),
            ],
          ),
          child: child,
        );
      },
    );
  }
}
