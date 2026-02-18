import 'package:cloud_firestore/cloud_firestore.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 1. Obtener o Crear un Chat (Para evitar duplicados)
  // Usamos un ID combinado: user_supplier para que sea único
  Future<String> getOrCreateChat({
    required String userId,
    required String supplierId,
    required Map<String, dynamic>
        userData, // Datos básicos del usuario (nombre, foto)
    required Map<String, dynamic> supplierData, // Datos básicos del proveedor
  }) async {
    // Generamos un ID predecible ordenando los IDs para que siempre sea el mismo
    // Pero en tu caso, como es Usuario -> Proveedor, podemos usar userId_supplierId
    // Sin embargo, para seguridad de búsqueda bidireccional, es mejor ordenarlos o usar un array.
    // Para simplificar y ahorrar: usaremos un Query.

    final QuerySnapshot existingChat = await _firestore
        .collection('chats')
        .where('participants', arrayContains: userId)
        .get();

    // Filtramos manualmente para encontrar el chat con este proveedor específico
    // (Firestore no deja hacer dos 'arrayContains' en la misma query fácilmente en modo gratuito)
    for (var doc in existingChat.docs) {
      final data = doc.data() as Map<String, dynamic>;
      if ((data['participants'] as List).contains(supplierId)) {
        return doc.id;
      }
    }

    // Si no existe, lo creamos
    final docRef = _firestore.collection('chats').doc();
    await docRef.set({
      'participants': [userId, supplierId],
      'userId': userId,
      'supplierId': supplierId,
      'userName': userData['nombre'],
      'userImage': userData['imagen'],
      'supplierName': supplierData['nombre'],
      'supplierImage': supplierData['imagen'],
      'lastMessage': '',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'readBySupplier': false,
      'readByUser': true,
    });

    return docRef.id;
  }

  // 2. Enviar Mensaje
  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String text,
  }) async {
    final timestamp = FieldValue.serverTimestamp();

    // A. Guardar el mensaje en la subcolección
    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add({
      'senderId': senderId,
      'text': text,
      'timestamp': timestamp,
    });

    // B. Actualizar el documento padre (Chat) para la lista de inbox
    // Esto ahorra lecturas masivas después
    await _firestore.collection('chats').doc(chatId).update({
      'lastMessage': text,
      'lastMessageTime': timestamp,
      // Si el que envía es el usuario, el proveedor no lo ha leído
      'readBySupplier': false,
      'readByUser': true, // Asumimos lógica inversa si envía proveedor
    });
  }

  // 3. Stream de la Lista de Chats
  Stream<QuerySnapshot> getChats(String currentUserId) {
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: currentUserId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots();
  }

  // 4. Stream de Mensajes de un Chat
  Stream<QuerySnapshot> getMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp',
            descending: true) // Los más nuevos abajo (en UI invertimos)
        .limit(30) // LÍMITE DE AHORRO: Solo carga los últimos 30
        .snapshots();
  }
}
