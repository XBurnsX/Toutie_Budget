import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class FirebaseMonitorService {
  static const String _storageKey = 'firebase_monitor_history';
  static const int _maxHistoryEntries = 1000; // Limiter l'historique

  // Types de requêtes
  static const String _typeRead = 'read';
  static const String _typeWrite = 'write';
  static const String _typeDelete = 'delete';
  static const String _typeQuery = 'query';
  static const String _typeCacheHit = 'cache_hit';
  static const String _typeCacheMiss = 'cache_miss';

  // Structure d'une entrée d'historique
  static Map<String, dynamic> _createHistoryEntry({
    required String type,
    required String collection,
    required String document,
    required int count,
    required String userId,
    String? details,
  }) {
    return {
      'timestamp': DateTime.now().toIso8601String(),
      'type': type,
      'collection': collection,
      'document': document,
      'count': count,
      'userId': userId,
      'details': details,
      'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'time': DateFormat('HH:mm:ss').format(DateTime.now()),
    };
  }

  // Enregistrer une lecture
  static Future<void> logRead({
    required String collection,
    required String document,
    required int count,
    required String userId,
    String? details,
  }) async {
    await _addHistoryEntry(
      _createHistoryEntry(
        type: _typeRead,
        collection: collection,
        document: document,
        count: count,
        userId: userId,
        details: details,
      ),
    );
  }

  // Enregistrer une écriture
  static Future<void> logWrite({
    required String collection,
    required String document,
    required int count,
    required String userId,
    String? details,
  }) async {
    await _addHistoryEntry(
      _createHistoryEntry(
        type: _typeWrite,
        collection: collection,
        document: document,
        count: count,
        userId: userId,
        details: details,
      ),
    );
  }

  // Enregistrer une suppression
  static Future<void> logDelete({
    required String collection,
    required String document,
    required int count,
    required String userId,
    String? details,
  }) async {
    await _addHistoryEntry(
      _createHistoryEntry(
        type: _typeDelete,
        collection: collection,
        document: document,
        count: count,
        userId: userId,
        details: details,
      ),
    );
  }

  // Enregistrer une requête complexe
  static Future<void> logQuery({
    required String collection,
    required String document,
    required int count,
    required String userId,
    String? details,
  }) async {
    await _addHistoryEntry(
      _createHistoryEntry(
        type: _typeQuery,
        collection: collection,
        document: document,
        count: count,
        userId: userId,
        details: details,
      ),
    );
  }

  // Enregistrer un hit de cache
  static Future<void> logCacheHit({
    required String collection,
    required String document,
    required int count,
    required String userId,
    String? details,
  }) async {
    await _addHistoryEntry(
      _createHistoryEntry(
        type: _typeCacheHit,
        collection: collection,
        document: document,
        count: count,
        userId: userId,
        details: details,
      ),
    );
  }

  // Enregistrer un miss de cache
  static Future<void> logCacheMiss({
    required String collection,
    required String document,
    required int count,
    required String userId,
    String? details,
  }) async {
    await _addHistoryEntry(
      _createHistoryEntry(
        type: _typeCacheMiss,
        collection: collection,
        document: document,
        count: count,
        userId: userId,
        details: details,
      ),
    );
  }

  // Ajouter une entrée à l'historique
  static Future<void> _addHistoryEntry(Map<String, dynamic> entry) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_storageKey) ?? '[]';
      final List<dynamic> history = jsonDecode(historyJson);

      history.add(entry);

      // Limiter la taille de l'historique
      if (history.length > _maxHistoryEntries) {
        history.removeRange(0, history.length - _maxHistoryEntries);
      }

      await prefs.setString(_storageKey, jsonEncode(history));
    } catch (e) {
      // Ignorer les erreurs de stockage
    }
  }

  // Obtenir l'historique complet
  static Future<List<Map<String, dynamic>>> getHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_storageKey) ?? '[]';
      final List<dynamic> history = jsonDecode(historyJson);

      return history.cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  // Obtenir l'historique filtré par date
  static Future<List<Map<String, dynamic>>> getHistoryByDate(
      String date) async {
    final history = await getHistory();
    return history.where((entry) => entry['date'] == date).toList();
  }

  // Obtenir l'historique filtré par collection
  static Future<List<Map<String, dynamic>>> getHistoryByCollection(
      String collection) async {
    final history = await getHistory();
    return history.where((entry) => entry['collection'] == collection).toList();
  }

    // Obtenir les statistiques globales
  static Future<Map<String, dynamic>> getGlobalStats() async {
    final history = await getHistory();
    
    int totalReads = 0;
    int totalWrites = 0;
    int totalDeletes = 0;
    int totalQueries = 0;
    int totalCacheHits = 0;
    int totalCacheMisses = 0;
    
    Map<String, int> collectionStats = {};
    Map<String, int> dailyStats = {};
    
    for (final entry in history) {
      final type = entry['type'] as String;
      final count = entry['count'] as int;
      final collection = entry['collection'] as String;
      final date = entry['date'] as String;
      
      switch (type) {
        case _typeRead:
          totalReads += count;
          break;
        case _typeWrite:
          totalWrites += count;
          break;
        case _typeDelete:
          totalDeletes += count;
          break;
        case _typeQuery:
          totalQueries += count;
          break;
        case _typeCacheHit:
          totalCacheHits += count;
          break;
        case _typeCacheMiss:
          totalCacheMisses += count;
          break;
      }
      
      collectionStats[collection] = (collectionStats[collection] ?? 0) + count;
      dailyStats[date] = (dailyStats[date] ?? 0) + count;
    }
    
    final totalFirestoreOps = totalReads + totalWrites + totalDeletes + totalQueries;
    final totalCacheOps = totalCacheHits + totalCacheMisses;
    final totalOperations = totalFirestoreOps + totalCacheOps;
    
    return {
      'totalReads': totalReads,
      'totalWrites': totalWrites,
      'totalDeletes': totalDeletes,
      'totalQueries': totalQueries,
      'totalCacheHits': totalCacheHits,
      'totalCacheMisses': totalCacheMisses,
      'totalFirestoreOps': totalFirestoreOps,
      'totalCacheOps': totalCacheOps,
      'totalOperations': totalOperations,
      'cacheHitRate': totalCacheOps > 0 ? (totalCacheHits / totalCacheOps * 100).roundToDouble() : 0.0,
      'collectionStats': collectionStats,
      'dailyStats': dailyStats,
      'historySize': history.length,
    };
  }

    // Obtenir les statistiques du jour
  static Future<Map<String, dynamic>> getTodayStats() async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final todayHistory = await getHistoryByDate(today);
    
    int reads = 0;
    int writes = 0;
    int deletes = 0;
    int queries = 0;
    int cacheHits = 0;
    int cacheMisses = 0;
    
    Map<String, int> collectionStats = {};
    
    for (final entry in todayHistory) {
      final type = entry['type'] as String;
      final count = entry['count'] as int;
      final collection = entry['collection'] as String;
      
      switch (type) {
        case _typeRead:
          reads += count;
          break;
        case _typeWrite:
          writes += count;
          break;
        case _typeDelete:
          deletes += count;
          break;
        case _typeQuery:
          queries += count;
          break;
        case _typeCacheHit:
          cacheHits += count;
          break;
        case _typeCacheMiss:
          cacheMisses += count;
          break;
      }
      
      collectionStats[collection] = (collectionStats[collection] ?? 0) + count;
    }
    
    final totalFirestoreOps = reads + writes + deletes + queries;
    final totalCacheOps = cacheHits + cacheMisses;
    final totalOperations = totalFirestoreOps + totalCacheOps;
    final cacheHitRate = totalCacheOps > 0 ? (cacheHits / totalCacheOps * 100) : 0.0;
    
    return {
      'date': today,
      'reads': reads,
      'writes': writes,
      'deletes': deletes,
      'queries': queries,
      'cacheHits': cacheHits,
      'cacheMisses': cacheMisses,
      'totalFirestoreOps': totalFirestoreOps,
      'totalCacheOps': totalCacheOps,
      'total': totalOperations,
      'cacheHitRate': cacheHitRate,
      'collectionStats': collectionStats,
      'entries': todayHistory.length,
    };
  }

  // Obtenir les statistiques des 7 derniers jours
  static Future<List<Map<String, dynamic>>> getLast7DaysStats() async {
    final List<Map<String, dynamic>> weeklyStats = [];

    for (int i = 6; i >= 0; i--) {
      final date = DateTime.now().subtract(Duration(days: i));
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final dayHistory = await getHistoryByDate(dateStr);

      int total = 0;
      for (final entry in dayHistory) {
        total += entry['count'] as int;
      }

      weeklyStats.add({
        'date': dateStr,
        'dayName': DateFormat('E', 'fr_FR').format(date),
        'total': total,
        'entries': dayHistory.length,
      });
    }

    return weeklyStats;
  }

  // Vider l'historique
  static Future<void> clearHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (e) {
      // Ignorer les erreurs
    }
  }

  // Obtenir les collections les plus utilisées
  static Future<List<MapEntry<String, int>>> getTopCollections() async {
    final stats = await getGlobalStats();
    final collectionStats = stats['collectionStats'] as Map<String, int>;

    final sorted = collectionStats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(10).toList();
  }

  // Obtenir les heures de pointe
  static Future<Map<String, int>> getHourlyStats() async {
    final history = await getHistory();
    final Map<String, int> hourlyStats = {};

    for (final entry in history) {
      final time = entry['time'] as String;
      final hour = time.split(':')[0];
      final count = entry['count'] as int;

      hourlyStats[hour] = (hourlyStats[hour] ?? 0) + count;
    }

    return hourlyStats;
  }
}
