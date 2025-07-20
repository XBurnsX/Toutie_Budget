import 'package:firebase_auth/firebase_auth.dart';
import 'package:pocketbase/pocketbase.dart';
import 'firebase_service.dart';
import 'pocketbase_service.dart';
import '../pocketbase_config.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseService _firebaseService = FirebaseService();

  bool _isPocketBaseInitialized = false;

  // Initialisation
  Future<void> initialize() async {
    try {
      // Utiliser le nouveau système intelligent
      await PocketBaseService.instance;
      _isPocketBaseInitialized = true;
      print('✅ AuthService: PocketBase initialisé');
    } catch (e) {
      print('❌ AuthService: Erreur initialisation PocketBase: $e');
    }
  }

  // Authentification Google avec PocketBase
  Future<bool> signInWithGoogle() async {
    try {
      // Authentification Firebase avec Google (pour récupérer les infos)
      final userCredential = await _firebaseService.signInWithGoogle();

      if (userCredential.user != null) {
        // Créer l'utilisateur dans PocketBase avec les infos Google
        await _createUserInPocketBase(userCredential.user!);
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Erreur authentification Google: $e');
      return false;
    }
  }

  // Créer l'utilisateur dans PocketBase avec les infos Google
  Future<void> _createUserInPocketBase(User firebaseUser) async {
    try {
      final email = firebaseUser.email ?? '';
      final name = firebaseUser.displayName ?? 'Utilisateur';

      print('🔄 Création utilisateur dans PocketBase: $email ($name)');

      // Créer l'utilisateur dans PocketBase
      try {
        await PocketBaseService.signUp(
            email, 'google_auth_123', 'google_auth_123',
            data: {
              'name': name,
              'email': email,
            });
        print('✅ Utilisateur créé dans PocketBase: $email');
      } catch (e) {
        // L'utilisateur existe déjà
        print('ℹ️ Utilisateur existe déjà dans PocketBase: $email');
      }

      // Se connecter à PocketBase
      try {
        await PocketBaseService.signInWithEmail(email, 'google_auth_123');
        print('✅ Utilisateur connecté à PocketBase: $email');
      } catch (e) {
        print('❌ Erreur connexion PocketBase: $e');
      }
    } catch (e) {
      print('❌ Erreur création utilisateur PocketBase: $e');
    }
  }

  // Vérifier l'état de l'authentification
  bool get isFirebaseAuthenticated => _firebaseService.auth.currentUser != null;
  bool get isPocketBaseAuthenticated => PocketBaseService.isAuthenticated;
  bool get isAuthenticated =>
      isPocketBaseAuthenticated; // Utiliser PocketBase comme principal

  // Obtenir l'utilisateur actuel
  User? get firebaseUser => _firebaseService.auth.currentUser;
  RecordModel? get pocketBaseUser => PocketBaseService.currentUser;
  RecordModel? get currentUser =>
      pocketBaseUser; // Utiliser PocketBase comme principal

  // Streams d'authentification
  Stream<User?> get firebaseAuthStateChanges =>
      _firebaseService.authStateChanges;
  Stream<bool> get pocketBaseAuthStateChanges =>
      Stream.periodic(const Duration(milliseconds: 100), (_) {
        return PocketBaseService.isAuthenticated;
      }).distinct();
  Stream<bool> get authStateChanges =>
      pocketBaseAuthStateChanges; // Utiliser PocketBase comme principal

  // Obtenir les services
  FirebaseService get firebaseService => _firebaseService;
  Future<PocketBase> get pocketBaseService => PocketBaseService.instance;
}
