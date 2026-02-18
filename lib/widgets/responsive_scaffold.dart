import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

class ResponsiveScaffold extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const ResponsiveScaffold({
    super.key,
    required this.navigationShell,
  });

  @override
  Widget build(BuildContext context) {
    // Definimos los ítems del menú una sola vez para reutilizarlos
    final menuItems = [
      _NavigationItem(
        icon: HugeIcons.strokeRoundedHome02,
        label: 'Búsqueda',
      ),
      _NavigationItem(
        icon: HugeIcons.strokeRoundedTicket03,
        label: 'Reservas',
      ),
      _NavigationItem(
        icon: HugeIcons.strokeRoundedFavourite,
        label: 'Guardados',
      ),
      _NavigationItem(
        icon: HugeIcons.strokeRoundedSettings01,
        label: 'Configuración',
      ),
    ];

    // LayoutBuilder detecta el tamaño de la pantalla en tiempo real
    return LayoutBuilder(
      builder: (context, constraints) {
        // BREAKPOINT: 640px. Menos es Móvil, Más es Tablet/Web
        if (constraints.maxWidth < 640) {
          // ================================================================
          // VISTA MÓVIL (Bottom Navigation Bar)
          // ================================================================
          return Scaffold(
            backgroundColor: const Color.fromARGB(255, 243, 247, 254),
            body:
                navigationShell, // Aquí se pinta la pantalla actual (Search, Booking...)
            bottomNavigationBar: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
              ),
              child: BottomNavigationBar(
                type: BottomNavigationBarType.fixed,
                backgroundColor: Colors.white,
                elevation: 0,
                selectedItemColor: const Color.fromRGBO(240, 169, 52, 1),
                unselectedItemColor: const Color.fromRGBO(17, 48, 73, 1),
                showSelectedLabels: false,
                showUnselectedLabels: false,
                currentIndex: navigationShell.currentIndex,
                onTap: (index) => _onTap(context, index),
                items: menuItems
                    .map((item) => BottomNavigationBarItem(
                          icon: HugeIcon(
                            icon: item.icon,
                            color: const Color.fromRGBO(17, 48, 73, 1),
                            size: 24.0,
                          ),
                          activeIcon: HugeIcon(
                            icon: item.icon,
                            color: const Color.fromRGBO(240, 169, 52, 1),
                            size: 24.0,
                          ),
                          label: item.label,
                        ))
                    .toList(),
              ),
            ),
          );
        } else {
          // ================================================================
          // VISTA DESKTOP / WEB (Barra Lateral - Navigation Rail)
          // ================================================================
          return Scaffold(
            backgroundColor: const Color.fromARGB(255, 243, 247, 254),
            body: Row(
              children: [
                // Barra Lateral
                NavigationRail(
                  backgroundColor: Colors.white,
                  selectedIndex: navigationShell.currentIndex,
                  onDestinationSelected: (index) => _onTap(context, index),
                  labelType: NavigationRailLabelType.all,
                  groupAlignment: -0.8, // Alinear ítems hacia arriba
                  leading: Padding(
                    padding: const EdgeInsets.only(bottom: 20, top: 20),
                    child: Image.asset(
                      'assets/images/Biqoe logo1.png',
                      height: 50,
                      width: 50,
                      errorBuilder: (c, o, s) =>
                          const Icon(Icons.travel_explore),
                    ),
                  ),
                  selectedLabelTextStyle: const TextStyle(
                    color: Color.fromRGBO(240, 169, 52, 1),
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins',
                  ),
                  unselectedLabelTextStyle: const TextStyle(
                    color: Color.fromRGBO(17, 48, 73, 1),
                    fontFamily: 'Poppins',
                  ),
                  destinations: menuItems
                      .map((item) => NavigationRailDestination(
                            icon: HugeIcon(
                              icon: item.icon,
                              color: const Color.fromRGBO(17, 48, 73, 1),
                              size: 24.0,
                            ),
                            selectedIcon: HugeIcon(
                              icon: item.icon,
                              color: const Color.fromRGBO(240, 169, 52, 1),
                              size: 24.0,
                            ),
                            label: Text(item.label),
                          ))
                      .toList(),
                ),
                const VerticalDivider(thickness: 1, width: 1),
                // Contenido Principal (Se expande para llenar el resto)
                Expanded(
                  child: navigationShell,
                ),
              ],
            ),
          );
        }
      },
    );
  }

  void _onTap(BuildContext context, int index) {
    // goBranch cambia la rama activa sin perder el estado (scroll, inputs)
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}

class _NavigationItem {
  final IconData icon;
  final String label;
  _NavigationItem({required this.icon, required this.label});
}
