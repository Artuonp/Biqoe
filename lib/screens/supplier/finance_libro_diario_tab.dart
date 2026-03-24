import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'finance_widgets.dart';
import 'finance_transaction_modal.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PESTAÑA: LIBRO DIARIO
// Lista unificada de ingresos manuales + egresos.
// Filtros: tipo, estado, categoría, búsqueda.
// ─────────────────────────────────────────────────────────────────────────────
class FinanceLibroDiarioTab extends StatefulWidget {
  final String supplierId;
  const FinanceLibroDiarioTab({super.key, required this.supplierId});

  @override
  State<FinanceLibroDiarioTab> createState() => _FinanceLibroDiarioTabState();
}

class _FinanceLibroDiarioTabState extends State<FinanceLibroDiarioTab> {
  String _filterType = 'all'; // 'all' | 'income' | 'expense' | 'internal'
  String _filterStatus = 'all'; // 'all' | 'verified' | 'pending' | 'internal'
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openModal({Map<String, dynamic>? tx, String? type}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FinTransactionModal(
        supplierId: widget.supplierId,
        txToEdit: tx,
        initialType: type,
        onSaved: () {},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // ── FABs de acción rápida ─────────────────────────────────────────────
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(children: [
          Expanded(
            child: _ActionBtn(
              label: 'Agregar ingreso',
              icon: Icons.add_circle,
              color: kIncomeColor,
              onTap: () => _openModal(type: 'income'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ActionBtn(
              label: 'Registrar egreso',
              icon: Icons.remove_circle,
              color: kExpenseColor,
              onTap: () => _openModal(type: 'expense'),
            ),
          ),
          const SizedBox(width: 10),
          _SmallActionBtn(
            icon: Icons.swap_horiz,
            color: kInternalColor,
            onTap: () => _openModal(type: 'internal'),
            tooltip: 'Movimiento interno',
          ),
        ]),
      ),

      // ── Buscador ──────────────────────────────────────────────────────────
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: TextField(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
          decoration: InputDecoration(
            hintText: 'Buscar transacción...',
            hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey),
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _searchQuery = '');
                    })
                : null,
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200)),
          ),
        ),
      ),

      // ── Filtros de tipo y estado ──────────────────────────────────────────
      _buildFilterChips(),

      // ── Lista de transacciones ───────────────────────────────────────────
      Expanded(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('ingresos_egresos')
              .where('supplierId', isEqualTo: widget.supplierId)
              .orderBy('fecha', descending: true)
              .snapshots(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snap.hasData || snap.data!.docs.isEmpty) {
              return _EmptyState(
                onAdd: () => _openModal(type: 'income'),
              );
            }

            var docs = snap.data!.docs;

            // Aplicar filtros
            final filtered = docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final type = data['type'] ?? 'expense';
              final status = data['estado'] ?? 'pending';
              final desc = (data['descripcion'] ?? '').toString().toLowerCase();
              final cat = (data['categoria'] ?? '').toString().toLowerCase();

              if (_filterType != 'all' && type != _filterType) return false;
              if (_filterStatus != 'all' && status != _filterStatus) {
                return false;
              }
              if (_searchQuery.isNotEmpty &&
                  !desc.contains(_searchQuery) &&
                  !cat.contains(_searchQuery)) {
                return false;
              }
              return true;
            }).toList();

            if (filtered.isEmpty) {
              return Center(
                child: Text('Sin resultados para los filtros aplicados',
                    style: GoogleFonts.poppins(color: Colors.grey)),
              );
            }

            // Totales del filtro actual
            double totalIncome = 0, totalExpense = 0;
            for (var doc in filtered) {
              final data = doc.data() as Map<String, dynamic>;
              final amt = (data['monto'] ?? 0).toDouble();
              if ((data['type'] ?? '') == 'income') {
                totalIncome += amt;
              } else if ((data['type'] ?? '') == 'expense') {
                totalExpense += amt;
              }
            }

            return Column(children: [
              // Mini totales
              Container(
                margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade100)),
                child: Row(children: [
                  Expanded(
                      child: _TotalMini(
                          label: 'Ingresos registrados',
                          value: '\$${totalIncome.toStringAsFixed(2)}',
                          color: kIncomeColor)),
                  Container(width: 1, height: 30, color: Colors.grey[200]),
                  Expanded(
                      child: _TotalMini(
                          label: 'Egresos registrados',
                          value: '\$${totalExpense.toStringAsFixed(2)}',
                          color: kExpenseColor)),
                  Container(width: 1, height: 30, color: Colors.grey[200]),
                  Expanded(
                      child: _TotalMini(
                          label: 'Neto',
                          value:
                              '\$${(totalIncome - totalExpense).toStringAsFixed(2)}',
                          color: (totalIncome - totalExpense) >= 0
                              ? kIncomeColor
                              : kExpenseColor,
                          bold: true)),
                ]),
              ),

              // Lista
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final doc = filtered[index];
                    final data = doc.data() as Map<String, dynamic>;
                    data['id'] = doc.id;
                    return _TransactionCard(
                      data: data,
                      onEdit: () => _openModal(tx: data),
                      onDelete: () => _confirmDelete(context, doc.id),
                      onStatusChange: (s) => _updateStatus(doc.id, s),
                    );
                  },
                ),
              ),
            ]);
          },
        ),
      ),
    ]);
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Row(children: [
        // Tipo
        _FilterChip(
            label: 'Todos',
            selected: _filterType == 'all',
            onTap: () => setState(() => _filterType = 'all'),
            color: kPrimaryColor),
        const SizedBox(width: 6),
        _FilterChip(
            label: 'Ingresos',
            selected: _filterType == 'income',
            onTap: () => setState(() => _filterType = 'income'),
            color: kIncomeColor),
        const SizedBox(width: 6),
        _FilterChip(
            label: 'Egresos',
            selected: _filterType == 'expense',
            onTap: () => setState(() => _filterType = 'expense'),
            color: kExpenseColor),
        const SizedBox(width: 6),
        _FilterChip(
            label: 'Internos',
            selected: _filterType == 'internal',
            onTap: () => setState(() => _filterType = 'internal'),
            color: kInternalColor),
        const SizedBox(width: 14),
        Container(width: 1, height: 20, color: Colors.grey[300]),
        const SizedBox(width: 14),
        // Estado
        _FilterChip(
            label: 'Verificados',
            selected: _filterStatus == 'verified',
            onTap: () => setState(() => _filterStatus =
                _filterStatus == 'verified' ? 'all' : 'verified'),
            color: kIncomeColor),
        const SizedBox(width: 6),
        _FilterChip(
            label: 'Pendientes',
            selected: _filterStatus == 'pending',
            onTap: () => setState(() =>
                _filterStatus = _filterStatus == 'pending' ? 'all' : 'pending'),
            color: kPendingColor),
      ]),
    );
  }

  Future<void> _updateStatus(String docId, TxStatus status) async {
    await FirebaseFirestore.instance
        .collection('ingresos_egresos')
        .doc(docId)
        .update({'estado': status.name});
  }

  void _confirmDelete(BuildContext context, String docId) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('¿Eliminar transacción?',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content:
            Text('Esta acción es permanente.', style: GoogleFonts.poppins()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c),
              child: Text('Cancelar',
                  style: GoogleFonts.poppins(color: Colors.grey))),
          TextButton(
              onPressed: () {
                FirebaseFirestore.instance
                    .collection('ingresos_egresos')
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
}

// ── Tarjeta de transacción ────────────────────────────────────────────────────
class _TransactionCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<TxStatus> onStatusChange;

  const _TransactionCard({
    required this.data,
    required this.onEdit,
    required this.onDelete,
    required this.onStatusChange,
  });

  @override
  Widget build(BuildContext context) {
    final type = data['type'] ?? 'expense';
    final status = TxStatusExt.fromString(data['estado']);
    final amount = (data['monto'] ?? 0).toDouble();
    final desc = data['descripcion'] ?? 'Transacción';
    final cat = data['categoria'] ?? '';
    final date = parseFinanceDate(data['fecha']);
    final notas = data['notas']?.toString() ?? '';

    final Color typeColor = type == 'income'
        ? kIncomeColor
        : type == 'internal'
            ? kInternalColor
            : kExpenseColor;

    return GestureDetector(
      onLongPress: onEdit,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border(left: BorderSide(color: typeColor, width: 3.5)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 3))
          ],
        ),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              // Ícono tipo
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle),
                child: Icon(
                  type == 'income'
                      ? Icons.arrow_downward
                      : type == 'internal'
                          ? Icons.swap_horiz
                          : Icons.arrow_upward,
                  color: typeColor,
                  size: 17,
                ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(desc,
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 2),
                      Text(
                        '${DateFormat('dd MMM yy').format(date)}${cat.isNotEmpty ? ' · $cat' : ''}',
                        style: GoogleFonts.poppins(
                            fontSize: 11, color: Colors.grey[500]),
                      ),
                    ]),
              ),
              // Monto + estado
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(
                  '${type == 'income' ? '+' : type == 'internal' ? '~' : '-'}\$${amount.toStringAsFixed(2)}',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: typeColor),
                ),
                const SizedBox(height: 4),
                TxStatusBadge(status: status),
              ]),
            ]),
          ),

          // Notas si existen
          if (notas.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(14)),
              ),
              child: Text(notas,
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: Colors.grey[500])),
            ),

          // Acciones rápidas
          _buildActions(context, status),
        ]),
      ),
    );
  }

  Widget _buildActions(BuildContext context, TxStatus status) {
    return Container(
      decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.grey.shade100))),
      child: Row(children: [
        // Cambiar estado
        if (status != TxStatus.verified)
          Expanded(
            child: InkWell(
              onTap: () => onStatusChange(TxStatus.verified),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child:
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.check_circle_outline,
                      size: 15, color: kIncomeColor),
                  const SizedBox(width: 5),
                  Text('Verificar',
                      style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: kIncomeColor,
                          fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ),
        if (status != TxStatus.verified)
          Container(width: 1, height: 30, color: Colors.grey.shade100),

        // Editar
        Expanded(
          child: InkWell(
            onTap: onEdit,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.edit_outlined,
                    size: 15, color: Colors.blueGrey),
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
        Container(width: 1, height: 30, color: Colors.grey.shade100),

        // Eliminar
        Expanded(
          child: InkWell(
            onTap: onDelete,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.delete_outline,
                    size: 15, color: kExpenseColor),
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
    );
  }
}

// ── Widgets auxiliares ─────────────────────────────────────────────────────────
class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn(
      {required this.label,
      required this.icon,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(12)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: Colors.white, size: 17),
          const SizedBox(width: 6),
          Text(label,
              style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12)),
        ]),
      ),
    );
  }
}

class _SmallActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String tooltip;

  const _SmallActionBtn(
      {required this.icon,
      required this.color,
      required this.onTap,
      required this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.3))),
          child: Icon(icon, color: color, size: 22),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  const _FilterChip(
      {required this.label,
      required this.selected,
      required this.onTap,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : Colors.grey.shade200),
        ),
        child: Text(label,
            style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : Colors.grey[600])),
      ),
    );
  }
}

class _TotalMini extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool bold;

  const _TotalMini(
      {required this.label,
      required this.value,
      required this.color,
      this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value,
          style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
              color: color)),
      Text(label,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(fontSize: 9, color: Colors.grey)),
    ]);
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[300]),
        const SizedBox(height: 14),
        Text('Sin transacciones registradas',
            style: GoogleFonts.poppins(
                color: Colors.grey, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Text('Registra ingresos o egresos manualmente',
            style: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 12)),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add, color: Colors.white),
          label: Text('Agregar primera transacción',
              style: GoogleFonts.poppins(color: Colors.white)),
          style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12))),
        ),
      ]),
    );
  }
}
