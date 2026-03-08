import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

// --- IMPORTS ---
import '../../../../services/chat_service.dart';
import 'chat_detail_screen.dart';
// Ajusta esta ruta según donde hayas guardado la pantalla de proveedores
import '../screens/supplier/providers_list_screen.dart';

class ChatListScreen extends StatelessWidget {
  final String currentUserId;
  final bool isSupplier; // Para saber qué foto/nombre mostrar

  const ChatListScreen({
    super.key,
    required this.currentUserId,
    this.isSupplier = false, // Por defecto es usuario
  });

  @override
  Widget build(BuildContext context) {
    final chatService = ChatService();
    const Color primaryColor = Color.fromRGBO(17, 48, 73, 1);

    void goToProviders() {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              ProvidersListScreen(currentUserId: currentUserId),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Text(
          "Mensajes",
          style: GoogleFonts.poppins(
            color: primaryColor,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        actions: [
          // Botón para iniciar nueva conversación (siempre visible)
          if (!isSupplier) // Solo los usuarios buscan proveedores, usualmente
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: IconButton(
                onPressed: goToProviders,
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF3F7FE),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    HugeIcons.strokeRoundedMessageAdd01,
                    color: primaryColor,
                    size: 20,
                  ),
                ),
                tooltip: "Nuevo mensaje",
              ),
            )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: chatService.getChats(currentUserId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center();
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState(context, goToProviders);
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: snapshot.data!.docs.length,
            separatorBuilder: (context, index) =>
                const Divider(height: 30, color: Color(0xFFF5F5F5)),
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;

              // Lógica para determinar qué nombre/foto mostrar
              String otherName = isSupplier
                  ? (data['userName'] ?? 'Usuario')
                  : (data['supplierName'] ?? 'Proveedor');
              String otherImage = isSupplier
                  ? (data['userImage'] ?? '')
                  : (data['supplierImage'] ?? '');

              // Formato de hora
              String time = '';
              if (data['lastMessageTime'] != null) {
                Timestamp t = data['lastMessageTime'];
                DateTime date = t.toDate();
                if (date.day == DateTime.now().day) {
                  time = DateFormat('HH:mm').format(date);
                } else {
                  time = DateFormat('dd/MM').format(date);
                }
              }

              return InkWell(
                onTap: () {
                  // --- CAMBIO IMPORTANTE AQUÍ ---
                  // Usamos rootNavigator: true para tapar la BottomBar
                  Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute(
                      builder: (context) => ChatDetailScreen(
                        chatId: doc.id,
                        otherName: otherName,
                        otherImage: otherImage,
                        currentUserId: currentUserId,
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      // Avatar
                      Container(
                        width: 55,
                        height: 55,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey.shade100),
                          color: Colors.grey[50],
                        ),
                        child: ClipOval(
                          child: otherImage.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: otherImage,
                                  fit: BoxFit.cover,
                                  placeholder: (c, u) =>
                                      Container(color: Colors.grey[100]),
                                  errorWidget: (c, u, e) => const Icon(
                                      Icons.person,
                                      color: Colors.grey),
                                )
                              : Center(
                                  child: Text(
                                    otherName.isNotEmpty
                                        ? otherName[0].toUpperCase()
                                        : '?',
                                    style: GoogleFonts.poppins(
                                        color: primaryColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20),
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(width: 15),

                      // Info Textos
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    otherName,
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                      color: Colors.black87,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  time,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.grey[400],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              data['lastMessage'] ?? 'Inicia la conversación',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.grey[600],
                                height: 1.2,
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
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, VoidCallback onActionTap) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(25),
              decoration: const BoxDecoration(
                color: Color(0xFFF3F7FE),
                shape: BoxShape.circle,
              ),
              child: const Icon(HugeIcons.strokeRoundedMessage02,
                  size: 60, color: Color.fromRGBO(17, 48, 73, 0.4)),
            ),
            const SizedBox(height: 25),
            Text(
              "No tienes mensajes aún",
              style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color.fromRGBO(17, 48, 73, 1)),
            ),
            const SizedBox(height: 10),
            Text(
              "Comienza una nueva conversación",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  color: Colors.grey[500], fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 30),
            if (!isSupplier)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: onActionTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromRGBO(17, 48, 73, 1),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                    elevation: 0,
                  ),
                  child: Text(
                    "Explorar",
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              )
          ],
        ),
      ),
    );
  }
}
