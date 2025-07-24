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
      print('🔍 PocketBaseAdapter: Lecture des comptes...');
      final comptes = await PocketBaseService.lireComptes().first;
      print('✅ PocketBaseAdapter: ${comptes.length} comptes lus');
      return comptes;
    } catch (e) {
      print('❌ PocketBaseAdapter: Erreur lecture comptes: $e');
      rethrow;
    }
  }

  @override
  Future<void> ajouterCompte(Compte compte) async {
    try {
      print('🔍 PocketBaseAdapter: Ajout du compte ${compte.nom}...');
      await PocketBaseService.ajouterCompte(compte);
      print('✅ PocketBaseAdapter: Compte ajouté avec succès');
    } catch (e) {
      print('❌ PocketBaseAdapter: Erreur ajout compte: $e');
      rethrow;
    }
  }

  @override
  Future<void> mettreAJourCompte(
      String compteId, Map<String, dynamic> data) async {
    throw UnimplementedError(
        'mettreAJourCompte pas encore implémenté dans PocketBaseService');
  }

  @override
  Future<void> supprimerCompte(String compteId) async {
    throw UnimplementedError(
        'supprimerCompte pas encore implémenté dans PocketBaseService');
  }

  // === CATÉGORIES ===
  @override
  Future<List<Categorie>> lireCategories() async {
    try {
      print('🔍 PocketBaseAdapter: Lecture des catégories...');
      final categories = await PocketBaseService.lireCategories().first;
      print('✅ PocketBaseAdapter: ${categories.length} catégories lues');
      return categories;
    } catch (e) {
      print('❌ PocketBaseAdapter: Erreur lecture catégories: $e');
      rethrow;
    }
  }

  @override
  Future<void> ajouterCategorie(Categorie categorie) async {
    try {
      print('🔍 PocketBaseAdapter: Ajout de la catégorie ${categorie.nom}...');
      await PocketBaseService.ajouterCategorie(categorie);
      print('✅ PocketBaseAdapter: Catégorie ajoutée avec succès');
    } catch (e) {
      print('❌ PocketBaseAdapter: Erreur ajout catégorie: $e');
      rethrow;
    }
  }

  @override
  Future<void> mettreAJourCategorie(
      String categorieId, Map<String, dynamic> data) async {
    throw UnimplementedError(
        'mettreAJourCategorie pas encore implémenté dans PocketBaseService');
  }

  // === TRANSACTIONS ===
  @override
  Future<void> ajouterTransaction(app_model.Transaction transaction) async {
    try {
      print('🔍 PocketBaseAdapter: Ajout transaction...');
      await PocketBaseService.ajouterTransaction(transaction);
      print('✅ PocketBaseAdapter: Transaction ajoutée avec succès');
    } catch (e) {
      print('❌ PocketBaseAdapter: Erreur ajout transaction: $e');
      rethrow;
    }
  }

  @override
  Future<void> mettreAJourTransaction(app_model.Transaction transaction) async {
    try {
      print('🔍 PocketBaseAdapter: Mise à jour transaction...');
      await PocketBaseService.mettreAJourTransaction(transaction);
      print('✅ PocketBaseAdapter: Transaction mise à jour avec succès');
    } catch (e) {
      print('❌ PocketBaseAdapter: Erreur mise à jour transaction: $e');
      rethrow;
    }
  }

  @override
  Future<void> supprimerTransaction(String transactionId) async {
    try {
      print('🔍 PocketBaseAdapter: Suppression transaction...');
      await PocketBaseService.supprimerTransaction(transactionId);
      print('✅ PocketBaseAdapter: Transaction supprimée avec succès');
    } catch (e) {
      print('❌ PocketBaseAdapter: Erreur suppression transaction: $e');
      rethrow;
    }
  }

  @override
  Future<List<app_model.Transaction>> lireTransactionsCompte(
      String compteId) async {
    try {
      print('🔍 PocketBaseAdapter: Lecture transactions compte...');
      final transactions =
          await PocketBaseService.lireTransactionsCompte(compteId);
      print('✅ PocketBaseAdapter: ${transactions.length} transactions lues');
      return transactions;
    } catch (e) {
      print('❌ PocketBaseAdapter: Erreur lecture transactions: $e');
      rethrow;
    }
  }

  // === DETTES ===
  @override
  Future<void> creerDette(Dette dette) async {
    try {
      print('🔍 PocketBaseAdapter: Création dette...');
      await PocketBaseService.creerDette(dette);
      print('✅ PocketBaseAdapter: Dette créée avec succès');
    } catch (e) {
      print('❌ PocketBaseAdapter: Erreur création dette: $e');
      rethrow;
    }
  }

  @override
  Future<void> mettreAJourDette(
      String detteId, Map<String, dynamic> data) async {
    try {
      print('🔍 PocketBaseAdapter: Mise à jour dette...');
      await PocketBaseService.mettreAJourDette(detteId, data);
      print('✅ PocketBaseAdapter: Dette mise à jour avec succès');
    } catch (e) {
      print('❌ PocketBaseAdapter: Erreur mise à jour dette: $e');
      rethrow;
    }
  }

  @override
  Future<void> ajouterMouvementDette(
      String detteId, MouvementDette mouvement) async {
    try {
      print('🔍 PocketBaseAdapter: Ajout mouvement dette...');
      await PocketBaseService.ajouterMouvementDette(detteId, mouvement);
      print('✅ PocketBaseAdapter: Mouvement dette ajouté avec succès');
    } catch (e) {
      print('❌ PocketBaseAdapter: Erreur ajout mouvement dette: $e');
      rethrow;
    }
  }

  @override
  Future<List<Dette>> lireDettesActives() async {
    try {
      print('🔍 PocketBaseAdapter: Lecture dettes actives...');
      final dettes = await PocketBaseService.lireDettesActives();
      print('✅ PocketBaseAdapter: ${dettes.length} dettes lues');
      return dettes;
    } catch (e) {
      print('❌ PocketBaseAdapter: Erreur lecture dettes: $e');
      rethrow;
    }
  }

  // === TIERS ===
  @override
  Future<List<String>> lireTiers() async {
    try {
      print('🔍 PocketBaseAdapter: Lecture des tiers...');
      final tiers = await PocketBaseService.lireTiers();
      print('✅ PocketBaseAdapter: ${tiers.length} tiers lus');
      return tiers;
    } catch (e) {
      print('❌ PocketBaseAdapter: Erreur lecture tiers: $e');
      rethrow;
    }
  }

  @override
  Future<void> ajouterTiers(String nomTiers) async {
    try {
      print('🔍 PocketBaseAdapter: Ajout du tiers $nomTiers...');
      await PocketBaseService.ajouterTiers(nomTiers);
      print('✅ PocketBaseAdapter: Tiers ajouté avec succès');
    } catch (e) {
      print('❌ PocketBaseAdapter: Erreur ajout tiers: $e');
      rethrow;
    }
  }

  // === ENVELOPPES ===
  @override
  Future<List<Map<String, dynamic>>> lireEnveloppesCategorie(
      String categorieId) async {
    try {
      print(
          '🔍 PocketBaseAdapter: Lecture des enveloppes de la catégorie $categorieId...');
      final enveloppes =
          await PocketBaseService.lireEnveloppesParCategorie(categorieId);
      print('✅ PocketBaseAdapter: ${enveloppes.length} enveloppes lues');
      return enveloppes;
    } catch (e) {
      print('❌ PocketBaseAdapter: Erreur lecture enveloppes: $e');
      rethrow;
    }
  }

  @override
  Future<void> mettreAJourSoldeEnveloppe(String enveloppeId, double montant,
      app_model.TypeTransaction type) async {
    try {
      print('🔍 PocketBaseAdapter: Mise à jour solde enveloppe...');
      await PocketBaseService.mettreAJourSoldeEnveloppe(
          enveloppeId, montant, type);
      print('✅ PocketBaseAdapter: Solde enveloppe mis à jour avec succès');
    } catch (e) {
      print('❌ PocketBaseAdapter: Erreur mise à jour solde enveloppe: $e');
      rethrow;
    }
  }

  // === AUTHENTIFICATION ===
  @override
  String? getCurrentUserId() {
    // TODO: Implémenter getCurrentUserId dans PocketBaseService
    throw UnimplementedError(
        'getCurrentUserId pas encore implémenté dans PocketBaseService');
  }

  @override
  bool get isUserConnected {
    // TODO: Implémenter isUserConnected dans PocketBaseService
    throw UnimplementedError(
        'isUserConnected pas encore implémenté dans PocketBaseService');
  }

  // === UTILITAIRES ===
  @override
  Future<void> dispose() async {
    try {
      print('🔍 PocketBaseAdapter: Nettoyage des ressources...');
      await PocketBaseService.dispose();
      print('✅ PocketBaseAdapter: Ressources nettoyées');
    } catch (e) {
      print('❌ PocketBaseAdapter: Erreur nettoyage: $e');
      rethrow;
    }
  }
}
