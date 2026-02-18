import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

// PANTALLAS PRINCIPALES
import '../../main_screen.dart';
import '../../login_screen.dart';
import '../../register_screen.dart';
import '../../screens/supplier/destination_detail_screen.dart';
import '../../screens/search_screen.dart';
import '../../widgets/update_checker.dart';
import '../../verify_screen.dart';
import '../../supplier_verify_screen.dart';
import '../../guest_screen.dart';
import '../../password_reset_screen.dart';

// PANTALLAS DEL HOME
import '../../bookings_screen.dart';
import '../../saved_destinations_screen.dart';
import '../../settings_screen.dart';
import '../../search_results_screen.dart';
import '../../restaurants_screen.dart';
import '../../destinations_screen.dart';
import '../../filter_screen.dart';

// PANTALLAS DE CONFIGURACIÓN
import '../../account_screen.dart';
import '../../terms_conditions_screen.dart';
import '../../support_screen.dart';
import '../../biqoe_team_screen.dart';

// PANTALLAS DE CHAT
import '../../screens/chat_list_screen.dart';

// DASHBOARD DE PROVEEDOR
import '../../screens/supplier/supplier_dashboard_layout.dart';
import '../../screens/supplier/manifest_screen.dart';
import '../../screens/supplier/manual_booking_screen.dart';
import '../../screens/supplier/customer_detail_screen.dart';

// PERFIL PÚBLICO
import '../../screens/supplier/provider_profile_screen.dart';

// WIDGET RESPONSIVO
import '../../widgets/responsive_scaffold.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey =
    GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/',
  refreshListenable:
      GoRouterRefreshStream(FirebaseAuth.instance.authStateChanges()),

  // --- LÓGICA DE REDIRECCIÓN CORREGIDA ---
  redirect: (context, state) {
    final user = FirebaseAuth.instance.currentUser;

    // Un usuario es "realmente logueado" si existe Y NO es anónimo
    final bool isLoggedIn = user != null;
    final bool isAnon = user?.isAnonymous ?? false;

    final path = state.matchedLocation;

    final publicRoutes = [
      '/login',
      '/login-form',
      '/register',
      '/guest',
      '/forgot-password'
    ];

    // 1. Si no hay usuario (ni registrado ni anónimo)
    if (!isLoggedIn) {
      // Rutas públicas permitidas
      if (publicRoutes.contains(path)) return null;

      // Permitir Slugs (Perfiles públicos)
      if (path.length > 1 &&
          !path.startsWith('/bookings') &&
          !path.startsWith('/saved') &&
          !path.startsWith('/settings') &&
          !path.startsWith('/account') &&
          !path.startsWith('/verify') &&
          !path.startsWith('/supplier') &&
          !path.startsWith('/chats') &&
          !path.startsWith('/admin')) {
        return null;
      }

      // Si no, mandar a Login
      return '/login';
    }

    // 2. Si el usuario está logueado...
    // AHORA: Solo bloqueamos el login si NO es anónimo.
    if (isLoggedIn && !isAnon && publicRoutes.contains(path)) {
      return '/'; // Usuario registrado intentando ver login -> Home
    }

    return null; // Dejar pasar
  },

  routes: [
    // =========================================================================
    // STATEFUL SHELL ROUTE (Barra de Navegación Persistente - Home/Tabs)
    // =========================================================================
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return ResponsiveScaffold(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          navigatorKey: _shellNavigatorKey,
          routes: [
            GoRoute(
              path: '/',
              name: 'home',
              pageBuilder: (context, state) {
                final user = FirebaseAuth.instance.currentUser;
                return NoTransitionPage(
                  child: UpdateChecker(
                    child: SearchScreen(
                        userId: user?.uid ?? '', destinations: const []),
                  ),
                );
              },
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/bookings',
              name: 'bookings',
              pageBuilder: (context, state) => NoTransitionPage(
                child: BookingsScreen(
                    userId: FirebaseAuth.instance.currentUser?.uid ?? ''),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/saved',
              name: 'saved',
              pageBuilder: (context, state) => NoTransitionPage(
                child: SavedDestinationsScreen(
                    userId: FirebaseAuth.instance.currentUser?.uid ?? ''),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              name: 'settings',
              pageBuilder: (context, state) => NoTransitionPage(
                child: SettingsScreen(
                    userId: FirebaseAuth.instance.currentUser?.uid ?? '',
                    savedDestinations: const []),
              ),
            ),
          ],
        ),
      ],
    ),

    // --- RUTAS EXTERNAS ---

    // Auth
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(
        path: '/login-form',
        builder: (context, state) => const LoginFormScreen()),
    GoRoute(
        path: '/register', builder: (context, state) => const RegisterScreen()),
    GoRoute(path: '/guest', builder: (context, state) => const GuestScreen()),
    GoRoute(
      path: '/forgot-password',
      builder: (context, state) {
        final email = state.extra as String?;
        return PasswordResetScreen(email: email ?? '');
      },
    ),

    // Sub-pantallas del Home
    GoRoute(
      path: '/search-results',
      builder: (context, state) => SearchResultsScreen(
          userId: FirebaseAuth.instance.currentUser?.uid ?? ''),
    ),

    GoRoute(
      path: '/filter',
      builder: (context, state) {
        final args = state.extra as Map<String, dynamic>;
        return FilterScreen(
          userId: args['userId'],
          destinations: List<String>.from(args['destinations'] ?? []),
          selectedCategories:
              List<String>.from(args['selectedCategories'] ?? []),
          selectedLocation: args['selectedLocation'] ?? 'Todas',
          searchText: args['searchText'] ?? '',
        );
      },
    ),

    GoRoute(
      path: '/restaurants',
      builder: (context, state) => RestaurantsScreen(
          userId: FirebaseAuth.instance.currentUser?.uid ?? ''),
    ),

    GoRoute(
      path: '/destinations-list',
      builder: (context, state) {
        final args = state.extra as Map<String, dynamic>;
        return DestinationsScreen(
          userId: args['userId'],
          destinations: List<String>.from(args['destinations'] ?? []),
          initialCategories: List<String>.from(args['initialCategories'] ?? []),
          initialLocation: args['initialLocation'] ?? 'Todas',
          sortOption: args['sortOption'] ?? 0,
          searchText: args['searchText'] ?? '',
        );
      },
    ),

    GoRoute(
      path: '/d/:id',
      name: 'destination_detail',
      builder: (context, state) {
        final Map<String, dynamic>? destinoObject =
            state.extra as Map<String, dynamic>?;
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          return DestinationDetailScreen(
              destino: destinoObject ?? {}, userId: user.uid);
        } else {
          return const LoginScreen();
        }
      },
    ),

    // --- NUEVA RUTA PARA LISTA DE CHATS (Para Notificaciones) ---
    GoRoute(
      path: '/chats',
      builder: (context, state) => ChatListScreen(
        currentUserId: FirebaseAuth.instance.currentUser?.uid ?? '',
        // Asumimos false, si es supplier el dashboard lo maneja
        isSupplier: false,
      ),
    ),

    // Gestión y Configuración
    GoRoute(
        path: '/verify',
        builder: (context, state) =>
            VerifyScreen(userId: FirebaseAuth.instance.currentUser?.uid ?? '')),
    GoRoute(
        path: '/supplier/verify',
        builder: (context, state) => SupplierVerifyScreen(
            userId: FirebaseAuth.instance.currentUser?.uid ?? '')),
    GoRoute(
        path: '/account',
        builder: (context, state) => AccountScreen(
            userId: FirebaseAuth.instance.currentUser?.uid ?? '')),
    GoRoute(
        path: '/terms',
        builder: (context, state) => const TermsConditionsScreen()),
    GoRoute(
        path: '/support', builder: (context, state) => const SupportScreen()),
    GoRoute(
        path: '/admin/team',
        builder: (context, state) => BiqoeTeamScreen(
            userId: FirebaseAuth.instance.currentUser?.uid ?? '')),

    // Dashboard de Proveedor
    GoRoute(
      path: '/supplier/dashboard',
      builder: (context, state) => SupplierDashboardLayout(
          userId: FirebaseAuth.instance.currentUser?.uid ?? ''),
    ),
    GoRoute(
      path: '/supplier/manifest',
      builder: (context, state) {
        final args = state.extra as Map<String, dynamic>;
        final String currentUserId =
            FirebaseAuth.instance.currentUser?.uid ?? '';
        return ManifestScreen(
          supplierId: currentUserId,
          date: args['date'] as DateTime,
          tripName: args['tripName'] as String,
          tripId: args['tripId'] as String?,
        );
      },
    ),

    // --- AQUÍ ESTÁ EL ARREGLO ---
    GoRoute(
      path: '/supplier/manual-booking',
      builder: (context, state) {
        // Intentamos obtener el ID del extra (si viene del dashboard)
        final supplierIdFromExtra = state.extra as String?;
        // Si no, usamos el ID del usuario actual (fallback para evitar errores)
        final currentId = FirebaseAuth.instance.currentUser?.uid ?? '';

        return ManualBookingScreen(
            supplierId: supplierIdFromExtra ?? currentId);
      },
    ),
    // ----------------------------

    GoRoute(
      path: '/supplier/customer/detail',
      builder: (context, state) {
        final clientData = state.extra as Map<String, dynamic>;
        return CustomerDetailScreen(clientData: clientData);
      },
    ),

    // Ruta dinámica (Slug) - Al final
    GoRoute(
      path: '/:slug',
      builder: (context, state) {
        final slug = state.pathParameters['slug'];
        final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? 'guest';

        if (slug == null || slug.isEmpty) {
          return const LoginScreen();
        }

        return ProviderProfileScreen(
          slug: slug,
          currentUserId: currentUserId,
        );
      },
    ),
  ],
);

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }
  late final StreamSubscription<dynamic> _subscription;
  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
