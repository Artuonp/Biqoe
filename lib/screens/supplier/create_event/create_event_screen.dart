import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'steps/step_1_basic_info.dart';
import 'steps/step_2_multimedia.dart';
import 'steps/step_3_location.dart';
import 'steps/step_4_inventory.dart';
import 'steps/step_5_policies.dart';
import 'steps/step_6_review.dart';

class CreateEventScreen extends StatefulWidget {
  final Map<String, dynamic>? eventToEdit;
  final String? eventId;
  final String? supplierId; // <--- AGREGAR ESTO

  const CreateEventScreen({
    super.key,
    this.eventToEdit,
    this.eventId,
    this.supplierId, // <--- EN CONSTRUCTOR
  });

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  final int _totalSteps = 6;
  bool _isUploadingToFirebase = false;

  // Usamos 'late' para inicializarlo en el initState según el modo (Crear o Editar)
  late Map<String, dynamic> _formData;

  @override
  void initState() {
    super.initState();
    // LÓGICA DE INICIALIZACIÓN
    if (widget.eventToEdit != null) {
      // MODO EDICIÓN: Cargamos los datos existentes
      // Usamos Map.from para asegurar que sea mutable
      _formData = Map<String, dynamic>.from(widget.eventToEdit!);
    } else {
      // MODO CREAR: Iniciamos vacío
      _formData = {
        'nombre': '',
        'categorias': <String>[],
        'imagenes': <String>[],
        'estado': null,
        'lugar': '',
        'googleMapsLink': '',
        'paquetes': <Map<String, dynamic>>[],
        'preguntas': <Map<String, dynamic>>[],
        'metodosPago': <Map<String, dynamic>>[],
      };
    }
  }

  void _nextPage(Map<String, dynamic> stepData) {
    setState(() {
      _formData.addAll(stepData);
    });

    if (_currentStep < _totalSteps - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep++);
    }
  }

  void _previousPage() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep--);
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _submitToFirestore() async {
    setState(() => _isUploadingToFirebase = true);

    try {
      // 1. DETERMINAR ID DEL PROVEEDOR
      // Si nos pasaron un ID (desde el dashboard), usamos ese.
      // Si no, usamos el del usuario logueado (fallback).
      String targetId =
          widget.supplierId ?? FirebaseAuth.instance.currentUser?.uid ?? '';

      if (targetId.isEmpty) throw Exception("No se identificó al proveedor");

      // 1. Preparar la data común
      final eventData = {
        ..._formData,
        'supplierId': targetId, // <--- USAR targetId AQUÍ
        'updatedAt': FieldValue.serverTimestamp(),
        'searchKeywords': _generateKeywords(_formData['nombre']),
      };

      // 2. Decidir si CREAR o ACTUALIZAR
      if (widget.eventId != null) {
        // --- MODO EDICIÓN ---
        await FirebaseFirestore.instance
            .collection('destinos')
            .doc(widget.eventId)
            .update(eventData);
      } else {
        // --- MODO CREACIÓN ---
        // Agregamos campos que solo se ponen al crear
        eventData['createdAt'] = FieldValue.serverTimestamp();
        eventData['status'] = 'active';
        eventData['rating'] = 0.0;
        eventData['reviewsCount'] = 0;

        await FirebaseFirestore.instance.collection('destinos').add(eventData);
      }

      if (!mounted) return;

      // 3. DIALOGO DE ÉXITO (BLANCO)
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Theme(
          // Forzamos el tema blanco para este diálogo
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              surface: Colors.white,
              primary: Color.fromRGBO(17, 48, 73, 1),
            ),
            dialogTheme: DialogThemeData(backgroundColor: Colors.white),
          ),
          child: AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white, // Importante para Material 3
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Column(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 60),
                const SizedBox(height: 10),
                Text(
                  widget.eventId != null ? "¡Actualizado!" : "¡Publicado!",
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: Text(
              widget.eventId != null
                  ? "Los cambios en tu experiencia se han guardado correctamente."
                  : "Tu experiencia ha sido creada exitosamente y ya está visible para los usuarios.",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Cerrar dialogo
                  Navigator.pop(
                      context); // Cerrar pantalla (volver a lista/dashboard)
                },
                child: const Text(
                  "Volver",
                  style: TextStyle(
                    color: Color.fromRGBO(17, 48, 73, 1),
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            ],
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text("Error al guardar: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isUploadingToFirebase = false);
    }
  }

  List<String> _generateKeywords(String title) {
    List<String> keywords = [];
    String temp = "";
    for (int i = 0; i < title.length; i++) {
      temp = temp + title[i].toLowerCase();
      keywords.add(temp);
    }
    return keywords;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: _previousPage,
        ),
        title: Text(
          // Título dinámico según el paso y el modo
          _currentStep == _totalSteps - 1
              ? 'Confirmar'
              : (widget.eventId != null
                  ? 'Editar actividad'
                  : 'Crear actividad'),
          style: GoogleFonts.poppins(
              color: const Color.fromRGBO(17, 48, 73, 1),
              fontWeight: FontWeight.bold,
              fontSize: 16),
        ),
        centerTitle: true,
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 20),
              child: Text(
                "Paso ${_currentStep + 1}/$_totalSteps",
                style: GoogleFonts.poppins(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                    fontSize: 12),
              ),
            ),
          )
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4.0),
          child: LinearProgressIndicator(
            value: (_currentStep + 1) / _totalSteps,
            backgroundColor: Colors.grey[200],
            valueColor: const AlwaysStoppedAnimation<Color>(
                Color.fromRGBO(17, 48, 73, 1)),
          ),
        ),
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          Step1BasicInfo(initialData: _formData, onNext: _nextPage),
          Step2Multimedia(initialData: _formData, onNext: _nextPage),
          Step3Location(initialData: _formData, onNext: _nextPage),
          Step4Inventory(initialData: _formData, onNext: _nextPage),
          Step5Policies(initialData: _formData, onNext: _nextPage),
          Step6Review(
            formData: _formData,
            onSubmit: _submitToFirestore,
            isSubmitting: _isUploadingToFirebase,
          ),
        ],
      ),
    );
  }
}
