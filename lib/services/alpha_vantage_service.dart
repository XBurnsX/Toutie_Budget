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

    // Sauvegarder les métadonnées initiales
    _saveMetadataToFirestore();
  }

  // Arrêter le batch update
  void stopBatchUpdate() {
    _batchTimer?.cancel();
    _batchTimer = null;
  }

  // Ajouter une action à la queue de mise à jour
  void addSymbolToQueue(String symbol) {
    if (!_pendingSymbols.contains(symbol)) {
      _pendingSymbols.add(symbol);
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
      return;
    }

    // Prendre les 5 prochaines actions
    final batch = _pendingSymbols.take(BATCH_SIZE).toList();
    if (batch.isEmpty) {
      return;
    }

    for (String symbol in batch) {
      if (_requestsToday < MAX_REQUESTS_PER_DAY) {
        await _updatePrice(symbol);
        _requestsToday++;
        _pendingSymbols.remove(symbol);

        // Pause entre chaque requête pour respecter la limite de 5 req/min
        if (batch.indexOf(symbol) < batch.length - 1) {
          await Future.delayed(Duration(seconds: DELAY_BETWEEN_REQUESTS));
        }
      }
    }

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
    }
  }

  // Mettre à jour le prix d'une action
  Future<void> _updatePrice(String symbol) async {
    try {
      final url = Uri.parse(
          '$BASE_URL?function=GLOBAL_QUOTE&symbol=$symbol&apikey=$API_KEY');

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
          } else {}
        } else {}
      } else {}
    } catch (e) {}
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
    } catch (e) {}
  }

  // Récupérer le prix actuel depuis Firestore
  Future<double?> getCurrentPrice(String symbol) async {
    try {
      final doc = await _firestore.collection('prix_actions').doc(symbol).get();
      if (doc.exists && doc.data() != null) {
        return doc.data()!['prix']?.toDouble();
      }
    } catch (e) {}
    return null;
  }

  // Forcer une mise à jour immédiate (pour le bouton "Rafraîchir")
  Future<void> forceUpdate() async {
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
    } catch (e) {}
  }
}
