// 📁 Chemin : lib/services/auth_service.dart
// 🔗 Dépendances : pocketbase_service.dart, pocketbase_config.dart
// 📋 Description : Service d'authentification PocketBase avec instance partagée

import 'package:pocketbase/pocketbase.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:io';

import 'pocketbase_service.dart';
import '../pocketbase_config.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  static PocketBase? _pocketBase;
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  // URLs de fallback dans l'ordre de priorité
  static const List<String> _pocketBaseUrls = [
    'http://192.168.1.77:8090', // Local WiFi
    'http://10.0.2.2:8090', // Émulateur Android
    'https://toutiebudget.duckdns.org', // Production
  ];

  // ✅ NOUVELLE MÉTHODE : Partager l'instance PocketBase avec autres services
  static PocketBase? get pocketBaseInstance => _pocketBase;

  // Obtenir l'instance PocketBase avec fallback intelligent
  static Future<PocketBase> _getPocketBaseInstance() async {
    if (_pocketBase != null) return _pocketBase!;

    // Tester chaque URL dans l'ordre
    for (final url in _pocketBaseUrls) {
      try {
        print('🔍 Test connexion PocketBase: $url');

        // Test de connectivité
        final response = await http.get(Uri.parse('$url/api/health')).timeout(
              const Duration(seconds: 3),
            );

        if (response.statusCode == 200) {
          print('✅ Connexion PocketBase réussie: $url');
          _pocketBase = PocketBase(url);
          return _pocketBase!;
        }
      } catch (e) {
        print('❌ Échec connexion PocketBase: $url - $e');
        continue;
      }
    }

    throw Exception('❌ Aucune connexion PocketBase disponible');
  }

  // Utiliser l'authentification Google NATIVE de PocketBase
  static Future<RecordModel?> signInWithGoogle() async {
    try {
      print('🔐 Connexion Google NATIVE PocketBase...');

      final pb = await _getPocketBaseInstance();

      // Utiliser l'OAuth Google intégré de PocketBase !
      final authData = await pb.collection('users').authWithOAuth2('google', (url) async {
        print('🔗 URL OAuth Google: $url');
        
        // PocketBase va gérer l'OAuth Google automatiquement !
        // L'utilisateur sera redirigé vers Google puis de retour vers l'app
      });

      print('✅ Authentification Google PocketBase réussie !');
      print('🔐 Utilisateur: ${authData.record.data['email']}');
      print('🔐 Nom: ${authData.record.data['name']}');

      return authData.record;
    } catch (e) {
      print('❌ Erreur Google OAuth PocketBase: $e');
      rethrow;
    }
  }

  // Déconnexion
  static Future<void> signOut() async {
    try {
      print('🚪 Déconnexion...');

      // Déconnexion Google
      await _googleSignIn.signOut();

      // Déconnexion PocketBase
      if (_pocketBase != null) {
        _pocketBase!.authStore.clear();
      }

      print('✅ Déconnexion réussie');
    } catch (e) {
      print('❌ Erreur déconnexion: $e');
    }
  }

  // Stream des changements d'authentification
  static Stream<RecordModel?> get authStateChanges {
    return Stream.periodic(const Duration(seconds: 1), (_) {
      return _pocketBase?.authStore.model;
    }).distinct().cast<RecordModel?>();
  }

  // Utilisateur actuel
  static RecordModel? get currentUser {
    return _pocketBase?.authStore.model;
  }

  // Vérifier si connecté
  static bool get isSignedIn {
    return _pocketBase?.authStore.isValid ?? false;
  }

  // Obtenir l'ID utilisateur
  static String? get currentUserId {
    return _pocketBase?.authStore.model?.id;
  }

  // Obtenir l'email utilisateur
  static String? get currentUserEmail {
    return _pocketBase?.authStore.model?.data['email'];
  }

  // Obtenir le nom utilisateur
  static String? get currentUserName {
    return _pocketBase?.authStore.model?.data['name'];
  }
}