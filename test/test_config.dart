import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:mockito/mockito.dart';

/// Configuration Firebase pour les tests
class FirebaseTestConfig {
  static Future<void> setupFirebaseForTesting() async {
    // Configuration mock pour Firebase
    TestWidgetsFlutterBinding.ensureInitialized();

    // Initialiser Firebase avec une configuration de test
    await Firebase.initializeApp();
  }
}

/// Configuration globale pour les tests
class TestConfig {
  // Données de test pour les comptes
  static final List<Map<String, dynamic>> testComptes = [
    {
      'id': 'compte_principal',
      'nom': 'Compte Principal',
      'type': 'Chèque',
      'solde': 2000.0,
      'couleur': 0xFF2196F3,
      'pretAPlacer': 1000.0,
    },
    {
      'id': 'compte_epargne',
      'nom': 'Épargne',
      'type': 'Épargne',
      'solde': 5000.0,
      'couleur': 0xFF4CAF50,
      'pretAPlacer': 2000.0,
    },
    {
      'id': 'compte_carte',
      'nom': 'Carte de crédit',
      'type': 'Carte de crédit',
      'solde': -500.0,
      'couleur': 0xFFE53935,
      'pretAPlacer': 0.0,
    },
  ];

  // Données de test pour les catégories
  static final List<Map<String, dynamic>> testCategories = [
    {
      'id': 'cat_essentiels',
      'nom': 'Essentiels',
      'enveloppes': [
        {
          'id': 'env_epicerie',
          'nom': 'Épicerie',
          'solde': 400.0,
          'objectif': 500.0,
          'depense': 100.0,
          'archivee': false,
        },
        {
          'id': 'env_transport',
          'nom': 'Transport',
          'solde': 200.0,
          'objectif': 300.0,
          'depense': 50.0,
          'archivee': false,
        },
      ],
    },
    {
      'id': 'cat_loisirs',
      'nom': 'Loisirs',
      'enveloppes': [
        {
          'id': 'env_restaurant',
          'nom': 'Restaurant',
          'solde': 150.0,
          'objectif': 200.0,
          'depense': 75.0,
          'archivee': false,
        },
        {
          'id': 'env_vacances',
          'nom': 'Vacances',
          'solde': 800.0,
          'objectif': 2000.0,
          'depense': 0.0,
          'archivee': false,
        },
      ],
    },
  ];

  // Données de test pour les transactions
  static final List<Map<String, dynamic>> testTransactions = [
    {
      'id': 'trans_1',
      'type': 'depense',
      'typeMouvement': 'depenseNormale',
      'montant': 85.50,
      'tiers': 'Super U',
      'compteId': 'compte_principal',
      'enveloppeId': 'env_epicerie',
      'estFractionnee': false,
    },
    {
      'id': 'trans_2',
      'type': 'revenu',
      'typeMouvement': 'revenuNormal',
      'montant': 2500.0,
      'tiers': 'Salaire',
      'compteId': 'compte_principal',
      'estFractionnee': false,
    },
  ];

  // Données de test pour les dettes
  static final List<Map<String, dynamic>> testDettes = [
    {
      'id': 'dette_1',
      'nomTiers': 'Papa',
      'montantInitial': 1000.0,
      'solde': 800.0,
      'type': 'pret',
      'archive': false,
    },
    {
      'id': 'dette_2',
      'nomTiers': 'Banque',
      'montantInitial': 5000.0,
      'solde': 4500.0,
      'type': 'dette',
      'archive': false,
    },
  ];

  // Constantes de test
  static const String testUserId = 'user_test_123';
  static const String testMonthKey = '2025-01';
  static const double testMontant = 100.0;
  static const String testTiers = 'Test Tiers';

  // Méthodes utilitaires pour les tests
  static Map<String, dynamic> createTestCompte({
    String? id,
    String? nom,
    String? type,
    double? solde,
    int? couleur,
    double? pretAPlacer,
  }) {
    return {
      'id': id ?? 'compte_test',
      'nom': nom ?? 'Compte Test',
      'type': type ?? 'Chèque',
      'solde': solde ?? 1000.0,
      'couleur': couleur ?? 0xFF2196F3,
      'pretAPlacer': pretAPlacer ?? 500.0,
    };
  }

  static Map<String, dynamic> createTestEnveloppe({
    String? id,
    String? nom,
    double? solde,
    double? objectif,
    double? depense,
    bool? archivee,
  }) {
    return {
      'id': id ?? 'env_test',
      'nom': nom ?? 'Enveloppe Test',
      'solde': solde ?? 100.0,
      'objectif': objectif ?? 200.0,
      'depense': depense ?? 0.0,
      'archivee': archivee ?? false,
    };
  }

  static Map<String, dynamic> createTestTransaction({
    String? id,
    String? type,
    String? typeMouvement,
    double? montant,
    String? tiers,
    String? compteId,
    String? enveloppeId,
    bool? estFractionnee,
  }) {
    return {
      'id': id ?? 'trans_test',
      'type': type ?? 'depense',
      'typeMouvement': typeMouvement ?? 'depenseNormale',
      'montant': montant ?? 50.0,
      'tiers': tiers ?? 'Test Tiers',
      'compteId': compteId ?? 'compte_principal',
      'enveloppeId': enveloppeId,
      'estFractionnee': estFractionnee ?? false,
    };
  }

  // Méthodes de validation pour les tests
  static bool isValidCompte(Map<String, dynamic> compte) {
    return compte.containsKey('id') &&
        compte.containsKey('nom') &&
        compte.containsKey('type') &&
        compte.containsKey('solde') &&
        compte.containsKey('couleur') &&
        compte.containsKey('pretAPlacer');
  }

  static bool isValidEnveloppe(Map<String, dynamic> enveloppe) {
    return enveloppe.containsKey('id') &&
        enveloppe.containsKey('nom') &&
        enveloppe.containsKey('solde') &&
        enveloppe.containsKey('objectif') &&
        enveloppe.containsKey('depense') &&
        enveloppe.containsKey('archivee');
  }

  static bool isValidTransaction(Map<String, dynamic> transaction) {
    return transaction.containsKey('id') &&
        transaction.containsKey('type') &&
        transaction.containsKey('typeMouvement') &&
        transaction.containsKey('montant') &&
        transaction.containsKey('tiers') &&
        transaction.containsKey('compteId') &&
        transaction.containsKey('estFractionnee');
  }

  // Méthodes de calcul pour les tests
  static double calculateTotalSolde(List<Map<String, dynamic>> comptes) {
    return comptes.fold(
      0.0,
      (sum, compte) => sum + (compte['solde'] as double),
    );
  }

  static double calculateTotalObjectifs(List<Map<String, dynamic>> categories) {
    return categories.fold(0.0, (sum, cat) {
      final enveloppes = cat['enveloppes'] as List<dynamic>;
      return sum +
          enveloppes.fold(
            0.0,
            (sumEnv, env) => sumEnv + (env['objectif'] as double),
          );
    });
  }

  static double calculateTotalSoldes(List<Map<String, dynamic>> categories) {
    return categories.fold(0.0, (sum, cat) {
      final enveloppes = cat['enveloppes'] as List<dynamic>;
      return sum +
          enveloppes.fold(
            0.0,
            (sumEnv, env) => sumEnv + (env['solde'] as double),
          );
    });
  }
}

/// Extensions pour faciliter les tests
extension TestExtensions on WidgetTester {
  /// Attendre que l'animation soit terminée
  Future<void> waitForAnimation() async {
    await pumpAndSettle();
  }

  /// Taper sur un widget avec un délai
  Future<void> tapWithDelay(Finder finder, {Duration? delay}) async {
    await tap(finder);
    if (delay != null) {
      await Future.delayed(delay);
    }
    await pump();
  }

  /// Entrer du texte avec un délai
  Future<void> enterTextWithDelay(
    Finder finder,
    String text, {
    Duration? delay,
  }) async {
    await enterText(finder, text);
    if (delay != null) {
      await Future.delayed(delay);
    }
    await pump();
  }
}
