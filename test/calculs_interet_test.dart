import 'package:flutter_test/flutter_test.dart';
import 'dart:math' as math;

void main() {
  group('Calculs d\'intérêt pour dettes manuelles', () {
    test('Calcul montant mensuel sans intérêts', () {
      final soldeActuel = 1000.0;
      final tauxInteret = 0.0;
      final moisRestants = 12;

      final montantMensuel = soldeActuel / moisRestants;
      expect(montantMensuel, closeTo(83.33, 0.01));
    });

    test('Calcul montant mensuel avec intérêts - formule PMT', () {
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

    test('Calcul total intérêts payés sur la durée', () {
      final soldeActuel = 1000.0;
      final tauxInteret = 12.0; // 12% annuel
      final montantMensuel = 100.0;
      final moisRestants = 12;

      double soldeRestant = soldeActuel;
      double totalInterets = 0.0;
      double totalCapital = 0.0;

      for (int mois = 0; mois < moisRestants && soldeRestant > 0; mois++) {
        final interetMensuel = soldeRestant * (tauxInteret / 100 / 12);
        final capitalMensuel = montantMensuel - interetMensuel;

        if (capitalMensuel > soldeRestant) {
          // Dernier paiement
          totalCapital += soldeRestant;
          totalInterets += interetMensuel;
          break;
        }

        totalCapital += capitalMensuel;
        totalInterets += interetMensuel;
        soldeRestant -= capitalMensuel;
      }

      // Avec 12% d'intérêt, on devrait payer des intérêts significatifs
      expect(totalInterets, greaterThan(0));
      expect(
        totalCapital,
        closeTo(1000.0, 1.0),
      ); // Le capital remboursé devrait être proche du solde initial
      expect(
        totalInterets + totalCapital,
        greaterThan(1000.0),
      ); // Total devrait être supérieur au capital initial
    });

    test('Calcul mois entre deux dates', () {
      final debut = DateTime(2025, 1, 1);
      final fin = DateTime(2025, 12, 1);

      final mois = (fin.year - debut.year) * 12 + (fin.month - debut.month);
      expect(mois, 11); // 11 mois entre janvier et décembre
    });

    test('Calcul avec taux d\'intérêt élevé', () {
      final soldeActuel = 5000.0;
      final tauxInteret = 20.0; // 20% annuel (taux de carte de crédit)
      final moisRestants = 24;

      final tauxMensuel = tauxInteret / 100 / 12;
      final numerateur =
          soldeActuel * tauxMensuel * math.pow(1 + tauxMensuel, moisRestants);
      final denominateur = math.pow(1 + tauxMensuel, moisRestants) - 1;
      final montantMensuel = numerateur / denominateur;

      // Avec 20% d'intérêt, le montant mensuel devrait être significativement plus élevé
      expect(montantMensuel, greaterThan(5000.0 / 24)); // Plus que 208.33
      expect(montantMensuel, closeTo(254.96, 0.01)); // Valeur calculée
    });

    test('Vérification que le solde atteint zéro', () {
      final soldeActuel = 1000.0;
      final tauxInteret = 10.0; // 10% annuel
      final moisRestants = 12;

      final tauxMensuel = tauxInteret / 100 / 12;
      final numerateur =
          soldeActuel * tauxMensuel * math.pow(1 + tauxMensuel, moisRestants);
      final denominateur = math.pow(1 + tauxMensuel, moisRestants) - 1;
      final montantMensuel = numerateur / denominateur;

      // Simuler les paiements mensuels
      double soldeRestant = soldeActuel;
      for (int mois = 0; mois < moisRestants && soldeRestant > 0; mois++) {
        final interetMensuel = soldeRestant * tauxMensuel;
        final capitalMensuel = montantMensuel - interetMensuel;

        if (capitalMensuel > soldeRestant) {
          soldeRestant = 0;
        } else {
          soldeRestant -= capitalMensuel;
        }
      }

      // Le solde devrait être proche de zéro après tous les paiements
      expect(soldeRestant, closeTo(0, 0.01));
    });
  });
}
