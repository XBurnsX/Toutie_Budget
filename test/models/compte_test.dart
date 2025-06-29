import 'package:flutter_test/flutter_test.dart';
import 'package:toutie_budget/models/compte.dart';

void main() {
  group('Compte Model Tests', () {
    test('Compte creation with all fields', () {
      final compte = Compte(
        id: 'compte_1',
        userId: 'user_123',
        nom: 'Compte Principal',
        type: 'Chèque',
        solde: 1500.75,
        couleur: 0xFF2196F3,
        pretAPlacer: 500.0,
        dateCreation: DateTime(2025, 1, 1),
        estArchive: false,
        dateSuppression: null,
        detteAssocieeId: null,
      );

      expect(compte.id, 'compte_1');
      expect(compte.nom, 'Compte Principal');
      expect(compte.type, 'Chèque');
      expect(compte.solde, 1500.75);
      expect(compte.pretAPlacer, 500.0);
      expect(compte.estArchive, false);
    });

    test('Compte creation with minimal fields', () {
      final compte = Compte(
        id: 'compte_2',
        nom: 'Compte Secondaire',
        type: 'Épargne',
        solde: 1000.0,
        couleur: 0xFF4CAF50,
        pretAPlacer: 200.0,
        dateCreation: DateTime(2025, 1, 1),
        estArchive: false,
      );

      expect(compte.userId, isNull);
      expect(compte.dateSuppression, isNull);
      expect(compte.detteAssocieeId, isNull);
    });

    test('Compte with debt association', () {
      final compte = Compte(
        id: 'compte_dette',
        nom: 'Prêt Personnel : Papa',
        type: 'Dette',
        solde: -500.0,
        couleur: 0xFFE53935,
        pretAPlacer: 0.0,
        dateCreation: DateTime(2025, 1, 1),
        estArchive: false,
        detteAssocieeId: 'dette_1',
      );

      expect(compte.detteAssocieeId, 'dette_1');
      expect(compte.solde, -500.0);
    });

    test('Compte toMap serialization', () {
      final compte = Compte(
        id: 'compte_1',
        userId: 'user_123',
        nom: 'Compte Principal',
        type: 'Chèque',
        solde: 1500.75,
        couleur: 0xFF2196F3,
        pretAPlacer: 500.0,
        dateCreation: DateTime(2025, 1, 1),
        estArchive: false,
        dateSuppression: null,
        detteAssocieeId: 'dette_1',
      );

      final map = compte.toMap();
      expect(map['userId'], 'user_123');
      expect(map['nom'], 'Compte Principal');
      expect(map['type'], 'Chèque');
      expect(map['solde'], 1500.75);
      expect(map['couleur'], 0xFF2196F3);
      expect(map['pretAPlacer'], 500.0);
      expect(map['estArchive'], false);
      expect(map['detteAssocieeId'], 'dette_1');
    });

    test('Compte fromMap deserialization', () {
      final map = {
        'userId': 'user_123',
        'nom': 'Compte Principal',
        'type': 'Chèque',
        'solde': 1500.75,
        'couleur': 0xFF2196F3,
        'pretAPlacer': 500.0,
        'dateCreation': '2025-01-01T00:00:00.000',
        'estArchive': false,
        'dateSuppression': null,
        'detteAssocieeId': 'dette_1',
      };

      final compte = Compte.fromMap(map, 'compte_1');
      expect(compte.id, 'compte_1');
      expect(compte.userId, 'user_123');
      expect(compte.nom, 'Compte Principal');
      expect(compte.type, 'Chèque');
      expect(compte.solde, 1500.75);
      expect(compte.couleur, 0xFF2196F3);
      expect(compte.pretAPlacer, 500.0);
      expect(compte.estArchive, false);
      expect(compte.detteAssocieeId, 'dette_1');
    });

    test('Compte fromMap with missing fields', () {
      final map = {'nom': 'Compte Test', 'type': 'Chèque', 'solde': 1000.0};

      final compte = Compte.fromMap(map, 'compte_test');
      expect(compte.id, 'compte_test');
      expect(compte.userId, isNull);
      expect(compte.nom, 'Compte Test');
      expect(compte.type, 'Chèque');
      expect(compte.solde, 1000.0);
      expect(compte.couleur, 0xFF2196F3); // Valeur par défaut
      expect(compte.pretAPlacer, 0.0); // Valeur par défaut
      expect(compte.estArchive, false); // Valeur par défaut
    });

    test('Compte equality', () {
      final compte1 = Compte(
        id: 'compte_1',
        nom: 'Compte Principal',
        type: 'Chèque',
        solde: 1000.0,
        couleur: 0xFF2196F3,
        pretAPlacer: 500.0,
        dateCreation: DateTime(2025, 1, 1),
        estArchive: false,
      );

      final compte2 = Compte(
        id: 'compte_1',
        nom: 'Compte Principal',
        type: 'Chèque',
        solde: 1000.0,
        couleur: 0xFF2196F3,
        pretAPlacer: 500.0,
        dateCreation: DateTime(2025, 1, 1),
        estArchive: false,
      );

      final compte3 = Compte(
        id: 'compte_2',
        nom: 'Compte Secondaire',
        type: 'Épargne',
        solde: 1000.0,
        couleur: 0xFF4CAF50,
        pretAPlacer: 500.0,
        dateCreation: DateTime(2025, 1, 1),
        estArchive: false,
      );

      expect(compte1, equals(compte2));
      expect(compte1, isNot(equals(compte3)));
    });

    test('Compte hashCode consistency', () {
      final compte1 = Compte(
        id: 'compte_1',
        nom: 'Compte Principal',
        type: 'Chèque',
        solde: 1000.0,
        couleur: 0xFF2196F3,
        pretAPlacer: 500.0,
        dateCreation: DateTime(2025, 1, 1),
        estArchive: false,
      );

      final compte2 = Compte(
        id: 'compte_1',
        nom: 'Compte Principal',
        type: 'Chèque',
        solde: 1000.0,
        couleur: 0xFF2196F3,
        pretAPlacer: 500.0,
        dateCreation: DateTime(2025, 1, 1),
        estArchive: false,
      );

      expect(compte1.hashCode, equals(compte2.hashCode));
    });

    test('Compte with archived status', () {
      final compte = Compte(
        id: 'compte_archive',
        nom: 'Ancien Compte',
        type: 'Chèque',
        solde: 0.0,
        couleur: 0xFF2196F3,
        pretAPlacer: 0.0,
        dateCreation: DateTime(2025, 1, 1),
        estArchive: true,
        dateSuppression: DateTime(2025, 6, 1),
      );

      expect(compte.estArchive, true);
      expect(compte.dateSuppression, isNotNull);
    });

    test('Compte types validation', () {
      final types = [
        'Chèque',
        'Épargne',
        'Carte de crédit',
        'Dette',
        'Investissement',
      ];

      for (final type in types) {
        final compte = Compte(
          id: 'compte_$type',
          nom: 'Compte $type',
          type: type,
          solde: 1000.0,
          couleur: 0xFF2196F3,
          pretAPlacer: 500.0,
          dateCreation: DateTime(2025, 1, 1),
          estArchive: false,
        );

        expect(compte.type, type);
      }
    });
  });
}
