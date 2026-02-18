import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:hugeicons/hugeicons.dart';

// --- IMPORTS ---
import '../chat_detail_screen.dart'; // Ajusta la ruta a tu chat
import 'dashboard_home_screen.dart'; // Para reutilizar BookingDetailDialog

const Color kPrimaryColor = Color.fromRGBO(17, 48, 73, 1);
const Color kBackgroundColor = Color(0xFFF8F9FD);

class ActivityHistoryScreen extends StatefulWidget {
  final String userId;

  const ActivityHistoryScreen({super.key, required this.userId});

  @override
  State<ActivityHistoryScreen> createState() => _ActivityHistoryScreenState();
}

class _ActivityHistoryScreenState extends State<ActivityHistoryScreen> {
  @override
  void initState() {
    super.initState();
    initializeDateFormatting('es');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: kPrimaryColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("Historial de actividades",
            style: GoogleFonts.poppins(
                color: kPrimaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 18)),
      ),
      // USAMOS STREAM BUILDER ANIDADO PARA GARANTIZAR DATOS FRESCOS
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('reservaciones')
            .doc(widget.userId)
            .collection('reservas')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, bookingSnap) {
          if (bookingSnap.connectionState == ConnectionState.waiting) {
            return const Center();
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('chats')
                .where('participants', arrayContains: widget.userId)
                .orderBy('lastMessageTime', descending: true)
                .snapshots(),
            builder: (context, chatSnap) {
              final List<Map<String, dynamic>> allItems = [];
              final bookingDocs = bookingSnap.data?.docs ?? [];
              final chatDocs = chatSnap.data?.docs ?? [];

              // 1. PROCESAR RESERVAS Y PAGOS (Lógica idéntica al Dashboard)
              for (var doc in bookingDocs) {
                final data = doc.data() as Map<String, dynamic>;

                // A. Creación Reserva
                allItems.add({
                  'type': 'booking',
                  'id': "${doc.id}_booking",
                  'docId': doc.id,
                  'date': (data['createdAt'] as Timestamp?)?.toDate() ??
                      DateTime(2000),
                  'data': data,
                });

                // B. Pagos Individuales
                List<dynamic> history = data['paymentHistory'] ?? [];
                if (history.isNotEmpty) {
                  for (int i = 0; i < history.length; i++) {
                    var p = history[i];
                    bool isPayment = (p['type'] == 'installment') ||
                        (p['type'] == 'initial' && (p['amount'] ?? 0) > 0);

                    if (isPayment) {
                      allItems.add({
                        'type': 'payment_event',
                        'id': "${doc.id}_pay_$i",
                        'docId': doc.id,
                        'date': (p['date'] as Timestamp?)?.toDate() ??
                            DateTime.now(),
                        'data': {
                          ...data,
                          'specificAmount': p['amount'],
                          'paymentType': p['type'],
                          'isPaymentEvent': true,
                          'displayDate': p['date']
                        },
                      });
                    }
                  }
                }
              }

              // 2. PROCESAR MENSAJES
              for (var doc in chatDocs) {
                final data = doc.data() as Map<String, dynamic>;
                allItems.add({
                  'type': 'message',
                  'id': doc.id,
                  'docId': doc.id,
                  'date': (data['lastMessageTime'] as Timestamp?)?.toDate() ??
                      DateTime(2000),
                  'data': data,
                });
              }

              // 3. ORDENAR
              allItems.sort((a, b) => b['date'].compareTo(a['date']));

              if (allItems.isEmpty) {
                return Center(
                    child: Text("No hay historial disponible",
                        style: GoogleFonts.poppins(color: Colors.grey)));
              }

              return ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: allItems.length,
                separatorBuilder: (c, i) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = allItems[index];

                  // Usamos un widget local _HistoryItem para visualizar
                  return _HistoryItemLocal(
                    itemType: item['type'],
                    data: item['data'],
                    docId: item['docId'],
                    userId: widget.userId,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

// --- WIDGET ITEM LOCAL PARA EL HISTORIAL ---
class _HistoryItemLocal extends StatelessWidget {
  final String itemType;
  final Map<String, dynamic> data;
  final String docId;
  final String userId;

  const _HistoryItemLocal(
      {required this.itemType,
      required this.data,
      required this.docId,
      required this.userId});

  @override
  Widget build(BuildContext context) {
    String title = "";
    String status = "";
    IconData icon = Icons.info;
    Color color = kPrimaryColor;
    DateTime date = DateTime.now();

    // 1. Mensaje
    if (itemType == 'message') {
      title = data['userName'] ?? 'Usuario';
      status = "Mensaje: ${data['lastMessage'] ?? ''}";
      icon = HugeIcons.strokeRoundedMessage01;
      color = Colors.blue;
      date =
          (data['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime.now();
    }
    // 2. Pago
    else if (itemType == 'payment_event') {
      if (data['displayDate'] != null && data['displayDate'] is Timestamp) {
        date = (data['displayDate'] as Timestamp).toDate();
      } else {
        date = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
      }

      String type = data['paymentType'] ?? 'installment';
      double amount = (data['specificAmount'] ?? 0).toDouble();
      title = data['name'] ?? 'Cliente';

      if (type == 'initial') {
        status = "Pago inicial: \$${amount.toStringAsFixed(2)}";
        icon = HugeIcons.strokeRoundedCheckmarkCircle02;
        color = Colors.green;
      } else {
        status = "Pago cuota: \$${amount.toStringAsFixed(2)}";
        icon = HugeIcons.strokeRoundedInvoice;
        color = Colors.purple;
      }
    }
    // 3. Reserva
    else {
      title = "Reserva: ${data['planName']}";
      String state = data['estado'] ?? 'pendiente';
      if (state == 'pendiente') {
        status = "Nueva reserva";
        icon = HugeIcons.strokeRoundedNotification01;
        color = Colors.orange;
      } else {
        status = "Reserva ${state.toUpperCase()}";
        icon = HugeIcons.strokeRoundedCheckmarkCircle02;
        color = Colors.green;
      }
      date = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    }

    final dateStr = DateFormat('dd/MM/yyyy hh:mm a', 'es').format(date);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (itemType == 'message') {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => ChatDetailScreen(
                        chatId: docId,
                        otherName: data['userName'] ?? 'Usuario',
                        otherImage: data['userImage'] ?? '',
                        currentUserId: userId,
                      )));
        } else {
          // Abrir Dialogo (Reutilizado del Dashboard)
          showDialog(
              context: context,
              builder: (_) => BookingDetailDialog(
                    data: data,
                    docId: docId,
                    supplierId: userId,
                  ));
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withAlpha((0.03 * 255).round()),
                blurRadius: 5,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: color.withAlpha((0.1 * 255).round()),
                  shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(status,
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: kPrimaryColor)),
                      Text(dateStr,
                          style: GoogleFonts.poppins(
                              fontSize: 10, color: Colors.grey[400])),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(title,
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: Colors.grey[700]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
