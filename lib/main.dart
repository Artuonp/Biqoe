import 'package:biqoe/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'splash_screen.dart';
import 'main_screen.dart';
import 'search_screen.dart';
import 'booking_provider.dart';
import 'package:logger/logger.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'verify_screen.dart';
import 'supplier_verify_screen.dart';
import 'dart:async';

final List<String> destinations = [
  'Destino 1',
  'Destino 2',
  'Destino 3',
];

final Logger logger = Logger();
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  logger.i(
      'Notificación recibida en segundo plano: ${message.notification?.title}');
  _handleNotificationNavigation(message);
}

void _handleNotificationNavigation(RemoteMessage message) async {
  final user = FirebaseAuth.instance.currentUser;
  final rol = message.data['rol'];

  if (user == null) {
    navigatorKey.currentState?.pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
    return;
  }

  final userId = user.uid;

  if (rol == 'supplier') {
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => SupplierVerifyScreen(userId: userId)),
    );
  } else if (rol == 'admin') {
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => VerifyScreen(userId: userId)),
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    ErrorScreen.show(details.exceptionAsString(), details.stack?.toString());
  };

  runZonedGuarded(() async {
    try {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);

      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }

      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings();

      final InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS, // <-- Agrega esto
      );

      await flutterLocalNotificationsPlugin.initialize(initializationSettings);

      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);
      await Hive.initFlutter();
      await Hive.openBox<Map>('saved_destinations');

      setupFirebaseMessaging();

      FirebaseMessaging.instance
          .getInitialMessage()
          .then((RemoteMessage? message) {
        if (message != null) {
          _handleNotificationNavigation(message);
        }
      });

      runApp(MyApp(destinations: destinations));
    } catch (e, stack) {
      runApp(ErrorScreen(message: e.toString(), stack: stack.toString()));
    }
  }, (error, stack) {
    runApp(ErrorScreen(message: error.toString(), stack: stack.toString()));
  });
}

void setupFirebaseMessaging() {
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    importance: Importance.max,
  );

  flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null && android != null) {
      flutterLocalNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            icon: android.smallIcon,
          ),
        ),
      );
    }

    // Mostrar el diálogo de notificación en cualquier pantalla
    final context = navigatorKey.currentContext;
    if (context != null && context.mounted) {
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: Colors.white,
          title: Text(
            notification?.title ?? 'Notificación',
            style: const TextStyle(
              color: Color.fromRGBO(17, 48, 73, 1),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            notification?.body ?? 'Sin contenido',
            style: const TextStyle(
              color: Color.fromRGBO(17, 48, 73, 1),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await Future.delayed(const Duration(milliseconds: 100));

                // Lógica para manejar la navegación según el rol
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  final userId = user.uid;
                  final rol = message.data['rol'];
                  if (rol == 'supplier') {
                    navigatorKey.currentState?.push(
                      MaterialPageRoute(
                        builder: (context) =>
                            SupplierVerifyScreen(userId: userId),
                      ),
                    );
                  } else if (rol == 'admin') {
                    navigatorKey.currentState?.push(
                      MaterialPageRoute(
                        builder: (context) => VerifyScreen(userId: userId),
                      ),
                    );
                  }
                }
              },
              child: const Text(
                'Ok',
                style: TextStyle(
                  color: Color.fromRGBO(17, 48, 73, 1),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    }
  });

  FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationNavigation);

  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(user.uid)
            .update({'deviceToken': newToken});
        logger.i('Token actualizado en Firestore: $newToken');
      } catch (e) {
        logger.e('Error al actualizar el token en Firestore: $e');
      }
    }
  });
}

class MyApp extends StatelessWidget {
  final List<String> destinations;

  const MyApp({super.key, required this.destinations});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => BookingProvider(),
        ),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'biqoe',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        builder: (context, child) {
          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: mq.copyWith(textScaler: TextScaler.linear(1.0)),
            child: child!,
          );
        },
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('es', 'ES'),
        ],
        home: SplashWrapper(destinations: destinations),
      ),
    );
  }
}

class SplashWrapper extends StatefulWidget {
  final List<String> destinations;

  const SplashWrapper({super.key, required this.destinations});

  @override
  SplashWrapperState createState() => SplashWrapperState();
}

class SplashWrapperState extends State<SplashWrapper> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) =>
                AuthWrapper(destinations: widget.destinations),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const SplashScreen();
  }
}

class AuthWrapper extends StatelessWidget {
  final List<String> destinations;

  const AuthWrapper({super.key, required this.destinations});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        } else if (snapshot.hasData) {
          final userId = snapshot.data?.uid ?? '';
          return SearchScreen(
            destinations: destinations,
            userId: userId,
          );
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}

class ErrorScreen extends StatelessWidget {
  final String message;
  final String? stack;
  static void show(String message, String? stack) {
    runApp(ErrorScreen(message: message, stack: stack));
  }

  const ErrorScreen({super.key, required this.message, this.stack});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '¡Error en la app!',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: const TextStyle(color: Colors.black, fontSize: 16),
                ),
                if (stack != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    stack!,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
