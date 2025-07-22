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
        return _pocketBase!;
      } catch (e) {
        print('❌ Échec connexion PocketBase: $url - $e');
        continue;
      }
    }

    throw Exception('❌ Aucune connexion PocketBase disponible');
  }

  // Lire TOUS les comptes depuis les différentes collections
  static Stream<List<Compte>> lireComptes() async* {
    try {
      print('🔄 PocketBaseService - Lecture comptes (toutes collections)...');
      final pb = await _getPocketBaseInstance();
      
      // Vérifier que l'utilisateur est connecté
      final utilisateurId = pb.authStore.model?.id;
      if (utilisateurId == null) {
        print('❌ Aucun utilisateur connecté dans PocketBase');
        yield []; // Retourner liste vide
        return; // TERMINER le stream
      }
      
      print('🔐 Utilisateur connecté: $utilisateurId');

      List<Compte> tousLesComptes = [];

      // Collections de comptes selon le guide et types réels de l'app
      final collectionsComptes = {
        'comptes_cheques': 'Chèque',
        'comptes_credits': 'Carte de crédit', 
        'comptes_dettes': 'Dette',
        'comptes_investissement': 'Investissement',
      };

      for (final entry in collectionsComptes.entries) {
        final nomCollection = entry.key;
        final typeCompte = entry.value;
        
        try {
          print('🔍 Lecture collection: $nomCollection');
          
          // Lire la collection avec filtre utilisateur
          final records = await pb.collection(nomCollection).getFullList(
            filter: 'utilisateur_id = "$utilisateurId"',
          );
          
          print('✅ $nomCollection: ${records.length} compte(s) trouvé(s)');

          // Convertir les records en objets Compte
          for (final record in records) {
            try {
              final compte = Compte.fromPocketBase(record.data, record.id, typeCompte);
              tousLesComptes.add(compte);
            } catch (e) {
              print('❌ Erreur conversion compte ${record.id}: $e');
            }
          }
        } catch (e) {
          print('⚠️ Collection $nomCollection non trouvée ou erreur: $e');
          // Continue avec les autres collections
        }
      }

      print('✅ Total: ${tousLesComptes.length} compte(s) trouvé(s)');
      yield tousLesComptes;
      
    } catch (e) {
      print('❌ Erreur lecture comptes PocketBase: $e');
      yield [];
    }
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
      final categories = records
          .map((record) => Categorie(
                id: record.id,
                userId: record.data['utilisateur_id'],
                nom: record.data['nom'] ?? '',
                enveloppes: [], // Pour l'instant, on met une liste vide
                ordre: record.data['ordre'] ?? 0,
              ))
          .toList();

      print('✅ PocketBaseService - Catégories converties: ${categories.length}');
      yield categories;
      print('✅ PocketBaseService - Catégories yielded avec succès');
    } catch (e) {
      print('❌ Erreur lecture catégories PocketBase: $e');
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
      if (utilisateurId == null) {
        throw Exception('❌ Aucun utilisateur connecté dans PocketBase');
      }

      print('🔐 Utilisateur connecté pour ajout: $utilisateurId');

      // Déterminer la collection selon le type de compte
      String nomCollection;
      Map<String, dynamic> donneesCompte;

      switch (compte.type) {
        case 'Chèque':
          nomCollection = 'comptes_cheques';
          donneesCompte = {
            'utilisateur_id': utilisateurId,
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
            'utilisateur_id': utilisateurId,
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
            'utilisateur_id': utilisateurId,
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
            'utilisateur_id': utilisateurId,
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
}