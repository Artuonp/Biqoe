import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:intl/intl.dart';
import 'package:logger/logger.dart';

class BookingProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, List<Map<String, dynamic>>> _userBookings = {};
  final Logger logger = Logger();

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

  Future<void> loadBookings(String userId) async {
    try {
      // Consulta TODAS las reservas del usuario usando collectionGroup
      QuerySnapshot pendingSnapshot = await _firestore
          .collectionGroup('reservas')
          .where('userId', isEqualTo: userId)
          .where('estado', isEqualTo: 'pendiente')
          .get();

      QuerySnapshot verifiedSnapshot = await _firestore
          .collectionGroup('reservas')
          .where('userId', isEqualTo: userId)
          .where('estado', isEqualTo: 'verificado')
          .get();

      _userBookings[userId] = [
        ...pendingSnapshot.docs.map((doc) => _mapBookingDoc(doc)),
        ...verifiedSnapshot.docs.map((doc) => _mapBookingDoc(doc)),
      ];

      notifyListeners();
    } catch (e) {
      logger.i('Error al cargar las reservas: $e');
    }
  }

  Map<String, dynamic> _mapBookingDoc(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return {
      'id': doc.id,
      'planName': data['planName'], // Cambiado de planID a planName
      'totalPriceBs': data['totalPriceBs'],
      'name': data['name'],
      'email': data['email'],
      'celular': data['celular'],
      'planLocation': data['planLocation'], // Cambiado de ubicacion
      'planPrice': data['totalPrice'], // Cambiado de precio a totalPrice
      'transactionCode':
          data['transactionCode'], // Cambiado de codigoTransaccion
      'receipt': data['receipt'], // Cambiado de comprobante
      'fecha': data['fecha'],
      'estado': data['estado'],
      'supplier': data['supplier'],
      'paymentMethod': data['paymentMethod'],
      'code': data['code'],
      'cedula': data['cedula'],
      'numero': data['numero'],
      'correo': data['correo'],
      'packages': (data['packages'] as List<dynamic>)
          .map((pkg) => {
                'numero': pkg['numero'],
                'fechaReserva': pkg['fechaReserva'],
                'horaReserva': pkg['horaReserva'],
                'personas': pkg['personas'],
                'miniDescripcion': pkg['miniDescripcion'],
              })
          .toList(),
    };
  }

  Future<void> addBooking({
    required String userId,
    required String planName,
    required double totalPriceBs,
    required String name,
    required String email,
    required String celular,
    required String planLocation,
    required double planPrice,
    required String supplier, // Este es el supplierId (UID del proveedor)
    required String paymentMethod,
    required String transactionCode,
    required String receipt,
    required String documentId,
    required String code,
    required String cedula,
    required String numero,
    required String correo,
    required List<Map<String, dynamic>> packagesData,
  }) async {
    try {
      final fecha = DateTime.now().toIso8601String();

      // Usar supplierId como ID del documento en "reservaciones"
      final docRef = _firestore
          .collection('reservaciones')
          .doc(supplier) // Cambiado de userId a supplier
          .collection('reservas')
          .doc(documentId);

      final bookingData = {
        'planName': planName,
        'totalPriceBs': totalPriceBs,
        'name': name,
        'email': email,
        'celular': celular,
        'planLocation': planLocation,
        'totalPrice': planPrice,
        'transactionCode': transactionCode,
        'receipt': receipt,
        'fecha': fecha,
        'estado': 'pendiente',
        'supplier': supplier, // Proveedor
        'userId': userId, // Usuario que hace la reserva
        'paymentMethod': paymentMethod,
        'code': code,
        'cedula': cedula,
        'numero': numero,
        'correo': correo,
        'packages': packagesData.map((pkg) {
          DateTime fecha = _parseFecha(pkg['fecha']);
          return {
            'numero': pkg['numero'],
            'fechaReserva': DateFormat('yyyy-MM-dd').format(fecha),
            'horaReserva': pkg['hora'],
            'personas': pkg['personas'],
            'miniDescripcion': pkg['miniDescripcion'],
          };
        }).toList(),
      };

      await docRef.set(bookingData);
      await loadBookings(userId);
    } catch (e, stacktrace) {
      logger.e('Error al agregar reserva: $e\n$stacktrace');
    }
  }

  DateTime _parseFecha(dynamic fecha) {
    if (fecha is DateTime) return fecha;
    if (fecha is String) return DateFormat('yyyy-MM-dd').parse(fecha);
    throw FormatException('Formato de fecha no válido: $fecha');
  }

  Future<void> verifyBooking(String reservaId, String supplierId) async {
    try {
      await _firestore
          .collection('reservaciones')
          .doc(supplierId)
          .collection('reservas')
          .doc(reservaId)
          .update({'estado': 'verificado'});

      updateBookingStatus(supplierId, reservaId, 'verificado');

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
