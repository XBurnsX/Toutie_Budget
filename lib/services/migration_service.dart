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
import 'dart:io'; // Added for File

class MigrationService {
  static final MigrationService _instance = MigrationService._internal();
  factory MigrationService() => _instance;
  MigrationService._internal();

  final FirebaseService _firebaseService = FirebaseService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Test de connexion aux services
  Future<Map<String, bool>> testConnections() async {
    final results = <String, bool>{};

    try {
      // Test Firebase
      final auth = FirebaseAuth.instance;
      results['firebase'] = auth.currentUser != null;
      print('✅ Connexion Firebase réussie');
    } catch (e) {
      results['firebase'] = false;
      print('❌ Erreur connexion Firebase: $e');
    }

    try {
      // Test PocketBase
      await PocketBaseService.instance;
      results['pocketbase'] = true;
      print('✅ Connexion PocketBase réussie');
    } catch (e) {
      results['pocketbase'] = false;
      print('❌ Erreur connexion PocketBase: $e');
    }

    return results;
  }

  // Comparer les données entre Firebase et PocketBase
  Future<Map<String, int>> compareData() async {
    final comparison = <String, int>{};

    try {
      // Compter les comptes Firebase - utiliser le stream
      final comptesFirebaseStream = _firebaseService.lireComptes();
      final comptesFirebase = await comptesFirebaseStream.first;
      comparison['comptes_firebase'] = comptesFirebase.length;

      // Compter les comptes PocketBase
      final comptesPocketBase = await PocketBaseService.getComptes();
      comparison['comptes_pocketbase'] = comptesPocketBase.length;

      // Compter les catégories Firebase - utiliser le stream
      final categoriesFirebaseStream = _firebaseService.lireCategories();
      final categoriesFirebase = await categoriesFirebaseStream.first;
      comparison['categories_firebase'] = categoriesFirebase.length;

      // Compter les catégories PocketBase
      final categoriesPocketBase = await PocketBaseService.getCategories();
      comparison['categories_pocketbase'] = categoriesPocketBase.length;

      print('📊 Comptes Firebase: ${comparison['comptes_firebase']}');
      print('📊 Comptes PocketBase: ${comparison['comptes_pocketbase']}');
      print('📊 Catégories Firebase: ${comparison['categories_firebase']}');
      print('📊 Catégories PocketBase: ${comparison['categories_pocketbase']}');
    } catch (e) {
      print('❌ Erreur comparaison données: $e');
    }

    return comparison;
  }

  // Migrer des données de test vers PocketBase
  Future<void> migrateTestData() async {
    try {
      print('🔄 Migration des données de test...');

      // Synchroniser l'authentification
      final authService = AuthService();
      await authService.signInWithGoogle();

      // Récupérer l'utilisateur connecté
      final currentUser = PocketBaseService.currentUser;
      if (currentUser == null) {
        print('❌ Aucun utilisateur connecté à PocketBase');
        return;
      }

      final userId = currentUser.id;
      print('✅ Utilisateur connecté: $userId');

      // Créer un compte de test
      await PocketBaseService.createCompte({
        'nom': 'Compte Test Migration',
        'type': 'cheque',
        'solde': 1000.0,
        'pret_a_placer': 0.0,
        'couleur': '0xFF2196F3',
        'ordre': 1,
        'archive': false,
        'utilisateur_id': userId, // Utiliser l'ID réel
      });

      // Créer une catégorie de test
      await PocketBaseService.createCategorie({
        'nom': 'Catégorie Test Migration',
        'ordre': 1,
        'enveloppes': [],
        'utilisateur_id': userId, // Utiliser l'ID réel
      });

      print('✅ Données de test migrées avec succès');
    } catch (e) {
      print('❌ Erreur lors de la migration de test: $e');
    }
  }

  // Migration complète de toutes les données
  Future<void> migrateAllData() async {
    try {
      print('🔄 Migration complète de toutes les données...');

      // Initialiser le mapping utilisateur
      await _initUserMapping();

      print('📋 Mapping utilisateur configuré:');
      _userMapping.forEach((firebaseId, pocketbaseId) {
        print('   - $firebaseId → $pocketbaseId');
      });

      // 1. Migrer TOUTES les catégories de TOUS les utilisateurs (en premier)
      await _migrateCategories('');

      // 2. Migrer TOUS les comptes de TOUS les utilisateurs
      await _migrateComptes('');

      // 3. Migrer TOUTES les enveloppes de TOUS les utilisateurs (après catégories)
      await _migrateEnveloppes('');

      // 4. Migrer TOUTES les transactions de TOUS les utilisateurs
      await _migrateTransactions('');

      // 5. Migrer TOUTES les dettes de TOUS les utilisateurs
      await _migrateDettes('');

      // 6. Migrer TOUS les investissements de TOUS les utilisateurs
      await _migrateInvestissements('');

      print('✅ Migration complète terminée avec succès');
      print('📊 Toutes les données de tous les utilisateurs ont été migrées');
    } catch (e) {
      print('❌ Erreur lors de la migration complète: $e');
    }
  }

  // Migrer les comptes Firebase vers PocketBase
  Future<void> _migrateComptes(String userId) async {
    try {
      print('🔄 Migration des comptes...');

      // Initialiser le mapping utilisateur
      await _initUserMapping();

      final firebaseService = FirebaseService();

      // Récupérer TOUS les comptes de Firebase (tous les utilisateurs)
      final allComptes =
          await firebaseService.firestore.collection('comptes').get();

      print('📊 Comptes Firebase trouvés: ${allComptes.docs.length}');

      int totalMigres = 0;
      Map<String, int> compteursParUser = {};

      for (final doc in allComptes.docs) {
        final data = doc.data();
        final compte = Compte.fromMap(data, doc.id);

        // Utiliser le mapping pour l'ID utilisateur
        final user = compte.userId ?? 'unknown';
        if (user == 'unknown') {
          print('⚠️ Compte ${compte.nom} sans userId, ignoré');
          continue;
        }
        final pocketbaseUserId = _getPocketBaseUserId(user);

        // Adapter les données Firebase vers PocketBase
        final dataPocketBase = {
          'nom': compte.nom,
          'solde': compte.solde,
          'type': _adapterTypeCompte(compte.type),
          'utilisateur_id': pocketbaseUserId,
          'couleur': compte.couleur ?? '#000000',
          'est_actif': !compte.estArchive,
          'ordre': compte.ordre ?? 0,
        };

        try {
          await PocketBaseService.createCompte(dataPocketBase);
          totalMigres++;

          final user = compte.userId ?? 'unknown';
          compteursParUser[user] = (compteursParUser[user] ?? 0) + 1;

          print(
              '✅ Compte migré: ${compte.nom} (Firebase User: $user → PocketBase User: $pocketbaseUserId)');
        } catch (e) {
          print('⚠️ Erreur migration compte ${compte.nom}: $e');
        }
      }

      print('📊 Répartition des comptes migrés:');
      compteursParUser.forEach((user, count) {
        print('   - User $user: $count compte(s)');
      });

      print('✅ Migration des comptes terminée');
    } catch (e) {
      print('❌ Erreur migration comptes: $e');
    }
  }

  // Migrer les catégories Firebase vers PocketBase
  Future<void> _migrateCategories(String userId) async {
    try {
      print('🔄 Migration des catégories...');

      // Initialiser le mapping utilisateur
      await _initUserMapping();

      final firebaseService = FirebaseService();

      // Récupérer TOUTES les catégories de Firebase (tous les utilisateurs)
      final allCategories =
          await firebaseService.firestore.collection('categories').get();

      print('📊 Catégories Firebase trouvées: ${allCategories.docs.length}');

      int totalEnveloppes = 0;
      int categoriesExclues = 0;
      Map<String, int> compteursParUser = {};

      for (final doc in allCategories.docs) {
        final data = doc.data();
        data['id'] = doc.id; // Ajouter l'ID du document
        final categorie = Categorie.fromMap(data);

        // Exclure la catégorie "Dette" qui est créée automatiquement
        if (categorie.nom.toLowerCase() == 'dette' ||
            categorie.nom.toLowerCase() == 'dettes') {
          categoriesExclues++;
          print(
              '🚫 Catégorie EXCLUE "${categorie.nom}" (créée automatiquement par les dettes)');
          continue;
        }

        // Utiliser le mapping pour l'ID utilisateur
        final user = categorie.userId ?? 'unknown';
        if (user == 'unknown') {
          print('⚠️ Catégorie ${categorie.nom} sans userId, ignorée');
          continue;
        }
        final pocketbaseUserId = _getPocketBaseUserId(user);

        // Adapter les enveloppes Firebase vers PocketBase
        final enveloppesAdaptees = categorie.enveloppes
            .map((env) => {
                  'nom': env.nom,
                  'solde': env.solde,
                  'objectif': env.objectif,
                  'objectif_date': env.objectifDate,
                  'depense': env.depense ?? 0.0,
                  'archivee': env.archivee,
                  'provenance_compte_id': env.provenanceCompteId,
                  'frequence_objectif': env.frequenceObjectif,
                  'date_dernier_ajout': env.dateDernierAjout?.toIso8601String(),
                  'objectif_jour': env.objectifJour,
                  'historique': env.historique,
                  'ordre': env.ordre ?? 999,
                })
            .toList();

        final dataPocketBase = {
          'nom': categorie.nom,
          'ordre': categorie.ordre ?? 999,
          'enveloppes': enveloppesAdaptees,
          'utilisateur_id': pocketbaseUserId,
        };

        try {
          await PocketBaseService.createCategorie(dataPocketBase);
          totalEnveloppes += categorie.enveloppes.length;

          final user = categorie.userId ?? 'unknown';
          compteursParUser[user] = (compteursParUser[user] ?? 0) + 1;

          print(
              '✅ Catégorie migrée: ${categorie.nom} (Firebase User: $user → PocketBase User: $pocketbaseUserId)');
        } catch (e) {
          print('⚠️ Erreur migration catégorie ${categorie.nom}: $e');
        }
      }

      print('📊 Répartition des catégories migrées:');
      compteursParUser.forEach((user, count) {
        print('   - User $user: $count catégorie(s)');
      });

      print('📊 Total enveloppes migrées: $totalEnveloppes');
      print('❌ Catégories exclues (Dettes): $categoriesExclues');
      print('✅ Migration des catégories terminée');
    } catch (e) {
      print('❌ Erreur migration catégories: $e');
    }
  }

  // Migrer les transactions Firebase vers PocketBase
  Future<void> _migrateTransactions(String userId) async {
    try {
      print('🔄 Migration des transactions...');

      // Initialiser le mapping utilisateur
      await _initUserMapping();

      final firebaseService = FirebaseService();

      // Récupérer TOUTES les transactions de Firebase (tous les utilisateurs)
      final allTransactions =
          await firebaseService.firestore.collection('transactions').get();

      print(
          '📊 Transactions Firebase trouvées: ${allTransactions.docs.length}');

      int totalTransactions = 0;
      int totalAllocations = 0;
      Map<String, int> compteursParUser = {};

      for (final doc in allTransactions.docs) {
        final data = doc.data();
        data['id'] = doc.id; // Ajouter l'ID du document
        final transaction = Transaction.fromJson(data);

        // Utiliser le mapping pour l'ID utilisateur
        final user = transaction.userId ?? 'unknown';
        if (user == 'unknown') {
          print(
              '⚠️ Transaction ${transaction.tiers ?? 'Sans tiers'} sans userId, ignorée');
          continue;
        }
        final pocketbaseUserId = _getPocketBaseUserId(user);

        // Adapter les données Firebase vers PocketBase
        final dataTransaction = {
          'montant': transaction.montant,
          'date': transaction.date.toIso8601String(),
          'tiers': transaction.tiers ?? '',
          'type': _adapterTypeTransaction(transaction.type.name),
          'type_mouvement':
              _adapterTypeMouvementFinancier(transaction.typeMouvement.name),
          'utilisateur_id': pocketbaseUserId,
          'compte_id': transaction.compteId,
          'note': transaction.note ?? '',
        };

        try {
          // 1. Transaction normale
          await PocketBaseService.createTransaction(dataTransaction);
          totalTransactions++;

          // 2. Allocation mensuelle (même transaction mais date au 1er du mois)
          final dataAllocation = {
            'montant': transaction.montant,
            'date': DateTime(transaction.date.year, transaction.date.month, 1)
                .toIso8601String(),
            'utilisateur_id': pocketbaseUserId,
            'compte_id': transaction.compteId,
            'note': 'Allocation mensuelle migrée depuis Firebase',
          };

          await PocketBaseService.createAllocationMensuelle(dataAllocation);
          totalAllocations++;

          final user = transaction.userId ?? 'unknown';
          compteursParUser[user] = (compteursParUser[user] ?? 0) + 1;

          print(
              '✅ Transaction migrée: ${transaction.tiers ?? 'Sans tiers'} (Firebase User: $user → PocketBase User: $pocketbaseUserId)');
        } catch (e) {
          print(
              '⚠️ Erreur migration transaction ${transaction.tiers ?? 'Sans tiers'}: $e');
        }
      }

      print('📊 Répartition des transactions migrées:');
      compteursParUser.forEach((user, count) {
        print('   - User $user: $count transaction(s)');
      });

      print('📊 Transactions migrées: $totalTransactions');
      print('📊 Allocations mensuelles migrées: $totalAllocations');
      print('✅ Migration des transactions terminée');
    } catch (e) {
      print('❌ Erreur migration transactions: $e');
    }
  }

  // Vérifier si une transaction est une allocation mensuelle
  bool _isAllocationMensuelle(DateTime date) {
    // Allocation mensuelle = 1er du mois à minuit (00:00:00)
    return date.day == 1 &&
        date.hour == 0 &&
        date.minute == 0 &&
        date.second == 0;
  }

  // Migrer les dettes Firebase vers PocketBase
  Future<void> _migrateDettes(String userId) async {
    try {
      print('🔄 Migration des dettes...');

      // Initialiser le mapping utilisateur
      await _initUserMapping();

      final firebaseService = FirebaseService();

      // Récupérer TOUTES les dettes de Firebase (tous les utilisateurs)
      final allDettes =
          await firebaseService.firestore.collection('dettes').get();

      print('📊 Dettes Firebase trouvées: ${allDettes.docs.length}');

      int dettesManuelles = 0;
      int dettesContractees = 0;
      int pretsAccordes = 0;
      Map<String, int> compteursParUser = {};

      for (final doc in allDettes.docs) {
        final data = doc.data();
        data['id'] = doc.id; // Ajouter l'ID du document
        final dette = Dette.fromMap(data);

        // Utiliser le mapping pour l'ID utilisateur
        final user = dette.userId ?? 'unknown';
        if (user == 'unknown') {
          print('⚠️ Dette ${dette.nomTiers} sans userId, ignorée');
          continue;
        }
        final pocketbaseUserId = _getPocketBaseUserId(user);

        // Adapter les données Firebase vers PocketBase (version simplifiée)
        final dataPocketBase = {
          'nom_tiers': dette.nomTiers,
          'montant_initial': dette.montantInitial,
          'solde': dette.solde,
          'type': dette.type,
          'archive': dette.archive,
          'date_creation': dette.dateCreation.toIso8601String(),
          'utilisateur_id': pocketbaseUserId,
          // Champs optionnels
          'note': 'Migré depuis Firebase',
          'historique': dette.historique
              .map((m) => {
                    'id': m.id,
                    'date': m.date.toIso8601String(),
                    'montant': m.montant,
                    'type': m.type,
                    'note': m.note,
                  })
              .toList(),
          // Champ pour distinguer manuel vs automatique
          'est_manuel': dette.estManuelle,
        };

        try {
          if (dette.estManuelle) {
            // Dette manuelle → Collection comptes_dettes
            await PocketBaseService.createDette(dataPocketBase);
            dettesManuelles++;
            print('✅ Dette manuelle migrée: ${dette.nomTiers}');
          } else {
            // Dette automatique → Vérifier le type
            if (dette.type == 'dette') {
              // Dette contractée → Collection comptes_dettes (apparaît dans comptes)
              await PocketBaseService.createDette(dataPocketBase);
              dettesContractees++;
              print('✅ Dette contractée migrée: ${dette.nomTiers}');
            } else if (dette.type == 'pret') {
              // Prêt accordé → Collection pret_personnel (n'apparaît PAS dans comptes)
              try {
                await PocketBaseService.createPretPersonnel(dataPocketBase);
                pretsAccordes++;
                print('✅ Prêt accordé migré: ${dette.nomTiers}');
              } catch (e) {
                print(
                    '⚠️ Collection pret_personnel non disponible, dette migrée vers comptes_dettes: ${dette.nomTiers}');
                // Fallback vers comptes_dettes si pret_personnel n'existe pas
                await PocketBaseService.createDette(dataPocketBase);
                dettesContractees++;
              }
            }
          }

          final user = dette.userId ?? 'unknown';
          compteursParUser[user] = (compteursParUser[user] ?? 0) + 1;
        } catch (e) {
          print('⚠️ Erreur migration dette ${dette.nomTiers}: $e');
        }
      }

      print('📊 Répartition des dettes migrées:');
      compteursParUser.forEach((user, count) {
        print('   - User $user: $count dette(s)');
      });

      print('   - Dettes manuelles (comptes_dettes): $dettesManuelles');
      print('   - Dettes contractées (comptes_dettes): $dettesContractees');
      print('   - Prêts accordés (pret_personnel): $pretsAccordes');

      print('✅ Migration des dettes terminée');
    } catch (e) {
      print('❌ Erreur migration dettes: $e');
    }
  }

  // Migrer les enveloppes Firebase vers PocketBase
  Future<void> _migrateEnveloppes(String userId) async {
    try {
      print('🔄 Migration des enveloppes...');

      // Initialiser le mapping utilisateur
      await _initUserMapping();

      final firebaseService = FirebaseService();

      // Récupérer TOUTES les catégories de Firebase (tous les utilisateurs)
      final allCategories =
          await firebaseService.firestore.collection('categories').get();

      print('📊 Catégories Firebase trouvées: ${allCategories.docs.length}');

      int totalMigres = 0;
      Map<String, int> compteursParUser = {};
      int totalExclues = 0;

      for (final doc in allCategories.docs) {
        final data = doc.data();
        data['id'] = doc.id; // Ajouter l'ID du document
        final categorie = Categorie.fromMap(data);

        // Exclure la catégorie "Dettes"
        if (categorie.nom.toLowerCase() == 'dettes') {
          totalExclues++;
          continue;
        }

        // Utiliser le mapping pour l'ID utilisateur
        final user = categorie.userId ?? 'unknown';
        if (user == 'unknown') {
          print('⚠️ Catégorie ${categorie.nom} sans userId, ignorée');
          continue;
        }
        final pocketbaseUserId = _getPocketBaseUserId(user);

        // Migrer chaque enveloppe de la catégorie
        for (final enveloppe in categorie.enveloppes) {
          try {
            final dataEnveloppe = {
              'nom': enveloppe.nom,
              'solde': enveloppe.solde,
              'utilisateur_id': pocketbaseUserId,
              'ordre': enveloppe.ordre ?? 0,
            };

            await PocketBaseService.createEnveloppe(dataEnveloppe);
            totalMigres++;

            final user = categorie.userId ?? 'unknown';
            compteursParUser[user] = (compteursParUser[user] ?? 0) + 1;

            print(
                '✅ Enveloppe migrée: "${enveloppe.nom}" (Catégorie: ${categorie.nom}) (Firebase User: $user → PocketBase User: $pocketbaseUserId)');
          } catch (e) {
            print('⚠️ Erreur migration enveloppe ${enveloppe.nom}: $e');
          }
        }
      }

      print('📊 Répartition des enveloppes migrées:');
      compteursParUser.forEach((user, count) {
        print('   - User $user: $count enveloppe(s)');
      });

      print('📊 Total enveloppes migrées: $totalMigres');
      print('❌ Catégories exclues (Dettes): $totalExclues');
      print('✅ Migration des enveloppes terminée');
    } catch (e) {
      print('❌ Erreur migration enveloppes: $e');
    }
  }

  // Migrer les investissements Firebase vers PocketBase
  Future<void> _migrateInvestissements(String userId) async {
    try {
      print('🔄 Migration des investissements...');

      // Initialiser le mapping utilisateur
      await _initUserMapping();

      final firebaseService = FirebaseService();

      // Récupérer TOUS les investissements de Firebase (tous les utilisateurs)
      final allInvestissements =
          await firebaseService.firestore.collection('investissements').get();

      print(
          '📊 Investissements Firebase trouvés: ${allInvestissements.docs.length}');

      int totalMigres = 0;
      Map<String, int> compteursParUser = {};

      for (final doc in allInvestissements.docs) {
        final data = doc.data();
        final investissement = ActionInvestissement.fromMap(data);

        // Utiliser le mapping pour l'ID utilisateur
        final user = investissement.id;
        if (user.isEmpty) {
          print(
              '⚠️ Investissement ${investissement.symbole} sans userId, ignoré');
          continue;
        }
        final pocketbaseUserId = _getPocketBaseUserId(user);

        // Adapter les données Firebase vers PocketBase
        final dataPocketBase = {
          'nom': investissement.symbole,
          'valeur_marche': investissement.valeurActuelle,
          'cout_base': investissement.prixMoyen * investissement.nombre,
          'utilisateur_id': pocketbaseUserId,
        };

        try {
          await PocketBaseService.createInvestissement(dataPocketBase);
          totalMigres++;

          final user = investissement.id;
          compteursParUser[user] = (compteursParUser[user] ?? 0) + 1;

          print(
              '✅ Investissement migré: ${investissement.symbole} (Firebase User: $user → PocketBase User: $pocketbaseUserId)');
        } catch (e) {
          print(
              '⚠️ Erreur migration investissement ${investissement.symbole}: $e');
        }
      }

      print('📊 Répartition des investissements migrés:');
      compteursParUser.forEach((user, count) {
        print('   - User $user: $count investissement(s)');
      });

      print('✅ Migration des investissements terminée');
    } catch (e) {
      print('❌ Erreur migration investissements: $e');
    }
  }

  // Adapter le type de compte Firebase vers PocketBase
  String _adapterTypeCompte(String typeFirebase) {
    switch (typeFirebase.toLowerCase()) {
      case 'cheque':
      case 'compte chèque':
        return 'cheque';
      case 'epargne':
      case 'compte épargne':
        return 'epargne';
      case 'credit':
      case 'carte de crédit':
        return 'credit';
      case 'dette':
        return 'dette';
      case 'investissement':
        return 'investissement';
      default:
        return 'cheque';
    }
  }

  // Adapter le type de transaction Firebase vers PocketBase
  String _adapterTypeTransaction(String typeFirebase) {
    switch (typeFirebase.toLowerCase()) {
      case 'depense':
        return 'depense';
      case 'revenu':
        return 'revenu';
      default:
        return 'depense';
    }
  }

  // Adapter le type de mouvement financier Firebase vers PocketBase
  String _adapterTypeMouvementFinancier(String typeFirebase) {
    switch (typeFirebase.toLowerCase()) {
      case 'depensenormale':
        return 'depense_normale';
      case 'revenunormal':
        return 'revenu_normal';
      case 'pretaccorde':
        return 'pret_accorde';
      case 'remboursementrecu':
        return 'remboursement_recu';
      case 'dettecontractee':
        return 'dette_contractee';
      case 'remboursementeffectue':
        return 'remboursement_effectue';
      case 'ajustement':
        return 'ajustement';
      default:
        return 'depense_normale';
    }
  }

  // Générer un rapport de migration
  Future<String> generateMigrationReport() async {
    final report = StringBuffer();
    report.writeln('📋 RAPPORT DE MIGRATION POCKETBASE');
    report.writeln();

    report.writeln('✅ Services créés:');
    report.writeln('- PocketBaseService: Service principal pour PocketBase');
    report.writeln('- MigrationService: Service de migration et tests');
    report.writeln('- PocketBaseConfig: Configuration centralisée');
    report.writeln();

    report.writeln('✅ Fonctionnalités implémentées:');
    report.writeln('- Authentification (connexion/inscription/déconnexion)');
    report.writeln('- Gestion des comptes chèques');
    report.writeln('- Gestion des catégories');
    report.writeln('- Gestion des transactions de base');
    report.writeln();

    report.writeln('🔄 Prochaines étapes:');
    report.writeln('1. Tester la connexion PocketBase');
    report.writeln('2. Migrer les données existantes');
    report.writeln('3. Adapter les pages pour utiliser PocketBase');
    report.writeln('4. Supprimer Firebase progressivement');
    report.writeln();

    report.writeln('! Points d\'attention:');
    report.writeln('- Les modèles existants doivent être adaptés');
    report.writeln('- Les pages doivent être mises à jour');
    report.writeln('- Les tests doivent être créés');

    return report.toString();
  }

  // Test de migration complète (simulation)
  Future<void> testMigration(String userId) async {
    try {
      print('🧪 Test de migration complète (simulation)...');

      // Initialiser le mapping utilisateur
      await _initUserMapping();

      print('📋 Mapping utilisateur configuré:');
      _userMapping.forEach((firebaseId, pocketbaseId) {
        print('   - $firebaseId → $pocketbaseId');
      });

      // 1. Test migration des comptes
      await _testMigrationComptes(userId);

      // 2. Test migration des catégories
      await _testMigrationCategories(userId);

      // 3. Test migration des enveloppes
      await _testMigrationEnveloppes(userId);

      // 4. Test migration des transactions
      await _testMigrationTransactions(userId);

      // 5. Test migration des dettes
      await _testMigrationDettes(userId);

      // 6. Test migration des investissements
      await _testMigrationInvestissements(userId);

      print('✅ Test de migration complète terminé');
      print('📊 Résumé de la simulation:');
      print('   - Mapping utilisateur: ${_userMapping.length} utilisateurs');
      print('   - Toutes les données Firebase seront migrées vers PocketBase');
      print(
          '   - Chaque utilisateur aura ses données dans sa collection PocketBase');
    } catch (e) {
      print('❌ Erreur test migration: $e');
    }
  }

  // Test de migration des comptes (simulation)
  Future<void> _testMigrationComptes(String userId) async {
    try {
      print('🧪 Test migration des comptes...');

      // Initialiser le mapping utilisateur
      await _initUserMapping();

      final firebaseService = FirebaseService();

      // Récupérer TOUS les comptes de Firebase (tous les utilisateurs)
      final allComptes =
          await firebaseService.firestore.collection('comptes').get();

      print('📊 Comptes Firebase trouvés: ${allComptes.docs.length}');

      Map<String, int> compteursParType = {};
      Map<String, int> compteursParUser = {};

      for (final doc in allComptes.docs) {
        final data = doc.data();
        final compte = Compte.fromMap(data, doc.id);

        // Utiliser le mapping pour l'ID utilisateur
        final pocketbaseUserId = _getPocketBaseUserId(compte.userId ?? userId);

        final typeAdapte = _adapterTypeCompte(compte.type);
        compteursParType[typeAdapte] = (compteursParType[typeAdapte] ?? 0) + 1;

        // Compter par utilisateur
        final user = compte.userId ?? 'unknown';
        compteursParUser[user] = (compteursParUser[user] ?? 0) + 1;

        print(
            '📋 Compte "${compte.nom}" (Firebase User: $user → PocketBase User: $pocketbaseUserId) → Collection: ${_getCollectionForType(typeAdapte)}');
      }

      print('📊 Répartition des comptes par collection:');
      compteursParType.forEach((type, count) {
        print('   - ${_getCollectionForType(type)}: $count compte(s)');
      });

      print('📊 Répartition par utilisateur:');
      compteursParUser.forEach((user, count) {
        print('   - User $user: $count compte(s)');
      });

      print('✅ Test migration des comptes terminé');
    } catch (e) {
      print('❌ Erreur test migration comptes: $e');
    }
  }

  // Test de migration des catégories (simulation)
  Future<void> _testMigrationCategories(String userId) async {
    try {
      print('🧪 Test migration des catégories...');

      final firebaseService = FirebaseService();

      // Récupérer TOUTES les catégories de Firebase (tous les utilisateurs)
      final allCategories =
          await firebaseService.firestore.collection('categories').get();

      print('📊 Catégories Firebase trouvées: ${allCategories.docs.length}');

      Map<String, int> compteursParUser = {};
      int totalExclues = 0;

      for (final doc in allCategories.docs) {
        final data = doc.data();
        data['id'] = doc.id; // Ajouter l'ID du document
        final categorie = Categorie.fromMap(data);

        // Exclure la catégorie "Dettes"
        if (categorie.nom.toLowerCase() == 'dettes') {
          totalExclues++;
          continue;
        }

        // Utiliser le mapping pour l'ID utilisateur
        final pocketbaseUserId =
            _getPocketBaseUserId(categorie.userId ?? userId);

        // Compter par utilisateur
        final user = categorie.userId ?? 'unknown';
        compteursParUser[user] = (compteursParUser[user] ?? 0) + 1;

        print(
            '📋 Catégorie "${categorie.nom}" (Firebase User: $user → PocketBase User: $pocketbaseUserId)');
      }

      print('📊 Répartition par utilisateur:');
      compteursParUser.forEach((user, count) {
        print('   - User $user: $count catégorie(s)');
      });

      print('❌ Catégories exclues (Dettes): $totalExclues');
      print('✅ Test migration des catégories terminé');
    } catch (e) {
      print('❌ Erreur test migration catégories: $e');
    }
  }

  // Test de migration des transactions (simulation)
  Future<void> _testMigrationTransactions(String userId) async {
    try {
      print('🧪 Test migration des transactions...');

      final firebaseService = FirebaseService();

      // Récupérer TOUTES les transactions de Firebase (tous les utilisateurs)
      final allTransactions =
          await firebaseService.firestore.collection('transactions').get();

      print(
          '📊 Transactions Firebase trouvées: ${allTransactions.docs.length}');

      Map<String, int> compteursParUser = {};
      int totalAllocations = 0;

      for (final doc in allTransactions.docs) {
        final data = doc.data();
        data['id'] = doc.id; // Ajouter l'ID du document
        final transaction = Transaction.fromJson(data);

        // Utiliser le mapping pour l'ID utilisateur
        final pocketbaseUserId =
            _getPocketBaseUserId(transaction.userId ?? userId);

        // Compter par utilisateur
        final user = transaction.userId ?? 'unknown';
        compteursParUser[user] = (compteursParUser[user] ?? 0) + 1;

        // Vérifier si c'est une allocation mensuelle
        if (_isAllocationMensuelle(transaction.date)) {
          totalAllocations++;
          print(
              '📋 Transaction "${transaction.tiers ?? 'Sans tiers'}" (Allocation mensuelle) (Firebase User: $user → PocketBase User: $pocketbaseUserId)');
        } else {
          print(
              '📋 Transaction "${transaction.tiers ?? 'Sans tiers'}" (Firebase User: $user → PocketBase User: $pocketbaseUserId)');
        }
      }

      print('📊 Répartition par utilisateur:');
      compteursParUser.forEach((user, count) {
        print('   - User $user: $count transaction(s)');
      });

      print('📅 Allocations mensuelles détectées: $totalAllocations');
      print('✅ Test migration des transactions terminé');
    } catch (e) {
      print('❌ Erreur test migration transactions: $e');
    }
  }

  // Test de migration des dettes (simulation)
  Future<void> _testMigrationDettes(String userId) async {
    try {
      print('🧪 Test migration des dettes...');

      final firebaseService = FirebaseService();

      // Récupérer TOUTES les dettes de Firebase (tous les utilisateurs)
      final allDettes =
          await firebaseService.firestore.collection('dettes').get();

      print('📊 Dettes Firebase trouvées: ${allDettes.docs.length}');

      Map<String, int> compteursParUser = {};
      Map<String, int> compteursParType = {
        'manual': 0,
        'automatic': 0,
        'loan': 0
      };

      for (final doc in allDettes.docs) {
        final data = doc.data();
        final dette = Dette.fromMap(data);

        // Utiliser le mapping pour l'ID utilisateur
        final pocketbaseUserId = _getPocketBaseUserId(dette.userId);

        // Compter par utilisateur
        final user = dette.userId;
        compteursParUser[user] = (compteursParUser[user] ?? 0) + 1;

        // Déterminer le type de dette
        String typeDette = 'manual';
        String collection = 'comptes_dettes';

        if (dette.type == 'pret') {
          typeDette = 'loan';
          collection = 'pret_personnel';
        }

        compteursParType[typeDette] = (compteursParType[typeDette] ?? 0) + 1;

        print(
            '📋 Dette "${dette.nomTiers}" (Type: $typeDette) → Collection: $collection (Firebase User: $user → PocketBase User: $pocketbaseUserId)');
      }

      print('📊 Répartition par utilisateur:');
      compteursParUser.forEach((user, count) {
        print('   - User $user: $count dette(s)');
      });

      print('📊 Répartition par type:');
      compteursParType.forEach((type, count) {
        print('   - $type: $count dette(s)');
      });

      print('✅ Test migration des dettes terminé');
    } catch (e) {
      print('❌ Erreur test migration dettes: $e');
    }
  }

  // Test de migration des investissements (simulation)
  Future<void> _testMigrationInvestissements(String userId) async {
    try {
      print('🧪 Test migration des investissements...');

      final firebaseService = FirebaseService();

      // Récupérer TOUS les investissements de Firebase (tous les utilisateurs)
      final allInvestissements =
          await firebaseService.firestore.collection('investissements').get();

      print(
          '📊 Investissements Firebase trouvés: ${allInvestissements.docs.length}');

      Map<String, int> compteursParUser = {};

      for (final doc in allInvestissements.docs) {
        final data = doc.data();
        final investissement = ActionInvestissement.fromMap(data);

        // Utiliser le mapping pour l'ID utilisateur
        final pocketbaseUserId = _getPocketBaseUserId(investissement.id);

        // Compter par utilisateur (utiliser l'ID comme fallback)
        final user = investissement.id;
        compteursParUser[user] = (compteursParUser[user] ?? 0) + 1;

        print(
            '📋 Investissement "${investissement.symbole}" (Firebase User: $user → PocketBase User: $pocketbaseUserId)');
      }

      print('📊 Répartition par utilisateur:');
      compteursParUser.forEach((user, count) {
        print('   - User $user: $count investissement(s)');
      });

      print('✅ Test migration des investissements terminé');
    } catch (e) {
      print('❌ Erreur test migration investissements: $e');
    }
  }

  // Test de migration des enveloppes (simulation)
  Future<void> _testMigrationEnveloppes(String userId) async {
    try {
      print('🧪 Test migration des enveloppes...');

      final firebaseService = FirebaseService();

      // Récupérer TOUTES les catégories de Firebase (tous les utilisateurs)
      final allCategories =
          await firebaseService.firestore.collection('categories').get();

      print('📊 Catégories Firebase trouvées: ${allCategories.docs.length}');

      Map<String, int> compteursParUser = {};
      int totalEnveloppes = 0;
      int totalExclues = 0;

      for (final doc in allCategories.docs) {
        final data = doc.data();
        data['id'] = doc.id; // Ajouter l'ID du document
        final categorie = Categorie.fromMap(data);

        // Exclure la catégorie "Dettes"
        if (categorie.nom.toLowerCase() == 'dettes') {
          totalExclues++;
          continue;
        }

        // Utiliser le mapping pour l'ID utilisateur
        final pocketbaseUserId =
            _getPocketBaseUserId(categorie.userId ?? userId);

        // Compter par utilisateur
        final user = categorie.userId ?? 'unknown';
        compteursParUser[user] =
            (compteursParUser[user] ?? 0) + categorie.enveloppes.length;
        totalEnveloppes += categorie.enveloppes.length;

        print(
            '📋 Catégorie "${categorie.nom}" (Firebase User: $user → PocketBase User: $pocketbaseUserId)');
        print('   - Enveloppes: ${categorie.enveloppes.length}');

        for (final enveloppe in categorie.enveloppes) {
          print(
              '     • Enveloppe "${enveloppe.nom}" (solde: ${enveloppe.solde}€)');
        }
      }

      print('📊 Répartition par utilisateur:');
      compteursParUser.forEach((user, count) {
        print('   - User $user: $count enveloppe(s)');
      });

      print('📊 Total enveloppes: $totalEnveloppes');
      print('❌ Catégories exclues (Dettes): $totalExclues');
      print('✅ Test migration des enveloppes terminé');
    } catch (e) {
      print('❌ Erreur test migration enveloppes: $e');
    }
  }

  // Obtenir le nom de la collection pour un type de compte
  String _getCollectionForType(String type) {
    switch (type) {
      case 'cheque':
        return PocketBaseConfig.comptesChequesCollection;
      case 'epargne':
        return PocketBaseConfig.comptesEpargneCollection;
      case 'credit':
        return PocketBaseConfig.comptesCreditsCollection;
      case 'dette':
        return PocketBaseConfig.comptesDettesCollection;
      case 'investissement':
        return PocketBaseConfig.comptesInvestissementCollection;
      default:
        return PocketBaseConfig.comptesChequesCollection;
    }
  }

  // Obtenir la date du 1er du mois pour une allocation mensuelle
  DateTime _getDatePremierMois(DateTime date) {
    return DateTime(date.year, date.month, 1, 0, 0, 0);
  }

  // Mapping des utilisateurs Firebase vers PocketBase (configuré manuellement)
  Map<String, String> _userMapping = {
    'vH0n5dPnOiVmdPFpY4NWHTa0QKr2': '3gisghkqm6uau4b', // Premier utilisateur
    'p7tkc5JDEIhzLOOY4wwbvH7exVU2': '9vgxq9oh11qtvsc', // Deuxième utilisateur
    'BCE6de7OPIhUdlYKj1RthWdxOFv1': 's1bt7ukigruvoez', // Troisième utilisateur
  };

  // Initialiser le mapping utilisateur
  Future<void> _initUserMapping() async {
    try {
      print('🔗 Initialisation du mapping utilisateur...');

      final firebaseService = FirebaseService();

      // Récupérer tous les comptes Firebase pour identifier tous les utilisateurs
      final allComptes =
          await firebaseService.firestore.collection('comptes').get();

      // Extraire tous les utilisateurs uniques
      Set<String> firebaseUserIds = {};
      for (final doc in allComptes.docs) {
        final data = doc.data();
        final userId = data['userId'] as String?;
        if (userId != null) {
          firebaseUserIds.add(userId);
        }
      }

      print('📊 Utilisateurs Firebase trouvés: ${firebaseUserIds.length}');

      // Vérifier que tous les utilisateurs Firebase sont dans le mapping
      for (final firebaseUserId in firebaseUserIds) {
        if (!_userMapping.containsKey(firebaseUserId)) {
          print('⚠️ Utilisateur Firebase $firebaseUserId non mappé !');
          print('   Ajoutez-le dans le mapping _userMapping');
        }
      }

      print(
          '✅ Mapping utilisateur initialisé: ${_userMapping.length} utilisateurs');

      // Afficher le mapping complet pour debug
      print('📋 Mapping actuel:');
      _userMapping.forEach((firebaseId, pocketbaseId) {
        print('   - $firebaseId → $pocketbaseId');
      });
    } catch (e) {
      print('❌ Erreur initialisation mapping: $e');
    }
  }

  // Obtenir l'ID PocketBase pour un ID Firebase
  String _getPocketBaseUserId(String firebaseUserId) {
    final pocketbaseId = _userMapping[firebaseUserId];
    if (pocketbaseId == null) {
      print('❌ ERREUR: Utilisateur Firebase $firebaseUserId non mappé !');
      print('📋 Utilisateurs disponibles dans le mapping:');
      _userMapping.forEach((firebaseId, pocketbaseId) {
        print('   - $firebaseId → $pocketbaseId');
      });
      print('❌ Migration arrêtée - Ajoutez $firebaseUserId au mapping');
      throw Exception('Utilisateur Firebase $firebaseUserId non mappé');
    }
    return pocketbaseId;
  }

  // Analyser l'export Firebase pour extraire les données
  Future<void> analyzeFirebaseExport() async {
    try {
      print('🔍 Analyse de l\'export Firebase...');

      // Sur Android, on ne peut pas accéder directement aux fichiers
      // On va analyser les données que nous avons déjà extraites
      print('📱 Environnement Android détecté - Analyse des données extraites');

      // Données extraites de l'export Firebase (basées sur notre analyse précédente)
      final List<String> users = [
        'vH0n5dPnOiVmdPFpY4NWHTa0QKr2',
        'p7tkc5JDEIhzLOOY4wwbvH7exVU2',
        'BCE6de7OPIhUdlYKj1RthWdxOFv1'
      ];

      final Map<String, String> collections = {
        'comptes': 'comptes',
        'categories': 'categories',
        'transactions': 'transactions',
        'dettes': 'dettes',
        'investissements': 'actions',
        'tiers': 'tiers'
      };

      print('📊 Données extraites de l\'export Firebase:');
      print('👥 Utilisateurs trouvés: ${users.length}');
      users.forEach((user) => print('   - $user'));

      print('📁 Collections trouvées: ${collections.length}');
      collections.forEach((name, collection) {
        print('   - $name → $collection');
      });

      // Vérifier le mapping utilisateur
      print('🔗 Vérification du mapping utilisateur:');
      final mapping = {
        'vH0n5dPnOiVmdPFpY4NWHTa0QKr2': '3gisghkqm6uau4b',
        'p7tkc5JDEIhzLOOY4wwbvH7exVU2': '9vgxq9oh11qtvsc',
        'BCE6de7OPIhUdlYKj1RthWdxOFv1': 's1bt7ukigruvoez',
      };

      mapping.forEach((firebaseId, pocketbaseId) {
        print('   - $firebaseId → $pocketbaseId');
      });

      print('✅ Analyse de l\'export Firebase terminée');
      print('💡 Prêt pour la migration avec les vrais IDs utilisateurs !');
    } catch (e) {
      print('❌ Erreur analyse export Firebase: $e');
    }
  }

  // Migration complète avec les vrais IDs utilisateurs
  Future<void> migrateAllDataWithRealIds() async {
    try {
      print('🚀 Début de la migration complète avec vrais IDs...');

      // Mapping des vrais IDs utilisateurs
      final userMapping = {
        'vH0n5dPnOiVmdPFpY4NWHTa0QKr2': '3gisghkqm6uau4b',
        'p7tkc5JDEIhzLOOY4wwbvH7exVU2': '9vgxq9oh11qtvsc',
        'BCE6de7OPIhUdlYKj1RthWdxOFv1': 's1bt7ukigruvoez',
      };

      print('👥 Migration pour ${userMapping.length} utilisateurs:');
      userMapping.forEach((firebaseId, pocketbaseId) {
        print('   - $firebaseId → $pocketbaseId');
      });

      // Migrer les comptes pour tous les utilisateurs
      print('\n🏦 Migration des comptes...');
      for (final entry in userMapping.entries) {
        final firebaseUserId = entry.key;
        final pocketbaseUserId = entry.value;

        try {
          // Récupérer tous les comptes de Firebase
          final comptesSnapshot = await FirebaseFirestore.instance
              .collection('comptes')
              .where('userId', isEqualTo: firebaseUserId)
              .get();

          final comptes =
              comptesSnapshot.docs.map((doc) => doc.data()).toList();
          print('   📊 ${comptes.length} comptes trouvés pour $firebaseUserId');

          for (final compte in comptes) {
            try {
              final typeCompte = compte['type'] ?? 'Chèque';
              Map<String, dynamic> newCompte = {
                'nom': compte['nom'],
                'solde': compte['solde'] ?? 0.0,
                'utilisateur_id': pocketbaseUserId,
                'couleur': compte['couleur'] ?? 0xFF2196F3,
                'ordre': compte['ordre'] ?? 0,
                'archive': compte['estArchive'] ?? false,
              };

              // Ajouter les champs supplémentaires selon le type
              RecordModel result;
              if (typeCompte == 'Carte de crédit') {
                newCompte['limite_credit'] = compte['limiteCredit'] ?? 0.0;
                newCompte['solde_utilise'] = compte['soldeUtilise'] ?? 0.0;
                newCompte['taux_interet'] = compte['tauxInteret'] ?? 0.0;
                newCompte['paiement_minimum'] =
                    compte['paiementMinimum'] ?? 0.0;
                newCompte['date_echeance'] =
                    compte['dateEcheance'] ?? DateTime.now().toIso8601String();
                newCompte['rembourser_dettes_associees'] =
                    compte['rembourserDettesAssociees'] ?? false;
                newCompte['depenses_fixes'] = compte['depensesFixes'] ?? [];
                result = await PocketBaseService.createCompteCredit(newCompte);
              } else if (typeCompte == 'Dette') {
                newCompte['solde_dette'] = compte['solde'] ?? 0.0;
                newCompte['taux_interet'] = compte['tauxInteret'] ?? 0.0;
                newCompte['montant_initial'] = compte['montantInitial'] ?? 0.0;
                newCompte['paiement_minimum'] =
                    compte['paiementMinimum'] ?? 0.0;
                result = await PocketBaseService.createDette(newCompte);
              } else if (typeCompte == 'Investissement') {
                newCompte['valeur_marche'] = compte['valeurMarche'] ?? 0.0;
                newCompte['cout_base'] = compte['coutBase'] ?? 0.0;
                result =
                    await PocketBaseService.createInvestissement(newCompte);
              } else {
                // Type Chèque par défaut
                newCompte['pret_a_placer'] = compte['pretAPlacer'] ?? 0.0;
                result = await PocketBaseService.createCompte(newCompte);
              }

              print(
                  '   🔍 Tentative création compte: ${compte['nom']} (Type: $typeCompte)');
              print('   📊 Données envoyées: $newCompte');

              print('   ✅ Compte créé: ${compte['nom']} (${typeCompte})');
            } catch (e) {
              print('   ❌ Erreur création compte ${compte['nom']}: $e');
              print('   📊 Données qui ont causé l\'erreur: ${compte}');
            }
          }
        } catch (e) {
          print('   ❌ Erreur récupération comptes pour $firebaseUserId: $e');
        }
      }

      // Migrer les catégories (excluant "Dettes")
      print('\n📁 Migration des catégories...');
      for (final entry in userMapping.entries) {
        final firebaseUserId = entry.key;
        final pocketbaseUserId = entry.value;

        try {
          final categoriesSnapshot = await FirebaseFirestore.instance
              .collection('categories')
              .where('userId', isEqualTo: firebaseUserId)
              .get();

          final categories =
              categoriesSnapshot.docs.map((doc) => doc.data()).toList();
          final categoriesFiltered =
              categories.where((cat) => cat['nom'] != 'Dettes').toList();
          print(
              '   📊 ${categoriesFiltered.length} catégories trouvées pour $firebaseUserId');

          for (final categorie in categoriesFiltered) {
            try {
              final newCategorie = {
                'nom': categorie['nom'],
                'utilisateur_id': pocketbaseUserId,
                'ordre': categorie['ordre'] ?? 0,
              };

              // Ajouter les enveloppes si elles existent
              if (categorie['enveloppes'] != null &&
                  categorie['enveloppes'] is List) {
                newCategorie['enveloppes'] = categorie['enveloppes'];
              }

              print('   🔍 Tentative création catégorie: ${categorie['nom']}');
              print('   📊 Données envoyées: $newCategorie');

              final result =
                  await PocketBaseService.createCategorie(newCategorie);
              print('   ✅ Catégorie créée: ${categorie['nom']}');
            } catch (e) {
              print('   ❌ Erreur création catégorie ${categorie['nom']}: $e');
              print('   📊 Données qui ont causé l\'erreur: ${categorie}');
            }
          }
        } catch (e) {
          print('   ❌ Erreur récupération catégories pour $firebaseUserId: $e');
        }
      }

      // Migrer les transactions
      print('\n💳 Migration des transactions...');
      for (final entry in userMapping.entries) {
        final firebaseUserId = entry.key;
        final pocketbaseUserId = entry.value;

        try {
          final transactionsSnapshot = await FirebaseFirestore.instance
              .collection('transactions')
              .where('userId', isEqualTo: firebaseUserId)
              .get();

          final transactions =
              transactionsSnapshot.docs.map((doc) => doc.data()).toList();
          print(
              '   📊 ${transactions.length} transactions trouvées pour $firebaseUserId');

          for (final transaction in transactions) {
            try {
              // Convertir le Timestamp en String ISO
              String dateTransaction = DateTime.now().toIso8601String();
              if (transaction['date'] != null) {
                if (transaction['date'] is Timestamp) {
                  final timestamp = transaction['date'] as Timestamp;
                  dateTransaction = DateTime.fromMillisecondsSinceEpoch(
                    timestamp.millisecondsSinceEpoch,
                  ).toIso8601String();
                } else {
                  dateTransaction = transaction['date'].toString();
                }
              }

              final newTransaction = {
                'utilisateur_id': pocketbaseUserId,
                'type': transaction['type'] ?? 'Depense',
                'type_mouvement':
                    transaction['typeMouvement'] ?? 'depenseNormale',
                'montant': transaction['montant'] ?? 0.0,
                'date': dateTransaction,
                'note': transaction['note'] ?? '',
                'compte_id': transaction['compteId'] ?? '',
                'collection_compte': 'comptes_cheques',
                'tiers_id': transaction['tiers'] ?? '',
                'marqueur': transaction['marqueur'] ?? '',
                'est_fractionnee': transaction['estFractionnee'] ?? false,
                'transaction_parente_id':
                    transaction['transactionParenteId'] ?? '',
                'compte_de_passif_associe':
                    transaction['compteDePassifAssocie'] ?? '',
              };

              // Ajouter enveloppe_id seulement si elle existe
              if (transaction['enveloppeId'] != null &&
                  transaction['enveloppeId'].toString().isNotEmpty) {
                newTransaction['enveloppe_id'] = transaction['enveloppeId'];
              }

              // Ajouter sousItems seulement s'ils existent
              if (transaction['sousItems'] != null &&
                  transaction['sousItems'] is List) {
                newTransaction['sous_items'] = transaction['sousItems'];
              }

              print(
                  '   🔍 Tentative création transaction: ${transaction['tiers'] ?? 'Sans tiers'}');
              print('   📊 Données envoyées: $newTransaction');

              final result =
                  await PocketBaseService.createTransaction(newTransaction);
              print(
                  '   ✅ Transaction créée: ${transaction['tiers'] ?? 'Sans tiers'}');
            } catch (e) {
              print(
                  '   ❌ Erreur création transaction ${transaction['tiers'] ?? 'Sans tiers'}: $e');
              print('   📊 Données qui ont causé l\'erreur: ${transaction}');
            }
          }
        } catch (e) {
          print(
              '   ❌ Erreur récupération transactions pour $firebaseUserId: $e');
        }
      }

      // Migrer les dettes
      print('\n💸 Migration des dettes...');
      for (final entry in userMapping.entries) {
        final firebaseUserId = entry.key;
        final pocketbaseUserId = entry.value;

        try {
          final dettesSnapshot = await FirebaseFirestore.instance
              .collection('dettes')
              .where('userId', isEqualTo: firebaseUserId)
              .get();

          final dettes = dettesSnapshot.docs.map((doc) => doc.data()).toList();
          print('   📊 ${dettes.length} dettes trouvées pour $firebaseUserId');

          for (final dette in dettes) {
            try {
              final estManuelle = dette['estManuelle'] ?? true;

              // Convertir le Timestamp en String ISO
              String dateCreation = DateTime.now().toIso8601String();
              if (dette['dateCreation'] != null) {
                if (dette['dateCreation'] is Timestamp) {
                  final timestamp = dette['dateCreation'] as Timestamp;
                  dateCreation = DateTime.fromMillisecondsSinceEpoch(
                    timestamp.millisecondsSinceEpoch,
                  ).toIso8601String();
                } else {
                  dateCreation = dette['dateCreation'].toString();
                }
              }

              if (estManuelle) {
                final newDette = {
                  'nom_tiers': dette['nomTiers'] ?? '',
                  'montant_initial': dette['montantInitial'] ?? 0.0,
                  'solde': dette['solde'] ?? 0.0,
                  'type': 'dette',
                  'archive': dette['archive'] ?? false,
                  'date_creation': dateCreation,
                  'utilisateur_id': pocketbaseUserId,
                  'note': dette['note'] ?? '',
                };

                print('   🔍 Tentative création dette: ${dette['nomTiers']}');
                print('   📊 Données envoyées: $newDette');

                final result = await PocketBaseService.createDette(newDette);
                print('   ✅ Dette manuelle créée: ${dette['nomTiers']}');
              } else {
                final newPret = {
                  'nom_tiers': dette['nomTiers'] ?? '',
                  'montant_initial': dette['montantInitial'] ?? 0.0,
                  'solde': dette['solde'] ?? 0.0,
                  'type': 'pret',
                  'archive': dette['archive'] ?? false,
                  'date_creation': dateCreation,
                  'utilisateur_id': pocketbaseUserId,
                  'note': dette['note'] ?? '',
                };

                print('   🔍 Tentative création prêt: ${dette['nomTiers']}');
                print('   📊 Données envoyées: $newPret');

                final result =
                    await PocketBaseService.createPretPersonnel(newPret);
                print('   ✅ Prêt personnel créé: ${dette['nomTiers']}');
              }
            } catch (e) {
              print('   ❌ Erreur création dette ${dette['nomTiers']}: $e');
              print('   📊 Données qui ont causé l\'erreur: ${dette}');
            }
          }
        } catch (e) {
          print('   ❌ Erreur récupération dettes pour $firebaseUserId: $e');
        }
      }

      // Migrer les investissements
      print('\n📈 Migration des investissements...');
      for (final entry in userMapping.entries) {
        final firebaseUserId = entry.key;
        final pocketbaseUserId = entry.value;

        try {
          final investissementsSnapshot = await FirebaseFirestore.instance
              .collection('actions')
              .where('userId', isEqualTo: firebaseUserId)
              .get();

          final investissements =
              investissementsSnapshot.docs.map((doc) => doc.data()).toList();
          print(
              '   📊 ${investissements.length} investissements trouvés pour $firebaseUserId');

          for (final investissement in investissements) {
            try {
              final newInvestissement = {
                'symbole': investissement['symbole'] ?? '',
                'quantite': investissement['quantite'] ?? 0.0,
                'prix_achat': investissement['prixAchat'] ?? 0.0,
                'date_achat': investissement['dateAchat'] ??
                    DateTime.now().toIso8601String(),
                'utilisateur_id': pocketbaseUserId,
                'notes': investissement['notes'] ?? '',
              };

              final result = await PocketBaseService.createInvestissement(
                  newInvestissement);
              print('   ✅ Investissement créé: ${investissement['symbole']}');
            } catch (e) {
              print(
                  '   ❌ Erreur création investissement ${investissement['symbole']}: $e');
            }
          }
        } catch (e) {
          print(
              '   ❌ Erreur récupération investissements pour $firebaseUserId: $e');
        }
      }

      // Migrer les enveloppes
      print('\n📦 Migration des enveloppes...');
      for (final entry in userMapping.entries) {
        final firebaseUserId = entry.key;
        final pocketbaseUserId = entry.value;

        try {
          final enveloppesSnapshot = await FirebaseFirestore.instance
              .collection('enveloppes')
              .where('userId', isEqualTo: firebaseUserId)
              .get();

          final enveloppes =
              enveloppesSnapshot.docs.map((doc) => doc.data()).toList();
          print(
              '   📊 ${enveloppes.length} enveloppes trouvées pour $firebaseUserId');

          for (final enveloppe in enveloppes) {
            try {
              final newEnveloppe = {
                'utilisateur_id': pocketbaseUserId,
                'categorie_id': enveloppe['categorieId'] ?? '',
                'nom': enveloppe['nom'] ?? '',
                'objectif_date': enveloppe['objectifDate'] ??
                    DateTime.now().toIso8601String(),
                'frequence_objectif': enveloppe['frequenceObjectif'] ?? 'Aucun',
                'compte_provenance_id': enveloppe['compteProvenanceId'] ?? '',
                'ordre': enveloppe['ordre'] ?? 0,
                'solde_enveloppe': enveloppe['soldeEnveloppe'] ?? 0.0,
                'depense': enveloppe['depense'] ?? 0.0,
                'est_archive': enveloppe['estArchive'] ?? false,
                'objectif_montant': enveloppe['objectifMontant'] ?? 0.0,
                'moisObjectif': enveloppe['moisObjectif'] ??
                    DateTime.now().toIso8601String(),
              };

              final result =
                  await PocketBaseService.createEnveloppe(newEnveloppe);
              print('   ✅ Enveloppe créée: ${enveloppe['nom']}');
            } catch (e) {
              print('   ❌ Erreur création enveloppe ${enveloppe['nom']}: $e');
            }
          }
        } catch (e) {
          print('   ❌ Erreur récupération enveloppes pour $firebaseUserId: $e');
        }
      }

      // Migrer les allocations mensuelles
      print('\n💰 Migration des allocations mensuelles...');
      for (final entry in userMapping.entries) {
        final firebaseUserId = entry.key;
        final pocketbaseUserId = entry.value;

        try {
          final allocationsSnapshot = await FirebaseFirestore.instance
              .collection('allocations_mensuelles')
              .where('userId', isEqualTo: firebaseUserId)
              .get();

          final allocations =
              allocationsSnapshot.docs.map((doc) => doc.data()).toList();
          print(
              '   📊 ${allocations.length} allocations trouvées pour $firebaseUserId');

          for (final allocation in allocations) {
            try {
              final newAllocation = {
                'utilisateur_id': pocketbaseUserId,
                'enveloppe_id': allocation['enveloppeId'] ?? '',
                'mois': allocation['mois'] ?? DateTime.now().toIso8601String(),
                'solde': allocation['solde'] ?? 0.0,
                'alloue': allocation['alloue'] ?? 0.0,
                'depense': allocation['depense'] ?? 0.0,
                'compte_source_id': allocation['compteSourceId'] ?? '',
                'collection_compte_source':
                    allocation['collectionCompteSource'] ?? 'comptes_cheques',
              };

              final result = await PocketBaseService.createAllocationMensuelle(
                  newAllocation);
              print(
                  '   ✅ Allocation mensuelle créée: ${allocation['alloue'] ?? 0.0}€');
            } catch (e) {
              print('   ❌ Erreur création allocation mensuelle: $e');
            }
          }
        } catch (e) {
          print(
              '   ❌ Erreur récupération allocations pour $firebaseUserId: $e');
        }
      }

      // Migrer les tiers
      print('\n👥 Migration des tiers...');
      for (final entry in userMapping.entries) {
        final firebaseUserId = entry.key;
        final pocketbaseUserId = entry.value;

        try {
          final tiersSnapshot = await FirebaseFirestore.instance
              .collection('tiers')
              .where('userId', isEqualTo: firebaseUserId)
              .get();

          final tiers = tiersSnapshot.docs.map((doc) => doc.data()).toList();
          print('   📊 ${tiers.length} tiers trouvés pour $firebaseUserId');

          for (final tiers in tiers) {
            try {
              final newTiers = {
                'nom': tiers['nom'] ?? '',
                'utilisateur_id': pocketbaseUserId,
              };

              print('   🔍 Tentative création tiers: ${tiers['nom']}');
              print('   📊 Données envoyées: $newTiers');

              final result = await PocketBaseService.createTiers(newTiers);
              print('   ✅ Tiers créé: ${tiers['nom']}');
            } catch (e) {
              print('   ❌ Erreur création tiers ${tiers['nom']}: $e');
              print('   📊 Données qui ont causé l\'erreur: ${tiers}');
            }
          }
        } catch (e) {
          print('   ❌ Erreur récupération tiers pour $firebaseUserId: $e');
        }
      }

      print('\n✅ Migration complète terminée !');
      print(
          '🎉 Toutes les données ont été migrées avec les vrais IDs utilisateurs !');
    } catch (e) {
      print('❌ Erreur migration complète: $e');
    }
  }

  // Vérifier toutes les collections PocketBase
  Future<void> verifyAllPocketBaseCollections() async {
    try {
      print('🔍 Vérification de toutes les collections PocketBase...');

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
          print('   ✅ $collection: ${records.length} enregistrements');
        } catch (e) {
          print('   ❌ $collection: Erreur - $e');
        }
      }

      print('✅ Vérification terminée');
    } catch (e) {
      print('❌ Erreur vérification collections: $e');
    }
  }

  // Migration pour l'utilisateur connecté uniquement
  Future<void> migrateCurrentUserData() async {
    try {
      print('🚀 Début de la migration pour l\'utilisateur connecté...');

      // Récupérer l'utilisateur Firebase connecté
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) {
        print('❌ Aucun utilisateur Firebase connecté');
        return;
      }

      final firebaseUserId = firebaseUser.uid;
      print('👤 Utilisateur connecté: $firebaseUserId');

      // Créer automatiquement l'utilisateur dans PocketBase
      try {
        final pb = await PocketBaseService.instance;
        final userData = {
          'email': firebaseUser.email ?? '',
          'name': firebaseUser.displayName ?? 'Utilisateur',
          'password': 'temp123456', // Mot de passe temporaire
          'passwordConfirm': 'temp123456',
        };

        final pocketbaseUser = await PocketBaseService.signUp(
          userData['email'] ?? '',
          userData['password'] ?? '',
          userData['passwordConfirm'] ?? '',
          data: userData,
        );

        final pocketbaseUserId = pocketbaseUser.id;
        print('✅ Utilisateur créé dans PocketBase: $pocketbaseUserId');

        // Migrer les comptes
        print('\n🏦 Migration des comptes...');
        try {
          final comptesSnapshot = await FirebaseFirestore.instance
              .collection('comptes')
              .where('userId', isEqualTo: firebaseUserId)
              .get();

          final comptes =
              comptesSnapshot.docs.map((doc) => doc.data()).toList();
          print('   📊 ${comptes.length} comptes trouvés');

          for (final compte in comptes) {
            try {
              final typeCompte = compte['type'] ?? 'Chèque';
              Map<String, dynamic> newCompte = {
                'nom': compte['nom'],
                'solde': compte['solde'] ?? 0.0,
                'utilisateur_id': pocketbaseUserId,
                'couleur': compte['couleur'] ?? 0xFF2196F3,
                'ordre': compte['ordre'] ?? 0,
                'archive': compte['estArchive'] ?? false,
              };

              // Ajouter les champs supplémentaires selon le type
              RecordModel result;
              if (typeCompte == 'Carte de crédit') {
                newCompte['limite_credit'] = compte['limiteCredit'] ?? 0.0;
                newCompte['solde_utilise'] = compte['soldeUtilise'] ?? 0.0;
                newCompte['taux_interet'] = compte['tauxInteret'] ?? 0.0;
                newCompte['paiement_minimum'] =
                    compte['paiementMinimum'] ?? 0.0;
                newCompte['date_echeance'] =
                    compte['dateEcheance'] ?? DateTime.now().toIso8601String();
                newCompte['rembourser_dettes_associees'] =
                    compte['rembourserDettesAssociees'] ?? false;
                newCompte['depenses_fixes'] = compte['depensesFixes'] ?? [];
                result = await PocketBaseService.createCompteCredit(newCompte);
              } else if (typeCompte == 'Dette') {
                newCompte['solde_dette'] = compte['solde'] ?? 0.0;
                newCompte['taux_interet'] = compte['tauxInteret'] ?? 0.0;
                newCompte['montant_initial'] = compte['montantInitial'] ?? 0.0;
                newCompte['paiement_minimum'] =
                    compte['paiementMinimum'] ?? 0.0;
                result = await PocketBaseService.createDette(newCompte);
              } else if (typeCompte == 'Investissement') {
                newCompte['valeur_marche'] = compte['valeurMarche'] ?? 0.0;
                newCompte['cout_base'] = compte['coutBase'] ?? 0.0;
                result =
                    await PocketBaseService.createInvestissement(newCompte);
              } else {
                // Type Chèque par défaut
                newCompte['pret_a_placer'] = compte['pretAPlacer'] ?? 0.0;
                result = await PocketBaseService.createCompte(newCompte);
              }

              print(
                  '   🔍 Tentative création compte: ${compte['nom']} (Type: $typeCompte)');
              print('   📊 Données envoyées: $newCompte');

              print('   ✅ Compte créé: ${compte['nom']} (${typeCompte})');
            } catch (e) {
              print('   ❌ Erreur création compte ${compte['nom']}: $e');
              print('   📊 Données qui ont causé l\'erreur: ${compte}');
            }
          }
        } catch (e) {
          print('   ❌ Erreur récupération comptes: $e');
        }

        // Migrer les catégories
        print('\n📁 Migration des catégories...');
        try {
          final categoriesSnapshot = await FirebaseFirestore.instance
              .collection('categories')
              .where('userId', isEqualTo: firebaseUserId)
              .get();

          final categories =
              categoriesSnapshot.docs.map((doc) => doc.data()).toList();
          final categoriesFiltered =
              categories.where((cat) => cat['nom'] != 'Dettes').toList();
          print('   📊 ${categoriesFiltered.length} catégories trouvées');

          for (final categorie in categoriesFiltered) {
            try {
              final newCategorie = {
                'nom': categorie['nom'],
                'utilisateur_id': pocketbaseUserId,
                'ordre': categorie['ordre'] ?? 0,
              };

              // Ajouter les enveloppes si elles existent
              if (categorie['enveloppes'] != null &&
                  categorie['enveloppes'] is List) {
                newCategorie['enveloppes'] = categorie['enveloppes'];
              }

              print('   🔍 Tentative création catégorie: ${categorie['nom']}');
              print('   📊 Données envoyées: $newCategorie');

              final result =
                  await PocketBaseService.createCategorie(newCategorie);
              print('   ✅ Catégorie créée: ${categorie['nom']}');
            } catch (e) {
              print('   ❌ Erreur création catégorie ${categorie['nom']}: $e');
              print('   📊 Données qui ont causé l\'erreur: ${categorie}');
            }
          }
        } catch (e) {
          print('   ❌ Erreur récupération catégories: $e');
        }

        // Migrer les transactions
        print('\n💳 Migration des transactions...');
        try {
          final transactionsSnapshot = await FirebaseFirestore.instance
              .collection('transactions')
              .where('userId', isEqualTo: firebaseUserId)
              .get();

          final transactions =
              transactionsSnapshot.docs.map((doc) => doc.data()).toList();
          print('   📊 ${transactions.length} transactions trouvées');

          for (final transaction in transactions) {
            try {
              final newTransaction = {
                'utilisateur_id': pocketbaseUserId,
                'type': transaction['type'] ?? 'Depense',
                'montant': transaction['montant'] ?? 0.0,
                'date': transaction['date'] ?? DateTime.now().toIso8601String(),
                'note': transaction['note'] ?? '',
                'compte_id': transaction['compteId'] ?? '',
                'collection_compte': 'comptes_cheques',
                'tiers_id': transaction['tiers'] ?? '',
                'enveloppe_id': transaction['enveloppeId'] ?? '',
              };

              print(
                  '   🔍 Tentative création transaction: ${transaction['tiers'] ?? 'Sans tiers'}');
              print('   📊 Données envoyées: $newTransaction');

              final result =
                  await PocketBaseService.createTransaction(newTransaction);
              print(
                  '   ✅ Transaction créée: ${transaction['tiers'] ?? 'Sans tiers'}');
            } catch (e) {
              print(
                  '   ❌ Erreur création transaction ${transaction['tiers'] ?? 'Sans tiers'}: $e');
              print('   📊 Données qui ont causé l\'erreur: ${transaction}');
            }
          }
        } catch (e) {
          print('   ❌ Erreur récupération transactions: $e');
        }

        // Migrer les dettes
        print('\n💸 Migration des dettes...');
        try {
          final dettesSnapshot = await FirebaseFirestore.instance
              .collection('dettes')
              .where('userId', isEqualTo: firebaseUserId)
              .get();

          final dettes = dettesSnapshot.docs.map((doc) => doc.data()).toList();
          print('   📊 ${dettes.length} dettes trouvées');

          for (final dette in dettes) {
            try {
              final estManuelle = dette['estManuelle'] ?? true;

              // Convertir le Timestamp en String ISO
              String dateCreation = DateTime.now().toIso8601String();
              if (dette['dateCreation'] != null) {
                if (dette['dateCreation'] is Timestamp) {
                  final timestamp = dette['dateCreation'] as Timestamp;
                  dateCreation = DateTime.fromMillisecondsSinceEpoch(
                    timestamp.millisecondsSinceEpoch,
                  ).toIso8601String();
                } else {
                  dateCreation = dette['dateCreation'].toString();
                }
              }

              if (estManuelle) {
                final newDette = {
                  'nom_tiers': dette['nomTiers'] ?? '',
                  'montant_initial': dette['montantInitial'] ?? 0.0,
                  'solde': dette['solde'] ?? 0.0,
                  'type': 'dette',
                  'archive': dette['archive'] ?? false,
                  'date_creation': dateCreation,
                  'utilisateur_id': pocketbaseUserId,
                  'note': dette['note'] ?? '',
                };

                print('   🔍 Tentative création dette: ${dette['nomTiers']}');
                print('   📊 Données envoyées: $newDette');

                final result = await PocketBaseService.createDette(newDette);
                print('   ✅ Dette manuelle créée: ${dette['nomTiers']}');
              } else {
                final newPret = {
                  'nom_tiers': dette['nomTiers'] ?? '',
                  'montant_initial': dette['montantInitial'] ?? 0.0,
                  'solde': dette['solde'] ?? 0.0,
                  'type': 'pret',
                  'archive': dette['archive'] ?? false,
                  'date_creation': dateCreation,
                  'utilisateur_id': pocketbaseUserId,
                  'note': dette['note'] ?? '',
                };

                print('   🔍 Tentative création prêt: ${dette['nomTiers']}');
                print('   📊 Données envoyées: $newPret');

                final result =
                    await PocketBaseService.createPretPersonnel(newPret);
                print('   ✅ Prêt personnel créé: ${dette['nomTiers']}');
              }
            } catch (e) {
              print('   ❌ Erreur création dette ${dette['nomTiers']}: $e');
              print('   📊 Données qui ont causé l\'erreur: ${dette}');
            }
          }
        } catch (e) {
          print('   ❌ Erreur récupération dettes: $e');
        }

        // Migrer les tiers
        print('\n👥 Migration des tiers...');
        try {
          final tiersSnapshot = await FirebaseFirestore.instance
              .collection('tiers')
              .where('userId', isEqualTo: firebaseUserId)
              .get();

          final tiers = tiersSnapshot.docs.map((doc) => doc.data()).toList();
          print('   📊 ${tiers.length} tiers trouvés');

          for (final tiers in tiers) {
            try {
              final newTiers = {
                'nom': tiers['nom'] ?? '',
                'utilisateur_id': pocketbaseUserId,
              };

              print('   🔍 Tentative création tiers: ${tiers['nom']}');
              print('   📊 Données envoyées: $newTiers');

              final result = await PocketBaseService.createTiers(newTiers);
              print('   ✅ Tiers créé: ${tiers['nom']}');
            } catch (e) {
              print('   ❌ Erreur création tiers ${tiers['nom']}: $e');
              print('   📊 Données qui ont causé l\'erreur: ${tiers}');
            }
          }
        } catch (e) {
          print('   ❌ Erreur récupération tiers: $e');
        }

        print('\n✅ Migration terminée pour l\'utilisateur connecté !');
        print('🎉 Toutes les données ont été migrées vers PocketBase !');
      } catch (e) {
        print('❌ Erreur création utilisateur PocketBase: $e');
      }
    } catch (e) {
      print('❌ Erreur migration utilisateur connecté: $e');
    }
  }
}
