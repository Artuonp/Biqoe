import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

const Color kPrimaryColor = Color.fromRGBO(17, 48, 73, 1);
const Color kBackgroundColor = Color(0xFFF8F9FD);

class SupplierCustomersScreen extends StatefulWidget {
  final String userId;

  const SupplierCustomersScreen({super.key, required this.userId});

  @override
  State<SupplierCustomersScreen> createState() =>
      _SupplierCustomersScreenState();
}

class _SupplierCustomersScreenState extends State<SupplierCustomersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  // --- LÓGICA DE AGRUPACIÓN Y CÁLCULO ---
  List<Map<String, dynamic>> _processCustomers(
      List<QueryDocumentSnapshot> docs) {
    Map<String, Map<String, dynamic>> uniqueCustomers = {};

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;

      // 1. DEFINIR CLAVE ÚNICA (PRIORIDAD: UserId > Cédula > Email > Nombre+Telf)
      String key;
      String? uid; // Guardamos el UID limpio si existe

      if (data['userId'] != null && data['userId'].toString().isNotEmpty) {
        uid = data['userId'];
        key = "UID_$uid";
      } else if (data['cedula'] != null &&
          data['cedula'].toString().isNotEmpty) {
        key = "ID_${data['cedula']}";
      } else if (data['email'] != null && data['email'].toString().isNotEmpty) {
        key = "MAIL_${data['email']}";
      } else {
        String name = data['name'] ?? 'Desconocido';
        String phone = data['celular'] ?? data['numero'] ?? '';
        key = "MANUAL_${name}_$phone";
      }

      // 2. CALCULAR MONTOS
      final double totalCost =
          (data['totalPlanPrice'] ?? data['totalPrice'] ?? 0).toDouble();
      final double paidAmount =
          (data['amountPaid'] ?? data['totalPrice'] ?? 0).toDouble();

      double currentDebt = totalCost - paidAmount;
      if (currentDebt < 0) currentDebt = 0;

      DateTime? activityDate;
      if (data['createdAt'] != null) {
        activityDate = (data['createdAt'] as Timestamp).toDate();
      }

      // 3. AGRUPAR O CREAR
      if (!uniqueCustomers.containsKey(key)) {
        bool isAppUser = uid != null;

        uniqueCustomers[key] = {
          'uniqueKey': key,
          'uid': uid, // Guardamos el UID puro para consultas futuras
          'name': data['name'] ?? 'Sin Nombre',
          'email': data['email'] ?? '',
          'phone': data['celular'] ?? data['numero'] ?? '',
          'cedula': data['cedula'] ?? '',
          'type': isAppUser ? 'app' : 'offline',
          'debt': currentDebt,
          'total_spend': paidAmount,
          'reservation_count': 1,
          'last_activity_date': activityDate ?? DateTime(2000),
          'last_activity_str': _formatDate(activityDate),
        };
      } else {
        var existing = uniqueCustomers[key]!;
        existing['debt'] += currentDebt;
        existing['total_spend'] += paidAmount;
        existing['reservation_count'] += 1;

        if (activityDate != null) {
          DateTime existingDate = existing['last_activity_date'];
          if (activityDate.isAfter(existingDate)) {
            existing['last_activity_date'] = activityDate;
            existing['last_activity_str'] = _formatDate(activityDate);
            // Solo actualizamos datos de contacto si NO es app user (los app users se consultan en vivo)
            if (existing['type'] != 'app') {
              existing['name'] = data['name'] ?? existing['name'];
              existing['phone'] =
                  data['celular'] ?? data['numero'] ?? existing['phone'];
            }
          }
        }
      }
    }

    List<Map<String, dynamic>> customersList = uniqueCustomers.values.toList();

    customersList.sort((a, b) {
      if (a['debt'] > 0 && b['debt'] == 0) return -1;
      if (b['debt'] > 0 && a['debt'] == 0) return 1;
      return b['last_activity_date'].compareTo(a['last_activity_date']);
    });

    if (_searchQuery.isNotEmpty) {
      customersList = customersList.where((c) {
        final name = c['name'].toString().toLowerCase();
        final cedula = c['cedula'].toString().toLowerCase();
        final email = c['email'].toString().toLowerCase();
        return name.contains(_searchQuery) ||
            cedula.contains(_searchQuery) ||
            email.contains(_searchQuery);
      }).toList();
    }

    return customersList;
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) return 'Hoy';
    if (diff.inDays == 1) return 'Ayer';
    if (diff.inDays < 7) return 'Hace ${diff.inDays} días';
    return DateFormat('d MMM').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // --- HEADER ---
            Container(
              padding: const EdgeInsets.all(20),
              color: Colors.white,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Clientes',
                          style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: kPrimaryColor)),
                      IconButton(
                        icon: const Icon(Icons.person_add_alt_1),
                        color: kPrimaryColor,
                        tooltip: "Registra cliente manual",
                        onPressed: () {
                          context.push('/supplier/manual-booking');
                        },
                      )
                    ],
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: _searchController,
                    onChanged: (val) =>
                        setState(() => _searchQuery = val.toLowerCase()),
                    decoration: InputDecoration(
                      hintText: 'Buscar por nombre, cédula o correo',
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      filled: true,
                      fillColor: kBackgroundColor,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // --- LISTA ---
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('reservaciones')
                    .doc(widget.userId)
                    .collection('reservas')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center();
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return _buildEmptyState();
                  }

                  final customers = _processCustomers(snapshot.data!.docs);

                  if (customers.isEmpty) {
                    return Center(
                        child: Text("No se encontraron resultados",
                            style: GoogleFonts.poppins(color: Colors.grey)));
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: customers.length,
                    itemBuilder: (context, index) {
                      final client = customers[index];
                      final isAppUser = client['type'] == 'app';

                      // Si es App User, usamos un FutureBuilder para traer el nombre real
                      if (isAppUser && client['uid'] != null) {
                        return FutureBuilder<DocumentSnapshot>(
                            future: FirebaseFirestore.instance
                                .collection('usuarios')
                                .doc(client['uid'])
                                .get(),
                            builder: (context, userSnap) {
                              // Si hay datos frescos, los usamos visualmente
                              String displayName = client['name'];
                              if (userSnap.hasData && userSnap.data!.exists) {
                                final userData = userSnap.data!.data()
                                    as Map<String, dynamic>;
                                displayName = userData['name'] ?? displayName;
                                // Opcional: Actualizar foto si la tuvieras
                              }

                              return _buildCustomerCard(
                                  client, displayName, isAppUser);
                            });
                      }

                      // Si es manual, usamos los datos directos
                      return _buildCustomerCard(
                          client, client['name'], isAppUser);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Tarjeta extraída para evitar duplicar código en el builder
  Widget _buildCustomerCard(
      Map<String, dynamic> client, String displayName, bool isAppUser) {
    final double debt = client['debt'];
    final bool hasDebt = debt > 1.0;

    return GestureDetector(
      onTap: () {
        // Al navegar, pasamos el mapa cliente.
        // Si el nombre se actualizó visualmente arriba, aquí se envía el original de la reserva
        // PERO la pantalla de detalle YA TIENE la lógica para buscar el nombre real de nuevo,
        // así que no hay problema.
        context.push('/supplier/customer/detail', extra: client);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withAlpha((0.03 * 255).round()),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
          border: hasDebt
              ? Border.all(
                  color: Colors.orange.withAlpha((0.5 * 255).round()),
                  width: 1.5)
              : null,
        ),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: isAppUser
                      ? kPrimaryColor.withAlpha((0.1 * 255).round())
                      : Colors.grey.shade100,
                  child: Text(
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: kPrimaryColor),
                  ),
                ),
                if (hasDebt)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  )
              ],
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(displayName, // Usamos el nombre actualizado
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        isAppUser ? Icons.verified_user : Icons.person_outline,
                        size: 14,
                        color: isAppUser ? Colors.blue : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isAppUser ? "Usuario de Biqoe" : "Cliente externo",
                        style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isAppUser ? Colors.blue : Colors.grey),
                      ),
                    ],
                  ),
                  Text(
                      "Activo: ${client['last_activity_str']} (${client['reservation_count']} reservas)",
                      style: GoogleFonts.poppins(
                          fontSize: 10, color: Colors.grey[500])),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (hasDebt) ...[
                  Text("Debe",
                      style: GoogleFonts.poppins(
                          fontSize: 10, color: Colors.orange[800])),
                  Text("\$${debt.toStringAsFixed(0)}",
                      style: GoogleFonts.poppins(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                ] else ...[
                  Text("Total gastado",
                      style: GoogleFonts.poppins(
                          fontSize: 10, color: Colors.grey)),
                  Text(
                      "\$${(client['total_spend'] as double).toStringAsFixed(0)}",
                      style: GoogleFonts.poppins(
                          color: kPrimaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                ],
                const SizedBox(height: 4),
                const Icon(Icons.chevron_right, color: Colors.grey, size: 18)
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.groups_3_outlined, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 10),
          Text("Aún no tienes clientes registrados",
              style: GoogleFonts.poppins(color: Colors.grey)),
        ],
      ),
    );
  }
}
