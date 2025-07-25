import '../interfaces/data_service_interface.dart';
import '../pocketbase_service.dart';
import '../../models/compte.dart';
import '../../models/categorie.dart';
import '../../models/transaction_model.dart' as app_model;
import '../../models/dette.dart';

/// Adaptateur PocketBase qui implémente l'interface DataServiceInterface
/// Permet d'utiliser PocketBase comme backend principal
/// NOTE: Certaines méthodes ne sont pas encore implémentées dans PocketBaseService
class PocketBaseAdapter implements DataServiceInterface {
  // === COMPTES ===
  @override
  Future<List<Compte>> lireComptes() async {
    try {
      final comptes = await PocketBaseService.lireComptes().first;
      return comptes;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> ajouterCompte(Compte compte) async {
    try {
      await PocketBaseService.ajouterCompte(compte);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> mettreAJourCompte(
      String compteId, Map<String, dynamic> data) async {
    try {
      // TODO: Implémenter dans PocketBaseService
      throw UnimplementedError(
          'mettreAJourCompte pas encore implémenté dans PocketBaseService');
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> supprimerCompte(String compteId) async {
    try {
      // TODO: Implémenter dans PocketBaseService
      throw UnimplementedError(
          'supprimerCompte pas encore implémenté dans PocketBaseService');
    } catch (e) {
      rethrow;
    }
  }

  // === CATÉGORIES ===
  @override
  Future<List<Categorie>> lireCategories() async {
    try {
      final categories = await PocketBaseService.lireCategories().first;
      return categories;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> ajouterCategorie(Categorie categorie) async {
    try {
      await PocketBaseService.ajouterCategorie(categorie);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> mettreAJourCategorie(
      String categorieId, Map<String, dynamic> data) async {
    try {
      // TODO: Implémenter dans PocketBaseService
      throw UnimplementedError(
          'mettreAJourCategorie pas encore implémenté dans PocketBaseService');
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> supprimerCategorie(String categorieId) async {
    try {
      // TODO: Implémenter dans PocketBaseService
      throw UnimplementedError(
          'supprimerCategorie pas encore implémenté dans PocketBaseService');
    } catch (e) {
      rethrow;
    }
  }

  // === TRANSACTIONS ===
  @override
  Future<void> ajouterTransaction(app_model.Transaction transaction) async {
    try {
      await PocketBaseService.ajouterTransaction(transaction);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> mettreAJourTransaction(app_model.Transaction transaction) async {
    try {
      await PocketBaseService.mettreAJourTransaction(transaction);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> supprimerTransaction(String transactionId) async {
    try {
      await PocketBaseService.supprimerTransaction(transactionId);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<app_model.Transaction>> lireTransactionsCompte(
      String compteId) async {
    try {
      final transactions =
          await PocketBaseService.lireTransactionsCompte(compteId);
      return transactions;
    } catch (e) {
      rethrow;
    }
  }

  // === DETTES ===
  @override
  Future<void> creerDette(Dette dette) async {
    try {
      await PocketBaseService.creerDette(dette);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> mettreAJourDette(
      String detteId, Map<String, dynamic> data) async {
    try {
      await PocketBaseService.mettreAJourDette(detteId, data);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> ajouterMouvementDette(
      String detteId, MouvementDette mouvement) async {
    try {
      await PocketBaseService.ajouterMouvementDette(detteId, mouvement);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<Dette>> lireDettesActives() async {
    try {
      return await PocketBaseService.lireDettesActives();
    } catch (e) {
      rethrow;
    }
  }

  // === TIERS ===
  @override
  Future<List<String>> lireTiers() async {
    try {
      return await PocketBaseService.lireTiers();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> ajouterTiers(String nom) async {
    try {
      await PocketBaseService.ajouterTiers(nom);
    } catch (e) {
      rethrow;
    }
  }

  // === ENVELOPPES ===
  @override
  Future<List<Map<String, dynamic>>> lireEnveloppesCategorie(
      String categorieId) async {
    try {
      return await PocketBaseService.lireEnveloppesParCategorie(categorieId);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> mettreAJourSoldeEnveloppe(String enveloppeId, double montant,
      app_model.TypeTransaction type) async {
    try {
      await PocketBaseService.mettreAJourSoldeEnveloppe(
          enveloppeId, montant, type);
    } catch (e) {
      rethrow;
    }
  }

  // === AUTHENTIFICATION ===
  @override
  String? getCurrentUserId() {
    return PocketBaseService.getCurrentUserId();
  }

  @override
  bool get isUserConnected {
    return PocketBaseService.isUserConnected;
  }

  // === UTILITAIRES ===
  @override
  Future<void> dispose() async {
    // PocketBaseService n'a pas de méthode dispose
    // TODO: Implémenter si nécessaire
  }
}
