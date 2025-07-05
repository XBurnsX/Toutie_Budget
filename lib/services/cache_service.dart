import '../models/compte.dart';
import '../models/categorie.dart';
import '../models/transaction_model.dart' as app_model;
import 'firebase_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'persistent_cache_service.dart';
import 'firebase_monitor_service.dart';

class CacheService {
  static List<Compte>? _comptesCache;
  static DateTime? _lastComptesUpdate;
  static List<Categorie>? _categoriesCache;
  static DateTime? _lastCategoriesUpdate;
  static Map<String, List<app_model.Transaction>>? _transactionsCache;
  static Map<String, DateTime>? _lastTransactionsUpdate;

  // Cache plus agressif pour le web (30 min vs 10 min mobile)
  static Duration get _cacheDuration =>
      kIsWeb ? const Duration(minutes: 30) : const Duration(minutes: 10);

  // Synchronisation intelligente pour le web
  static bool _isWebSyncInProgress = false;
  static DateTime? _lastWebSync;

  static Future<List<Compte>> getComptes(FirebaseService service) async {
    final user = service.auth.currentUser;
    final userId = user?.uid ?? 'anonymous';

    // Vérifier le cache mémoire
    if (_comptesCache != null &&
        _lastComptesUpdate != null &&
        DateTime.now().difference(_lastComptesUpdate!) < _cacheDuration) {
      // Logger le hit de cache mémoire
      FirebaseMonitorService.logCacheHit(
        collection: 'comptes',
        document: 'memory_cache',
        count: _comptesCache!.length,
        userId: userId,
        details: 'Cache mémoire: ${_comptesCache!.length} comptes',
      );

      // Pour le web, synchroniser en arrière-plan si nécessaire
      if (kIsWeb && _shouldSyncInBackground()) {
        _syncComptesInBackground(service);
      }

      return _comptesCache!;
    }

    // Essayer le cache persistant (mobile uniquement)
    if (!kIsWeb) {
      try {
        final cachedComptes = await PersistentCacheService.loadComptes();
        if (cachedComptes != null &&
            await PersistentCacheService.isCacheValid('comptes_cache')) {
          // Logger le hit de cache persistant
          FirebaseMonitorService.logCacheHit(
            collection: 'comptes',
            document: 'sqlite_cache',
            count: cachedComptes.length,
            userId: userId,
            details: 'Cache SQLite: ${cachedComptes.length} comptes',
          );

          _comptesCache = cachedComptes;
          _lastComptesUpdate = DateTime.now();

          // Synchroniser en arrière-plan
          _syncComptesInBackground(service);
          return cachedComptes;
        }
      } catch (e) {
        // Ignorer les erreurs de cache persistant
      }
    }

    // Logger le miss de cache
    FirebaseMonitorService.logCacheMiss(
      collection: 'comptes',
      document: 'firestore_fallback',
      count: 1,
      userId: userId,
      details: 'Cache miss - chargement depuis Firestore',
    );

    // Charger depuis Firestore
    final comptes = await service.lireComptes().first;
    _comptesCache = comptes;
    _lastComptesUpdate = DateTime.now();

    // Sauvegarder dans le cache persistant (mobile uniquement)
    if (!kIsWeb) {
      try {
        await PersistentCacheService.saveComptes(comptes);
      } catch (e) {
        // Ignorer les erreurs de sauvegarde
      }
    }

    // Marquer la synchronisation web
    if (kIsWeb) {
      _lastWebSync = DateTime.now();
    }

    return comptes;
  }

  static Future<List<Categorie>> getCategories(FirebaseService service) async {
    final user = service.auth.currentUser;
    final userId = user?.uid ?? 'anonymous';

    // Vérifier le cache mémoire
    if (_categoriesCache != null &&
        _lastCategoriesUpdate != null &&
        DateTime.now().difference(_lastCategoriesUpdate!) < _cacheDuration) {
      // Logger le hit de cache mémoire
      FirebaseMonitorService.logCacheHit(
        collection: 'categories',
        document: 'memory_cache',
        count: _categoriesCache!.length,
        userId: userId,
        details: 'Cache mémoire: ${_categoriesCache!.length} catégories',
      );

      // Pour le web, synchroniser en arrière-plan si nécessaire
      if (kIsWeb && _shouldSyncInBackground()) {
        _syncCategoriesInBackground(service);
      }

      return _categoriesCache!;
    }

    // Essayer le cache persistant (mobile uniquement)
    if (!kIsWeb) {
      try {
        final cachedCategories = await PersistentCacheService.loadCategories();
        if (cachedCategories != null &&
            await PersistentCacheService.isCacheValid('categories_cache')) {
          // Logger le hit de cache persistant
          FirebaseMonitorService.logCacheHit(
            collection: 'categories',
            document: 'sqlite_cache',
            count: cachedCategories.length,
            userId: userId,
            details: 'Cache SQLite: ${cachedCategories.length} catégories',
          );

          _categoriesCache = cachedCategories;
          _lastCategoriesUpdate = DateTime.now();

          // Synchroniser en arrière-plan
          _syncCategoriesInBackground(service);
          return cachedCategories;
        }
      } catch (e) {
        // Ignorer les erreurs de cache persistant
      }
    }

    // Logger le miss de cache
    FirebaseMonitorService.logCacheMiss(
      collection: 'categories',
      document: 'firestore_fallback',
      count: 1,
      userId: userId,
      details: 'Cache miss - chargement depuis Firestore',
    );

    // Charger depuis Firestore
    final categories = await service.lireCategories().first;
    _categoriesCache = categories;
    _lastCategoriesUpdate = DateTime.now();

    // Sauvegarder dans le cache persistant (mobile uniquement)
    if (!kIsWeb) {
      try {
        await PersistentCacheService.saveCategories(categories);
      } catch (e) {
        // Ignorer les erreurs de sauvegarde
      }
    }

    // Marquer la synchronisation web
    if (kIsWeb) {
      _lastWebSync = DateTime.now();
    }

    return categories;
  }

  static Future<List<app_model.Transaction>> getTransactions(
      FirebaseService service, String compteId) async {
    final user = service.auth.currentUser;
    final userId = user?.uid ?? 'anonymous';

    // Vérifier le cache mémoire
    if (_transactionsCache != null &&
        _lastTransactionsUpdate != null &&
        _transactionsCache!.containsKey(compteId) &&
        _lastTransactionsUpdate!.containsKey(compteId) &&
        DateTime.now().difference(_lastTransactionsUpdate![compteId]!) <
            _cacheDuration) {
      // Logger le hit de cache mémoire
      FirebaseMonitorService.logCacheHit(
        collection: 'transactions',
        document: 'memory_cache',
        count: _transactionsCache![compteId]!.length,
        userId: userId,
        details:
            'Cache mémoire: ${_transactionsCache![compteId]!.length} transactions pour compte $compteId',
      );

      // Pour le web, synchroniser en arrière-plan si nécessaire
      if (kIsWeb && _shouldSyncInBackground()) {
        _syncTransactionsInBackground(service, compteId);
      }

      return _transactionsCache![compteId]!;
    }

    // Essayer le cache persistant (mobile uniquement)
    if (!kIsWeb) {
      try {
        final cachedTransactions =
            await PersistentCacheService.loadTransactions(compteId);
        if (cachedTransactions != null &&
            await PersistentCacheService.isCacheValid('transactions_cache')) {
          // Logger le hit de cache persistant
          FirebaseMonitorService.logCacheHit(
            collection: 'transactions',
            document: 'sqlite_cache',
            count: cachedTransactions.length,
            userId: userId,
            details:
                'Cache SQLite: ${cachedTransactions.length} transactions pour compte $compteId',
          );

          _transactionsCache ??= {};
          _lastTransactionsUpdate ??= {};

          _transactionsCache![compteId] = cachedTransactions;
          _lastTransactionsUpdate![compteId] = DateTime.now();

          // Synchroniser en arrière-plan
          _syncTransactionsInBackground(service, compteId);
          return cachedTransactions;
        }
      } catch (e) {
        // Ignorer les erreurs de cache persistant
      }
    }

    // Logger le miss de cache
    FirebaseMonitorService.logCacheMiss(
      collection: 'transactions',
      document: 'firestore_fallback',
      count: 1,
      userId: userId,
      details: 'Cache miss - chargement depuis Firestore pour compte $compteId',
    );
    
    // Charger depuis Firestore
    final transactions = await service.lireTransactions(compteId).first;

    _transactionsCache ??= {};
    _lastTransactionsUpdate ??= {};

    _transactionsCache![compteId] = transactions;
    _lastTransactionsUpdate![compteId] = DateTime.now();

    // Sauvegarder dans le cache persistant (mobile uniquement)
    if (!kIsWeb) {
      try {
        await PersistentCacheService.saveTransactions(compteId, transactions);
      } catch (e) {
        // Ignorer les erreurs de sauvegarde
      }
    }

    // Marquer la synchronisation web
    if (kIsWeb) {
      _lastWebSync = DateTime.now();
    }

    return transactions;
  }

  // Synchronisation intelligente pour le web
  static bool _shouldSyncInBackground() {
    if (_isWebSyncInProgress) return false;
    if (_lastWebSync == null) return true;

    // Synchroniser toutes les 5 minutes en arrière-plan
    return DateTime.now().difference(_lastWebSync!) >
        const Duration(minutes: 5);
  }

  // Synchronisation en arrière-plan pour le web
  static Future<void> _syncComptesInBackground(FirebaseService service) async {
    if (_isWebSyncInProgress) return;

    _isWebSyncInProgress = true;
    try {
      final comptes = await service.lireComptes().first;
      _comptesCache = comptes;
      _lastComptesUpdate = DateTime.now();
      _lastWebSync = DateTime.now();
    } catch (e) {
      // Ignorer les erreurs de synchronisation en arrière-plan
    } finally {
      _isWebSyncInProgress = false;
    }
  }

  static Future<void> _syncCategoriesInBackground(
      FirebaseService service) async {
    if (_isWebSyncInProgress) return;

    _isWebSyncInProgress = true;
    try {
      final categories = await service.lireCategories().first;
      _categoriesCache = categories;
      _lastCategoriesUpdate = DateTime.now();
      _lastWebSync = DateTime.now();
    } catch (e) {
      // Ignorer les erreurs de synchronisation en arrière-plan
    } finally {
      _isWebSyncInProgress = false;
    }
  }

  static Future<void> _syncTransactionsInBackground(
      FirebaseService service, String compteId) async {
    if (_isWebSyncInProgress) return;

    _isWebSyncInProgress = true;
    try {
      final transactions = await service.lireTransactions(compteId).first;

      _transactionsCache ??= {};
      _lastTransactionsUpdate ??= {};

      _transactionsCache![compteId] = transactions;
      _lastTransactionsUpdate![compteId] = DateTime.now();
      _lastWebSync = DateTime.now();
    } catch (e) {
      // Ignorer les erreurs de synchronisation en arrière-plan
    } finally {
      _isWebSyncInProgress = false;
    }
  }

  // Méthodes d'invalidation
  static void invalidateComptes() {
    _comptesCache = null;
    _lastComptesUpdate = null;
  }

  static void invalidateCategories() {
    _categoriesCache = null;
    _lastCategoriesUpdate = null;
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

  // Statistiques du cache pour le debug
  static Map<String, dynamic> getCacheStats() {
    return {
      'isWeb': kIsWeb,
      'cacheDuration': _cacheDuration.inMinutes,
      'comptesCached': _comptesCache != null,
      'categoriesCached': _categoriesCache != null,
      'transactionsCached': _transactionsCache?.length ?? 0,
      'lastComptesUpdate': _lastComptesUpdate?.toIso8601String(),
      'lastCategoriesUpdate': _lastCategoriesUpdate?.toIso8601String(),
      'lastWebSync': _lastWebSync?.toIso8601String(),
      'isWebSyncInProgress': _isWebSyncInProgress,
    };
  }
}
