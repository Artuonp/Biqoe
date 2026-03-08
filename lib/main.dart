import 'dart:async';

import 'package:flutter/foundation.dart'; // Para kIsWeb y TargetPlatform

import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

import 'package:firebase_core/firebase_core.dart';

import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:flutter_web_plugins/url_strategy.dart'; // Necesario para URLs limpias

import 'package:hive_flutter/hive_flutter.dart';

import 'package:logger/logger.dart';

import 'package:provider/provider.dart';

import 'package:firebase_auth/firebase_auth.dart';

// Añadido para el observador

import 'firebase_options.dart';

import 'booking_provider.dart';

import 'config/router/app_router.dart';

final Logger logger = Logger();

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// 🔥 NUEVO: Observador de rutas para depuración

class LoggingNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route route, Route? previousRoute) {
    debugPrint('Ruta push: ${route.settings.name}');
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    debugPrint('Ruta pop: ${route.settings.name}');
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    debugPrint('Ruta replace: ${newRoute?.settings.name}');
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  logger.i(
      'Notificación recibida en segundo plano: ${message.notification?.title}');
}

void _handleNotificationNavigation(RemoteMessage message) {
  final user = FirebaseAuth.instance.currentUser;

  if (user != null) {
    final data = message.data;

    final String? screen = data['screen'];

    if (screen == 'dashboard') {
      appRouter.go('/supplier/dashboard');

      return;
    }

    if (screen == 'verify') {
      appRouter.push('/supplier/verify');
    }
  }
}

Future<void> main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    usePathUrlStrategy();

    if (!kIsWeb) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }

    // ==============================================================

    // 🔥 BLOQUEO DE SERVICE WORKERS EN WEB PARA EVITAR CRASH 🔥

    // ==============================================================

    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);
    }

    // Manejo de Errores Globales

    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);

      logger.e('FlutterError: ${details.exceptionAsString()}');
    };

    // 1. Inicializar Firebase + SOLUCIÓN OFICIAL DE SAFARI

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }

      // ==============================================================

      // 🔥 NUEVO: APAGAR EL CACHÉ DE FIRESTORE PARA SAFARI 🔥

      // ==============================================================

      if (kIsWeb) {
        try {
          FirebaseFirestore.instance.settings = const Settings(
            persistenceEnabled: false,
          );
        } catch (_) {}
      }

      // ==============================================================

      // 🔥 EL VERDADERO FIX PARA SAFARI (PERSISTENCIA AUTH) 🔥

      // ==============================================================

      if (kIsWeb) {
        try {
          await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
        } catch (e) {
          debugPrint("Safari bloqueó cookies. Usando persistencia en memoria.");

          await FirebaseAuth.instance.setPersistence(Persistence.NONE);
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error al iniciar Firebase: $e');
    }

    // 2. Inicializar Hive protegido

    if (!kIsWeb) {
      try {
        await Hive.initFlutter();

        await Hive.openBox<Map>('saved_destinations');
      } catch (e) {
        debugPrint('⚠️ Error al iniciar Hive: $e');
      }
    }

    // 3. Inicializar Notificaciones (Solo Móvil) protegido

    if (!kIsWeb) {
      try {
        await _setupNotifications();

        final initialMessage =
            await FirebaseMessaging.instance.getInitialMessage();

        if (initialMessage != null) {
          _handleNotificationNavigation(initialMessage);
        }
      } catch (e) {
        debugPrint('⚠️ Error al iniciar Notificaciones: $e');
      }
    }

    // 4. Ejecutar la app

    runApp(const MyApp());
  }, (error, stack) {
    debugPrint('🛡️ Error asíncrono atrapado y neutralizado: $error');
  });
}

Future<void> _setupNotifications() async {
  if (kIsWeb) return;

  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  if (defaultTargetPlatform == TargetPlatform.android) {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      importance: Importance.max,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  if (defaultTargetPlatform == TargetPlatform.iOS) {
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const DarwinInitializationSettings initializationSettingsIOS =
      DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
  );

  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    RemoteNotification? notification = message.notification;

    AndroidNotification? android = message.notification?.android;

    if (notification != null && android != null && !kIsWeb) {
      flutterLocalNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'High Importance Notifications',
            icon: android.smallIcon,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
      );
    }

    _showInAppNotificationDialog(message);
  });

  FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationNavigation);

  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(user.uid)
            .update({'fcmToken': newToken});

        // ignore: empty_catches
      } catch (e) {}
    }
  });
}

void _showInAppNotificationDialog(RemoteMessage message) {
  final context = rootNavigatorKey.currentContext;

  if (context != null && context.mounted) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color.fromARGB(254, 255, 249, 255),
        title: Text(message.notification?.title ?? 'Notificación',
            style: const TextStyle(
                color: Color.fromRGBO(17, 48, 73, 1),
                fontWeight: FontWeight.bold)),
        content: Text(message.notification?.body ?? 'Sin contenido',
            style: const TextStyle(color: Color.fromRGBO(17, 48, 73, 1))),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();

              if (!kIsWeb) {
                await Future.delayed(const Duration(milliseconds: 100));
              }

              _handleNotificationNavigation(message);
            },
            child: const Text('Ver',
                style: TextStyle(
                    color: Color.fromRGBO(17, 48, 73, 1),
                    fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cerrar', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 🔥 NUEVO: Configurar ErrorWidget.builder para capturar errores en el árbol de widgets

    ErrorWidget.builder = (FlutterErrorDetails errorDetails) {
      return Material(
        child: Container(
          color: Colors.white,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SelectableText(
                'Error en la interfaz:\n${errorDetails.exception}',
                style: const TextStyle(color: Colors.red, fontSize: 16),
              ),
            ),
          ),
        ),
      );
    };

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => BookingProvider()),
      ],
      child: MaterialApp.router(
        routerConfig: appRouter,
        title: 'Biqoe',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primaryColor: const Color.fromRGBO(17, 48, 73, 1),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color.fromARGB(255, 255, 255, 255),
            primary: const Color.fromRGBO(17, 48, 73, 1),
          ),
          useMaterial3: true,
        ),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('es', 'ES')],
        builder: (context, child) {
          final mq = MediaQuery.of(context);

          return MediaQuery(
            data: mq.copyWith(textScaler: const TextScaler.linear(1.0)),
            child: child ?? const SizedBox.shrink(),
          );
        },
      ),
    );
  }
}
