import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

// PANTALLAS PRINCIPALES
import '../../main_screen.dart';
import '../../login_screen.dart';
import '../../register_screen.dart';
import '../../screens/supplier/destination_detail_screen.dart';
import '../../screens/search_screen.dart';
import '../../widgets/update_checker.dart';
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

// =====================================================================
// 🔥 EL BYPASS DEFINITIVO PARA SAFARI / APPLE 🔥
// Firebase Auth colapsa en Safari al pedir el 'currentUser' si el
// navegador bloquea las cookies. Esta función atrapa ese colapso letal.
// =====================================================================
User? get _safeCurrentUser {
  try {
    return FirebaseAuth.instance.currentUser;
  } catch (e) {
    return null; // Si Safari hace colapsar a Firebase, devolvemos null seguro
  }
}

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey =
    GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/',

  // Apagamos este Stream en Web porque también detona colapsos asíncronos en Safari
  refreshListenable: kIsWeb
      ? null
      : GoRouterRefreshStream(FirebaseAuth.instance.authStateChanges()),

  redirect: (context, state) {
    final user = _safeCurrentUser;
    final bool isLoggedIn = user != null;
    final bool isAnon = user?.isAnonymous ?? false;
    final path = state.matchedLocation;

    // RUTAS PÚBLICAS ESTRICTAS
    final publicRoutes = [
      '/',
      '/login',
      '/login-form',
      '/register',
      '/guest',
      '/forgot-password'
    ];

    if (!isLoggedIn) {
      // Sin sesión: '/' redirige a '/login' para que LoginScreen se muestre
      // fuera del StatefulShellRoute (sin bottom nav bar).
      if (path == '/') return '/login';

      if (publicRoutes.contains(path)) return null;

      // 🔥 LÓGICA DE RUTAS MEJORADA Y BLINDADA 🔥
      // Definimos claramente cuáles son las rutas que requieren sesión obligatoria.
      final isProtectedRoute = path.startsWith('/bookings') ||
          path.startsWith('/saved') ||
          path.startsWith('/settings') ||
          path.startsWith('/account') ||
          path.startsWith('/verify') ||
          path.startsWith('/supplier') ||
          path.startsWith('/chats') ||
          path.startsWith('/admin');

      // Si es una ruta protegida y no hay sesión, mandarlo al login
      if (isProtectedRoute) {
        return '/login';
      }

      // Si no es una ruta protegida (Por ejemplo: /mi-slug-de-proveedor),
      // lo dejamos pasar sin restricciones para que no colapse en Safari.
      return null;
    }

    if (isLoggedIn && !isAnon) {
      // Si está logueado e intenta volver al login, lo mandamos al home
      if (path == '/login' ||
          path == '/login-form' ||
          path == '/register' ||
          path == '/guest') {
        return '/';
      }
    }

    return null;
  },

  routes: [
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
                // El redirect garantiza que solo usuarios con sesión activa
                // llegan aquí — sin sesión se redirige a '/login' (fuera del shell).
                final String safeUid = _safeCurrentUser?.uid ?? 'guest';
                return NoTransitionPage(
                  child: UpdateChecker(
                    child:
                        SearchScreen(userId: safeUid, destinations: const []),
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
              pageBuilder: (context, state) {
                final uid = _safeCurrentUser?.uid ?? '';
                return NoTransitionPage(
                  child: BookingsScreen(userId: uid),
                );
              },
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/saved',
              name: 'saved',
              pageBuilder: (context, state) {
                final uid = _safeCurrentUser?.uid ?? '';
                return NoTransitionPage(
                  child: SavedDestinationsScreen(userId: uid),
                );
              },
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              name: 'settings',
              pageBuilder: (context, state) {
                final uid = _safeCurrentUser?.uid ?? '';
                return NoTransitionPage(
                  child:
                      SettingsScreen(userId: uid, savedDestinations: const []),
                );
              },
            ),
          ],
        ),
      ],
    ),

    // --- RUTAS EXTERNAS ---
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
    GoRoute(
      path: '/search-results',
      builder: (context, state) =>
          SearchResultsScreen(userId: _safeCurrentUser?.uid ?? ''),
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
      builder: (context, state) =>
          RestaurantsScreen(userId: _safeCurrentUser?.uid ?? ''),
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
        final String? id = state.pathParameters['id'];
        final user = _safeCurrentUser;
        final String userId = user?.uid ?? 'guest';
        return DestinationDetailScreen(
          destinationId: id ?? '',
          userId: userId,
        );
      },
    ),
    GoRoute(
      path: '/chats',
      builder: (context, state) => ChatListScreen(
        currentUserId: _safeCurrentUser?.uid ?? '',
        isSupplier: false,
      ),
    ),
    GoRoute(
        path: '/account',
        builder: (context, state) =>
            AccountScreen(userId: _safeCurrentUser?.uid ?? '')),
    GoRoute(
        path: '/terms',
        builder: (context, state) => const TermsConditionsScreen()),
    GoRoute(
        path: '/support', builder: (context, state) => const SupportScreen()),
    GoRoute(
        path: '/admin/team',
        builder: (context, state) =>
            BiqoeTeamScreen(userId: _safeCurrentUser?.uid ?? '')),
    GoRoute(
      path: '/supplier/dashboard',
      builder: (context, state) =>
          SupplierDashboardLayout(userId: _safeCurrentUser?.uid ?? ''),
    ),
    GoRoute(
      path: '/supplier/manifest',
      builder: (context, state) {
        final args = state.extra as Map<String, dynamic>;
        final String currentUserId = _safeCurrentUser?.uid ?? '';
        return ManifestScreen(
          supplierId: currentUserId,
          date: args['date'] as DateTime,
          tripName: args['tripName'] as String,
          tripId: args['tripId'] as String?,
        );
      },
    ),
    GoRoute(
      path: '/supplier/manual-booking',
      builder: (context, state) {
        final supplierIdFromExtra = state.extra as String?;
        final currentId = _safeCurrentUser?.uid ?? '';
        return ManualBookingScreen(
            supplierId: supplierIdFromExtra ?? currentId);
      },
    ),
    GoRoute(
      path: '/supplier/customer/detail',
      builder: (context, state) {
        final clientData = state.extra as Map<String, dynamic>;
        return CustomerDetailScreen(clientData: clientData);
      },
    ),
    // ==================================================
    // 🔥 RUTA DE ACTIVIDAD POR SLUG: /{proveedor}/{actividad} 🔥
    // Ejemplo: /tanturismo/glampingentachira3d2noches
    // Busca en Firestore el destino cuyo proveedor tiene ese slug
    // y cuyo nombre normalizado coincide con el slug de actividad.
    // ==================================================
    GoRoute(
      path: '/:providerSlug/:activitySlug',
      builder: (context, state) {
        final providerSlug = state.pathParameters['providerSlug'] ?? '';
        final activitySlug = state.pathParameters['activitySlug'] ?? '';
        final currentUserId = _safeCurrentUser?.uid ?? 'guest';

        return _ActivityBySlugScreen(
          providerSlug: providerSlug,
          activitySlug: activitySlug,
          currentUserId: currentUserId,
        );
      },
    ),

    // ==================================================
    // 🔥 RUTA DEL PERFIL DEL PROVEEDOR BLINDADA 🔥
    // ==================================================
    GoRoute(
      path: '/:slug',
      builder: (context, state) {
        final slug = state.pathParameters['slug'];

        // Garantizamos que SIEMPRE haya un ID, para no romper Hive en la otra pantalla
        final currentUserId = _safeCurrentUser?.uid ?? 'guest';

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

// ===========================================================================
// Widget que resuelve /{providerSlug}/{activitySlug} → DestinationDetailScreen
// ===========================================================================
class _ActivityBySlugScreen extends StatefulWidget {
  final String providerSlug;
  final String activitySlug;
  final String currentUserId;

  const _ActivityBySlugScreen({
    required this.providerSlug,
    required this.activitySlug,
    required this.currentUserId,
  });

  @override
  State<_ActivityBySlugScreen> createState() => _ActivityBySlugScreenState();
}

class _ActivityBySlugScreenState extends State<_ActivityBySlugScreen> {
  String? _destinationId;
  bool _loading = true;
  bool _notFound = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  /// Normaliza un string igual que la función _toSlug en destination_detail_screen.
  String _normalize(String text) {
    const Map<String, String> accents = {
      'á': 'a',
      'é': 'e',
      'í': 'i',
      'ó': 'o',
      'ú': 'u',
      'à': 'a',
      'è': 'e',
      'ì': 'i',
      'ò': 'o',
      'ù': 'u',
      'ä': 'a',
      'ë': 'e',
      'ï': 'i',
      'ö': 'o',
      'ü': 'u',
      'â': 'a',
      'ê': 'e',
      'î': 'i',
      'ô': 'o',
      'û': 'u',
      'ã': 'a',
      'õ': 'o',
      'ñ': 'n',
      'Á': 'a',
      'É': 'e',
      'Í': 'i',
      'Ó': 'o',
      'Ú': 'u',
      'À': 'a',
      'È': 'e',
      'Ì': 'i',
      'Ò': 'o',
      'Ù': 'u',
      'Ä': 'a',
      'Ë': 'e',
      'Ï': 'i',
      'Ö': 'o',
      'Ü': 'u',
      'Â': 'a',
      'Ê': 'e',
      'Î': 'i',
      'Ô': 'o',
      'Û': 'u',
      'Ã': 'a',
      'Õ': 'o',
      'Ñ': 'n',
    };
    String result = text;
    accents.forEach((k, v) => result = result.replaceAll(k, v));
    return result
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  Future<void> _resolve() async {
    try {
      // 1. Buscar el UID del proveedor a partir de su slug en metadata/slugs
      final slugsDoc = await FirebaseFirestore.instance
          .collection('metadata')
          .doc('slugs')
          .get();

      if (!slugsDoc.exists) {
        if (mounted) {
          setState(() {
            _loading = false;
            _notFound = true;
          });
        }
        return;
      }

      final mapping =
          Map<String, dynamic>.from(slugsDoc.data()?['mapping'] ?? {});
      final supplierId = mapping[widget.providerSlug]?.toString();

      if (supplierId == null || supplierId.isEmpty) {
        if (mounted) {
          setState(() {
            _loading = false;
            _notFound = true;
          });
        }
        return;
      }

      // 2. Buscar todas las actividades de ese proveedor
      final snap = await FirebaseFirestore.instance
          .collection('destinos')
          .where('supplierId', isEqualTo: supplierId)
          .get();

      // 3. Encontrar la actividad cuyo nombre normalizado coincide
      String? foundId;
      for (final doc in snap.docs) {
        final nombre = doc.data()['nombre']?.toString() ?? '';
        if (_normalize(nombre) == widget.activitySlug) {
          foundId = doc.id;
          break;
        }
      }

      if (mounted) {
        setState(() {
          _destinationId = foundId;
          _loading = false;
          _notFound = foundId == null;
        });
      }
    } catch (e) {
      debugPrint('Error resolviendo link de actividad: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _notFound = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8F9FD),
        body: Center(
          child:
              CircularProgressIndicator(color: Color.fromRGBO(17, 48, 73, 1)),
        ),
      );
    }

    if (_notFound || _destinationId == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FD),
        appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: BackButton(
                color: const Color.fromRGBO(17, 48, 73, 1),
                onPressed: () => context.go('/'))),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.explore_off, size: 60, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'Actividad no encontrada',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700]),
              ),
              const SizedBox(height: 8),
              Text(
                'El link puede haber cambiado o la actividad ya no está disponible.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    color: Colors.grey[500]),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromRGBO(17, 48, 73, 1),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                onPressed: () => context.go('/'),
                child: const Text('Ir al inicio',
                    style:
                        TextStyle(fontFamily: 'Poppins', color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    // 4. Renderizar la pantalla de detalle con el ID encontrado
    return DestinationDetailScreen(
      destinationId: _destinationId!,
      userId: widget.currentUserId,
    );
  }
}

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
