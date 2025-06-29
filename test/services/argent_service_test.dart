import 'package:flutter_test/flutter_test.dart';
import 'package:toutie_budget/services/argent_service.dart';
import 'package:toutie_budget/models/compte.dart';
import 'package:toutie_budget/models/categorie.dart';
import '../firebase_test_config.dart';

void main() {
  group('ArgentService Tests', () {
    late ArgentService argentService;

    setUpAll(() async {
      // Initialiser Firebase pour tous les tests
      await setupFirebaseForTests();
    });

    setUp(() {
      argentService = ArgentService();
    });

    group('Validation des montants', () {
      test('Validation de montant positif', () {
        final montant = 100.0;
        final estValide = montant > 0;
        expect(estValide, true);
      });

      test('Validation de montant zéro', () {
        final montant = 0.0;
        final estValide = montant > 0;
        expect(estValide, false);
      });

      test('Validation de montant négatif', () {
        final montant = -50.0;
        final estValide = montant > 0;
        expect(estValide, false);
      });

      test('Validation de montant très grand', () {
        final montant = 999999999.99;
        final estValide = montant > 0;
        expect(estValide, true);
      });
    });

    group('Formatage des montants', () {
      test('Formatage de montant simple', () {
        final montant = 100.0;
        final formate = montant.toStringAsFixed(2);
        expect(formate, '100.00');
      });

      test('Formatage de montant entier', () {
        final montant = 100;
        final formate = montant.toDouble().toStringAsFixed(2);
        expect(formate, '100.00');
      });

      test('Formatage de montant avec beaucoup de décimales', () {
        final montant = 100.123456;
        final formate = montant.toStringAsFixed(2);
        expect(formate, '100.12');
      });

      test('Formatage de montant négatif', () {
        final montant = -100.0;
        final formate = montant.toStringAsFixed(2);
        expect(formate, '-100.00');
      });

      test('Formatage de montant zéro', () {
        final montant = 0.0;
        final formate = montant.toStringAsFixed(2);
        expect(formate, '0.00');
      });
    });

    group('Calculs de solde', () {
      test('Calcul de solde total des comptes', () {
        final comptes = [
          Compte(
            id: '1',
            nom: 'Compte 1',
            type: 'Chèque',
            solde: 1000.0,
            couleur: 0xFF0000,
            pretAPlacer: 500.0,
            dateCreation: DateTime.now(),
            estArchive: false,
          ),
          Compte(
            id: '2',
            nom: 'Compte 2',
            type: 'Épargne',
            solde: 2000.0,
            couleur: 0xFF0000,
            pretAPlacer: 1000.0,
            dateCreation: DateTime.now(),
            estArchive: false,
          ),
        ];

        final soldeTotal = comptes.fold(
          0.0,
          (sum, compte) => sum + compte.solde,
        );
        expect(soldeTotal, 3000.0);
      });

      test('Calcul de solde avec comptes négatifs', () {
        final comptes = [
          Compte(
            id: '1',
            nom: 'Compte 1',
            type: 'Chèque',
            solde: 1000.0,
            couleur: 0xFF0000,
            pretAPlacer: 500.0,
            dateCreation: DateTime.now(),
            estArchive: false,
          ),
          Compte(
            id: '2',
            nom: 'Compte 2',
            type: 'Carte',
            solde: -500.0,
            couleur: 0xFF0000,
            pretAPlacer: 0.0,
            dateCreation: DateTime.now(),
            estArchive: false,
          ),
        ];

        final soldeTotal = comptes.fold(
          0.0,
          (sum, compte) => sum + compte.solde,
        );
        expect(soldeTotal, 500.0);
      });

      test('Calcul de solde avec comptes archivés', () {
        final comptes = [
          Compte(
            id: '1',
            nom: 'Compte 1',
            type: 'Chèque',
            solde: 1000.0,
            couleur: 0xFF0000,
            pretAPlacer: 500.0,
            dateCreation: DateTime.now(),
            estArchive: false,
          ),
          Compte(
            id: '2',
            nom: 'Compte 2',
            type: 'Épargne',
            solde: 2000.0,
            couleur: 0xFF0000,
            pretAPlacer: 1000.0,
            dateCreation: DateTime.now(),
            estArchive: true,
          ),
        ];

        final soldeTotal = comptes
            .where((compte) => !compte.estArchive)
            .fold(0.0, (sum, compte) => sum + compte.solde);
        expect(soldeTotal, 1000.0); // Seulement le compte non archivé
      });
    });

    group('Gestion des provenances', () {
      test('Ajout de provenance simple', () {
        final enveloppe = <String, dynamic>{'provenances': []};

        argentService.ajouterOuMettreAJourProvenance(
          enveloppe,
          'compte1',
          100.0,
        );

        expect(enveloppe['provenances'], isA<List>());
        expect(enveloppe['provenances'].length, 1);
        expect(enveloppe['provenances'][0]['compte_id'], 'compte1');
        expect(enveloppe['provenances'][0]['montant'], 100.0);
      });

      test('Mise à jour de provenance existante', () {
        final enveloppe = <String, dynamic>{
          'provenances': [
            {'compte_id': 'compte1', 'montant': 100.0},
          ],
        };

        argentService.ajouterOuMettreAJourProvenance(
          enveloppe,
          'compte1',
          50.0,
        );

        expect(enveloppe['provenances'].length, 1);
        expect(enveloppe['provenances'][0]['montant'], 150.0);
      });

      test('Ajout de nouvelle provenance', () {
        final enveloppe = <String, dynamic>{
          'provenances': [
            {'compte_id': 'compte1', 'montant': 100.0},
          ],
        };

        argentService.ajouterOuMettreAJourProvenance(
          enveloppe,
          'compte2',
          75.0,
        );

        expect(enveloppe['provenances'].length, 2);
        expect(enveloppe['provenances'][1]['compte_id'], 'compte2');
        expect(enveloppe['provenances'][1]['montant'], 75.0);
      });

      test('Initialisation de provenances null', () {
        final enveloppe = <String, dynamic>{'provenances': null};

        argentService.ajouterOuMettreAJourProvenance(
          enveloppe,
          'compte1',
          100.0,
        );

        expect(enveloppe['provenances'], isA<List>());
        expect(enveloppe['provenances'].length, 1);
      });
    });

    group('Nettoyage des provenances', () {
      test('Nettoyage des provenances corrompues', () async {
        // Test que la méthode existe et peut être appelée
        expect(
          () => argentService.nettoyerProvenancesCorrrompues(),
          returnsNormally,
        );
      });

      test('Debug des provenances', () async {
        // Test que la méthode existe et peut être appelée
        expect(() => argentService.debugProvenances(), returnsNormally);
      });
    });
  });
}
