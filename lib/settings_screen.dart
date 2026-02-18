import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:google_fonts/google_fonts.dart';

// No necesitamos importar el servicio aquí, lo usará el Dashboard
// import '../../services/supplier_service.dart';

class SettingsScreen extends StatefulWidget {
  final String userId;
  final List<Map<String, dynamic>> savedDestinations;

  const SettingsScreen({
    super.key,
    required this.userId,
    required this.savedDestinations,
  });

  @override
  SettingsScreenState createState() => SettingsScreenState();
}

class SettingsScreenState extends State<SettingsScreen> {
  bool isAdmin = false;
  bool isSupplier = false;
  bool isGuest = false;
  bool isLoading = true;
  final Logger logger = Logger();

  final Color primaryColor = const Color.fromRGBO(17, 48, 73, 1);

  @override
  void initState() {
    super.initState();
    _checkUserRoles();
  }

  Future<void> _checkUserRoles() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null || user.isAnonymous) {
        if (mounted) {
          setState(() {
            isGuest = true;
            isLoading = false;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showGuestDialog();
          });
        }
        return;
      }

      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        if (mounted) {
          setState(() {
            isAdmin = userDoc['isAdmin'] ?? false;
            // IMPORTANTE: Si es empleado (tiene associatedSupplierId),
            // asegúrate de poner 'isSupplier': true en su documento de Firestore
            // para que entre en este IF.
            isSupplier = userDoc['isSupplier'] ?? false;
            isGuest = false;
          });
        }
      }
    } catch (e) {
      logger.e('Error al verificar los roles del usuario: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _showGuestDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: _GuestContent(primaryColor: primaryColor),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Color.fromARGB(255, 243, 248, 255),
        body: Center(),
      );
    }

    if (isGuest) {
      return Scaffold(
        backgroundColor: const Color.fromARGB(255, 243, 248, 255),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Configuración',
              style: TextStyle(
                  color: Color.fromRGBO(17, 48, 73, 1),
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins')),
          centerTitle: true,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(30.0),
            child: _GuestContent(primaryColor: primaryColor),
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: const Color.fromARGB(255, 243, 248, 255),
          title: const Center(
            child: Text(
              'Configuración',
              style: TextStyle(
                  fontSize: 25.0,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                  color: Color.fromRGBO(17, 48, 73, 1)),
            ),
          ),
        ),
        backgroundColor: const Color.fromARGB(255, 243, 248, 255),
        body: ListView(
          children: [
            ListTile(
              leading: const Icon(Icons.person,
                  color: Color.fromRGBO(17, 48, 73, 1)),
              title: const Text('Cuenta',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      color: Color.fromRGBO(17, 48, 73, 1))),
              trailing: const Icon(Icons.arrow_forward_ios,
                  color: Color.fromRGBO(17, 48, 73, 1)),
              onTap: () => context.push('/account'),
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined,
                  color: Color.fromRGBO(17, 48, 73, 1)),
              title: const Text('Términos y condiciones',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      color: Color.fromRGBO(17, 48, 73, 1))),
              trailing: const Icon(Icons.arrow_forward_ios,
                  color: Color.fromRGBO(17, 48, 73, 1)),
              onTap: () => context.push('/terms'),
            ),
            ListTile(
              leading: const Icon(Icons.support_agent_outlined,
                  color: Color.fromRGBO(17, 48, 73, 1)),
              title: const Text('Soporte',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      color: Color.fromRGBO(17, 48, 73, 1))),
              trailing: const Icon(Icons.arrow_forward_ios,
                  color: Color.fromRGBO(17, 48, 73, 1)),
              onTap: () => context.push('/support'),
            ),
            if (isAdmin)
              ListTile(
                leading: const Icon(Icons.group,
                    color: Color.fromRGBO(17, 48, 73, 1)),
                title: const Text('Biqoe team',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        color: Color.fromRGBO(17, 48, 73, 1))),
                trailing: const Icon(Icons.arrow_forward_ios,
                    color: Color.fromRGBO(17, 48, 73, 1)),
                onTap: () => context.push('/admin/team'),
              ),

            // --- ÁREA DE PROVEEDOR (SIMPLIFICADO) ---
            if (isSupplier)
              ListTile(
                leading: const Icon(Icons.business_center,
                    color: Color.fromRGBO(17, 48, 73, 1)),
                title: const Text('Área de proveedor',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        color: Color.fromRGBO(17, 48, 73, 1))),
                trailing: const Icon(Icons.arrow_forward_ios,
                    color: Color.fromRGBO(17, 48, 73, 1)),
                onTap: () {
                  // SIMPLEMENTE NAVEGAMOS.
                  // El Dashboard calculará el ID correcto.
                  context.push('/supplier/dashboard');
                },
              ),

            ListTile(
              leading: const Icon(Icons.logout,
                  color: Color.fromRGBO(240, 169, 52, 1)),
              title: const Text('Cerrar sesión',
                  style: TextStyle(
                      color: Color.fromRGBO(240, 169, 52, 1),
                      fontFamily: 'Poppins')),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  context.go('/login');
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _GuestContent extends StatelessWidget {
  final Color primaryColor;

  const _GuestContent({required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: (0.1)),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.lock_person_rounded, size: 40, color: primaryColor),
        ),
        const SizedBox(height: 20),
        Text(
          "Acceso restringido",
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          "Para configurar tu perfil y ver detalles de tu cuenta, necesitas estar registrado.",
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
              fontSize: 14, color: Colors.grey[600], height: 1.5),
        ),
        const SizedBox(height: 25),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }
              context.go('/login');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: Text("Iniciar Sesión / Registrarse",
                style: GoogleFonts.poppins(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
            context.go('/');
          },
          child: Text("Volver al inicio",
              style: GoogleFonts.poppins(
                  color: Colors.grey[600], fontWeight: FontWeight.w500)),
        )
      ],
    );
  }
}
