import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({super.key});

  Future<UserCredential> signInWithGoogle() async {
    // Trigger the authentication flow
    final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

    // Obtain the auth details from the request
    final GoogleSignInAuthentication? googleAuth = await googleUser?.authentication;

    // Create a new credential
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth?.accessToken,
      idToken: googleAuth?.idToken,
    );

    // Once signed in, return the UserCredential
    return await FirebaseAuth.instance.signInWithCredential(credential);
  }

  @override
  Widget build(BuildContext context)  {
    return ElevatedButton.icon(
      icon: const Icon(Icons.login),
      label: const Text('Sign in with Google'),
      onPressed: () async {
        try {
          await signInWithGoogle();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Signed in with Google!')),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to sign in: $e')),
          );
        }
      },
    );
  }
}