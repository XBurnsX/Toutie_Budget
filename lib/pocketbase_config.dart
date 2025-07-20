import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PocketBaseConfig {
  // URLs possibles pour PocketBase
  static const List<String> possibleUrls = [
    'http://192.168.1.77:8090', // Réseau local
    'http://10.0.2.2:8090', // Émulateur Android
    'http://127.0.0.1:8090', // Localhost
    'https://toutiebudget.duckdns.net', // Serveur distant
  ];

  // URL active (sera définie après test)
  static String? _activeUrl;

  // Noms exacts des collections (selon le guide de migration)
  static const String usersCollection = 'users';
  static const String comptesChequesCollection = 'comptes_cheques';
  static const String comptesCreditsCollection = 'comptes_credits';
  static const String comptesDettesCollection = 'comptes_dettes';
  static const String comptesInvestissementCollection =
      'comptes_investissement';
  static const String categoriesCollection = 'categories';
  static const String enveloppesCollection = 'enveloppes';
  static const String transactionsCollection = 'transactions';
  static const String allocationsMensuellesCollection =
      'allocations_mensuelles';
  static const String tiersCollection = 'tiers';

  // Getter pour l'URL active
  static String get serverUrl {
    if (_activeUrl == null) {
      throw Exception(
          'PocketBase URL non initialisée. Appelez testAndSetActiveUrl() d\'abord.');
    }
    return _activeUrl!;
  }

  // Tester et définir l'URL active
  static Future<void> testAndSetActiveUrl() async {
    for (final url in possibleUrls) {
      try {
        print('🔄 Test de connexion à: $url');
        final response = await http.get(Uri.parse('$url/api/health')).timeout(
              const Duration(seconds: 5),
            );

        if (response.statusCode == 200) {
          _activeUrl = url;
          print('✅ PocketBase trouvé sur: $url');
          return;
        }
      } catch (e) {
        print('❌ Échec de connexion à: $url');
      }
    }

    throw Exception('Aucune URL PocketBase accessible trouvée');
  }
}
