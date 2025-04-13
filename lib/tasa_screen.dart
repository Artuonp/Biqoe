import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TasaScreen extends StatefulWidget {
  const TasaScreen({super.key});

  @override
  TasaScreenState createState() => TasaScreenState();
}

class TasaScreenState extends State<TasaScreen> {
  final TextEditingController _tasaController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadTasa();
  }

  Future<void> _loadTasa() async {
    DocumentSnapshot snapshot =
        await _firestore.collection('config').doc('tasa').get();
    if (snapshot.exists) {
      double tasa = snapshot.get('valor');
      _tasaController.text = tasa.toStringAsFixed(2);
    }
  }

  Future<void> _saveTasa() async {
    double? nuevaTasa = double.tryParse(_tasaController.text);
    if (nuevaTasa != null) {
      await _firestore
          .collection('config')
          .doc('tasa')
          .set({'valor': nuevaTasa});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tasa actualizada correctamente')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingrese un valor válido')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          backgroundColor: const Color.fromARGB(255, 243, 248, 255),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextFormField(
                controller: _tasaController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Tasa de Cambio (Bs/\$)',
                  labelStyle: TextStyle(
                      fontFamily: 'Poppins',
                      color: Color.fromRGBO(17, 48, 73, 1),
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _saveTasa,
                child: const Text('Guardar Tasa',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.bold,
                        color: Color.fromRGBO(17, 48, 73, 1))),
              ),
            ],
          ),
        ),
        backgroundColor: const Color.fromARGB(255, 243, 248, 255));
  }
}
