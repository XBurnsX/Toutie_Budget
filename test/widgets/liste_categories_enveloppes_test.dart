import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toutie_budget/widgets/liste_categories_enveloppes.dart';

void main() {
  group('ListeCategoriesEnveloppes Widget Tests', () {
    testWidgets('ListeCategoriesEnveloppes displays categories correctly', (
      WidgetTester tester,
    ) async {
      final categories = [
        {
          'id': 'cat_1',
          'nom': 'Essentiels',
          'enveloppes': [
            {
              'id': 'env_1',
              'nom': 'Épicerie',
              'solde': 400.0,
              'objectif': 500.0,
              'depense': 100.0,
              'archivee': false,
            },
            {
              'id': 'env_2',
              'nom': 'Transport',
              'solde': 200.0,
              'objectif': 300.0,
              'depense': 50.0,
              'archivee': false,
            },
          ],
        },
        {
          'id': 'cat_2',
          'nom': 'Loisirs',
          'enveloppes': [
            {
              'id': 'env_3',
              'nom': 'Restaurant',
              'solde': 150.0,
              'objectif': 200.0,
              'depense': 75.0,
              'archivee': false,
            },
          ],
        },
      ];

      final comptes = [
        {'id': 'compte_1', 'couleur': 0xFF2196F3},
        {'id': 'compte_2', 'couleur': 0xFF4CAF50},
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListeCategoriesEnveloppes(
              categories: categories,
              comptes: comptes,
              selectedMonthKey: '2025-01',
            ),
          ),
        ),
      );

      // Vérifier que les catégories sont affichées
      expect(find.text('Essentiels'), findsOneWidget);
      expect(find.text('Loisirs'), findsOneWidget);

      // Vérifier que les enveloppes sont affichées
      expect(find.text('Épicerie'), findsOneWidget);
      expect(find.text('Transport'), findsOneWidget);
      expect(find.text('Restaurant'), findsOneWidget);
    });

    testWidgets('ListeCategoriesEnveloppes handles empty categories', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListeCategoriesEnveloppes(
              categories: [],
              comptes: [],
              selectedMonthKey: '2025-01',
            ),
          ),
        ),
      );

      // Vérifier que le widget s'affiche sans erreur avec des listes vides
      expect(find.byType(ListeCategoriesEnveloppes), findsOneWidget);
    });

    testWidgets(
      'ListeCategoriesEnveloppes displays envelope progress correctly',
      (WidgetTester tester) async {
        final categories = [
          {
            'id': 'cat_1',
            'nom': 'Test',
            'enveloppes': [
              {
                'id': 'env_1',
                'nom': 'Test Enveloppe',
                'solde': 75.0,
                'objectif': 100.0,
                'depense': 25.0,
                'archivee': false,
              },
            ],
          },
        ];

        final comptes = [
          {'id': 'compte_1', 'couleur': 0xFF2196F3},
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ListeCategoriesEnveloppes(
                categories: categories,
                comptes: comptes,
                selectedMonthKey: '2025-01',
              ),
            ),
          ),
        );

        // Vérifier que l'enveloppe est affichée
        expect(find.text('Test Enveloppe'), findsOneWidget);
      },
    );

    testWidgets('ListeCategoriesEnveloppes handles negative balances', (
      WidgetTester tester,
    ) async {
      final categories = [
        {
          'id': 'cat_1',
          'nom': 'Test',
          'enveloppes': [
            {
              'id': 'env_1',
              'nom': 'Enveloppe Négative',
              'solde': -50.0,
              'objectif': 100.0,
              'depense': 150.0,
              'archivee': false,
            },
          ],
        },
      ];

      final comptes = [
        {'id': 'compte_1', 'couleur': 0xFF2196F3},
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListeCategoriesEnveloppes(
              categories: categories,
              comptes: comptes,
              selectedMonthKey: '2025-01',
            ),
          ),
        ),
      );

      // Vérifier que l'enveloppe négative est affichée
      expect(find.text('Enveloppe Négative'), findsOneWidget);
    });

    testWidgets('ListeCategoriesEnveloppes handles archived envelopes', (
      WidgetTester tester,
    ) async {
      final categories = [
        {
          'id': 'cat_1',
          'nom': 'Test',
          'enveloppes': [
            {
              'id': 'env_1',
              'nom': 'Enveloppe Archivée',
              'solde': 0.0,
              'objectif': 100.0,
              'depense': 0.0,
              'archivee': true,
            },
          ],
        },
      ];

      final comptes = [
        {'id': 'compte_1', 'couleur': 0xFF2196F3},
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListeCategoriesEnveloppes(
              categories: categories,
              comptes: comptes,
              selectedMonthKey: '2025-01',
            ),
          ),
        ),
      );

      // Vérifier que l'enveloppe archivée est affichée
      expect(find.text('Enveloppe Archivée'), findsOneWidget);
    });

    testWidgets('ListeCategoriesEnveloppes handles missing compte data', (
      WidgetTester tester,
    ) async {
      final categories = [
        {
          'id': 'cat1',
          'nom': 'Catégorie Test',
          'enveloppes': [
            {
              'id': 'env1',
              'nom': 'Enveloppe Test',
              'solde': 100.0,
              // On ne met pas d'objectif ni de provenance pour forcer l'affichage du solde
            },
          ],
        },
      ];

      final comptes = [
        {'id': 'compte1', 'couleur': 0xFF2196F3},
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListeCategoriesEnveloppes(
              categories: categories,
              comptes: comptes,
              selectedMonthKey: null,
            ),
          ),
        ),
      );

      // Diagnostic : afficher tous les textes présents
      final textWidgets = find.byType(Text).evaluate().toList();
      for (final element in textWidgets) {
        final widget = element.widget as Text;
        // ignore: avoid_print
        print('TEXTE TROUVÉ : "' + (widget.data ?? '') + '"');
      }

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              (widget.data == '100.00 \$' || widget.data == '100.00\u00A0\$'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('ListeCategoriesEnveloppes handles different month keys', (
      WidgetTester tester,
    ) async {
      final categories = [
        {
          'id': 'cat_1',
          'nom': 'Test',
          'enveloppes': [
            {
              'id': 'env_1',
              'nom': 'Test Enveloppe',
              'solde': 100.0,
              'objectif': 100.0,
              'depense': 0.0,
              'archivee': false,
              'historique': {
                '2025-01': {'solde': 100.0, 'depense': 0.0, 'objectif': 100.0},
                '2025-02': {'solde': 150.0, 'depense': 50.0, 'objectif': 100.0},
              },
            },
          ],
        },
      ];

      final comptes = [
        {'id': 'compte_1', 'couleur': 0xFF2196F3},
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListeCategoriesEnveloppes(
              categories: categories,
              comptes: comptes,
              selectedMonthKey: '2025-02',
            ),
          ),
        ),
      );

      // Vérifier que le widget s'affiche avec la clé de mois différente
      expect(find.text('Test Enveloppe'), findsOneWidget);
    });

    testWidgets('ListeCategoriesEnveloppes handles null values gracefully', (
      WidgetTester tester,
    ) async {
      final categories = [
        {
          'id': 'cat_1',
          'nom': 'Test',
          'enveloppes': [
            {
              'id': 'env_1',
              'nom': 'Test Enveloppe',
              'solde': null,
              'objectif': null,
              'depense': null,
              'archivee': null,
            },
          ],
        },
      ];

      final comptes = [
        {'id': 'compte_1', 'couleur': null},
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListeCategoriesEnveloppes(
              categories: categories,
              comptes: comptes,
              selectedMonthKey: '2025-01',
            ),
          ),
        ),
      );

      // Vérifier que le widget s'affiche sans erreur avec des valeurs null
      expect(find.text('Test Enveloppe'), findsOneWidget);
    });
  });
}
