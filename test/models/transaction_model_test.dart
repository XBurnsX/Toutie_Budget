import 'package:flutter_test/flutter_test.dart';
import 'package:toutie_budget/models/transaction_model.dart';

void main() {
  group('Transaction Model Tests', () {
    test('TypeTransaction extensions work correctly', () {
      expect(TypeTransaction.depense.estDepense, true);
      expect(TypeTransaction.depense.estRevenu, false);
      expect(TypeTransaction.revenu.estDepense, false);
      expect(TypeTransaction.revenu.estRevenu, true);
    });

    test('TypeMouvementFinancier extensions work correctly', () {
      // Test des dépenses
      expect(TypeMouvementFinancier.depenseNormale.estDepense, true);
      expect(TypeMouvementFinancier.pretAccorde.estDepense, true);
      expect(TypeMouvementFinancier.remboursementEffectue.estDepense, true);

      // Test des revenus
      expect(TypeMouvementFinancier.revenuNormal.estRevenu, true);
      expect(TypeMouvementFinancier.remboursementRecu.estRevenu, true);
      expect(TypeMouvementFinancier.detteContractee.estRevenu, true);
    });

    test('Transaction creation and serialization', () {
      final transaction = Transaction(
        id: 'test_id',
        userId: 'user_123',
        type: TypeTransaction.depense,
        typeMouvement: TypeMouvementFinancier.depenseNormale,
        montant: 100.50,
        tiers: 'Épicerie',
        compteId: 'compte_1',
        date: DateTime(2025, 1, 15),
        enveloppeId: 'enveloppe_1',
        marqueur: 'Important',
        note: 'Test transaction',
        estFractionnee: false,
      );

      expect(transaction.id, 'test_id');
      expect(transaction.montant, 100.50);
      expect(transaction.tiers, 'Épicerie');
      expect(transaction.estFractionnee, false);
    });

    test('Transaction JSON serialization', () {
      final transaction = Transaction(
        id: 'test_id',
        userId: 'user_123',
        type: TypeTransaction.depense,
        typeMouvement: TypeMouvementFinancier.depenseNormale,
        montant: 100.50,
        tiers: 'Épicerie',
        compteId: 'compte_1',
        date: DateTime(2025, 1, 15),
        enveloppeId: 'enveloppe_1',
        marqueur: 'Important',
        note: 'Test transaction',
        estFractionnee: false,
      );

      final json = transaction.toJson();
      expect(json['id'], 'test_id');
      expect(json['type'], 'depense');
      expect(json['typeMouvement'], 'depenseNormale');
      expect(json['montant'], 100.50);
      expect(json['tiers'], 'Épicerie');
      expect(json['estFractionnee'], false);
    });

    test('Transaction JSON deserialization', () {
      final json = {
        'id': 'test_id',
        'userId': 'user_123',
        'type': 'depense',
        'typeMouvement': 'depenseNormale',
        'montant': 100.50,
        'tiers': 'Épicerie',
        'compteId': 'compte_1',
        'date': '2025-01-15T00:00:00.000',
        'enveloppeId': 'enveloppe_1',
        'marqueur': 'Important',
        'note': 'Test transaction',
        'estFractionnee': false,
      };

      final transaction = Transaction.fromJson(json);
      expect(transaction.id, 'test_id');
      expect(transaction.type, TypeTransaction.depense);
      expect(transaction.typeMouvement, TypeMouvementFinancier.depenseNormale);
      expect(transaction.montant, 100.50);
      expect(transaction.tiers, 'Épicerie');
      expect(transaction.estFractionnee, false);
    });

    test('Transaction with fractionnement', () {
      final transaction = Transaction(
        id: 'test_id',
        userId: 'user_123',
        type: TypeTransaction.depense,
        typeMouvement: TypeMouvementFinancier.depenseNormale,
        montant: 100.0,
        tiers: 'Épicerie',
        compteId: 'compte_1',
        date: DateTime(2025, 1, 15),
        estFractionnee: true,
        sousItems: [
          {'id': 'item1', 'montant': 60.0, 'enveloppeId': 'env1'},
          {'id': 'item2', 'montant': 40.0, 'enveloppeId': 'env2'},
        ],
      );

      expect(transaction.estFractionnee, true);
      expect(transaction.sousItems, isNotNull);
      expect(transaction.sousItems!.length, 2);
    });
  });
}
