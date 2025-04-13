import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'account_screen.dart';
import 'main_screen.dart';
import 'terms_conditions_screen.dart';
import 'bookings_screen.dart';
import 'search_screen.dart';
import 'saved_destinations_screen.dart';
import 'biqoe_team_screen.dart';
import 'supplier_screen.dart'; // Importa la pantalla del área de proveedor
import 'package:logger/logger.dart';
import 'support_screen.dart';
import 'package:hugeicons/hugeicons.dart';

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
  bool isLoading = true;
  final Logger logger = Logger();

  @override
  void initState() {
    super.initState();
    _checkUserRoles();
  }

  Future<void> _checkUserRoles() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          setState(() {
            isAdmin = userDoc['isAdmin'] ?? false;
            isSupplier = userDoc['isSupplier'] ?? false;
            isLoading = false;
          });
        }
      }
    } catch (e) {
      logger.e('Error al verificar los roles del usuario: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    if (isLoading) {
      return const Scaffold(
        backgroundColor: Color.fromARGB(255, 243, 248, 255),
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
        body: Container(
          color: const Color.fromARGB(255, 243, 248, 255),
          child: ListView(
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
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            AccountScreen(userId: widget.userId)),
                  );
                },
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
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const TermsConditionsScreen()),
                  );
                },
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
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const SupportScreen()),
                  );
                },
              ),
              if (isAdmin) // Mostrar solo si el usuario es administrador
                ListTile(
                  leading: const Icon(Icons.group,
                      color: Color.fromRGBO(17, 48, 73, 1)),
                  title: const Text('Biqoe team',
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          color: Color.fromRGBO(17, 48, 73, 1))),
                  trailing: const Icon(Icons.arrow_forward_ios,
                      color: Color.fromRGBO(17, 48, 73, 1)),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              BiqoeTeamScreen(userId: widget.userId)),
                    );
                  },
                ),
              if (isSupplier) // Mostrar solo si el usuario es proveedor
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
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              SupplierScreen(userId: widget.userId)),
                    );
                  },
                ),
              ListTile(
                leading: const Icon(Icons.logout,
                    color: Color.fromRGBO(240, 169, 52, 1)),
                title: const Text('Cerrar sesión',
                    style: TextStyle(
                        color: Color.fromRGBO(240, 169, 52, 1),
                        fontFamily: 'Poppins')),
                onTap: () {
                  FirebaseAuth.instance.signOut();
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const LoginScreen()),
                    (route) => false,
                  );
                },
              ),
            ],
          ),
        ),
        bottomNavigationBar: Container(
          height: screenHeight * 0.1,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10.0),
            child: BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.transparent,
              elevation: 0,
              selectedItemColor: const Color.fromRGBO(17, 48, 73, 1),
              unselectedItemColor: const Color.fromRGBO(17, 48, 73, 1),
              showSelectedLabels: false,
              showUnselectedLabels: false,
              onTap: (index) {
                switch (index) {
                  case 0:
                    Navigator.pushReplacement(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (_, __, ___) => SearchScreen(
                          userId: widget.userId,
                          destinations: const [],
                        ),
                        transitionsBuilder: (_, a, __, c) => FadeTransition(
                          opacity: a,
                          child: c,
                        ),
                        transitionDuration: const Duration(milliseconds: 300),
                      ),
                    );
                    break;
                  case 1:
                    Navigator.pushReplacement(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (_, __, ___) => BookingsScreen(
                          userId: widget.userId,
                        ),
                        transitionsBuilder: (_, a, __, c) => FadeTransition(
                          opacity: a,
                          child: c,
                        ),
                        transitionDuration: const Duration(milliseconds: 300),
                      ),
                    );
                    break;
                  case 2:
                    Navigator.pushReplacement(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (_, __, ___) => SavedDestinationsScreen(
                          userId: widget.userId,
                        ),
                        transitionsBuilder: (_, a, __, c) => FadeTransition(
                          opacity: a,
                          child: c,
                        ),
                        transitionDuration: const Duration(milliseconds: 300),
                      ),
                    );
                    break;
                  case 3:
                    // Ya estamos en SettingsScreen, no necesita navegación
                    break;
                }
              },
              items: [
                BottomNavigationBarItem(
                  icon: HugeIcon(
                    icon: HugeIcons.strokeRoundedHome02,
                    color: Color.fromRGBO(17, 48, 73, 1), // Color normal
                    size: 24.0,
                  ),
                  label: 'Buscar',
                ),
                BottomNavigationBarItem(
                  icon: HugeIcon(
                    icon: HugeIcons.strokeRoundedTicket03,
                    color: Color.fromRGBO(17, 48, 73, 1),
                    size: 24.0,
                  ),
                  label: 'Booked',
                ),
                BottomNavigationBarItem(
                  icon: HugeIcon(
                    icon: HugeIcons.strokeRoundedFavourite,
                    color: Color.fromRGBO(17, 48, 73, 1),
                    size: 24.0,
                  ),
                  label: 'Saved',
                ),
                BottomNavigationBarItem(
                  icon: HugeIcon(
                    icon: HugeIcons.strokeRoundedSettings01,
                    color: Color.fromRGBO(240, 169, 52, 1), // Color activo
                    size: 24.0,
                  ),
                  label: 'Configuración',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
