import 'package:flutter/material.dart';

/// Stub implementation of Google Sign-in button build helper.
///
/// **Why it exists**: To prevent compile-time errors on Mobile (where `dart:html`
/// or `google_sign_in_web` web-only APIs are unavailable) and Web.
/// The Dart compiler resolves this at compile-time using conditional imports.
Widget buildGoogleSignInButton({
  required VoidCallback onPressedMobile,
  required Function(String idToken) onWebSignInSuccess,
  required Function(String error) onError,
}) {
  throw UnsupportedError('Cannot create Google Sign-In button without platform check');
}
