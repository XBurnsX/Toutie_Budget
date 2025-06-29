import 'package:flutter_test/flutter_test.dart';
import 'package:toutie_budget/models/categorie.dart';
import '../test_config.dart';

void main() {
  group('Categorie Model Tests', () {
    test('Categorie creation with all fields', () {
      final enveloppes = [
        Enveloppe(
          id: 'env_1',
          nom: 'Épicerie',
          solde: 400.0,
          objectif: 500.0,
          depense: 100.0,
          archivee: false,
        ),
        Enveloppe(
          id: 'env_2',
          nom: 'Transport',
          solde: 200.0,
          objectif: 300.0,
          depense: 50.0,
          archivee: false,
        ),
      ];

      final categorie = Categorie(
        id: 'cat_1',
        userId: 'user_123',
        nom: 'Essentiels',
        enveloppes: enveloppes,
      );

      expect(categorie.id, 'cat_1');
      expect(categorie.userId, 'user_123');
      expect(categorie.nom, 'Essentiels');
      expect(categorie.enveloppes, hasLength(2));
      expect(categorie.enveloppes.first.nom, 'Épicerie');
      expect(categorie.enveloppes.last.nom, 'Transport');
    });

    test('Categorie creation with minimal fields', () {
      final categorie = Categorie(id: 'cat_2', nom: 'Loisirs', enveloppes: []);

      expect(categorie.userId, isNull);
      expect(categorie.enveloppes, isEmpty);
    });

    test('Categorie toMap serialization', () {
      final enveloppes = [
        Enveloppe(
          id: 'env_1',
          nom: 'Épicerie',
          solde: 400.0,
          objectif: 500.0,
          depense: 100.0,
          archivee: false,
        ),
      ];

      final categorie = Categorie(
        id: 'cat_1',
        userId: 'user_123',
        nom: 'Essentiels',
        enveloppes: enveloppes,
      );

      final map = categorie.toMap();
      expect(map['userId'], 'user_123');
      expect(map['nom'], 'Essentiels');
      expect(map['enveloppes'], hasLength(1));
      expect(map['enveloppes'][0]['nom'], 'Épicerie');
    });

    test('Categorie fromMap deserialization', () {
      final map = {
        'userId': 'user_123',
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
        ],
      };

      final categorie = Categorie.fromMap(map, 'cat_1');
      expect(categorie.id, 'cat_1');
      expect(categorie.userId, 'user_123');
      expect(categorie.nom, 'Essentiels');
      expect(categorie.enveloppes, hasLength(1));
      expect(categorie.enveloppes.first.nom, 'Épicerie');
    });

    test('Categorie fromMap with missing fields', () {
      final map = {'nom': 'Test Catégorie', 'enveloppes': []};

      final categorie = Categorie.fromMap(map, 'cat_test');
      expect(categorie.id, 'cat_test');
      expect(categorie.userId, isNull);
      expect(categorie.nom, 'Test Catégorie');
      expect(categorie.enveloppes, isEmpty);
    });

    test('Categorie equality', () {
      final enveloppes = [
        Enveloppe(
          id: 'env_1',
          nom: 'Épicerie',
          solde: 400.0,
          objectif: 500.0,
          depense: 100.0,
          archivee: false,
        ),
      ];

      final categorie1 = Categorie(
        id: 'cat_1',
        nom: 'Essentiels',
        enveloppes: enveloppes,
      );

      final categorie2 = Categorie(
        id: 'cat_1',
        nom: 'Essentiels',
        enveloppes: enveloppes,
      );

      final categorie3 = Categorie(id: 'cat_2', nom: 'Loisirs', enveloppes: []);

      expect(categorie1, equals(categorie2));
      expect(categorie1, isNot(equals(categorie3)));
    });

    test('Categorie hashCode consistency', () {
      final enveloppes = [
        Enveloppe(
          id: 'env_1',
          nom: 'Épicerie',
          solde: 400.0,
          objectif: 500.0,
          depense: 100.0,
          archivee: false,
        ),
      ];

      final categorie1 = Categorie(
        id: 'cat_1',
        nom: 'Essentiels',
        enveloppes: enveloppes,
      );

      final categorie2 = Categorie(
        id: 'cat_1',
        nom: 'Essentiels',
        enveloppes: enveloppes,
      );

      expect(categorie1.hashCode, equals(categorie2.hashCode));
    });

    test('Categorie with archived enveloppes', () {
      final enveloppes = [
        Enveloppe(
          id: 'env_1',
          nom: 'Épicerie',
          solde: 0.0,
          objectif: 500.0,
          depense: 500.0,
          archivee: true,
        ),
      ];

      final categorie = Categorie(
        id: 'cat_1',
        nom: 'Essentiels',
        enveloppes: enveloppes,
      );

      expect(categorie.enveloppes.first.archivee, isTrue);
      expect(categorie.enveloppes.first.solde, 0.0);
    });

    test('Categorie total calculations', () {
      final enveloppes = [
        Enveloppe(
          id: 'env_1',
          nom: 'Épicerie',
          solde: 400.0,
          objectif: 500.0,
          depense: 100.0,
          archivee: false,
        ),
        Enveloppe(
          id: 'env_2',
          nom: 'Transport',
          solde: 200.0,
          objectif: 300.0,
          depense: 50.0,
          archivee: false,
        ),
      ];

      final categorie = Categorie(
        id: 'cat_1',
        nom: 'Essentiels',
        enveloppes: enveloppes,
      );

      // Calculer le total des soldes
      final totalSolde = categorie.enveloppes.fold<double>(
        0.0,
        (sum, env) => sum + env.solde,
      );

      // Calculer le total des objectifs
      final totalObjectif = categorie.enveloppes.fold<double>(
        0.0,
        (sum, env) => sum + env.objectif,
      );

      // Calculer le total des dépenses
      final totalDepense = categorie.enveloppes.fold<double>(
        0.0,
        (sum, env) => sum + env.depense,
      );

      expect(totalSolde, 600.0);
      expect(totalObjectif, 800.0);
      expect(totalDepense, 150.0);
    });

    test('Categorie with enveloppes containing objectifs', () {
      final enveloppes = [
        Enveloppe(
          id: 'env_1',
          nom: 'Vacances',
          solde: 800.0,
          objectif: 2000.0,
          depense: 0.0,
          archivee: false,
          objectifDate: '2025-12-31T00:00:00.000',
          frequenceObjectif: 'date',
          objectifJour: 15,
        ),
      ];

      final categorie = Categorie(
        id: 'cat_1',
        nom: 'Épargne',
        enveloppes: enveloppes,
      );

      expect(categorie.enveloppes.first.objectifDate, isNotNull);
      expect(categorie.enveloppes.first.frequenceObjectif, 'date');
      expect(categorie.enveloppes.first.objectifJour, 15);
    });
  });
}
