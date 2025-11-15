import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'config/api_config.dart';
import 'screens/splash_screen.dart';
import 'services/auth_service.dart';
import 'services/cache_service.dart';
import 'services/notification_service.dart';
import 'services/fcm_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize cache service
  await CacheService().init();

  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('Failed to load .env: $e');
  }

  // Initialize Firebase
  await Firebase.initializeApp();

  await Supabase.initialize(
    url: ApiConfig.supabaseUrl,
    anonKey: ApiConfig.supabaseAnonKey,
  );

  AuthService().setupAuthListener();

  // Initialize Firebase Cloud Messaging
  await FCMService().initialize();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _notificationService = NotificationService();
  final _fcmService = FCMService();

  @override
  void initState() {
    super.initState();
    _notificationService.initialize();
  }

  @override
  void dispose() {
    _notificationService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _fcmService.navigatorKey,
      title: 'Megg',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.black,
          primary: Colors.black,
          secondary: Colors.grey[800]!,
        ),
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'FuturaCyrillicBook',
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            fontFamily: 'FuturaCyrillicBook',
            fontSize: 48,
            fontWeight: FontWeight.w300,
            letterSpacing: 8,
          ),
          displayMedium: TextStyle(
            fontFamily: 'FuturaCyrillicBook',
            fontSize: 32,
            fontWeight: FontWeight.w300,
            letterSpacing: 2,
          ),
          displaySmall: TextStyle(
            fontFamily: 'FuturaCyrillicBook',
            fontSize: 24,
            fontWeight: FontWeight.w400,
            letterSpacing: 1,
          ),
          headlineLarge: TextStyle(
            fontFamily: 'FuturaCyrillicBook',
            fontSize: 22,
            fontWeight: FontWeight.w400,
            letterSpacing: 1,
          ),
          headlineMedium: TextStyle(
            fontFamily: 'FuturaCyrillicBook',
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
          headlineSmall: TextStyle(
            fontFamily: 'FuturaCyrillicBook',
            fontSize: 18,
            fontWeight: FontWeight.w400,
            letterSpacing: 2,
          ),
          titleLarge: TextStyle(
            fontFamily: 'FuturaCyrillicBook',
            fontSize: 16,
            fontWeight: FontWeight.w500,
            letterSpacing: 2,
          ),
          titleMedium: TextStyle(
            fontFamily: 'FuturaCyrillicBook',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 2,
          ),
          titleSmall: TextStyle(
            fontFamily: 'FuturaCyrillicBook',
            fontSize: 13,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.5,
          ),
          bodyLarge: TextStyle(
            fontFamily: 'FuturaCyrillicBook',
            fontSize: 14,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.3,
          ),
          bodyMedium: TextStyle(
            fontFamily: 'FuturaCyrillicBook',
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          bodySmall: TextStyle(
            fontFamily: 'FuturaCyrillicBook',
            fontSize: 12,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.5,
          ),
          labelLarge: TextStyle(
            fontFamily: 'FuturaCyrillicBook',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 2,
          ),
          labelMedium: TextStyle(
            fontFamily: 'FuturaCyrillicBook',
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 1,
          ),
          labelSmall: TextStyle(
            fontFamily: 'FuturaCyrillicBook',
            fontSize: 11,
            fontWeight: FontWeight.w500,
            letterSpacing: 1,
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.black),
          titleTextStyle: TextStyle(
            fontFamily: 'FuturaCyrillicBook',
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w400,
            letterSpacing: 2,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            textStyle: const TextStyle(
              fontFamily: 'FuturaCyrillicBook',
              letterSpacing: 2,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            textStyle: const TextStyle(
              fontFamily: 'FuturaCyrillicBook',
              letterSpacing: 1.5,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          selectedLabelStyle: TextStyle(
            fontFamily: 'FuturaCyrillicBook',
            letterSpacing: 1,
            fontWeight: FontWeight.w500,
          ),
          unselectedLabelStyle: TextStyle(
            fontFamily: 'FuturaCyrillicBook',
            letterSpacing: 1,
          ),
        ),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}
