import 'package:flutter/material.dart';

/// Service pour gérer les couleurs des montants dans l'application
class ColorService {
  /// Détermine la couleur d'un montant selon les règles :
  /// - Rouge si négatif
  /// - Gris si entre -0.1 et 0.1
  /// - Couleur fournie sinon
  static Color getCouleurMontant(double montant, Color couleurDefaut) {
    // Si le montant est négatif, retourner rouge
    if (montant < 0) {
      return Colors.red;
    }

    // Si le montant est entre -0.1 et 0.1, retourner gris
    if (montant >= -0.1 && montant <= 0.1) {
      return Colors.grey;
    }

    // Sinon, utiliser la couleur par défaut
    return couleurDefaut;
  }
}
