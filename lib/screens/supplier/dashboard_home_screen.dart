import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'customer_detail_screen.dart';
import 'activity_history_screen.dart';

// --- IMPORTS ---
// Eliminamos sales_history_screen.dart
import '../chat_list_screen.dart';
import '../chat_detail_screen.dart';
import 'supplier_verify_payments_screen.dart'; // Ya lo tenías, pero confirmamos su uso principal

const Color kPrimaryColor = Color.fromRGBO(17, 48, 73, 1);
const Color kBackgroundColor = Color(0xFFF8F9FD);

class DashboardHomeScreen extends StatefulWidget {
  final String userId;

  const DashboardHomeScreen({super.key, required this.userId});

  @override
  State<DashboardHomeScreen> createState() => _DashboardHomeScreenState();
}

class _DashboardHomeScreenState extends State<DashboardHomeScreen> {
  // Variables para la fusión de streams
  List<Map<String, dynamic>> _mixedActivities = [];

  // NUEVA VARIABLE: Guardará todas las reservas crudas para calcular KPIs sin importar si se ocultan visualmente
  List<QueryDocumentSnapshot> _allBookingDocs = [];

  bool _isLoading = true;
  StreamSubscription? _bookingsSub;
  StreamSubscription? _chatsSub;

  // Variables para el Badge Persistente
  int _unreadCount = 0;
  DateTime _lastBadgeDismissTime = DateTime(2000);
  Box? _prefsBox;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('es');
    _initPrefs();
    _setupDashboardStreams();
  }

  Future<void> _initPrefs() async {
    try {
      _prefsBox = await Hive.openBox('dashboard_prefs_${widget.userId}');
      if (mounted) {
        setState(() {
          final int? timestamp = _prefsBox?.get('lastBadgeDismissTime');
          if (timestamp != null) {
            _lastBadgeDismissTime =
                DateTime.fromMillisecondsSinceEpoch(timestamp);
          }
        });
      }
    } catch (e) {
      debugPrint("Error abriendo Hive prefs: $e");
    }
  }

  @override
  void dispose() {
    _bookingsSub?.cancel();
    _chatsSub?.cancel();
    super.dispose();
  }

  // --- FUSIÓN DE STREAMS ---
  void _setupDashboardStreams() {
    final bookingStream = FirebaseFirestore.instance
        .collection('reservaciones')
        .doc(widget.userId)
        .collection('reservas')
        .orderBy('createdAt', descending: true)
        .snapshots();

    final chatStream = FirebaseFirestore.instance
        .collection('chats')
        .where('participants', arrayContains: widget.userId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots();

    void updateData(List<QueryDocumentSnapshot> bookingDocs,
        List<QueryDocumentSnapshot> chatDocs) {
      final List<Map<String, dynamic>> tempActivities = [];

      int currentUnread = 0;
      DateTime newestUnreadDate = DateTime(2000);

      // A. Procesar Reservas y PAGOS
      for (var doc in bookingDocs) {
        final data = doc.data() as Map<String, dynamic>;

        // Obtenemos la lista de eventos ocultos de este documento
        List<dynamic> hiddenEvents = data['hiddenEvents'] ?? [];

        // 1. CREACIÓN DE RESERVA
        String bookingEventId = "${doc.id}_booking";

        // Si no está en la lista de ocultos, lo agregamos
        if (!hiddenEvents.contains(bookingEventId)) {
          tempActivities.add({
            'type': 'booking',
            'id': bookingEventId, // ID único para el dismissible
            'docId': doc.id,
            'date':
                (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000),
            'data': data,
            'isHidden': false,
          });
        }

        // 2. PAGOS INDIVIDUALES
        List<dynamic> historyList = data['paymentHistory'] ?? [];

        if (historyList.isNotEmpty) {
          for (var i = 0; i < historyList.length; i++) {
            var p = historyList[i];
            bool isPayment = (p['type'] == 'installment') ||
                (p['type'] == 'initial' && (p['amount'] ?? 0) > 0);

            if (isPayment) {
              String paymentEventId = "${doc.id}_pay_$i";

              // Solo agregamos si este pago específico no ha sido ocultado
              if (!hiddenEvents.contains(paymentEventId)) {
                tempActivities.add({
                  'type': 'payment_event',
                  'id': paymentEventId,
                  'docId': doc.id,
                  'date': (p['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
                  'data': {
                    ...data,
                    'specificAmount': p['amount'],
                    'paymentType': p['type'],
                    'isPaymentEvent': true,
                    // Guardamos el índice para saber qué pago es al borrarlo si fuera necesario
                    'paymentIndex': i
                  },
                  'isHidden': false,
                });
              }
            }
          }
        }
      }

      // B. Procesar Mensajes (Los chats se ocultan completos por ahora)
      for (var doc in chatDocs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['readBySupplier'] == false) {
          currentUnread++;
          final msgDate = (data['lastMessageTime'] as Timestamp?)?.toDate() ??
              DateTime(2000);
          if (msgDate.isAfter(newestUnreadDate)) newestUnreadDate = msgDate;
        }

        if (data['hiddenFromDashboard'] == true) continue;

        tempActivities.add({
          'type': 'message',
          'id': doc.id,
          'docId': doc.id,
          'date': (data['lastMessageTime'] as Timestamp?)?.toDate() ??
              DateTime(2000),
          'data': data,
          'isHidden': false,
        });
      }

      bool showBadge =
          currentUnread > 0 && newestUnreadDate.isAfter(_lastBadgeDismissTime);

      // D. Ordenar
      tempActivities.sort((a, b) => b['date'].compareTo(a['date']));

      if (mounted) {
        setState(() {
          _mixedActivities = tempActivities; // Lista Visual (se puede borrar)
          _allBookingDocs =
              bookingDocs; // Lista Financiera (SIEMPRE COMPLETA) <--- AGREGAR ESTO
          _unreadCount = showBadge ? currentUnread : 0;
          _isLoading = false;
        });
      }
    }

    List<QueryDocumentSnapshot> currentBookings = [];
    List<QueryDocumentSnapshot> currentChats = [];

    _bookingsSub = bookingStream.listen((snapshot) {
      currentBookings = snapshot.docs;
      updateData(currentBookings, currentChats);
    });

    _chatsSub = chatStream.listen((snapshot) {
      currentChats = snapshot.docs;
      updateData(currentBookings, currentChats);
    });
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(symbol: '\$', decimalDigits: 2).format(amount);
  }

  // --- NAVEGACIÓN A LA NUEVA PANTALLA DE PAGOS ---
  void _navigateToSalesList(BuildContext context, int tabIndex) {
    // Redirigimos a SupplierVerifyPaymentsScreen pasando el índice del tab deseado
    // Nota: Como esa pantalla usa DefaultTabController, no podemos pasar el índice directamente
    // en el constructor a menos que modifiques esa pantalla también.
    // Por simplicidad, abriremos la pantalla general y el usuario puede cambiar de tab.

    // Si quieres que abra un tab específico, tendrías que modificar SupplierVerifyPaymentsScreen
    // para aceptar 'initialIndex'. Por ahora, abre la pantalla general.

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SupplierVerifyPaymentsScreen(
          supplierId: widget.userId,
          planName: "", // Vacío para ver global
        ),
      ),
    );
  }

  void _navigateToHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        // Asegúrate de importar activity_history_screen.dart al inicio del archivo
        builder: (context) => ActivityHistoryScreen(userId: widget.userId),
      ),
    );
  }

  void _onMessageIconTap() {
    final now = DateTime.now();
    setState(() {
      _unreadCount = 0;
      _lastBadgeDismissTime = now;
    });
    _prefsBox?.put('lastBadgeDismissTime', now.millisecondsSinceEpoch);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatListScreen(
          currentUserId: widget.userId,
          isSupplier: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // --- CÁLCULO DE KPIs EXACTOS (Basado en Historial de Pagos) ---
    double verifiedIncome = 0;
    int pendingVerificationCount = 0;
    double pendingCollectionAmount = 0;

    for (var doc in _allBookingDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final List history = data['paymentHistory'] ?? [];
      final double total = (data['totalPlanPrice'] ?? 0).toDouble();
      final double paid =
          (data['amountPaid'] ?? 0).toDouble(); // Solo lo verificado

      // 1. Analizar Historial de Pagos (Para ingresos y conteo de pendientes)
      bool hasPendingInternal = false;

      for (var p in history) {
        final String status =
            p['status'] ?? 'verified'; // Legacy asumimos verified
        final double amount = (p['amount'] ?? 0).toDouble();

        if (status == 'verified') {
          verifiedIncome += amount;
        } else if (status == 'pending') {
          pendingVerificationCount++;
          hasPendingInternal = true;
        }
      }

      // 2. Caso Legacy: Reserva pendiente sin historial desglosado
      // Si la reserva está pendiente y no hay items 'pending' adentro, cuenta como 1 pendiente
      if (data['estado'] == 'pendiente' && !hasPendingInternal) {
        pendingVerificationCount++;
      }

      // 3. Deuda Por Cobrar (Saldo Restante)
      // Si hay diferencia entre el precio total y lo pagado (verificado)
      if ((total - paid) > 1.0) {
        pendingCollectionAmount += (total - paid);
      }
    }

    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: kBackgroundColor,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: kPrimaryColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Panel de control',
                style: GoogleFonts.poppins(
                    color: kPrimaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 20)),
            Text('Gestión de tus actividades',
                style: GoogleFonts.poppins(
                    color: Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.w400)),
          ],
        ),
        actions: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                margin: const EdgeInsets.only(right: 16, top: 5),
                decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withAlpha((0.01 * 255).round()),
                          blurRadius: 2)
                    ]),
                child: IconButton(
                  icon: const Icon(HugeIcons.strokeRoundedMessage01,
                      color: kPrimaryColor, size: 22),
                  onPressed: _onMessageIconTap,
                ),
              ),
              if (_unreadCount > 0)
                Positioned(
                  right: 12,
                  top: 5,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: kBackgroundColor, width: 2),
                    ),
                    constraints:
                        const BoxConstraints(minWidth: 18, minHeight: 18),
                    child: Text(
                      '$_unreadCount',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Resumen financiero',
                      style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: kPrimaryColor)),
                  const SizedBox(height: 15),

                  // KPIs
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => _navigateToSalesList(context, 2),
                          child: _KPICard(
                            title: 'Verificadas',
                            value: _formatCurrency(verifiedIncome),
                            icon: Icons.verified_user,
                            color: Colors.green,
                            gradientColors: [
                              Colors.green.shade400,
                              Colors.green.shade700
                            ],
                          ),
                        ),
                        const SizedBox(width: 15),
                        GestureDetector(
                          onTap: () => _navigateToSalesList(context, 1),
                          child: _KPICard(
                            title: 'Por verificar',
                            value: '$pendingVerificationCount',
                            icon: Icons.notifications_active,
                            color: Colors.orange,
                            gradientColors: [
                              Colors.orange.shade300,
                              Colors.orange.shade600
                            ],
                          ),
                        ),
                        const SizedBox(width: 15),
                        GestureDetector(
                          onTap: () => _navigateToSalesList(context, 3),
                          child: _KPICard(
                            title: 'Por cobrar',
                            value: _formatCurrency(pendingCollectionAmount),
                            subtitle: 'Cuotas y efectivo',
                            icon: Icons.account_balance_wallet,
                            color: Colors.blue,
                            gradientColors: [
                              const Color(0xFF56CCF2),
                              const Color(0xFF2F80ED)
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ACTIVIDAD RECIENTE
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Actividad reciente',
                          style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: kPrimaryColor)),
                      TextButton(
                        onPressed: _navigateToHistory,
                        child: Text('Ver todo',
                            style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.blue,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // FILTRO VISUAL: Solo mostramos las que no están ocultas
                  // (Los KPIs arriba usan _mixedActivities completo, así que no bajan sus números)
                  Builder(
                    builder: (context) {
                      final visibleActivities = _mixedActivities
                          .where((item) => item['isHidden'] != true)
                          .toList();

                      if (visibleActivities.isEmpty) {
                        return _buildEmptyState();
                      }

                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        // Mostramos máximo 10 de las VISIBLES
                        itemCount: visibleActivities.length > 10
                            ? 10
                            : visibleActivities.length,
                        separatorBuilder: (c, i) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          // Usamos la lista FILTRADA 'visibleActivities' si aplicaste ese filtro,
                          // o _mixedActivities si estás mostrando todo.
                          // Asumo que estás usando la lógica de filtro visual que te pasé antes:

                          final item = visibleActivities[
                              index]; // O _mixedActivities[index]

                          final String uniqueId =
                              item['id']; // ID único (puede ser virtual)
                          final String realDocId =
                              item['docId']; // ID real de Firestore
                          final String type = item['type'];
                          final Map<String, dynamic> data = item['data'];

                          return Dismissible(
                            key: Key(
                                uniqueId), // Usamos el uniqueId (ej: reserva_pay_1)
                            direction: DismissDirection.horizontal,
                            onDismissed: (direction) {
                              if (type == 'booking' ||
                                  type == 'payment_event') {
                                // ACTUALIZACIÓN PARCIAL: Agregar ID al array de ocultos
                                FirebaseFirestore.instance
                                    .collection('reservaciones')
                                    .doc(widget.userId)
                                    .collection('reservas')
                                    .doc(realDocId)
                                    .update({
                                  'hiddenEvents':
                                      FieldValue.arrayUnion([uniqueId])
                                });
                              } else if (type == 'message') {
                                // Los mensajes siguen ocultándose completos
                                FirebaseFirestore.instance
                                    .collection('chats')
                                    .doc(realDocId)
                                    .update({'hiddenFromDashboard': true});
                              }

                              // Actualizar localmente
                              setState(() {
                                // Simplemente lo sacamos de la lista visual,
                                // el stream lo filtrará en la próxima actualización
                                _mixedActivities.removeAt(index);
                              });
                            },
                            // ... (backgrounds igual que antes) ...
                            child: _ActivityItem(
                              itemType: type,
                              data: data,
                              onTap: () {
                                if (type == 'message') {
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              ChatDetailScreen(
                                                chatId:
                                                    realDocId, // <--- USAR ID REAL
                                                otherName: data['userName'] ??
                                                    'Usuario',
                                                otherImage:
                                                    data['userImage'] ?? '',
                                                currentUserId: widget.userId,
                                              )));
                                } else {
                                  // Marcar leída
                                  FirebaseFirestore.instance
                                      .collection('reservaciones')
                                      .doc(widget.userId)
                                      .collection('reservas')
                                      .doc(realDocId)
                                      .update({'read': true});

                                  // Mostrar Diálogo
                                  showDialog(
                                    context: context,
                                    builder: (context) => BookingDetailDialog(
                                      data: data,
                                      docId: realDocId, // <--- USAR ID REAL
                                      supplierId: widget.userId,
                                    ),
                                  );
                                }
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(30),
      width: double.infinity,
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        children: [
          Icon(Icons.inbox, size: 40, color: Colors.grey[300]),
          const SizedBox(height: 10),
          Text("No hay actividad reciente",
              style: GoogleFonts.poppins(color: Colors.grey)),
        ],
      ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final String itemType; // 'booking', 'message', o 'payment_event'
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  const _ActivityItem(
      {required this.itemType, required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    String activityTitle = data['name'] ?? 'Cliente';
    String activitySubtitle = data['planName'] ?? 'Reserva';
    String activityStatusText = "";
    IconData activityIcon = Icons.help;
    Color iconColor = kPrimaryColor;
    bool isRead = true;
    DateTime itemDate;

    // --- 1. CASO MENSAJE ---
    if (itemType == 'message') {
      itemDate =
          (data['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime.now();
      isRead = true; // Mensajes visualmente siempre blancos en la lista

      activityTitle = data['userName'] ?? 'Usuario';
      activitySubtitle = data['lastMessage'] ?? 'Mensaje de texto';
      activityStatusText = "Nuevo mensaje";
      activityIcon = HugeIcons.strokeRoundedMessage01;
      iconColor = Colors.blueAccent;
    }
    // --- 2. CASO PAGO (Cuota o Inicial) ---
    else if (itemType == 'payment_event' || data['isPaymentEvent'] == true) {
      // Intentamos usar la fecha específica del pago si fue inyectada por el stream
      // Si no, usamos createdAt como respaldo.
      if (data['displayDate'] != null && data['displayDate'] is Timestamp) {
        itemDate = (data['displayDate'] as Timestamp).toDate();
      } else {
        itemDate =
            (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
      }

      isRead = data['read'] ?? false;

      // Determinamos subtipo de pago
      String type = data['paymentType'] ?? 'installment';
      double amount = (data['specificAmount'] ?? 0).toDouble();

      if (type == 'initial') {
        activityStatusText = "Pago inicial";
        activityIcon = HugeIcons.strokeRoundedCheckmarkCircle02;
        iconColor = Colors.green;
      } else {
        activityStatusText = "Nuevo pago"; // Cuota
        activityIcon = HugeIcons.strokeRoundedInvoice;
        iconColor = Colors.purple;
      }

      // Mostramos el monto de este pago específico
      activitySubtitle = "Monto: \$${amount.toStringAsFixed(2)}";
    }
    // --- 3. CASO RESERVA GENERAL (Creación) ---
    else {
      itemDate = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
      isRead = data['read'] ?? false;

      final String status = data['estado'] ?? 'pendiente';

      if (status == 'pendiente') {
        activityStatusText = "Nueva reserva";
        activityIcon = HugeIcons.strokeRoundedNotification01;
        iconColor = Colors.orange;
      } else if (status == 'verificado') {
        activityStatusText = "Reserva Confirmada";
        activityIcon = HugeIcons.strokeRoundedCheckmarkCircle02;
        iconColor = Colors.green;
      } else {
        activityStatusText = "Actividad";
        iconColor = Colors.grey;
      }
    }

    // Formateo de fecha y hora
    final dateStr = DateFormat('d MMM', 'es').format(itemDate);
    final timeStr = DateFormat('hh:mm a').format(itemDate);

    // Diseño Condicional (Leído vs No Leído)
    final Color bgColor =
        isRead ? Colors.white : Colors.blue.withAlpha((0.04 * 255).round());
    final Color borderColor = isRead
        ? Colors.grey.shade100
        : Colors.blue.withAlpha((0.1 * 255).round());

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withAlpha((0.02 * 255).round()),
                  blurRadius: 5,
                  offset: const Offset(0, 2))
            ],
            border: Border.all(color: borderColor, width: isRead ? 1 : 1.5)),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withAlpha((0.1 * 255).round()),
                shape: BoxShape.circle,
              ),
              child: Icon(activityIcon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(activityStatusText,
                          style: GoogleFonts.poppins(
                              fontWeight:
                                  isRead ? FontWeight.w600 : FontWeight.bold,
                              fontSize: 13,
                              color: kPrimaryColor)),
                      Text(timeStr,
                          style: GoogleFonts.poppins(
                              color: Colors.grey[400], fontSize: 10)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          "$activityTitle • $activitySubtitle",
                          style: GoogleFonts.poppins(
                              color: Colors.grey[600], fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      Text(dateStr,
                          style: GoogleFonts.poppins(
                              color: Colors.grey[400], fontSize: 10)),
                    ],
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

// Widget KPI
class _KPICard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final List<Color> gradientColors;

  const _KPICard(
      {required this.title,
      required this.value,
      this.subtitle,
      required this.icon,
      required this.color,
      required this.gradientColors});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 155,
      height: 165,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: gradientColors.last.withAlpha((0.03 * 255).round()),
              blurRadius: 5,
              offset: const Offset(0, 1))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: Colors.white.withAlpha((0.2 * 255).round()),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              const SizedBox(height: 4),
              Text(title,
                  style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.white.withAlpha((0.9 * 255).round()),
                      fontWeight: FontWeight.w500)),
              if (subtitle != null)
                Text(subtitle!,
                    style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: Colors.white.withAlpha((0.7 * 255).round()))),
            ],
          ),
        ],
      ),
    );
  }
}

// --- NUEVO COMPONENTE REUTILIZABLE: DETALLE DE RESERVA (ACTUALIZADO) ---
class BookingDetailDialog extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;
  final String supplierId;

  const BookingDetailDialog({
    super.key,
    required this.data,
    required this.docId,
    required this.supplierId,
  });

  @override
  Widget build(BuildContext context) {
    // --- 1. DATOS GENERALES ---
    final String clientName = data['name'] ?? 'Cliente';
    final String clientEmail = data['email'] ?? '';
    final String clientPhone = data['numero'] ?? data['celular'] ?? '';
    final String clientCedula = data['cedula'] ?? '';
    final String planName = data['planName'] ?? 'Actividad';
    final String reservationCode = data['code'] ?? '---';
    final String userId = data['userId'] ?? ''; // ID del usuario App

    // --- 2. DATOS FINANCIEROS ---
    final double totalPrice =
        (data['totalPlanPrice'] ?? data['totalPrice'] ?? 0).toDouble();
    final double amountPaid =
        (data['amountPaid'] ?? data['totalPrice'] ?? 0).toDouble();
    final double debt = totalPrice - amountPaid;

    final String status = data['estado'] ?? 'pendiente';
    final bool isVerified = status == 'verificado';
    final bool isFullyPaid = debt <= 1.0;

    // --- 3. PAQUETES (Fechas del viaje) ---
    String tripDateStr = "Por definir";
    if (data['packages'] != null && (data['packages'] as List).isNotEmpty) {
      final pkg = (data['packages'] as List)[0];
      if (pkg['fechaReserva'] != null) {
        try {
          DateTime tripDate = DateTime.parse(pkg['fechaReserva']);
          tripDateStr = DateFormat('dd/MM/yyyy').format(tripDate);
        } catch (e) {
          tripDateStr = pkg['fechaReserva']; // Fallback
        }
      }
    }

    // --- 4. HISTORIAL DE PAGOS ---
    final List<dynamic> paymentHistory = data['paymentHistory'] ?? [];

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(15),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 700),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((0.15 * 255).round()),
              blurRadius: 25,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // --- HEADER ---
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 20, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text("Detalle de reserva",
                        style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: kPrimaryColor)),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close,
                          size: 20, color: Colors.black54),
                    ),
                  )
                ],
              ),
            ),
            const Divider(height: 1),

            // --- CONTENIDO SCROLLABLE ---
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // A. SECCIÓN CLIENTE (Clickable)
                    InkWell(
                      onTap: () {
                        // Navegar a CustomerDetailScreen
                        final clientMap = {
                          'name':
                              clientName, // Se actualizará al entrar al detalle
                          'email': clientEmail,
                          'phone': clientPhone,
                          'cedula': clientCedula,
                          'uniqueKey': 'UID_$userId',
                          'debt': debt,
                          'total_spend': amountPaid,
                          'reservation_count': 1,
                          'type': 'app',
                        };

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                CustomerDetailScreen(clientData: clientMap),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: kPrimaryColor.withAlpha((0.03 * 255).round()),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color:
                                  kPrimaryColor.withAlpha((0.1 * 255).round())),
                        ),
                        // AQUÍ ESTÁ LA LÓGICA DE ACTUALIZACIÓN DE NOMBRE
                        child: userId.isEmpty
                            ? _buildUserRow(
                                clientName) // Cliente manual (usa nombre reserva)
                            : FutureBuilder<DocumentSnapshot>(
                                // Cliente App (busca nombre real)
                                future: FirebaseFirestore.instance
                                    .collection('usuarios')
                                    .doc(userId)
                                    .get(),
                                builder: (context, snapshot) {
                                  String displayName =
                                      clientName; // Por defecto el de la reserva

                                  if (snapshot.hasData &&
                                      snapshot.data != null &&
                                      snapshot.data!.exists) {
                                    final userData = snapshot.data!.data()
                                        as Map<String, dynamic>;
                                    displayName =
                                        userData['name'] ?? clientName;
                                  }

                                  return _buildUserRow(displayName);
                                },
                              ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // B. DATOS BÁSICOS
                    Text("INFORMACIÓN GENERAL",
                        style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[500],
                            letterSpacing: 1.0)),
                    const SizedBox(height: 10),
                    _InfoTile(
                        label: "Actividad",
                        value: planName,
                        icon: HugeIcons.strokeRoundedTicket01),
                    _InfoTile(
                        label: "Código de reserva",
                        value: reservationCode,
                        icon: HugeIcons.strokeRoundedQrCode),
                    _InfoTile(
                        label: "Fecha",
                        value: tripDateStr,
                        icon: HugeIcons.strokeRoundedCalendar01),

                    const SizedBox(height: 24),

                    // C. HISTORIAL DE PAGOS
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("HISTORIAL DE PAGOS",
                            style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[500],
                                letterSpacing: 1.0)),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                              color: isFullyPaid
                                  ? Colors.green.withAlpha((0.1 * 255).round())
                                  : Colors.orange
                                      .withAlpha((0.1 * 255).round()),
                              borderRadius: BorderRadius.circular(4)),
                          child: Text(
                            isFullyPaid ? "PAGADO" : "PENDIENTE",
                            style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color:
                                    isFullyPaid ? Colors.green : Colors.orange),
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 10),

                    if (paymentHistory.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(8)),
                        child: Text("Pago único inicial registrado.",
                            style: GoogleFonts.poppins(fontSize: 12)),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: paymentHistory.length,
                        separatorBuilder: (c, i) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final pay =
                              paymentHistory[index] as Map<String, dynamic>;
                          return _PaymentCard(
                              paymentData: pay, index: index + 1);
                        },
                      ),

                    const SizedBox(height: 24),

                    // D. RESUMEN FINANCIERO
                    const Divider(),
                    const SizedBox(height: 10),
                    _FinanceRow(label: "Costo Total", amount: totalPrice),
                    const SizedBox(height: 5),
                    _FinanceRow(
                        label: "Total Abonado",
                        amount: amountPaid,
                        color: Colors.green),
                    const SizedBox(height: 5),
                    _FinanceRow(
                        label: "Restante por Pagar",
                        amount: debt < 0 ? 0 : debt,
                        color: debt > 1 ? Colors.red : Colors.grey,
                        isBold: true),
                  ],
                ),
              ),
            ),

            // --- BOTÓN VERIFICAR ---
            if (!isVerified || !isFullyPaid)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                    color: Colors.white,
                    border:
                        Border(top: BorderSide(color: Colors.grey.shade100))),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SupplierVerifyPaymentsScreen(
                            supplierId: supplierId,
                            planName: planName,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: Text(
                      "Gestionar",
                      style: GoogleFonts.poppins(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // --- HELPER PARA EVITAR CÓDIGO DUPLICADO EN EL FUTURE BUILDER ---
  Widget _buildUserRow(String displayName) {
    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: kPrimaryColor,
          child: Text(
            displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
            style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(displayName,
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.black87)),
              Row(
                children: [
                  Text("Ver perfil cliente",
                      style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: kPrimaryColor,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_ios,
                      size: 10, color: kPrimaryColor)
                ],
              )
            ],
          ),
        )
      ],
    );
  }
}

// --- WIDGET AUXILIAR: Tarjeta de Pago Individual ---
class _PaymentCard extends StatelessWidget {
  final Map<String, dynamic> paymentData;
  final int index;

  const _PaymentCard({required this.paymentData, required this.index});

  @override
  Widget build(BuildContext context) {
    // Extraer datos con validación null
    final double amount = (paymentData['amount'] ?? 0).toDouble();
    final double amountBs = (paymentData['amountBs'] ?? 0).toDouble();
    final String type = paymentData['type'] ?? 'installment';
    final String method = paymentData['method'] ?? 'Desconocido';
    final String? bank = paymentData['banco'];
    final String? ref = paymentData['referencia'];
    final String? cedula = paymentData['cedula'];
    final String? phone = paymentData['telefono'];

    // Fecha
    DateTime? date;
    if (paymentData['date'] != null) {
      date = (paymentData['date'] as Timestamp).toDate();
    }
    final dateStr =
        date != null ? DateFormat('dd/MM/yyyy').format(date) : '--/--/----';

    final String title = type == 'initial' ? "Pago inicial" : "Cuota #$index";

    return Container(
      decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          // Icono según método
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade100)),
            child: Icon(Icons.attach_money, size: 18, color: Colors.green[700]),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600, fontSize: 13)),
              Text("\$${amount.toStringAsFixed(0)}",
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.black87)),
            ],
          ),
          subtitle: Text("$dateStr • $method",
              style:
                  GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500])),

          // DETALLES EXPANDIBLES
          children: [
            const Divider(),
            if (amountBs > 0)
              _miniRow("Monto Bs", "Bs. ${amountBs.toStringAsFixed(2)}"),
            if (bank != null && bank.isNotEmpty) _miniRow("Banco", bank),
            if (ref != null && ref.isNotEmpty) _miniRow("Referencia", ref),
            if (cedula != null && cedula.isNotEmpty) _miniRow("Cédula", cedula),
            if (phone != null && phone.isNotEmpty) _miniRow("Teléfono", phone),
          ],
        ),
      ),
    );
  }

  Widget _miniRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style:
                  GoogleFonts.poppins(fontSize: 11, color: Colors.grey[600])),
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87)),
        ],
      ),
    );
  }
}

// --- WIDGET AUXILIAR: Fila de Info General ---
class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _InfoTile(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[400]),
          const SizedBox(width: 10),
          Text("$label: ",
              style:
                  GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// --- WIDGET AUXILIAR: Fila Financiera (Ya existente simplificada) ---
class _FinanceRow extends StatelessWidget {
  final String label;
  final double amount;
  final Color? color;
  final bool isBold;

  const _FinanceRow(
      {required this.label,
      required this.amount,
      this.color,
      this.isBold = false});

  @override
  Widget build(BuildContext context) {
    final fmt =
        NumberFormat.currency(symbol: '\$', decimalDigits: 2).format(amount);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.black87,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        Text(fmt,
            style: GoogleFonts.poppins(
                fontSize: 13,
                color: color ?? Colors.black87,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
      ],
    );
  }
}
