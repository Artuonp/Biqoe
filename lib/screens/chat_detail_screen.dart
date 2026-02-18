import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Para rootBundle
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:googleapis_auth/auth_io.dart'; // Para credenciales

import '../../../../services/chat_service.dart';
import 'supplier/provider_profile_screen.dart';

class ChatDetailScreen extends StatefulWidget {
  final String chatId;
  final String otherName;
  final String otherImage;
  final String currentUserId;

  const ChatDetailScreen({
    super.key,
    required this.chatId,
    required this.otherName,
    required this.otherImage,
    required this.currentUserId,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ChatService _chatService = ChatService();
  final Color primaryColor = const Color.fromRGBO(17, 48, 73, 1);

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    debugPrint(">>> INTENTANDO ENVIAR MENSAJE <<<");
    debugPrint("Chat ID: ${widget.chatId}");
    debugPrint("Sender ID: ${widget.currentUserId}");

    // 1. Enviar mensaje a Firestore
    _chatService.sendMessage(
      chatId: widget.chatId,
      senderId: widget.currentUserId,
      text: text,
    );

    _messageController.clear();

    // 2. Enviar Notificación al Receptor
    _handleNotificationLogic(text);
  }

  // --- LÓGICA DE NOTIFICACIÓN ---
  Future<void> _handleNotificationLogic(String messageText) async {
    try {
      debugPrint("--- Inicio Lógica Notificación ---");

      // A. Identificar al receptor
      final chatDoc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .get();

      if (!chatDoc.exists) {
        debugPrint("❌ Error: Documento del chat no existe.");
        return;
      }

      final data = chatDoc.data();
      debugPrint("Datos del chat: $data");

      final List<dynamic> participants = data?['participants'] ?? [];
      debugPrint("Participantes encontrados: $participants");
      debugPrint("Mi ID actual: ${widget.currentUserId}");

      // Buscamos el ID que NO es el mío
      // Usamos trim() para evitar errores por espacios en blanco invisibles
      String recipientId = participants
          .firstWhere(
            (id) => id.toString().trim() != widget.currentUserId.trim(),
            orElse: () => '',
          )
          .toString();

      // FALLBACK: Si participants falla o está vacío, intentamos deducir por los campos legacy
      if (recipientId.isEmpty) {
        debugPrint(
            "⚠ Warning: No se encontró receptor en 'participants'. Usando campos directos.");
        final String pUserId = data?['userId'] ?? '';
        final String pSupplierId = data?['supplierId'] ?? '';

        if (pUserId == widget.currentUserId) {
          recipientId = pSupplierId;
        } else {
          recipientId = pUserId;
        }
      }

      if (recipientId.isEmpty) {
        debugPrint(
            "❌ Error CRÍTICO: No se pudo determinar el ID del receptor.");
        return;
      }

      debugPrint("✅ ID del Receptor detectado: $recipientId");

      // B. Obtener datos del receptor (Token y Rol)
      final userDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(recipientId)
          .get();

      if (!userDoc.exists) {
        debugPrint(
            "❌ Error: Usuario receptor no encontrado en colección 'usuarios'");
        return;
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      // Buscamos ambos campos de token por compatibilidad
      final String? token = userData['fcmToken'] ?? userData['deviceToken'];
      final bool isSupplier = userData['isSupplier'] ?? false;

      if (token == null || token.isEmpty) {
        debugPrint(
            "⚠ Aviso: El receptor no tiene token FCM activo. No se envía notificación.");
        return;
      }

      debugPrint("Token destino: ${token.substring(0, 5)}...");
      debugPrint("¿Es proveedor?: $isSupplier");

      // C. Definir a qué pantalla debe ir
      // Si el receptor es proveedor -> Dashboard
      // Si el receptor es usuario normal -> Chat List
      final String targetScreen = isSupplier ? 'dashboard' : 'chat_list';

      // D. Enviar
      await _sendHttpV1Notification(
        token: token,
        title: "Nuevo mensaje de ${widget.otherName}",
        body: messageText,
        screen: targetScreen,
        chatId: widget.chatId,
      );
    } catch (e) {
      debugPrint("❌ Excepción gestionando notificación de chat: $e");
    }
  }

  Future<void> _sendHttpV1Notification({
    required String token,
    required String title,
    required String body,
    required String screen,
    required String chatId,
  }) async {
    try {
      const String serviceAccountPath =
          'assets/biqoe-app-firebase-adminsdk-fbsvc-067c9b5471.json';
      const List<String> scopes = [
        'https://www.googleapis.com/auth/firebase.messaging'
      ];

      // Cargar credenciales
      final serviceAccount = ServiceAccountCredentials.fromJson(
          await rootBundle.loadString(serviceAccountPath));

      final client = await clientViaServiceAccount(serviceAccount, scopes);

      final notificationPayload = {
        'message': {
          'token': token,
          'notification': {
            'title': 'Nuevo mensaje 💬',
            'body': body,
          },
          'data': {
            'click_action': 'FLUTTER_NOTIFICATION_CLICK',
            'screen': screen, // 'dashboard' o 'chat_list'
            'chatId': chatId,
            'type': 'chat_message',
          },
          'android': {
            'priority': 'high',
            'notification': {
              'sound': 'default',
              'click_action': 'FLUTTER_NOTIFICATION_CLICK',
            }
          },
          'apns': {
            'payload': {
              'aps': {'sound': 'default', 'badge': 1}
            }
          }
        }
      };

      const String projectId = 'biqoe-app';
      final url = Uri.parse(
          'https://fcm.googleapis.com/v1/projects/$projectId/messages:send');

      debugPrint("🚀 Enviando notificación HTTP v1...");
      final response = await client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(notificationPayload),
      );

      if (response.statusCode != 200) {
        debugPrint("❌ Error FCM Chat: ${response.body}");
      } else {
        debugPrint("✅ Notificación de chat enviada OK");
      }
      client.close();
    } catch (e) {
      debugPrint("❌ Excepción FCM Chat: $e");
    }
  }

  // --- LÓGICA PARA IR AL PERFIL ---
  void _goToProviderProfile() async {
    ScaffoldMessenger.of(context).removeCurrentSnackBar();

    debugPrint("--- Navegando a Perfil ---");

    try {
      final chatDoc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .get();

      if (!chatDoc.exists) {
        debugPrint("Chat no existe");
        return;
      }

      final data = chatDoc.data() as Map<String, dynamic>;
      final List<dynamic> participants = data['participants'] ?? [];

      // Búsqueda robusta del ID ajeno
      String otherId = participants
          .firstWhere(
              (id) => id.toString().trim() != widget.currentUserId.trim(),
              orElse: () => '')
          .toString();

      // Fallback
      if (otherId.isEmpty) {
        if (data['userId'] == widget.currentUserId) {
          otherId = data['supplierId'] ?? '';
        } else {
          otherId = data['userId'] ?? '';
        }
      }

      if (otherId.isEmpty) {
        debugPrint("No se encontró ID del otro usuario para navegar.");
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(otherId)
          .get();

      if (!userDoc.exists) {
        debugPrint("Usuario destino no existe en DB");
        return;
      }

      final userData = userDoc.data() as Map<String, dynamic>;

      // Solo navegamos si es un proveedor real
      if (userData['isSupplier'] == true) {
        final slug = userData['slug'];
        if (slug != null && slug.toString().isNotEmpty) {
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProviderProfileScreen(
                  slug: slug,
                  currentUserId: widget.currentUserId,
                ),
              ),
            );
          }
        } else {
          debugPrint("El proveedor no tiene slug configurado.");
        }
      } else {
        debugPrint("El usuario destino no es proveedor (isSupplier != true).");
      }
    } catch (e) {
      debugPrint("Error al navegar al perfil: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: GestureDetector(
          onTap: _goToProviderProfile,
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.grey[200],
                backgroundImage: widget.otherImage.isNotEmpty
                    ? CachedNetworkImageProvider(widget.otherImage)
                    : null,
                child: widget.otherImage.isEmpty
                    ? Text(
                        widget.otherName.isNotEmpty ? widget.otherName[0] : '?',
                        style: TextStyle(color: primaryColor),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.otherName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black,
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Text(
                      "Ver perfil",
                      style: TextStyle(
                        color: Colors.grey,
                        fontFamily: 'Poppins',
                        fontSize: 10,
                      ),
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _chatService.getMessages(widget.chatId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text("Error cargando mensajes"));
                }
                if (!snapshot.hasData) {
                  return const Center();
                }

                final docs = snapshot.data!.docs;

                return ListView.builder(
                  reverse: true,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final bool isMe = data['senderId'] == widget.currentUserId;

                    return _buildMessageBubble(data['text'], isMe);
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: TextField(
                        controller: _messageController,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          hintText: "Escribe un mensaje...",
                          hintStyle: TextStyle(
                              color: Colors.grey, fontFamily: 'Poppins'),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 14),
                        ),
                        style: const TextStyle(fontFamily: 'Poppins'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: primaryColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            )
                          ]),
                      child: const Icon(HugeIcons.strokeRoundedSent,
                          color: Colors.white, size: 22),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(String text, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? primaryColor : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft:
                isMe ? const Radius.circular(20) : const Radius.circular(2),
            bottomRight:
                isMe ? const Radius.circular(2) : const Radius.circular(20),
          ),
          boxShadow: [
            if (!isMe)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(0, 2),
              )
          ],
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isMe ? Colors.white : const Color(0xFF333333),
            fontFamily: 'Poppins',
            fontSize: 15,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}
