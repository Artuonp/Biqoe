import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';

class BookingProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, List<Map<String, dynamic>>> _userBookings = {};
  final Logger logger = Logger();

  // --- GETTERS ---
  List<Map<String, dynamic>> getPendingBookings(String userId) {
    return _userBookings[userId]
            ?.where((booking) => booking['estado'] == 'pendiente')
            .toList() ??
        [];
  }

  List<Map<String, dynamic>> getVerifiedBookings(String userId) {
    return _userBookings[userId]
            ?.where((booking) => booking['estado'] == 'verificado')
            .toList() ??
        [];
  }

  // --- CARGAR RESERVAS ---
  Future<void> loadBookings(String userId) async {
    try {
      // Buscamos en 'reservaciones/{supplierId}/reservas' usando collectionGroup
      QuerySnapshot pendingSnapshot = await _firestore
          .collectionGroup('reservas')
          .where('userId', isEqualTo: userId)
          .where('estado', isEqualTo: 'pendiente')
          .orderBy('createdAt', descending: true)
          .get();

      QuerySnapshot verifiedSnapshot = await _firestore
          .collectionGroup('reservas')
          .where('userId', isEqualTo: userId)
          .where('estado', isEqualTo: 'verificado')
          .orderBy('createdAt', descending: true)
          .get();

      if (userId.isNotEmpty) {
        _userBookings[userId] = [
          ...pendingSnapshot.docs.map((doc) => _mapBookingDoc(doc)),
          ...verifiedSnapshot.docs.map((doc) => _mapBookingDoc(doc)),
        ];
      }

      notifyListeners();
    } catch (e) {
      logger.e('Error al cargar las reservas: $e');
    }
  }

  // --- MAPEO DE DATOS (LECTURA) ---
  Map<String, dynamic> _mapBookingDoc(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return {
      'id': doc.id,
      'planName': data['planName'],
      'planLocation': data['planLocation'],
      'googleMapsLink': data['googleMapsLink'],
      'supplier': data['supplier'],

      // Datos Financieros
      'totalPriceBs': data['totalPriceBs'],
      'amountPaid':
          (data['amountPaid'] ?? data['totalPrice'] ?? 0.0).toDouble(),
      'totalPlanPrice':
          (data['totalPlanPrice'] ?? data['totalPrice'] ?? 0.0).toDouble(),
      'isInstallment': data['isInstallment'] ?? false,
      'installmentsPaid': data['installmentsPaid'] ?? 0,
      'paymentStatus': data['paymentStatus'] ?? 'completed',

      // HISTORIAL DE PAGOS
      'paymentHistory': data['paymentHistory'] ?? [],

      // Datos Contacto
      'name': data['name'],
      'email': data['email'],
      'celular': data['celular'],

      // Datos de Referencia (Último estado)
      'transactionCode': data['transactionCode'],
      'receipt': data['receipt'],
      'paymentMethod': data['paymentMethod'],
      'cedula': data['cedula'],
      'numero': data['numero'],
      'correo': data['correo'],

      // Meta
      'fecha': data['fecha'],
      'createdAt': data['createdAt'],
      'estado': data['estado'],
      'code': data['code'],

      // Paquetes
      'packages': (data['packages'] as List<dynamic>? ?? []).map((pkg) {
        if (pkg is! Map<String, dynamic>) return {};

        final bookingType = pkg['tipoDeReserva'] ?? 'Reserva';
        Map<String, dynamic> packageDetails = {
          'numero': pkg['numero'],
          'personas': pkg['personas'],
          'miniDescripcion': pkg['miniDescripcion'],
          'tipoDeReserva': bookingType,
        };

        if (bookingType == 'Reserva' && pkg['fechaReserva'] != null) {
          packageDetails['fechaReserva'] = pkg['fechaReserva'];
          packageDetails['horaReserva'] = pkg['horaReserva'];
        } else if (bookingType == 'Reserva Flexible' &&
            pkg['instrucciones'] != null) {
          packageDetails['instrucciones'] = pkg['instrucciones'];
        }

        return packageDetails;
      }).toList(),
    };
  }

  // --- AGREGAR RESERVA INICIAL (ESCRITURA) ---
  Future<void> addBooking({
    required String userId,
    required String planName,
    required double totalPriceBs,
    required String name,
    required String email,
    required String celular,
    required String planLocation,
    required double planPrice, // Monto pagado EN ESTA TRANSACCIÓN
    required String supplier,

    // Campos planos
    required String paymentMethod,
    required String transactionCode,
    required String receipt,
    required String cedula,
    required String numero,
    required String correo,
    required String documentId,
    required String code,
    required List<Map<String, dynamic>> packagesData,

    // Nuevos Campos
    double? totalPlanPrice,
    bool isInstallment = false,
    int installmentsPaid = 0,

    // DETALLE COMPLETO DEL PRIMER PAGO
    required Map<String, dynamic> initialPaymentDetails,
  }) async {
    try {
      final fechaIso = DateTime.now().toIso8601String();
      final double finalTotal = totalPlanPrice ?? planPrice;
      String paymentStatus = 'completed';

      if (isInstallment && planPrice < (finalTotal - 0.1)) {
        paymentStatus = 'partial';
      }

      final docRef = _firestore
          .collection('reservaciones')
          .doc(supplier)
          .collection('reservas')
          .doc(documentId);

      // Creamos el objeto del primer pago (Este sí nace verificado usualmente al crearlo el proveedor)
      final firstPaymentEntry = {
        ...initialPaymentDetails,
        'amount': planPrice,
        'date': Timestamp.now(),
        'type': 'initial',
        'status':
            'verified', // El pago inicial manual se asume verificado al crearlo el proveedor
      };

      final bookingData = {
        'userId': userId,
        'supplier': supplier,
        'planName': planName,
        'planLocation': planLocation,

        // --- FINANZAS ---
        'amountPaid': planPrice,
        'totalPlanPrice': finalTotal,
        'totalPriceBs': totalPriceBs,
        'isInstallment': isInstallment,
        'installmentsPaid': installmentsPaid,
        'paymentStatus': paymentStatus,

        // --- HISTORIAL DE PAGOS ---
        'paymentHistory': [firstPaymentEntry],

        // --- DATOS PLANOS ---
        'paymentMethod': paymentMethod,
        'transactionCode': transactionCode,
        'receipt': receipt,
        'cedula': cedula,
        'numero': numero,
        'correo': correo,

        // --- CONTACTO Y ESTADO ---
        'name': name,
        'email': email,
        'celular': celular,
        'fecha': fechaIso,
        'createdAt': FieldValue.serverTimestamp(),
        'estado': 'pendiente', // O 'verificado' según lógica de manual_booking
        'code': code,

        // --- PAQUETES ---
        'packages': packagesData.map((pkg) {
          final String bookingType = pkg['tipoDeReserva'] ?? 'Reserva';
          Map<String, dynamic> packageToSave = {
            'numero': pkg['numero'],
            'personas': pkg['personas'],
            'miniDescripcion': pkg['miniDescripcion'],
            'tipoDeReserva': bookingType,
          };

          if (bookingType == 'Reserva') {
            DateTime fechaReserva = _parseFecha(pkg['fecha']);
            packageToSave['fechaReserva'] =
                DateFormat('yyyy-MM-dd').format(fechaReserva);
            packageToSave['horaReserva'] = pkg['hora'];
          } else if (bookingType == 'Reserva Flexible') {
            packageToSave['instrucciones'] = pkg['instrucciones'];
          }
          return packageToSave;
        }).toList(),
      };

      await docRef.set(bookingData);
      await loadBookings(userId);
    } catch (e, stacktrace) {
      logger.e('Error al agregar reserva: $e\n$stacktrace');
      throw Exception('Error al crear la reserva en el provider: $e');
    }
  }

  // --- REGISTRAR ABONO (MODIFICADO: SE GUARDA COMO PENDIENTE) ---
  Future<void> addPaymentToBooking({
    required String supplierId,
    required String bookingId,
    required String userId,
    required double amountPaid, // Monto del pago
    required Map<String, dynamic> paymentDetails, // Banco, Ref, etc.
    required double
        currentTotalPaid, // No se usa para update inmediato, solo referencia
    required double totalPlanPrice, // No se usa para update inmediato
  }) async {
    try {
      // 1. Creamos el objeto con status PENDIENTE
      final newPaymentEntry = {
        ...paymentDetails,
        'amount': amountPaid,
        'date': Timestamp.now(),
        'type': 'installment',
        'status': 'pending', // <--- IMPORTANTE: No verificado aún
      };

      // 2. Solo agregamos al historial. NO sumamos amountPaid todavía.
      await _firestore
          .collection('reservaciones')
          .doc(supplierId)
          .collection('reservas')
          .doc(bookingId)
          .update({
        'paymentHistory': FieldValue.arrayUnion([newPaymentEntry]),

        // Actualizamos referencia visual rápida, pero no el saldo contable
        'paymentMethod': paymentDetails['method'],
        'transactionCode': paymentDetails['referencia'] ?? '',
      });

      await loadBookings(userId);
    } catch (e) {
      logger.e('Error registrando abono: $e');
      throw Exception('No se pudo registrar el pago: $e');
    }
  }

  // --- NUEVA FUNCIÓN: VERIFICAR UN PAGO ESPECÍFICO ---
  // Esta función se llamará desde supplier_verify_payments_screen
  Future<void> verifyIndividualPayment({
    required String supplierId,
    required String bookingId,
    required Map<String, dynamic> paymentData, // El objeto del pago pendiente
    required double currentTotalPaid, // Lo que ya estaba pagado (verificado)
    required double totalPlanPrice,
    required int currentInstallments,
  }) async {
    try {
      // 1. Calcular nuevos totales ahora que se verificó
      double paymentAmount = (paymentData['amount'] ?? 0).toDouble();
      double newTotalPaid = currentTotalPaid + paymentAmount;
      bool isCompleted = newTotalPaid >= (totalPlanPrice - 0.1);

      // 2. Crear la versión verificada del objeto de pago
      Map<String, dynamic> verifiedPayment = Map.from(paymentData);
      verifiedPayment['status'] = 'verified';
      verifiedPayment['verifiedAt'] = Timestamp.now();

      final docRef = _firestore
          .collection('reservaciones')
          .doc(supplierId)
          .collection('reservas')
          .doc(bookingId);

      // 3. Ejecutar transacción para integridad
      await _firestore.runTransaction((transaction) async {
        // Primero quitamos el pago pendiente antiguo del array
        transaction.update(docRef, {
          'paymentHistory': FieldValue.arrayRemove([paymentData])
        });

        // Luego agregamos el verificado y actualizamos los saldos globales
        transaction.update(docRef, {
          'paymentHistory': FieldValue.arrayUnion([verifiedPayment]),
          'amountPaid': newTotalPaid, // AHORA SÍ SUMAMOS
          'installmentsPaid': currentInstallments + 1,
          'paymentStatus': isCompleted ? 'completed' : 'partial',
          'estado': isCompleted
              ? 'verificado'
              : 'verificado', // Mantenemos verificado o cambiamos si completó
        });
      });
    } catch (e) {
      logger.e('Error verificando pago individual: $e');
      throw Exception('Error al verificar pago: $e');
    }
  }

  // --- UTILERÍA ---
  DateTime _parseFecha(dynamic fecha) {
    if (fecha is DateTime) return fecha;
    if (fecha is String) return DateFormat('yyyy-MM-dd').parse(fecha);
    if (fecha is Timestamp) return fecha.toDate();
    throw FormatException('Formato de fecha no válido: $fecha');
  }

  // Verificar reserva completa (Lado del Proveedor - Para reserva inicial)
  Future<void> verifyBooking(String reservaId, String supplierId) async {
    try {
      final reservaRef = _firestore
          .collection('reservaciones')
          .doc(supplierId)
          .collection('reservas')
          .doc(reservaId);

      await reservaRef.update({'estado': 'verificado'});

      final doc = await reservaRef.get();
      if (doc.exists) {
        final userId = doc.data()?['userId'];
        if (userId != null) {
          updateBookingStatus(userId, reservaId, 'verificado');
        }
      }
      notifyListeners();
    } catch (e) {
      logger.e('Error al verificar la reserva: $e');
    }
  }

  void updateBookingStatus(
      String userId, String reservaId, String nuevoEstado) {
    final bookings = _userBookings[userId];
    if (bookings != null) {
      for (var booking in bookings) {
        if (booking['id'] == reservaId) {
          booking['estado'] = nuevoEstado;
          notifyListeners();
          break;
        }
      }
    }
  }
}
