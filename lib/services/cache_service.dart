import '../models/compte.dart';
import '../models/categorie.dart';
import 'firebase_service.dart';

class CacheService {
  static List<Compte>? _comptesCache;
  static DateTime? _lastComptesUpdate;
  static List<Categorie>? _categoriesCache;
  static DateTime? _lastCategoriesUpdate;

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

  // Invalider tout le cache (ex: après ajout/suppression)
  static void invalidateAll() {
    invalidateComptes();
    invalidateCategories();
  }
}
