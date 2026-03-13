import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'utils/theme.dart';
import 'screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Suppress the known Flutter Web keyboard modifier assertion bug
  if (kIsWeb) {
    FlutterError.onError = (FlutterErrorDetails details) {
      final msg = details.exceptionAsString();
      if (msg.contains('keysPressed') ||
          msg.contains('Attempted to send a key down event when no keys are in keysPressed')) {
        return; // silently ignore
      }
      FlutterError.presentError(details);
    };
  }
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: AppTheme.lCardBg,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AutoDiagno - AI Car Service',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light, // Set to light as requested
      home: const SplashScreen(),
    );
  }
}
