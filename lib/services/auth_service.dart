// 📁 Chemin : lib/services/auth_service.dart
// 🔗 Dépendances : pocketbase, google_sign_in
// 📋 Description : Google Sign-In configuré SEULEMENT pour PocketBase

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
  
  // ✅ CONFIGURATION GOOGLE SIGN-IN POUR POCKETBASE SEULEMENT
  // Utilise le Client ID de ton OAuth PocketBase dans Google Console
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: '127120738889-b12hrhrrjce3gjbjdm9rhfeo5gfj9juu.apps.googleusercontent.com',
    scopes: ['email', 'profile', 'openid'],
  );

  // URLs de fallback dans l'ordre de priorité
  static const List<String> _pocketBaseUrls = [
    'http://192.168.1.77:8090', // Local WiFi
    'http://10.0.2.2:8090', // Émulateur Android
    'https://toutiebudget.duckdns.org', // Production
  ];

  // ✅ Partager l'instance PocketBase avec autres services
  static PocketBase? get pocketBaseInstance => _pocketBase;

  // Obtenir l'instance PocketBase avec fallback intelligent
  static Future<PocketBase> _getPocketBaseInstance() async {
    print('🔄 ========== OBTENTION INSTANCE POCKETBASE ==========');
    
    if (_pocketBase != null) {
      print('✅ Instance PocketBase existante trouvée');
      print('🔗 URL actuelle: ${_pocketBase!.baseUrl}');
      return _pocketBase!;
    }

    print('🆕 Création nouvelle instance PocketBase...');

    // Tester chaque URL dans l'ordre
    for (int i = 0; i < _pocketBaseUrls.length; i++) {
      final url = _pocketBaseUrls[i];
      print('🔍 Test connexion PocketBase: $url');

      try {
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

  // 🔥 GOOGLE SIGN-IN AVEC CONFIG POCKETBASE SEULEMENT
  static Future<RecordModel?> signInWithGoogle() async {
    print('');
    print('🚀 ========================================');
    print('🚀 GOOGLE SIGN-IN POCKETBASE CONFIG ONLY');
    print('🚀 ========================================');
    
    try {
      // ÉTAPE 1: Google Sign-In avec le Client ID PocketBase
      print('');
      print('🔐 ========== ÉTAPE 1: GOOGLE SIGN-IN ==========');
      print('🆔 Client ID utilisé: 127120738889-b12hrhrrjce3gjbjdm9rhfeo5gfj9juu');
      print('🎯 Scopes: email, profile, openid');
      
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        print('❌ Utilisateur a annulé la connexion Google');
        return null;
      }

      print('✅ Google Sign-In réussi !');
      print('👤 Email: ${googleUser.email}');
      print('📛 Nom: ${googleUser.displayName}');
      print('🆔 Google ID: ${googleUser.id}');
      print('🖼️ Avatar: ${googleUser.photoUrl}');

      // ÉTAPE 2: Obtenir les tokens Google
      print('');
      print('🔑 ========== ÉTAPE 2: TOKENS GOOGLE ==========');
      
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      print('🔑 Access Token présent: ${googleAuth.accessToken != null}');
      print('🔑 ID Token présent: ${googleAuth.idToken != null}');
      
      if (googleAuth.accessToken != null) {
        print('🔑 Access Token (premiers 30): ${googleAuth.accessToken!.substring(0, 30)}...');
        print('🔑 Access Token longueur: ${googleAuth.accessToken!.length}');
      }
      
      if (googleAuth.idToken != null) {
        print('🔑 ID Token (premiers 30): ${googleAuth.idToken!.substring(0, 30)}...');
        print('🔑 ID Token longueur: ${googleAuth.idToken!.length}');
      }

      // ÉTAPE 3: Sync avec PocketBase
      print('');
      print('🗃️ ========== ÉTAPE 3: SYNC POCKETBASE ==========');
      
      final pb = await _getPocketBaseInstance();
      print('✅ Instance PocketBase obtenue');

      try {
        // Vérifier si l'utilisateur existe déjà
        print('🔍 Recherche utilisateur existant...');
        final existingUsers = await pb.collection('users').getList(
          filter: 'email = "${googleUser.email}"',
          perPage: 1,
        );
        
        if (existingUsers.items.isNotEmpty) {
          // Utilisateur existant
          final user = existingUsers.items.first;
          print('✅ Utilisateur existant trouvé: ${user.id}');
          print('📧 Email: ${user.data['email']}');
          print('📛 Nom: ${user.data['name']}');
          
          // Mettre à jour les infos
          print('🔄 Mise à jour des informations utilisateur...');
          final updatedUser = await pb.collection('users').update(user.id, body: {
            'name': googleUser.displayName ?? user.data['name'],
            'avatar': googleUser.photoUrl ?? user.data['avatar'],
            'googleId': googleUser.id,
            'lastLogin': DateTime.now().toIso8601String(),
          });
          
          print('✅ Informations utilisateur mises à jour');
          
          // Sauvegarder la session avec le token Google
          print('💾 Sauvegarde session PocketBase...');
          pb.authStore.save(googleAuth.accessToken!, updatedUser);
          
          print('✅ Session utilisateur existant configurée');
          print('🔒 AuthStore valide: ${pb.authStore.isValid}');
          
          return updatedUser;
          
        } else {
          // Nouvel utilisateur
          print('🆕 Création nouvel utilisateur PocketBase...');
          
          final newUser = await pb.collection('users').create(body: {
            'email': googleUser.email,
            'name': googleUser.displayName ?? 'Utilisateur',
            'avatar': googleUser.photoUrl ?? '',
            'emailVisibility': true,
            'verified': true,
            'provider': 'google',
            'googleId': googleUser.id,
            'createdAt': DateTime.now().toIso8601String(),
            'lastLogin': DateTime.now().toIso8601String(),
          });
          
          print('✅ Nouvel utilisateur créé: ${newUser.id}');
          print('📧 Email: ${newUser.data['email']}');
          print('📛 Nom: ${newUser.data['name']}');
          
          // Sauvegarder la session avec le token Google
          print('💾 Sauvegarde session PocketBase...');
          pb.authStore.save(googleAuth.accessToken!, newUser);
          
          print('✅ Session nouvel utilisateur configurée');
          print('🔒 AuthStore valide: ${pb.authStore.isValid}');
          
          return newUser;
        }
        
      } catch (e) {
        print('❌ Erreur sync PocketBase: $e');
        print('🔍 Type erreur: ${e.runtimeType}');
        throw e;
      }

    } catch (e, stackTrace) {
      print('');
      print('💥 ========== ERREUR AUTHENTIFICATION ==========');
      print('❌ Erreur: $e');
      print('🔍 Type: ${e.runtimeType}');
      
      // Debug spécifique pour ApiException
      if (e.toString().contains('ApiException: 10')) {
        print('');
        print('🔧 ========== DEBUG APIEXCEPTION 10 ==========');
        print('💡 ApiException 10 = DEVELOPER_ERROR');
        print('🔍 Causes possibles:');
        print('   1. Client ID incorrect ou non configuré');
        print('   2. SHA-1 fingerprint manquant/incorrect');
        print('   3. Package name incorrect');
        print('   4. Restriction d\'application mal configurée');
        print('');
        print('📋 Configuration actuelle:');
        print('   🆔 Client ID: 127120738889-b12hrhrrjce3gjbjdm9rhfeo5gfj9juu');
        print('   📦 Package: com.xburnsx.toutie_budget');
        print('   🔐 SHA-1 requis dans Google Console');
        print('');
        print('🔧 Actions à vérifier:');
        print('   1. Ajouter SHA-1 debug dans Google Console');
        print('   2. Vérifier que le Client ID est activé');
        print('   3. Vérifier les restrictions d\'app');
      }
      
      rethrow;
    }
  }

  // Déconnexion
  static Future<void> signOut() async {
    print('🚪 ========== DÉCONNEXION ==========');
    
    try {
      print('🔓 Déconnexion Google Sign-In...');
      await _googleSignIn.signOut();
      print('✅ Google Sign-In déconnecté');

      if (_pocketBase != null) {
        print('🧹 Nettoyage AuthStore PocketBase...');
        _pocketBase!.authStore.clear();
        print('✅ AuthStore PocketBase vidé');
      }

      print('✅ Déconnexion complète réussie');
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