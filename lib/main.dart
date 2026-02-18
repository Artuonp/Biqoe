import 'dart:async';
// import 'dart:io'; // Mantenemos comentado o eliminado para compatibilidad Web

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

import 'firebase_options.dart';
import 'booking_provider.dart';
import 'config/router/app_router.dart'; // Asegúrate que esta ruta sea correcta

final Logger logger = Logger();

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// Handler de Background (Notificaciones en segundo plano)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  logger.i(
      'Notificación recibida en segundo plano: ${message.notification?.title}');
}

// LÓGICA DE NAVEGACIÓN POR NOTIFICACIONES
void _handleNotificationNavigation(RemoteMessage message) {
  final user = FirebaseAuth.instance.currentUser;

  if (user != null) {
    final data = message.data;
    final String? screen = data['screen'];
    // final String? rol = data['rol']; // Ya no es estrictamente necesario si usamos 'screen'

    // 1. Redirección al Dashboard de Proveedor
    if (screen == 'dashboard') {
      // CORRECCIÓN IMPORTANTE: La ruta en app_router.dart es '/supplier/dashboard'
      appRouter.go('/supplier/dashboard');
      return;
    }

    // 2. Fallbacks (Lógica antigua por si acaso)
    if (screen == 'verify') {
      // Mantener compatibilidad con posibles notificaciones viejas
      appRouter.push('/supplier/verify');
    }
  }
}

Future<void> main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Configuración Web (URLs limpias sin # si el server lo soporta)
    usePathUrlStrategy();

    // Configuración de Notificaciones Background
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Manejo de Errores Globales
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      logger.e('FlutterError: ${details.exceptionAsString()}');
      if (details.stack != null) {
        logger.e(details.stack.toString());
      }
    };

    // Orientación Vertical (Solo bloquear en móviles, Web libre)
    if (!kIsWeb) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }

    // Inicializar Firebase
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    // Inicializar Hive
    await Hive.initFlutter();
    await Hive.openBox<Map>('saved_destinations');

    // Configuración de Notificaciones Locales y Canales
    await _setupNotifications();

    // IMPORTANTE: Manejo de notificación inicial (Cold Start en Móvil)
    if (!kIsWeb) {
      FirebaseMessaging.instance
          .getInitialMessage()
          .then((RemoteMessage? message) {
        if (message != null) {
          _handleNotificationNavigation(message);
        }
      });
    }

    runApp(const MyApp());
  }, (error, stack) {
    logger.e('Error fuera de zona: $error');
    logger.e(stack.toString());
  });
}

Future<void> _setupNotifications() async {
  // Si es Web, evitamos configuraciones nativas complejas por ahora
  if (kIsWeb) {
    return;
  }

  // Solicitar permisos explícitos (Crítico para iOS 10+)
  NotificationSettings settings =
      await FirebaseMessaging.instance.requestPermission(
    alert: true,
    announcement: false,
    badge: true,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
    sound: true,
  );

  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    logger.i('Permiso de notificaciones concedido');
  } else {
    logger.w('Permiso de notificaciones denegado');
  }

  // --- CONFIGURACIÓN SOLO PARA MÓVILES (Android/iOS) ---

  // Configuración Android Channel
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

  // Configuración iOS Foreground
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  // Inicialización Local Notifications
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

  await flutterLocalNotificationsPlugin.initialize(initializationSettings,
      // Callback cuando se toca la notificación local (Foreground)
      onDidReceiveNotificationResponse: (NotificationResponse response) {
    // Aquí es difícil pasar el payload completo del RemoteMessage original
    // Idealmente, usa onMessageOpenedApp para background.
    // Para foreground, podrías guardar el payload en una variable global o manejarlo aquí si tienes datos simples.
  });

  // Escuchar mensajes en primer plano
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    // Mostrar notificación nativa (Pop-up del sistema) solo en móvil
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

    // Mostrar diálogo dentro de la app (Funciona en Web y Móvil)
    // Opcional: Puedes quitar esto si prefieres solo la notificación de sistema
    _showInAppNotificationDialog(message);
  });

  // Escuchar cuando se abre la app desde notificación en segundo plano
  FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationNavigation);

  // Refresco de Token
  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(user.uid)
            .update(
                {'fcmToken': newToken}); // CAMBIO: Usamos 'fcmToken' estándar
        logger.i('Token actualizado en Firestore: $newToken');
      } catch (e) {
        logger.e('Error al actualizar el token en Firestore: $e');
      }
    }
  });
}

// Diálogo de notificación dentro de la app (In-App Alert)
void _showInAppNotificationDialog(RemoteMessage message) {
  // Obtenemos el contexto actual desde el Router
  final context = rootNavigatorKey.currentContext;

  if (context != null && context.mounted) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color.fromARGB(254, 255, 249, 255),
        title: Text(
          message.notification?.title ?? 'Notificación',
          style: const TextStyle(
            color: Color.fromRGBO(17, 48, 73, 1),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          message.notification?.body ?? 'Sin contenido',
          style: const TextStyle(
            color: Color.fromRGBO(17, 48, 73, 1),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              // Pequeña espera en móvil para suavizar la transición
              if (!kIsWeb) {
                await Future.delayed(const Duration(milliseconds: 100));
              }
              _handleNotificationNavigation(message);
            },
            child: const Text(
              'Ver',
              style: TextStyle(
                color: Color.fromRGBO(17, 48, 73, 1),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
            },
            child: const Text(
              'Cerrar',
              style: TextStyle(color: Colors.grey),
            ),
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
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => BookingProvider(),
        ),
      ],
      // USAMOS MaterialApp.router PARA INTEGRAR GO_ROUTER
      child: MaterialApp.router(
        routerConfig: appRouter, // Aquí conectamos el router
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
        supportedLocales: const [
          Locale('es', 'ES'),
        ],
        builder: (context, child) {
          // Aseguramos que el tamaño del texto no se escale excesivamente
          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: mq.copyWith(textScaler: const TextScaler.linear(1.0)),
            child: child!,
          );
        },
      ),
    );
  }
}
