import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SupplierService {
  /// Devuelve el ID del proveedor que se debe gestionar.
  /// 1. Si el usuario tiene 'associatedSupplierId', devuelve ese ID (es empleado).
  /// 2. Si no, devuelve su propio UID (es el dueño).
  static Future<String> getActiveSupplierId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return '';

    try {
      final doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .get();

      if (!doc.exists) return user.uid;

      final data = doc.data() as Map<String, dynamic>;

      // Verifica si tiene un jefe asignado
      if (data['associatedSupplierId'] != null &&
          data['associatedSupplierId'].toString().isNotEmpty) {
        return data['associatedSupplierId'];
      }

      // Si no, es su propia cuenta
      return user.uid;
    } catch (e) {
      return user.uid; // Fallback seguro
    }
  }
}
