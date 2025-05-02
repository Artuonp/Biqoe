import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class ChangeNameScreen extends StatefulWidget {
  final String userId;

  const ChangeNameScreen({super.key, required this.userId});

  @override
  ChangeNameScreenState createState() => ChangeNameScreenState();
}

class ChangeNameScreenState extends State<ChangeNameScreen> {
  final TextEditingController _nameController = TextEditingController();
  String _currentName = '';
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentName();
  }

  Future<void> _loadCurrentName() async {
    final docSnapshot = await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(widget.userId)
        .get();

    if (docSnapshot.exists) {
      setState(() {
        _currentName = docSnapshot.data()?['name'] ?? '';
      });
    }
  }

  Future<void> _updateName() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) {
      _showErrorDialog('El nombre no puede estar vacío.');
      return;
    }
    if (newName.length > 30) {
      _showErrorDialog('El nombre es demasiado largo. Máximo 30 caracteres.');
      return;
    }

    setState(() => _isUpdating = true);

    await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(widget.userId)
        .update({'name': newName});

    if (mounted) {
      setState(() => _isUpdating = false);
      Navigator.pop(context);
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Text(
            'Error',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: const Color.fromRGBO(17, 48, 73, 1),
            ),
          ),
          content: Text(
            message,
            style: GoogleFonts.poppins(),
          ),
          actions: [
            TextButton(
              child: Text(
                'ENTENDIDO',
                style: GoogleFonts.poppins(
                  color: const Color.fromRGBO(17, 48, 73, 1),
                  fontWeight: FontWeight.w500,
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    const primaryColor = Color.fromRGBO(17, 48, 73, 1);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 243, 247, 254),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: primaryColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: const Color.fromARGB(255, 243, 247, 254),
      body: SingleChildScrollView(
        padding:
            EdgeInsets.symmetric(horizontal: size.width * 0.08, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCurrentNameCard(),
            SizedBox(height: size.height * 0.04),
            _buildNameInputField(),
            SizedBox(height: size.height * 0.05),
            _buildUpdateButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentNameCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: const Color.fromARGB(30, 128, 128, 128),
            spreadRadius: 3,
            blurRadius: 7,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nombre actual:',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: const Color.fromRGBO(17, 48, 73, 1),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _currentName,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: const Color.fromRGBO(17, 48, 73, 1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameInputField() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: const Color.fromARGB(30, 128, 128, 128),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nuevo nombre:',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: const Color.fromRGBO(17, 48, 73, 1),
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _nameController,
            style: GoogleFonts.poppins(fontSize: 16),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: 'Ingresa tu nuevo nombre',
              hintStyle: GoogleFonts.poppins(
                color: Colors.grey.shade400,
              ),
              counterStyle: GoogleFonts.poppins(
                color: Colors.grey.shade400,
              ),
            ),
            maxLength: 30,
          ),
        ],
      ),
    );
  }

  Widget _buildUpdateButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isUpdating ? null : _updateName,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color.fromRGBO(17, 48, 73, 1),
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isUpdating
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                'Actualizar nombre',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}
