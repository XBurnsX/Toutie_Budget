import 'dart:math' as math;

class CalculPretService {
  /// Calcule le paiement mensuel pour un prêt amorti
  static double calculerPaiementMensuel({
    required double principal,
    required double tauxAnnuel,
    required int dureeMois,
  }) {
    final tauxMensuel = tauxAnnuel / 100 / 12;
    if (tauxMensuel == 0) {
      return principal / dureeMois;
    }
    return principal *
        (tauxMensuel * math.pow(1 + tauxMensuel, dureeMois)) /
        (math.pow(1 + tauxMensuel, dureeMois) - 1);
  }

  /// Calcule le taux effectif à partir d'un paiement mensuel
  static double calculerTauxEffectif({
    required double principal,
    required double paiementMensuel,
    required int dureeMois,
  }) {
    double low = 0.0;
    double high = 2.0; // 200% annuel max
    double epsilon = 0.0001;
    while ((high - low) > 1e-7) {
      double mid = (low + high) / 2;
      double tauxMensuel = mid / 12;
      double numerateur =
          principal * tauxMensuel * math.pow(1 + tauxMensuel, dureeMois);
      double denominateur = math.pow(1 + tauxMensuel, dureeMois) - 1;
      double paiementCalcule = numerateur / denominateur;
      if ((paiementCalcule - paiementMensuel).abs() < epsilon) {
        return mid * 100; // Retourne le taux annuel en %
      } else if (paiementCalcule > paiementMensuel) {
        high = mid;
      } else {
        low = mid;
      }
    }
    return (low + high) / 2 * 100;
  }

  /// Calcule le coût total du prêt
  static double calculerCoutTotal({
    required double paiementMensuel,
    required int dureeMois,
  }) {
    return paiementMensuel * dureeMois;
  }

  /// Calcule le solde restant après n paiements
  static double calculerSoldeRestant({
    required double principal,
    required double tauxAnnuel,
    required int dureeMois,
    required int paiementsEffectues,
  }) {
    final tauxMensuel = tauxAnnuel / 100 / 12;
    if (tauxMensuel == 0) {
      return principal * (1 - paiementsEffectues / dureeMois);
    }
    final paiementMensuel = calculerPaiementMensuel(
      principal: principal,
      tauxAnnuel: tauxAnnuel,
      dureeMois: dureeMois,
    );
    return principal * math.pow(1 + tauxMensuel, paiementsEffectues) -
        paiementMensuel *
            (math.pow(1 + tauxMensuel, paiementsEffectues) - 1) /
            tauxMensuel;
  }

  /// Simule le solde restant après n paiements, en tenant compte d'un paiement mensuel imposé (même si ce n'est pas le paiement PMT exact)
  static double simulerSoldeRestant({
    required double principal,
    required double tauxAnnuel,
    required int paiementsEffectues,
    required double paiementMensuel,
  }) {
    final tauxMensuel = tauxAnnuel / 100 / 12;
    double solde = principal;
    for (int i = 0; i < paiementsEffectues; i++) {
      final interet = solde * tauxMensuel;
      final capital = paiementMensuel - interet;
      solde -= capital;
      if (solde < 0) return 0;
    }
    return solde;
  }

  /// Simule le solde restant après n paiements, en arrondissant à chaque étape comme le ferait une banque
  static double simulerSoldeRestantBanque({
    required double principal,
    required double tauxAnnuel,
    required int paiementsEffectues,
    required double paiementMensuel,
  }) {
    final tauxMensuel = tauxAnnuel / 100 / 12;
    double solde = principal;
    for (int i = 0; i < paiementsEffectues; i++) {
      final interet = double.parse((solde * tauxMensuel).toStringAsFixed(2));
      final capital = double.parse(
        (paiementMensuel - interet).toStringAsFixed(2),
      );
      solde = double.parse((solde - capital).toStringAsFixed(2));
      if (solde < 0) return 0;
    }
    return solde;
  }

  /// Simulation exacte comme dans le test (pas d'arrondi à chaque étape, arrondi seulement à la fin)
  static double simulerSoldeRestantExactTest({
    required double principal,
    required double tauxAnnuel,
    required int paiementsEffectues,
    required double paiementMensuel,
  }) {
    final tauxMensuel = tauxAnnuel / 100 / 12;
    double solde = principal;
    for (int i = 0; i < paiementsEffectues; i++) {
      final interetMensuel = solde * tauxMensuel;
      final capitalMensuel = paiementMensuel - interetMensuel;
      solde -= capitalMensuel;
      print(
        'Mois \\${i + 1}: Solde=\\${solde.toStringAsFixed(2)}, Intérêt=\\${interetMensuel.toStringAsFixed(2)}, Capital=\\${capitalMensuel.toStringAsFixed(2)}',
      );
    }
    print('Solde final (arrondi): \\${solde.toStringAsFixed(2)}');
    return double.parse(solde.toStringAsFixed(2));
  }
}
