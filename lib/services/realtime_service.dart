// 📁 Chemin : lib/services/realtime_service.dart
// 🔗 Dépendances : pocketbase_service.dart
// 📋 Description : Service centralisé pour gérer le temps réel PocketBase

import 'package:pocketbase/pocketbase.dart';
import 'pocketbase_service.dart';
import 'auth_service.dart';

class RealtimeService {
  static final RealtimeService _instance = RealtimeService._internal();
  factory RealtimeService() => _instance;
  RealtimeService._internal();

  static bool _isInitialized = false;
  static final Map<String, dynamic> _subscriptions = {};

  // Initialiser le temps réel pour toutes les collections
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final pb = await AuthService.pocketBaseInstance;
      if (pb == null) return;

      final userId = pb.authStore.model?.id;
      if (userId == null) return;

      // S'abonner aux collections principales
      await _subscribeToCollection('comptes_cheques', userId);
      await _subscribeToCollection('comptes_credits', userId);
      await _subscribeToCollection('comptes_investissement', userId);
      await _subscribeToCollection('comptes_dettes', userId);
      await _subscribeToCollection('pret_personnel', userId);
      await _subscribeToCollection('categories', userId);
      await _subscribeToCollection('enveloppes', userId);

      _isInitialized = true;
    } catch (e) {
      // Gestion silencieuse des erreurs
    }
  }

  // S'abonner à une collection
  static Future<void> _subscribeToCollection(
      String collectionName, String userId) async {
    try {
      final pb = await AuthService.pocketBaseInstance;
      if (pb == null) return;

      // S'abonner avec filtre utilisateur
      final subscription = pb.collection(collectionName).subscribe(
            'utilisateur_id = "$userId"',
            (data) => _handleRealtimeUpdate(collectionName, data),
          );

      _subscriptions[collectionName] = subscription;
    } catch (e) {
      // Gestion silencieuse des erreurs
    }
  }

  // Gérer les mises à jour en temps réel
  static void _handleRealtimeUpdate(String collectionName, dynamic data) {
    try {
      final action = data.action;
      final record = data.record;

      // Notifier les listeners appropriés selon la collection
      switch (collectionName) {
        case 'comptes_cheques':
        case 'comptes_credits':
        case 'comptes_investissement':
        case 'comptes_dettes':
        case 'pret_personnel':
          _notifyComptesUpdate();
          break;
        case 'categories':
          _notifyCategoriesUpdate();
          break;
        case 'enveloppes':
          _notifyEnveloppesUpdate();
          break;
      }
    } catch (e) {
      // Gestion silencieuse des erreurs
    }
  }

  // Notifier la mise à jour des comptes
  static void _notifyComptesUpdate() {
    // Les streams PocketBaseService se mettront à jour automatiquement
  }

  // Notifier la mise à jour des catégories
  static void _notifyCategoriesUpdate() {
  }

  // Notifier la mise à jour des enveloppes
  static void _notifyEnveloppesUpdate() {
  }

  // Nettoyer toutes les subscriptions
  static Future<void> dispose() async {
    try {
      for (final subscription in _subscriptions.values) {
        if (subscription.unsubscribe != null) {
          await subscription.unsubscribe();
        }
      }
      _subscriptions.clear();
      _isInitialized = false;
    } catch (e) {
      // Gestion silencieuse des erreurs
    }
  }

  // Vérifier si le temps réel est initialisé
  static bool get isInitialized => _isInitialized;

  // Obtenir le statut des subscriptions
  static Map<String, bool> get subscriptionsStatus {
    return _subscriptions.map((key, value) => MapEntry(key, value != null));
  }
}
