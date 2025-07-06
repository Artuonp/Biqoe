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

      if (userId.isNotEmpty) {
        _userBookings[userId] = [
          ...pendingSnapshot.docs.map((doc) => _mapBookingDoc(doc)),
          ...verifiedSnapshot.docs.map((doc) => _mapBookingDoc(doc)),
        ];
      }

      notifyListeners();
    } catch (e) {
      logger.i('Error al cargar las reservas: $e');
    }
  }

  // MODIFICADO: Ahora mapea correctamente los nuevos tipos de paquetes desde Firestore.
  Map<String, dynamic> _mapBookingDoc(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return {
      'id': doc.id,
      'planName': data['planName'],
      'totalPriceBs': data['totalPriceBs'],
      'name': data['name'],
      'email': data['email'],
      'celular': data['celular'],
      'planLocation': data['planLocation'],
      'planPrice': data['totalPrice'],
      'transactionCode': data['transactionCode'],
      'receipt': data['receipt'],
      'fecha': data['fecha'],
      'estado': data['estado'],
      'supplier': data['supplier'],
      'paymentMethod': data['paymentMethod'],
      'code': data['code'],
      'cedula': data['cedula'],
      'numero': data['numero'],
      'correo': data['correo'],
      'packages': (data['packages'] as List<dynamic>).map((pkg) {
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

  // MODIFICADO: El método addBooking ahora es dinámico y guarda los datos correctos para cada tipo de paquete.
  Future<void> addBooking({
    required String userId,
    required String planName,
    required double totalPriceBs,
    required String name,
    required String email,
    required String celular,
    required String planLocation,
    required double planPrice,
    required String supplier,
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
      final docRef = _firestore
          .collection('reservaciones')
          .doc(supplier)
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
        'supplier': supplier,
        'userId': userId,
        'paymentMethod': paymentMethod,
        'code': code,
        'cedula': cedula,
        'numero': numero,
        'correo': correo,
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
          // Los tipos 'Ticket' y 'Suscripción' no guardan campos adicionales en el paquete de la reserva.

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

  // MODIFICADO: Ahora también maneja Timestamps de Firestore, haciéndolo más robusto.
  DateTime _parseFecha(dynamic fecha) {
    if (fecha is DateTime) return fecha;
    if (fecha is String) return DateFormat('yyyy-MM-dd').parse(fecha);
    if (fecha is Timestamp) return fecha.toDate();
    throw FormatException('Formato de fecha no válido: $fecha');
  }

  // MODIFICADO: Corrige un error lógico al actualizar el estado local
  Future<void> verifyBooking(String reservaId, String supplierId) async {
    try {
      final reservaRef = _firestore
          .collection('reservaciones')
          .doc(supplierId)
          .collection('reservas')
          .doc(reservaId);

      await reservaRef.update({'estado': 'verificado'});

      // Busca el userId del cliente para actualizar el estado en la UI
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
