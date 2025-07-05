import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/compte.dart';
import '../models/categorie.dart';
import '../models/transaction_model.dart' as app_model;
import 'package:flutter/foundation.dart' show kIsWeb;

class PersistentCacheService {
  static Database? _database;
  static const String _dbName = 'toutie_budget_cache.db';
  static const int _dbVersion = 1;

  // Tables
  static const String _tableComptes = 'comptes_cache';
  static const String _tableCategories = 'categories_cache';
  static const String _tableTransactions = 'transactions_cache';
  static const String _tableCacheMeta = 'cache_meta';

  // Initialiser la base de données
  static Future<Database> get database async {
    if (_database != null) return _database!;

    // Sur le web, on utilise le cache mémoire uniquement
    if (kIsWeb) {
      throw UnsupportedError(
          'PersistentCacheService n\'est pas supporté sur le web');
    }

    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    // Table des comptes
    await db.execute('''
      CREATE TABLE $_tableComptes (
        id TEXT PRIMARY KEY,
        data TEXT NOT NULL,
        last_updated INTEGER NOT NULL
      )
    ''');

    // Table des catégories
    await db.execute('''
      CREATE TABLE $_tableCategories (
        id TEXT PRIMARY KEY,
        data TEXT NOT NULL,
        last_updated INTEGER NOT NULL
      )
    ''');

    // Table des transactions
    await db.execute('''
      CREATE TABLE $_tableTransactions (
        compte_id TEXT NOT NULL,
        data TEXT NOT NULL,
        last_updated INTEGER NOT NULL,
        PRIMARY KEY (compte_id)
      )
    ''');

    // Table des métadonnées du cache
    await db.execute('''
      CREATE TABLE $_tableCacheMeta (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  static Future<void> _onUpgrade(
      Database db, int oldVersion, int newVersion) async {
    // Gérer les migrations futures ici
  }

  // Sauvegarder les comptes
  static Future<void> saveComptes(List<Compte> comptes) async {
    if (kIsWeb) return;

    final db = await database;
    final batch = db.batch();

    for (final compte in comptes) {
      batch.insert(
        _tableComptes,
        {
          'id': compte.id,
          'data': jsonEncode(compte.toMap()),
          'last_updated': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit();
  }

  // Charger les comptes
  static Future<List<Compte>?> loadComptes() async {
    if (kIsWeb) return null;

    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(_tableComptes);

    if (maps.isEmpty) return null;

    return maps.map((map) {
      final data = jsonDecode(map['data'] as String);
      return Compte.fromMap(data, map['id'] as String);
    }).toList();
  }

  // Sauvegarder les catégories
  static Future<void> saveCategories(List<Categorie> categories) async {
    if (kIsWeb) return;

    final db = await database;
    final batch = db.batch();

    for (final categorie in categories) {
      batch.insert(
        _tableCategories,
        {
          'id': categorie.id,
          'data': jsonEncode(categorie.toMap()),
          'last_updated': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit();
  }

    // Charger les catégories
  static Future<List<Categorie>?> loadCategories() async {
    if (kIsWeb) return null;
    
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(_tableCategories);
    
    if (maps.isEmpty) return null;
    
    return maps.map((map) {
      final data = jsonDecode(map['data'] as String);
      return Categorie.fromMap(data);
    }).toList();
  }

  // Sauvegarder les transactions d'un compte
  static Future<void> saveTransactions(
      String compteId, List<app_model.Transaction> transactions) async {
    if (kIsWeb) return;

    final db = await database;
    await db.insert(
      _tableTransactions,
      {
        'compte_id': compteId,
        'data': jsonEncode(transactions.map((t) => t.toJson()).toList()),
        'last_updated': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Charger les transactions d'un compte
  static Future<List<app_model.Transaction>?> loadTransactions(
      String compteId) async {
    if (kIsWeb) return null;

    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableTransactions,
      where: 'compte_id = ?',
      whereArgs: [compteId],
    );

    if (maps.isEmpty) return null;

    final data = jsonDecode(maps.first['data'] as String);
    return (data as List)
        .map((item) => app_model.Transaction.fromJson(item))
        .toList();
  }

  // Vérifier si le cache est valide (moins de 24h)
  static Future<bool> isCacheValid(String table, [String? id]) async {
    if (kIsWeb) return false;

    final db = await database;
    final String whereClause = id != null ? 'id = ?' : '1=1';
    final List<dynamic> whereArgs = id != null ? [id] : [];

    final List<Map<String, dynamic>> maps = await db.query(
      table,
      columns: ['last_updated'],
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'last_updated DESC',
      limit: 1,
    );

    if (maps.isEmpty) return false;

    final lastUpdated =
        DateTime.fromMillisecondsSinceEpoch(maps.first['last_updated'] as int);
    final cacheAge = DateTime.now().difference(lastUpdated);

    // Cache valide pendant 24h
    return cacheAge.inHours < 24;
  }

  // Nettoyer le cache expiré
  static Future<void> cleanExpiredCache() async {
    if (kIsWeb) return;

    final db = await database;
    final cutoffTime = DateTime.now()
        .subtract(const Duration(hours: 24))
        .millisecondsSinceEpoch;

    await db.delete(
      _tableComptes,
      where: 'last_updated < ?',
      whereArgs: [cutoffTime],
    );

    await db.delete(
      _tableCategories,
      where: 'last_updated < ?',
      whereArgs: [cutoffTime],
    );

    await db.delete(
      _tableTransactions,
      where: 'last_updated < ?',
      whereArgs: [cutoffTime],
    );
  }

  // Vider tout le cache
  static Future<void> clearAllCache() async {
    if (kIsWeb) return;

    final db = await database;
    await db.delete(_tableComptes);
    await db.delete(_tableCategories);
    await db.delete(_tableTransactions);
    await db.delete(_tableCacheMeta);
  }

  // Obtenir la taille du cache
  static Future<Map<String, int>> getCacheSize() async {
    if (kIsWeb) return {};

    final db = await database;

    final comptesCount = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM $_tableComptes')) ??
        0;

    final categoriesCount = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM $_tableCategories')) ??
        0;

    final transactionsCount = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM $_tableTransactions')) ??
        0;

    return {
      'comptes': comptesCount,
      'categories': categoriesCount,
      'transactions': transactionsCount,
    };
  }

  // Fermer la base de données
  static Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
