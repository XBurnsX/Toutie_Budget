import '../models/compte.dart';
import '../models/categorie.dart';
import '../models/transaction_model.dart' as app_model;
import 'firebase_service.dart';

class CacheService {
  static List<Compte>? _comptesCache;
  static DateTime? _lastComptesUpdate;
  static List<Categorie>? _categoriesCache;
  static DateTime? _lastCategoriesUpdate;
  static Map<String, List<app_model.Transaction>>? _transactionsCache;
  static Map<String, DateTime>? _lastTransactionsUpdate;

  static const Duration _cacheDuration = Duration(minutes: 10);

  static Future<List<Compte>> getComptes(FirebaseService service) async {
    if (_comptesCache != null &&
        _lastComptesUpdate != null &&
        DateTime.now().difference(_lastComptesUpdate!) < _cacheDuration) {
      return _comptesCache!;
    }
    final comptes = await service.lireComptes().first;
    _comptesCache = comptes;
    _lastComptesUpdate = DateTime.now();
    return comptes;
  }

  static void invalidateComptes() {
    _comptesCache = null;
    _lastComptesUpdate = null;
  }

  static Future<List<Categorie>> getCategories(FirebaseService service) async {
    if (_categoriesCache != null &&
        _lastCategoriesUpdate != null &&
        DateTime.now().difference(_lastCategoriesUpdate!) < _cacheDuration) {
      return _categoriesCache!;
    }
    final categories = await service.lireCategories().first;
    _categoriesCache = categories;
    _lastCategoriesUpdate = DateTime.now();
    return categories;
  }

  static void invalidateCategories() {
    _categoriesCache = null;
    _lastCategoriesUpdate = null;
  }

  static Future<List<app_model.Transaction>> getTransactions(
      FirebaseService service, String compteId) async {
    if (_transactionsCache != null &&
        _lastTransactionsUpdate != null &&
        _transactionsCache!.containsKey(compteId) &&
        _lastTransactionsUpdate!.containsKey(compteId) &&
        DateTime.now().difference(_lastTransactionsUpdate![compteId]!) <
            _cacheDuration) {
      return _transactionsCache![compteId]!;
    }

    final transactions = await service.lireTransactions(compteId).first;

    if (_transactionsCache == null) {
      _transactionsCache = {};
    }
    if (_lastTransactionsUpdate == null) {
      _lastTransactionsUpdate = {};
    }

    _transactionsCache![compteId] = transactions;
    _lastTransactionsUpdate![compteId] = DateTime.now();
    return transactions;
  }

  static void invalidateTransactions([String? compteId]) {
    if (compteId != null) {
      _transactionsCache?.remove(compteId);
      _lastTransactionsUpdate?.remove(compteId);
    } else {
      _transactionsCache = null;
      _lastTransactionsUpdate = null;
    }
  }

  // Invalider tout le cache (ex: après ajout/suppression)
  static void invalidateAll() {
    invalidateComptes();
    invalidateCategories();
    invalidateTransactions();
  }
}
