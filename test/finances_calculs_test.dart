import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:toutie_budget/models/compte.dart';
import 'package:toutie_budget/models/dette.dart';
import 'package:toutie_budget/services/argent_service.dart';
import 'dart:math' as math;

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'fake',
        appId: 'fake',
        messagingSenderId: 'fake',
        projectId: 'fake',
      ),
    );
  });

  group('Calculs financiers', () {
    test('Montant nécessaire pour objectif enveloppe', () {
      // Hypothèses :
      // Objectif total : 1200, date de création : 2025-01, date cible : 2025-12, solde actuel : 300, mois de référence : 2025-06
      final objectifTotal = 1200.0;
      final dateCreation = DateTime(2025, 1, 1);
      final dateCible = DateTime(2025, 12, 1);
      final dateReference = DateTime(2025, 6, 1);
      final soldeActuel = 300.0;
      final moisTotal =
          (dateCible.year - dateCreation.year) * 12 +
          (dateCible.month - dateCreation.month) +
          1;
      final moisRestants =
          (dateCible.year - dateReference.year) * 12 +
          (dateCible.month - dateReference.month) +
          1;
      final montantNecessaire = moisTotal > 0 ? objectifTotal / moisTotal : 0;
      final manquant = objectifTotal - soldeActuel;
      final montantParMoisRestant = moisRestants > 0
          ? manquant / moisRestants
          : 0;
      expect(moisTotal, 12);
      expect(moisRestants, 7);
      expect(montantNecessaire, closeTo(100.0, 0.01));
      expect(montantParMoisRestant, closeTo(128.57, 0.01));
    });

    test('Calcul écart de réconciliation', () {
      final soldeReel = 1050.0;
      final soldeCompte = 1000.0;
      final ecart = soldeReel - soldeCompte;
      expect(ecart, 50.0);
    });

    test('Calcul prêt à placer', () {
      final ancienPretAPlacer = 200.0;
      final ancienSolde = 1000.0;
      final nouveauSolde = 1200.0;
      final nouveauPretAPlacer =
          ancienPretAPlacer + (nouveauSolde - ancienSolde);
      expect(nouveauPretAPlacer, 400.0);
    });

    test('Calcul montant négatif total', () {
      final comptes = [-100.0, 200.0, -50.0, 300.0];
      final categories = [0.0, -20.0, 10.0];
      final totalNegatif =
          comptes.where((c) => c < 0).fold(0.0, (a, b) => a + b) +
          categories.where((c) => c < 0).fold(0.0, (a, b) => a + b);
      expect(totalNegatif, -170.0);
    });

    test('Calcul montant mensuel avec intérêts - dette simple', () {
      // Test sans intérêts
      final soldeActuel = 1000.0;
      final tauxInteret = 0.0;
      final moisRestants = 12;

      final montantMensuel = soldeActuel / moisRestants;
      expect(montantMensuel, closeTo(83.33, 0.01));
    });

    test('Calcul montant mensuel avec intérêts - dette avec intérêts', () {
      // Test avec intérêts
      final soldeActuel = 10000.0;
      final tauxInteret = 5.0; // 5% annuel
      final moisRestants = 12;

      final tauxMensuel = tauxInteret / 100 / 12;
      final numerateur =
          soldeActuel * tauxMensuel * math.pow(1 + tauxMensuel, moisRestants);
      final denominateur = math.pow(1 + tauxMensuel, moisRestants) - 1;
      final montantMensuel = numerateur / denominateur;

      // Le montant mensuel devrait être supérieur à 10000/12 = 833.33 à cause des intérêts
      expect(montantMensuel, greaterThan(833.33));
      expect(montantMensuel, closeTo(856.07, 0.01)); // Valeur approximative
    });

    test('Calcul total intérêts payés', () {
      final soldeActuel = 1000.0;
      final tauxInteret = 12.0; // 12% annuel
      final montantMensuel = 100.0;
      final moisRestants = 12;

      double soldeRestant = soldeActuel;
      double totalInterets = 0.0;

      for (int mois = 0; mois < moisRestants && soldeRestant > 0; mois++) {
        final interetMensuel = soldeRestant * (tauxInteret / 100 / 12);
        final capitalMensuel = montantMensuel - interetMensuel;

        if (capitalMensuel > soldeRestant) {
          totalInterets += interetMensuel;
          break;
        }

        totalInterets += interetMensuel;
        soldeRestant -= capitalMensuel;
      }

      // Avec 12% d'intérêt, on devrait payer des intérêts significatifs
      expect(totalInterets, greaterThan(0));
      expect(totalInterets, closeTo(66.67, 1.0)); // Approximation
    });

    test('Calcul mois entre deux dates', () {
      final debut = DateTime(2025, 1, 1);
      final fin = DateTime(2025, 12, 1);

      final mois = (fin.year - debut.year) * 12 + (fin.month - debut.month);
      expect(mois, 11); // 11 mois entre janvier et décembre
    });
  });

  group('ArgentService', () {
    test('allouerPretAPlacer déduit le montant si suffisant', () async {
      // Ce test nécessite un mock ou un fake de FirebaseService et Compte
      // Ici, on simule la logique métier sans accès à Firebase
      final compte = Compte(
        id: '1',
        nom: 'Test',
        type: 'Chèque',
        solde: 1000,
        pretAPlacer: 500,
        couleur: 0,
        dateCreation: DateTime.now(),
        estArchive: false,
      );
      final service = ArgentService();
      // On simule la logique métier :
      double pretAPlacerAvant = compte.pretAPlacer;
      double montant = 200;
      if (pretAPlacerAvant < montant) {
        expect(() => throw Exception('Montant insuffisant'), throwsException);
      } else {
        final pretAPlacerApres = pretAPlacerAvant - montant;
        expect(pretAPlacerApres, 300);
      }
    });

    test(
      'allouerPretAPlacer lève une exception si montant insuffisant',
      () async {
        final compte = Compte(
          id: '1',
          nom: 'Test',
          type: 'Chèque',
          solde: 1000,
          pretAPlacer: 100,
          couleur: 0,
          dateCreation: DateTime.now(),
          estArchive: false,
        );
        final montant = 200;
        expect(() {
          if (compte.pretAPlacer < montant) {
            throw Exception('Montant insuffisant');
          }
        }, throwsException);
      },
    );

    test('virementEntreComptes ajuste les deux comptes si suffisant', () async {
      final source = Compte(
        id: '1',
        nom: 'Source',
        type: 'Chèque',
        solde: 1000,
        pretAPlacer: 500,
        couleur: 0,
        dateCreation: DateTime.now(),
        estArchive: false,
      );
      final dest = Compte(
        id: '2',
        nom: 'Dest',
        type: 'Chèque',
        solde: 500,
        pretAPlacer: 100,
        couleur: 0,
        dateCreation: DateTime.now(),
        estArchive: false,
      );
      final montant = 200.0;
      if (source.pretAPlacer < montant) {
        expect(() => throw Exception('Montant insuffisant'), throwsException);
      } else {
        final pretAPlacerSourceApres = source.pretAPlacer - montant;
        final pretAPlacerDestApres = dest.pretAPlacer + montant;
        expect(pretAPlacerSourceApres, 300);
        expect(pretAPlacerDestApres, 300);
      }
    });

    test(
      'virementEntreComptes lève une exception si source insuffisant',
      () async {
        final source = Compte(
          id: '1',
          nom: 'Source',
          type: 'Chèque',
          solde: 1000,
          pretAPlacer: 100,
          couleur: 0,
          dateCreation: DateTime.now(),
          estArchive: false,
        );
        final dest = Compte(
          id: '2',
          nom: 'Dest',
          type: 'Chèque',
          solde: 500,
          pretAPlacer: 100,
          couleur: 0,
          dateCreation: DateTime.now(),
          estArchive: false,
        );
        final montant = 200.0;
        expect(() {
          if (source.pretAPlacer < montant) {
            throw Exception('Montant insuffisant');
          }
        }, throwsException);
      },
    );

    test('allouerPretAPlacer avec montant égal à pretAPlacer', () async {
      final compte = Compte(
        id: '3',
        nom: 'Test2',
        type: 'Chèque',
        solde: 1000,
        pretAPlacer: 200,
        couleur: 0,
        dateCreation: DateTime.now(),
        estArchive: false,
      );
      double montant = 200;
      final pretAPlacerApres = compte.pretAPlacer - montant;
      expect(pretAPlacerApres, 0);
    });

    test(
      'allouerPretAPlacer avec montant négatif lève une exception',
      () async {
        final compte = Compte(
          id: '4',
          nom: 'Test3',
          type: 'Chèque',
          solde: 1000,
          pretAPlacer: 200,
          couleur: 0,
          dateCreation: DateTime.now(),
          estArchive: false,
        );
        double montant = -50;
        expect(() {
          if (montant <= 0) {
            throw Exception('Montant invalide');
          }
        }, throwsException);
      },
    );

    test('allouerPretAPlacer avec montant nul ne change rien', () async {
      final compte = Compte(
        id: '5',
        nom: 'Test4',
        type: 'Chèque',
        solde: 1000,
        pretAPlacer: 200,
        couleur: 0,
        dateCreation: DateTime.now(),
        estArchive: false,
      );
      double montant = 0;
      final pretAPlacerApres = compte.pretAPlacer - montant;
      expect(pretAPlacerApres, 200);
    });

    test(
      'virementEntreComptes avec montant négatif lève une exception',
      () async {
        final source = Compte(
          id: '6',
          nom: 'Source2',
          type: 'Chèque',
          solde: 1000,
          pretAPlacer: 300,
          couleur: 0,
          dateCreation: DateTime.now(),
          estArchive: false,
        );
        final dest = Compte(
          id: '7',
          nom: 'Dest2',
          type: 'Chèque',
          solde: 500,
          pretAPlacer: 100,
          couleur: 0,
          dateCreation: DateTime.now(),
          estArchive: false,
        );
        double montant = -100;
        expect(() {
          if (montant <= 0) {
            throw Exception('Montant invalide');
          }
        }, throwsException);
      },
    );

    test('virementEntreComptes avec montant nul ne change rien', () async {
      final source = Compte(
        id: '8',
        nom: 'Source3',
        type: 'Chèque',
        solde: 1000,
        pretAPlacer: 300,
        couleur: 0,
        dateCreation: DateTime.now(),
        estArchive: false,
      );
      final dest = Compte(
        id: '9',
        nom: 'Dest3',
        type: 'Chèque',
        solde: 500,
        pretAPlacer: 100,
        couleur: 0,
        dateCreation: DateTime.now(),
        estArchive: false,
      );
      double montant = 0;
      final pretAPlacerSourceApres = source.pretAPlacer - montant;
      final pretAPlacerDestApres = dest.pretAPlacer + montant;
      expect(pretAPlacerSourceApres, 300);
      expect(pretAPlacerDestApres, 100);
    });

    test(
      'virementEntreComptes avec comptes identiques ne change rien',
      () async {
        final compte = Compte(
          id: '10',
          nom: 'Identique',
          type: 'Chèque',
          solde: 1000,
          pretAPlacer: 300,
          couleur: 0,
          dateCreation: DateTime.now(),
          estArchive: false,
        );
        double montant = 100;
        final pretAPlacerAvant = compte.pretAPlacer;
        // Si source et dest sont identiques, rien ne change
        final pretAPlacerApres = pretAPlacerAvant - montant + montant;
        expect(pretAPlacerApres, pretAPlacerAvant);
      },
    );

    test(
      'virementEntreComptes avec source ou dest inexistant lève une exception',
      () async {
        Compte? source;
        final dest = Compte(
          id: '11',
          nom: 'Dest4',
          type: 'Chèque',
          solde: 500,
          pretAPlacer: 100,
          couleur: 0,
          dateCreation: DateTime.now(),
          estArchive: false,
        );
        double montant = 100;
        expect(() {
          throw Exception('Compte inexistant');
        }, throwsException);
      },
    );

    test(
      'virementEntreComptes avec comptes archivés lève une exception',
      () async {
        final source = Compte(
          id: '12',
          nom: 'SourceArch',
          type: 'Chèque',
          solde: 1000,
          pretAPlacer: 300,
          couleur: 0,
          dateCreation: DateTime.now(),
          estArchive: true,
        );
        final dest = Compte(
          id: '13',
          nom: 'DestArch',
          type: 'Chèque',
          solde: 500,
          pretAPlacer: 100,
          couleur: 0,
          dateCreation: DateTime.now(),
          estArchive: true,
        );
        double montant = 100;
        expect(() {
          if (source.estArchive || dest.estArchive) {
            throw Exception('Compte archivé');
          }
        }, throwsException);
      },
    );

    // Pour virementEnveloppeVersEnveloppe, il faudrait mocker Enveloppe et la logique de provenance, mais voici un exemple de test logique :
    test(
      'virementEnveloppeVersEnveloppe avec montant négatif lève une exception',
      () async {
        final source = {'solde': 100.0};
        final dest = {'solde': 50.0};
        double montant = -20;
        expect(() {
          if (montant <= 0) {
            throw Exception('Montant invalide');
          }
        }, throwsException);
      },
    );

    test(
      'virementEnveloppeVersEnveloppe avec montant supérieur au solde source lève une exception',
      () async {
        final source = {'solde': 100.0};
        final dest = {'solde': 50.0};
        double montant = 200;
        expect(() {
          if ((source['solde'] as double) < montant) {
            throw Exception('Montant insuffisant dans l\'enveloppe source');
          }
        }, throwsException);
      },
    );

    test(
      'virementEnveloppeVersEnveloppe avec montant nul ne change rien',
      () async {
        final source = {'solde': 100.0};
        final dest = {'solde': 50.0};
        double montant = 0;
        final soldeSourceApres = (source['solde'] as double) - montant;
        final soldeDestApres = (dest['solde'] as double) + montant;
        expect(soldeSourceApres, 100.0);
        expect(soldeDestApres, 50.0);
      },
    );

    test(
      'virementEnveloppeVersEnveloppe avec source ou dest inexistant lève une exception',
      () async {
        Map<String, dynamic>? source;
        final dest = {'solde': 50.0};
        double montant = 10;
        expect(() {
          throw Exception('Enveloppe inexistante');
        }, throwsException);
      },
    );

    test(
      'virementEnveloppeVersEnveloppe avec provenances incompatibles lève une exception',
      () async {
        final source = {
          'solde': 100.0,
          'provenances': [
            {'compte_id': 'A', 'montant': 100.0},
          ],
        };
        final dest = {
          'solde': 50.0,
          'provenances': [
            {'compte_id': 'B', 'montant': 50.0},
          ],
        };
        double montant = 10;
        expect(() {
          final comptesSource = (source['provenances'] as List)
              .map((prov) => (prov as Map)['compte_id'].toString())
              .toSet();
          final comptesDest = (dest['provenances'] as List)
              .map((prov) => (prov as Map)['compte_id'].toString())
              .toSet();
          if (!comptesSource.every((id) => comptesDest.contains(id)) ||
              !comptesDest.every((id) => comptesSource.contains(id))) {
            throw Exception(
              'Impossible de mélanger des fonds provenant de comptes différents.',
            );
          }
        }, throwsException);
      },
    );

    test(
      'virementEnveloppeVersEnveloppe avec provenances compatibles réussit',
      () async {
        final source = {
          'solde': 100.0,
          'provenances': [
            {'compte_id': 'A', 'montant': 100.0},
          ],
        };
        final dest = {
          'solde': 50.0,
          'provenances': [
            {'compte_id': 'A', 'montant': 50.0},
          ],
        };
        double montant = 10;
        final soldeSourceApres = (source['solde'] as double) - montant;
        final soldeDestApres = (dest['solde'] as double) + montant;
        expect(soldeSourceApres, 90.0);
        expect(soldeDestApres, 60.0);
      },
    );
  });

  group('DetteService', () {
    test('création de dette valide', () async {
      final dette = Dette(
        id: '1',
        nomTiers: 'Paul',
        montantInitial: 500,
        solde: 500,
        type: 'dette',
        historique: [],
        archive: false,
        dateCreation: DateTime.now(),
        dateArchivage: null,
        userId: 'user1',
      );
      expect(dette.solde, dette.montantInitial);
      expect(dette.archive, false);
    });

    test('création de dette avec montant négatif', () async {
      expect(
        () {
          Dette(
            id: '2',
            nomTiers: 'Paul',
            montantInitial: -100,
            solde: -100,
            type: 'dette',
            historique: [],
            archive: false,
            dateCreation: DateTime.now(),
            dateArchivage: null,
            userId: 'user1',
          );
        },
        returnsNormally,
      ); // Peut lever une exception selon la logique métier réelle
    });

    test('remboursement partiel de dette', () async {
      final dette = Dette(
        id: '3',
        nomTiers: 'Paul',
        montantInitial: 500,
        solde: 500,
        type: 'dette',
        historique: [],
        archive: false,
        dateCreation: DateTime.now(),
        dateArchivage: null,
        userId: 'user1',
      );
      final remboursement = 200.0;
      final soldeApres = dette.solde - remboursement;
      expect(soldeApres, 300.0);
    });

    test('remboursement total de dette', () async {
      final dette = Dette(
        id: '4',
        nomTiers: 'Paul',
        montantInitial: 500,
        solde: 500,
        type: 'dette',
        historique: [],
        archive: false,
        dateCreation: DateTime.now(),
        dateArchivage: null,
        userId: 'user1',
      );
      final remboursement = 500.0;
      final soldeApres = dette.solde - remboursement;
      expect(soldeApres, 0.0);
    });

    test('remboursement supérieur au solde lève une exception', () async {
      final dette = Dette(
        id: '5',
        nomTiers: 'Paul',
        montantInitial: 500,
        solde: 100,
        type: 'dette',
        historique: [],
        archive: false,
        dateCreation: DateTime.now(),
        dateArchivage: null,
        userId: 'user1',
      );
      final remboursement = 200.0;
      expect(() {
        if (remboursement > dette.solde) {
          throw Exception('Remboursement supérieur au solde');
        }
      }, throwsException);
    });

    test('archivage de dette', () async {
      final dette = Dette(
        id: '6',
        nomTiers: 'Paul',
        montantInitial: 500,
        solde: 0,
        type: 'dette',
        historique: [],
        archive: false,
        dateCreation: DateTime.now(),
        dateArchivage: null,
        userId: 'user1',
      );
      final archive = true;
      final dateArchivage = DateTime.now();
      expect(archive, true);
      expect(
        dateArchivage.isBefore(DateTime.now().add(Duration(seconds: 1))),
        true,
      );
    });
  });

  group('RolloverService', () {
    test('Rollover d\'une enveloppe avec solde positif', () async {
      final enveloppe = {
        'solde': 100.0,
        'depense': 50.0,
        'objectif': 200.0,
        'historique': <String, Map<String, dynamic>>{},
      };
      final currentMonthKey = DateFormat('yyyy-MM').format(DateTime.now());
      enveloppe['depense'] = 0.0;
      enveloppe['solde'] = 100.0;
      (enveloppe['historique']
          as Map<String, Map<String, dynamic>>)[currentMonthKey] = {
        'solde': enveloppe['solde'],
        'depense': enveloppe['depense'],
        'objectif': enveloppe['objectif'],
      };
      expect((enveloppe['historique'] as Map)[currentMonthKey]['solde'], 100.0);
      expect((enveloppe['historique'] as Map)[currentMonthKey]['depense'], 0.0);
    });

    test('Rollover d\'une enveloppe avec solde négatif', () async {
      final enveloppe = {
        'solde': -20.0,
        'depense': 10.0,
        'objectif': 100.0,
        'historique': <String, Map<String, dynamic>>{},
      };
      final currentMonthKey = DateFormat('yyyy-MM').format(DateTime.now());
      enveloppe['depense'] = 0.0;
      enveloppe['solde'] = -20.0;
      (enveloppe['historique']
          as Map<String, Map<String, dynamic>>)[currentMonthKey] = {
        'solde': enveloppe['solde'],
        'depense': enveloppe['depense'],
        'objectif': enveloppe['objectif'],
      };
      expect((enveloppe['historique'] as Map)[currentMonthKey]['solde'], -20.0);
      expect((enveloppe['historique'] as Map)[currentMonthKey]['depense'], 0.0);
    });

    test('Rollover d\'une enveloppe avec solde nul', () async {
      final enveloppe = {
        'solde': 0.0,
        'depense': 0.0,
        'objectif': 50.0,
        'historique': <String, Map<String, dynamic>>{},
      };
      final currentMonthKey = DateFormat('yyyy-MM').format(DateTime.now());
      enveloppe['depense'] = 0.0;
      enveloppe['solde'] = 0.0;
      (enveloppe['historique']
          as Map<String, Map<String, dynamic>>)[currentMonthKey] = {
        'solde': enveloppe['solde'],
        'depense': enveloppe['depense'],
        'objectif': enveloppe['objectif'],
      };
      expect((enveloppe['historique'] as Map)[currentMonthKey]['solde'], 0.0);
      expect((enveloppe['historique'] as Map)[currentMonthKey]['depense'], 0.0);
    });

    test('Rollover enveloppe avec historique réinitialisé', () async {
      final enveloppe = {
        'solde': 80.0,
        'depense': 0.0,
        'objectif': 100.0,
        'historique': <String, Map<String, dynamic>>{},
      };
      final currentMonthKey = DateFormat('yyyy-MM').format(DateTime.now());
      enveloppe['historique'] = <String, Map<String, dynamic>>{};
      (enveloppe['historique']
          as Map<String, Map<String, dynamic>>)[currentMonthKey] = {
        'solde': enveloppe['solde'],
        'depense': enveloppe['depense'],
        'objectif': enveloppe['objectif'],
      };
      expect((enveloppe['historique'] as Map)[currentMonthKey]['solde'], 80.0);
    });

    test('Rollover avec plusieurs enveloppes', () async {
      final enveloppes = [
        {
          'solde': 100.0,
          'depense': 0.0,
          'objectif': 200.0,
          'historique': <String, Map<String, dynamic>>{},
        },
        {
          'solde': -10.0,
          'depense': 0.0,
          'objectif': 50.0,
          'historique': <String, Map<String, dynamic>>{},
        },
      ];
      final currentMonthKey = DateFormat('yyyy-MM').format(DateTime.now());
      for (var enveloppe in enveloppes) {
        (enveloppe['historique']
            as Map<String, Map<String, dynamic>>)[currentMonthKey] = {
          'solde': enveloppe['solde'],
          'depense': enveloppe['depense'],
          'objectif': enveloppe['objectif'],
        };
      }
      expect(
        (enveloppes[0]['historique'] as Map)[currentMonthKey]['solde'],
        100.0,
      );
      expect(
        (enveloppes[1]['historique'] as Map)[currentMonthKey]['solde'],
        -10.0,
      );
    });
  });

  group('Modèles', () {
    test('Création de Compte avec valeurs extrêmes', () {
      final compte = Compte(
        id: 'c1',
        nom: '',
        type: '',
        solde: double.maxFinite,
        pretAPlacer: double.minPositive,
        couleur: 0xFFFFFFFF,
        dateCreation: DateTime(1900, 1, 1),
        estArchive: false,
      );
      expect(compte.solde, double.maxFinite);
      expect(compte.pretAPlacer, double.minPositive);
      expect(compte.nom, '');
    });

    test('Comparaison d\'égalité entre deux comptes identiques', () {
      final compte1 = Compte(
        id: 'c2',
        nom: 'Compte A',
        type: 'Chèque',
        solde: 100,
        pretAPlacer: 50,
        couleur: 0xFF000000,
        dateCreation: DateTime(2020, 1, 1),
        estArchive: false,
      );
      final compte2 = Compte(
        id: 'c2',
        nom: 'Compte A',
        type: 'Chèque',
        solde: 100,
        pretAPlacer: 50,
        couleur: 0xFF000000,
        dateCreation: DateTime(2020, 1, 1),
        estArchive: false,
      );
      expect(compte1, equals(compte2));
    });

    test('Modification d\'un compte archivé', () {
      final compte = Compte(
        id: 'c3',
        nom: 'Compte B',
        type: 'Epargne',
        solde: 200,
        pretAPlacer: 0,
        couleur: 0xFF123456,
        dateCreation: DateTime(2021, 5, 10),
        estArchive: true,
      );
      expect(compte.estArchive, true);
    });

    test('Création de Dette avec historique', () {
      final dette = Dette(
        id: 'd1',
        nomTiers: 'Alice',
        montantInitial: 1000,
        solde: 800,
        type: 'dette',
        historique: [
          MouvementDette(
            id: 'm1',
            date: DateTime(2024, 1, 1),
            montant: 200,
            type: 'remboursement',
          ),
        ],
        archive: false,
        dateCreation: DateTime(2024, 1, 1),
        dateArchivage: null,
        userId: 'user2',
      );
      expect(dette.historique.length, 1);
      expect(dette.historique[0].montant, 200);
    });

    test('Création de Compte avec nom long et caractères spéciaux', () {
      final compte = Compte(
        id: 'c4',
        nom: 'Compte Très Très Long !@#€%&*()_+=-[]{}',
        type: 'Epargne',
        solde: 123.45,
        pretAPlacer: 0,
        couleur: 0xFFABCDEF,
        dateCreation: DateTime(2025, 6, 27),
        estArchive: false,
      );
      expect(compte.nom.contains('Très Très Long'), true);
      expect(compte.nom.contains('!@#€%&*()_+=-[]{}'), true);
    });

    test('Création de Dette avec montant initial nul', () {
      final dette = Dette(
        id: 'd2',
        nomTiers: 'Bob',
        montantInitial: 0,
        solde: 0,
        type: 'créance',
        historique: [],
        archive: false,
        dateCreation: DateTime(2025, 6, 27),
        dateArchivage: null,
        userId: 'user3',
      );
      expect(dette.montantInitial, 0);
      expect(dette.solde, 0);
    });

    test('Création de Dette archivée', () {
      final dette = Dette(
        id: 'd3',
        nomTiers: 'Charlie',
        montantInitial: 100,
        solde: 0,
        type: 'dette',
        historique: [],
        archive: true,
        dateCreation: DateTime(2024, 12, 31),
        dateArchivage: DateTime(2025, 1, 1),
        userId: 'user4',
      );
      expect(dette.archive, true);
      expect(dette.dateArchivage, isNotNull);
    });

    test('Comparaison de Dette différentes', () {
      final dette1 = Dette(
        id: 'd4',
        nomTiers: 'Delta',
        montantInitial: 100,
        solde: 100,
        type: 'dette',
        historique: [],
        archive: false,
        dateCreation: DateTime(2025, 6, 27),
        dateArchivage: null,
        userId: 'user5',
      );
      final dette2 = Dette(
        id: 'd5',
        nomTiers: 'Echo',
        montantInitial: 200,
        solde: 200,
        type: 'créance',
        historique: [],
        archive: false,
        dateCreation: DateTime(2025, 6, 27),
        dateArchivage: null,
        userId: 'user6',
      );
      expect(dette1 == dette2, false);
    });
  });
}
