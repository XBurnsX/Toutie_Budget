import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_core/firebase_core.dart' as firebase_core;

/// Mock de Firebase pour les tests
class MockFirebase extends Mock implements firebase_core.Firebase {}

/// Configuration Firebase pour les tests
class FirebaseTestConfig {
  static Future<void> setupFirebaseForTesting() async {
    TestWidgetsFlutterBinding.ensureInitialized();

    // Utiliser un mock au lieu d'initialiser Firebase réellement
    // Cela évite les problèmes de canal dans l'environnement de test
  }
}

/// Configuration Firebase mock pour les tests
class MockFirebaseConfig {
  static const Map<String, dynamic> testConfig = {
    'apiKey': 'test-api-key',
    'appId': 'test-app-id',
    'messagingSenderId': 'test-sender-id',
    'projectId': 'test-project-id',
  };
}

/// Initialisation Firebase pour tous les tests
Future<void> setupFirebaseForTests() async {
  // Pour l'instant, on skip l'initialisation Firebase
  // et on utilise des mocks dans les tests individuels
  TestWidgetsFlutterBinding.ensureInitialized();
}
