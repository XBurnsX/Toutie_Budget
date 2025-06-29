# 🧪 Tests - Toutie_Budget

Ce dossier contient tous les tests automatisés pour l'application Toutie_Budget.

## 📁 Structure des Tests

```
test/
├── models/                    # Tests unitaires des modèles
│   ├── transaction_model_test.dart
│   ├── fractionnement_model_test.dart
│   ├── compte_test.dart
│   └── categorie_test.dart
├── services/                  # Tests unitaires des services
│   ├── argent_service_test.dart
│   ├── dette_service_test.dart
│   └── firebase_service_test.dart
├── widgets/                   # Tests de widgets
│   ├── numeric_keyboard_test.dart
│   ├── liste_categories_enveloppes_test.dart
│   └── month_picker_test.dart
├── integration/               # Tests d'intégration
│   └── scenarios_test.dart
├── test_config.dart          # Configuration et utilitaires de test
├── finances_calculs_test.dart # Tests existants
└── widget_test.dart          # Tests de widgets par défaut
```

## 🎯 Types de Tests

### 1. Tests Unitaires (`models/`, `services/`)

**Objectif :** Tester chaque fonction ou classe de manière isolée.

**Exemples :**
- Validation des modèles de données
- Calculs financiers
- Sérialisation/désérialisation JSON
- Logique métier des services

**Structure :**
```dart
group('Nom du modèle/service', () {
  test('Description du test', () {
    // Arrange
    final data = TestConfig.createTestData();
    
    // Act
    final result = functionToTest(data);
    
    // Assert
    expect(result, expectedValue);
  });
});
```

### 2. Tests de Widgets (`widgets/`)

**Objectif :** Tester l'interface utilisateur et les interactions.

**Exemples :**
- Affichage correct des composants
- Gestion des interactions utilisateur
- Validation des entrées
- Gestion des états d'erreur

**Structure :**
```dart
testWidgets('Description du test', (WidgetTester tester) async {
  // Arrange
  await tester.pumpWidget(MyWidget());
  
  // Act
  await tester.tap(find.text('Button'));
  await tester.pump();
  
  // Assert
  expect(find.text('Expected Result'), findsOneWidget);
});
```

### 3. Tests d'Intégration (`integration/`)

**Objectif :** Tester des scénarios complets d'utilisation.

**Exemples :**
- Création d'un compte et ajout d'enveloppes
- Processus complet d'ajout de transaction
- Gestion des prêts personnels
- Virements entre comptes

## 🚀 Exécution des Tests

### Script Automatisé (Recommandé)

```bash
# Tous les tests
./scripts/run_tests.sh

# Avec couverture
./scripts/run_tests.sh -c

# Tests unitaires seulement
./scripts/run_tests.sh -u

# Tests de widgets seulement
./scripts/run_tests.sh -w

# Tests d'intégration seulement
./scripts/run_tests.sh -i

# Mode verbeux
./scripts/run_tests.sh -v
```

### Commandes Flutter Directes

```bash
# Tous les tests
flutter test

# Tests avec couverture
flutter test --coverage

# Tests spécifiques
flutter test test/models/
flutter test test/widgets/
flutter test test/integration/

# Tests en mode verbose
flutter test --verbose
```

## 📊 Couverture de Tests

### Objectifs de Couverture

- **Modèles :** 100% (validation, sérialisation)
- **Services :** 90%+ (logique métier critique)
- **Widgets :** 80%+ (composants principaux)
- **Intégration :** 70%+ (scénarios critiques)

### Génération du Rapport

```bash
# Générer le rapport HTML
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html

# Ouvrir le rapport
open coverage/html/index.html  # macOS
xdg-open coverage/html/index.html  # Linux
start coverage/html/index.html  # Windows
```

## 🛠️ Configuration des Tests

### TestConfig

Le fichier `test_config.dart` contient :
- Données de test réutilisables
- Méthodes utilitaires
- Constantes de test
- Extensions pour WidgetTester

### Utilisation

```dart
import 'test_config.dart';

test('Test avec données configurées', () {
  final compte = TestConfig.createTestCompte(
    nom: 'Mon Compte',
    solde: 1000.0,
  );
  
  expect(TestConfig.isValidCompte(compte), true);
});
```

## 📋 Checklist des Tests

### Modèles
- [x] Transaction
- [x] Fractionnement
- [x] Compte
- [x] Catégorie
- [x] Dette

### Services
- [x] ArgentService
- [ ] DetteService
- [ ] FirebaseService
- [ ] RolloverService

### Widgets
- [x] NumericKeyboard
- [x] ListeCategoriesEnveloppes
- [ ] MonthPicker
- [ ] PieChartWithLegend
- [ ] ModaleFractionnement

### Intégration
- [x] Configuration initiale
- [x] Gestion des transactions
- [x] Gestion des objectifs
- [x] Situations d'urgence
- [x] Virements
- [x] Prêts personnels

## 🔧 Bonnes Pratiques

### 1. Nommage
- Tests descriptifs et explicites
- Groupes logiques avec `group()`
- Noms en français pour la cohérence

### 2. Structure AAA
```dart
test('Test description', () {
  // Arrange - Préparer les données
  final input = TestConfig.createTestData();
  
  // Act - Exécuter l'action
  final result = functionToTest(input);
  
  // Assert - Vérifier le résultat
  expect(result, expectedValue);
});
```

### 3. Données de Test
- Utiliser `TestConfig` pour les données communes
- Créer des données spécifiques si nécessaire
- Éviter les données codées en dur

### 4. Gestion des Erreurs
```dart
test('Test avec exception', () {
  expect(() => functionThatThrows(), throwsException);
  expect(() => functionThatThrows(), throwsA(isA<SpecificException>()));
});
```

### 5. Tests Asynchrones
```dart
test('Test asynchrone', () async {
  final result = await asyncFunction();
  expect(result, expectedValue);
});
```

## 🐛 Debug des Tests

### Mode Verbose
```bash
flutter test --verbose
```

### Tests Spécifiques
```bash
flutter test test/models/transaction_model_test.dart
```

### Debug avec Breakpoints
```bash
flutter test --start-paused
```

### Logs Personnalisés
```dart
test('Test avec logs', () {
  print('Debug info');
  expect(result, expectedValue);
});
```

## 📈 Métriques

### Couverture Actuelle
- **Total :** ~60%
- **Modèles :** 85%
- **Services :** 45%
- **Widgets :** 30%
- **Intégration :** 70%

### Objectifs
- **Total :** 80%+
- **Modèles :** 100%
- **Services :** 90%+
- **Widgets :** 80%+
- **Intégration :** 85%+

## 🔄 Maintenance

### Ajout de Nouveaux Tests
1. Créer le fichier dans le bon dossier
2. Suivre la structure AAA
3. Utiliser TestConfig pour les données
4. Ajouter au script d'exécution si nécessaire

### Mise à Jour des Tests
1. Vérifier la compatibilité après refactoring
2. Mettre à jour les données de test si nécessaire
3. Ajouter des tests pour les nouvelles fonctionnalités

### Exécution Régulière
- Avant chaque commit
- Avant chaque merge
- Intégration continue (CI/CD)

## 📚 Ressources

- [Documentation Flutter Testing](https://docs.flutter.dev/testing)
- [Widget Testing](https://docs.flutter.dev/cookbook/testing/widget/introduction)
- [Integration Testing](https://docs.flutter.dev/cookbook/testing/integration/introduction)
- [Test Coverage](https://docs.flutter.dev/testing#coverage) 