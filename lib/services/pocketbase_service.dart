import 'package:pocketbase/pocketbase.dart';
import '../pocketbase_config.dart';

class PocketBaseService {
  static PocketBase? _instance;
  static bool _initialized = false;

  // Initialisation intelligente
  static Future<PocketBase> get instance async {
    if (!_initialized) {
      await _initialize();
    }
    return _instance!;
  }

  static Future<void> _initialize() async {
    try {
      // Tester et définir l'URL active
      await PocketBaseConfig.testAndSetActiveUrl();

      _instance = PocketBase(PocketBaseConfig.serverUrl);
      _initialized = true;

      print(
          '✅ PocketBaseService initialisé avec: ${PocketBaseConfig.serverUrl}');
    } catch (e) {
      print('❌ Erreur initialisation PocketBaseService: $e');
      rethrow;
    }
  }

  // Méthode pour re-tester la connexion
  static Future<void> retestConnection() async {
    _initialized = false;
    await _initialize();
  }

  // Authentification
  static Future<RecordAuth> signInWithEmail(
      String email, String password) async {
    final pb = await instance;
    return await pb
        .collection(PocketBaseConfig.usersCollection)
        .authWithPassword(email, password);
  }

  static Future<RecordModel> signUp(
      String email, String password, String passwordConfirm,
      {Map<String, dynamic>? data}) async {
    final pb = await instance;
    final body = data ?? {};
    body['email'] = email;
    body['password'] = password;
    body['passwordConfirm'] = passwordConfirm;
    return await pb
        .collection(PocketBaseConfig.usersCollection)
        .create(body: body);
  }

  static Future<void> signOut() async {
    final pb = await instance;
    pb.authStore.clear();
  }

  // Gestion des comptes
  static Future<List<RecordModel>> getComptes() async {
    final pb = await instance;
    return await pb
        .collection(PocketBaseConfig.comptesChequesCollection)
        .getFullList();
  }

  static Future<RecordModel> createCompte(Map<String, dynamic> data) async {
    final pb = await instance;
    return await pb
        .collection(PocketBaseConfig.comptesChequesCollection)
        .create(body: data);
  }

  static Future<RecordModel> createCompteCredit(
      Map<String, dynamic> data) async {
    final pb = await instance;
    return await pb
        .collection(PocketBaseConfig.comptesCreditsCollection)
        .create(body: data);
  }

  static Future<RecordModel> updateCompte(
      String id, Map<String, dynamic> data) async {
    final pb = await instance;
    return await pb
        .collection(PocketBaseConfig.comptesChequesCollection)
        .update(id, body: data);
  }

  static Future<void> deleteCompte(String id) async {
    final pb = await instance;
    await pb.collection(PocketBaseConfig.comptesChequesCollection).delete(id);
  }

  // Gestion des catégories
  static Future<List<RecordModel>> getCategories() async {
    final pb = await instance;
    return await pb
        .collection(PocketBaseConfig.categoriesCollection)
        .getFullList();
  }

  static Future<RecordModel> createCategorie(Map<String, dynamic> data) async {
    final pb = await instance;
    return await pb
        .collection(PocketBaseConfig.categoriesCollection)
        .create(body: data);
  }

  static Future<RecordModel> updateCategorie(
      String id, Map<String, dynamic> data) async {
    final pb = await instance;
    return await pb
        .collection(PocketBaseConfig.categoriesCollection)
        .update(id, body: data);
  }

  static Future<void> deleteCategorie(String id) async {
    final pb = await instance;
    await pb.collection(PocketBaseConfig.categoriesCollection).delete(id);
  }

  // Gestion des transactions
  static Future<List<RecordModel>> getTransactions() async {
    final pb = await instance;
    return await pb
        .collection(PocketBaseConfig.transactionsCollection)
        .getFullList();
  }

  static Future<RecordModel> createTransaction(
      Map<String, dynamic> data) async {
    final pb = await instance;
    return await pb
        .collection(PocketBaseConfig.transactionsCollection)
        .create(body: data);
  }

  static Future<RecordModel> updateTransaction(
      String id, Map<String, dynamic> data) async {
    final pb = await instance;
    return await pb
        .collection(PocketBaseConfig.transactionsCollection)
        .update(id, body: data);
  }

  static Future<void> deleteTransaction(String id) async {
    final pb = await instance;
    await pb.collection(PocketBaseConfig.transactionsCollection).delete(id);
  }

  // Gestion des enveloppes
  static Future<List<RecordModel>> getEnveloppes() async {
    final pb = await instance;
    return await pb
        .collection(PocketBaseConfig.enveloppesCollection)
        .getFullList();
  }

  static Future<RecordModel> createEnveloppe(Map<String, dynamic> data) async {
    final pb = await instance;
    return await pb
        .collection(PocketBaseConfig.enveloppesCollection)
        .create(body: data);
  }

  static Future<RecordModel> updateEnveloppe(
      String id, Map<String, dynamic> data) async {
    final pb = await instance;
    return await pb
        .collection(PocketBaseConfig.enveloppesCollection)
        .update(id, body: data);
  }

  static Future<void> deleteEnveloppe(String id) async {
    final pb = await instance;
    await pb.collection(PocketBaseConfig.enveloppesCollection).delete(id);
  }

  // Gestion des allocations mensuelles
  static Future<List<RecordModel>> getAllocationsMensuelles() async {
    final pb = await instance;
    return await pb
        .collection(PocketBaseConfig.allocationsMensuellesCollection)
        .getFullList();
  }

  static Future<RecordModel> createAllocationMensuelle(
      Map<String, dynamic> data) async {
    final pb = await instance;
    return await pb
        .collection(PocketBaseConfig.allocationsMensuellesCollection)
        .create(body: data);
  }

  static Future<RecordModel> updateAllocationMensuelle(
      String id, Map<String, dynamic> data) async {
    final pb = await instance;
    return await pb
        .collection(PocketBaseConfig.allocationsMensuellesCollection)
        .update(id, body: data);
  }

  static Future<void> deleteAllocationMensuelle(String id) async {
    final pb = await instance;
    await pb
        .collection(PocketBaseConfig.allocationsMensuellesCollection)
        .delete(id);
  }

  // Gestion des dettes
  static Future<List<RecordModel>> getDettes() async {
    final pb = await instance;
    return await pb
        .collection(PocketBaseConfig.comptesDettesCollection)
        .getFullList();
  }

  static Future<RecordModel> createDette(Map<String, dynamic> data) async {
    final pb = await instance;
    return await pb
        .collection(PocketBaseConfig.comptesDettesCollection)
        .create(body: data);
  }

  static Future<RecordModel> updateDette(
      String id, Map<String, dynamic> data) async {
    final pb = await instance;
    return await pb
        .collection(PocketBaseConfig.comptesDettesCollection)
        .update(id, body: data);
  }

  static Future<void> deleteDette(String id) async {
    final pb = await instance;
    await pb.collection(PocketBaseConfig.comptesDettesCollection).delete(id);
  }

  // Gestion des investissements
  static Future<List<RecordModel>> getInvestissements() async {
    final pb = await instance;
    return await pb
        .collection(PocketBaseConfig.comptesInvestissementCollection)
        .getFullList();
  }

  static Future<RecordModel> createInvestissement(
      Map<String, dynamic> data) async {
    final pb = await instance;
    return await pb
        .collection(PocketBaseConfig.comptesInvestissementCollection)
        .create(body: data);
  }

  static Future<RecordModel> updateInvestissement(
      String id, Map<String, dynamic> data) async {
    final pb = await instance;
    return await pb
        .collection(PocketBaseConfig.comptesInvestissementCollection)
        .update(id, body: data);
  }

  static Future<void> deleteInvestissement(String id) async {
    final pb = await instance;
    await pb
        .collection(PocketBaseConfig.comptesInvestissementCollection)
        .delete(id);
  }

  // Gestion des prêts personnels
  static Future<List<RecordModel>> getPretsPersonnels() async {
    final pb = await instance;
    return await pb
        .collection(PocketBaseConfig.pretPersonnelCollection)
        .getFullList();
  }

  static Future<RecordModel> createPretPersonnel(
      Map<String, dynamic> data) async {
    final pb = await instance;
    return await pb
        .collection(PocketBaseConfig.pretPersonnelCollection)
        .create(body: data);
  }

  static Future<RecordModel> updatePretPersonnel(
      String id, Map<String, dynamic> data) async {
    final pb = await instance;
    return await pb
        .collection(PocketBaseConfig.pretPersonnelCollection)
        .update(id, body: data);
  }

  static Future<void> deletePretPersonnel(String id) async {
    final pb = await instance;
    await pb.collection(PocketBaseConfig.pretPersonnelCollection).delete(id);
  }

  // Gestion des tiers
  static Future<List<RecordModel>> getTiers() async {
    final pb = await instance;
    return await pb.collection(PocketBaseConfig.tiersCollection).getFullList();
  }

  static Future<RecordModel> createTiers(Map<String, dynamic> data) async {
    final pb = await instance;
    return await pb
        .collection(PocketBaseConfig.tiersCollection)
        .create(body: data);
  }

  static Future<RecordModel> updateTiers(
      String id, Map<String, dynamic> data) async {
    final pb = await instance;
    return await pb
        .collection(PocketBaseConfig.tiersCollection)
        .update(id, body: data);
  }

  static Future<void> deleteTiers(String id) async {
    final pb = await instance;
    await pb.collection(PocketBaseConfig.tiersCollection).delete(id);
  }

  // Vérifier si l'utilisateur est connecté
  static bool get isAuthenticated {
    return _instance?.authStore.isValid ?? false;
  }

  // Obtenir l'utilisateur connecté
  static RecordModel? get currentUser {
    return _instance?.authStore.model;
  }
}
