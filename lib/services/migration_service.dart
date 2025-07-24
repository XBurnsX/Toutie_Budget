/*// 📁 Chemin : lib/services/migration_service.dart
// 🔗 Dépendances : firebase_service.dart, pocketbase_service.dart, pocketbase_config.dart
// 📋 Description : Service de migration complet Firebase → PocketBase avec logique métier

import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pocketbase/pocketbase.dart';
import '../models/compte.dart';
import '../models/categorie.dart';
import '../models/transaction_model.dart';
import '../models/dette.dart';
import '../models/action_investissement.dart';
import 'firebase_service.dart';
import 'pocketbase_service.dart';
import '../pocketbase_config.dart';
import 'auth_service.dart';
import 'cache_service.dart';
import 'dette_service.dart';
import 'dart:io';

class MigrationService {
  static final MigrationService _instance = MigrationService._internal();
  factory MigrationService() => _instance;
  MigrationService._internal();

  final FirebaseService _serviceFirebase = FirebaseService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Mapping utilisateur Firebase → PocketBase
  Map<String, String> _mappingUtilisateur = {};

  // Test de connexion aux services
  Future<Map<String, bool>> testerConnexions() async {
    final resultats = <String, bool>{};

    try {
      // Test Firebase
      final auth = FirebaseAuth.instance;
      resultats['firebase'] = auth.currentUser != null;
    } catch (e) {
      resultats['firebase'] = false;
    }

    try {
      // Test PocketBase
      await PocketBaseService.instance;
      resultats['pocketbase'] = true;
    } catch (e) {
      resultats['pocketbase'] = false;
    }

    return resultats;
  }

  // Méthodes de compatibilité pour l'ancienne page de test
  Future<Map<String, bool>> testConnections() => testerConnexions();

  Future<Map<String, Map<String, int>>> compareData() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      return await comparerDonneesUtilisateur(currentUser.uid);
    }
    return {};
  }

  Future<void> migrateTestData() async {
    try {
      await migrerUtilisateurConnecte();
    } catch (e) {
    }
  }

  Future<String> generateMigrationReport() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      return await genererRapportMigrationUtilisateur(currentUser.uid);
    }
    return 'Aucun utilisateur connecté';
  }

  Future<void> testMigration(String userId) async {
    try {
      await migrerUtilisateurConnecte();
    } catch (e) {
    }
  }

  Future<void> migrateAllData() => migrerToutesLesDonnees();

  Future<void> analyzeFirebaseExport() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await comparerDonneesUtilisateur(currentUser.uid);
      }
    } catch (e) {
    }
  }

  Future<void> migrateAllDataWithRealIds() => migrerToutesLesDonnees();

  Future<void> migrateCurrentUserData() => migrerUtilisateurConnecte();

  Future<void> verifyAllPocketBaseCollections() =>
      verifierToutesLesCollections();

  // Initialiser le mapping utilisateur Firebase → PocketBase
  Future<void> _initialiserMappingUtilisateur() async {
    try {

      // Récupérer tous les utilisateurs Firebase uniques
      final collectionsFirebase = [
        'comptes',
        'categories',
        'transactions',
        'dettes'
      ];
      final utilisateursFirebase = <String>{};

      for (final collection in collectionsFirebase) {
        final snapshot = await _firestore.collection(collection).get();
        for (final doc in snapshot.docs) {
          final userId = doc.data()['userId'] as String?;
          if (userId != null && userId.isNotEmpty) {
            utilisateursFirebase.add(userId);
          }
        }
      }


      // Créer automatiquement les utilisateurs PocketBase
      for (final firebaseUserId in utilisateursFirebase) {
        try {
          final pb = await PocketBaseService.instance;
          final donneesUtilisateur = {
            'email': '$firebaseUserId@migration.local',
            'password': 'migration123456',
            'passwordConfirm': 'migration123456',
            'name': 'Utilisateur Migré $firebaseUserId',
          };

          final utilisateurPocketBase = await PocketBaseService.signUp(
            donneesUtilisateur['email']!,
            donneesUtilisateur['password']!,
            donneesUtilisateur['name'] ?? 'Utilisateur',
          );

          _mappingUtilisateur[firebaseUserId] = utilisateurPocketBase.id;
              '   ✅ Utilisateur créé: $firebaseUserId → ${utilisateurPocketBase.id}');
        } catch (e) {
        }
      }

          '✅ Mapping utilisateur terminé: ${_mappingUtilisateur.length} utilisateurs');
    } catch (e) {
    }
  }

  // Obtenir l'ID PocketBase depuis l'ID Firebase
  String _obtenirIdPocketBase(String idFirebase) {
    return _mappingUtilisateur[idFirebase] ?? idFirebase;
  }

  // Adapter le type de compte Firebase vers les collections PocketBase
  String _adapterTypeCompte(String typeFirebase) {
    switch (typeFirebase.toLowerCase()) {
      case 'cheque':
      case 'compte chèque':
        return 'comptes_cheques';
      case 'epargne':
      case 'compte épargne':
        return 'comptes_cheques'; // Les épargnes vont aussi dans comptes_cheques
      case 'credit':
      case 'carte de crédit':
        return 'comptes_credits';
      case 'dette':
        return 'comptes_dettes';
      case 'investissement':
        return 'comptes_investissement';
      default:
        return 'comptes_cheques';
    }
  }

  // Migration pour l'utilisateur connecté uniquement
  Future<void> migrerUtilisateurConnecte() async {
    try {

      // 1. Vérifier qu'un utilisateur Firebase est connecté
      final utilisateurFirebase = FirebaseAuth.instance.currentUser;
      if (utilisateurFirebase == null) {
        throw Exception('❌ Aucun utilisateur Firebase connecté');
      }

      final idFirebase = utilisateurFirebase.uid;
          '👤 Utilisateur connecté: ${utilisateurFirebase.email} ($idFirebase)');

      // 2. Créer ou récupérer le compte PocketBase pour cet utilisateur
      final utilisateurPocketBase =
          await _creerComptePocketBase(utilisateurFirebase);
      final idPocketBase = utilisateurPocketBase.id;

      // 3. IMPORTANT: Configurer le mapping pour cet utilisateur
      _mappingUtilisateur[idFirebase] = idPocketBase;

      // 4. CRUCIAL: Vérifier que l'utilisateur est bien connecté dans PocketBase
      final pb = await PocketBaseService.instance;
      final currentAuth = pb.authStore.model;
      if (currentAuth == null || currentAuth.id != idPocketBase) {
        throw Exception(
            '❌ Utilisateur PocketBase non authentifié correctement');
      }

      // 5. NETTOYAGE: Supprimer les catégories "Dettes" existantes
      await _supprimerCategoriesDettes(currentAuth.id);

      // 6. Migrer les données de cet utilisateur uniquement
      await _migrerDonneesUtilisateur(idFirebase, idPocketBase);

    } catch (e) {
      rethrow;
    }
  }

  // Supprimer les catégories "Dettes" existantes pour éviter les doublons
  Future<void> _supprimerCategoriesDettes(String utilisateurId) async {
    try {

      final pb = await PocketBaseService.instance;
      final categories = await pb
          .collection('categories')
          .getFullList(filter: 'utilisateur_id = "$utilisateurId"');

      int supprimees = 0;
      for (final categorie in categories) {
        final nom = categorie.data['nom'] ?? '';
        if (_estCategorieDettes(nom)) {
          await pb.collection('categories').delete(categorie.id);
          supprimees++;
        }
      }

      if (supprimees > 0) {
      } else {
      }
    } catch (e) {
    }
  }

  // Créer un compte PocketBase pour l'utilisateur Firebase connecté
  Future<RecordModel> _creerComptePocketBase(User utilisateurFirebase) async {
    try {

      // Vérifier que PocketBase est bien initialisé
      final pb = await PocketBaseService.instance;

      final email = utilisateurFirebase.email ??
          '${utilisateurFirebase.uid}@migration.local';
      final password = 'migration123456';


      // Essayer de se connecter d'abord (au cas où l'utilisateur existe déjà)
      try {
        final authData =
            await pb.collection('users').authWithPassword(email, password);
            '✅ Connexion réussie avec utilisateur existant: ${authData.record?.id}');
        return authData.record!;
      } catch (loginError) {

        // Si la connexion échoue, créer un nouvel utilisateur
        final donneesUtilisateur = {
          'email': email,
          'password': password,
          'passwordConfirm': password,
          'name': utilisateurFirebase.displayName ??
              'Utilisateur ${utilisateurFirebase.uid}',
        };

        try {
          final utilisateurPocketBase =
              await pb.collection('users').create(body: donneesUtilisateur);

          // Se connecter avec le nouvel utilisateur
          final authData =
              await pb.collection('users').authWithPassword(email, password);
              '✅ Connexion automatique réussie avec token: ${authData.token.isNotEmpty}');

          return utilisateurPocketBase;
        } catch (createError) {
          rethrow;
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  // Migrer toutes les données d'un utilisateur spécifique
  Future<void> _migrerDonneesUtilisateur(
      String idFirebase, String idPocketBase) async {
    try {

      // 1. Migrer les catégories de cet utilisateur
      await _migrerCategoriesUtilisateur(idFirebase, idPocketBase);

      // 2. Migrer les comptes de cet utilisateur
      await _migrerComptesUtilisateur(idFirebase, idPocketBase);

      // 3. Migrer les enveloppes de cet utilisateur
      await _migrerEnveloppesUtilisateur(idFirebase, idPocketBase);

      // 4. Migrer les transactions de cet utilisateur
      await _migrerTransactionsUtilisateur(idFirebase, idPocketBase);

      // 5. Migrer les dettes de cet utilisateur
      await _migrerDettesUtilisateur(idFirebase, idPocketBase);

      // 6. Migrer les investissements de cet utilisateur
      await _migrerInvestissementsUtilisateur(idFirebase, idPocketBase);

      // 7. Migrer les tiers de cet utilisateur
      await _migrerTiersUtilisateur(idFirebase, idPocketBase);

    } catch (e) {
      rethrow;
    }
  }

  // Migrer les catégories d'un utilisateur spécifique
  Future<void> _migrerCategoriesUtilisateur(
      String idFirebase, String idPocketBase) async {
    try {

      final snapshot = await _firestore
          .collection('categories')
          .where('userId', isEqualTo: idFirebase)
          .get();


      for (final doc in snapshot.docs) {
        try {
          final donnees = doc.data();

          final categorieData = {
            'utilisateur_id': idPocketBase, // Forcer l'ID exact
            'nom': donnees['nom'] ?? 'Catégorie sans nom',
            'ordre': donnees['ordre'] ?? 0,
          };

              '   📝 Création catégorie: ${categorieData['nom']} avec utilisateur_id: $idPocketBase');
          final pb = await PocketBaseService.instance;

          // Vérifier que l'utilisateur est bien connecté
          final currentAuth = pb.authStore.model;
          if (currentAuth == null || currentAuth.id != idPocketBase) {
            throw Exception(
                'Utilisateur PocketBase non connecté correctement: auth=${currentAuth?.id}, expected=$idPocketBase');
          }

          // S'assurer que l'utilisateur_id est bien l'ID et non le nom
          categorieData['utilisateur_id'] =
              currentAuth.id; // Forcer l'ID authentifié

          final result =
              await pb.collection('categories').create(body: categorieData);
              '   ✅ Catégorie créée avec ID: ${result.id} pour utilisateur: ${result.data['utilisateur_id']}');
        } catch (e) {
        }
      }
    } catch (e) {
    }
  }

  // Migrer les comptes d'un utilisateur spécifique
  Future<void> _migrerComptesUtilisateur(
      String idFirebase, String idPocketBase) async {
    try {

      final snapshot = await _firestore
          .collection('comptes')
          .where('userId', isEqualTo: idFirebase)
          .get();


      Map<String, int> compteurParType = {};

      for (final doc in snapshot.docs) {
        try {
          final donnees = doc.data();
          final compte = Compte.fromMap(donnees, doc.id);
          final typeCollection = _adapterTypeCompte(compte.type);

          // Vérifier l'authentification PocketBase
          final pb = await PocketBaseService.instance;
          final currentAuth = pb.authStore.model;
          if (currentAuth == null || currentAuth.id != idPocketBase) {
            throw Exception('Utilisateur PocketBase non connecté');
          }

          // Données communes avec ID utilisateur forcé
          final donneesBase = {
            'utilisateur_id': currentAuth.id, // Forcer l'ID authentifié
            'nom': compte.nom,
            'couleur': '#${compte.couleur.toRadixString(16).padLeft(8, '0')}',
            'ordre': compte.ordre ?? 0,
            'archive': compte.estArchive,
          };

              '   📝 Création compte: ${compte.nom} avec utilisateur_id: ${currentAuth.id}');

          // Données spécifiques par type
          if (typeCollection == 'comptes_cheques') {
            donneesBase.addAll({
              'solde': compte.solde,
              'pret_a_placer': compte.pretAPlacer,
            });
            final result = await pb
                .collection('comptes_cheques')
                .create(body: donneesBase);
                '   🔍 Compte chèques créé, utilisateur_id: ${result.data['utilisateur_id']}');
          } else if (typeCollection == 'comptes_credits') {
            donneesBase.addAll({
              'solde_utilise': compte.solde.abs(),
              'limite_credit': compte.solde.abs() + 1000,
              'taux_interet': 19.99,
            });
            final result = await pb
                .collection('comptes_credits')
                .create(body: donneesBase);
                '   🔍 Compte crédit créé, utilisateur_id: ${result.data['utilisateur_id']}');
          } else if (typeCollection == 'comptes_dettes') {
            donneesBase.addAll({
              'nom_tiers': compte.nom,
              'solde_dette': compte.solde.abs(),
              'montant_initial': compte.solde.abs(),
              'taux_interet': 0.0,
              'paiement_minimum': 0.0,
            });
            final result =
                await pb.collection('comptes_dettes').create(body: donneesBase);
                '   🔍 Compte dette créé, utilisateur_id: ${result.data['utilisateur_id']}');
          } else if (typeCollection == 'comptes_investissement') {
            donneesBase.addAll({
              'valeur_marche': compte.solde,
              'cout_base': compte.pretAPlacer,
              'symbole': 'UNKNOWN',
              'nombre_actions': 0,
              'prix_moyen_achat': 0.0,
              'prix_actuel': 0.0,
              'variation_pourcentage': 0.0,
              'date_derniere_maj': DateTime.now().toIso8601String(),
            });
            final result = await pb
                .collection('comptes_investissement')
                .create(body: donneesBase);
                '   🔍 Compte investissement créé, utilisateur_id: ${result.data['utilisateur_id']}');
          }

          compteurParType[typeCollection] =
              (compteurParType[typeCollection] ?? 0) + 1;
        } catch (e) {
        }
      }

    } catch (e) {
    }
  }

  // Migrer les enveloppes d'un utilisateur spécifique
  Future<void> _migrerEnveloppesUtilisateur(
      String idFirebase, String idPocketBase) async {
    try {

      final snapshot = await _firestore
          .collection('categories')
          .where('userId', isEqualTo: idFirebase)
          .get();

      int totalEnveloppes = 0;

      // D'abord, créer un mapping des catégories Firebase → PocketBase
      final pb = await PocketBaseService.instance;
      final categoriesPocketBase =
          await pb.collection('categories').getFullList();
      final mappingCategories = <String, String>{};

      for (final catPB in categoriesPocketBase) {
        // Associer par nom de catégorie
        for (final docFirebase in snapshot.docs) {
          final donneesFirebase = docFirebase.data();
          if (donneesFirebase['nom'] == catPB.data['nom']) {
            mappingCategories[docFirebase.id] = catPB.id;
                '   🔗 Mapping catégorie: ${docFirebase.id} → ${catPB.id} (${catPB.data['nom']})');
          }
        }
      }

      for (final doc in snapshot.docs) {
        try {
          final donnees = doc.data();
          final nomCategorie = donnees['nom'] ?? '';

          // IMPORTANT: EXCLURE les enveloppes de la catégorie "Dettes"
          if (_estCategorieDettes(nomCategorie)) {
                '   ⚠️ Enveloppes de catégorie EXCLUES (auto-créées): $nomCategorie');
            continue; // Ignorer toutes les enveloppes de cette catégorie
          }

          final enveloppes = donnees['enveloppes'] as List<dynamic>? ?? [];
          final categorieIdPocketBase = mappingCategories[doc.id];

          if (categorieIdPocketBase == null) {
            continue;
          }

          for (final enveloppe in enveloppes) {
            try {
              final enveloppeData = {
                'utilisateur_id': idPocketBase,
                'categorie_id':
                    categorieIdPocketBase, // Utiliser l'ID PocketBase
                'nom': enveloppe['nom'] ?? 'Enveloppe sans nom',
                'objectif_date': enveloppe['objectifDate'] ??
                    DateTime.now().toIso8601String(),
                'frequence_objectif':
                    _adapterFrequenceObjectif(enveloppe['frequenceObjectif']),
                'compte_provenance_id': enveloppe['provenanceCompteId'] ?? '',
                'ordre': enveloppe['ordre'] ?? 0,
                'solde_enveloppe': (enveloppe['solde'] ?? 0.0).toDouble(),
                'depense': (enveloppe['depense'] ?? 0.0).toDouble(),
                'est_archive': enveloppe['archivee'] ?? false,
                'objectif_montant': (enveloppe['objectif'] ?? 0.0).toDouble(),
                'moisObjectif': enveloppe['objectifDate'] ??
                    DateTime.now().toIso8601String(),
              };

              await pb.collection('enveloppes').create(body: enveloppeData);
              totalEnveloppes++;
            } catch (e) {
            }
          }
        } catch (e) {
        }
      }

    } catch (e) {
    }
  }

  // Migrer les transactions d'un utilisateur spécifique
  Future<void> _migrerTransactionsUtilisateur(
      String idFirebase, String idPocketBase) async {
    try {

      final snapshot = await _firestore
          .collection('transactions')
          .where('userId', isEqualTo: idFirebase)
          .get();


      // Créer un mapping des enveloppes Firebase → PocketBase
      final pb = await PocketBaseService.instance;
      final enveloppesPocketBase =
          await pb.collection('enveloppes').getFullList();
      final mappingEnveloppes = <String, String>{};

      for (final envPB in enveloppesPocketBase) {
        mappingEnveloppes[envPB.data['nom']] = envPB.id;
      }

      int totalTransactions = 0;
      int totalAllocations = 0;

      for (final doc in snapshot.docs) {
        try {
          final donnees = doc.data();
          final transaction = Transaction.fromJson(donnees);

          // 1. Créer la transaction normale
          final transactionData = {
            'utilisateur_id': idPocketBase,
            'type': _adapterTypeTransaction(
                transaction.type.name), // Adapter le type
            'type_mouvement': transaction.typeMouvement.name,
            'montant': transaction.type == TypeTransaction.depense
                ? -transaction.montant
                : transaction.montant,
            'date': transaction.date.toIso8601String(),
            'note': transaction.note ?? '',
            'compte_id': transaction.compteId,
            'collection_compte': _adapterTypeCompte(
                _obtenirTypeCompteDepuisId(transaction.compteId)),
            'tiers_id': transaction.tiers ?? '',
            'marqueur': transaction.marqueur ?? '',
            'est_fractionnee': transaction.estFractionnee,
            'transaction_parente_id': transaction.transactionParenteId ?? '',
            'sous_items': transaction.sousItems ?? [],
            'compte_passif_id': transaction.compteDePassifAssocie ?? '',
          };

          // 2. Créer les allocations mensuelles
          if (transaction.estFractionnee &&
              transaction.sousItems != null &&
              transaction.sousItems!.isNotEmpty) {
            // Transaction fractionnée : créer une allocation pour chaque sous-item
                '   🔄 Transaction fractionnée détectée avec ${transaction.sousItems!.length} sous-items');

            for (final sousItem in transaction.sousItems!) {
              final enveloppeIdFirebase = sousItem['enveloppeId'] as String?;
              final montant = (sousItem['montant'] as num?)?.toDouble() ?? 0.0;

              if (enveloppeIdFirebase != null &&
                  enveloppeIdFirebase.isNotEmpty) {
                // Rechercher l'enveloppe par nom depuis Firebase
                String? nomEnveloppeFirebase;
                final categoriesFirebase = await _firestore
                    .collection('categories')
                    .where('userId', isEqualTo: idFirebase)
                    .get();

                for (final catDoc in categoriesFirebase.docs) {
                  final catData = catDoc.data();
                  final enveloppes =
                      catData['enveloppes'] as List<dynamic>? ?? [];

                  for (final enveloppe in enveloppes) {
                    if (enveloppe['id'] == enveloppeIdFirebase) {
                      nomEnveloppeFirebase = enveloppe['nom'];
                      break;
                    }
                  }
                  if (nomEnveloppeFirebase != null) break;
                }

                // Utiliser le mapping par nom pour trouver l'ID PocketBase
                String? enveloppeIdPocketBase;
                if (nomEnveloppeFirebase != null &&
                    mappingEnveloppes.containsKey(nomEnveloppeFirebase)) {
                  enveloppeIdPocketBase =
                      mappingEnveloppes[nomEnveloppeFirebase];
                      '   ✅ Enveloppe trouvée pour sous-item: "$nomEnveloppeFirebase" → $enveloppeIdPocketBase');
                }

                if (enveloppeIdPocketBase != null) {
                  final allocationData = {
                    'utilisateur_id': idPocketBase,
                    'enveloppe_id': enveloppeIdPocketBase,
                    'mois': _forcerPremierDuMoisMinuit(transaction.date)
                        .toIso8601String(),
                    'solde': transaction.type == TypeTransaction.depense
                        ? -montant
                        : montant,
                    'alloue': transaction.type == TypeTransaction.revenu
                        ? montant
                        : 0.0,
                    'depense': transaction.type == TypeTransaction.depense
                        ? montant
                        : 0.0,
                    'compte_source_id': transaction.compteId,
                    'collection_compte_source': _adapterTypeCompte(
                        _obtenirTypeCompteDepuisId(transaction.compteId)),
                  };

                  final allocationRecord = await pb
                      .collection('allocations_mensuelles')
                      .create(body: allocationData);
                  totalAllocations++;
                      '   ✅ Allocation créée pour sous-item: ${sousItem['description'] ?? 'Sans description'} (${montant.toStringAsFixed(2)}\$)');

                  // Pour les transactions fractionnées, on ne met pas d'allocation_mensuelle_id
                  // car on utilise le JSON des sous_items pour afficher les enveloppes
                } else {
                      '   ⚠️ Enveloppe non trouvée pour sous-item: $enveloppeIdFirebase');
                }
              }
            }
          } else if (transaction.enveloppeId != null &&
              transaction.enveloppeId!.isNotEmpty) {
            String? enveloppeIdPocketBase;

            // Rechercher l'enveloppe par nom depuis Firebase
            String? nomEnveloppeFirebase;
            final categoriesFirebase = await _firestore
                .collection('categories')
                .where('userId', isEqualTo: idFirebase)
                .get();

            for (final catDoc in categoriesFirebase.docs) {
              final catData = catDoc.data();
              final enveloppes = catData['enveloppes'] as List<dynamic>? ?? [];

              for (final enveloppe in enveloppes) {
                if (enveloppe['id'] == transaction.enveloppeId) {
                  nomEnveloppeFirebase = enveloppe['nom'];
                  break;
                }
              }
              if (nomEnveloppeFirebase != null) break;
            }

            // Utiliser le mapping par nom pour trouver l'ID PocketBase
            if (nomEnveloppeFirebase != null &&
                mappingEnveloppes.containsKey(nomEnveloppeFirebase)) {
              enveloppeIdPocketBase = mappingEnveloppes[nomEnveloppeFirebase];
                  '   ✅ Enveloppe trouvée: "$nomEnveloppeFirebase" → $enveloppeIdPocketBase');
            }

            if (enveloppeIdPocketBase != null) {
              final allocationData = {
                'utilisateur_id': idPocketBase,
                'enveloppe_id': enveloppeIdPocketBase,
                'mois': _forcerPremierDuMoisMinuit(transaction.date)
                    .toIso8601String(),
                'solde': transaction.type == TypeTransaction.depense
                    ? -transaction.montant
                    : transaction.montant,
                'alloue': transaction.type == TypeTransaction.revenu
                    ? transaction.montant
                    : 0.0,
                'depense': transaction.type == TypeTransaction.depense
                    ? transaction.montant
                    : 0.0,
                'compte_source_id': transaction.compteId,
                'collection_compte_source': _adapterTypeCompte(
                    _obtenirTypeCompteDepuisId(transaction.compteId)),
              };

              final allocationRecord = await pb
                  .collection('allocations_mensuelles')
                  .create(body: allocationData);
              totalAllocations++;
                  '   ✅ Allocation mensuelle créée pour enveloppe: $enveloppeIdPocketBase');

              // Ajouter l'ID de l'allocation dans la transaction
              transactionData['allocation_mensuelle_id'] = allocationRecord.id;
            } else {
            }
          } else {
                '   ⚠️ Transaction sans enveloppeId, création allocation quand même...');

            // Créer allocation mensuelle même sans enveloppe pour les revenus
            final allocationData = {
              'utilisateur_id': idPocketBase,
              'enveloppe_id': '', // Vide
              'mois': _forcerPremierDuMoisMinuit(transaction.date)
                  .toIso8601String(),
              'solde': transaction.type == TypeTransaction.depense
                  ? -transaction.montant
                  : transaction.montant,
              'alloue': transaction.type == TypeTransaction.revenu
                  ? transaction.montant
                  : 0.0,
              'depense': transaction.type == TypeTransaction.depense
                  ? transaction.montant
                  : 0.0,
              'compte_source_id': transaction.compteId,
              'collection_compte_source': _adapterTypeCompte(
                  _obtenirTypeCompteDepuisId(transaction.compteId)),
            };

            try {
              await pb
                  .collection('allocations_mensuelles')
                  .create(body: allocationData);
              totalAllocations++;
            } catch (e) {
            }
          }

          // Créer la transaction pour TOUTES les transactions
          await pb.collection('transactions').create(body: transactionData);
          totalTransactions++;

          if (totalTransactions % 10 == 0) {
          }
        } catch (e) {
        }
      }

    } catch (e) {
    }
  }

  // Migrer les dettes d'un utilisateur spécifique
  Future<void> _migrerDettesUtilisateur(
      String idFirebase, String idPocketBase) async {
    try {

      final snapshot = await _firestore
          .collection('dettes')
          .where('userId', isEqualTo: idFirebase)
          .get();


      int dettesVersPretPersonnel = 0;
      int dettesVersComptesDettes = 0;

      for (final doc in snapshot.docs) {
        try {
          final donnees = doc.data();
          donnees['id'] = doc.id;
          final dette = Dette.fromMap(donnees);

          final donneesBase = {
            'utilisateur_id': idPocketBase,
            'nom_tiers': dette.nomTiers,
            'montant_initial': dette.montantInitial,
            'solde': dette.solde,
            'type': dette.type,
            'archive': dette.archive,
            'date_creation':
                dette.dateCreation.toIso8601String(), // Convertir en string
            'note': '',
            'historique': dette.historique
                .map((m) => {
                      'id': m.id,
                      'date':
                          m.date.toIso8601String(), // Convertir les Timestamps
                      'montant': m.montant,
                      'type': m.type,
                      'note': m.note,
                    })
                .toList(),
          };

          // Logique de séparation selon estManuelle
          if (dette.estManuelle == false) {
            // estManuelle = false → Collection pret_personnel
            final pb = await PocketBaseService.instance;
            await pb.collection('pret_personnel').create(body: donneesBase);
            dettesVersPretPersonnel++;
          } else {
            // estManuelle = true → Collection comptes_dettes
            // IMPORTANT: Ajouter le champ "nom" pour comptes_dettes
            donneesBase.addAll({
              'nom': dette.nomTiers, // Ajouter le champ nom requis
              'solde_dette': dette.solde,
              'taux_interet': dette.tauxInteret ?? 0.0,
              'paiement_minimum': dette.montantMensuel ?? 0.0,
              'est_manuelle': true,
            });

            final pb = await PocketBaseService.instance;
            await pb.collection('comptes_dettes').create(body: donneesBase);
            dettesVersComptesDettes++;
          }
        } catch (e) {
        }
      }

          '   📊 pret_personnel: $dettesVersPretPersonnel, comptes_dettes: $dettesVersComptesDettes');
    } catch (e) {
    }
  }

  // Migrer les investissements d'un utilisateur spécifique
  Future<void> _migrerInvestissementsUtilisateur(
      String idFirebase, String idPocketBase) async {
    try {

      final snapshot = await _firestore
          .collection('investissements')
          .where('userId', isEqualTo: idFirebase)
          .get();


      int totalMigres = 0;

      for (final doc in snapshot.docs) {
        try {
          final donnees = doc.data();
          final investissement = ActionInvestissement.fromMap(donnees);

          final investissementData = {
            'utilisateur_id': idPocketBase,
            'nom': investissement.symbole,
            'valeur_marche': investissement.valeurActuelle,
            'cout_base': investissement.prixMoyen * investissement.nombre,
            'couleur': '#FF4CAF50',
            'ordre': totalMigres,
            'archive': false,
            'symbole': investissement.symbole,
            'nombre_actions': investissement.nombre,
            'prix_moyen_achat': investissement.prixMoyen,
            'prix_actuel': investissement.prixActuel,
            'variation_pourcentage': investissement.variation,
            'date_derniere_maj':
                investissement.dateDerniereMiseAJour.toIso8601String(),
            'transactions_details':
                investissement.transactions.map((t) => t.toMap()).toList(),
          };

          final pb = await PocketBaseService.instance;
          await pb
              .collection('comptes_investissement')
              .create(body: investissementData);
          totalMigres++;
        } catch (e) {
        }
      }

    } catch (e) {
    }
  }

  // Migrer les tiers d'un utilisateur spécifique
  Future<void> _migrerTiersUtilisateur(
      String idFirebase, String idPocketBase) async {
    try {

      final snapshot = await _firestore
          .collection('tiers')
          .where('userId', isEqualTo: idFirebase)
          .get();


      for (final doc in snapshot.docs) {
        try {
          final donnees = doc.data();

          final tiersData = {
            'utilisateur_id': idPocketBase,
            'nom': donnees['nom'] ?? 'Tiers sans nom',
          };

          final pb = await PocketBaseService.instance;
          await pb.collection('tiers').create(body: tiersData);
        } catch (e) {
        }
      }
    } catch (e) {
    }
  }

  // Vérifier si une catégorie est la catégorie "Dettes" (à exclure)
  bool _estCategorieDettes(String nomCategorie) {
    if (nomCategorie.isEmpty) return false;

    final nomLower = nomCategorie.toLowerCase().trim();
    final estDette = nomLower == 'dettes' ||
        nomLower == 'dette' ||
        nomLower == 'debts' ||
        nomLower == 'debt' ||
        nomLower.contains('dette');

        '   🔍 Test exclusion: "$nomCategorie" → nomLower="$nomLower" → exclure=$estDette');
    return estDette;
  }

  // Adapter les types de transaction Firebase vers PocketBase
  String _adapterTypeTransaction(String typeFirebase) {
    switch (typeFirebase.toLowerCase()) {
      case 'depense':
        return 'Depense'; // Respecter le format SELECT PocketBase
      case 'revenu':
        return 'Revenu';
      case 'pret':
        return 'Pret';
      case 'emprunt':
        return 'Emprunt';
      default:
        return 'Depense';
    }
  }

  // Adapter la fréquence d'objectif
  String _adapterFrequenceObjectif(String? frequence) {
    switch (frequence?.toLowerCase()) {
      case 'mensuel':
        return 'Mensuel';
      case 'bihebdomadaire':
        return 'Bihebdomadaire';
      default:
        return 'Aucun';
    }
  }

  // Forcer la date au 1er du mois à minuit
  DateTime _forcerPremierDuMoisMinuit(DateTime date) {
    return DateTime(date.year, date.month, 1, 0, 0, 0);
  }

  // Obtenir le type de compte depuis l'ID (simulation)
  String _obtenirTypeCompteDepuisId(String compteId) {
    // TODO: Implémenter la logique pour déterminer le type depuis l'ID
    return 'cheque'; // Par défaut
  }

  // Vérifier toutes les collections PocketBase
  Future<void> verifierToutesLesCollections() async {
    try {

      final collections = [
        'users',
        'comptes_cheques',
        'comptes_credits',
        'comptes_dettes',
        'comptes_investissement',
        'categories',
        'enveloppes',
        'transactions',
        'allocations_mensuelles',
        'pret_personnel',
        'tiers'
      ];

      for (final collection in collections) {
        try {
          final pb = await PocketBaseService.instance;
          final records = await pb.collection(collection).getFullList();
        } catch (e) {
        }
      }

    } catch (e) {
    }
  }

  // Comparer les données entre Firebase et PocketBase pour un utilisateur
  Future<Map<String, Map<String, int>>> comparerDonneesUtilisateur(
      String idFirebase) async {
    final comparaison = <String, Map<String, int>>{};

    try {
      // Compter les comptes
      final comptesFirebase = await _firestore
          .collection('comptes')
          .where('userId', isEqualTo: idFirebase)
          .get();
      final comptesPocketBase = await PocketBaseService.getComptes();
      comparaison['comptes'] = {
        'firebase': comptesFirebase.docs.length,
        'pocketbase': comptesPocketBase.length,
      };

      // Compter les catégories
      final categoriesFirebase = await _firestore
          .collection('categories')
          .where('userId', isEqualTo: idFirebase)
          .get();
      final categoriesPocketBase = await PocketBaseService.getCategories();
      comparaison['categories'] = {
        'firebase': categoriesFirebase.docs.length,
        'pocketbase': categoriesPocketBase.length,
      };

      // Compter les transactions
      final transactionsFirebase = await _firestore
          .collection('transactions')
          .where('userId', isEqualTo: idFirebase)
          .get();
      final transactionsPocketBase = await PocketBaseService.getTransactions();
      comparaison['transactions'] = {
        'firebase': transactionsFirebase.docs.length,
        'pocketbase': transactionsPocketBase.length,
      };

      // Compter les dettes
      final dettesFirebase = await _firestore
          .collection('dettes')
          .where('userId', isEqualTo: idFirebase)
          .get();
      final pb = await PocketBaseService.instance;
      final dettesPocketBase =
          await pb.collection('comptes_dettes').getFullList();
      final pretsPocketBase =
          await pb.collection('pret_personnel').getFullList();
      comparaison['dettes'] = {
        'firebase': dettesFirebase.docs.length,
        'pocketbase': dettesPocketBase.length + pretsPocketBase.length,
      };

      comparaison.forEach((type, counts) {
            '   $type: Firebase=${counts['firebase']}, PocketBase=${counts['pocketbase']}');
      });
    } catch (e) {
    }

    return comparaison;
  }

  // Générer un rapport de migration pour un utilisateur
  Future<String> genererRapportMigrationUtilisateur(String idFirebase) async {
    final rapport = StringBuffer();
    rapport.writeln('📋 RAPPORT DE MIGRATION UTILISATEUR');
    rapport.writeln('Utilisateur Firebase: $idFirebase');
    rapport.writeln('Date: ${DateTime.now()}');
    rapport.writeln();

    try {
      final comparaison = await comparerDonneesUtilisateur(idFirebase);

      rapport.writeln('📊 STATISTIQUES DE MIGRATION:');
      comparaison.forEach((type, counts) {
        final firebase = counts['firebase'] ?? 0;
        final pocketbase = counts['pocketbase'] ?? 0;
        final taux = firebase > 0
            ? (pocketbase / firebase * 100).toStringAsFixed(1)
            : '0.0';
        rapport.writeln('   $type: $pocketbase/$firebase migrés ($taux%)');
      });

      rapport.writeln();
      rapport.writeln('✅ COLLECTIONS MIGRÉES:');
      rapport.writeln(
          '   - Comptes → Séparés par type (cheques, credits, dettes, investissement)');
      rapport.writeln(
          '   - Dettes → Séparées selon estManuelle (pret_personnel vs comptes_dettes)');
      rapport.writeln(
          '   - Transactions → Double écriture (transactions + allocations_mensuelles)');
      rapport.writeln('   - Catégories & Enveloppes → Structure adaptée');
      rapport.writeln('   - Investissements → Structure enrichie');
      rapport.writeln('   - Tiers → Migration directe');

      rapport.writeln();
      rapport.writeln('🔧 LOGIQUE MÉTIER APPLIQUÉE:');
      rapport.writeln(
          '   - Toutes les transactions → Collection transactions (vraie date/heure)');
      rapport.writeln(
          '   - Toutes les transactions → Collection allocations_mensuelles (1er du mois à minuit)');
      rapport.writeln('   - estManuelle = false → Collection pret_personnel');
      rapport.writeln('   - estManuelle = true → Collection comptes_dettes');
      rapport.writeln(
          '   - Types de comptes → Collections séparées automatiquement');
    } catch (e) {
      rapport.writeln('❌ Erreur génération rapport: $e');
    }

    return rapport.toString();
  }

  // Migration complète de toutes les données (gardée pour compatibilité)
  Future<void> migrerToutesLesDonnees() async {
    try {
          '⚠️  ATTENTION: Cette méthode migre TOUS les utilisateurs à la fois');
          '⚠️  Il est recommandé d\'utiliser migrerUtilisateurConnecte() à la place');

      // 1. Initialiser le mapping utilisateur
      await _initialiserMappingUtilisateur();

      // 2. Migrer toutes les données utilisateur par utilisateur
      for (final entry in _mappingUtilisateur.entries) {
        final idFirebase = entry.key;
        final idPocketBase = entry.value;

        await _migrerDonneesUtilisateur(idFirebase, idPocketBase);
      }

    } catch (e) {
    }
  }
}
*/
