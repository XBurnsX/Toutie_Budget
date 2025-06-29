import 'package:flutter_test/flutter_test.dart';
import 'package:toutie_budget/models/fractionnement_model.dart';

void main() {
  group('Fractionnement Model Tests', () {
    test('SousItemFractionnement creation and serialization', () {
      final sousItem = SousItemFractionnement(
        id: 'item_1',
        description: 'Épicerie',
        montant: 60.0,
        enveloppeId: 'env_1',
        transactionParenteId: 'trans_1',
      );

      expect(sousItem.id, 'item_1');
      expect(sousItem.description, 'Épicerie');
      expect(sousItem.montant, 60.0);
      expect(sousItem.enveloppeId, 'env_1');
    });

    test('SousItemFractionnement JSON serialization', () {
      final sousItem = SousItemFractionnement(
        id: 'item_1',
        description: 'Épicerie',
        montant: 60.0,
        enveloppeId: 'env_1',
        transactionParenteId: 'trans_1',
      );

      final json = sousItem.toJson();
      expect(json['id'], 'item_1');
      expect(json['description'], 'Épicerie');
      expect(json['montant'], 60.0);
      expect(json['enveloppeId'], 'env_1');
      expect(json['transactionParenteId'], 'trans_1');
    });

    test('SousItemFractionnement JSON deserialization', () {
      final json = {
        'id': 'item_1',
        'description': 'Épicerie',
        'montant': 60.0,
        'enveloppeId': 'env_1',
        'transactionParenteId': 'trans_1',
      };

      final sousItem = SousItemFractionnement.fromJson(json);
      expect(sousItem.id, 'item_1');
      expect(sousItem.description, 'Épicerie');
      expect(sousItem.montant, 60.0);
      expect(sousItem.enveloppeId, 'env_1');
    });

    test('SousItemFractionnement copyWith', () {
      final original = SousItemFractionnement(
        id: 'item_1',
        description: 'Épicerie',
        montant: 60.0,
        enveloppeId: 'env_1',
      );

      final modified = original.copyWith(
        montant: 75.0,
        description: 'Épicerie + Restaurant',
      );

      expect(modified.id, 'item_1');
      expect(modified.description, 'Épicerie + Restaurant');
      expect(modified.montant, 75.0);
      expect(modified.enveloppeId, 'env_1');
    });

    test('TransactionFractionnee creation and validation', () {
      final sousItems = [
        SousItemFractionnement(
          id: 'item_1',
          description: 'Épicerie',
          montant: 60.0,
          enveloppeId: 'env_1',
        ),
        SousItemFractionnement(
          id: 'item_2',
          description: 'Restaurant',
          montant: 40.0,
          enveloppeId: 'env_2',
        ),
      ];

      final transactionFractionnee = TransactionFractionnee(
        transactionParenteId: 'trans_1',
        sousItems: sousItems,
        montantTotal: 100.0,
      );

      expect(transactionFractionnee.transactionParenteId, 'trans_1');
      expect(transactionFractionnee.sousItems.length, 2);
      expect(transactionFractionnee.montantTotal, 100.0);
      expect(transactionFractionnee.montantAlloue, 100.0);
      expect(transactionFractionnee.montantRestant, 0.0);
      expect(transactionFractionnee.estValide, true);
    });

    test('TransactionFractionnee with invalid total', () {
      final sousItems = [
        SousItemFractionnement(
          id: 'item_1',
          description: 'Épicerie',
          montant: 60.0,
          enveloppeId: 'env_1',
        ),
        SousItemFractionnement(
          id: 'item_2',
          description: 'Restaurant',
          montant: 40.0,
          enveloppeId: 'env_2',
        ),
      ];

      final transactionFractionnee = TransactionFractionnee(
        transactionParenteId: 'trans_1',
        sousItems: sousItems,
        montantTotal: 120.0, // Différent de la somme (100.0)
      );

      expect(transactionFractionnee.montantAlloue, 100.0);
      expect(transactionFractionnee.montantRestant, 20.0);
      expect(transactionFractionnee.estValide, false);
    });

    test('TransactionFractionnee with floating point precision', () {
      final sousItems = [
        SousItemFractionnement(
          id: 'item_1',
          description: 'Épicerie',
          montant: 33.33,
          enveloppeId: 'env_1',
        ),
        SousItemFractionnement(
          id: 'item_2',
          description: 'Restaurant',
          montant: 33.33,
          enveloppeId: 'env_2',
        ),
        SousItemFractionnement(
          id: 'item_3',
          description: 'Transport',
          montant: 33.34,
          enveloppeId: 'env_3',
        ),
      ];

      final transactionFractionnee = TransactionFractionnee(
        transactionParenteId: 'trans_1',
        sousItems: sousItems,
        montantTotal: 100.0,
      );

      expect(transactionFractionnee.montantAlloue, closeTo(100.0, 0.01));
      expect(transactionFractionnee.montantRestant, closeTo(0.0, 0.01));
      expect(transactionFractionnee.estValide, true);
    });

    test('TransactionFractionnee JSON serialization', () {
      final sousItems = [
        SousItemFractionnement(
          id: 'item_1',
          description: 'Épicerie',
          montant: 60.0,
          enveloppeId: 'env_1',
        ),
        SousItemFractionnement(
          id: 'item_2',
          description: 'Restaurant',
          montant: 40.0,
          enveloppeId: 'env_2',
        ),
      ];

      final transactionFractionnee = TransactionFractionnee(
        transactionParenteId: 'trans_1',
        sousItems: sousItems,
        montantTotal: 100.0,
      );

      final json = transactionFractionnee.toJson();
      expect(json['transactionParenteId'], 'trans_1');
      expect(json['montantTotal'], 100.0);
      expect(json['sousItems'], isA<List>());
      expect(json['sousItems'].length, 2);
    });

    test('TransactionFractionnee JSON deserialization', () {
      final json = {
        'transactionParenteId': 'trans_1',
        'montantTotal': 100.0,
        'sousItems': [
          {
            'id': 'item_1',
            'description': 'Épicerie',
            'montant': 60.0,
            'enveloppeId': 'env_1',
          },
          {
            'id': 'item_2',
            'description': 'Restaurant',
            'montant': 40.0,
            'enveloppeId': 'env_2',
          },
        ],
      };

      final transactionFractionnee = TransactionFractionnee.fromJson(json);
      expect(transactionFractionnee.transactionParenteId, 'trans_1');
      expect(transactionFractionnee.montantTotal, 100.0);
      expect(transactionFractionnee.sousItems.length, 2);
      expect(transactionFractionnee.estValide, true);
    });

    test('Empty TransactionFractionnee', () {
      final transactionFractionnee = TransactionFractionnee(
        transactionParenteId: 'trans_1',
        sousItems: [],
        montantTotal: 100.0,
      );

      expect(transactionFractionnee.montantAlloue, 0.0);
      expect(transactionFractionnee.montantRestant, 100.0);
      expect(transactionFractionnee.estValide, false);
    });
  });
}
