import 'dart:math';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'bookings_screen.dart';

// Import condicional: en web usa fetch nativo del browser (no-cors),
// en nativo usa el stub vacío. Esto evita el error de dart:js en Android.
import 'fetch_helper_stub.dart' if (dart.library.html) 'fetch_helper_web.dart';

const Color kPrimaryColor = Color.fromRGBO(17, 48, 73, 1);
const Color kBackgroundColor = Color(0xFFF8F9FD);

class PaymentDetailsScreen extends StatefulWidget {
  final String userId;
  final String paymentMethod;
  final String planName;
  final String planLocation;
  final String supplier;
  final double totalPrice;
  final dynamic packagesData;
  final String? destinationId;
  // Respuestas del cliente a las preguntas del proveedor
  final Map<String, dynamic> questionAnswers;
  // Divisa del destino: 'usd' (por defecto) o 'eur'
  final String divisa;

  const PaymentDetailsScreen({
    super.key,
    required this.userId,
    required this.paymentMethod,
    required this.planName,
    required this.planLocation,
    required this.totalPrice,
    required this.supplier,
    required this.packagesData,
    this.destinationId,
    this.questionAnswers = const {},
    this.divisa = 'usd',
  });

  @override
  PaymentDetailsScreenState createState() => PaymentDetailsScreenState();
}

class PaymentDetailsScreenState extends State<PaymentDetailsScreen> {
  final _transactionCtrl = TextEditingController();
  final _payerIdCtrl = TextEditingController();
  final _payerPhoneCtrl = TextEditingController();
  final _payerNameCtrl = TextEditingController();
  final _payerEmailCtrl = TextEditingController();
  final _guestNameCtrl = TextEditingController();
  final _guestEmailCtrl = TextEditingController();
  final _guestPhoneCtrl = TextEditingController();

  Map<String, String> _providerBankData = {};
  bool _isLoadingBankData = true;
  bool _payInInstallments = false;
  bool _canPayInInstallments = false;
  List<double> _installmentConfig = [];
  bool _isProcessing = false;
  bool _isGuest = false;

  // Tasa de cambio — se carga en _fetchDestinationData para mostrarla
  double _exchangeRate = 0.0;

  // ── Helpers de divisa ─────────────────────────────────────────────────────
  // Devuelven el símbolo y la etiqueta correctos según widget.divisa
  String get _currencySymbol => widget.divisa == 'eur' ? '€' : '\$';
  String get _currencyLabel => widget.divisa == 'eur' ? 'EUR' : 'USD';

  List<Map<String, dynamic>> _cleanPackagesData = [];

  final String _projectId = 'biqoe-app';
  static const String _apiKey = 'AIzaSyD6gvIVnsBg9QSdP04gM3qgzEjKI5FjEEU';

  // Usuario cacheado al inicio para no volver a llamar Firebase Auth
  // (Safari lanza TypeError en llamadas repetidas a FirebaseAuth)
  String _cachedUserId = '';
  String _cachedUserName = '';
  String _cachedUserEmail = '';

  // Slug del proveedor — se obtiene durante la carga para navegar de vuelta
  String _supplierSlug = '';

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      _cachedUserId = user?.uid ?? widget.userId;
      _cachedUserName = user?.displayName ?? '';
      _cachedUserEmail = user?.email ?? '';
      if (mounted) setState(() => _isGuest = user?.isAnonymous ?? true);
    } catch (e) {
      _cachedUserId = widget.userId;
      _cachedUserName = '';
      _cachedUserEmail = '';
      if (mounted) setState(() => _isGuest = true);
    }

    try {
      final raw = widget.packagesData;
      if (raw != null) {
        final jsonString = jsonEncode(raw);
        final decoded = jsonDecode(jsonString);
        if (decoded is Iterable) {
          _cleanPackagesData = [];
          for (var e in decoded) {
            if (e is Map) {
              final Map<String, dynamic> cleanMap = {};
              e.forEach((k, v) => cleanMap[k.toString()] = v);
              _cleanPackagesData.add(cleanMap);
            }
          }
        }
      }
    } catch (e) {
      _cleanPackagesData = [];
    }

    await _fetchDestinationData();
  }

  Map<String, dynamic> _convertFirestoreMap(dynamic firestoreDoc) {
    final result = <String, dynamic>{};
    if (firestoreDoc == null || firestoreDoc is! Map) return result;
    final fields = firestoreDoc['fields'];
    if (fields is! Map) return result;
    for (final keyObj in fields.keys) {
      final String keyStr = keyObj.toString();
      final valueObj = fields[keyObj];
      if (valueObj is Map) {
        result[keyStr] = _extractFirestoreValue(valueObj);
      }
    }
    return result;
  }

  dynamic _extractFirestoreValue(Map valueObj) {
    if (valueObj.containsKey('stringValue')) return valueObj['stringValue'];
    if (valueObj.containsKey('integerValue')) {
      return int.tryParse(valueObj['integerValue'].toString()) ?? 0;
    }
    if (valueObj.containsKey('doubleValue')) {
      final dv = valueObj['doubleValue'];
      return (dv is num)
          ? dv.toDouble()
          : double.tryParse(dv.toString()) ?? 0.0;
    }
    if (valueObj.containsKey('booleanValue')) {
      return valueObj['booleanValue'] == true;
    }
    if (valueObj.containsKey('timestampValue')) {
      return valueObj['timestampValue'];
    }
    if (valueObj.containsKey('nullValue')) return null;
    if (valueObj.containsKey('arrayValue')) {
      final arrVal = valueObj['arrayValue'];
      if (arrVal is Map && arrVal['values'] is Iterable) {
        final outList = [];
        for (var item in arrVal['values']) {
          if (item is Map) {
            if (item.containsKey('mapValue') &&
                item['mapValue'] is Map &&
                item['mapValue'].containsKey('fields')) {
              outList.add(
                  _convertFirestoreMap({'fields': item['mapValue']['fields']}));
            } else {
              outList.add(_extractFirestoreValue(item));
            }
          } else {
            outList.add(item);
          }
        }
        return outList;
      }
      return [];
    }
    if (valueObj.containsKey('mapValue')) {
      final mv = valueObj['mapValue'];
      if (mv is Map && mv.containsKey('fields')) {
        return _convertFirestoreMap({'fields': mv['fields']});
      }
    }
    return valueObj;
  }

  Future<void> _fetchDestinationData() async {
    try {
      const headers = <String, String>{'Content-Type': 'application/json'};
      Map<String, dynamic>? data;

      // Intento 1: GET por destinationId
      if (widget.destinationId != null && widget.destinationId!.isNotEmpty) {
        final url =
            'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents/destinos/${widget.destinationId}?key=$_apiKey';
        try {
          final response = await http
              .get(Uri.parse(url), headers: headers)
              .timeout(const Duration(seconds: 15));
          if (response.statusCode == 200) {
            data = _convertFirestoreMap(jsonDecode(response.body));
          }
        } on Exception catch (_) {}
      }

      // Intento 2: POST runQuery por nombre
      if (data == null || data.isEmpty) {
        final queryUrl =
            'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents:runQuery?key=$_apiKey';
        try {
          final body = jsonEncode({
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
          });
          final response = await http
              .post(Uri.parse(queryUrl), headers: headers, body: body)
              .timeout(const Duration(seconds: 15));
          if (response.statusCode == 200) {
            final List<dynamic> result = jsonDecode(response.body);
            if (result.isNotEmpty && result[0]['document'] != null) {
              data = _convertFirestoreMap(result[0]['document']);
            }
          }
        } on Exception catch (_) {}
      }

      if (data != null && data.isNotEmpty) {
        // Cuotas
        final paquetes = data['paquetes'];
        if (paquetes is Iterable) {
          for (var p in paquetes) {
            if (p is Map && p['tieneCuotas'] == true) {
              _canPayInInstallments = true;
              final config = p['configuracionCuotas'];
              if (config is Iterable) {
                _installmentConfig = [];
                for (var c in config) {
                  if (c is num) {
                    _installmentConfig.add(c.toDouble());
                  } else {
                    _installmentConfig
                        .add(double.tryParse(c.toString()) ?? 0.0);
                  }
                }
              } else {
                _installmentConfig = [50.0, 50.0];
              }
              break;
            }
          }
        }

        // Métodos de pago
        final rawPagos = data['metodosPago'] ?? data['pagos'];
        List<dynamic> methods = [];
        if (rawPagos is Iterable) {
          for (var m in rawPagos) {
            methods.add(m);
          }
        }

        Map? selected;
        for (var m in methods) {
          if (m is Map && m['metodo']?.toString() == widget.paymentMethod) {
            selected = m;
            break;
          }
        }

        if (selected != null) {
          _providerBankData = {};
          selected.forEach((k, v) {
            _providerBankData[k.toString()] = v.toString();
          });
        }
      }

// Cargar tasa de cambio (SISTEMA DUAL AUTOMÁTICO - MEDIANOCHE)
      try {
        final tasaUrl =
            'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents/config/tasa?key=$_apiKey';
        final tasaResponse = await http
            .get(Uri.parse(tasaUrl))
            .timeout(const Duration(seconds: 5));

        if (tasaResponse.statusCode == 200) {
          final parsedTasa =
              _convertFirestoreMap(jsonDecode(tasaResponse.body));

          // Determinamos qué campos leer según la divisa
          final String fieldActual =
              widget.divisa == 'eur' ? 'eur_actual' : 'usd_actual';
          final String fieldNuevo =
              widget.divisa == 'eur' ? 'eur_nuevo' : 'usd_nuevo';
          final String fieldFallback = widget.divisa == 'eur'
              ? 'eur'
              : 'valor'; // Por si los nuevos no existen aún

          double tasaActual = 0.0;
          double tasaNueva = 0.0;
          double tasaFallback = 0.0;

          // Leer valores de Firestore
          if (parsedTasa[fieldActual] != null) {
            tasaActual = (parsedTasa[fieldActual] is num)
                ? parsedTasa[fieldActual].toDouble()
                : (double.tryParse(parsedTasa[fieldActual].toString()) ?? 0.0);
          }
          if (parsedTasa[fieldNuevo] != null) {
            tasaNueva = (parsedTasa[fieldNuevo] is num)
                ? parsedTasa[fieldNuevo].toDouble()
                : (double.tryParse(parsedTasa[fieldNuevo].toString()) ?? 0.0);
          }
          if (parsedTasa[fieldFallback] != null) {
            tasaFallback = (parsedTasa[fieldFallback] is num)
                ? parsedTasa[fieldFallback].toDouble()
                : (double.tryParse(parsedTasa[fieldFallback].toString()) ??
                    0.0);
          }

          // Si no hay tasas duales aún en BD, usamos el fallback tradicional
          if (tasaActual == 0.0 && tasaNueva == 0.0) {
            _exchangeRate = tasaFallback;
          } else {
            // LÓGICA DE MEDIANOCHE: ¿Qué tasa usamos?
            bool usarTasaNueva = false;

            if (parsedTasa['fecha_activacion'] != null) {
              try {
                // toLocal() asegura que la hora se compare en el huso horario de Venezuela/del dispositivo
                DateTime fechaActivacion =
                    DateTime.parse(parsedTasa['fecha_activacion'].toString())
                        .toLocal();
                DateTime ahora = DateTime.now();

                // Si la hora actual ya cruzó la medianoche programada
                if (ahora.isAfter(fechaActivacion) ||
                    ahora.isAtSameMomentAs(fechaActivacion)) {
                  usarTasaNueva = true;
                }
              } catch (_) {}
            }

            // Asignamos la tasa correcta. Si alguna es 0 por error, usa la otra de respaldo.
            _exchangeRate = usarTasaNueva
                ? (tasaNueva > 0 ? tasaNueva : tasaActual)
                : (tasaActual > 0 ? tasaActual : tasaNueva);
          }
        }
      } catch (_) {}

      // Cargar slug del proveedor para navegación de vuelta
      try {
        final slugsUrl =
            'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents/metadata/slugs';
        final slugsResponse = await http
            .get(Uri.parse(slugsUrl))
            .timeout(const Duration(seconds: 5));
        if (slugsResponse.statusCode == 200) {
          final slugsData = jsonDecode(slugsResponse.body);
          final mapping =
              slugsData['fields']?['mapping']?['mapValue']?['fields'];
          if (mapping is Map) {
            for (var entry in mapping.entries) {
              if (entry.value['stringValue'] == widget.supplier) {
                _supplierSlug = entry.key.toString();
                break;
              }
            }
          }
        }
      } catch (_) {}
    } catch (e, stack) {
      debugPrint('ERROR en _fetchDestinationData: $e\n$stack');
    } finally {
      if (mounted) {
        setState(() => _isLoadingBankData = false);
      }
    }
  }

  String _generateRandomCode(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random();
    return String.fromCharCodes(Iterable.generate(
        length, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  }

  Future<void> _processReservation() async {
    setState(() => _isProcessing = true);

    try {
      final userId = _cachedUserId.isNotEmpty ? _cachedUserId : widget.userId;

      String contactName = _isGuest
          ? _guestNameCtrl.text.trim()
          : (_cachedUserName.isNotEmpty ? _cachedUserName : "");
      String contactEmail =
          _isGuest ? _guestEmailCtrl.text.trim() : _cachedUserEmail;
      String contactPhone = _isGuest ? _guestPhoneCtrl.text.trim() : "";

      // SIEMPRE fetch desde Firestore — en Safari _isGuest puede ser true
      // aunque el usuario esté logueado porque Firebase Auth falla.
      if (userId.isNotEmpty) {
        try {
          final userUrl =
              'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents/usuarios/$userId?key=$_apiKey';
          final userResponse = await http
              .get(Uri.parse(userUrl))
              .timeout(const Duration(seconds: 5));
          if (userResponse.statusCode == 200) {
            final parsedUser =
                _convertFirestoreMap(jsonDecode(userResponse.body));
            final fsName = parsedUser['name']?.toString() ?? '';
            final fsEmail = parsedUser['email']?.toString() ?? '';
            final fsPhone = parsedUser['celular']?.toString() ??
                parsedUser['telefono']?.toString() ??
                '';
            if (fsName.isNotEmpty) contactName = fsName;
            if (fsEmail.isNotEmpty) contactEmail = fsEmail;
            if (fsPhone.isNotEmpty && contactPhone.isEmpty) {
              contactPhone = fsPhone;
            }
          }
        } catch (_) {}
      }
      if (contactName.isEmpty) contactName = "Cliente";

      double finalAmount = widget.totalPrice;
      if (_payInInstallments && _installmentConfig.isNotEmpty) {
        finalAmount = widget.totalPrice * (_installmentConfig[0] / 100);
      }

      double tasa = _exchangeRate > 0 ? _exchangeRate : 67.0;
      final double amountBs = finalAmount * tasa;
      final double finalTotal = widget.totalPrice;
      final String paymentStatus =
          (_payInInstallments && finalAmount < (finalTotal - 0.1))
              ? 'partial'
              : 'completed';
      final String documentId = _generateRandomCode(20).toLowerCase();
      final String code = _generateRandomCode(8);
      final String fechaIso = DateTime.now().toIso8601String();

      final Map<String, dynamic> initialPaymentDetails = {
        'amountBs': amountBs,
        'currencyRate': tasa,
        'method': widget.paymentMethod,
        if (widget.paymentMethod == 'Pago móvil') ...{
          'referencia': _transactionCtrl.text,
          'cedula': _payerIdCtrl.text,
          'telefono': _payerPhoneCtrl.text,
        } else if (widget.paymentMethod != 'Efectivo') ...{
          'referencia': _transactionCtrl.text,
          'email_pago': _payerEmailCtrl.text,
          'titular': _payerNameCtrl.text,
        }
      };

      Map<String, dynamic> toFV(dynamic val) {
        if (val == null) return {'nullValue': null};
        if (val is bool) return {'booleanValue': val};
        if (val is int) return {'integerValue': val.toString()};
        if (val is double) return {'doubleValue': val};
        if (val is String) return {'stringValue': val};
        if (val is List) {
          return {
            'arrayValue': {'values': val.map((e) => toFV(e)).toList()}
          };
        }
        if (val is Map) {
          return {
            'mapValue': {
              'fields': val.map((k, v) => MapEntry(k.toString(), toFV(v)))
            }
          };
        }
        return {'stringValue': val.toString()};
      }

      final firstPayment = {
        ...initialPaymentDetails,
        'amount': finalAmount,
        'date': fechaIso,
        'type': 'initial',
        'status': 'verified',
      };

      final List<Map<String, dynamic>> packages = _cleanPackagesData.map((pkg) {
        final String bt = pkg['tipoDeReserva']?.toString() ?? 'Reserva';
        final Map<String, dynamic> p = {
          'numero': pkg['numero'],
          'personas': pkg['personas'],
          'miniDescripcion': pkg['miniDescripcion'],
          'tipoDeReserva': bt,
        };
        if (bt == 'Reserva') {
          p['fechaReserva'] = pkg['fecha']?.toString() ?? '';
          p['horaReserva'] = pkg['hora']?.toString() ?? '';
        } else if (bt == 'Reserva Flexible') {
          p['instrucciones'] = pkg['instrucciones']?.toString() ?? '';
        }
        return p;
      }).toList();

      final bookingFields = {
        'userId': toFV(userId),
        'supplier': toFV(widget.supplier),
        'planName': toFV(widget.planName),
        'planLocation': toFV(widget.planLocation),
        'amountPaid': toFV(finalAmount),
        'totalPlanPrice': toFV(finalTotal),
        'totalPriceBs': toFV(amountBs),
        'isInstallment': toFV(_payInInstallments),
        'installmentsPaid': toFV(_payInInstallments ? 1 : 0),
        'paymentStatus': toFV(paymentStatus),
        'paymentHistory': toFV([firstPayment]),
        'paymentMethod': toFV(widget.paymentMethod),
        'transactionCode': toFV(_transactionCtrl.text),
        'receipt': toFV(''),
        'cedula': toFV(_payerIdCtrl.text),
        'numero': toFV(_payerPhoneCtrl.text),
        'correo': toFV(_payerEmailCtrl.text),
        'name': toFV(contactName),
        'email': toFV(contactEmail),
        'celular': toFV(contactPhone),
        'fecha': toFV(fechaIso),
        'createdAt': toFV(fechaIso),
        'estado': toFV('pendiente'),
        'code': toFV(code),
        'packages': toFV(packages),
        // Divisa del destino — campo nuevo, no afecta los campos existentes
        'divisa': toFV(widget.divisa),
        // Respuestas del cliente a las preguntas del proveedor
        if (widget.questionAnswers.isNotEmpty)
          'respuestasPreguntas': toFV(widget.questionAnswers),
      };

      final writeUrl =
          'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents/reservaciones/${widget.supplier}/reservas/$documentId?key=$_apiKey';

      final writeResponse = await http
          .patch(
            Uri.parse(writeUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'fields': bookingFields}),
          )
          .timeout(const Duration(seconds: 15));

      if (writeResponse.statusCode != 200 && writeResponse.statusCode != 201) {
        throw Exception(
            'Error guardando reserva HTTP ${writeResponse.statusCode}: '
            '${writeResponse.body.substring(0, writeResponse.body.length.clamp(0, 300))}');
      }

      // Notificación al proveedor — no bloquea
      _sendNotificationToSupplier(widget.supplier, widget.planName, contactName)
          .catchError((_) {});

      // Email al usuario — se espera (await) para que el correo salga
      // antes de mostrar el diálogo de éxito. Si falla, no bloquea la UI.
      final String emailToUse =
          contactEmail.isNotEmpty ? contactEmail : _payerEmailCtrl.text;
      if (emailToUse.isNotEmpty) {
        await _sendUserEmail(
          contactEmail: emailToUse,
          contactName: contactName.isNotEmpty ? contactName : 'Cliente',
          planName: widget.planName,
          code: code,
          paidAmount: finalAmount,
          totalAmount: widget.totalPrice,
          paymentMethod: widget.paymentMethod,
        ).catchError((_) {});
      }

      if (!mounted) return;
      _showSuccessDialog(
        code: code,
        contactName: contactName,
        contactEmail: emailToUse,
        planName: widget.planName,
        planLocation: widget.planLocation,
        paidAmount: finalAmount,
        totalAmount: widget.totalPrice,
        amountBs: amountBs,
        tasa: tasa,
        paymentMethod: widget.paymentMethod,
        packages: packages,
        fechaIso: fechaIso,
      );
    } catch (e) {
      if (mounted) _showErrorDialog("Error al procesar: $e");
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ─── Notificación al proveedor — estrategia dual ──────────────────────────
  // Token OAuth2 cacheado en memoria para no hacer roundtrip en cada llamada
  // Se invalida después de 55 minutos (los tokens Google duran 60 min).
  static String? _cachedFcmToken;
  static DateTime? _fcmTokenExpiry;

  Future<void> _sendNotificationToSupplier(
      String supplierId, String planName, String clientName) async {
    // Paso 1: Firestore via REST — guarda la notificación (siempre funciona)
    try {
      final notifId = DateTime.now().millisecondsSinceEpoch.toString();
      final notifUrl =
          'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents/notificaciones/$supplierId/pending/$notifId?key=$_apiKey';
      await http
          .patch(
            Uri.parse(notifUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'fields': {
                'type': {'stringValue': 'new_reservation'},
                'planName': {'stringValue': planName},
                'clientName': {'stringValue': clientName},
                'supplierId': {'stringValue': supplierId},
                'createdAt': {'stringValue': DateTime.now().toIso8601String()},
                'read': {'booleanValue': false},
              }
            }),
          )
          .timeout(const Duration(seconds: 8));
    } catch (_) {}

    // Paso 2: FCM push via service account
    // El path del asset DEBE llevar 'assets/' en nativo (Android/iOS).
    // En web Flutter también lo resuelve correctamente con el prefijo.
    const String serviceAccountPath =
        'assets/biqoe-app-firebase-adminsdk-fbsvc-067c9b5471.json';
    const List<String> scopes = [
      'https://www.googleapis.com/auth/firebase.messaging'
    ];

    try {
      debugPrint('🔔 [FCM] Buscando token del proveedor $supplierId...');

      // Obtener fcmToken del proveedor via REST
      final supplierUrl =
          'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents/usuarios/$supplierId?key=$_apiKey';
      final supplierResponse = await http
          .get(Uri.parse(supplierUrl))
          .timeout(const Duration(seconds: 8));
      if (supplierResponse.statusCode != 200) {
        debugPrint(
            '🔔 [FCM] HTTP ${supplierResponse.statusCode} al buscar proveedor');
        return;
      }
      final parsedSupplier =
          _convertFirestoreMap(jsonDecode(supplierResponse.body));
      final String? deviceToken = parsedSupplier['fcmToken']?.toString() ??
          parsedSupplier['deviceToken']?.toString();
      if (deviceToken == null || deviceToken.isEmpty) {
        debugPrint('🔔 [FCM] Sin token FCM para el proveedor.');
        return;
      }
      debugPrint(
          '🔔 [FCM] Token encontrado: ${deviceToken.substring(0, deviceToken.length.clamp(0, 20))}...');

      // Obtener access token OAuth2 (cacheado para evitar roundtrips repetidos)
      final String accessToken;
      final now = DateTime.now();
      if (_cachedFcmToken != null &&
          _fcmTokenExpiry != null &&
          now.isBefore(_fcmTokenExpiry!)) {
        debugPrint('🔔 [FCM] Usando access token cacheado.');
        accessToken = _cachedFcmToken!;
      } else {
        debugPrint('🔔 [FCM] Solicitando nuevo access token...');
        final String serviceAccountJson =
            await rootBundle.loadString(serviceAccountPath);
        final serviceAccount =
            ServiceAccountCredentials.fromJson(serviceAccountJson);
        // clientViaServiceAccount con timeout explícito via http.Client
        final httpClient = http.Client();
        try {
          final credentials = await obtainAccessCredentialsViaServiceAccount(
            serviceAccount,
            scopes,
            httpClient,
          ).timeout(const Duration(seconds: 20));
          accessToken = credentials.accessToken.data;
          _cachedFcmToken = accessToken;
          // Invalidar 5 minutos antes de la expiración real
          _fcmTokenExpiry = credentials.accessToken.expiry
              .subtract(const Duration(minutes: 5));
          debugPrint(
              '🔔 [FCM] Access token obtenido. Expira: $_fcmTokenExpiry');
        } finally {
          httpClient.close();
        }
      }

      // Enviar la notificación FCM con el token OAuth2
      debugPrint('🔔 [FCM] Enviando push...');
      final fcmResponse = await http
          .post(
            Uri.parse(
                'https://fcm.googleapis.com/v1/projects/$_projectId/messages:send'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $accessToken',
            },
            body: jsonEncode({
              'message': {
                'token': deviceToken,
                'notification': {
                  'title': 'Nueva Reserva 📅',
                  'body': '$clientName ha reservado $planName. ¡Verifícalo!',
                },
                'data': {
                  'click_action': 'FLUTTER_NOTIFICATION_CLICK',
                  'screen': 'dashboard',
                  'type': 'new_reservation',
                  'planName': planName,
                },
                'android': {
                  'priority': 'high',
                  'notification': {'sound': 'default'},
                },
                'apns': {
                  'payload': {
                    'aps': {'sound': 'default', 'badge': 1}
                  }
                },
              }
            }),
          )
          .timeout(const Duration(seconds: 15));

      debugPrint('🔔 [FCM] ✅ Push enviado. Status: ${fcmResponse.statusCode}');
      if (fcmResponse.statusCode != 200) {
        debugPrint(
            '🔔 [FCM] Body: ${fcmResponse.body.substring(0, fcmResponse.body.length.clamp(0, 300))}');
        // Si el token expiró o fue rechazado, limpiarlo para el próximo intento
        if (fcmResponse.statusCode == 401) {
          _cachedFcmToken = null;
          _fcmTokenExpiry = null;
        }
      }
    } catch (e) {
      debugPrint('🔔 [FCM] ❌ Error: $e');
      // Limpiar token cacheado si hubo error de autenticación
      _cachedFcmToken = null;
      _fcmTokenExpiry = null;
    }
  }

  // ─── Email al usuario ─────────────────────────────────────────────────────
  Future<void> _sendUserEmail({
    required String contactEmail,
    required String contactName,
    required String planName,
    required String code,
    required double paidAmount,
    required double totalAmount,
    required String paymentMethod,
  }) async {
    debugPrint('📧 [EMAIL] Iniciando envío a $contactEmail | kIsWeb=$kIsWeb');

    final Set<String> recipientSet = {};
    if (contactEmail.isNotEmpty) recipientSet.add(contactEmail);
    if (_payerEmailCtrl.text.isNotEmpty) recipientSet.add(_payerEmailCtrl.text);
    if (_guestEmailCtrl.text.isNotEmpty) recipientSet.add(_guestEmailCtrl.text);
    if (_cachedUserEmail.isNotEmpty) recipientSet.add(_cachedUserEmail);
    final List<String> recipients =
        recipientSet.where((e) => e.isNotEmpty).toList();

    if (recipients.isEmpty) {
      debugPrint('📧 [EMAIL] Sin destinatarios — abortando.');
      return;
    }

    final String paidStr = paidAmount.toStringAsFixed(2);
    final String yearStr = DateTime.now().year.toString();
    final String dateStr = '${DateTime.now().day.toString().padLeft(2, '0')}/'
        '${DateTime.now().month.toString().padLeft(2, '0')}/'
        '${DateTime.now().year}';
    final String qrUrl =
        'https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=$code&color=113049';

    // HTML compacto para evitar URL demasiado larga en GET
    final String htmlContent =
        '<div style="font-family:Arial,sans-serif;color:#333;max-width:600px;'
        'margin:0 auto;padding:20px;border:1px solid #e0e0e0;border-radius:8px;background:#fff;">'
        '<h2 style="color:#113049;text-align:center;">¡Solicitud recibida!</h2>'
        '<p>Tu reserva está en proceso de verificación.</p>'
        '<p>Hola <strong>$contactName</strong>, gracias por reservar '
        '<strong>$planName</strong>.</p>'
        '<div style="background:#f0f7ff;padding:20px;border-radius:8px;'
        'text-align:center;margin:20px 0;border:1px dashed #113049;">'
        '<p style="font-size:12px;text-transform:uppercase;color:#555;">Código de reserva</p>'
        '<h1 style="font-size:32px;letter-spacing:5px;color:#113049;">$code</h1>'
        '<img src="$qrUrl" width="150" height="150" '
        'style="border:4px solid white;border-radius:8px;" />'
        '<p style="font-size:11px;color:#666;">Muestra este código al llegar</p>'
        '</div>'
        '<table style="width:100%;border-collapse:collapse;">'
        '<tr><td style="padding:8px 0;color:#666;">Fecha:</td>'
        '<td style="text-align:right;font-weight:bold;">$dateStr</td></tr>'
        '<tr><td style="padding:8px 0;color:#666;">Actividad:</td>'
        '<td style="text-align:right;font-weight:bold;">$planName</td></tr>'
        '<tr><td style="padding:8px 0;color:#666;">Método de pago:</td>'
        '<td style="text-align:right;">$paymentMethod</td></tr>'
        '<tr style="background:#f0f7ff;"><td style="padding:8px 5px;'
        'color:#113049;font-weight:bold;">Monto pagado (${widget.divisa.toUpperCase()}):</td>'
        '<td style="text-align:right;font-weight:bold;color:#113049;">'
        '${widget.divisa == 'eur' ? '€' : '\$'}$paidStr</td></tr>'
        '</table>'
        '<p style="text-align:center;color:#888;font-size:12px;margin-top:20px;">'
        '&copy; $yearStr Biqoe App</p>'
        '</div>';

    const String gasUrl =
        'https://script.google.com/macros/s/AKfycbz5Wy1Qtn_uUT1sgL78MYOWvI4M3TJA1fml0rTd7qtjQBAB2DI7MXMP74P24aFN7bT6Jg/exec';

    final Map<String, dynamic> payload = {
      'to': recipients.join(','),
      'subject': 'Reserva Recibida - $planName ($code)',
      'htmlBody': htmlContent,
      'name': 'Biqoe Reservas',
    };

    if (kIsWeb) {
      // ── WEB: fetch nativo con mode:'no-cors' ──────────────────────────────
      // POST JSON a GAS desde el browser falla por CORS preflight. Con
      // mode:'no-cors' se envía sin preflight y sin leer la respuesta (opaque),
      // pero el GAS recibe la petición y ejecuta el envío de correo.
      try {
        debugPrint('📧 [EMAIL] Web: fetch no-cors...');
        final jsonBody = jsonEncode(payload);
        // sendNoCorsPost está en fetch_helper_web.dart (web) /
        // fetch_helper_stub.dart (nativo — no-op). Import condicional.
        sendNoCorsPost(gasUrl, jsonBody);
        debugPrint('📧 [EMAIL] ✅ fetch no-cors disparado (el GAS procesará)');
      } catch (e) {
        debugPrint('📧 [EMAIL] ❌ fetch no-cors falló: $e → fallback http...');
        try {
          final r = await http
              .post(Uri.parse(gasUrl),
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode(payload))
              .timeout(const Duration(seconds: 30));
          debugPrint('📧 [EMAIL] Fallback http status: ${r.statusCode}');
        } catch (e2) {
          debugPrint('📧 [EMAIL] ❌ Fallback también falló: $e2');
        }
      }
    } else {
      // ── NATIVO: http POST sin restricciones CORS ─────────────────────────
      try {
        debugPrint('📧 [EMAIL] Nativo: POST JSON...');
        final r = await http
            .post(Uri.parse(gasUrl),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode(payload))
            .timeout(const Duration(seconds: 30));
        debugPrint(
            '📧 [EMAIL] ✅ status: ${r.statusCode} body: ${r.body.substring(0, r.body.length.clamp(0, 200))}');
      } catch (e) {
        debugPrint('📧 [EMAIL] ❌ Nativo falló: $e');
      }
    }
  }

  // ─── Generación de imagen del comprobante ────────────────────────────────
  // Usamos RepaintBoundary + RenderRepaintBoundary.toImage() para generar
  // un PNG del comprobante sin dart:html, sin pdf, sin printing.
  // Funciona en todas las plataformas: web (Safari, Chrome, Android), nativo.
  //
  // En web: abre la imagen en una nueva pestaña (compatible con Safari)
  //         usando window.open() via dart:js, que sí funciona desde un
  //         gesto síncrono de usuario (tap en botón).
  // En nativo: muestra la imagen en un diálogo con botón de compartir.

  Future<Uint8List?> _generateReceiptImage({
    required String code,
    required String contactName,
    required String contactEmail,
    required String planName,
    required String planLocation,
    required double paidAmount,
    required double totalAmount,
    required double amountBs,
    required double tasa,
    required String paymentMethod,
    required List<Map<String, dynamic>> packages,
    required String fechaIso,
  }) async {
    debugPrint('🖼️ [RECEIPT] Generando imagen del comprobante...');

    // Parsear fecha
    String fechaStr = '';
    try {
      final dt = DateTime.parse(fechaIso);
      fechaStr =
          '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      fechaStr = fechaIso.split('T').first;
    }

    // Cargar QR como imagen
    Uint8List? qrBytes;
    try {
      final qrUrl =
          'https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=$code&color=113049';
      final qrResponse =
          await http.get(Uri.parse(qrUrl)).timeout(const Duration(seconds: 8));
      if (qrResponse.statusCode == 200) qrBytes = qrResponse.bodyBytes;
    } catch (_) {}

    // Cargar logo
    Uint8List? logoBytes;
    try {
      final logoData = await rootBundle.load('assets/images/Biqoe logo.png');
      logoBytes = logoData.buffer.asUint8List();
    } catch (_) {}

    const double W = 600;
    const double padding = 24;
    const Color primary = Color.fromRGBO(17, 48, 73, 1);
    const Color lightBlue = Color(0xFFF0F7FF);

    // Construimos el widget del comprobante fuera del árbol de widgets para
    // renderizarlo a imagen con toImage().
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Calcular altura dinámica según paquetes
    double baseH = 520;
    if (packages.isNotEmpty) baseH += 30 + packages.length * 36.0;
    if (tasa > 0) baseH += 28;
    if (totalAmount > paidAmount) baseH += 56;

    final paint = Paint();

    // Fondo blanco
    paint.color = Colors.white;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, W, baseH), const Radius.circular(16)),
      paint,
    );

    // Helper: texto
    void drawText(String text, double x, double y,
        {double fontSize = 12,
        Color color = const Color(0xFF333333),
        FontWeight weight = FontWeight.normal,
        double maxWidth = 500,
        TextAlign align = TextAlign.left}) {
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: fontSize,
              color: color,
              fontWeight: weight),
        ),
        textDirection: TextDirection.ltr,
        textAlign: align,
      )..layout(maxWidth: maxWidth);
      tp.paint(canvas, Offset(x, y));
    }

    // Helper: línea horizontal
    void drawLine(double y,
        {Color color = const Color(0xFFEEEEEE), double thickness = 1}) {
      paint.color = color;
      canvas.drawRect(
          Rect.fromLTWH(padding, y, W - padding * 2, thickness), paint);
    }

    // Helper: rectángulo redondeado con color
    void drawRect(double x, double y, double w, double h,
        {Color color = lightBlue, double radius = 10}) {
      paint.color = color;
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(x, y, w, h), Radius.circular(radius)),
          paint);
    }

    double cy = padding;

    // ── Logo / Header ────────────────────────────────────────────────────────
    if (logoBytes != null) {
      final codec = await ui.instantiateImageCodec(logoBytes,
          targetWidth: 80, targetHeight: 28);
      final frame = await codec.getNextFrame();
      canvas.drawImage(frame.image, Offset(padding, cy), Paint());
    } else {
      drawText('BIQOE', padding, cy + 4,
          fontSize: 20, color: primary, weight: FontWeight.bold);
    }
    drawText('COMPROBANTE DE RESERVA', W - padding - 180, cy + 4,
        fontSize: 11, color: primary, weight: FontWeight.bold, maxWidth: 180);
    drawText('Fecha: $fechaStr', W - padding - 180, cy + 20,
        fontSize: 9, color: const Color(0xFF666666), maxWidth: 180);

    cy += 44;
    drawLine(cy, color: primary, thickness: 1.5);
    cy += 14;

    // ── Bloque azul: actividad + código ─────────────────────────────────────
    drawRect(padding, cy, W - padding * 2, 90, color: lightBlue);
    drawText('ACTIVIDAD', padding + 12, cy + 10,
        fontSize: 8, color: const Color(0xFF888888), weight: FontWeight.bold);
    drawText(planName, padding + 12, cy + 22,
        fontSize: 15, color: primary, weight: FontWeight.bold, maxWidth: 340);
    drawText('UBICACIÓN', padding + 12, cy + 44,
        fontSize: 8, color: const Color(0xFF888888), weight: FontWeight.bold);
    drawText(planLocation, padding + 12, cy + 56,
        fontSize: 11, color: const Color(0xFF444444), maxWidth: 340);

    // Código único (derecha del bloque azul)
    drawText('CÓDIGO', W - padding - 150, cy + 10,
        fontSize: 8,
        color: const Color(0xFF888888),
        weight: FontWeight.bold,
        maxWidth: 150);
    drawText(code, W - padding - 150, cy + 22,
        fontSize: 18, color: primary, weight: FontWeight.bold, maxWidth: 150);

    cy += 100;

    // ── QR ───────────────────────────────────────────────────────────────────
    if (qrBytes != null) {
      try {
        final qrCodec = await ui.instantiateImageCodec(qrBytes,
            targetWidth: 110, targetHeight: 110);
        final qrFrame = await qrCodec.getNextFrame();
        // Borde blanco alrededor del QR
        drawRect(W - padding - 126, cy - 100, 122, 122,
            color: Colors.white, radius: 8);
        paint.color = primary;
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(W - padding - 126, cy - 100, 122, 122),
                const Radius.circular(8)),
            Paint()
              ..color = primary
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5);
        canvas.drawImage(
            qrFrame.image, Offset(W - padding - 118, cy - 94), Paint());
        drawText('Muestra este QR al llegar', W - padding - 126, cy + 26,
            fontSize: 8, color: const Color(0xFF888888), maxWidth: 122);
      } catch (_) {}
    }

    // ── Datos del titular ────────────────────────────────────────────────────
    drawText('DATOS DEL TITULAR', padding, cy,
        fontSize: 8, color: const Color(0xFF888888), weight: FontWeight.bold);
    cy += 14;
    drawText('Nombre: ', padding, cy,
        fontSize: 9, color: const Color(0xFF888888));
    drawText(contactName, padding + 58, cy,
        fontSize: 10, color: Colors.black, weight: FontWeight.bold);
    if (contactEmail.isNotEmpty) {
      cy += 16;
      drawText('Email: ', padding, cy,
          fontSize: 9, color: const Color(0xFF888888));
      drawText(contactEmail, padding + 44, cy,
          fontSize: 10, color: const Color(0xFF444444), maxWidth: 340);
    }
    cy += 24;
    drawLine(cy);
    cy += 14;

    // ── Detalle de paquetes ──────────────────────────────────────────────────
    if (packages.isNotEmpty) {
      drawText('DETALLE DE PAQUETES', padding, cy,
          fontSize: 8, color: const Color(0xFF888888), weight: FontWeight.bold);
      cy += 14;
      // Cabecera tabla
      drawRect(padding, cy, W - padding * 2, 24,
          color: const Color(0xFFF5F5F5), radius: 4);
      drawText('Descripción', padding + 6, cy + 6,
          fontSize: 8, weight: FontWeight.bold, maxWidth: 240);
      drawText('Pers.', padding + 260, cy + 6,
          fontSize: 8, weight: FontWeight.bold, maxWidth: 50);
      drawText('Tipo / Fecha', padding + 330, cy + 6,
          fontSize: 8, weight: FontWeight.bold, maxWidth: 200);
      cy += 24;
      for (var pkg in packages) {
        final tipo = pkg['tipoDeReserva']?.toString() ?? '';
        String info = '';
        if (tipo == 'Reserva') {
          info =
              '${pkg['fechaReserva'] ?? ''} ${pkg['horaReserva'] ?? ''}'.trim();
        } else if (tipo == 'Reserva Flexible') {
          info = pkg['instrucciones']?.toString() ?? '';
        } else {
          info = tipo;
        }
        drawText(pkg['miniDescripcion']?.toString() ?? '', padding + 6, cy + 4,
            fontSize: 9, maxWidth: 240);
        drawText(pkg['personas']?.toString() ?? '', padding + 260, cy + 4,
            fontSize: 9, maxWidth: 50);
        drawText(info, padding + 330, cy + 4, fontSize: 9, maxWidth: 200);
        cy += 28;
        drawLine(cy, color: const Color(0xFFEEEEEE));
        cy += 6;
      }
      cy += 8;
    }

    // ── Resumen de pago ──────────────────────────────────────────────────────
    drawText('RESUMEN DE PAGO', padding, cy,
        fontSize: 8, color: const Color(0xFF888888), weight: FontWeight.bold);
    cy += 14;

    drawRect(padding, cy, W - padding * 2,
        tasa > 0 ? (totalAmount > paidAmount ? 124 : 80) : 56,
        color: const Color(0xFFF5F5F5), radius: 8);

    final rowH = 26.0;
    // Método de pago
    drawText('Método de pago', padding + 12, cy + 10,
        fontSize: 9, color: const Color(0xFF888888));
    drawText(paymentMethod, W - padding - 12 - 160, cy + 10,
        fontSize: 9, color: Colors.black, maxWidth: 160);
    // Monto pagado
    drawText('Monto pagado (${widget.divisa.toUpperCase()})', padding + 12,
        cy + 10 + rowH,
        fontSize: 9, color: const Color(0xFF888888));
    drawText('$_currencySymbol${paidAmount.toStringAsFixed(2)}',
        W - padding - 12 - 160, cy + 10 + rowH,
        fontSize: 11,
        color: Colors.black,
        weight: FontWeight.bold,
        maxWidth: 160);
    if (tasa > 0) {
      drawText('Monto en Bs (Tasa: ${tasa.toStringAsFixed(2)})', padding + 12,
          cy + 10 + rowH * 2,
          fontSize: 9, color: const Color(0xFF888888));
      drawText('Bs ${amountBs.toStringAsFixed(2)}', W - padding - 12 - 160,
          cy + 10 + rowH * 2,
          fontSize: 9, color: Colors.black, maxWidth: 160);
    }
    if (totalAmount > paidAmount) {
      final extra = tasa > 0 ? rowH * 3 : rowH * 2;
      drawText('Saldo restante', padding + 12, cy + 10 + extra,
          fontSize: 9, color: const Color(0xFF888888));
      drawText(
          '$_currencySymbol${(totalAmount - paidAmount).toStringAsFixed(2)}',
          W - padding - 12 - 160,
          cy + 10 + extra,
          fontSize: 11,
          color: const Color(0xFFE65100),
          weight: FontWeight.bold,
          maxWidth: 160);
    }
    cy += tasa > 0 ? (totalAmount > paidAmount ? 134 : 90) : 66;

    // ── Footer ───────────────────────────────────────────────────────────────
    cy += 14;
    drawLine(cy, color: const Color(0xFFDDDDDD));
    cy += 10;
    drawText('Biqoe — Explora, reserva y vive experiencias únicas en Venezuela',
        0, cy,
        fontSize: 8,
        color: const Color(0xFFAAAAAA),
        maxWidth: W,
        align: TextAlign.center);
    cy += 14;
    drawText('Estado: PENDIENTE DE VERIFICACIÓN POR EL PROVEEDOR', 0, cy,
        fontSize: 8,
        color: const Color(0xFFFF6F00),
        weight: FontWeight.bold,
        maxWidth: W,
        align: TextAlign.center);

    final picture = recorder.endRecording();
    final img = await picture.toImage(W.toInt(), baseH.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return null;

    final bytes = byteData.buffer.asUint8List();
    debugPrint('🖼️ [RECEIPT] ✅ Imagen generada: ${bytes.length} bytes');
    return bytes;
  }

  Future<void> _showReceiptImage({
    required BuildContext dialogContext,
    required String code,
    required String contactName,
    required String contactEmail,
    required String planName,
    required String planLocation,
    required double paidAmount,
    required double totalAmount,
    required double amountBs,
    required double tasa,
    required String paymentMethod,
    required List<Map<String, dynamic>> packages,
    required String fechaIso,
  }) async {
    if (kIsWeb) {
      if (isSafariBrowser()) {
        // ── SAFARI / APPLE WEB ───────────────────────────────────────────────
        // Safari no permite descargar PDFs generados en memoria.
        // Mostramos un diálogo modal compacto con toda la info del comprobante
        // para que el usuario tome captura de pantalla.
        debugPrint(
            '📄 [RECEIPT] Safari detectado → mostrando diálogo captura.');
        if (!mounted) return;
        _showSafariReceiptDialog(
          context: context,
          code: code,
          contactName: contactName,
          planName: planName,
          planLocation: planLocation,
          paidAmount: paidAmount,
          totalAmount: totalAmount,
          amountBs: amountBs,
          tasa: tasa,
          paymentMethod: paymentMethod,
          packages: packages,
          fechaIso: fechaIso,
        );
      } else {
        // ── ANDROID WEB / CHROME / FIREFOX ──────────────────────────────────
        // layoutPdf abre el visor PDF nativo del browser con botón de descarga.
        debugPrint('📄 [RECEIPT-WEB] Chrome/Android: layoutPdf...');
        try {
          await Printing.layoutPdf(
            name: 'Reserva-$code.pdf',
            onLayout: (_) async => _buildPdfBytes(
              code: code,
              contactName: contactName,
              contactEmail: contactEmail,
              planName: planName,
              planLocation: planLocation,
              paidAmount: paidAmount,
              totalAmount: totalAmount,
              amountBs: amountBs,
              tasa: tasa,
              paymentMethod: paymentMethod,
              packages: packages,
              fechaIso: fechaIso,
            ),
          );
          debugPrint('📄 [RECEIPT-WEB] ✅ layoutPdf completado');
        } catch (e) {
          debugPrint('📄 [RECEIPT-WEB] ❌ layoutPdf falló: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('No se pudo abrir el comprobante. Código: $code'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 6),
            ));
          }
        }
      }
    } else {
      // ── NATIVO (Android app / iOS app) ───────────────────────────────────
      debugPrint('🖼️ [RECEIPT-NATIVE] Generando imagen...');
      final imgBytes = await _generateReceiptImage(
        code: code,
        contactName: contactName,
        contactEmail: contactEmail,
        planName: planName,
        planLocation: planLocation,
        paidAmount: paidAmount,
        totalAmount: totalAmount,
        amountBs: amountBs,
        tasa: tasa,
        paymentMethod: paymentMethod,
        packages: packages,
        fechaIso: fechaIso,
      );
      if (imgBytes == null) {
        try {
          final pdfBytes = await _buildPdfBytes(
            code: code,
            contactName: contactName,
            contactEmail: contactEmail,
            planName: planName,
            planLocation: planLocation,
            paidAmount: paidAmount,
            totalAmount: totalAmount,
            amountBs: amountBs,
            tasa: tasa,
            paymentMethod: paymentMethod,
            packages: packages,
            fechaIso: fechaIso,
          );
          await Printing.sharePdf(
              bytes: pdfBytes, filename: 'Reserva-$code.pdf');
        } catch (_) {}
        return;
      }
      if (!dialogContext.mounted) return;

      showDialog(
        context: dialogContext,
        builder: (ctx) => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: Image.memory(imgBytes,
                    width: double.infinity, fit: BoxFit.fitWidth),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          try {
                            final pdfBytes = await _buildPdfBytes(
                              code: code,
                              contactName: contactName,
                              contactEmail: contactEmail,
                              planName: planName,
                              planLocation: planLocation,
                              paidAmount: paidAmount,
                              totalAmount: totalAmount,
                              amountBs: amountBs,
                              tasa: tasa,
                              paymentMethod: paymentMethod,
                              packages: packages,
                              fechaIso: fechaIso,
                            );
                            await Printing.sharePdf(
                                bytes: pdfBytes, filename: 'Reserva-$code.pdf');
                          } catch (_) {}
                        },
                        icon: const Icon(Icons.share, color: Colors.white),
                        label: const Text('Compartir PDF',
                            style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: kPrimaryColor),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cerrar'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  // ── Diálogo compacto para Safari: muestra el comprobante para captura ─────
  void _showSafariReceiptDialog({
    required BuildContext context,
    required String code,
    required String contactName,
    required String planName,
    required String planLocation,
    required double paidAmount,
    required double totalAmount,
    required double amountBs,
    required double tasa,
    required String paymentMethod,
    required List<Map<String, dynamic>> packages,
    required String fechaIso,
  }) {
    String fechaStr = '';
    try {
      final dt = DateTime.parse(fechaIso);
      fechaStr =
          '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      fechaStr = fechaIso.split('T').first;
    }

    final qrUrl =
        'https://api.qrserver.com/v1/create-qr-code/?size=160x160&data=$code&color=113049';

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          // Compacto: máximo 88% del alto de pantalla, sin scroll
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.88,
            maxWidth: 420,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Banner "Toma captura de pantalla" ──────────────────────────
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: const BoxDecoration(
                  color: kPrimaryColor,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.photo_camera,
                        color: Colors.white, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '📸  Toma captura de pantalla',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    // Botón X para cerrar
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        // Navegar al perfil del proveedor (comportamiento web)
                        Navigator.of(context, rootNavigator: true)
                            .popUntil((route) => route.isFirst);
                        final target =
                            _supplierSlug.isNotEmpty ? '/$_supplierSlug' : '/';
                        context.replace(target);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close,
                            color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Contenido del comprobante ───────────────────────────────────
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Actividad + código en fila
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F7FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: kPrimaryColor.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Info izquierda
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('ACTIVIDAD',
                                      style: GoogleFonts.poppins(
                                          fontSize: 9,
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5)),
                                  Text(planName,
                                      style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: kPrimaryColor)),
                                  const SizedBox(height: 6),
                                  Text('CÓDIGO ÚNICO',
                                      style: GoogleFonts.poppins(
                                          fontSize: 9,
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5)),
                                  Text(code,
                                      style: GoogleFonts.poppins(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: kPrimaryColor,
                                          letterSpacing: 3)),
                                  const SizedBox(height: 6),
                                  Text('TITULAR',
                                      style: GoogleFonts.poppins(
                                          fontSize: 9,
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5)),
                                  Text(contactName,
                                      style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            // QR
                            Column(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    qrUrl,
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 80,
                                      height: 80,
                                      color: Colors.grey[200],
                                      child: const Icon(Icons.qr_code,
                                          color: kPrimaryColor, size: 40),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text('Muestra al llegar',
                                    style: GoogleFonts.poppins(
                                        fontSize: 8, color: Colors.grey[600])),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Resumen de pago
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            _receiptRow('Fecha', fechaStr),
                            _receiptRow('Método de pago', paymentMethod),
                            _receiptRow('Monto pagado',
                                '$_currencySymbol${paidAmount.toStringAsFixed(2)} $_currencyLabel',
                                bold: true),
                            if (tasa > 0)
                              _receiptRow('Equivalente',
                                  'Bs ${amountBs.toStringAsFixed(2)}'),
                            if (totalAmount > paidAmount)
                              _receiptRow('Saldo restante',
                                  '$_currencySymbol${(totalAmount - paidAmount).toStringAsFixed(2)} $_currencyLabel',
                                  color: Colors.orange[800]!),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Estado pendiente
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'PENDIENTE DE VERIFICACIÓN',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[800]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper de fila para el diálogo de comprobante Safari
  Widget _receiptRow(String label, String value,
      {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style:
                  GoogleFonts.poppins(fontSize: 11, color: Colors.grey[600])),
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                  color: color ?? Colors.black87)),
        ],
      ),
    );
  }

  // ── Genera bytes del PDF del comprobante (web y nativo) ───────────────────
  Future<Uint8List> _buildPdfBytes({
    required String code,
    required String contactName,
    required String contactEmail,
    required String planName,
    required String planLocation,
    required double paidAmount,
    required double totalAmount,
    required double amountBs,
    required double tasa,
    required String paymentMethod,
    required List<Map<String, dynamic>> packages,
    required String fechaIso,
  }) async {
    final pdf = pw.Document();

    pw.MemoryImage? logoImage;
    try {
      final logoData = await rootBundle.load('assets/images/Biqoe logo.png');
      logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (_) {}

    pw.MemoryImage? qrImage;
    try {
      final qrUrl =
          'https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=$code&color=113049';
      final r =
          await http.get(Uri.parse(qrUrl)).timeout(const Duration(seconds: 8));
      if (r.statusCode == 200) qrImage = pw.MemoryImage(r.bodyBytes);
    } catch (_) {}

    final primary = PdfColor.fromHex('#113049');
    final lightBlue = PdfColor.fromHex('#F0F7FF');
    final greyLight = PdfColor.fromHex('#F5F5F5');
    final hStyle = pw.TextStyle(
        fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600);
    final nStyle = pw.TextStyle(fontSize: 10, color: PdfColors.grey800);
    final bStyle = pw.TextStyle(
        fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.black);

    String fechaStr = '';
    try {
      final dt = DateTime.parse(fechaIso);
      fechaStr =
          '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      fechaStr = fechaIso.split('T').first;
    }

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(30),
      build: (pw.Context ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (logoImage != null)
                pw.Container(height: 40, child: pw.Image(logoImage))
              else
                pw.Text('BIQOE',
                    style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: primary)),
              pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('COMPROBANTE DE RESERVA',
                        style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: primary)),
                    pw.Text('Fecha: $fechaStr',
                        style: pw.TextStyle(
                            fontSize: 9, color: PdfColors.grey600)),
                  ]),
            ],
          ),
          pw.Divider(color: primary, thickness: 1.5),
          pw.SizedBox(height: 12),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                  child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                        color: lightBlue,
                        borderRadius: pw.BorderRadius.circular(8),
                        border: pw.Border.all(color: primary, width: 0.5)),
                    child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('ACTIVIDAD', style: hStyle),
                          pw.SizedBox(height: 3),
                          pw.Text(planName,
                              style: pw.TextStyle(
                                  fontSize: 14,
                                  fontWeight: pw.FontWeight.bold,
                                  color: primary)),
                          pw.SizedBox(height: 8),
                          pw.Text('UBICACIÓN', style: hStyle),
                          pw.SizedBox(height: 3),
                          pw.Text(planLocation, style: nStyle),
                          pw.SizedBox(height: 8),
                          pw.Text('CÓDIGO ÚNICO', style: hStyle),
                          pw.SizedBox(height: 3),
                          pw.Text(code,
                              style: pw.TextStyle(
                                  fontSize: 18,
                                  fontWeight: pw.FontWeight.bold,
                                  letterSpacing: 3,
                                  color: primary)),
                        ]),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text('DATOS DEL TITULAR', style: hStyle),
                  pw.SizedBox(height: 4),
                  pw.Row(children: [
                    pw.Text('Nombre: ', style: hStyle),
                    pw.Text(contactName, style: bStyle)
                  ]),
                  pw.SizedBox(height: 2),
                  if (contactEmail.isNotEmpty)
                    pw.Row(children: [
                      pw.Text('Email: ', style: hStyle),
                      pw.Text(contactEmail, style: nStyle)
                    ]),
                ],
              )),
              pw.SizedBox(width: 20),
              pw.Column(children: [
                if (qrImage != null)
                  pw.Container(
                    padding: const pw.EdgeInsets.all(6),
                    decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: primary, width: 1.5),
                        borderRadius: pw.BorderRadius.circular(8)),
                    child: pw.Image(qrImage, width: 110, height: 110),
                  )
                else
                  pw.BarcodeWidget(
                      data: code,
                      barcode: pw.Barcode.qrCode(),
                      width: 110,
                      height: 110,
                      color: primary),
                pw.SizedBox(height: 4),
                pw.Text('Muestra este QR al llegar',
                    style:
                        pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
              ]),
            ],
          ),
          pw.SizedBox(height: 16),
          if (packages.isNotEmpty) ...[
            pw.Text('DETALLE DE PAQUETES', style: hStyle),
            pw.SizedBox(height: 6),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(2)
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: greyLight),
                  children: [
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text('Descripción',
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold, fontSize: 9))),
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text('Pers.',
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold, fontSize: 9))),
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text('Tipo / Fecha',
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold, fontSize: 9))),
                  ],
                ),
                ...packages.map((pkg) {
                  final tipo = pkg['tipoDeReserva']?.toString() ?? '';
                  String fh = '';
                  if (tipo == 'Reserva') {
                    fh =
                        '${pkg['fechaReserva'] ?? ''} ${pkg['horaReserva'] ?? ''}'
                            .trim();
                  } else if (tipo == 'Reserva Flexible')
                    // ignore: curly_braces_in_flow_control_structures
                    fh = pkg['instrucciones']?.toString() ?? '';
                  return pw.TableRow(children: [
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(pkg['miniDescripcion']?.toString() ?? '',
                            style: nStyle)),
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(pkg['personas']?.toString() ?? '',
                            style: nStyle)),
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child:
                            pw.Text(fh.isNotEmpty ? fh : tipo, style: nStyle)),
                  ]);
                }),
              ],
            ),
            pw.SizedBox(height: 14),
          ],
          pw.Text('RESUMEN DE PAGO', style: hStyle),
          pw.SizedBox(height: 6),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
                color: greyLight,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: PdfColors.grey300, width: 0.5)),
            child: pw.Column(children: [
              _pdfRow('Método de pago', paymentMethod, nStyle, hStyle),
              pw.SizedBox(height: 6),
              _pdfRow(
                  'Monto pagado (${widget.divisa.toUpperCase()})',
                  '$_currencySymbol${paidAmount.toStringAsFixed(2)}',
                  bStyle,
                  hStyle),
              if (tasa > 0) ...[
                pw.SizedBox(height: 4),
                _pdfRow('Monto en Bs (Tasa: ${tasa.toStringAsFixed(2)})',
                    'Bs ${amountBs.toStringAsFixed(2)}', nStyle, hStyle),
              ],
              if (totalAmount > paidAmount) ...[
                pw.SizedBox(height: 4),
                _pdfRow(
                    'Total del plan',
                    '$_currencySymbol${totalAmount.toStringAsFixed(2)}',
                    nStyle,
                    hStyle),
                pw.SizedBox(height: 4),
                _pdfRow(
                    'Saldo restante',
                    '$_currencySymbol${(totalAmount - paidAmount).toStringAsFixed(2)}',
                    pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.orange800),
                    hStyle),
              ],
            ]),
          ),
          pw.Spacer(),
          pw.Divider(color: PdfColors.grey300),
          pw.Center(
              child: pw.Text(
                  'Biqoe — Explora, reserva y vive experiencias únicas en Venezuela',
                  style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500))),
          pw.Center(
              child: pw.Text(
                  'Estado: PENDIENTE DE VERIFICACIÓN POR EL PROVEEDOR',
                  style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.orange))),
        ],
      ),
    ));

    return pdf.save();
  }

  pw.Widget _pdfRow(String label, String value, pw.TextStyle valueStyle,
      pw.TextStyle labelStyle) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: labelStyle),
        pw.Text(value, style: valueStyle)
      ],
    );
  }

  // ─── Validación y envío ───────────────────────────────────────────────────
  void _validateAndSubmit() {
    if (_isGuest) {
      if (_guestNameCtrl.text.isEmpty ||
          _guestEmailCtrl.text.isEmpty ||
          _guestPhoneCtrl.text.isEmpty) {
        _showErrorDialog("Por favor completa tus datos de contacto.");
        return;
      }
    }

    if (widget.paymentMethod != 'Efectivo' &&
        widget.paymentMethod != 'Gratis') {
      if (widget.paymentMethod == 'Pago móvil') {
        if (_transactionCtrl.text.isEmpty ||
            _payerIdCtrl.text.isEmpty ||
            _payerPhoneCtrl.text.isEmpty) {
          _showErrorDialog("Completa los datos del pago móvil realizado.");
          return;
        }
      } else {
        if (_payerNameCtrl.text.isEmpty ||
            _payerEmailCtrl.text.isEmpty ||
            _transactionCtrl.text.isEmpty) {
          _showErrorDialog("Completa los datos de la transferencia.");
          return;
        }
      }
    }

    _processReservation();
  }

  void _showErrorDialog(String msg) {
    showDialog(
        context: context,
        builder: (c) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Text("Atención"),
              content: SingleChildScrollView(child: Text(msg)),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(c), child: const Text("OK"))
              ],
            ));
  }

  void _showSuccessDialog({
    required String code,
    required String contactName,
    required String contactEmail,
    required String planName,
    required String planLocation,
    required double paidAmount,
    required double totalAmount,
    required double amountBs,
    required double tasa,
    required String paymentMethod,
    required List<Map<String, dynamic>> packages,
    required String fechaIso,
  }) {
    bool isDownloading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDlgState) => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          // insetPadding reduce márgenes en pantallas pequeñas
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            // Máximo 90% de la pantalla para que no desborde en ningún dispositivo
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.90,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        shape: BoxShape.circle),
                    child: const Icon(Icons.mark_email_read_rounded,
                        size: 40, color: Colors.green),
                  ),
                  const SizedBox(height: 20),
                  Text("¡Reserva enviada!",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: kPrimaryColor)),
                  const SizedBox(height: 8),
                  Text(
                      "Hemos enviado un correo con todos los detalles y tu código QR.",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                          fontSize: 13, color: Colors.black87)),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [
                      const Icon(Icons.info_outline,
                          size: 18, color: Colors.orange),
                      const SizedBox(width: 10),
                      Flexible(
                          child: Text(
                              "Si no recibes el correo, revisa tu carpeta de SPAM",
                              style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: Colors.orange[800],
                                  fontWeight: FontWeight.w600))),
                    ]),
                  ),

                  const SizedBox(height: 16),

                  // ── Sección comprobante ───────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: kPrimaryColor.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: kPrimaryColor.withValues(alpha: 0.15))),
                    child: Column(
                      children: [
                        Row(children: [
                          const Icon(Icons.image_outlined,
                              color: kPrimaryColor, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(
                                  "Descarga tu comprobante con el código QR para presentarlo al proveedor.",
                                  style: GoogleFonts.poppins(
                                      fontSize: 11, color: kPrimaryColor))),
                        ]),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          height: 42,
                          child: ElevatedButton.icon(
                            onPressed: isDownloading
                                ? null
                                : () async {
                                    setDlgState(() => isDownloading = true);
                                    try {
                                      await _showReceiptImage(
                                        dialogContext: ctx,
                                        code: code,
                                        contactName: contactName,
                                        contactEmail: contactEmail,
                                        planName: planName,
                                        planLocation: planLocation,
                                        paidAmount: paidAmount,
                                        totalAmount: totalAmount,
                                        amountBs: amountBs,
                                        tasa: tasa,
                                        paymentMethod: paymentMethod,
                                        packages: packages,
                                        fechaIso: fechaIso,
                                      );
                                    } finally {
                                      setDlgState(() => isDownloading = false);
                                    }
                                  },
                            icon: isDownloading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.download_rounded,
                                    size: 18, color: Colors.white),
                            label: Text(
                                isDownloading
                                    ? "Generando..."
                                    : "Descargar comprobante",
                                style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kPrimaryColor,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              elevation: 2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Botón Entendido ───────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        // 1. Cerrar el diálogo de éxito
                        Navigator.pop(dialogCtx);

                        if (kIsWeb) {
                          // WEB: limpiar pila de Navigator y navegar al perfil
                          // del proveedor (comportamiento original).
                          Navigator.of(context, rootNavigator: true)
                              .popUntil((route) => route.isFirst);
                          final target = _supplierSlug.isNotEmpty
                              ? '/$_supplierSlug'
                              : '/';
                          context.replace(target);
                        } else {
                          // APP NATIVA (Android / iOS): ir directamente a
                          // bookings_screen para que el usuario vea su reserva.
                          Navigator.of(context, rootNavigator: true)
                              .popUntil((route) => route.isFirst);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  BookingsScreen(userId: _cachedUserId),
                            ),
                          );
                        }
                      },
                      style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: kPrimaryColor),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: Text("Entendido",
                          style: GoogleFonts.poppins(
                              color: kPrimaryColor,
                              fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              ), // Column
            ), // SingleChildScrollView
          ), // ConstrainedBox
        ), // Dialog
      ),
    );
  }

  List<Widget> _buildBankDataRows() {
    List<Widget> rows = [];
    for (var k in _providerBankData.keys) {
      if (k != 'metodo') {
        rows.add(Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                  width: 100,
                  child: Text(k.capitalize(),
                      style: GoogleFonts.poppins(
                          color: Colors.grey[600], fontSize: 13))),
              Expanded(
                  child: SelectableText(_providerBankData[k]!,
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.black87))),
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: _providerBankData[k]!));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text("Copiado"),
                      duration: Duration(milliseconds: 500)));
                },
                child: Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Icon(Icons.copy, size: 18, color: Colors.blue[300])),
              ),
            ],
          ),
        ));
      }
    }
    return rows;
  }

  // ─── Widget de monto total (siempre visible) ─────────────────────────────
  Widget _buildAmountSummary() {
    // Monto a pagar hoy
    double amountToday = widget.totalPrice;
    if (_payInInstallments && _installmentConfig.isNotEmpty) {
      amountToday = widget.totalPrice * (_installmentConfig[0] / 100);
    }
    final double amountBs = _exchangeRate > 0 ? amountToday * _exchangeRate : 0;
    final double restante = widget.totalPrice - amountToday;
    final bool hasPlan = _payInInstallments && restante > 0.01;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [kPrimaryColor, Color(0xFF1E5F8C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: kPrimaryColor.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(hasPlan ? "Monto a pagar hoy" : "Monto total",
              style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "$_currencySymbol${amountToday.toStringAsFixed(2)}",
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(_currencyLabel,
                    style: GoogleFonts.poppins(
                        color: Colors.white60, fontSize: 14)),
              ),
            ],
          ),
          if (_exchangeRate > 0) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.currency_exchange,
                      color: Colors.white70, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    "Bs ${amountBs.toStringAsFixed(2)}",
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    "(Tasa: ${_exchangeRate.toStringAsFixed(2)})",
                    style: GoogleFonts.poppins(
                        color: Colors.white60, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
          if (hasPlan) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Precio total del plan:",
                    style: GoogleFonts.poppins(
                        color: Colors.white70, fontSize: 11)),
                Text(
                    "$_currencySymbol${widget.totalPrice.toStringAsFixed(2)} $_currencyLabel",
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Saldo restante:",
                    style: GoogleFonts.poppins(
                        color: Colors.white70, fontSize: 11)),
                Text(
                    "$_currencySymbol${restante.toStringAsFixed(2)} $_currencyLabel",
                    style: GoogleFonts.poppins(
                        color: Colors.amber,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: Text("Detalles del pago",
            style: GoogleFonts.poppins(
                color: kPrimaryColor, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: kBackgroundColor,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Datos de contacto (invitado / Safari) ──────────────────
                if (_isGuest) ...[
                  const _SectionTitle(title: "Tus datos de contacto"),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: _cardDecoration(),
                    child: Column(
                      children: [
                        _buildTextField(
                            controller: _guestNameCtrl,
                            label: "Nombre completo",
                            icon: Icons.person_outline),
                        const SizedBox(height: 12),
                        _buildTextField(
                            controller: _guestEmailCtrl,
                            label: "Correo electrónico",
                            icon: Icons.email_outlined,
                            type: TextInputType.emailAddress),
                        const SizedBox(height: 12),
                        _buildTextField(
                            controller: _guestPhoneCtrl,
                            label: "Teléfono (WhatsApp)",
                            icon: Icons.phone_outlined,
                            type: TextInputType.phone),
                      ],
                    ),
                  ),
                  const SizedBox(height: 25),
                ],

                // ── Bloque de monto — SIEMPRE visible ──────────────────────
                if (_isLoadingBankData)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  _buildAmountSummary(),
                  const SizedBox(height: 20),
                ],

                // ── Opción cuotas ───────────────────────────────────────────
                if (_canPayInInstallments && !_isLoadingBankData) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: kPrimaryColor.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: kPrimaryColor.withValues(alpha: 0.2))),
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text("Pagar en cuotas",
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              color: kPrimaryColor)),
                      subtitle: Text(
                          "Paga el ${_installmentConfig.isNotEmpty ? _installmentConfig[0].toStringAsFixed(0) : 50}% hoy y el resto después.",
                          style: GoogleFonts.poppins(fontSize: 12)),
                      value: _payInInstallments,
                      activeThumbColor: kPrimaryColor,
                      onChanged: (val) =>
                          setState(() => _payInInstallments = val),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // ── Datos bancarios del proveedor ───────────────────────────
                const _SectionTitle(title: "Realiza el pago a esta cuenta"),
                _isLoadingBankData
                    ? const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(child: CircularProgressIndicator()))
                    : Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: _cardDecoration(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                    widget.paymentMethod.contains('Zelle')
                                        ? Icons.attach_money
                                        : Icons.account_balance,
                                    color: kPrimaryColor),
                                const SizedBox(width: 10),
                                Text(widget.paymentMethod,
                                    style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                              ],
                            ),
                            const Divider(height: 25),
                            if (_providerBankData.isEmpty)
                              Text(
                                  "No hay datos disponibles para este método. Contacta soporte.",
                                  style: GoogleFonts.poppins(
                                      color:
                                          const Color.fromRGBO(17, 48, 73, 1)))
                            else
                              ..._buildBankDataRows(),
                          ],
                        ),
                      ),
                const SizedBox(height: 25),

                // ── Datos de la transferencia ───────────────────────────────
                if (widget.paymentMethod != 'Efectivo' &&
                    widget.paymentMethod != 'Gratis') ...[
                  const _SectionTitle(title: "Reporta tu transferencia"),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: _cardDecoration(),
                    child: Column(
                      children: [
                        if (widget.paymentMethod == 'Pago móvil') ...[
                          _buildTextField(
                              controller: _transactionCtrl,
                              label: "Referencia (últimos 4 dígitos)",
                              icon: Icons.confirmation_number),
                          const SizedBox(height: 12),
                          _buildTextField(
                              controller: _payerIdCtrl,
                              label: "Cédula del titular",
                              icon: Icons.badge),
                          const SizedBox(height: 12),
                          _buildTextField(
                              controller: _payerPhoneCtrl,
                              label: "Teléfono del titular",
                              icon: Icons.phone_android,
                              type: TextInputType.phone),
                        ] else ...[
                          _buildTextField(
                              controller: _payerNameCtrl,
                              label: "Nombre del titular",
                              icon: Icons.person),
                          const SizedBox(height: 12),
                          _buildTextField(
                              controller: _payerEmailCtrl,
                              label: "Correo / Usuario",
                              icon: Icons.email),
                          const SizedBox(height: 12),
                          _buildTextField(
                              controller: _transactionCtrl,
                              label: "Código de referencia / confirmación",
                              icon: Icons.confirmation_number),
                        ]
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 30),

                // ── Botón confirmar ─────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryColor,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 4),
                    onPressed: _isProcessing ? null : _validateAndSubmit,
                    child: _isProcessing
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Text("Confirmar pago",
                            style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
        border: Border.all(color: Colors.grey.shade200));
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType type = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        isDense: true,
      ),
    );
  }
}

// ── Pantalla de previsualización del PDF (para Safari/Apple web) ─────────────
// Safari no permite descargar PDFs generados en memoria. Esta pantalla
// renderiza el PDF como widgets usando PdfPreview e instruye al usuario
// a tomar una captura de pantalla.
// ignore: unused_element
class _PdfPreviewPage extends StatelessWidget {
  final Future<Uint8List> Function() pdfBytesBuilder;
  final String code;

  const _PdfPreviewPage({
    required this.pdfBytesBuilder,
    required this.code,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: Text(
          'Comprobante · $code',
          style: GoogleFonts.poppins(
              color: const Color.fromRGBO(17, 48, 73, 1),
              fontWeight: FontWeight.bold,
              fontSize: 15),
        ),
        backgroundColor: const Color(0xFFF8F9FD),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Banner: instrucción de captura de pantalla
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color.fromRGBO(17, 48, 73, 1),
            child: Row(
              children: [
                const Icon(Icons.photo_camera_outlined,
                    color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Toma una captura de pantalla para guardar tu comprobante',
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          // Vista previa del PDF renderizado como widgets
          Expanded(
            child: PdfPreview(
              build: (_) => pdfBytesBuilder(),
              allowSharing: false,
              allowPrinting: false,
              canChangePageFormat: false,
              canChangeOrientation: false,
              canDebug: false,
              initialPageFormat: PdfPageFormat.a4,
              padding: const EdgeInsets.all(0),
              pdfFileName: 'Reserva-$code.pdf',
            ),
          ),
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
      padding: const EdgeInsets.only(bottom: 10, left: 4),
      child: Text(title,
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold, fontSize: 16, color: kPrimaryColor)),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return "";
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
