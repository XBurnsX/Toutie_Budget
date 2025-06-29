import 'package:flutter_test/flutter_test.dart';
import 'dart:math' as math;

void main() {
  group('Tests de scénarios de dettes réelles', () {
    test('Calcul avec données réelles: 25.07% APR, 1149.72\$, 24 mois', () {
      final prixAchat = 1149.72;
      final tauxInteretAnnuel = 25.07;
      final nombrePaiements = 24;
      final paiementsEffectues = 7; // Données d'entrée directes
      final montantMensuelAttendu = 61.39;
      final payeADate = 429.73;
      final soldeRestantAttendu = 1043.71;

      // Calculer le montant mensuel avec la formule d'amortissement
      final tauxMensuel = tauxInteretAnnuel / 100 / 12;
      final montantMensuelCalcule =
          prixAchat *
          (tauxMensuel * math.pow(1 + tauxMensuel, nombrePaiements)) /
          (math.pow(1 + tauxMensuel, nombrePaiements) - 1);

      // Calculer le coût total
      final coutTotalCalcule = montantMensuelCalcule * nombrePaiements;
      final coutTotalAttendu = 1473.44; // 61.39 * 24

      // Calculer le total payé
      final totalPaye = montantMensuelCalcule * paiementsEffectues;

      // Calculer le solde restant
      final soldeRestantCalcule = coutTotalCalcule - totalPaye;

      print('\n=== PREMIER SCÉNARIO ===');
      print('Prix d\'achat: ${prixAchat.toStringAsFixed(2)}\$');
      print('Taux APR: ${tauxInteretAnnuel.toStringAsFixed(2)}%');
      print('Durée: ${nombrePaiements} mois');
      print('Paiements effectués: ${paiementsEffectues}');
      print(
        'Montant mensuel attendu: ${montantMensuelAttendu.toStringAsFixed(2)}\$',
      );
      print(
        'Payé à ce jour: ${(montantMensuelCalcule * paiementsEffectues).toStringAsFixed(2)}\$',
      );
      print(
        'Solde restant attendu: ${soldeRestantAttendu.toStringAsFixed(2)}\$',
      );
      print('Coût total attendu: ${coutTotalAttendu.toStringAsFixed(2)}\$');

      print('\n--- RÉSULTATS CALCULÉS ---');
      print(
        'Montant mensuel calculé: ${montantMensuelCalcule.toStringAsFixed(2)}\$',
      );
      print('Coût total calculé: ${coutTotalCalcule.toStringAsFixed(2)}\$');
      print('Coût total attendu: ${coutTotalAttendu.toStringAsFixed(2)}\$');
      print(
        'Différence: ${(coutTotalCalcule - coutTotalAttendu).toStringAsFixed(2)}\$',
      );

      print('Total payé: ${totalPaye.toStringAsFixed(2)}\$');
      print('Total payé attendu: ${payeADate.toStringAsFixed(2)}\$');
      print(
        'Solde restant calculé: ${soldeRestantCalcule.toStringAsFixed(2)}\$',
      );
      print(
        'Solde restant attendu: ${soldeRestantAttendu.toStringAsFixed(2)}\$',
      );
      print(
        'Différence: ${(soldeRestantCalcule - soldeRestantAttendu).toStringAsFixed(2)}\$',
      );

      // Vérifications
      expect(montantMensuelCalcule, closeTo(montantMensuelAttendu, 0.50));
      expect(coutTotalCalcule, closeTo(coutTotalAttendu, 1.0));
      expect(totalPaye, closeTo(payeADate, 1.0));
      expect(soldeRestantCalcule, closeTo(soldeRestantAttendu, 1.0));
    });

    test('Analyse du deuxième scénario: 24.22% APR, 409.88\$, 12 mois', () {
      final prixAchat = 409.88;
      final tauxInteretAnnuel = 24.22;
      final nombrePaiements = 12;
      final paiementsEffectues = 2; // Données d'entrée directes
      final montantMensuel = 38.80;
      final soldeRestantAttendu = 388.03;
      final coutTotalAttendu = 465.63;

      print('\n=== DEUXIÈME SCÉNARIO ===');
      print('Prix d\'achat: ${prixAchat.toStringAsFixed(2)}\$');
      print('Paiement mensuel: ${montantMensuel.toStringAsFixed(2)}\$');
      print('Taux APR: ${tauxInteretAnnuel.toStringAsFixed(2)}%');
      print('Durée: ${nombrePaiements} mois');
      print('Paiements effectués: ${paiementsEffectues}');
      print(
        'Payé à ce jour: ${(montantMensuel * paiementsEffectues).toStringAsFixed(2)}\$',
      );
      print(
        'Solde restant attendu: ${soldeRestantAttendu.toStringAsFixed(2)}\$',
      );
      print('Coût total attendu: ${coutTotalAttendu.toStringAsFixed(2)}\$');

      // Calculer le coût total
      final coutTotalCalcule = montantMensuel * nombrePaiements;

      // Calculer le solde restant
      final soldeRestantCalcule =
          coutTotalCalcule - (montantMensuel * paiementsEffectues);

      print('\n--- RÉSULTATS CALCULÉS ---');
      print('Coût total calculé: ${coutTotalCalcule.toStringAsFixed(2)}\$');
      print('Coût total attendu: ${coutTotalAttendu.toStringAsFixed(2)}\$');
      print(
        'Différence: ${(coutTotalCalcule - coutTotalAttendu).toStringAsFixed(2)}\$',
      );

      print(
        'Solde restant calculé: ${soldeRestantCalcule.toStringAsFixed(2)}\$',
      );
      print(
        'Solde restant attendu: ${soldeRestantAttendu.toStringAsFixed(2)}\$',
      );
      print(
        'Différence: ${(soldeRestantCalcule - soldeRestantAttendu).toStringAsFixed(2)}\$',
      );

      // Vérifications
      expect(coutTotalCalcule, closeTo(coutTotalAttendu, 1.0));
      expect(soldeRestantCalcule, closeTo(soldeRestantAttendu, 1.0));

      // Test du taux effectif
      final tauxEffectif = _calculerTauxEffectif(
        principal: prixAchat,
        paiementMensuel: montantMensuel,
        nombrePaiements: nombrePaiements,
        paiementsEffectues: paiementsEffectues,
        soldeRestantReel: soldeRestantAttendu,
      );

      print(
        'Taux d\'intérêt effectif calculé: ${tauxEffectif.toStringAsFixed(2)}%',
      );
      print('Taux d\'intérêt affiché (APR): 24.22%');
      print('Différence: ${(24.22 - tauxEffectif).toStringAsFixed(2)}%');

      // Vérifier que le taux calculé donne bien le solde restant attendu
      final tauxMensuel = tauxEffectif / 100 / 12;
      double soldeRestant = prixAchat;

      for (int mois = 0; mois < paiementsEffectues; mois++) {
        final interetMensuel = soldeRestant * tauxMensuel;
        final capitalMensuel = montantMensuel - interetMensuel;
        soldeRestant -= capitalMensuel;
      }

      expect(soldeRestant, closeTo(soldeRestantAttendu, 1.0));
    });

    test('Vérification du calcul d\'intérêts composés', () {
      final prixAchat = 1149.72;
      final tauxInteretAnnuel = 25.07;
      final tauxMensuel = tauxInteretAnnuel / 100 / 12;
      final montantMensuel = 61.39;
      final paiementsEffectues = 7;

      // Simuler les 7 premiers paiements
      double soldeRestant = prixAchat;
      double totalInterets = 0.0;
      double totalCapital = 0.0;

      for (int mois = 0; mois < paiementsEffectues; mois++) {
        final interetMensuel = soldeRestant * tauxMensuel;
        final capitalMensuel = montantMensuel - interetMensuel;

        totalInterets += interetMensuel;
        totalCapital += capitalMensuel;
        soldeRestant -= capitalMensuel;

        print(
          'Mois ${mois + 1}: Intérêt=${interetMensuel.toStringAsFixed(2)}, Capital=${capitalMensuel.toStringAsFixed(2)}, Solde=${soldeRestant.toStringAsFixed(2)}',
        );
      }

      print('\n--- VÉRIFICATION INTÉRÊTS COMPOSÉS ---');
      print('Total intérêts payés: ${totalInterets.toStringAsFixed(2)}\$');
      print('Total capital remboursé: ${totalCapital.toStringAsFixed(2)}\$');
      print('Solde restant: ${soldeRestant.toStringAsFixed(2)}\$');
      print(
        'Total payé: ${(totalInterets + totalCapital).toStringAsFixed(2)}\$',
      );

      // Vérifications
      expect(totalInterets, greaterThan(0));
      expect(totalCapital, greaterThan(0));
      expect(soldeRestant, greaterThan(0));
      expect(soldeRestant, lessThan(prixAchat));
    });

    test('Vérification du coût total de la dette', () {
      final prixAchat = 1149.72;
      final montantMensuel = 61.39;
      final nombrePaiements = 24;

      final coutTotal = montantMensuel * nombrePaiements;
      final coutInterets = coutTotal - prixAchat;

      print('Prix d\'achat: ${prixAchat.toStringAsFixed(2)}');
      print('Coût total: ${coutTotal.toStringAsFixed(2)}');
      print('Coût des intérêts: ${coutInterets.toStringAsFixed(2)}');

      expect(coutTotal, closeTo(1473.36, 0.01)); // 61.39 * 24
      expect(coutInterets, closeTo(323.64, 0.01)); // 1473.36 - 1149.72
    });

    test('Calcul du taux d\'intérêt effectif réel', () {
      final prixAchat = 1149.72;
      final montantMensuel = 61.39;
      final nombrePaiements = 24;
      final paiementsEffectues = 7;
      final soldeRestantReel = 1043.71;

      // Calculer le taux effectif qui donne ce comportement
      final tauxEffectif = _calculerTauxEffectif(
        principal: prixAchat,
        paiementMensuel: montantMensuel,
        nombrePaiements: nombrePaiements,
        paiementsEffectues: paiementsEffectues,
        soldeRestantReel: soldeRestantReel,
      );

      print(
        'Taux d\'intérêt effectif calculé: ${tauxEffectif.toStringAsFixed(2)}%',
      );
      print('Taux d\'intérêt affiché (APR): 25.07%');
      print('Différence: ${(25.07 - tauxEffectif).toStringAsFixed(2)}%');

      // Vérifier que le taux calculé donne bien le solde restant attendu
      final tauxMensuel = tauxEffectif / 100 / 12;
      double soldeRestant = prixAchat;

      for (int mois = 0; mois < paiementsEffectues; mois++) {
        final interetMensuel = soldeRestant * tauxMensuel;
        final capitalMensuel = montantMensuel - interetMensuel;
        soldeRestant -= capitalMensuel;
      }

      expect(soldeRestant, closeTo(soldeRestantReel, 1.0));
    });

    test('Vérification manuelle du taux pour le deuxième scénario', () {
      final prixAchat = 409.88;
      final montantMensuel = 38.80;
      final nombrePaiements = 12;
      final tauxAttendu = 24.22;

      print('\n=== VÉRIFICATION MANUELLE DU TAUX ===');
      print('Prix d\'achat: ${prixAchat.toStringAsFixed(2)}\$');
      print('Paiement mensuel: ${montantMensuel.toStringAsFixed(2)}\$');
      print('Durée: ${nombrePaiements} mois');
      print('Taux attendu: ${tauxAttendu.toStringAsFixed(2)}%');

      // Test avec le taux attendu
      final tauxMensuelAttendu = tauxAttendu / 100 / 12;
      double soldeRestant = prixAchat;
      double totalInterets = 0.0;

      for (int mois = 0; mois < nombrePaiements; mois++) {
        final interetMensuel = soldeRestant * tauxMensuelAttendu;
        final capitalMensuel = montantMensuel - interetMensuel;

        totalInterets += interetMensuel;
        soldeRestant -= capitalMensuel;

        print(
          'Mois ${mois + 1}: Intérêt=${interetMensuel.toStringAsFixed(2)}, Capital=${capitalMensuel.toStringAsFixed(2)}, Solde=${soldeRestant.toStringAsFixed(2)}',
        );
      }

      final coutTotal = montantMensuel * nombrePaiements;
      final interetsCalcules = coutTotal - prixAchat;

      print('\nRésultats:');
      print('Coût total: ${coutTotal.toStringAsFixed(2)}\$');
      print('Intérêts calculés: ${interetsCalcules.toStringAsFixed(2)}\$');
      print('Intérêts simulés: ${totalInterets.toStringAsFixed(2)}\$');
      print('Solde restant final: ${soldeRestant.toStringAsFixed(2)}\$');

      // Vérifications
      expect(
        soldeRestant,
        closeTo(0.0, 1.0),
      ); // Le solde devrait être proche de 0
      expect(
        totalInterets,
        closeTo(interetsCalcules, 1.0),
      ); // Les intérêts devraient correspondre
    });

    test(
      'Troisième scénario - Calcul automatique: 25.99% APR, 2334.35\$, 24 mois',
      () {
        final prixAchat = 2334.35;
        final tauxInteretAnnuel = 25.99;
        final nombrePaiements = 24;
        final paiementsEffectues = 8;

        print('\n=== TROISIÈME SCÉNARIO - CALCUL AUTOMATIQUE ===');
        print('Prix d\'achat: ${prixAchat.toStringAsFixed(2)}\$');
        print('Taux APR: ${tauxInteretAnnuel.toStringAsFixed(2)}%');
        print('Durée: ${nombrePaiements} mois');
        print('Paiements effectués: ${paiementsEffectues}');

        // Calculer le montant mensuel avec la formule d'amortissement
        final tauxMensuel = tauxInteretAnnuel / 100 / 12;
        final montantMensuelCalcule =
            prixAchat *
            (tauxMensuel * math.pow(1 + tauxMensuel, nombrePaiements)) /
            (math.pow(1 + tauxMensuel, nombrePaiements) - 1);

        // Calculer le coût total
        final coutTotalCalcule = montantMensuelCalcule * nombrePaiements;

        // Calculer le total payé
        final totalPaye = montantMensuelCalcule * paiementsEffectues;

        // Calculer le solde restant
        final soldeRestantCalcule = coutTotalCalcule - totalPaye;

        // Calculer les intérêts payés
        final interetsPayes = totalPaye - (prixAchat - soldeRestantCalcule);

        print('\n--- RÉSULTATS CALCULÉS ---');
        print('Montant mensuel: ${montantMensuelCalcule.toStringAsFixed(2)}\$');
        print('Coût total: ${coutTotalCalcule.toStringAsFixed(2)}\$');
        print('Total payé: ${totalPaye.toStringAsFixed(2)}\$');
        print('Solde restant: ${soldeRestantCalcule.toStringAsFixed(2)}\$');
        print('Intérêts payés: ${interetsPayes.toStringAsFixed(2)}\$');

        // Vérification de cohérence
        print('\n--- VÉRIFICATIONS ---');
        print(
          'Capital remboursé: ${(prixAchat - soldeRestantCalcule).toStringAsFixed(2)}\$',
        );
        print(
          'Vérification: Capital + Intérêts = ${(prixAchat - soldeRestantCalcule + interetsPayes).toStringAsFixed(2)}\$ = Total payé: ${totalPaye.toStringAsFixed(2)}\$',
        );

        // Vérifications logiques
        expect(montantMensuelCalcule, greaterThan(0));
        expect(coutTotalCalcule, greaterThan(prixAchat));
        expect(soldeRestantCalcule, greaterThan(0));
        expect(soldeRestantCalcule, lessThan(prixAchat));
        expect(totalPaye, greaterThan(0));
        expect(totalPaye, lessThan(coutTotalCalcule));
      },
    );
  });
}

/// Calcule le taux d'intérêt effectif basé sur les paiements réels
double _calculerTauxEffectif({
  required double principal,
  required double paiementMensuel,
  required int nombrePaiements,
  required int paiementsEffectues,
  required double soldeRestantReel,
}) {
  // Utiliser une approche plus simple : calculer le taux qui donne le bon solde restant
  // après le nombre de paiements effectués

  // Si le solde restant réel est plus élevé que le principal,
  // cela signifie que les paiements n'ont pas encore commencé
  if (soldeRestantReel >= principal) {
    return 0.0;
  }

  // Calculer le taux approximatif basé sur la formule d'amortissement
  // Solde restant = Principal * (1 + r)^n - Paiement * ((1 + r)^n - 1) / r
  // où r est le taux mensuel et n est le nombre de paiements effectués

  // Pour simplifier, utilisons une approximation linéaire
  double capitalRembourse = principal - soldeRestantReel;
  double totalPaye = paiementsEffectues * paiementMensuel;
  double interetsPayes = totalPaye - capitalRembourse;

  // Taux effectif approximatif basé sur les intérêts payés
  if (capitalRembourse > 0) {
    double tauxMensuelApprox =
        interetsPayes / (capitalRembourse * paiementsEffectues);
    return tauxMensuelApprox * 12 * 100; // Convertir en taux annuel
  }

  return 0.0;
}

double _calculerTauxPourPaiementMensuel({
  required double principal,
  required double paiementMensuel,
  required int nombrePaiements,
}) {
  double low = 0.0;
  double high = 1.0; // 100% annuel
  double epsilon = 0.01;

  while ((high - low) > 1e-6) {
    double mid = (low + high) / 2;
    double tauxMensuel = mid / 12;

    // Simuler les paiements avec ce taux
    double soldeRestant = principal;
    for (int mois = 0; mois < nombrePaiements; mois++) {
      double interetMensuel = soldeRestant * tauxMensuel;
      double capitalMensuel = paiementMensuel - interetMensuel;
      soldeRestant -= capitalMensuel;
    }

    if ((soldeRestant - 0).abs() < epsilon) {
      return mid * 100; // Retourne le taux annuel en %
    } else if (soldeRestant > 0) {
      // Il reste trop, il faut augmenter le taux
      low = mid;
    } else {
      // Il reste trop peu, il faut baisser le taux
      high = mid;
    }
  }

  return (low + high) / 2 * 100;
}
