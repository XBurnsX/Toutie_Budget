import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toutie_budget/widgets/numeric_keyboard.dart';

void main() {
  group('NumericKeyboard Widget Tests', () {
    late TextEditingController controller;

    setUp(() {
      controller = TextEditingController();
    });

    tearDown(() {
      controller.dispose();
    });

    testWidgets('NumericKeyboard displays all number buttons', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: NumericKeyboard(controller: controller)),
        ),
      );

      // Vérifier que tous les chiffres de 0 à 9 sont présents
      for (int i = 0; i <= 9; i++) {
        expect(find.text('$i'), findsOneWidget);
      }

      // Vérifier que le point décimal est présent
      expect(find.text('.'), findsOneWidget);

      // Vérifier que le bouton de retour arrière est présent
      expect(find.byIcon(Icons.backspace_outlined), findsOneWidget);
    });

    testWidgets('NumericKeyboard number input', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: NumericKeyboard(controller: controller)),
        ),
      );

      // Taper sur le chiffre 5
      await tester.tap(find.text('5'));
      await tester.pump();

      // Le widget formate automatiquement avec le symbole $ et la logique de calculatrice
      expect(controller.text, '0.05 \$');
    });

    testWidgets('NumericKeyboard decimal input', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: NumericKeyboard(controller: controller)),
        ),
      );

      // Taper 1, puis ., puis 5
      await tester.tap(find.text('1'));
      await tester.pump();
      await tester.tap(find.text('.'));
      await tester.pump();
      await tester.tap(find.text('5'));
      await tester.pump();

      // Le widget formate automatiquement avec la logique de calculatrice
      expect(controller.text, '0.15 \$');
    });

    testWidgets('NumericKeyboard clear button', (WidgetTester tester) async {
      bool clearCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NumericKeyboard(
              controller: controller,
              onClear: () => clearCalled = true,
            ),
          ),
        ),
      );

      // Taper quelques chiffres d'abord
      await tester.tap(find.text('1'));
      await tester.tap(find.text('2'));
      await tester.pump();

      // Taper sur le bouton Effacer
      await tester.tap(find.text('Effacer'));
      await tester.pump();

      expect(controller.text, '0.00 \$');
      expect(clearCalled, isTrue);
    });

    testWidgets('NumericKeyboard multiple decimal points prevention', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: NumericKeyboard(controller: controller)),
        ),
      );

      // Taper 1, puis ., puis 2, puis ., puis 3
      await tester.tap(find.text('1'));
      await tester.pump();
      await tester.tap(find.text('.'));
      await tester.pump();
      await tester.tap(find.text('2'));
      await tester.pump();
      await tester.tap(find.text('.'));
      await tester.pump();
      await tester.tap(find.text('3'));
      await tester.pump();

      // Le widget devrait empêcher les points décimaux multiples et formater correctement
      expect(controller.text, '1.23 \$');
    });

    testWidgets('NumericKeyboard button layout', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: NumericKeyboard(controller: controller)),
        ),
      );

      // Vérifier qu'il y a exactement 12 boutons (0-9, ., backspace)
      expect(find.byType(ElevatedButton), findsNWidgets(12));
    });

    testWidgets('NumericKeyboard accessibility', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: NumericKeyboard(controller: controller)),
        ),
      );

      // Vérifier que le bouton de retour arrière est accessible
      expect(find.byIcon(Icons.backspace_outlined), findsOneWidget);
    });

    testWidgets('NumericKeyboard large numbers', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: NumericKeyboard(controller: controller)),
        ),
      );

      // Taper une séquence de chiffres pour former un grand nombre
      final digits = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'];
      for (String digit in digits) {
        await tester.tap(find.text(digit));
        await tester.pump();
      }

      // Le widget formate automatiquement avec la logique de calculatrice
      expect(controller.text, '12345678.90 \$');
    });

    testWidgets('NumericKeyboard decimal precision', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: NumericKeyboard(controller: controller)),
        ),
      );

      // Taper 1, ., 2, 3, 4, 5
      await tester.tap(find.text('1'));
      await tester.pump();
      await tester.tap(find.text('.'));
      await tester.pump();
      await tester.tap(find.text('2'));
      await tester.pump();
      await tester.tap(find.text('3'));
      await tester.pump();
      await tester.tap(find.text('4'));
      await tester.pump();
      await tester.tap(find.text('5'));
      await tester.pump();

      // Le widget formate automatiquement avec la logique de calculatrice
      expect(controller.text, '123.45 \$');
    });

    testWidgets('NumericKeyboard without decimal', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NumericKeyboard(controller: controller, showDecimal: false),
          ),
        ),
      );

      // Vérifier que le point décimal n'est pas présent
      expect(find.text('.'), findsNothing);

      // Vérifier qu'il y a exactement 11 boutons (0-9, backspace)
      expect(find.byType(ElevatedButton), findsNWidgets(11));
    });

    testWidgets('NumericKeyboard onValueChanged callback', (
      WidgetTester tester,
    ) async {
      String? lastValue;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NumericKeyboard(
              controller: controller,
              onValueChanged: (value) => lastValue = value,
            ),
          ),
        ),
      );

      // Taper sur le chiffre 5
      await tester.tap(find.text('5'));
      await tester.pump();

      expect(lastValue, '0.05 \$');
    });
  });
}
