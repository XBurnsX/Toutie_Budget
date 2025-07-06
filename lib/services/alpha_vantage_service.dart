import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AlphaVantageService {
  static const String API_KEY = 'BD4NV7ZVF2RBD59B';
  static const String BASE_URL = 'https://www.alphavantage.co/query';
  static const int MAX_REQUESTS_PER_DAY = 500;
  static const int BATCH_SIZE = 5; // 5 actions par batch
  static const int BATCH_INTERVAL =
      10 * 60 * 1000; // 10 minutes en millisecondes
  static const int DELAY_BETWEEN_REQUESTS =
      12; // 12 secondes entre chaque requête (5 req/min max)

  final List<String> _pendingSymbols = [];
  int _requestsToday = 0;
  DateTime _lastResetDate = DateTime.now();
  Timer? _batchTimer;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  DateTime? _lastBatchTime;

  // Singleton pattern
  static final AlphaVantageService _instance = AlphaVantageService._internal();
  factory AlphaVantageService() => _instance;
  AlphaVantageService._internal() {
    _loadPersistentStats();
  }

  Future<void> _loadPersistentStats() async {
    final prefs = await SharedPreferences.getInstance();
    _requestsToday = prefs.getInt('requestsToday') ?? 0;
    final lastReset = prefs.getString('lastResetDate');
    if (lastReset != null) {
      _lastResetDate = DateTime.parse(lastReset);
    }
    final lastBatch = prefs.getString('lastBatchTime');
    if (lastBatch != null) {
      _lastBatchTime = DateTime.parse(lastBatch);
    }
  }

  Future<void> _savePersistentStats() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('requestsToday', _requestsToday);
    await prefs.setString('lastResetDate', _lastResetDate.toIso8601String());
    if (_lastBatchTime != null) {
      await prefs.setString('lastBatchTime', _lastBatchTime!.toIso8601String());
    }
  }

  // Démarrer le batch update automatique
  void startBatchUpdate() {
    if (_batchTimer != null) {
      _batchTimer!.cancel();
    }

    _batchTimer = Timer.periodic(Duration(minutes: 10), (timer) async {
      await _processNextBatch();
    });

    print(
        '🔄 Batch update Alpha Vantage démarré (5 actions toutes les 10 min)');

    // Sauvegarder les métadonnées initiales
    _saveMetadataToFirestore();
  }

  // Arrêter le batch update
  void stopBatchUpdate() {
    _batchTimer?.cancel();
    _batchTimer = null;
    print('⏹️ Batch update Alpha Vantage arrêté');
  }

  // Ajouter une action à la queue de mise à jour
  void addSymbolToQueue(String symbol) {
    if (!_pendingSymbols.contains(symbol)) {
      _pendingSymbols.add(symbol);
      print(
          '📝 $symbol ajouté à la queue de mise à jour (${_pendingSymbols.length} en attente)');
    }
  }

  // Ajouter plusieurs actions à la queue
  void addSymbolsToQueue(List<String> symbols) {
    for (String symbol in symbols) {
      addSymbolToQueue(symbol);
    }
  }

  // Traiter le prochain batch
  Future<void> _processNextBatch() async {
    _resetDailyCounter();

    // Vérifier si on peut faire des requêtes
    if (_requestsToday >= MAX_REQUESTS_PER_DAY) {
      print(
          '⚠️ Limite quotidienne Alpha Vantage atteinte (500), pause jusqu\'à demain');
      return;
    }

    // Prendre les 5 prochaines actions
    final batch = _pendingSymbols.take(BATCH_SIZE).toList();
    if (batch.isEmpty) {
      print('ℹ️ Aucune action en attente de mise à jour');
      return;
    }

    print('🔄 Traitement du batch: ${batch.join(', ')}');

    // Traiter le batch
    for (String symbol in batch) {
      if (_requestsToday < MAX_REQUESTS_PER_DAY) {
        await _updatePrice(symbol);
        _requestsToday++;
        _pendingSymbols.remove(symbol);

        print('✅ Mise à jour $symbol ($_requestsToday/500 aujourd\'hui)');

        // Pause entre chaque requête pour respecter la limite de 5 req/min
        if (batch.indexOf(symbol) < batch.length - 1) {
          await Future.delayed(Duration(seconds: DELAY_BETWEEN_REQUESTS));
        }
      }
    }

    print('📊 Batch terminé. Actions restantes: ${_pendingSymbols.length}');
    _lastBatchTime = DateTime.now();
    await _savePersistentStats();

    // Sauvegarder les métadonnées dans Firestore pour tous les comptes d'investissement
    await _saveMetadataToFirestore();
  }

  // Reset le compteur quotidien
  void _resetDailyCounter() {
    final now = DateTime.now();
    if (now.day != _lastResetDate.day ||
        now.month != _lastResetDate.month ||
        now.year != _lastResetDate.year) {
      _requestsToday = 0;
      _lastResetDate = now;
      _savePersistentStats();
      print('🔄 Nouveau jour, compteur Alpha Vantage remis à zéro');
    }
  }

  // Mettre à jour le prix d'une action
  Future<void> _updatePrice(String symbol) async {
    try {
      final url = Uri.parse(
          '$BASE_URL?function=GLOBAL_QUOTE&symbol=$symbol&apikey=$API_KEY');

      print('🌐 Requête Alpha Vantage pour $symbol...');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Vérifier si on a des données
        if (data['Global Quote'] != null &&
            data['Global Quote']['05. price'] != null) {
          final price = double.tryParse(data['Global Quote']['05. price']);

          if (price != null && price > 0) {
            // Sauvegarder dans Firestore
            await _savePriceToFirestore(symbol, price);
            print('💾 Prix $symbol sauvegardé: \$${price.toStringAsFixed(2)}');
          } else {
            print(
                '❌ Prix invalide pour $symbol: ${data['Global Quote']['05. price']}');
          }
        } else {
          print(
              '❌ Pas de données pour $symbol: ${data['Note'] ?? 'Données manquantes'}');
        }
      } else {
        print('❌ Erreur HTTP ${response.statusCode} pour $symbol');
      }
    } catch (e) {
      print('❌ Erreur mise à jour $symbol: $e');
    }
  }

  // Sauvegarder le prix dans Firestore
  Future<void> _savePriceToFirestore(String symbol, double price) async {
    try {
      final now = DateTime.now();

      // Sauvegarder le prix actuel
      await _firestore.collection('prix_actions').doc(symbol).set({
        'symbol': symbol,
        'prix': price,
        'derniere_mise_a_jour': now.toIso8601String(),
        'source': 'alpha_vantage',
      });

      // Ajouter à l'historique
      await _firestore.collection('historique_prix').add({
        'symbol': symbol,
        'prix': price,
        'date': now.toIso8601String(),
        'source': 'alpha_vantage',
      });
    } catch (e) {
      print('❌ Erreur sauvegarde Firestore pour $symbol: $e');
    }
  }

  // Récupérer le prix actuel depuis Firestore
  Future<double?> getCurrentPrice(String symbol) async {
    try {
      final doc = await _firestore.collection('prix_actions').doc(symbol).get();
      if (doc.exists && doc.data() != null) {
        return doc.data()!['prix']?.toDouble();
      }
    } catch (e) {
      print('❌ Erreur récupération prix $symbol: $e');
    }
    return null;
  }

  // Forcer une mise à jour immédiate (pour le bouton "Rafraîchir")
  Future<void> forceUpdate() async {
    print('🔄 Mise à jour forcée Alpha Vantage...');
    await _processNextBatch();

    // Sauvegarder les métadonnées après la mise à jour forcée
    await _saveMetadataToFirestore();
  }

  // Obtenir les statistiques
  Map<String, dynamic> getStats() {
    return {
      'requestsToday': _requestsToday,
      'maxRequestsPerDay': MAX_REQUESTS_PER_DAY,
      'pendingSymbols': _pendingSymbols.length,
      'batchSize': BATCH_SIZE,
      'batchInterval': BATCH_INTERVAL ~/ 60000, // en minutes
      'lastBatchTime': _lastBatchTime?.toIso8601String(),
      'lastResetDate': _lastResetDate.toIso8601String(),
    };
  }

  // Obtenir le temps jusqu'à la prochaine mise à jour
  String getNextUpdateTime() {
    if (_batchTimer == null) return 'Arrêté';
    final now = DateTime.now();
    if (_lastBatchTime == null) return 'Inconnu';
    final nextUpdate =
        _lastBatchTime!.add(Duration(milliseconds: BATCH_INTERVAL));
    final difference = nextUpdate.difference(now);
    if (difference.isNegative) return 'Imminente';
    final minutes = difference.inMinutes;
    final seconds = difference.inSeconds % 60;
    return '${minutes}m ${seconds}s';
  }

  // Nettoyer les anciens symboles de la queue
  void clearQueue() {
    _pendingSymbols.clear();
    print('🧹 Queue de mise à jour vidée');
  }

  // Sauvegarder les métadonnées dans Firestore pour tous les comptes d'investissement
  Future<void> _saveMetadataToFirestore() async {
    try {
      // Récupérer tous les comptes d'investissement
      final comptesSnapshot = await _firestore
          .collection('comptes')
          .where('type', isEqualTo: 'Investissement')
          .get();

      final now = DateTime.now();
      final prochaineMaj = now.add(Duration(minutes: 10));

      // Mettre à jour les métadonnées pour chaque compte d'investissement
      for (final doc in comptesSnapshot.docs) {
        await _firestore.collection('meta_investissement').doc(doc.id).set({
          'requestsToday': _requestsToday,
          'lastUpdate': now.toIso8601String(),
          'prochaineMaj': prochaineMaj.toIso8601String(),
          'pendingSymbols': _pendingSymbols.length,
        }, SetOptions(merge: true));
      }

      print(
          '💾 Métadonnées sauvegardées pour ${comptesSnapshot.docs.length} comptes d\'investissement');
    } catch (e) {
      print('❌ Erreur sauvegarde métadonnées Firestore: $e');
    }
  }
}
