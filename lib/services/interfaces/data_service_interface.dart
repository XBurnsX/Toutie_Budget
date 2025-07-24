import '../../models/compte.dart';
import '../../models/categorie.dart';
import '../../models/transaction_model.dart' as app_model;
import '../../models/dette.dart';

/// Interface commune pour les services de données
/// Permet de basculer entre Firebase et PocketBase facilement
abstract class DataServiceInterface {
  // === COMPTES ===
  /// Lire tous les comptes de l'utilisateur connecté
  Future<List<Compte>> lireComptes();

  /// Ajouter un nouveau compte
  Future<void> ajouterCompte(Compte compte);

  /// Mettre à jour un compte existant
  Future<void> mettreAJourCompte(String compteId, Map<String, dynamic> data);

  /// Supprimer un compte
  Future<void> supprimerCompte(String compteId);

  // === CATÉGORIES ===
  /// Lire toutes les catégories de l'utilisateur connecté
  Future<List<Categorie>> lireCategories();

  /// Ajouter une nouvelle catégorie
  Future<void> ajouterCategorie(Categorie categorie);

  /// Mettre à jour une catégorie existante
  Future<void> mettreAJourCategorie(
      String categorieId, Map<String, dynamic> data);

  // === TRANSACTIONS ===
  /// Ajouter une nouvelle transaction
  Future<void> ajouterTransaction(app_model.Transaction transaction);

  /// Mettre à jour une transaction existante
  Future<void> mettreAJourTransaction(app_model.Transaction transaction);

  /// Supprimer une transaction
  Future<void> supprimerTransaction(String transactionId);

  /// Lire les transactions d'un compte
  Future<List<app_model.Transaction>> lireTransactionsCompte(String compteId);

  // === DETTES ===
  /// Créer une nouvelle dette
  Future<void> creerDette(Dette dette);

  /// Mettre à jour une dette
  Future<void> mettreAJourDette(String detteId, Map<String, dynamic> data);

  /// Ajouter un mouvement à une dette
  Future<void> ajouterMouvementDette(String detteId, MouvementDette mouvement);

  /// Lire toutes les dettes actives
  Future<List<Dette>> lireDettesActives();

  // === TIERS ===
  /// Lire tous les tiers connus
  Future<List<String>> lireTiers();

  /// Ajouter un nouveau tiers
  Future<void> ajouterTiers(String nomTiers);

  // === ENVELOPPES ===
  /// Lire les enveloppes d'une catégorie
  Future<List<Map<String, dynamic>>> lireEnveloppesCategorie(
      String categorieId);

  /// Mettre à jour le solde d'une enveloppe
  Future<void> mettreAJourSoldeEnveloppe(
      String enveloppeId, double montant, app_model.TypeTransaction type);

  // === AUTHENTIFICATION ===
  /// Obtenir l'utilisateur connecté
  String? getCurrentUserId();

  /// Vérifier si un utilisateur est connecté
  bool get isUserConnected;

  // === UTILITAIRES ===
  /// Nettoyer les ressources
  Future<void> dispose();
}
