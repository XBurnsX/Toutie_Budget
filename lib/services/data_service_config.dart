import 'interfaces/data_service_interface.dart';
import 'firebase_service.dart';
import 'adapters/pocketbase_adapter.dart';
import '../models/compte.dart';
import '../models/categorie.dart';
import '../models/transaction_model.dart' as app_model;
import '../models/dette.dart';

/// Service de configuration pour basculer entre Firebase et PocketBase
/// Permet de changer facilement de backend sans modifier le code métier
class DataServiceConfig {
  static DataServiceInterface? _instance;
  static bool _usePocketBase =
      false; // Flag pour basculer entre Firebase et PocketBase

  /// Obtenir l'instance du service de données configuré
  static DataServiceInterface get instance {
    _instance ??= _createService();
    return _instance!;
  }

  /// Créer le service approprié selon la configuration
  static DataServiceInterface _createService() {
    if (_usePocketBase) {
      print('🔧 DataServiceConfig: Utilisation de PocketBase');
      return PocketBaseAdapter();
    } else {
      print('🔧 DataServiceConfig: Utilisation de Firebase');
      return FirebaseAdapter();
    }
  }

  /// Basculer vers PocketBase
  static void usePocketBase() {
    print('🔄 DataServiceConfig: Basculement vers PocketBase');
    _usePocketBase = true;
    _instance = null; // Forcer la recréation de l'instance
  }

  /// Basculer vers Firebase
  static void useFirebase() {
    print('🔄 DataServiceConfig: Basculement vers Firebase');
    _usePocketBase = false;
    _instance = null; // Forcer la recréation de l'instance
  }

  /// Vérifier si PocketBase est utilisé
  static bool get isUsingPocketBase => _usePocketBase;

  /// Vérifier si Firebase est utilisé
  static bool get isUsingFirebase => !_usePocketBase;

  /// Réinitialiser l'instance (utile pour les tests)
  static void reset() {
    _instance = null;
  }
}

/// Adaptateur Firebase qui implémente l'interface DataServiceInterface
/// Wrapper autour de FirebaseService pour l'adapter à l'interface commune
class FirebaseAdapter implements DataServiceInterface {
  final FirebaseService _firebaseService = FirebaseService();

  // === COMPTES ===
  @override
  Future<List<Compte>> lireComptes() async {
    return await _firebaseService.lireComptes().first;
  }

  @override
  Future<void> ajouterCompte(Compte compte) async {
    await _firebaseService.ajouterCompte(compte);
  }

  @override
  Future<void> mettreAJourCompte(
      String compteId, Map<String, dynamic> data) async {
    await _firebaseService.updateCompte(compteId, data);
  }

  @override
  Future<void> supprimerCompte(String compteId) async {
    // TODO: Implémenter la suppression de compte dans FirebaseService
    throw UnimplementedError(
        'supprimerCompte pas encore implémenté dans FirebaseService');
  }

  // === CATÉGORIES ===
  @override
  Future<List<Categorie>> lireCategories() async {
    return await _firebaseService.lireCategories().first;
  }

  @override
  Future<void> ajouterCategorie(Categorie categorie) async {
    await _firebaseService.ajouterCategorie(categorie);
  }

  @override
  Future<void> mettreAJourCategorie(
      String categorieId, Map<String, dynamic> data) async {
    // TODO: Implémenter la mise à jour de catégorie dans FirebaseService
    throw UnimplementedError(
        'mettreAJourCategorie pas encore implémenté dans FirebaseService');
  }

  // === TRANSACTIONS ===
  @override
  Future<void> ajouterTransaction(app_model.Transaction transaction) async {
    await _firebaseService.ajouterTransaction(transaction);
  }

  @override
  Future<void> mettreAJourTransaction(app_model.Transaction transaction) async {
    await _firebaseService.mettreAJourTransaction(transaction);
  }

  @override
  Future<void> supprimerTransaction(String transactionId) async {
    // TODO: Implémenter la suppression de transaction dans FirebaseService
    throw UnimplementedError(
        'supprimerTransaction pas encore implémenté dans FirebaseService');
  }

  @override
  Future<List<app_model.Transaction>> lireTransactionsCompte(
      String compteId) async {
    // TODO: Implémenter la lecture des transactions par compte dans FirebaseService
    throw UnimplementedError(
        'lireTransactionsCompte pas encore implémenté dans FirebaseService');
  }

  // === DETTES ===
  @override
  Future<void> creerDette(Dette dette) async {
    // TODO: Implémenter la création de dette dans FirebaseService
    throw UnimplementedError(
        'creerDette pas encore implémenté dans FirebaseService');
  }

  @override
  Future<void> mettreAJourDette(
      String detteId, Map<String, dynamic> data) async {
    // TODO: Implémenter la mise à jour de dette dans FirebaseService
    throw UnimplementedError(
        'mettreAJourDette pas encore implémenté dans FirebaseService');
  }

  @override
  Future<void> ajouterMouvementDette(
      String detteId, MouvementDette mouvement) async {
    // TODO: Implémenter l'ajout de mouvement de dette dans FirebaseService
    throw UnimplementedError(
        'ajouterMouvementDette pas encore implémenté dans FirebaseService');
  }

  @override
  Future<List<Dette>> lireDettesActives() async {
    // TODO: Implémenter la lecture des dettes actives dans FirebaseService
    throw UnimplementedError(
        'lireDettesActives pas encore implémenté dans FirebaseService');
  }

  // === TIERS ===
  @override
  Future<List<String>> lireTiers() async {
    return await _firebaseService.lireTiers();
  }

  @override
  Future<void> ajouterTiers(String nomTiers) async {
    await _firebaseService.ajouterTiers(nomTiers);
  }

  // === ENVELOPPES ===
  @override
  Future<List<Map<String, dynamic>>> lireEnveloppesCategorie(
      String categorieId) async {
    // TODO: Implémenter la lecture des enveloppes par catégorie dans FirebaseService
    throw UnimplementedError(
        'lireEnveloppesCategorie pas encore implémenté dans FirebaseService');
  }

  @override
  Future<void> mettreAJourSoldeEnveloppe(String enveloppeId, double montant,
      app_model.TypeTransaction type) async {
    // TODO: Implémenter la mise à jour du solde d'enveloppe dans FirebaseService
    throw UnimplementedError(
        'mettreAJourSoldeEnveloppe pas encore implémenté dans FirebaseService');
  }

  // === AUTHENTIFICATION ===
  @override
  String? getCurrentUserId() {
    return _firebaseService.auth.currentUser?.uid;
  }

  @override
  bool get isUserConnected => _firebaseService.auth.currentUser != null;

  // === UTILITAIRES ===
  @override
  Future<void> dispose() async {
    // FirebaseService n'a pas de méthode dispose
  }
}
