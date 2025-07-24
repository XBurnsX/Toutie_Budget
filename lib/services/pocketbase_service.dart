// 📁 Chemin : lib/services/pocketbase_service.dart
// 🔗 Dépendances : pocketbase.dart, auth_service.dart
// 📋 Description : Service PocketBase pour remplacer FirebaseService - Version COMPLÈTE

import 'package:pocketbase/pocketbase.dart';
import 'package:pocketbase/pocketbase.dart' show RecordModel;
import '../models/enveloppe.dart';
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

  // Lire les catégories depuis PocketBase
  static Stream<List<Categorie>> lireCategories() async* {
    try {
      final pb = await _getPocketBaseInstance();

      // Vérifier que l'utilisateur est connecté
      final utilisateurId = pb.authStore.model?.id;
      
      if (utilisateurId == null) {
        yield [];
        return;
      }

      final records = await pb.collection('categories').getFullList(
        filter: 'utilisateur_id = "$utilisateurId"',
      );

      final List<Categorie> categories = [];
      
      for (final record in records) {
        // Récupérer les enveloppes pour cette catégorie
        final enveloppesRecords = await pb.collection('enveloppes').getFullList(
          filter: 'categorie_id = "${record.id}" && utilisateur_id = "$utilisateurId"',
        );
        
        // Convertir les enveloppes
        final enveloppes = enveloppesRecords.map((envRecord) => Enveloppe(
          id: envRecord.id,
          utilisateurId: envRecord.data['utilisateur_id'] ?? '',
          categorieId: envRecord.data['categorie_id'] ?? '',
          nom: envRecord.data['nom'] ?? '',
          soldeEnveloppe: (envRecord.data['solde_enveloppe'] ?? 0).toDouble(),
        )).toList();
        
        // Créer la catégorie avec ses enveloppes
        final categorie = Categorie(
          id: record.id,
          utilisateurId: record.data['utilisateur_id'],
          nom: record.data['nom'] ?? '',
          ordre: record.data['ordre'] ?? 0,
        );
        
        categories.add(categorie);
      }

      yield categories;
    } catch (e) {
      yield [];
    }
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
        await pb.collection('categories').update(categorie.id, body: categorieData);
        return categorie.id;
      } else {
        final record = await pb.collection('categories').create(body: categorieData);
        return record.id;
      }
    } catch (e) {
      throw Exception('Erreur lors de l\'ajout/mise à jour de la catégorie: $e');
    }
  }

  // Méthode pour supprimer une catégorie
  static Future<void> supprimerCategorie(String categorieId) async {
    try {
      final pb = await _getPocketBaseInstance();
      await pb.collection('categories').delete(categorieId);
    } catch (e) {
      throw Exception('Erreur lors de la suppression de la catégorie: $e');
    }
  }

  // Lire uniquement les comptes chèques depuis PocketBase
  static Stream<List<Compte>> lireComptesChecques() async* {
    try {
      final pb = await _getPocketBaseInstance();
      
      // Vérifier que l'utilisateur est connecté
      final utilisateurId = pb.authStore.model?.id;
      final utilisateurNom = pb.authStore.model?.getStringValue('name') ?? pb.authStore.model?.getStringValue('username') ?? '';
      
      if (utilisateurId == null || utilisateurNom.isEmpty) {
        yield [];
        return;
      }
      
      final filtre = 'utilisateur_id = "$utilisateurId"';
      
      final records = await pb.collection('comptes_cheques').getFullList(
        filter: filtre,
      );
      
      
      final comptes = records
          .map((record) => Compte.fromPocketBase(record.data, record.id, 'Chèque'))
          .toList();

      yield comptes;
    } catch (e) {
      yield [];
    }
  }

  // Lire uniquement les comptes de crédit depuis PocketBase
  static Stream<List<Compte>> lireComptesCredits() async* {
    try {
      final pb = await _getPocketBaseInstance();
      
      // Vérifier que l'utilisateur est connecté
      final utilisateurId = pb.authStore.model?.id;
      final utilisateurNom = pb.authStore.model?.getStringValue('name') ?? pb.authStore.model?.getStringValue('username') ?? '';
      
      if (utilisateurId == null || utilisateurNom.isEmpty) {
        yield [];
        return;
      }

      final records = await pb.collection('comptes_credits').getFullList(
        filter: 'utilisateur_id = "$utilisateurId"',
      );

      final comptes = records
          .map((record) => Compte.fromPocketBase(record.data, record.id, 'Carte de crédit'))
          .toList();

      yield comptes;
    } catch (e) {
      yield [];
    }
  }

  // Lire uniquement les comptes d'investissement depuis PocketBase
  static Stream<List<Compte>> lireComptesInvestissement() async* {
    try {
      final pb = await _getPocketBaseInstance();
      
      // Vérifier que l'utilisateur est connecté
      final utilisateurId = pb.authStore.model?.id;
      final utilisateurNom = pb.authStore.model?.getStringValue('name') ?? pb.authStore.model?.getStringValue('username') ?? '';
      
      if (utilisateurId == null || utilisateurNom.isEmpty) {
        yield [];
        return;
      }

      final records = await pb.collection('comptes_investissement').getFullList(
        filter: 'utilisateur_id = "$utilisateurId"',
      );

      final comptes = records
          .map((record) => Compte.fromPocketBase(record.data, record.id, 'Investissement'))
          .toList();

      yield comptes;
    } catch (e) {
      yield [];
    }
  }

  // Lire les dettes (comptes_dettes + prêts personnels) depuis PocketBase
  static Stream<List<Compte>> lireComptesDettes() async* {
    try {
      final pb = await _getPocketBaseInstance();
      
      final utilisateurId = pb.authStore.model?.id;
      final utilisateurNom = pb.authStore.model?.getStringValue('name') ?? pb.authStore.model?.getStringValue('username') ?? '';
      
      if (utilisateurId == null || utilisateurNom.isEmpty) {
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
      } catch (e) {
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
      } catch (e) {
      }

      yield toutesLesDettes;
    } catch (e) {
      yield [];
    }
  }

  // Combiner tous les types de comptes en un seul stream
  static Stream<List<Compte>> lireTousLesComptes() async* {
    try {
      
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
      
      yield tousLesComptes;
      
    } catch (e) {
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

      // Récupérer tous les comptes de l'utilisateur
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
          couleur: int.tryParse(record.data['couleur']?.toString() ?? '0') ?? 0x2196F3,
          pretAPlacer: (record.data['pret_a_placer'] ?? 0.0).toDouble(),
          dateCreation: DateTime.tryParse(record.data['created'] ?? '') ?? DateTime.now(),
          estArchive: record.data['archive'] ?? false,
          ordre: record.data['ordre'] ?? 0,
          userId: record.data['utilisateur_id'] ?? userId,
        );
      }).toList();

      yield comptes;
    } catch (e) {
      yield [];
    }
  }

  // Méthode pour récupérer les enveloppes d'une catégorie spécifique
  static Future<List<Map<String, dynamic>>> lireEnveloppesParCategorie(String categorieId) async {
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
  static Future<Map<String, List<Map<String, dynamic>>>> lireEnveloppesGroupeesParCategorie() async {
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
        final nomEnveloppe = record.data['nom'] ?? 'Sans nom';
        
        
        if (!enveloppesParCategorie.containsKey(categorieId)) {
          enveloppesParCategorie[categorieId] = [];
        }
        enveloppesParCategorie[categorieId]!.add(enveloppeData);
      }
      
      enveloppesParCategorie.forEach((catId, enveloppes) {
      });
      
      return enveloppesParCategorie;
    } catch (e) {
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
  static Future<String> ajouterEnveloppe(Map<String, dynamic> enveloppeData) async {
    try {
      final pb = await _getPocketBaseInstance();
      final userId = pb.authStore.model?.id;
      if (userId == null) throw Exception('Utilisateur non connecté');
      
      // Ajouter l'ID utilisateur si pas déjà présent
      enveloppeData['utilisateur_id'] = userId;
      
      final record = await pb.collection('enveloppes').create(body: enveloppeData);
      return record.id;
    } catch (e) {
      throw Exception('Erreur lors de l\'ajout de l\'enveloppe: $e');
    }
  }

  // Méthode pour mettre à jour une enveloppe
  static Future<void> mettreAJourEnveloppe(String enveloppeId, Map<String, dynamic> donnees) async {
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
            'utilisateur_id': utilisateurId, // Utiliser le bon champ selon le guide
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
            'utilisateur_id': utilisateurId, // Utiliser le bon champ selon le guide
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

      
      final result = await pb.collection(nomCollection).create(body: donneesCompte);
      

    } catch (e) {
      rethrow;
    }
  }

  // Méthode pour mettre à jour un compte
  static Future<void> updateCompte(String compteId, Map<String, dynamic> donnees) async {
    try {
      final pb = await _getPocketBaseInstance();

      // Déterminer la collection en cherchant dans toutes les collections
      final collections = ['comptes_cheques', 'comptes_credits', 'comptes_investissement', 'comptes_dettes', 'pret_personnel'];
      
      for (final nomCollection in collections) {
        try {
          await pb.collection(nomCollection).update(compteId, body: donnees);
          return;
        } catch (e) {
          // Continuer vers la collection suivante si le compte n'est pas trouvé
          continue;
        }
      }
      
      throw Exception('Compte non trouvé dans aucune collection');
    } catch (e) {
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
        } catch (e) {
        }
      }

    } catch (e) {
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
