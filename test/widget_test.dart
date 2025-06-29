// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:toutie_budget/main.dart';
import 'firebase_test_config.dart';

void main() {
  setUpAll(() async {
    // Initialiser Firebase pour tous les tests
    await setupFirebaseForTests();
  });

  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that our counter starts at 0.
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    // Tap the '+' icon and trigger a frame.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    // Verify that our counter has incremented.
    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('Affichage d\'erreur si champ requis vide', (
    WidgetTester tester,
  ) async {
    // Widget de test : un formulaire simple avec validation
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Form(
            key: GlobalKey<FormState>(),
            child: Column(
              children: [
                TextFormField(
                  key: const Key('champ-obligatoire'),
                  validator: (value) => (value == null || value.isEmpty)
                      ? 'Ce champ est requis'
                      : null,
                ),
                ElevatedButton(
                  onPressed: () {
                    final form = Form.of(
                      tester.element(find.byType(TextFormField)),
                    );
                    form.validate();
                  },
                  child: const Text('Valider'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Ne rien saisir et appuyer sur le bouton
    await tester.tap(find.text('Valider'));
    await tester.pump();

    // Vérifier que le message d'erreur s'affiche
    expect(find.text('Ce champ est requis'), findsOneWidget);
  });

  testWidgets('Affichage d\'erreur si transfert entre comptes incompatibles', (
    WidgetTester tester,
  ) async {
    // Widget de test : formulaire de transfert simplifié
    String? erreur;
    String compteSource = 'Compte A';
    String compteDest = 'Compte B';
    double montant = 100;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                children: [
                  DropdownButton<String>(
                    key: const Key('source'),
                    value: compteSource,
                    items: [
                      DropdownMenuItem(
                        value: 'Compte A',
                        child: Text('Compte A'),
                      ),
                      DropdownMenuItem(
                        value: 'Compte B',
                        child: Text('Compte B'),
                      ),
                    ],
                    onChanged: (val) => setState(() => compteSource = val!),
                  ),
                  DropdownButton<String>(
                    key: const Key('dest'),
                    value: compteDest,
                    items: [
                      DropdownMenuItem(
                        value: 'Compte A',
                        child: Text('Compte A'),
                      ),
                      DropdownMenuItem(
                        value: 'Compte B',
                        child: Text('Compte B'),
                      ),
                    ],
                    onChanged: (val) => setState(() => compteDest = val!),
                  ),
                  TextFormField(
                    key: const Key('montant'),
                    initialValue: '100',
                    keyboardType: TextInputType.number,
                    onChanged: (val) => montant = double.tryParse(val) ?? 0,
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (compteSource == compteDest) {
                        setState(
                          () => erreur =
                              'Impossible de transférer vers le même compte',
                        );
                      } else if (compteSource != 'Compte A') {
                        setState(
                          () => erreur = 'Compte de provenance invalide',
                        );
                      } else {
                        setState(() => erreur = null);
                      }
                    },
                    child: const Text('Transférer'),
                  ),
                  if (erreur != null) Text(erreur!, key: const Key('erreur')),
                ],
              );
            },
          ),
        ),
      ),
    );

    // Sélectionner le même compte pour source et destination
    await tester.tap(find.byKey(const Key('dest')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Compte A').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transférer'));
    await tester.pump();
    expect(
      find.text('Impossible de transférer vers le même compte'),
      findsOneWidget,
    );

    // Sélectionner un compte de provenance invalide
    await tester.tap(find.byKey(const Key('source')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Compte B').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transférer'));
    await tester.pump();
    expect(find.text('Compte de provenance invalide'), findsOneWidget);
  });

  testWidgets(
    'Affichage d\'erreur pour tous les cas de transfert (compte-compte, enveloppe-enveloppe, enveloppe-compte, etc.)',
    (WidgetTester tester) async {
      String? erreur;
      String sourceType = 'Compte';
      String destType = 'Compte';
      String source = 'A';
      String dest = 'B';
      double montant = 100;
      String provenance = 'A';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  children: [
                    DropdownButton<String>(
                      key: const Key('sourceType'),
                      value: sourceType,
                      items: [
                        DropdownMenuItem(
                          value: 'Compte',
                          child: Text('Compte'),
                        ),
                        DropdownMenuItem(
                          value: 'Enveloppe',
                          child: Text('Enveloppe'),
                        ),
                      ],
                      onChanged: (val) => setState(() => sourceType = val!),
                    ),
                    DropdownButton<String>(
                      key: const Key('destType'),
                      value: destType,
                      items: [
                        DropdownMenuItem(
                          value: 'Compte',
                          child: Text('Compte'),
                        ),
                        DropdownMenuItem(
                          value: 'Enveloppe',
                          child: Text('Enveloppe'),
                        ),
                      ],
                      onChanged: (val) => setState(() => destType = val!),
                    ),
                    DropdownButton<String>(
                      key: const Key('source'),
                      value: source,
                      items: [
                        DropdownMenuItem(value: 'A', child: Text('A')),
                        DropdownMenuItem(value: 'B', child: Text('B')),
                      ],
                      onChanged: (val) => setState(() => source = val!),
                    ),
                    DropdownButton<String>(
                      key: const Key('dest'),
                      value: dest,
                      items: [
                        DropdownMenuItem(value: 'A', child: Text('A')),
                        DropdownMenuItem(value: 'B', child: Text('B')),
                      ],
                      onChanged: (val) => setState(() => dest = val!),
                    ),
                    DropdownButton<String>(
                      key: const Key('provenance'),
                      value: provenance,
                      items: [
                        DropdownMenuItem(value: 'A', child: Text('A')),
                        DropdownMenuItem(value: 'B', child: Text('B')),
                      ],
                      onChanged: (val) => setState(() => provenance = val!),
                    ),
                    TextFormField(
                      key: const Key('montant'),
                      initialValue: '100',
                      keyboardType: TextInputType.number,
                      onChanged: (val) => montant = double.tryParse(val) ?? 0,
                    ),
                    ElevatedButton(
                      onPressed: () {
                        // Cas d'erreur : même source et destination
                        if (source == dest && sourceType == destType) {
                          setState(
                            () => erreur =
                                'Impossible de transférer vers la même entité',
                          );
                        }
                        // Cas d'erreur : provenance incompatible (ex : enveloppe avec provenance différente)
                        else if (sourceType == 'Enveloppe' &&
                            provenance != source) {
                          setState(
                            () => erreur =
                                'Provenance incompatible avec l\'enveloppe source',
                          );
                        }
                        // Cas d'erreur : enveloppe vers enveloppe avec provenances différentes
                        else if (sourceType == 'Enveloppe' &&
                            destType == 'Enveloppe' &&
                            provenance != dest) {
                          setState(
                            () => erreur =
                                'Impossible de mélanger des fonds de provenances différentes',
                          );
                        }
                        // Cas d'erreur : montant négatif ou nul
                        else if (montant <= 0) {
                          setState(() => erreur = 'Montant invalide');
                        }
                        // Cas d'erreur : source ou destination archivée (ici simulé par B)
                        else if (source == 'B' || dest == 'B') {
                          setState(
                            () => erreur = 'Source ou destination archivée',
                          );
                        } else {
                          setState(() => erreur = null);
                        }
                      },
                      child: const Text('Transférer'),
                    ),
                    if (erreur != null) Text(erreur!, key: const Key('erreur')),
                  ],
                );
              },
            ),
          ),
        ),
      );

      // Cas 1 : même source et destination
      await tester.tap(find.byKey(const Key('dest')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('A').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Transférer'));
      await tester.pump();
      expect(
        find.text('Impossible de transférer vers la même entité'),
        findsOneWidget,
      );

      // Cas 2 : provenance incompatible enveloppe
      await tester.tap(find.byKey(const Key('sourceType')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enveloppe').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('provenance')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('B').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Transférer'));
      await tester.pump();
      expect(
        find.text('Provenance incompatible avec l\'enveloppe source'),
        findsOneWidget,
      );

      // Cas 3 : enveloppe vers enveloppe avec provenances différentes
      await tester.tap(find.byKey(const Key('destType')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enveloppe').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('provenance')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('A').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('dest')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('B').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('provenance')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('B').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Transférer'));
      await tester.pump();
      expect(
        find.text(
          'Impossible de mélanger des fonds de provenances différentes',
        ),
        findsOneWidget,
      );

      // Cas 4 : montant négatif
      await tester.enterText(find.byKey(const Key('montant')), '-10');
      await tester.tap(find.text('Transférer'));
      await tester.pump();
      expect(find.text('Montant invalide'), findsOneWidget);

      // Cas 5 : source archivée
      await tester.tap(find.byKey(const Key('source')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('B').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Transférer'));
      await tester.pump();
      expect(find.text('Source ou destination archivée'), findsOneWidget);
    },
  );
}
