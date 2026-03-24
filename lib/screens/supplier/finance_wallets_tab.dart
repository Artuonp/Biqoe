import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'finance_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PESTAÑA: CAJAS / WALLETS
// Gestión de fondos: Caja Chica, Banco, Fondo Mantenimiento, etc.
// Muestra saldo real por caja cruzando ingresos_egresos.
// ─────────────────────────────────────────────────────────────────────────────
class FinanceWalletsTab extends StatelessWidget {
  final String supplierId;
  const FinanceWalletsTab({super.key, required this.supplierId});

  void _openAddWallet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _WalletModal(supplierId: supplierId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Header acción
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Cajas y fondos',
                  style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: kPrimaryColor)),
              Text('Saldos calculados en tiempo real',
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: Colors.grey[500])),
            ]),
            ElevatedButton.icon(
              onPressed: () => _openAddWallet(context),
              icon: const Icon(Icons.add, color: Colors.white, size: 16),
              label: Text('Nueva caja',
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
            ),
          ],
        ),
      ),

      // Stream de wallets
      Expanded(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('wallets')
              .where('supplierId', isEqualTo: supplierId)
              .orderBy('createdAt', descending: false)
              .snapshots(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snap.hasData || snap.data!.docs.isEmpty) {
              return _noWalletsView(context);
            }

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('ingresos_egresos')
                  .where('supplierId', isEqualTo: supplierId)
                  .snapshots(),
              builder: (context, txSnap) {
                final txDocs = txSnap.data?.docs ?? [];

                // Calcular saldo por walletId
                Map<String, double> balances = {};
                for (var tx in txDocs) {
                  final d = tx.data() as Map<String, dynamic>;
                  final walletId = d['walletId']?.toString();
                  final toWalletId = d['toWalletId']?.toString();
                  final amt = (d['monto'] ?? 0).toDouble();
                  final type = d['type'] ?? 'expense';

                  if (walletId != null) {
                    balances[walletId] ??= 0;
                    if (type == 'income') {
                      balances[walletId] = balances[walletId]! + amt;
                    } else if (type == 'expense') {
                      balances[walletId] = balances[walletId]! - amt;
                    } else if (type == 'internal') {
                      balances[walletId] = balances[walletId]! - amt;
                    }
                  }
                  if (toWalletId != null && type == 'internal') {
                    balances[toWalletId] ??= 0;
                    balances[toWalletId] = balances[toWalletId]! + amt;
                  }
                }

                final wallets = snap.data!.docs;
                final totalBalance = balances.values.fold(0.0, (a, b) => a + b);

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Total consolidado
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [kPrimaryColor, Color(0xFF1A5F8A)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                  color: kPrimaryColor.withValues(alpha: 0.3),
                                  blurRadius: 14,
                                  offset: const Offset(0, 6))
                            ],
                          ),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Balance total consolidado',
                                    style: GoogleFonts.poppins(
                                        color: Colors.white70, fontSize: 12)),
                                const SizedBox(height: 6),
                                Text(
                                  '\$${totalBalance.toStringAsFixed(2)}',
                                  style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                    '${wallets.length} ${wallets.length == 1 ? 'caja' : 'cajas'} activas',
                                    style: GoogleFonts.poppins(
                                        color: Colors.white60, fontSize: 11)),
                              ]),
                        ),
                        const SizedBox(height: 24),

                        Text('Detalle por caja',
                            style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: kPrimaryColor)),
                        const SizedBox(height: 14),

                        // Lista de wallets
                        ...wallets.map((doc) {
                          final d = doc.data() as Map<String, dynamic>;
                          final balance = balances[doc.id] ?? 0.0;
                          return _WalletCard(
                            walletId: doc.id,
                            name: d['name'] ?? 'Caja',
                            description: d['description'] ?? '',
                            icon: _iconFromString(d['icon'] ?? 'wallet'),
                            color: _colorFromHex(d['color'] ?? '#113049'),
                            balance: balance,
                            onDelete: () => _confirmDelete(context, doc.id),
                            onEdit: () => showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => _WalletModal(
                                supplierId: supplierId,
                                walletId: doc.id,
                                existing: d,
                              ),
                            ),
                          );
                        }),
                      ]),
                );
              },
            );
          },
        ),
      ),
    ]);
  }

  Widget _noWalletsView(BuildContext context) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.account_balance_wallet_outlined,
            size: 64, color: Colors.grey[300]),
        const SizedBox(height: 14),
        Text('Sin cajas creadas',
            style: GoogleFonts.poppins(
                color: Colors.grey, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Text('Crea tu primera caja o fondo de dinero',
            style: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 12)),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: () => _openAddWallet(context),
          icon: const Icon(Icons.add, color: Colors.white),
          label: Text('Crear primera caja',
              style: GoogleFonts.poppins(color: Colors.white)),
          style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12))),
        ),
      ]),
    );
  }

  void _confirmDelete(BuildContext context, String docId) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('¿Eliminar caja?',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text('Las transacciones asociadas no se eliminarán.',
            style: GoogleFonts.poppins()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c),
              child: Text('Cancelar',
                  style: GoogleFonts.poppins(color: Colors.grey))),
          TextButton(
              onPressed: () {
                FirebaseFirestore.instance
                    .collection('wallets')
                    .doc(docId)
                    .delete();
                Navigator.pop(c);
              },
              child: Text('Eliminar',
                  style: GoogleFonts.poppins(color: Colors.red))),
        ],
      ),
    );
  }

  IconData _iconFromString(String s) {
    switch (s) {
      case 'bank':
        return Icons.account_balance;
      case 'cash':
        return Icons.payments;
      case 'savings':
        return Icons.savings;
      case 'partner':
        return Icons.people;
      case 'marketing':
        return Icons.campaign;
      default:
        return Icons.account_balance_wallet;
    }
  }

  Color _colorFromHex(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', 'FF'), radix: 16));
    } catch (_) {
      return kPrimaryColor;
    }
  }
}

// ── Tarjeta de wallet ─────────────────────────────────────────────────────────
class _WalletCard extends StatelessWidget {
  final String walletId;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final double balance;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _WalletCard({
    required this.walletId,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.balance,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ]),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    if (description.isNotEmpty)
                      Text(description,
                          style: GoogleFonts.poppins(
                              fontSize: 11, color: Colors.grey[500])),
                  ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(
                '\$${balance.toStringAsFixed(2)}',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: balance >= 0 ? kPrimaryColor : kExpenseColor),
              ),
              Text('saldo disponible',
                  style: GoogleFonts.poppins(
                      fontSize: 10, color: Colors.grey[400])),
            ]),
          ]),
        ),
        // Barra de acciones
        Container(
          decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade100))),
          child: Row(children: [
            Expanded(
              child: InkWell(
                onTap: onEdit,
                borderRadius:
                    const BorderRadius.only(bottomLeft: Radius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.edit_outlined,
                            size: 14, color: Colors.blueGrey),
                        const SizedBox(width: 5),
                        Text('Editar',
                            style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: Colors.blueGrey,
                                fontWeight: FontWeight.w600)),
                      ]),
                ),
              ),
            ),
            Container(width: 1, height: 28, color: Colors.grey.shade100),
            Expanded(
              child: InkWell(
                onTap: onDelete,
                borderRadius:
                    const BorderRadius.only(bottomRight: Radius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.delete_outline,
                            size: 14, color: kExpenseColor),
                        const SizedBox(width: 5),
                        Text('Eliminar',
                            style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: kExpenseColor,
                                fontWeight: FontWeight.w600)),
                      ]),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ── Modal crear/editar wallet ─────────────────────────────────────────────────
class _WalletModal extends StatefulWidget {
  final String supplierId;
  final String? walletId;
  final Map<String, dynamic>? existing;

  const _WalletModal({required this.supplierId, this.walletId, this.existing});

  @override
  State<_WalletModal> createState() => _WalletModalState();
}

class _WalletModalState extends State<_WalletModal> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _icon = 'wallet';
  String _color = '#113049';
  bool _saving = false;

  static const _icons = [
    ('wallet', Icons.account_balance_wallet, 'Caja general'),
    ('bank', Icons.account_balance, 'Banco'),
    ('cash', Icons.payments, 'Efectivo'),
    ('savings', Icons.savings, 'Ahorro'),
    ('partner', Icons.people, 'Socio'),
    ('marketing', Icons.campaign, 'Marketing'),
  ];

  static const _colors = [
    '#113049',
    '#34C759',
    '#FF3B30',
    '#FF9500',
    '#007AFF',
    '#9B59B6',
    '#1ABC9C',
    '#E91E63',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _nameCtrl.text = widget.existing!['name'] ?? '';
      _descCtrl.text = widget.existing!['description'] ?? '';
      _icon = widget.existing!['icon'] ?? 'wallet';
      _color = widget.existing!['color'] ?? '#113049';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final Map<String, dynamic> data = {
      'supplierId': widget.supplierId,
      'name': _nameCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'icon': _icon,
      'color': _color,
    };
    try {
      if (widget.walletId != null) {
        await FirebaseFirestore.instance
            .collection('wallets')
            .doc(widget.walletId)
            .update(data);
      } else {
        data['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('wallets').add(data);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10))),
            ),
            const SizedBox(height: 18),
            Text(
              widget.walletId != null ? 'Editar caja' : 'Nueva caja / fondo',
              style: GoogleFonts.poppins(
                  color: kPrimaryColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: 'Nombre de la caja',
                hintText: 'Ej: Caja Chica, Banco Provincial...',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              decoration: InputDecoration(
                labelText: 'Descripción (opcional)',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 18),
            Text('Ícono',
                style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600])),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              children: _icons.map((entry) {
                final selected = _icon == entry.$1;
                return GestureDetector(
                  onTap: () => setState(() => _icon = entry.$1),
                  child: Tooltip(
                    message: entry.$3,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: selected ? kPrimaryColor : Colors.grey[100],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(entry.$2,
                          color: selected ? Colors.white : Colors.grey[600],
                          size: 22),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),
            Text('Color',
                style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600])),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              children: _colors.map((hex) {
                Color c;
                try {
                  c = Color(int.parse(hex.replaceFirst('#', 'FF'), radix: 16));
                } catch (_) {
                  c = kPrimaryColor;
                }
                final selected = _color == hex;
                return GestureDetector(
                  onTap: () => setState(() => _color = hex),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: selected
                          ? Border.all(color: Colors.white, width: 2)
                          : null,
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                  color: c.withValues(alpha: 0.5),
                                  blurRadius: 6,
                                  spreadRadius: 1)
                            ]
                          : null,
                    ),
                    child: selected
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                child: _saving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        widget.walletId != null ? 'Actualizar' : 'Crear caja',
                        style: GoogleFonts.poppins(
                            color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
