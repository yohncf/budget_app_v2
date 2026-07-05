import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
// ignore: depend_on_referenced_packages
import 'package:google_sign_in_web/web_only.dart' as web;

/// Web implementation of Google Sign-in button.
///
/// **Why it exists**: The Google Identity Services (GIS) SDK on Web requires
/// the sign-in widget to be rendered by Google's SDK inside an iframe.
/// This widget renders `web.renderButton()` and listens to the login events
/// stream to extract the user's OpenID Connect `idToken`.
Widget buildGoogleSignInButton({
  required VoidCallback onPressedMobile,
  required Function(String idToken) onWebSignInSuccess,
  required Function(String error) onError,
}) {
  return WebGoogleSignInButton(
    onWebSignInSuccess: onWebSignInSuccess,
    onError: onError,
  );
}

class WebGoogleSignInButton extends StatefulWidget {
  final Function(String idToken) onWebSignInSuccess;
  final Function(String error) onError;

  const WebGoogleSignInButton({
    super.key,
    required this.onWebSignInSuccess,
    required this.onError,
  });

  @override
  State<WebGoogleSignInButton> createState() => _WebGoogleSignInButtonState();
}

class _WebGoogleSignInButtonState extends State<WebGoogleSignInButton> {
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    // Start listening to the broadcast sign-in events stream
    _subscription = GoogleSignIn.instance.authenticationEvents.listen(
      (event) {
        if (event is GoogleSignInAuthenticationEventSignIn) {
          try {
            // Retrieve authentication details from Google session
            final googleAuth = event.user.authentication;
            final idToken = googleAuth.idToken;
            if (idToken != null) {
              widget.onWebSignInSuccess(idToken);
            } else {
              widget.onError('Google Sign-In succeeded, but no ID token was retrieved.');
            }
          } catch (e) {
            widget.onError('Failed to extract Google credentials: $e');
          }
        }
      },
      onError: (err) {
        widget.onError('Google Auth stream error: $err');
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Renders the official GIS button.
    // Inside, it builds a platform view embedding Google's javascript button.
    return SizedBox(
      height: 48,
      child: Center(
        child: web.renderButton(),
      ),
    );
  }
}
