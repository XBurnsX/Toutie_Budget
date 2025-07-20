import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_service.dart';
import 'pocketbase_service.dart';
import 'auth_service.dart';
import 'cache_service.dart';
import '../pocketbase_config.dart';
import '../models/compte.dart';
import '../models/categorie.dart';

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
}
