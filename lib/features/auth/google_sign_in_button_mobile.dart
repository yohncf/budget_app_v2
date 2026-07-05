import 'package:flutter/material.dart';

/// Mobile/Android implementation of Google Sign-in button.
///
/// **Why it exists**: Renders our custom Material Design 3 outlined button.
/// When tapped, it triggers the interactive native sign-in flow.
Widget buildGoogleSignInButton({
  required VoidCallback onPressedMobile,
  required Function(String idToken) onWebSignInSuccess,
  required Function(String error) onError,
}) {
  return OutlinedButton.icon(
    onPressed: onPressedMobile,
    style: OutlinedButton.styleFrom(
      foregroundColor: Colors.white,
      side: const BorderSide(color: Colors.white24),
      padding: const EdgeInsets.symmetric(vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    icon: const Icon(Icons.login, color: Colors.white, size: 16),
    label: const Text('Sign in with Google', style: TextStyle(fontWeight: FontWeight.w500)),
  );
}
