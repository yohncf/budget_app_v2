import 'package:flutter/material.dart';
import 'package:budget_app_v2/core/config/app_colors.dart';
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
      scaffoldBackgroundColor: AppColors.background, // Always App Background #030303
      colorScheme: const ColorScheme.dark(
        primary: AppColors.limeMoss, // Lime Moss #7DAC20
        secondary: AppColors.googleBlue, // Google Blue #4285F4
        tertiary: AppColors.lavenderPurple, // Lavender purple #9272BF
        surface: AppColors.card, // Cards Background #0E0E0E
        error: AppColors.cinnabar, // Cinnabar #E3647F
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.background,
        labelStyle: const TextStyle(color: Colors.white),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.limeMoss,
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
          foregroundColor: AppColors.limeMoss,
          side: const BorderSide(color: AppColors.limeMoss, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.limeMoss,
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
