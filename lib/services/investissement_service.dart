import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/action_investissement.dart';
import 'firebase_service.dart';

class InvestissementService {
  // TODO: Remplace par ta clé API FinancialModelingPrep
  // Obtenir gratuitement sur https://financialmodelingprep.com/
  // Gratuit : 250 requêtes/jour
  static const String _apiKey = 'aMnielp03sER1Gfj0pYvYyQuOlPjMFTg';
  static const String _baseUrl = 'https://financialmodelingprep.com/api/v3';

  final FirebaseService _firebaseService = FirebaseService();

  // Charger les données d'un compte d'investissement
  Future<Map<String, dynamic>> chargerDonneesCompte(String compteId) async {
    try {
      print('📂 Chargement des données pour le compte: $compteId');

      // Récupérer les actions depuis Firebase
      final actionsSnapshot = await _firebaseService.firestore
          .collection('investissements')
          .doc(compteId)
          .collection('actions')
          .get();

      print('📊 ${actionsSnapshot.docs.length} actions trouvées dans Firebase');

      List<ActionInvestissement> actions = [];
      double cashDisponible = 0.0;
      double valeurTotale = 0.0;
      double dernierChangement = 0.0;

      // Charger le cash disponible
      final cashDoc = await _firebaseService.firestore
          .collection('investissements')
          .doc(compteId)
          .collection('cash')
          .doc('disponible')
          .get();

      if (cashDoc.exists) {
        cashDisponible = (cashDoc.data()?['montant'] ?? 0.0).toDouble();
        valeurTotale += cashDisponible;
      }

      // Traiter chaque action
      for (var doc in actionsSnapshot.docs) {
        print('📋 Traitement de l\'action: ${doc.id}');
        print('📋 Données Firebase: ${doc.data()}');

        final action = ActionInvestissement.fromMap({
          'id': doc.id,
          ...doc.data(),
        });

        print(
            '✅ Action créée: ${action.symbole} - ${action.nombre} actions à ${action.prixMoyen.toStringAsFixed(2)}\$');

        // Mettre à jour le prix actuel depuis l'API
        final prixActuel = await _obtenirPrixActuel(action.symbole);
        if (prixActuel > 0) {
          final nouvelleValeur = action.nombre * prixActuel;
          final ancienneValeur = action.valeurActuelle;
          final variation = prixActuel > 0
              ? ((prixActuel - action.prixMoyen) / action.prixMoyen) * 100
              : 0.0;

          final actionMiseAJour = action.copyWith(
            prixActuel: prixActuel,
            valeurActuelle: nouvelleValeur,
            variation: variation,
            dateDerniereMiseAJour: DateTime.now(),
          );

          // Sauvegarder la mise à jour
          await _firebaseService.firestore
              .collection('investissements')
              .doc(compteId)
              .collection('actions')
              .doc(action.id)
              .update(actionMiseAJour.toMap());

          actions.add(actionMiseAJour);
          valeurTotale += nouvelleValeur;
          dernierChangement += (nouvelleValeur - ancienneValeur);
        } else {
          actions.add(action);
          valeurTotale += action.valeurActuelle;
        }
      }

      print(
          '📈 Résumé: ${actions.length} actions, valeur totale: ${valeurTotale.toStringAsFixed(2)}\$');

      return {
        'actions': actions,
        'cash': cashDisponible,
        'valeurTotale': valeurTotale,
        'dernierChangement': dernierChangement,
      };
    } catch (e) {
      print('❌ Erreur lors du chargement: $e');
      throw Exception('Erreur lors du chargement des données: $e');
    }
  }

  // Charger l'historique pour le graphique
  Future<List<Map<String, double>>> chargerHistorique(String compteId) async {
    try {
      final historiqueSnapshot = await _firebaseService.firestore
          .collection('investissements')
          .doc(compteId)
          .collection('historique')
          .orderBy('date')
          .limit(30) // Derniers 30 jours
          .get();

      List<Map<String, double>> spots = [];
      int index = 0;

      for (var doc in historiqueSnapshot.docs) {
        final data = doc.data();
        final date = DateTime.parse(data['date']);
        final valeur = (data['valeur'] ?? 0.0).toDouble();

        spots.add({'x': index.toDouble(), 'y': valeur});
        index++;
      }

      return spots;
    } catch (e) {
      return [];
    }
  }

  // Ajouter une nouvelle transaction
  Future<void> ajouterTransaction({
    required String symbole,
    required int nombre,
    required double prix,
    required String compteId,
  }) async {
    try {
      print('🟣 [SERVICE] Ajout transaction dans le compte: $compteId');
      final transactionId = DateTime.now().millisecondsSinceEpoch.toString();
      final transaction = TransactionInvestissement(
        id: transactionId,
        type: 'achat',
        nombre: nombre,
        prix: prix,
        date: DateTime.now(),
      );

      // Vérifier si l'action existe déjà
      final actionDoc = await _firebaseService.firestore
          .collection('investissements')
          .doc(compteId)
          .collection('actions')
          .doc(symbole)
          .get();

      if (actionDoc.exists) {
        // Mettre à jour l'action existante
        final actionExistante = ActionInvestissement.fromMap({
          'id': actionDoc.id,
          ...actionDoc.data()!,
        });

        final nouveauNombre = actionExistante.nombre + nombre;
        final nouveauPrixMoyen =
            ((actionExistante.prixMoyen * actionExistante.nombre) +
                    (prix * nombre)) /
                nouveauNombre;
        final nouvellesTransactions = [
          ...actionExistante.transactions,
          transaction
        ];

        final actionMiseAJour = actionExistante.copyWith(
          nombre: nouveauNombre,
          prixMoyen: nouveauPrixMoyen,
          transactions: nouvellesTransactions,
        );

        await _firebaseService.firestore
            .collection('investissements')
            .doc(compteId)
            .collection('actions')
            .doc(symbole)
            .update(actionMiseAJour.toMap());
      } else {
        // Créer une nouvelle action
        final nouvelleAction = ActionInvestissement(
          id: symbole,
          symbole: symbole,
          nombre: nombre,
          prixMoyen: prix,
          prixActuel: prix,
          valeurActuelle: nombre * prix,
          variation: 0.0,
          dateDerniereMiseAJour: DateTime.now(),
          transactions: [transaction],
        );

        await _firebaseService.firestore
            .collection('investissements')
            .doc(compteId)
            .collection('actions')
            .doc(symbole)
            .set(nouvelleAction.toMap());
      }

      // Ajouter à l'historique
      await _ajouterHistorique(compteId);
    } catch (e) {
      throw Exception('Erreur lors de l\'ajout de la transaction: $e');
    }
  }

  // Obtenir le prix actuel d'une action via l'API
  Future<double> _obtenirPrixActuel(String symbole) async {
    // Vérifier si l'API est configurée
    if (_apiKey == 'YOUR_FINANCIAL_MODELING_PREP_API_KEY') {
      print('⚠️ API non configurée. Utilise le prix stocké pour $symbole');
      return 0.0; // Retourner 0 pour utiliser le prix stocké
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/quote/$symbole?apikey=$_apiKey'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List && data.isNotEmpty) {
          return (data[0]['price'] ?? 0.0).toDouble();
        }
      } else if (response.statusCode == 401) {
        print('❌ Clé API invalide pour FinancialModelingPrep');
      } else if (response.statusCode == 429) {
        print('⚠️ Limite de requêtes API atteinte (250/jour)');
      }
      return 0.0;
    } catch (e) {
      print('Erreur API pour $symbole: $e');
      return 0.0;
    }
  }

  // Ajouter une entrée à l'historique
  Future<void> _ajouterHistorique(String compteId) async {
    try {
      final donnees = await chargerDonneesCompte(compteId);
      final valeurTotale = donnees['valeurTotale'] ?? 0.0;

      await _firebaseService.firestore
          .collection('investissements')
          .doc(compteId)
          .collection('historique')
          .add({
        'date': DateTime.now().toIso8601String(),
        'valeur': valeurTotale,
      });
    } catch (e) {
      print('Erreur lors de l\'ajout à l\'historique: $e');
    }
  }

  // Mettre à jour tous les prix (pour les mises à jour automatiques)
  Future<void> mettreAJourPrix(String compteId) async {
    try {
      final actionsSnapshot = await _firebaseService.firestore
          .collection('investissements')
          .doc(compteId)
          .collection('actions')
          .get();

      for (var doc in actionsSnapshot.docs) {
        final action = ActionInvestissement.fromMap({
          'id': doc.id,
          ...doc.data(),
        });

        final prixActuel = await _obtenirPrixActuel(action.symbole);
        if (prixActuel > 0) {
          final nouvelleValeur = action.nombre * prixActuel;
          final variation = prixActuel > 0
              ? ((prixActuel - action.prixMoyen) / action.prixMoyen) * 100
              : 0.0;

          final actionMiseAJour = action.copyWith(
            prixActuel: prixActuel,
            valeurActuelle: nouvelleValeur,
            variation: variation,
            dateDerniereMiseAJour: DateTime.now(),
          );

          await _firebaseService.firestore
              .collection('investissements')
              .doc(compteId)
              .collection('actions')
              .doc(action.id)
              .update(actionMiseAJour.toMap());
        }
      }

      // Ajouter à l'historique après mise à jour
      await _ajouterHistorique(compteId);
    } catch (e) {
      throw Exception('Erreur lors de la mise à jour des prix: $e');
    }
  }

  // Mise à jour batch de tous les prix d'actions du compte
  Future<void> batchUpdatePrix(String compteId) async {
    try {
      print('🔄 Début batch update pour le compte: $compteId');

      final actionsSnapshot = await _firebaseService.firestore
          .collection('investissements')
          .doc(compteId)
          .collection('actions')
          .get();

      if (actionsSnapshot.docs.isEmpty) {
        print('ℹ️ Aucune action trouvée pour le batch update');
        return;
      }

      final symboles = actionsSnapshot.docs.map((doc) => doc.id).toList();
      print('📊 Actions à mettre à jour: ${symboles.join(', ')}');

      // Requête batch pour TOUTES les actions en une fois
      final joined = symboles.join(',');
      final url = '$_baseUrl/quote/$joined?apikey=$_apiKey';
      print('🌐 URL batch request: $url');

      final response = await http.get(Uri.parse(url));
      print('📡 Réponse API: ${response.statusCode}');

      Map<String, double> prixMap = {};
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List) {
          print('✅ ${data.length} prix reçus de l\'API');
          for (var item in data) {
            final symbole = item['symbol'];
            final prix = (item['price'] ?? 0.0).toDouble();
            prixMap[symbole] = prix;
            print('💰 $symbole: ${prix.toStringAsFixed(2)}\$');
          }
        }
      } else {
        print('❌ Erreur API: ${response.statusCode} - ${response.body}');
        return;
      }

      // Mise à jour de toutes les actions avec les nouveaux prix
      double valeurTotale = 0.0;
      int actionsMiseAJour = 0;

      for (var doc in actionsSnapshot.docs) {
        final action = ActionInvestissement.fromMap({
          'id': doc.id,
          ...doc.data(),
        });

        final prixActuel = prixMap[action.symbole] ?? action.prixActuel;
        if (prixActuel > 0) {
          final nouvelleValeur = action.nombre * prixActuel;
          final variation = action.prixMoyen > 0
              ? ((prixActuel - action.prixMoyen) / action.prixMoyen) * 100
              : 0.0;

          final actionMiseAJour = action.copyWith(
            prixActuel: prixActuel,
            valeurActuelle: nouvelleValeur,
            variation: variation,
            dateDerniereMiseAJour: DateTime.now(),
          );

          await _firebaseService.firestore
              .collection('investissements')
              .doc(compteId)
              .collection('actions')
              .doc(action.id)
              .update(actionMiseAJour.toMap());

          valeurTotale += nouvelleValeur;
          actionsMiseAJour++;
        } else {
          valeurTotale += action.valeurActuelle;
        }
      }

      // Ajouter le cash disponible
      final cashDoc = await _firebaseService.firestore
          .collection('investissements')
          .doc(compteId)
          .collection('cash')
          .doc('disponible')
          .get();
      if (cashDoc.exists) {
        valeurTotale += (cashDoc.data()?['montant'] ?? 0.0).toDouble();
      }

      // Ajouter à l'historique
      await _firebaseService.firestore
          .collection('investissements')
          .doc(compteId)
          .collection('historique')
          .add({
        'date': DateTime.now().toIso8601String(),
        'valeur': valeurTotale,
      });

      print(
          '✅ Batch update terminé: $actionsMiseAJour actions mises à jour, valeur totale: ${valeurTotale.toStringAsFixed(2)}\$');
    } catch (e) {
      print('❌ Erreur batch update: $e');
      throw Exception('Erreur batch update: $e');
    }
  }

  // Calculer la performance globale du portefeuille
  Future<Map<String, dynamic>> calculerPerformanceGlobale(
      String compteId) async {
    try {
      final donnees = await chargerDonneesCompte(compteId);
      final actions = donnees['actions'] ?? [];
      final cash = donnees['cash'] ?? 0.0;

      double valeurTotaleActuelle = cash;
      double valeurTotaleInvestie = cash;
      double gainPerteTotal = 0.0;

      for (var action in actions) {
        valeurTotaleActuelle += action.valeurActuelle;
        valeurTotaleInvestie += action.nombre * action.prixMoyen;
        gainPerteTotal +=
            (action.valeurActuelle - (action.nombre * action.prixMoyen));
      }

      double performancePourcentage = 0.0;
      if (valeurTotaleInvestie > 0) {
        performancePourcentage =
            ((valeurTotaleActuelle - valeurTotaleInvestie) /
                    valeurTotaleInvestie) *
                100;
      }

      return {
        'valeurActuelle': valeurTotaleActuelle,
        'valeurInvestie': valeurTotaleInvestie,
        'gainPerte': gainPerteTotal,
        'performancePourcentage': performancePourcentage,
        'cash': cash,
      };
    } catch (e) {
      return {
        'valeurActuelle': 0.0,
        'valeurInvestie': 0.0,
        'gainPerte': 0.0,
        'performancePourcentage': 0.0,
        'cash': 0.0,
      };
    }
  }

  // Calculer la performance d'une action spécifique
  Map<String, dynamic> calculerPerformanceAction(ActionInvestissement action) {
    final valeurInvestie = action.nombre * action.prixMoyen;
    final gainPerte = action.valeurActuelle - valeurInvestie;
    final performancePourcentage = action.prixMoyen > 0
        ? ((action.prixActuel - action.prixMoyen) / action.prixMoyen) * 100
        : 0.0;

    return {
      'valeurInvestie': valeurInvestie,
      'gainPerte': gainPerte,
      'performancePourcentage': performancePourcentage,
      'prixMoyen': action.prixMoyen,
      'prixActuel': action.prixActuel,
    };
  }

  Future<void> supprimerAction(String compteId, String symbole) async {
    try {
      print('🗑️ Suppression de l\'action $symbole du compte $compteId');
      await _firebaseService.firestore
          .collection('investissements')
          .doc(compteId)
          .collection('actions')
          .doc(symbole)
          .delete();
    } catch (e) {
      print('❌ Erreur lors de la suppression de l\'action: $e');
      rethrow;
    }
  }
}
