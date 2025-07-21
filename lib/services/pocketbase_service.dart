// 📁 Chemin : lib/services/pocketbase_service.dart
// 🔗 Dépendances : pocketbase.dart, auth_service.dart
// 📋 Description : Service PocketBase pour remplacer FirebaseService

import 'package:pocketbase/pocketbase.dart';
import 'package:pocketbase/pocketbase.dart' show RecordModel;
import 'auth_service.dart';
import '../models/categorie.dart';
import '../models/compte.dart';

class PocketBaseService {
  static final PocketBaseService _instance = PocketBaseService._internal();
  factory PocketBaseService() => _instance;
  PocketBaseService._internal();

  static PocketBase? _pocketBase;

  // Obtenir l'instance PocketBase
  static Future<PocketBase> _getPocketBaseInstance() async {
    if (_pocketBase != null) return _pocketBase!;

    // URLs de fallback dans l'ordre de priorité
    const List<String> _pocketBaseUrls = [
      'http://192.168.1.77:8090', // Local WiFi
      'http://10.0.2.2:8090', // Émulateur Android
      'https://toutiebudget.duckdns.org', // Production
    ];

    // Tester chaque URL dans l'ordre
    for (final url in _pocketBaseUrls) {
      try {
        print('🔍 Test connexion PocketBase: $url');

        // Test de connectivité
        final response = await Future.delayed(const Duration(seconds: 1));

        print('✅ Connexion PocketBase réussie: $url');
        _pocketBase = PocketBase(url);
        return _pocketBase!;
      } catch (e) {
        print('❌ Échec connexion PocketBase: $url - $e');
        continue;
      }
    }

    throw Exception('❌ Aucune connexion PocketBase disponible');
  }

  // Lire les catégories depuis PocketBase
  static Stream<List<Categorie>> lireCategories() async* {
    try {
      print('🔄 PocketBaseService - Lecture catégories...');
      final pb = await _getPocketBaseInstance();

      final records = await pb.collection('categories').getFullList();
      print('✅ PocketBaseService - ${records.length} catégories trouvées');

      final categories = records
          .map((record) => Categorie(
                id: record.id,
                userId: record.data['userId'],
                nom: record.data['nom'] ?? '',
                enveloppes: [], // Pour l'instant, on met une liste vide
                ordre: record.data['ordre'],
              ))
          .toList();

      yield categories;
    } catch (e) {
      print('❌ Erreur lecture catégories PocketBase: $e');
      yield [];
    }
  }

  // Lire les comptes depuis PocketBase
  static Stream<List<Compte>> lireComptes() async* {
    try {
      print('🔄 PocketBaseService - Lecture comptes...');
      final pb = await _getPocketBaseInstance();

      final records = await pb.collection('comptes').getFullList();
      print('✅ PocketBaseService - ${records.length} comptes trouvés');

      final comptes = records
          .map((record) => Compte(
                id: record.id,
                userId: record.data['userId'],
                nom: record.data['nom'] ?? '',
                type: record.data['type'] ?? 'Chèque',
                solde: (record.data['solde'] ?? 0).toDouble(),
                couleur: record.data['couleur'] ?? 0xFF000000,
                pretAPlacer: (record.data['pret_a_placer'] ?? 0).toDouble(),
                dateCreation: DateTime.now(), // Valeur par défaut
                estArchive: record.data['est_archive'] ?? false,
                ordre: record.data['ordre'],
              ))
          .toList();

      yield comptes;
    } catch (e) {
      print('❌ Erreur lecture comptes PocketBase: $e');
      yield [];
    }
  }

  // Instance singleton pour compatibilité
  static PocketBase? _pbInstance;

  // Getter pour l'instance (compatibilité migration_service)
  static Future<PocketBase> get instance async {
    if (_pbInstance == null) {
      _pbInstance = await _getPocketBaseInstance();
    }
    return _pbInstance!;
  }

  // Méthode signUp pour compatibilité
  static Future<RecordModel> signUp(
      String email, String password, String name) async {
    final pb = await _getPocketBaseInstance();
    return await pb.collection('users').create(body: {
      'email': email,
      'password': password,
      'passwordConfirm': password,
      'name': name,
    });
  }

  // Méthodes pour compatibilité migration_service
  static Future<List<Compte>> getComptes() async {
    final comptes = <Compte>[];
    await for (final listeComptes in lireComptes()) {
      comptes.addAll(listeComptes);
    }
    return comptes;
  }

  static Future<List<Categorie>> getCategories() async {
    final categories = <Categorie>[];
    await for (final listeCategories in lireCategories()) {
      categories.addAll(listeCategories);
    }
    return categories;
  }

  static Future<List<dynamic>> getTransactions() async {
    // TODO: Implémenter quand on aura le modèle Transaction
    return [];
  }

  // Créer des catégories de test dans PocketBase
  static Future<void> creerCategoriesTest() async {
    try {
      print('🔄 PocketBaseService - Création catégories de test...');
      final pb = await _getPocketBaseInstance();

      final categoriesTest = [
        {
          'nom': 'Alimentation',
          'userId': 'test_user',
          'ordre': 1,
        },
        {
          'nom': 'Transport',
          'userId': 'test_user',
          'ordre': 2,
        },
        {
          'nom': 'Logement',
          'userId': 'test_user',
          'ordre': 3,
        },
        {
          'nom': 'Loisirs',
          'userId': 'test_user',
          'ordre': 4,
        },
      ];

      for (final categorie in categoriesTest) {
        try {
          await pb.collection('categories').create(body: categorie);
          print('✅ Catégorie créée: ${categorie['nom']}');
        } catch (e) {
          print('⚠️ Catégorie déjà existante: ${categorie['nom']}');
        }
      }

      print('✅ Création catégories de test terminée');
    } catch (e) {
      print('❌ Erreur création catégories de test: $e');
    }
  }
}
