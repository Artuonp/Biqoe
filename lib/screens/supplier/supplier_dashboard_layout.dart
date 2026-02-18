import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// --- IMPORTA EL SERVICIO ---
import '../../services/supplier_service.dart';

// --- IMPORTA TODAS LAS PANTALLAS HIJAS ---
import 'supplier_calendar_screen.dart';
import 'supplier_customers_screen.dart';
import 'supplier_finance_screen.dart';
import 'create_event/create_event_screen.dart';
import 'dashboard_home_screen.dart';
import 'supplier_experiences_list_screen.dart';
import 'manual_booking_screen.dart'; // <--- AGREGADO (Faltaba este import)

const Color kPrimaryColor = Color.fromRGBO(17, 48, 73, 1);

class SupplierDashboardLayout extends StatefulWidget {
  final String userId; // ID del usuario logueado (Juan)

  const SupplierDashboardLayout({super.key, required this.userId});

  @override
  State<SupplierDashboardLayout> createState() =>
      _SupplierDashboardLayoutState();
}

class _SupplierDashboardLayoutState extends State<SupplierDashboardLayout> {
  int _selectedIndex = 0;
  List<Widget> _screens = [];

  // VARIABLES PARA LA LÓGICA MULTI-USUARIO
  bool _loadingRole = true;
  String _effectiveSupplierId = ''; // Este será el ID del Jefe (Biqoe)

  @override
  void initState() {
    super.initState();
    _resolveSupplierIdentity();
  }

  // --- DETERMINAR QUIÉN ES EL JEFE ---
  Future<void> _resolveSupplierIdentity() async {
    // 1. Usamos el servicio para ver si este usuario tiene un jefe
    String id = await SupplierService.getActiveSupplierId();

    // Si el servicio falla o no devuelve nada, usamos el ID del usuario actual
    if (id.isEmpty) id = widget.userId;

    if (mounted) {
      setState(() {
        _effectiveSupplierId = id; // Guardamos el ID real (Biqoe)

        // 2. Inicializamos las pantallas pasándoles el ID DEL JEFE
        // Así todas las pantallas cargarán los datos de Biqoe, no de Juan
        _screens = [
          DashboardHomeScreen(userId: _effectiveSupplierId),
          SupplierCalendarScreen(userId: _effectiveSupplierId),
          SupplierCustomersScreen(userId: _effectiveSupplierId),
          SupplierFinanceScreen(userId: _effectiveSupplierId),
        ];

        _loadingRole = false;
      });
    }
  }

  void _onDestinationSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _showQuickActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Acciones rápidas',
                  style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: kPrimaryColor)),
              const SizedBox(height: 20),

              // 1. CREAR EXPERIENCIA
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: kPrimaryColor,
                  child: Icon(Icons.add, color: Colors.white),
                ),
                title: Text('Crear experiencia',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                subtitle: Text('Publica un nueva experiencia',
                    style: GoogleFonts.poppins(fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          // PASAMOS EL ID DEL JEFE AL CREADOR DE EVENTOS
                          builder: (c) => CreateEventScreen(
                                supplierId: _effectiveSupplierId,
                              )));
                },
              ),

              // 2. EDITAR EXPERIENCIAS
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: kPrimaryColor.withValues(alpha: 0.1),
                  child: const Icon(Icons.edit, color: kPrimaryColor),
                ),
                title: Text('Editar experiencias',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                subtitle: Text('Gestiona tus publicaciones activas',
                    style: GoogleFonts.poppins(fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  // PASAMOS EL ID DEL JEFE A LA LISTA DE EXPERIENCIAS
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (c) => SupplierExperiencesListScreen(
                                supplierId: _effectiveSupplierId,
                              )));
                },
              ),

              // 3. REGISTRAR RESERVA
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: kPrimaryColor.withValues(alpha: 0.1),
                  child: const Icon(Icons.bookmark_add, color: kPrimaryColor),
                ),
                title: Text('Registrar reserva',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                subtitle: Text('Venta manual (WhatsApp/Otros)',
                    style: GoogleFonts.poppins(fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  // PASAMOS EL ID DEL JEFE AL REGISTRO MANUAL
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (c) => ManualBookingScreen(
                              supplierId: _effectiveSupplierId)));
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Si estamos determinando el rol, mostramos carga
    if (_loadingRole) {
      return const Scaffold(
        backgroundColor: Color.fromARGB(255, 243, 248, 255),
        body: Center(),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          return _buildMobileLayout();
        } else {
          return _buildDesktopLayout();
        }
      },
    );
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 243, 248, 255),
      body: _screens[_selectedIndex],
      floatingActionButton: FloatingActionButton(
        backgroundColor: kPrimaryColor,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => _showQuickActions(context),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onDestinationSelected,
        backgroundColor: Colors.white,
        indicatorColor: kPrimaryColor.withValues(alpha: 0.1),
        surfaceTintColor: Colors.white,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard, color: kPrimaryColor),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month, color: kPrimaryColor),
            label: 'Calendario',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people, color: kPrimaryColor),
            label: 'Clientes',
          ),
          NavigationDestination(
            icon: Icon(Icons.attach_money),
            selectedIcon: Icon(Icons.monetization_on, color: kPrimaryColor),
            label: 'Métricas',
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: _onDestinationSelected,
            labelType: NavigationRailLabelType.all,
            backgroundColor: Colors.white,
            indicatorColor: kPrimaryColor.withValues(alpha: 0.1),
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: FloatingActionButton(
                elevation: 0,
                backgroundColor: kPrimaryColor,
                child: const Icon(Icons.add, color: Colors.white),
                onPressed: () => _showQuickActions(context),
              ),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard, color: kPrimaryColor),
                label: Text('Inicio'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.calendar_month_outlined),
                selectedIcon: Icon(Icons.calendar_month, color: kPrimaryColor),
                label: Text('Calendario'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people, color: kPrimaryColor),
                label: Text('Clientes'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.attach_money),
                selectedIcon: Icon(Icons.monetization_on, color: kPrimaryColor),
                label: Text('Métricas'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: _screens[_selectedIndex]),
        ],
      ),
    );
  }
}
