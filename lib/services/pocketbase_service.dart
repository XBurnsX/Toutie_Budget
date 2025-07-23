// 📁 Chemin : lib/services/pocketbase_service.dart
// 🔗 Dépendances : pocketbase.dart, auth_service.dart
// 📋 Description : Service PocketBase pour remplacer FirebaseService - Version COMPLÈTE

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

  // Obtenir l'instance PocketBase depuis AuthService
  static Future<PocketBase> _getPocketBaseInstance() async {
    // UTILISER L'INSTANCE D'AUTHSERVICE au lieu de créer la nôtre !
    final authServiceInstance = AuthService.pocketBaseInstance;
    if (authServiceInstance != null) {
      print('🔄 PocketBaseService - Utilisation instance AuthService');
      print('🔗 URL PocketBase utilisée: ${authServiceInstance.baseUrl}');
      print('🔐 AuthStore valide: ${authServiceInstance.authStore.isValid}');
      print('🔐 Utilisateur connecté: ${authServiceInstance.authStore.model?.id}');
      return authServiceInstance;
    }

    print('⚠️ Pas d\'instance AuthService, création fallback...');
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

        // Test simple pour vérifier la connexion
        _pocketBase = PocketBase(url);
        await _pocketBase!.collection('users').getList(page: 1, perPage: 1);
        
        print('✅ Connexion PocketBase réussie: $url');
        print('🔗 URL PocketBase utilisée: ${_pocketBase!.baseUrl}');
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
      print('🔄 PocketBaseService - Instance obtenue pour catégories');

      // Vérifier que l'utilisateur est connecté
      final utilisateurId = pb.authStore.model?.id;
      print('🔄 PocketBaseService - Utilisateur ID pour catégories: $utilisateurId');
      
      if (utilisateurId == null) {
        print('❌ Aucun utilisateur connecté dans PocketBase pour catégories');
        yield [];
        return;
      }

      print('🔄 PocketBaseService - Début lecture collection categories');
      final records = await pb.collection('categories').getFullList(
        filter: 'utilisateur_id = "$utilisateurId"',
      );
      print('✅ PocketBaseService - ${records.length} catégories trouvées');

      print('🔄 PocketBaseService - Conversion des catégories...');
      final List<Categorie> categories = [];
      
      for (final record in records) {
        // Récupérer les enveloppes pour cette catégorie
        print('🔄 Récupération enveloppes pour catégorie: ${record.data['nom']}');
        final enveloppesRecords = await pb.collection('enveloppes').getFullList(
          filter: 'categorie_id = "${record.id}" && utilisateur_id = "$utilisateurId"',
        );
        print('✅ ${enveloppesRecords.length} enveloppes trouvées pour ${record.data['nom']}');
        
        // Convertir les enveloppes
        final enveloppes = enveloppesRecords.map((envRecord) => Enveloppe(
          id: envRecord.id,
          nom: envRecord.data['nom'] ?? '',
          solde: (envRecord.data['solde_enveloppe'] ?? 0).toDouble(),
          objectif: (envRecord.data['objectif'] ?? 0).toDouble(),
          archivee: envRecord.data['archivee'] ?? false,
          provenanceCompteId: envRecord.data['provenance_compte_id'] ?? '',
          frequenceObjectif: envRecord.data['frequence_objectif'] ?? 'mensuel',
          ordre: envRecord.data['ordre'],
        )).toList();
        
        // Créer la catégorie avec ses enveloppes
        final categorie = Categorie(
          id: record.id,
          userId: record.data['utilisateur_id'],
          nom: record.data['nom'] ?? '',
          enveloppes: enveloppes,
          ordre: record.data['ordre'] ?? 0,
        );
        
        categories.add(categorie);
      }

      print('✅ PocketBaseService - Catégories converties: ${categories.length}');
      yield categories;
      print('✅ PocketBaseService - Catégories yielded avec succès');
    } catch (e) {
      print('❌ Erreur lecture catégories PocketBase: $e');
      yield [];
    }
  }

  // Lire uniquement les comptes chèques depuis PocketBase
  static Stream<List<Compte>> lireComptesChecques() async* {
    try {
      print('🔄 PocketBaseService - Lecture comptes chèques...');
      final pb = await _getPocketBaseInstance();
      
      // Vérifier que l'utilisateur est connecté
      final utilisateurId = pb.authStore.model?.id;
      final utilisateurNom = pb.authStore.model?.getStringValue('name') ?? pb.authStore.model?.getStringValue('username') ?? '';
      
      if (utilisateurId == null || utilisateurNom.isEmpty) {
        print('❌ Aucun utilisateur connecté dans PocketBase');
        yield [];
        return;
      }
      
      final filtre = 'utilisateur_id = "$utilisateurId"';
      print('🔍 Filtre utilisé: $filtre');
      
      final records = await pb.collection('comptes_cheques').getFullList(
        filter: filtre,
      );
      
      print('📊 Nombre de records trouvés avec filtre: ${records.length}');
      
      final comptes = records
          .map((record) => Compte.fromPocketBase(record.data, record.id, 'Chèque'))
          .toList();

      print('✅ ${comptes.length} compte(s) chèque(s) trouvé(s)');
      yield comptes;
    } catch (e) {
      print('❌ Erreur lecture comptes chèques: $e');
      yield [];
    }
  }

  // Lire uniquement les comptes de crédit depuis PocketBase
  static Stream<List<Compte>> lireComptesCredits() async* {
    try {
      print('🔄 PocketBaseService - Lecture comptes crédits...');
      final pb = await _getPocketBaseInstance();
      
      // Vérifier que l'utilisateur est connecté
      final utilisateurId = pb.authStore.model?.id;
      final utilisateurNom = pb.authStore.model?.getStringValue('name') ?? pb.authStore.model?.getStringValue('username') ?? '';
      
      if (utilisateurId == null || utilisateurNom.isEmpty) {
        print('❌ Aucun utilisateur connecté dans PocketBase');
        yield [];
        return;
      }

      final records = await pb.collection('comptes_credits').getFullList(
        filter: 'utilisateur_id = "$utilisateurId"',
      );

      final comptes = records
          .map((record) => Compte.fromPocketBase(record.data, record.id, 'Carte de crédit'))
          .toList();

      print('✅ ${comptes.length} compte(s) de crédit trouvé(s)');
      yield comptes;
    } catch (e) {
      print('❌ Erreur lecture comptes crédits: $e');
      yield [];
    }
  }

  // Lire uniquement les comptes d'investissement depuis PocketBase
  static Stream<List<Compte>> lireComptesInvestissement() async* {
    try {
      print('🔄 PocketBaseService - Lecture comptes investissement...');
      final pb = await _getPocketBaseInstance();
      
      // Vérifier que l'utilisateur est connecté
      final utilisateurId = pb.authStore.model?.id;
      final utilisateurNom = pb.authStore.model?.getStringValue('name') ?? pb.authStore.model?.getStringValue('username') ?? '';
      
      if (utilisateurId == null || utilisateurNom.isEmpty) {
        print('❌ Aucun utilisateur connecté dans PocketBase');
        yield [];
        return;
      }

      final records = await pb.collection('comptes_investissement').getFullList(
        filter: 'utilisateur_id = "$utilisateurId"',
      );

      final comptes = records
          .map((record) => Compte.fromPocketBase(record.data, record.id, 'Investissement'))
          .toList();

      print('✅ ${comptes.length} compte(s) d\'investissement trouvé(s)');
      yield comptes;
    } catch (e) {
      print('❌ Erreur lecture comptes investissement: $e');
      yield [];
    }
  }

  // Lire les dettes (comptes_dettes + prêts personnels) depuis PocketBase
  static Stream<List<Compte>> lireComptesDettes() async* {
    try {
      print('🔄 PocketBaseService - Lecture comptes dettes + prêts personnels...');
      final pb = await _getPocketBaseInstance();
      
      final utilisateurId = pb.authStore.model?.id;
      final utilisateurNom = pb.authStore.model?.getStringValue('name') ?? pb.authStore.model?.getStringValue('username') ?? '';
      
      if (utilisateurId == null || utilisateurNom.isEmpty) {
        print('❌ Aucun utilisateur connecté dans PocketBase');
        yield [];
        return;
      }
      
      List<Compte> toutesLesDettes = [];

      // 1. Récupérer les dettes de la collection comptes_dettes
      try {
        final recordsDettes = await pb.collection('comptes_dettes').getFullList(
          filter: 'utilisateur_id = "$utilisateurId"',
        );

        final comptesDettes = recordsDettes
            .map((record) => Compte.fromPocketBase(record.data, record.id, 'Dette'))
            .toList();

        toutesLesDettes.addAll(comptesDettes);
        print('✅ ${comptesDettes.length} dette(s) trouvée(s) dans comptes_dettes');
      } catch (e) {
        print('⚠️ Erreur lecture comptes_dettes: $e');
      }

      // 2. Récupérer les prêts personnels de la collection pret_personnel
      try {
        final recordsPrets = await pb.collection('pret_personnel').getFullList(
          filter: 'utilisateur_id = "$utilisateurId"',
        );

        final comptesPrets = recordsPrets
            .map((record) => Compte.fromPocketBase(record.data, record.id, 'Dette'))
            .toList();

        toutesLesDettes.addAll(comptesPrets);
        print('✅ ${comptesPrets.length} prêt(s) personnel(s) trouvé(s)');
      } catch (e) {
        print('⚠️ Erreur lecture pret_personnel: $e');
      }

      print('✅ Total: ${toutesLesDettes.length} dette(s) + prêt(s) trouvé(s)');
      yield toutesLesDettes;
    } catch (e) {
      print('❌ Erreur lecture dettes: $e');
      yield [];
    }
  }

  // Combiner tous les types de comptes en un seul stream
  static Stream<List<Compte>> lireTousLesComptes() async* {
    print('🔄 Appel de lireTousLesComptes');
    try {
      print('🔄 PocketBaseService - Lecture de tous les comptes (4 collections)...');
      
      // Récupérer tous les comptes de chaque type
      final List<Compte> tousLesComptes = [];
      
      // Comptes chèques
      await for (final comptesChecques in lireComptesChecques()) {
        tousLesComptes.addAll(comptesChecques);
        break; // Prendre seulement la première émission
      }
      
      // Comptes crédits
      await for (final comptesCredits in lireComptesCredits()) {
        tousLesComptes.addAll(comptesCredits);
        break; // Prendre seulement la première émission
      }
      
      // Comptes investissement
      await for (final comptesInvestissement in lireComptesInvestissement()) {
        tousLesComptes.addAll(comptesInvestissement);
        break; // Prendre seulement la première émission
      }
      
      // Comptes dettes
      await for (final comptesDettes in lireComptesDettes()) {
        tousLesComptes.addAll(comptesDettes);
        break; // Prendre seulement la première émission
      }
      
      print('✅ Total combiné: ${tousLesComptes.length} compte(s)');
      yield tousLesComptes;
      
    } catch (e) {
      print('❌ Erreur lecture tous les comptes: $e');
      yield [];
    }
  }

  // Méthodes pour compatibilité migration_service
  static Future<List<Compte>> getComptes() async {
    final comptes = <Compte>[];
    await for (final listeComptes in lireTousLesComptes()) {
      comptes.addAll(listeComptes);
      break; // Prendre seulement la première émission du stream
    }
    return comptes;
  }

  static Future<List<Categorie>> getCategories() async {
    final categories = <Categorie>[];
    await for (final listeCategories in lireCategories()) {
      categories.addAll(listeCategories);
      break; // Prendre seulement la première émission du stream
    }
    return categories;
  }

  static Future<List<dynamic>> getTransactions() async {
    // TODO: Implémenter quand on aura le modèle Transaction
    return [];
  }

  // Ajouter un compte dans PocketBase
  static Future<void> ajouterCompte(Compte compte) async {
    try {
      print('🔄 PocketBaseService - Ajout compte: ${compte.nom}');
      final pb = await _getPocketBaseInstance();

      // Vérifier que l'utilisateur est connecté
      final utilisateurId = pb.authStore.model?.id;
      final utilisateurNom = pb.authStore.model?.getStringValue('name') ?? '';
      if (utilisateurId == null) {
        throw Exception('❌ Aucun utilisateur connecté dans PocketBase');
      }

      print('🔐 Utilisateur connecté pour ajout: $utilisateurId');
      print('🔐 Nom utilisateur pour ajout: $utilisateurNom');
      
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
            'utilisateur_id': utilisateurId, // Utiliser l'ID au lieu du nom
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
            'utilisateur_id': utilisateurId, // Utiliser l'ID au lieu du nom
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

      print('🔄 Création dans collection: $nomCollection');
      
      final result = await pb.collection(nomCollection).create(body: donneesCompte);
      
      print('✅ Compte créé avec ID: ${result.id}');
      print('✅ Ajout compte terminé: ${compte.nom}');

    } catch (e) {
      print('❌ Erreur ajout compte PocketBase: $e');
      rethrow;
    }
  }

  // Méthode pour mettre à jour un compte
  static Future<void> updateCompte(String compteId, Map<String, dynamic> donnees) async {
    try {
      print('🔄 PocketBaseService - Mise à jour compte: $compteId');
      final pb = await _getPocketBaseInstance();

      // Déterminer la collection en cherchant dans toutes les collections
      final collections = ['comptes_cheques', 'comptes_credits', 'comptes_investissement', 'comptes_dettes', 'pret_personnel'];
      
      for (final nomCollection in collections) {
        try {
          await pb.collection(nomCollection).update(compteId, body: donnees);
          print('✅ Compte mis à jour dans $nomCollection');
          return;
        } catch (e) {
          // Continuer vers la collection suivante si le compte n'est pas trouvé
          continue;
        }
      }
      
      throw Exception('Compte non trouvé dans aucune collection');
    } catch (e) {
      print('❌ Erreur mise à jour compte PocketBase: $e');
      rethrow;
    }
  }

  // Créer des catégories de test dans PocketBase
  static Future<void> creerCategoriesTest() async {
    try {
      print('🔄 PocketBaseService - Création catégories de test...');
      final pb = await _getPocketBaseInstance();

      // Vérifier que l'utilisateur est connecté
      final utilisateurId = pb.authStore.model?.id;
      if (utilisateurId == null) {
        print('❌ Aucun utilisateur connecté - impossible de créer des catégories');
        return;
      }

      final categoriesTest = [
        {
          'nom': 'Alimentation',
          'utilisateur_id': utilisateurId, // Utiliser le bon champ selon le guide
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
          print('✅ Catégorie créée: ${categorie['nom']}');
        } catch (e) {
          print('! Catégorie déjà existante: ${categorie['nom']}');
        }
      }

      print('✅ Création catégories de test terminée');
    } catch (e) {
      print('❌ Erreur création catégories de test: $e');
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
}