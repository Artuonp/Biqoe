import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

// Colores consistentes con Biqoe
const Color kPrimaryColor = Color.fromRGBO(17, 48, 73, 1);
const Color kBackgroundColor = Color(0xFFF3F7FE);

class TasaScreen extends StatefulWidget {
  const TasaScreen({super.key});

  @override
  TasaScreenState createState() => TasaScreenState();
}

class TasaScreenState extends State<TasaScreen> {
  // Controladores para la Tasa Actual (Hoy)
  final TextEditingController _usdActualCtrl = TextEditingController();
  final TextEditingController _eurActualCtrl = TextEditingController();

  // Controladores para la Tasa Nueva (Programada para la medianoche)
  final TextEditingController _usdNuevoCtrl = TextEditingController();
  final TextEditingController _eurNuevoCtrl = TextEditingController();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = true;
  String _ultimaActualizacionStr = "---";
  String _fechaActivacionStr = "---";
  bool _cambioYaOcurrio = false;

  @override
  void initState() {
    super.initState();
    _loadTasa();
  }

  /// Carga los datos desde config/tasa en Firestore
  Future<void> _loadTasa() async {
    setState(() => _isLoading = true);
    try {
      DocumentSnapshot snapshot =
          await _firestore.collection('config').doc('tasa').get();

      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;

        // Carga dual de valores (si no existen, busca el fallback viejo)
        double usdAct = (data['usd_actual'] ?? data['valor'] ?? 0.0).toDouble();
        double eurAct = (data['eur_actual'] ?? data['eur'] ?? 0.0).toDouble();

        double usdNue = (data['usd_nuevo'] ?? 0.0).toDouble();
        double eurNue = (data['eur_nuevo'] ?? 0.0).toDouble();

        _usdActualCtrl.text = usdAct.toStringAsFixed(2);
        _eurActualCtrl.text = eurAct.toStringAsFixed(2);
        _usdNuevoCtrl.text = usdNue.toStringAsFixed(2);
        _eurNuevoCtrl.text = eurNue.toStringAsFixed(2);

        // Formatear fecha de ejecución del script
        if (data['ultima_actualizacion'] != null) {
          DateTime updateDate =
              (data['ultima_actualizacion'] as Timestamp).toDate();
          _ultimaActualizacionStr =
              DateFormat('dd/MM/yyyy - hh:mm a').format(updateDate);
        }

        // Determinar estado de la activación
        if (data['fecha_activacion'] != null) {
          DateTime actDate = (data['fecha_activacion'] as Timestamp).toDate();
          _fechaActivacionStr =
              DateFormat('dd/MM/yyyy - hh:mm a').format(actDate);

          _cambioYaOcurrio = DateTime.now().isAfter(actDate);
        } else {
          _fechaActivacionStr = "No definida";
        }
      }
    } catch (e) {
      debugPrint("Error cargando tasa: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Guarda los cambios manualmente
  Future<void> _saveTasaManual() async {
    double? usdAct = double.tryParse(_usdActualCtrl.text.replaceAll(',', '.'));
    double? eurAct = double.tryParse(_eurActualCtrl.text.replaceAll(',', '.'));
    double? usdNue = double.tryParse(_usdNuevoCtrl.text.replaceAll(',', '.'));
    double? eurNue = double.tryParse(_eurNuevoCtrl.text.replaceAll(',', '.'));

    if (usdAct == null || eurAct == null || usdNue == null || eurNue == null) {
      _showSnackBar(
          "Por favor, rellene los 4 campos con números válidos.", Colors.red);
      return;
    }

    try {
      DateTime ahora = DateTime.now();
      // Calculamos la medianoche del día siguiente
      DateTime proximaMedianoche =
          DateTime(ahora.year, ahora.month, ahora.day + 1);

      await _firestore.collection('config').doc('tasa').set({
        // Sistema Nuevo Dual
        'usd_actual': usdAct,
        'eur_actual': eurAct,
        'usd_nuevo': usdNue,
        'eur_nuevo': eurNue,
        'fecha_activacion': Timestamp.fromDate(
            proximaMedianoche), // Fija a las 12:00 AM exactas
        'ultima_actualizacion': FieldValue.serverTimestamp(),

        // Compatibilidad hacia atrás (por si hay pantallas viejas)
        'valor': usdAct,
        'eur': eurAct,
      }, SetOptions(merge: true));

      _showSnackBar("Sistema Dual actualizado. La tasa cambiará a las 12:00 AM",
          Colors.green);
      _loadTasa();
    } catch (e) {
      _showSnackBar("Error al guardar: $e", Colors.red);
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.poppins()),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: Text("Panel de Tasas (Admin)",
            style: GoogleFonts.poppins(
                color: kPrimaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kPrimaryColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- SECCIÓN INFORMATIVA ---
                  _buildStatusCard(),
                  const SizedBox(height: 25),

                  // ==========================================
                  // BLOQUE 1: TASAS ACTUALES (HOY)
                  // ==========================================
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.today, color: Colors.grey),
                            const SizedBox(width: 8),
                            Text("Tasa Activa (Antes de 12:00 AM)",
                                style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[800])),
                          ],
                        ),
                        const SizedBox(height: 15),
                        _buildRateField(
                          controller: _usdActualCtrl,
                          label: "Dólar BCV (USD)",
                          icon: Icons.attach_money,
                          color: Colors.green,
                        ),
                        const SizedBox(height: 15),
                        _buildRateField(
                          controller: _eurActualCtrl,
                          label: "Euro BCV (EUR)",
                          icon: Icons.euro,
                          color: Colors.blue,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ==========================================
                  // BLOQUE 2: TASAS PROGRAMADAS (MAÑANA)
                  // ==========================================
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: kPrimaryColor.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: kPrimaryColor.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.schedule, color: kPrimaryColor),
                            const SizedBox(width: 8),
                            Text("Tasa Programada (12:00 AM)",
                                style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: kPrimaryColor)),
                          ],
                        ),
                        const SizedBox(height: 15),
                        _buildRateField(
                          controller: _usdNuevoCtrl,
                          label: "Dólar BCV Mañana (USD)",
                          icon: Icons.attach_money,
                          color: Colors.green,
                        ),
                        const SizedBox(height: 15),
                        _buildRateField(
                          controller: _eurNuevoCtrl,
                          label: "Euro BCV Mañana (EUR)",
                          icon: Icons.euro,
                          color: Colors.blue,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // --- BOTÓN GUARDAR ---
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryColor,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15)),
                        elevation: 4,
                      ),
                      onPressed: _saveTasaManual,
                      child: Text("Guardar Sistema Dual",
                          style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                    ),
                  ),

                  const SizedBox(height: 20),
                  Center(
                    child: TextButton.icon(
                      onPressed: _loadTasa,
                      icon: const Icon(Icons.refresh, size: 18),
                      label:
                          Text("Refrescar datos", style: GoogleFonts.poppins()),
                    ),
                  )
                ],
              ),
            ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: kPrimaryColor.withValues(
            alpha: (0.05),
          ))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.settings_suggest, color: Colors.amber, size: 20),
              const SizedBox(width: 8),
              Text("Estatus del Robot",
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const Divider(height: 20),
          _statusRow(Icons.history, "Robot corrió:", _ultimaActualizacionStr),
          const SizedBox(height: 12),
          _statusRow(Icons.alarm_on, "Activación:", _fechaActivacionStr),
          const SizedBox(height: 12),

          // Etiqueta de estado del cambio
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
                color: _cambioYaOcurrio
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                    _cambioYaOcurrio
                        ? Icons.check_circle
                        : Icons.pending_actions,
                    size: 14,
                    color:
                        _cambioYaOcurrio ? Colors.green : Colors.orange[800]),
                const SizedBox(width: 6),
                Text(
                    _cambioYaOcurrio
                        ? "La tasa de mañana ya está activa"
                        : "Esperando a la medianoche",
                    style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _cambioYaOcurrio
                            ? Colors.green[800]
                            : Colors.orange[800]))
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _statusRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Text(label,
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
        const Spacer(),
        Text(value,
            style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: kPrimaryColor)),
      ],
    );
  }

  Widget _buildRateField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey),
          prefixIcon: Icon(icon, color: color),
          suffixText: "Bs.",
          suffixStyle: GoogleFonts.poppins(
              fontWeight: FontWeight.bold, color: Colors.grey),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}
