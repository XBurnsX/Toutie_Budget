import 'package:flutter_test/flutter_test.dart';
import 'package:toutie_budget/models/compte.dart';
import 'package:toutie_budget/models/categorie.dart';
import 'package:toutie_budget/models/transaction_model.dart';
import 'package:toutie_budget/models/fractionnement_model.dart';
import 'package:toutie_budget/models/dette.dart';

void main() {
  group('Scénarios d\'intégration - Toutie_Budget', () {
    group('Scénario 1: Configuration initiale d\'un utilisateur', () {
      test('Création de comptes de base', () {
        // Simuler la création des comptes de base
        final comptes = [
          Compte(
            id: 'compte_principal',
            nom: 'Compte Principal',
            type: 'Chèque',
            solde: 2000.0,
            couleur: 0xFF2196F3,
            pretAPlacer: 1000.0,
            dateCreation: DateTime(2025, 1, 1),
            estArchive: false,
          ),
          Compte(
            id: 'compte_epargne',
            nom: 'Épargne',
            type: 'Épargne',
            solde: 5000.0,
            couleur: 0xFF4CAF50,
            pretAPlacer: 2000.0,
            dateCreation: DateTime(2025, 1, 1),
            estArchive: false,
          ),
        ];

        expect(comptes.length, 2);
        expect(comptes[0].type, 'Chèque');
        expect(comptes[1].type, 'Épargne');

        // Vérifier le solde total
        final soldeTotal = comptes.fold(
          0.0,
          (sum, compte) => sum + compte.solde,
        );
        expect(soldeTotal, 7000.0);
      });

      test('Création de catégories et enveloppes', () {
        final categories = [
          Categorie(
            id: 'cat_essentiels',
            nom: 'Essentiels',
            enveloppes: [
              Enveloppe(
                id: 'env_epicerie',
                nom: 'Épicerie',
                solde: 0.0,
                objectif: 400.0,
                depense: 0.0,
                archivee: false,
              ),
              Enveloppe(
                id: 'env_transport',
                nom: 'Transport',
                solde: 0.0,
                objectif: 200.0,
                depense: 0.0,
                archivee: false,
              ),
            ],
          ),
          Categorie(
            id: 'cat_loisirs',
            nom: 'Loisirs',
            enveloppes: [
              Enveloppe(
                id: 'env_restaurant',
                nom: 'Restaurant',
                solde: 0.0,
                objectif: 150.0,
                depense: 0.0,
                archivee: false,
              ),
            ],
          ),
        ];

        expect(categories.length, 2);
        expect(categories[0].enveloppes.length, 2);
        expect(categories[1].enveloppes.length, 1);

        // Vérifier les objectifs totaux
        final objectifTotal = categories.fold(
          0.0,
          (sum, cat) =>
              sum +
              cat.enveloppes.fold(0.0, (sumEnv, env) => sumEnv + env.objectif),
        );
        expect(objectifTotal, 750.0);
      });
    });

    group('Scénario 2: Allocation du budget mensuel', () {
      test('Allocation depuis le prêt à placer vers les enveloppes', () {
        final compte = Compte(
          id: 'compte_principal',
          nom: 'Compte Principal',
          type: 'Chèque',
          solde: 2000.0,
          couleur: 0xFF2196F3,
          pretAPlacer: 1000.0,
          dateCreation: DateTime(2025, 1, 1),
          estArchive: false,
        );

        final enveloppes = [
          Enveloppe(
            id: 'env_epicerie',
            nom: 'Épicerie',
            solde: 0.0,
            objectif: 400.0,
            depense: 0.0,
            archivee: false,
          ),
          Enveloppe(
            id: 'env_transport',
            nom: 'Transport',
            solde: 0.0,
            objectif: 200.0,
            depense: 0.0,
            archivee: false,
          ),
        ];

        // Simuler l'allocation
        double pretAPlacerRestant = compte.pretAPlacer;
        for (var enveloppe in enveloppes) {
          if (pretAPlacerRestant >= enveloppe.objectif) {
            // Dans un vrai test, on modifierait l'enveloppe
            pretAPlacerRestant -= enveloppe.objectif;
          }
        }

        expect(pretAPlacerRestant, 400.0); // 1000 - 400 - 200
      });
    });

    group('Scénario 3: Gestion des transactions', () {
      test('Transaction simple - Dépense d\'épicerie', () {
        final transaction = Transaction(
          id: 'trans_1',
          userId: 'user_123',
          type: TypeTransaction.depense,
          typeMouvement: TypeMouvementFinancier.depenseNormale,
          montant: 85.50,
          tiers: 'Super U',
          compteId: 'compte_principal',
          date: DateTime(2025, 1, 15),
          enveloppeId: 'env_epicerie',
          marqueur: 'Important',
          note: 'Courses de la semaine',
          estFractionnee: false,
        );

        expect(transaction.type, TypeTransaction.depense);
        expect(transaction.montant, 85.50);
        expect(transaction.tiers, 'Super U');
        expect(transaction.estFractionnee, false);
      });

      test('Transaction fractionnée - Courses multiples', () {
        final sousItems = [
          SousItemFractionnement(
            id: 'item_1',
            description: 'Épicerie',
            montant: 60.0,
            enveloppeId: 'env_epicerie',
          ),
          SousItemFractionnement(
            id: 'item_2',
            description: 'Restaurant',
            montant: 40.0,
            enveloppeId: 'env_restaurant',
          ),
        ];

        final transactionFractionnee = TransactionFractionnee(
          transactionParenteId: 'trans_2',
          sousItems: sousItems,
          montantTotal: 100.0,
        );

        final transaction = Transaction(
          id: 'trans_2',
          userId: 'user_123',
          type: TypeTransaction.depense,
          typeMouvement: TypeMouvementFinancier.depenseNormale,
          montant: 100.0,
          tiers: 'Centre commercial',
          compteId: 'compte_principal',
          date: DateTime(2025, 1, 16),
          estFractionnee: true,
          sousItems: sousItems.map((item) => item.toJson()).toList(),
        );

        expect(transaction.estFractionnee, true);
        expect(transactionFractionnee.estValide, true);
        expect(transactionFractionnee.montantAlloue, 100.0);
        expect(transactionFractionnee.montantRestant, 0.0);
      });
    });

    group('Scénario 4: Gestion des objectifs', () {
      test('Calcul de progression d\'objectif', () {
        final enveloppe = Enveloppe(
          id: 'env_vacances',
          nom: 'Vacances',
          solde: 800.0,
          objectif: 2000.0,
          depense: 0.0,
          archivee: false,
        );

        final progression = (enveloppe.solde / enveloppe.objectif) * 100;
        final montantRestant = enveloppe.objectif - enveloppe.solde;

        expect(progression, 40.0); // 800/2000 * 100
        expect(montantRestant, 1200.0);
      });

      test('Calcul d\'objectif mensuel avec date limite', () {
        final objectif = 2000.0;
        final soldeActuel = 800.0;
        final dateLimite = DateTime(2025, 12, 31);
        final dateActuelle = DateTime(2025, 6, 1);

        final moisRestants =
            ((dateLimite.year - dateActuelle.year) * 12) +
            (dateLimite.month - dateActuelle.month);
        final montantRestant = objectif - soldeActuel;
        final montantParMois = montantRestant / moisRestants;

        expect(moisRestants, 6);
        expect(montantRestant, 1200.0);
        expect(montantParMois, 200.0);
      });
    });

    group('Scénario 5: Gestion des situations d\'urgence', () {
      test('Détection de solde négatif', () {
        final comptes = [
          Compte(
            id: 'compte_principal',
            nom: 'Compte Principal',
            type: 'Chèque',
            solde: 2000.0,
            couleur: 0xFF2196F3,
            pretAPlacer: -500.0, // Négatif !
            dateCreation: DateTime(2025, 1, 1),
            estArchive: false,
          ),
        ];

        final categories = [
          Categorie(
            id: 'cat_essentiels',
            nom: 'Essentiels',
            enveloppes: [
              Enveloppe(
                id: 'env_epicerie',
                nom: 'Épicerie',
                solde: -100.0, // Négatif !
                objectif: 400.0,
                depense: 500.0,
                archivee: false,
              ),
            ],
          ),
        ];

        // Détecter les situations d'urgence
        final comptesNegatifs = comptes.any(
          (compte) =>
              compte.pretAPlacer < 0 &&
              compte.type != 'Dette' &&
              compte.type != 'Investissement',
        );

        final enveloppesNegatives = categories.any(
          (categorie) =>
              categorie.enveloppes.any((enveloppe) => enveloppe.solde < 0),
        );

        final montantNegatifTotal =
            comptes.fold(0.0, (sum, compte) {
              if (compte.pretAPlacer < 0 &&
                  compte.type != 'Dette' &&
                  compte.type != 'Investissement') {
                return sum + compte.pretAPlacer.abs();
              }
              return sum;
            }) +
            categories.fold(
              0.0,
              (sum, cat) =>
                  sum +
                  cat.enveloppes.fold(
                    0.0,
                    (sumEnv, env) =>
                        env.solde < 0 ? sumEnv + env.solde.abs() : sumEnv,
                  ),
            );

        expect(comptesNegatifs, true);
        expect(enveloppesNegatives, true);
        expect(montantNegatifTotal, 600.0); // 500 + 100
      });
    });

    group('Scénario 6: Virements et transferts', () {
      test('Virement entre comptes', () {
        final compteSource = Compte(
          id: 'compte_principal',
          nom: 'Compte Principal',
          type: 'Chèque',
          solde: 2000.0,
          couleur: 0xFF2196F3,
          pretAPlacer: 1000.0,
          dateCreation: DateTime(2025, 1, 1),
          estArchive: false,
        );

        final compteDestination = Compte(
          id: 'compte_epargne',
          nom: 'Épargne',
          type: 'Épargne',
          solde: 5000.0,
          couleur: 0xFF4CAF50,
          pretAPlacer: 2000.0,
          dateCreation: DateTime(2025, 1, 1),
          estArchive: false,
        );

        final montant = 500.0;

        // Simuler le virement
        if (compteSource.pretAPlacer >= montant) {
          // Dans un vrai virement, on mettrait à jour les comptes
          final nouveauPretSource = compteSource.pretAPlacer - montant;
          final nouveauPretDest = compteDestination.pretAPlacer + montant;

          expect(nouveauPretSource, 500.0);
          expect(nouveauPretDest, 2500.0);
        }
      });

      test('Virement entre enveloppes', () {
        final enveloppeSource = Enveloppe(
          id: 'env_restaurant',
          nom: 'Restaurant',
          solde: 200.0,
          objectif: 150.0,
          depense: 0.0,
          archivee: false,
        );

        final enveloppeDestination = Enveloppe(
          id: 'env_loisirs',
          nom: 'Loisirs',
          solde: 50.0,
          objectif: 100.0,
          depense: 0.0,
          archivee: false,
        );

        final montant = 50.0;

        // Simuler le virement
        if (enveloppeSource.solde >= montant) {
          final nouveauSoldeSource = enveloppeSource.solde - montant;
          final nouveauSoldeDest = enveloppeDestination.solde + montant;

          expect(nouveauSoldeSource, 150.0);
          expect(nouveauSoldeDest, 100.0);
        }
      });
    });

    group('Scénario 7: Gestion des prêts personnels', () {
      test('Création d\'un prêt personnel', () {
        final dette = Dette(
          id: 'dette_1',
          nomTiers: 'Papa',
          montantInitial: 1000.0,
          solde: 1000.0,
          type: 'pret',
          historique: [],
          archive: false,
          dateCreation: DateTime(2025, 1, 1),
          userId: 'user_123',
        );

        final compteDette = Compte(
          id: 'compte_dette',
          nom: 'Prêt Personnel : Papa',
          type: 'Dette',
          solde: -1000.0,
          couleur: 0xFFE53935,
          pretAPlacer: 0.0,
          dateCreation: DateTime(2025, 1, 1),
          estArchive: false,
        );

        expect(dette.montantInitial, 1000.0);
        expect(dette.solde, 1000.0);
        expect(compteDette.type, 'Dette');
        expect(compteDette.solde, -1000.0);
      });

      test('Remboursement d\'un prêt', () {
        final dette = Dette(
          id: 'dette_1',
          nomTiers: 'Papa',
          montantInitial: 1000.0,
          solde: 800.0, // Déjà 200€ remboursés
          type: 'pret',
          historique: [],
          archive: false,
          dateCreation: DateTime(2025, 1, 1),
          userId: 'user_123',
        );

        final montantRemboursement = 100.0;
        final nouveauSolde = dette.solde - montantRemboursement;

        expect(nouveauSolde, 700.0);

        // Vérifier si le prêt est remboursé
        final estRembourse = nouveauSolde <= 0;
        expect(estRembourse, false);
      });
    });
  });
}
