import '../models/transaction_model.dart' as app_model;
import 'alpha_vantage_service.dart';
import 'firebase_service.dart';
import 'package:intl/intl.dart';

class InvestissementService {
  final FirebaseService _firebaseService = FirebaseService();
  final AlphaVantageService _alphaVantage = AlphaVantageService();

  // Singleton pattern
  static final InvestissementService _instance =
      InvestissementService._internal();
  factory InvestissementService() => _instance;
  InvestissementService._internal();

  // Démarrer le service d'investissement
  void startService() {
    _alphaVantage.startBatchUpdate();
    print('🚀 Service d\'investissement démarré');
  }

  // Arrêter le service
  void stopService() {
    _alphaVantage.stopBatchUpdate();
    print('⏹️ Service d\'investissement arrêté');
  }

  // Ajouter une action à un compte
  Future<void> ajouterAction({
    required String compteId,
    required String symbol,
    required double quantite,
    required double prixAchat,
    required DateTime dateAchat,
  }) async {
    try {
      // Créer la transaction d'achat
      final transaction = app_model.Transaction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: app_model.TypeTransaction.depense,
        typeMouvement: app_model.TypeMouvementFinancier.depenseNormale,
        montant: -(quantite * prixAchat), // Montant négatif pour un achat
        compteId: compteId,
        date: dateAchat,
        tiers: symbol,
        enveloppeId: null,
        note:
            'Action: $symbol - Quantité: $quantite - Prix: \$${prixAchat.toStringAsFixed(2)}',
      );

      // Sauvegarder la transaction
      await _firebaseService.ajouterTransaction(transaction);

      // Déduire le montant du cash disponible (pretAPlacer)
      final compteDoc = await _firebaseService.firestore
          .collection('comptes')
          .doc(compteId)
          .get();
      if (!compteDoc.exists) throw Exception('Compte non trouvé');
      final compteData = compteDoc.data()!;
      final pretAPlacer = (compteData['pretAPlacer'] ?? 0).toDouble();
      final nouveauPretAPlacer = pretAPlacer - (quantite * prixAchat);
      await _firebaseService.firestore
          .collection('comptes')
          .doc(compteId)
          .update({
        'pretAPlacer': nouveauPretAPlacer,
      });

      // Sauvegarder les détails de l'action
      await _firebaseService.firestore.collection('actions').add({
        'compteId': compteId,
        'symbol': symbol,
        'quantite': quantite,
        'prixAchat': prixAchat,
        'dateAchat': dateAchat.toIso8601String(),
        'dateCreation': DateTime.now().toIso8601String(),
      });

      // Ajouter le symbole à la queue de mise à jour Alpha Vantage
      _alphaVantage.addSymbolToQueue(symbol);

      print('✅ Action $symbol ajoutée au compte $compteId');
    } catch (e) {
      print('❌ Erreur ajout action: $e');
      rethrow;
    }
  }

  // Supprimer une action
  Future<void> supprimerAction({
    required String actionId,
    required String compteId,
    required double quantite,
    required double prixVente,
    required DateTime dateVente,
    required double quantiteRestante,
  }) async {
    try {
      // Récupérer les détails de l'action
      final actionDoc = await _firebaseService.firestore
          .collection('actions')
          .doc(actionId)
          .get();
      if (!actionDoc.exists) {
        throw Exception('Action non trouvée');
      }

      final actionData = actionDoc.data()!;
      final symbol = actionData['symbol'] as String;
      final prixAchat = (actionData['prixAchat'] as num).toDouble();

      // Créer la transaction de vente
      final transaction = app_model.Transaction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: app_model.TypeTransaction.revenu,
        typeMouvement: app_model.TypeMouvementFinancier.revenuNormal,
        montant: quantite * prixVente, // Montant positif pour une vente
        compteId: compteId,
        date: dateVente,
        tiers: symbol,
        enveloppeId: null,
        note:
            'Action: $symbol - Quantité: $quantite - Prix: \$${prixVente.toStringAsFixed(2)}',
      );

      // Sauvegarder la transaction
      await _firebaseService.ajouterTransaction(transaction);

      // Mettre à jour le cash disponible (pretAPlacer)
      final compteDoc = await _firebaseService.firestore
          .collection('comptes')
          .doc(compteId)
          .get();
      if (!compteDoc.exists) throw Exception('Compte non trouvé');
      final compteData = compteDoc.data()!;
      final pretAPlacer = (compteData['pretAPlacer'] ?? 0).toDouble();
      final nouveauPretAPlacer = pretAPlacer + (quantite * prixVente);
      await _firebaseService.firestore
          .collection('comptes')
          .doc(compteId)
          .update({
        'pretAPlacer': nouveauPretAPlacer,
      });

      if (quantiteRestante > 0) {
        // Vente partielle : mettre à jour la quantité
        await _firebaseService.firestore
            .collection('actions')
            .doc(actionId)
            .update({
          'quantite': quantiteRestante,
        });
      } else {
        // Vente totale : supprimer l'action
        await _firebaseService.firestore
            .collection('actions')
            .doc(actionId)
            .delete();
      }

      print(
          '✅ Action $symbol vendue ($quantite/$quantiteRestante) du compte $compteId');
    } catch (e) {
      print('❌ Erreur suppression action: $e');
      rethrow;
    }
  }

  // Récupérer toutes les actions d'un compte
  Future<List<Map<String, dynamic>>> getActions(String compteId) async {
    try {
      final querySnapshot = await _firebaseService.firestore
          .collection('actions')
          .where('compteId', isEqualTo: compteId)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('❌ Erreur récupération actions: $e');
      return [];
    }
  }

  // Calculer la performance d'une action
  Future<Map<String, dynamic>> calculerPerformanceAction(
      String symbol, double quantite, double prixAchat) async {
    try {
      // Récupérer le prix actuel
      final prixActuel = await _alphaVantage.getCurrentPrice(symbol);

      if (prixActuel == null) {
        return {
          'valeurActuelle': 0.0,
          'gainPerte': 0.0,
          'performance': 0.0,
          'prixActuel': null,
          'prixDisponible': false,
        };
      }

      final valeurActuelle = quantite * prixActuel;
      final valeurAchat = quantite * prixAchat;
      final gainPerte = valeurActuelle - valeurAchat;
      final performance =
          prixAchat > 0 ? ((prixActuel - prixAchat) / prixAchat) * 100 : 0.0;

      return {
        'valeurActuelle': valeurActuelle,
        'gainPerte': gainPerte,
        'performance': performance,
        'prixActuel': prixActuel,
        'prixDisponible': true,
      };
    } catch (e) {
      print('❌ Erreur calcul performance $symbol: $e');
      return {
        'valeurActuelle': 0.0,
        'gainPerte': 0.0,
        'performance': 0.0,
        'prixActuel': null,
        'prixDisponible': false,
      };
    }
  }

  // Calculer la performance globale d'un compte
  Future<Map<String, dynamic>> calculerPerformanceCompte(
      String compteId) async {
    try {
      final actions = await getActions(compteId);

      double totalValeurAchat = 0.0;
      double totalValeurActuelle = 0.0;
      double totalGainPerte = 0.0;
      int actionsAvecPrix = 0;

      for (final action in actions) {
        final symbol = action['symbol'] as String;
        final quantite = (action['quantite'] as num).toDouble();
        final prixAchat = (action['prixAchat'] as num).toDouble();

        final performance =
            await calculerPerformanceAction(symbol, quantite, prixAchat);

        totalValeurAchat += quantite * prixAchat;

        if (performance['prixDisponible'] == true) {
          totalValeurActuelle += performance['valeurActuelle'];
          totalGainPerte += performance['gainPerte'];
          actionsAvecPrix++;
        }
      }

      final performanceGlobale = totalValeurAchat > 0
          ? (totalGainPerte / totalValeurAchat) * 100
          : 0.0;

      return {
        'totalValeurAchat': totalValeurAchat,
        'totalValeurActuelle': totalValeurActuelle,
        'totalGainPerte': totalGainPerte,
        'performanceGlobale': performanceGlobale,
        'nombreActions': actions.length,
        'actionsAvecPrix': actionsAvecPrix,
      };
    } catch (e) {
      print('❌ Erreur calcul performance compte: $e');
      return {
        'totalValeurAchat': 0.0,
        'totalValeurActuelle': 0.0,
        'totalGainPerte': 0.0,
        'performanceGlobale': 0.0,
        'nombreActions': 0,
        'actionsAvecPrix': 0,
      };
    }
  }

  // Forcer une mise à jour des prix
  Future<void> forcerMiseAJour() async {
    await _alphaVantage.forceUpdate();
  }

  // Obtenir les statistiques du service
  Map<String, dynamic> getStats() {
    return _alphaVantage.getStats();
  }

  // Obtenir le temps jusqu'à la prochaine mise à jour
  String getNextUpdateTime() {
    return _alphaVantage.getNextUpdateTime();
  }

  // Récupérer l'historique des prix d'une action
  Future<List<Map<String, dynamic>>> getHistoriquePrix(String symbol,
      {int limit = 30}) async {
    try {
      final querySnapshot = await _firebaseService.firestore
          .collection('historique_prix')
          .where('symbol', isEqualTo: symbol)
          .orderBy('date', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'prix': (data['prix'] as num).toDouble(),
          'date': DateTime.parse(data['date']),
          'source': data['source'],
        };
      }).toList();
    } catch (e) {
      print('❌ Erreur récupération historique prix $symbol: $e');
      return [];
    }
  }

  // Ajouter des actions de test pour le développement
  Future<void> ajouterActionsTest(String compteId) async {
    final actionsTest = [
      {'symbol': 'AAPL', 'quantite': 10, 'prixAchat': 150.0},
      {'symbol': 'MSFT', 'quantite': 5, 'prixAchat': 300.0},
      {'symbol': 'GOOGL', 'quantite': 2, 'prixAchat': 2500.0},
      {'symbol': 'TSLA', 'quantite': 3, 'prixAchat': 800.0},
      {'symbol': 'RY.TO', 'quantite': 20, 'prixAchat': 120.0},
    ];

    for (final action in actionsTest) {
      await ajouterAction(
        compteId: compteId,
        symbol: action['symbol'] as String,
        quantite: (action['quantite'] as num).toDouble(),
        prixAchat: (action['prixAchat'] as num).toDouble(),
        dateAchat: DateTime.now().subtract(Duration(days: 30)),
      );
    }

    print('✅ Actions de test ajoutées');
  }

  // Ajouter un dividende à un compte d'investissement
  Future<void> ajouterDividende({
    required String compteId,
    required String symbol,
    required double montant,
    required DateTime date,
  }) async {
    try {
      // Créer la transaction de dividende
      final transaction = app_model.Transaction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: app_model.TypeTransaction.revenu,
        typeMouvement: app_model.TypeMouvementFinancier.revenuNormal,
        montant: montant, // Montant positif
        compteId: compteId,
        date: date,
        tiers: symbol,
        enveloppeId: null,
        note: 'Dividende reçu sur $symbol',
      );

      // Sauvegarder la transaction
      await _firebaseService.ajouterTransaction(transaction);

      // Ajouter le montant au cash disponible (pretAPlacer)
      final compteDoc = await _firebaseService.firestore
          .collection('comptes')
          .doc(compteId)
          .get();
      if (!compteDoc.exists) throw Exception('Compte non trouvé');
      final compteData = compteDoc.data()!;
      final pretAPlacer = (compteData['pretAPlacer'] ?? 0).toDouble();
      final nouveauPretAPlacer = pretAPlacer + montant;
      await _firebaseService.firestore
          .collection('comptes')
          .doc(compteId)
          .update({
        'pretAPlacer': nouveauPretAPlacer,
      });

      print('✅ Dividende $montant ajouté au cash du compte $compteId');
    } catch (e) {
      print('❌ Erreur ajout dividende: $e');
      rethrow;
    }
  }

  // Sauvegarder un snapshot journalier du portefeuille
  Future<void> sauvegarderSnapshotJournalier(String compteId) async {
    final aujourdhui = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // 1. Vérifier si un snapshot a déjà été sauvegardé aujourd'hui
    final snapshotExiste = await _firebaseService.firestore
        .collection('historique_portefeuille')
        .where('compteId', isEqualTo: compteId)
        .where('date', isEqualTo: aujourdhui)
        .limit(1)
        .get();

    // Si rien n'a été sauvegardé aujourd'hui, on le fait
    if (snapshotExiste.docs.isEmpty) {
      // 2. Calculer la valeur totale actuelle
      final performance = await calculerPerformanceCompte(compteId);

      // Il faut récupérer le compte pour avoir le cash.
      final compteDoc = await _firebaseService.firestore
          .collection('comptes')
          .doc(compteId)
          .get();
      final pretAPlacer =
          compteDoc.exists ? (compteDoc.data()?['pretAPlacer'] ?? 0.0) : 0.0;

      final valeurTotale =
          (performance['totalValeurActuelle'] ?? 0.0) + pretAPlacer;

      // 3. Sauvegarder le snapshot dans Firestore
      if (valeurTotale > 0) {
        await _firebaseService.firestore
            .collection('historique_portefeuille')
            .add({
          'compteId': compteId,
          'date': aujourdhui,
          'valeur': valeurTotale,
        });
        print('📸 Snapshot du $aujourdhui sauvegardé ! Valeur: $valeurTotale');
      }
    }
  }
}
