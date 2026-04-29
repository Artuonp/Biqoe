import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'admin_activities_screen.dart';
import 'admin_providers_screen.dart';
import 'tasa_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BiqoeTeamScreen — Panel principal del equipo administrador de Biqoe
// ─────────────────────────────────────────────────────────────────────────────
class BiqoeTeamScreen extends StatelessWidget {
  final String userId;

  const BiqoeTeamScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F7FE),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Biqoe Team',
          style: GoogleFonts.poppins(
              color: const Color.fromRGBO(17, 48, 73, 1),
              fontWeight: FontWeight.bold,
              fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ─────────────────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(17, 48, 73, 1),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.admin_panel_settings,
                          color: Colors.white, size: 32),
                      const SizedBox(height: 10),
                      Text(
                        'Panel de administración',
                        style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18),
                      ),
                      Text(
                        'Gestión centralizada de Biqoe',
                        style: GoogleFonts.poppins(
                            color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // ── Sección: Gestión de contenido ──────────────────────────
                _SectionLabel(label: 'Gestión de contenido'),
                const SizedBox(height: 12),

                // ACTIVIDADES
                _AdminMenuCard(
                  icon: Icons.explore_outlined,
                  title: 'Actividades',
                  subtitle:
                      'Ver, crear, editar y eliminar todas las actividades de todos los proveedores.',
                  color: const Color.fromRGBO(17, 48, 73, 1),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AdminActivitiesScreen()),
                  ),
                ),
                const SizedBox(height: 12),

                // PROVEEDORES
                _AdminMenuCard(
                  icon: Icons.people_outline,
                  title: 'Proveedores / Usuarios',
                  subtitle:
                      'Buscar, editar roles, slugs, vincular cuentas y gestionar perfiles de todos los usuarios.',
                  color: const Color(0xFF1565C0),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AdminProvidersScreen()),
                  ),
                ),
                const SizedBox(height: 28),

                // ── Sección: Configuración ─────────────────────────────────
                _SectionLabel(label: 'Configuración del sistema'),
                const SizedBox(height: 12),

                // TASA
                _AdminMenuCard(
                  icon: Icons.monetization_on_outlined,
                  title: 'Tasa de cambio',
                  subtitle:
                      'Actualiza el tipo de cambio USD/Bs que se usa en toda la plataforma.',
                  color: const Color(0xFF2E7D32),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TasaScreen()),
                  ),
                ),
                const SizedBox(height: 40),

                // ── Footer ─────────────────────────────────────────────────
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Administrado por ',
                          style: GoogleFonts.poppins(
                              color: Colors.grey[400], fontSize: 12)),
                      Text('Biqoe Team',
                          style: GoogleFonts.poppins(
                              color: const Color.fromRGBO(17, 48, 73, 1),
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Card grande de menú ───────────────────────────────────────────────────────
class _AdminMenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _AdminMenuCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4))
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: const Color.fromRGBO(17, 48, 73, 1))),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: Colors.grey[600])),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}

// ── Etiqueta de sección ───────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.grey[500],
          letterSpacing: 0.8),
    );
  }
}
