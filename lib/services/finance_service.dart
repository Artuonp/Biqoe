import 'package:cloud_firestore/cloud_firestore.dart';

class FinanceService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Obtiene el resumen financiero completo para un rango de fechas
  Future<Map<String, dynamic>> getFinancialSummary({
    required String supplierId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    double totalIncome = 0.0;
    double totalExpenses = 0.0;
    double totalReceivable = 0.0; // Por cobrar

    List<Map<String, dynamic>> transactions = []; // Libro diario unificado
    List<Map<String, dynamic>> expensesList = [];

    // 1. OBTENER INGRESOS (Reservas)
    // Nota: Usamos collectionGroup para buscar en todas las reservas de este supplier
    // Idealmente deberías tener un índice compuesto para esto.
    final bookingsQuery = await _db
        .collectionGroup('reservas')
        .where('supplier', isEqualTo: supplierId)
        .where('createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .get();

    for (var doc in bookingsQuery.docs) {
      final data = doc.data();
      final double paid = (data['amountPaid'] ?? 0).toDouble();
      final double total = (data['totalPlanPrice'] ?? 0).toDouble();
      final String status = data['estado'] ?? 'pendiente';

      // Calcular Ingreso Real (Solo lo verificado cuenta para Cash Flow)
      if (status == 'verificado' || paid > 0) {
        totalIncome += paid;

        // Agregar al Libro Diario (Ingreso = Verde)
        transactions.add({
          'type': 'income',
          'amount': paid,
          'date': (data['createdAt'] as Timestamp).toDate(),
          'description': 'Reserva: ${data['planName']}',
          'category': 'Venta',
          'client': data['name'],
          'ref': data['code'] ?? doc.id,
        });
      }

      // Calcular Cuentas por Cobrar (Deuda)
      double debt = total - paid;
      if (debt > 1.0) {
        totalReceivable += debt;
      }
    }

    // 2. OBTENER EGRESOS (Gastos)
    // Asumimos que crearemos una colección 'gastos' a nivel raíz o dentro del usuario
    final expensesQuery = await _db
        .collection('gastos')
        .where('supplierId', isEqualTo: supplierId)
        .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('fecha', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .get();

    for (var doc in expensesQuery.docs) {
      final data = doc.data();
      final double amount = (data['monto'] ?? 0).toDouble();

      totalExpenses += amount;

      // Agregar a lista de gastos específica
      expensesList.add({
        'id': doc.id,
        ...data,
      });

      // Agregar al Libro Diario (Gasto = Rojo)
      transactions.add({
        'type': 'expense',
        'amount': amount,
        'date': (data['fecha'] as Timestamp).toDate(),
        'description': data['descripcion'] ?? 'Gasto operativo',
        'category': data['categoria'] ?? 'General',
        'ref': 'GASTO',
      });
    }

    // 3. ORDENAR CRONOLÓGICAMENTE (Más reciente primero)
    transactions.sort((a, b) => b['date'].compareTo(a['date']));

    // 4. RETORNAR PAQUETE DE DATOS
    return {
      'income': totalIncome,
      'expenses': totalExpenses,
      'netProfit': totalIncome - totalExpenses,
      'margin': totalIncome == 0
          ? 0.0
          : ((totalIncome - totalExpenses) / totalIncome) * 100,
      'receivable': totalReceivable,
      'transactions': transactions,
      'expensesList': expensesList,
    };
  }

  /// Registrar un nuevo gasto
  Future<void> addExpense({
    required String supplierId,
    required double amount,
    required String description,
    required String category,
    required DateTime date,
    String? destinationId, // Opcional: Si es de un viaje específico
  }) async {
    await _db.collection('gastos').add({
      'supplierId': supplierId,
      'monto': amount,
      'descripcion': description,
      'categoria': category,
      'fecha': Timestamp.fromDate(date),
      'destinationId': destinationId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
