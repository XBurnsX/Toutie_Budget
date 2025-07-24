// 📁 Chemin : lib/services/auth_service_firebase.dart
// 🔗 Dépendances : firebase_auth.dart, google_sign_in.dart
// 📋 Description : Service d'authentification Firebase temporaire

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthServiceFirebase {
  static final AuthServiceFirebase _instance = AuthServiceFirebase._internal();
  factory AuthServiceFirebase() => _instance;
  AuthServiceFirebase._internal();

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Connexion avec Google
  static Future<UserCredential?> signInWithGoogle() async {
    try {

      // 1. Authentification Google
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return null;
      }

      // 2. Obtenir les tokens Google
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final String? accessToken = googleAuth.accessToken;
      final String? idToken = googleAuth.idToken;

      if (accessToken == null || idToken == null) {
        return null;
      }


      // 3. Connexion Firebase avec Google
      final credential = GoogleAuthProvider.credential(
        accessToken: accessToken,
        idToken: idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  // Déconnexion
  static Future<void> signOut() async {
    try {

      // Déconnexion Google
      await _googleSignIn.signOut();

      // Déconnexion Firebase
      await _auth.signOut();

    } catch (e) {
    }
  }

  // Stream des changements d'authentification
  static Stream<User?> get authStateChanges {
    return _auth.authStateChanges();
  }

  // Utilisateur actuel
  static User? get currentUser {
    return _auth.currentUser;
  }

  // Vérifier si connecté
  static bool get isSignedIn {
    return _auth.currentUser != null;
  }

  // Obtenir l'ID utilisateur
  static String? get currentUserId {
    return _auth.currentUser?.uid;
  }

  // Obtenir l'email utilisateur
  static String? get currentUserEmail {
    return _auth.currentUser?.email;
  }

  // Obtenir le nom utilisateur
  static String? get currentUserName {
    return _auth.currentUser?.displayName;
  }
}
