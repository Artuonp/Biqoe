import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'finance_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODAL UNIFICADO DE TRANSACCIÓN
// Permite registrar: Ingreso manual, Egreso, Movimiento interno
// ─────────────────────────────────────────────────────────────────────────────
class FinTransactionModal extends StatefulWidget {
  final String supplierId;
  final Map<String, dynamic>? txToEdit; // null = nuevo
  final String? preSelectedDestinationId;
  final String? initialType; // 'income' | 'expense' | 'internal'
  final VoidCallback onSaved;

  const FinTransactionModal({
    super.key,
    required this.supplierId,
    this.txToEdit,
    this.preSelectedDestinationId,
    this.initialType,
    required this.onSaved,
  });

  @override
  State<FinTransactionModal> createState() => _FinTransactionModalState();
}

class _FinTransactionModalState extends State<FinTransactionModal>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  late String _type; // 'income' | 'expense' | 'internal'
  String _category = 'Operativo';
  String _subcategory = '';
  DateTime _selectedDate = DateTime.now();
  String? _selectedDestinationId;
  String? _selectedWalletId;
  String? _toWalletId; // para movimiento interno
  bool _isSaving = false;

  // Categorías por tipo
  static const Map<String, List<String>> _categoriesByType = {
    'income': [
      'Reservas',
      'Propinas',
      'Patrocinios',
      'Mercancía',
      'Eventos',
      'Otros'
    ],
    'expense': [
      'Operativo',
      'Transporte',
      'Comida',
      'Marketing',
      'Nómina',
      'Mantenimiento',
      'Equipamiento (CAPEX)',
      'Servicios',
      'Otros'
    ],
    'internal': ['Transferencia'],
  };

  @override
  void initState() {
    super.initState();
    _type = widget.initialType ?? widget.txToEdit?['type'] ?? 'expense';
    _category = _categoriesByType[_type]!.first;

    if (widget.txToEdit != null) {
      final e = widget.txToEdit!;
      _descCtrl.text = e['descripcion']?.toString() ?? '';
      _amountCtrl.text = e['monto']?.toString() ?? '';
      _notesCtrl.text = e['notas']?.toString() ?? '';
      _type = e['type'] ?? 'expense';
      _category = e['categoria'] ?? _categoriesByType[_type]!.first;
      _subcategory = e['subcategoria'] ?? '';
      _selectedDate = parseFinanceDate(e['fecha']);
      _selectedDestinationId = e['destinationId'];
      _selectedWalletId = e['walletId'];
    } else if (widget.preSelectedDestinationId != null) {
      _selectedDestinationId = widget.preSelectedDestinationId;
    }
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final double amount = double.parse(_amountCtrl.text.replaceAll(',', '.'));

      final Map<String, dynamic> data = {
        'supplierId': widget.supplierId,
        'type': _type,
        'monto': amount,
        'descripcion': _descCtrl.text.trim(),
        'categoria': _category,
        'subcategoria': _subcategory,
        'estado': 'confirmed', // fijo — ya no se gestiona manualmente
        'notas': _notesCtrl.text.trim(),
        'fecha': Timestamp.fromDate(_selectedDate),
        'destinationId': _selectedDestinationId,
        'walletId': _selectedWalletId,
        'toWalletId': _type == 'internal' ? _toWalletId : null,
        'updatedAt': FieldValue.serverTimestamp(),
        'source': 'manual',
      };

      if (widget.txToEdit != null) {
        await FirebaseFirestore.instance
            .collection('ingresos_egresos')
            .doc(widget.txToEdit!['id'])
            .update(data);
      } else {
        data['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance
            .collection('ingresos_egresos')
            .add(data);
      }

      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('FinTransactionModal save error: $e');
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 30),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Barra de arrastre
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 18),

              // TÍTULO
              Text(
                widget.txToEdit != null
                    ? 'Editar transacción'
                    : 'Nueva transacción',
                style: GoogleFonts.poppins(
                    color: kPrimaryColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 18),

              // SELECTOR DE TIPO
              _buildTypeSelector(),
              const SizedBox(height: 18),

              // MONTO + FECHA
              Row(children: [
                Expanded(
                  flex: 5,
                  child: TextFormField(
                    controller: _amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold, fontSize: 18),
                    decoration: InputDecoration(
                      labelText: 'Monto',
                      prefixText: '\$ ',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Requerido' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: InkWell(
                    onTap: () async {
                      final d = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2020),
                          lastDate:
                              DateTime.now().add(const Duration(days: 30)));
                      if (d != null) setState(() => _selectedDate = d);
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Fecha',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        prefixIcon:
                            const Icon(Icons.calendar_today_outlined, size: 16),
                      ),
                      child: Text(DateFormat('dd/MM/yy').format(_selectedDate),
                          style: GoogleFonts.poppins(fontSize: 13)),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 14),

              // DESCRIPCIÓN
              TextFormField(
                controller: _descCtrl,
                decoration: InputDecoration(
                  labelText: 'Descripción',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.edit_note_outlined),
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 14),

              // CATEGORÍA (solo — se elimina el dropdown de Estado)
              _buildCategoryDropdown(),
              const SizedBox(height: 14),

              // ACTIVIDAD (si no es movimiento interno)
              if (_type != 'internal') ...[
                _buildActivityDropdown(),
                const SizedBox(height: 14),
              ],

              // WALLET
              _buildWalletDropdown(),
              const SizedBox(height: 14),

              // WALLET DESTINO (solo movimiento interno)
              if (_type == 'internal') ...[
                _buildToWalletDropdown(),
                const SizedBox(height: 14),
              ],

              // NOTAS
              TextFormField(
                controller: _notesCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Notas / justificación (opcional)',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.comment_outlined, size: 18),
                ),
              ),
              const SizedBox(height: 24),

              // BOTÓN GUARDAR
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _typeColor(),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13)),
                    elevation: 4,
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          widget.txToEdit != null
                              ? 'Actualizar'
                              : 'Guardar transacción',
                          style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Selector de tipo (Ingreso / Egreso / Interno) ───────────────────────────
  Widget _buildTypeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: Colors.grey[100], borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        _typeChip('income', Icons.arrow_downward, 'Ingreso', kIncomeColor),
        _typeChip('expense', Icons.arrow_upward, 'Egreso', kExpenseColor),
        _typeChip('internal', Icons.swap_horiz, 'Interno', kInternalColor),
      ]),
    );
  }

  Widget _typeChip(String type, IconData icon, String label, Color color) {
    final selected = _type == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _type = type;
          _category = _categoriesByType[type]!.first;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon,
                size: 14, color: selected ? Colors.white : Colors.grey[600]),
            const SizedBox(width: 5),
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : Colors.grey[600])),
          ]),
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    final cats = _categoriesByType[_type] ?? ['Otros'];
    if (!cats.contains(_category)) _category = cats.first;
    return DropdownButtonFormField<String>(
      initialValue: _category,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Categoría',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        prefixIcon: const Icon(Icons.category_outlined, size: 18),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      items: cats
          .map((c) => DropdownMenuItem(
              value: c, child: Text(c, overflow: TextOverflow.ellipsis)))
          .toList(),
      onChanged: (v) => setState(() => _category = v!),
    );
  }

  Widget _buildActivityDropdown() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('destinos')
          .where('supplierId', isEqualTo: widget.supplierId)
          .where('status', isEqualTo: 'active')
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const LinearProgressIndicator();
        final items = snap.data!.docs.map((doc) {
          final d = doc.data() as Map<String, dynamic>;
          return DropdownMenuItem<String>(
            value: doc.id,
            child: Text(d['nombre'] ?? 'Sin nombre',
                overflow: TextOverflow.ellipsis),
          );
        }).toList();

        items.insert(
            0,
            const DropdownMenuItem(
                value: null, child: Text('Sin actividad específica')));

        return DropdownButtonFormField<String?>(
          initialValue: items.any((i) => i.value == _selectedDestinationId)
              ? _selectedDestinationId
              : null,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Actividad',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            prefixIcon:
                const Icon(Icons.map_rounded, color: kPrimaryColor, size: 18),
          ),
          items: items,
          onChanged: (v) => setState(() => _selectedDestinationId = v),
        );
      },
    );
  }

  Widget _buildWalletDropdown() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('wallets')
          .where('supplierId', isEqualTo: widget.supplierId)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const SizedBox();
        }
        final items = snap.data!.docs.map((doc) {
          final d = doc.data() as Map<String, dynamic>;
          return DropdownMenuItem<String>(
              value: doc.id,
              child:
                  Text(d['name'] ?? 'Caja', overflow: TextOverflow.ellipsis));
        }).toList();
        items.insert(
            0,
            const DropdownMenuItem(
                value: null, child: Text('Caja / Fondo (opcional)')));

        return DropdownButtonFormField<String?>(
          initialValue: items.any((i) => i.value == _selectedWalletId)
              ? _selectedWalletId
              : null,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: _type == 'internal' ? 'Caja origen' : 'Caja / Fondo',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            prefixIcon:
                const Icon(Icons.account_balance_wallet_outlined, size: 18),
          ),
          items: items,
          onChanged: (v) => setState(() => _selectedWalletId = v),
        );
      },
    );
  }

  Widget _buildToWalletDropdown() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('wallets')
          .where('supplierId', isEqualTo: widget.supplierId)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const SizedBox();
        }
        final items = snap.data!.docs
            .where((doc) => doc.id != _selectedWalletId)
            .map((doc) {
          final d = doc.data() as Map<String, dynamic>;
          return DropdownMenuItem<String>(
              value: doc.id,
              child:
                  Text(d['name'] ?? 'Caja', overflow: TextOverflow.ellipsis));
        }).toList();

        return DropdownButtonFormField<String?>(
          initialValue:
              items.any((i) => i.value == _toWalletId) ? _toWalletId : null,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Caja destino',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            prefixIcon: const Icon(Icons.call_made_outlined,
                size: 18, color: kInternalColor),
          ),
          items: items,
          onChanged: (v) => setState(() => _toWalletId = v),
        );
      },
    );
  }

  Color _typeColor() {
    switch (_type) {
      case 'income':
        return kIncomeColor;
      case 'internal':
        return kInternalColor;
      default:
        return kExpenseColor;
    }
  }
}
