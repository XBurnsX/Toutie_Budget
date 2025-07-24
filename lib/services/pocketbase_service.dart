// 📁 Chemin : lib/services/pocketbase_service.dart
// 🔗 Dépendances : pocketbase.dart, auth_service.dart
// 📋 Description : Service PocketBase pour remplacer FirebaseService - Version COMPLÈTE avec TEMPS RÉEL

import 'package:pocketbase/pocketbase.dart';
import 'package:pocketbase/pocketbase.dart' show RecordModel;
import '../models/enveloppe.dart';
import 'auth_service.dart';
import '../models/categorie.dart';
import '../models/compte.dart';
import 'allocation_service.dart';

import 'dart:async';

class PocketBaseService {
  static final PocketBaseService _instance = PocketBaseService._internal();
  factory PocketBaseService() => _instance;
  PocketBaseService._internal();

  static PocketBase? _pocketBase;

  // 🔥 TEMPS RÉEL - Streams en temps réel
  static final Map<String, StreamController<List<Compte>>> _comptesControllers =
      {};
  static final Map<String, StreamController<List<Categorie>>>
      _categoriesControllers = {};
  static final Map<String, StreamController<List<Enveloppe>>>
      _enveloppesControllers = {};

  // Cache des données en temps réel
  static final Map<String, List<Compte>> _comptesCache = {};
  static final Map<String, List<Categorie>> _categoriesCache = {};
  static final Map<String, List<Enveloppe>> _enveloppesCache = {};

  // Timers pour les mises à jour périodiques
  static Timer? _comptesTimer;
  static Timer? _categoriesTimer;
  static Timer? _enveloppesTimer;

  // Obtenir l'instance PocketBase depuis AuthService
  static Future<PocketBase> _getPocketBaseInstance() async {
    // UTILISER L'INSTANCE D'AUTHSERVICE au lieu de créer la nôtre !
    final authServiceInstance = AuthService.pocketBaseInstance;
    if (authServiceInstance != null) {
      return authServiceInstance;
    }

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
        // Test simple pour vérifier la connexion
        _pocketBase = PocketBase(url);
        await _pocketBase!.collection('users').getList(page: 1, perPage: 1);

        return _pocketBase!;
      } catch (e) {
        continue;
      }
    }

    throw Exception('❌ Aucune connexion PocketBase disponible');
  }

  // 🔥 MÉTHODES TEMPS RÉEL
  // ============================================================================

  // Initialiser les streams temps réel
  static Future<void> _initializeRealtimeStreams() async {
    try {
      // Éviter la double initialisation
      if (_comptesTimer != null &&
          _categoriesTimer != null &&
          _enveloppesTimer != null) {
        print('🔄 Streams déjà initialisés, skip...');
        return;
      }

      final pb = await _getPocketBaseInstance();
      final userId = pb.authStore.model?.id;

      if (userId == null) return;

      print('🔥 Initialisation du temps réel PocketBase...');

      // Créer les contrôleurs de stream
      _comptesControllers['comptes'] =
          StreamController<List<Compte>>.broadcast();
      _categoriesControllers['categories'] =
          StreamController<List<Categorie>>.broadcast();
      _enveloppesControllers['enveloppes'] =
          StreamController<List<Enveloppe>>.broadcast();

      // Charger les données initiales
      await _loadInitialDataSimple();

      // Démarrer les timers pour les mises à jour périodiques
      _comptesTimer?.cancel();
      _categoriesTimer?.cancel();
      _enveloppesTimer?.cancel();

      _comptesTimer = Timer.periodic(
          const Duration(milliseconds: 500), (_) => _updateComptesData());
      _categoriesTimer = Timer.periodic(
          const Duration(milliseconds: 750), (_) => _updateCategoriesData());
      _enveloppesTimer = Timer.periodic(
          const Duration(milliseconds: 1000), (_) => _updateEnveloppesData());

      print('✅ Temps réel PocketBase initialisé avec succès');
    } catch (e) {
      print('❌ Erreur initialisation temps réel: $e');
    }
  }

  // S'abonner à une collection avec filtrage par utilisateur
  static Future<void> _subscribeToCollection(
      String collectionName, String userId, String cacheKey) async {
    try {
      final pb = await _getPocketBaseInstance();

      // Créer le contrôleur de stream s'il n'existe pas
      if (!_comptesControllers.containsKey(cacheKey)) {
        _comptesControllers[cacheKey] =
            StreamController<List<Compte>>.broadcast();
      }
      if (!_categoriesControllers.containsKey(cacheKey)) {
        _categoriesControllers[cacheKey] =
            StreamController<List<Categorie>>.broadcast();
      }
      if (!_enveloppesControllers.containsKey(cacheKey)) {
        _enveloppesControllers[cacheKey] =
            StreamController<List<Enveloppe>>.broadcast();
      }

      // S'abonner à la collection avec filtre utilisateur
      final subscription = pb.collection(collectionName).subscribe(
            'utilisateur_id = "$userId"',
            (data) => _handleRealtimeUpdate(collectionName, data, cacheKey),
          );

      // Plus de subscriptions à gérer

      // Charger les données initiales
      await _loadInitialData(collectionName, userId, cacheKey);
    } catch (e) {
      print('❌ Erreur subscription $collectionName: $e');
    }
  }

  // Gérer les mises à jour en temps réel
  static void _handleRealtimeUpdate(
      String collectionName, dynamic data, String cacheKey) {
    try {
      switch (data.action) {
        case 'create':
          _handleCreate(collectionName, data, cacheKey);
          break;
        case 'update':
          _handleUpdate(collectionName, data, cacheKey);
          break;
        case 'delete':
          _handleDelete(collectionName, data, cacheKey);
          break;
      }
    } catch (e) {
      print('❌ Erreur traitement temps réel: $e');
    }
  }

  // Gérer la création d'un enregistrement
  static void _handleCreate(
      String collectionName, dynamic data, String cacheKey) {
    try {
      final record = data.record;
      if (record == null) return;

      switch (cacheKey) {
        case 'comptes':
          final compte = Compte.fromPocketBase(
              record.data, record.id, _getCompteType(collectionName));
          _comptesCache[cacheKey] ??= [];
          _comptesCache[cacheKey]!.add(compte);
          _comptesControllers[cacheKey]?.add(_comptesCache[cacheKey]!);
          break;
        case 'categories':
          final categorie = Categorie(
            id: record.id,
            utilisateurId: record.data['utilisateur_id'] ?? '',
            nom: record.data['nom'] ?? '',
            ordre: record.data['ordre'] ?? 0,
          );
          _categoriesCache[cacheKey] ??= [];
          _categoriesCache[cacheKey]!.add(categorie);
          _categoriesControllers[cacheKey]?.add(_categoriesCache[cacheKey]!);
          break;
        case 'enveloppes':
          final enveloppe = Enveloppe(
            id: record.id,
            utilisateurId: record.data['utilisateur_id'] ?? '',
            categorieId: record.data['categorie_id'] ?? '',
            nom: record.data['nom'] ?? '',
            soldeEnveloppe: (record.data['solde_enveloppe'] ?? 0).toDouble(),
          );
          _enveloppesCache[cacheKey] ??= [];
          _enveloppesCache[cacheKey]!.add(enveloppe);
          _enveloppesControllers[cacheKey]?.add(_enveloppesCache[cacheKey]!);
          break;
      }
    } catch (e) {
      print('❌ Erreur création temps réel: $e');
    }
  }

  // Gérer la mise à jour d'un enregistrement
  static void _handleUpdate(
      String collectionName, dynamic data, String cacheKey) {
    try {
      final record = data.record;
      if (record == null) return;

      switch (cacheKey) {
        case 'comptes':
          final compte = Compte.fromPocketBase(
              record.data, record.id, _getCompteType(collectionName));
          _comptesCache[cacheKey] ??= [];
          final index =
              _comptesCache[cacheKey]!.indexWhere((c) => c.id == record.id);
          if (index != -1) {
            _comptesCache[cacheKey]![index] = compte;
            _comptesControllers[cacheKey]?.add(_comptesCache[cacheKey]!);
          }
          break;
        case 'categories':
          final categorie = Categorie(
            id: record.id,
            utilisateurId: record.data['utilisateur_id'] ?? '',
            nom: record.data['nom'] ?? '',
            ordre: record.data['ordre'] ?? 0,
          );
          _categoriesCache[cacheKey] ??= [];
          final index =
              _categoriesCache[cacheKey]!.indexWhere((c) => c.id == record.id);
          if (index != -1) {
            _categoriesCache[cacheKey]![index] = categorie;
            _categoriesControllers[cacheKey]?.add(_categoriesCache[cacheKey]!);
          }
          break;
        case 'enveloppes':
          final enveloppe = Enveloppe(
            id: record.id,
            utilisateurId: record.data['utilisateur_id'] ?? '',
            categorieId: record.data['categorie_id'] ?? '',
            nom: record.data['nom'] ?? '',
            soldeEnveloppe: (record.data['solde_enveloppe'] ?? 0).toDouble(),
          );
          _enveloppesCache[cacheKey] ??= [];
          final index =
              _enveloppesCache[cacheKey]!.indexWhere((e) => e.id == record.id);
          if (index != -1) {
            _enveloppesCache[cacheKey]![index] = enveloppe;
            _enveloppesControllers[cacheKey]?.add(_enveloppesCache[cacheKey]!);
          }
          break;
      }
    } catch (e) {
      print('❌ Erreur mise à jour temps réel: $e');
    }
  }

  // Gérer la suppression d'un enregistrement
  static void _handleDelete(
      String collectionName, dynamic data, String cacheKey) {
    try {
      final record = data.record;
      if (record == null) return;

      switch (cacheKey) {
        case 'comptes':
          _comptesCache[cacheKey] ??= [];
          _comptesCache[cacheKey]!.removeWhere((c) => c.id == record.id);
          _comptesControllers[cacheKey]?.add(_comptesCache[cacheKey]!);
          break;
        case 'categories':
          _categoriesCache[cacheKey] ??= [];
          _categoriesCache[cacheKey]!.removeWhere((c) => c.id == record.id);
          _categoriesControllers[cacheKey]?.add(_categoriesCache[cacheKey]!);
          break;
        case 'enveloppes':
          _enveloppesCache[cacheKey] ??= [];
          _enveloppesCache[cacheKey]!.removeWhere((e) => e.id == record.id);
          _enveloppesControllers[cacheKey]?.add(_enveloppesCache[cacheKey]!);
          break;
      }
    } catch (e) {
      print('❌ Erreur suppression temps réel: $e');
    }
  }

  // Déterminer le type de compte selon la collection
  static String _getCompteType(String collectionName) {
    switch (collectionName) {
      case 'comptes_cheques':
        return 'Chèque';
      case 'comptes_credits':
        return 'Carte de crédit';
      case 'comptes_investissement':
        return 'Investissement';
      case 'comptes_dettes':
      case 'pret_personnel':
        return 'Dette';
      default:
        return 'Chèque';
    }
  }

  // Charger les données initiales
  static Future<void> _loadInitialData(
      String collectionName, String userId, String cacheKey) async {
    try {
      final pb = await _getPocketBaseInstance();

      final records = await pb.collection(collectionName).getFullList(
            filter: 'utilisateur_id = "$userId"',
          );

      switch (cacheKey) {
        case 'comptes':
          final comptes = records
              .map((record) => Compte.fromPocketBase(
                  record.data, record.id, _getCompteType(collectionName)))
              .toList();
          _comptesCache[cacheKey] = comptes;
          _comptesControllers[cacheKey]?.add(comptes);
          break;
        case 'categories':
          final categories = records
              .map((record) => Categorie(
                    id: record.id,
                    utilisateurId: record.data['utilisateur_id'] ?? '',
                    nom: record.data['nom'] ?? '',
                    ordre: record.data['ordre'] ?? 0,
                  ))
              .toList();
          _categoriesCache[cacheKey] = categories;
          _categoriesControllers[cacheKey]?.add(categories);
          break;
        case 'enveloppes':
          final enveloppes = records
              .map((record) => Enveloppe(
                    id: record.id,
                    utilisateurId: record.data['utilisateur_id'] ?? '',
                    categorieId: record.data['categorie_id'] ?? '',
                    nom: record.data['nom'] ?? '',
                    soldeEnveloppe:
                        (record.data['solde_enveloppe'] ?? 0).toDouble(),
                  ))
              .toList();
          _enveloppesCache[cacheKey] = enveloppes;
          _enveloppesControllers[cacheKey]?.add(enveloppes);
          break;
      }
    } catch (e) {
      print('❌ Erreur chargement initial $collectionName: $e');
    }
  }

  // Nettoyer toutes les subscriptions
  static Future<void> _disposeAllSubscriptions() async {
    // Arrêter les timers
    _comptesTimer?.cancel();
    _categoriesTimer?.cancel();
    _enveloppesTimer?.cancel();

    // Fermer les controllers
    _comptesControllers.values.forEach((controller) => controller.close());
    _categoriesControllers.values.forEach((controller) => controller.close());
    _enveloppesControllers.values.forEach((controller) => controller.close());

    // Vider les caches
    _comptesCache.clear();
    _categoriesCache.clear();
    _enveloppesCache.clear();

    print('🧹 Nettoyage des streams terminé');
  }

  // Nettoyer tous les contrôleurs
  static void _disposeAllControllers() {
    for (final controller in _comptesControllers.values) {
      controller.close();
    }
    for (final controller in _categoriesControllers.values) {
      controller.close();
    }
    for (final controller in _enveloppesControllers.values) {
      controller.close();
    }
    _comptesControllers.clear();
    _categoriesControllers.clear();
    _enveloppesControllers.clear();
  }

  // 🔥 STREAMS TEMPS RÉEL
  // ============================================================================

  // Lire les catégories en temps réel depuis PocketBase
  static Stream<List<Categorie>> lireCategories() async* {
    try {
      final pb = await _getPocketBaseInstance();
      final userId = pb.authStore.model?.id;

      if (userId == null) {
        yield [];
        return;
      }

      // Charger les catégories directement
      final records = await pb.collection('categories').getFullList(
            filter: 'utilisateur_id = "$userId"',
            sort: 'ordre,nom',
          );

      final List<Categorie> categories = [];

      for (final record in records) {
        // Créer la catégorie
        final categorie = Categorie(
          id: record.id,
          utilisateurId: record.data['utilisateur_id'] ?? '',
          nom: record.data['nom'] ?? '',
          ordre: record.data['ordre'] ?? 0,
        );

        categories.add(categorie);
      }

      yield categories;
    } catch (e) {
      print('❌ Erreur lecture catégories: $e');
      yield [];
    }
  }

  // Lire uniquement les comptes chèques en temps réel depuis PocketBase
  static Stream<List<Compte>> lireComptesChecques() async* {
    try {
      final pb = await _getPocketBaseInstance();
      final userId = pb.authStore.model?.id;

      if (userId == null) {
        yield [];
        return;
      }

      // Initialiser les streams temps réel si pas déjà fait
      if (_comptesControllers.isEmpty) {
        await _initializeRealtimeStreams();
      }

      // Retourner le stream temps réel
      if (_comptesControllers.containsKey('comptes')) {
        yield* _comptesControllers['comptes']!.stream.map(
            (comptes) => comptes.where((c) => c.type == 'Chèque').toList());
      } else {
        // Fallback vers la méthode non-temps réel
        final filtre = 'utilisateur_id = "$userId"';

        final records = await pb.collection('comptes_cheques').getFullList(
              filter: filtre,
            );

        final comptes = records
            .map((record) =>
                Compte.fromPocketBase(record.data, record.id, 'Chèque'))
            .toList();

        yield comptes;
      }
    } catch (e) {
      yield [];
    }
  }

  // Lire uniquement les comptes de crédit en temps réel depuis PocketBase
  static Stream<List<Compte>> lireComptesCredits() async* {
    try {
      final pb = await _getPocketBaseInstance();
      final userId = pb.authStore.model?.id;

      if (userId == null) {
        yield [];
        return;
      }

      // Initialiser les streams temps réel si pas déjà fait
      if (_comptesControllers.isEmpty) {
        await _initializeRealtimeStreams();
      }

      // Retourner le stream temps réel
      if (_comptesControllers.containsKey('comptes')) {
        yield* _comptesControllers['comptes']!.stream.map((comptes) =>
            comptes.where((c) => c.type == 'Carte de crédit').toList());
      } else {
        // Fallback vers la méthode non-temps réel
        final records = await pb.collection('comptes_credits').getFullList(
              filter: 'utilisateur_id = "$userId"',
            );

        final comptes = records
            .map((record) => Compte.fromPocketBase(
                record.data, record.id, 'Carte de crédit'))
            .toList();

        yield comptes;
      }
    } catch (e) {
      yield [];
    }
  }

  // Lire uniquement les comptes d'investissement en temps réel depuis PocketBase
  static Stream<List<Compte>> lireComptesInvestissement() async* {
    try {
      final pb = await _getPocketBaseInstance();
      final userId = pb.authStore.model?.id;

      if (userId == null) {
        yield [];
        return;
      }

      // Initialiser les streams temps réel si pas déjà fait
      if (_comptesControllers.isEmpty) {
        await _initializeRealtimeStreams();
      }

      // Retourner le stream temps réel
      if (_comptesControllers.containsKey('comptes')) {
        yield* _comptesControllers['comptes']!.stream.map((comptes) =>
            comptes.where((c) => c.type == 'Investissement').toList());
      } else {
        // Fallback vers la méthode non-temps réel
        final records =
            await pb.collection('comptes_investissement').getFullList(
                  filter: 'utilisateur_id = "$userId"',
                );

        final comptes = records
            .map((record) =>
                Compte.fromPocketBase(record.data, record.id, 'Investissement'))
            .toList();

        yield comptes;
      }
    } catch (e) {
      yield [];
    }
  }

  // Lire les dettes en temps réel depuis PocketBase
  static Stream<List<Compte>> lireComptesDettes() async* {
    try {
      final pb = await _getPocketBaseInstance();
      final userId = pb.authStore.model?.id;

      if (userId == null) {
        yield [];
        return;
      }

      // Initialiser les streams temps réel si pas déjà fait
      if (_comptesControllers.isEmpty) {
        await _initializeRealtimeStreams();
      }

      // Retourner le stream temps réel
      if (_comptesControllers.containsKey('comptes')) {
        yield* _comptesControllers['comptes']!
            .stream
            .map((comptes) => comptes.where((c) => c.type == 'Dette').toList());
      } else {
        // Fallback vers la méthode non-temps réel
        List<Compte> toutesLesDettes = [];

        // 1. Récupérer les dettes de la collection comptes_dettes
        try {
          final recordsDettes =
              await pb.collection('comptes_dettes').getFullList(
                    filter: 'utilisateur_id = "$userId"',
                  );

          final comptesDettes = recordsDettes
              .map((record) =>
                  Compte.fromPocketBase(record.data, record.id, 'Dette'))
              .toList();

          toutesLesDettes.addAll(comptesDettes);
        } catch (e) {}

        // 2. Récupérer les prêts personnels de la collection pret_personnel
        try {
          final recordsPrets =
              await pb.collection('pret_personnel').getFullList(
                    filter: 'utilisateur_id = "$userId"',
                  );

          final comptesPrets = recordsPrets
              .map((record) =>
                  Compte.fromPocketBase(record.data, record.id, 'Dette'))
              .toList();

          toutesLesDettes.addAll(comptesPrets);
        } catch (e) {}

        yield toutesLesDettes;
      }
    } catch (e) {
      yield [];
    }
  }

  // Combiner tous les types de comptes en un seul stream temps réel
  static Stream<List<Compte>> lireTousLesComptes() async* {
    try {
      // Charger les données directement sans streams complexes
      final List<Compte> tousLesComptes = [];

      // Comptes chèques
      final comptesChecques = await _chargerComptesChecques();
      tousLesComptes.addAll(comptesChecques);

      // Comptes crédits
      final comptesCredits = await _chargerComptesCredits();
      tousLesComptes.addAll(comptesCredits);

      // Comptes investissement
      final comptesInvestissement = await _chargerComptesInvestissement();
      tousLesComptes.addAll(comptesInvestissement);

      // Comptes dettes
      final comptesDettes = await _chargerComptesDettes();
      tousLesComptes.addAll(comptesDettes);

      yield tousLesComptes;
    } catch (e) {
      print('❌ Erreur lecture tous les comptes: $e');
      yield [];
    }
  }

  // Méthode lireComptes pour compatibilité avec page_archivage
  static Stream<List<Compte>> lireComptes() async* {
    try {
      final pb = await _getPocketBaseInstance();
      final userId = pb.authStore.model?.id;

      if (userId == null) {
        yield [];
        return;
      }

      // Initialiser les streams temps réel si pas déjà fait
      if (_comptesControllers.isEmpty) {
        await _initializeRealtimeStreams();
      }

      // Retourner le stream temps réel
      if (_comptesControllers.containsKey('comptes')) {
        yield* _comptesControllers['comptes']!.stream;
      } else {
        // Fallback vers la méthode non-temps réel
        final records = await pb.collection('comptes').getFullList(
              filter: 'utilisateur_id = "$userId"',
              sort: 'ordre,nom',
            );

        final comptes = records.map((record) {
          return Compte(
            id: record.id,
            nom: record.data['nom'] ?? '',
            solde: (record.data['solde'] ?? 0.0).toDouble(),
            type: record.data['type'] ?? 'cheque',
            couleur: int.tryParse(record.data['couleur']?.toString() ?? '0') ??
                0x2196F3,
            pretAPlacer: (record.data['pret_a_placer'] ?? 0.0).toDouble(),
            dateCreation: DateTime.tryParse(record.data['created'] ?? '') ??
                DateTime.now(),
            estArchive: record.data['archive'] ?? false,
            ordre: record.data['ordre'] ?? 0,
            userId: record.data['utilisateur_id'] ?? userId,
          );
        }).toList();

        yield comptes;
      }
    } catch (e) {
      yield [];
    }
  }

  // Méthodes de chargement direct des comptes
  static Future<List<Compte>> _chargerComptesChecques() async {
    try {
      final pb = await _getPocketBaseInstance();
      final userId = pb.authStore.model?.id;
      if (userId == null) return [];

      final records = await pb.collection('comptes_cheques').getFullList(
            filter: 'utilisateur_id = "$userId"',
          );

      return records
          .map((record) =>
              Compte.fromPocketBase(record.data, record.id, 'Chèque'))
          .toList();
    } catch (e) {
      print('❌ Erreur chargement comptes chèques: $e');
      return [];
    }
  }

  static Future<List<Compte>> _chargerComptesCredits() async {
    try {
      final pb = await _getPocketBaseInstance();
      final userId = pb.authStore.model?.id;
      if (userId == null) return [];

      final records = await pb.collection('comptes_credits').getFullList(
            filter: 'utilisateur_id = "$userId"',
          );

      return records
          .map((record) =>
              Compte.fromPocketBase(record.data, record.id, 'Crédit'))
          .toList();
    } catch (e) {
      print('❌ Erreur chargement comptes crédits: $e');
      return [];
    }
  }

  static Future<List<Compte>> _chargerComptesInvestissement() async {
    try {
      final pb = await _getPocketBaseInstance();
      final userId = pb.authStore.model?.id;
      if (userId == null) return [];

      final records = await pb.collection('comptes_investissement').getFullList(
            filter: 'utilisateur_id = "$userId"',
          );

      return records
          .map((record) =>
              Compte.fromPocketBase(record.data, record.id, 'Investissement'))
          .toList();
    } catch (e) {
      print('❌ Erreur chargement comptes investissement: $e');
      return [];
    }
  }

  static Future<List<Compte>> _chargerComptesDettes() async {
    try {
      final pb = await _getPocketBaseInstance();
      final userId = pb.authStore.model?.id;
      if (userId == null) return [];

      final records = await pb.collection('comptes_dettes').getFullList(
            filter: 'utilisateur_id = "$userId"',
          );

      return records
          .map((record) =>
              Compte.fromPocketBase(record.data, record.id, 'Dette'))
          .toList();
    } catch (e) {
      print('❌ Erreur chargement comptes dettes: $e');
      return [];
    }
  }

  // Supprimer une catégorie par ID
  static Future<void> supprimerCategorieParId(String categorieId) async {
    try {
      final pb = await _getPocketBaseInstance();
      await pb.collection('categories').delete(categorieId);
      print('✅ Catégorie supprimée: $categorieId');
    } catch (e) {
      print('❌ Erreur suppression catégorie: $e');
      rethrow;
    }
  }

  // Méthode pour récupérer les enveloppes d'une catégorie spécifique
  static Future<List<Map<String, dynamic>>> lireEnveloppesParCategorie(
      String categorieId) async {
    try {
      final pb = await _getPocketBaseInstance();
      final records = await pb.collection('enveloppes').getFullList(
            filter: 'categorie_id = "$categorieId"',
            sort: 'nom',
          );

      return records.map((record) => record.toJson()).toList();
    } catch (e) {
      return [];
    }
  }

  // Méthode pour récupérer toutes les enveloppes avec leur catégorie
  static Future<Map<String, List<Map<String, dynamic>>>>
      lireEnveloppesGroupeesParCategorie({DateTime? mois}) async {
    try {
      final pb = await _getPocketBaseInstance();

      // Vérifier que l'utilisateur est connecté
      final utilisateurId = pb.authStore.model?.id;
      if (utilisateurId == null) {
        return {};
      }

      // Filtrer par utilisateur connecté
      final filtre = 'utilisateur_id = "$utilisateurId"';

      final records = await pb.collection('enveloppes').getFullList(
            filter: filtre,
            expand: 'categorie_id',
            sort: 'categorie_id.nom,nom',
          );

      final Map<String, List<Map<String, dynamic>>> enveloppesParCategorie = {};

      for (final record in records) {
        final categorieId = record.data['categorie_id'] as String;
        final enveloppeData = record.toJson();

        if (!enveloppesParCategorie.containsKey(categorieId)) {
          enveloppesParCategorie[categorieId] = [];
        }
        enveloppesParCategorie[categorieId]!.add(enveloppeData);
      }

      return enveloppesParCategorie;
    } catch (e) {
      print('❌ Erreur lecture enveloppes groupées: $e');
      return {};
    }
  }

  // Méthode pour récupérer toutes les enveloppes d'un utilisateur
  static Future<List<Map<String, dynamic>>> lireToutesEnveloppes() async {
    try {
      final pb = await _getPocketBaseInstance();
      final userId = pb.authStore.model?.id;
      if (userId == null) throw Exception('Utilisateur non connecté');

      final records = await pb.collection('enveloppes').getFullList(
            filter: 'utilisateur_id = "$userId"',
            expand: 'categorie_id',
            sort: 'categorie_id.nom,nom',
          );

      return records.map((record) => record.toJson()).toList();
    } catch (e) {
      return [];
    }
  }

  // ============================================================================
  // MÉTHODES POUR GÉRER LES ENVELOPPES
  // ============================================================================

  // Méthode pour ajouter une nouvelle enveloppe
  static Future<String> ajouterEnveloppe(
      Map<String, dynamic> enveloppeData) async {
    try {
      final pb = await _getPocketBaseInstance();
      final userId = pb.authStore.model?.id;
      if (userId == null) throw Exception('Utilisateur non connecté');

      // Ajouter l'ID utilisateur si pas déjà présent
      enveloppeData['utilisateur_id'] = userId;

      final record =
          await pb.collection('enveloppes').create(body: enveloppeData);
      return record.id;
    } catch (e) {
      throw Exception('Erreur lors de l\'ajout de l\'enveloppe: $e');
    }
  }

  // Méthode pour mettre à jour une enveloppe
  static Future<void> mettreAJourEnveloppe(
      String enveloppeId, Map<String, dynamic> donnees) async {
    try {
      final pb = await _getPocketBaseInstance();
      await pb.collection('enveloppes').update(enveloppeId, body: donnees);
    } catch (e) {
      throw Exception('Erreur lors de la mise à jour de l\'enveloppe: $e');
    }
  }

  // Méthode pour supprimer une enveloppe
  static Future<void> supprimerEnveloppe(String enveloppeId) async {
    try {
      final pb = await _getPocketBaseInstance();
      await pb.collection('enveloppes').delete(enveloppeId);
    } catch (e) {
      throw Exception('Erreur lors de la suppression de l\'enveloppe: $e');
    }
  }

  // Méthode pour archiver une enveloppe
  static Future<void> archiverEnveloppe(String enveloppeId) async {
    try {
      final pb = await _getPocketBaseInstance();
      await pb.collection('enveloppes').update(enveloppeId, body: {
        'est_archive': true,
      });
    } catch (e) {
      throw Exception('Erreur lors de l\'archivage de l\'enveloppe: $e');
    }
  }

  // Méthode pour restaurer une enveloppe archivée
  static Future<void> restaurerEnveloppe(String enveloppeId) async {
    try {
      final pb = await _getPocketBaseInstance();
      await pb.collection('enveloppes').update(enveloppeId, body: {
        'est_archive': false,
      });
    } catch (e) {
      throw Exception('Erreur lors de la restauration de l\'enveloppe: $e');
    }
  }

  // Méthode pour modifier une enveloppe (alias pour mettreAJourEnveloppe)
  static Future<void> modifierEnveloppe(Map<String, dynamic> donnees) async {
    final enveloppeId = donnees['id'];
    if (enveloppeId == null) {
      throw Exception('ID de l\'enveloppe manquant pour la modification');
    }

    // Retirer l'ID des données à envoyer
    final donneesModification = Map<String, dynamic>.from(donnees);
    donneesModification.remove('id');

    await mettreAJourEnveloppe(enveloppeId, donneesModification);
  }

  // Méthode pour ajouter un compte dans PocketBase
  static Future<void> ajouterCompte(Compte compte) async {
    try {
      final pb = await _getPocketBaseInstance();

      // Vérifier que l'utilisateur est connecté
      final utilisateurId = pb.authStore.model?.id;
      final utilisateurNom = pb.authStore.model?.getStringValue('name') ?? '';
      if (utilisateurId == null) {
        throw Exception('❌ Aucun utilisateur connecté dans PocketBase');
      }

      // Déterminer la collection selon le type de compte
      String nomCollection;
      Map<String, dynamic> donneesCompte;

      switch (compte.type) {
        case 'Chèque':
          nomCollection = 'comptes_cheques';
          donneesCompte = {
            'utilisateur_id': utilisateurId, // Utiliser l'ID au lieu du nom
            'nom': compte.nom,
            'solde': compte.solde,
            'pret_a_placer': compte.pretAPlacer,
            'couleur': '#${compte.couleur.toRadixString(16).padLeft(8, '0')}',
            'ordre': compte.ordre ?? 0,
            'archive': compte.estArchive,
          };
          break;

        case 'Carte de crédit':
          nomCollection = 'comptes_credits';
          donneesCompte = {
            'utilisateur_id': utilisateurId, // Utiliser l'ID au lieu du nom
            'nom': compte.nom,
            'solde_utilise': compte.solde.abs(), // Montant utilisé (positif)
            'limite_credit': compte.solde.abs() + 1000, // Limite par défaut
            'taux_interet': 19.99, // Taux par défaut
            'couleur': '#${compte.couleur.toRadixString(16).padLeft(8, '0')}',
            'ordre': compte.ordre ?? 0,
            'archive': compte.estArchive,
          };
          break;

        case 'Dette':
          nomCollection = 'comptes_dettes';
          donneesCompte = {
            'utilisateur_id':
                utilisateurId, // Utiliser le bon champ selon le guide
            'nom': compte.nom,
            'nom_tiers': compte.nom, // Nom du tiers
            'solde_dette': compte.solde.abs(), // Montant de la dette (positif)
            'montant_initial': compte.solde.abs(),
            'taux_interet': 0.0,
            'paiement_minimum': 0.0,
            'ordre': compte.ordre ?? 0,
            'archive': compte.estArchive,
          };
          break;

        case 'Investissement':
          nomCollection = 'comptes_investissement';
          donneesCompte = {
            'utilisateur_id':
                utilisateurId, // Utiliser le bon champ selon le guide
            'nom': compte.nom,
            'valeur_marche': compte.solde,
            'cout_base': compte.pretAPlacer,
            'couleur': '#${compte.couleur.toRadixString(16).padLeft(8, '0')}',
            'ordre': compte.ordre ?? 0,
            'archive': compte.estArchive,
          };
          break;

        default:
          throw Exception('Type de compte non supporté: ${compte.type}');
      }

      final result =
          await pb.collection(nomCollection).create(body: donneesCompte);
    } catch (e) {
      rethrow;
    }
  }

  // Méthode pour mettre à jour un compte
  static Future<void> updateCompte(
      String compteId, Map<String, dynamic> donnees) async {
    try {
      final pb = await _getPocketBaseInstance();

      // Déterminer la collection en cherchant dans toutes les collections
      final collections = [
        'comptes_cheques',
        'comptes_credits',
        'comptes_investissement',
        'comptes_dettes',
        'pret_personnel'
      ];

      for (final nomCollection in collections) {
        try {
          print(
              '🔍 Tentative de mise à jour dans $nomCollection pour le compte $compteId');
          await pb.collection(nomCollection).update(compteId, body: donnees);
          print('✅ Compte mis à jour avec succès dans $nomCollection');

          // Forcer une mise à jour du cache temps réel avec délai
          await Future.delayed(const Duration(milliseconds: 100));
          await _updateComptesData();

          return;
        } catch (e) {
          print('❌ Erreur dans $nomCollection: $e');
          // Continuer vers la collection suivante si le compte n'est pas trouvé
          continue;
        }
      }

      throw Exception('Compte non trouvé dans aucune collection');
    } catch (e) {
      print('❌ Erreur updateCompte: $e');
      rethrow;
    }
  }

  // Créer des catégories de test dans PocketBase
  static Future<void> creerCategoriesTest() async {
    try {
      final pb = await _getPocketBaseInstance();

      // Vérifier que l'utilisateur est connecté
      final utilisateurId = pb.authStore.model?.id;
      if (utilisateurId == null) {
        return;
      }

      final categoriesTest = [
        {
          'nom': 'Alimentation',
          'utilisateur_id':
              utilisateurId, // Utiliser le bon champ selon le guide
          'ordre': 1,
        },
        {
          'nom': 'Transport',
          'utilisateur_id': utilisateurId,
          'ordre': 2,
        },
        {
          'nom': 'Logement',
          'utilisateur_id': utilisateurId,
          'ordre': 3,
        },
        {
          'nom': 'Loisirs',
          'utilisateur_id': utilisateurId,
          'ordre': 4,
        },
      ];

      for (final categorie in categoriesTest) {
        try {
          await pb.collection('categories').create(body: categorie);
        } catch (e) {}
      }
    } catch (e) {}
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

  // ============================================================================
  // MÉTHODES POUR GÉRER LES CATÉGORIES
  // ============================================================================

  // Méthode pour ajouter ou mettre à jour une catégorie
  static Future<String> ajouterCategorie(Categorie categorie) async {
    try {
      final pb = await _getPocketBaseInstance();
      final userId = pb.authStore.model?.id;
      if (userId == null) throw Exception('Utilisateur non connecté');

      final categorieData = {
        'utilisateur_id': userId,
        'nom': categorie.nom,
        'ordre': categorie.ordre,
      };

      // Si l'ID existe, on met à jour, sinon on crée
      if (categorie.id.isNotEmpty) {
        await pb
            .collection('categories')
            .update(categorie.id, body: categorieData);
        return categorie.id;
      } else {
        final record =
            await pb.collection('categories').create(body: categorieData);
        return record.id;
      }
    } catch (e) {
      throw Exception(
          'Erreur lors de l\'ajout/mise à jour de la catégorie: $e');
    }
  }

  // Méthode pour nettoyer toutes les ressources temps réel
  static Future<void> dispose() async {
    _comptesTimer?.cancel();
    _categoriesTimer?.cancel();
    _enveloppesTimer?.cancel();

    for (final controller in _comptesControllers.values) {
      controller.close();
    }
    for (final controller in _categoriesControllers.values) {
      controller.close();
    }
    for (final controller in _enveloppesControllers.values) {
      controller.close();
    }

    _comptesControllers.clear();
    _categoriesControllers.clear();
    _enveloppesControllers.clear();
    _comptesCache.clear();
    _categoriesCache.clear();
    _enveloppesCache.clear();
  }

  // Charger les données initiales
  static Future<void> _loadInitialDataSimple() async {
    try {
      // Charger les données en parallèle pour plus de rapidité
      await Future.wait([
        _updateComptesData(),
        _updateCategoriesData(),
        _updateEnveloppesData(),
      ]);
    } catch (e) {
      print('❌ Erreur chargement initial: $e');
    }
  }

  // Mettre à jour les données des comptes
  static Future<void> _updateComptesData() async {
    try {
      final pb = await _getPocketBaseInstance();
      final userId = pb.authStore.model?.id;

      if (userId == null) return;

      final List<Compte> tousLesComptes = [];

      // Récupérer tous les types de comptes en parallèle
      final collections = [
        'comptes_cheques',
        'comptes_credits',
        'comptes_investissement',
        'comptes_dettes',
        'pret_personnel'
      ];

      final futures = collections.map((collection) async {
        try {
          final records = await pb.collection(collection).getFullList(
                filter: 'utilisateur_id = "$userId"',
              );

          return records
              .map((record) => Compte.fromPocketBase(
                  record.data, record.id, _getCompteType(collection)))
              .toList();
        } catch (e) {
          print('❌ Erreur lecture $collection: $e');
          return <Compte>[];
        }
      });

      final results = await Future.wait(futures);
      for (final comptes in results) {
        tousLesComptes.addAll(comptes);
      }

      // Mettre à jour le cache et émettre
      _comptesCache['comptes'] = tousLesComptes;
      _comptesControllers['comptes']?.add(tousLesComptes);
    } catch (e) {
      print('❌ Erreur mise à jour comptes: $e');
    }
  }

  // Mettre à jour les données des catégories
  static Future<void> _updateCategoriesData() async {
    try {
      final pb = await _getPocketBaseInstance();
      final userId = pb.authStore.model?.id;

      if (userId == null) return;

      final records = await pb.collection('categories').getFullList(
            filter: 'utilisateur_id = "$userId"',
          );

      final categories = records
          .map((record) => Categorie(
                id: record.id,
                utilisateurId: record.data['utilisateur_id'] ?? '',
                nom: record.data['nom'] ?? '',
                ordre: record.data['ordre'] ?? 0,
              ))
          .toList();

      // Mettre à jour le cache et émettre
      _categoriesCache['categories'] = categories;
      _categoriesControllers['categories']?.add(categories);
    } catch (e) {
      print('❌ Erreur mise à jour catégories: $e');
    }
  }

  // Mettre à jour les données des enveloppes
  static Future<void> _updateEnveloppesData() async {
    try {
      final pb = await _getPocketBaseInstance();
      final userId = pb.authStore.model?.id;

      if (userId == null) return;

      final records = await pb.collection('enveloppes').getFullList(
            filter: 'utilisateur_id = "$userId"',
          );

      final enveloppes = records
          .map((record) => Enveloppe(
                id: record.id,
                utilisateurId: record.data['utilisateur_id'] ?? '',
                categorieId: record.data['categorie_id'] ?? '',
                nom: record.data['nom'] ?? '',
                soldeEnveloppe:
                    (record.data['solde_enveloppe'] ?? 0).toDouble(),
              ))
          .toList();

      // Mettre à jour le cache et émettre
      _enveloppesCache['enveloppes'] = enveloppes;
      _enveloppesControllers['enveloppes']?.add(enveloppes);
    } catch (e) {
      print('❌ Erreur mise à jour enveloppes: $e');
    }
  }
}
