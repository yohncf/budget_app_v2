import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:google_sign_in/google_sign_in.dart';
import 'core/config/supabase_config.dart';
import 'firebase_options.dart';
import 'features/auth/login_page.dart';
import 'features/navigation/main_layout.dart';
import 'package:google_fonts/google_fonts.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    print('Firebase initialization error: $e');
  }

  // Initialize Google Sign In (required for Web authentication)
  try {
    await GoogleSignIn.instance.initialize(
      clientId: '1006598018185-0jjngun0qctjsbrs3fat1441hf9vrlu8.apps.googleusercontent.com',
    );
    print('Google Sign-In initialized successfully.');
  } catch (e) {
    print('Google Sign-In initialization failed: $e');
  }

  // Initialize Supabase
  try {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
      headers: {
        'x-app-secure-key': SupabaseConfig.appSecretHeader,
      },
    );
    print('Supabase initialized successfully.');
    
    // Perform immediate connection and query diagnostics check
    try {
      final testAccounts = await Supabase.instance.client.from('accounts').select();
      print('SUPABASE DIAGNOSTICS: Connection successful! Table "accounts" returned ${testAccounts.length} rows.');
    } catch (queryErr) {
      print('SUPABASE DIAGNOSTICS: Connection check failed to query table "accounts". Details: $queryErr');
    }
  } catch (e) {
    print('Supabase initialization failed: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isBypassed = false;

  @override
  Widget build(BuildContext context) {
    // Premium custom Dark Theme following Material Design 3 and branding colors
    final darkTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: GoogleFonts.roboto().fontFamily,
      scaffoldBackgroundColor: const Color(0xFF030303), // Always App Background #030303
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF96CC28), // Primary Lime #96CC28
        secondary: Color(0xFF5E2CE4), // Deep Purple #5E2CE4
        tertiary: Color(0xFF0717ED), // Vibrant Blue #0717ED
        surface: Color(0xFF0E0E0E), // Cards Background #0E0E0E
        error: Color(0xFFDB1F87), // Error Messages #DB1F87
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF0E0E0E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF0E0E0E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF030303),
        elevation: 0,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF030303),
        labelStyle: const TextStyle(color: Colors.white),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF96CC28),
          foregroundColor: const Color(0xFF09090B),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF96CC28),
          side: const BorderSide(color: Color(0xFF96CC28), width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF96CC28),
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );

    return MaterialApp(
      title: 'Antigravity Budget',
      theme: darkTheme,
      debugShowCheckedModeBanner: false,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          final user = snapshot.data;
          
          if (user != null || _isBypassed) {
            return MainLayout(
              onLogout: () {
                setState(() {
                  _isBypassed = false;
                });
              },
            );
          }

          return LoginPage(
            onLoginSuccess: () {
              // Firebase Auth automatically updates the stream
            },
            onBypass: () {
              setState(() {
                _isBypassed = true;
              });
            },
          );
        },
      ),
    );
  }
}
