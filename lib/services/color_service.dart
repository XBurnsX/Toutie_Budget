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

  /// Retourne la couleur du compte source d'une enveloppe pour un mois donné
  /// - enveloppe : Map<String, dynamic> de l'enveloppe (doit contenir l'id)
  /// - comptes : liste des comptes (Map<String, dynamic> ou objets avec .id et .couleur)
  /// - compteSourceInfo : Map<String, String?> avec compte_source_id et collection_compte_source (optionnel)
  /// - couleurDefaut : couleur à utiliser si aucun compte trouvé
  static Color getCouleurCompteSourceEnveloppe({
    required Map<String, dynamic> enveloppe,
    required List comptes,
    Map<String, String?>? compteSourceInfo,
    Color couleurDefaut = Colors.grey,
  }) {
    try {
      // Si le solde est 0, on garde la couleur grise par défaut
      final double solde = (enveloppe['solde'] ?? 0.0).toDouble();
      if (solde == 0) return Colors.grey;

      // Si info du compte source fournie (recommandé)
      if (compteSourceInfo != null &&
          compteSourceInfo['compte_source_id'] != null &&
          compteSourceInfo['collection_compte_source'] != null) {
        final compteSourceId = compteSourceInfo['compte_source_id'];
        final collectionSource = compteSourceInfo['collection_compte_source'];
        try {
          final compte = comptes.firstWhere(
            (c) =>
                (c['id']?.toString() ?? c.id?.toString()) == compteSourceId &&
                (c['collection']?.toString()?.toLowerCase() ?? '') ==
                    collectionSource?.toLowerCase(),
            orElse: () => null,
          );
          if (compte != null) {
            dynamic couleurValue = compte['couleur'] ?? compte.couleur;
            if (couleurValue is Map && couleurValue['value'] != null) {
              couleurValue = couleurValue['value'];
            }
            if (couleurValue != null) {
              return Color(couleurValue is int
                  ? couleurValue
                  : int.tryParse(couleurValue.toString()) ?? 0xFF44474A);
            }
          } else {
            print(
                '[ColorService] Aucun compte source trouvé pour enveloppe ${enveloppe['id']} avec id=$compteSourceId et collection=$collectionSource');
          }
        } catch (e) {
          print('[ColorService] Erreur recherche compte source: $e');
        }
      }
      // Fallback : premier compte de la liste
      if (comptes.isNotEmpty) {
        final compte = comptes.first;
        dynamic couleurValue = compte['couleur'] ?? compte.couleur;
        if (couleurValue is Map && couleurValue['value'] != null) {
          couleurValue = couleurValue['value'];
        }
        if (couleurValue != null) {
          return Color(couleurValue is int
              ? couleurValue
              : int.tryParse(couleurValue.toString()) ?? 0xFF44474A);
        }
      }
      print(
          '[ColorService] Aucun compte trouvé, fallback gris pour enveloppe ${enveloppe['id']}');
      return couleurDefaut;
    } catch (e) {
      print('[ColorService] Exception inattendue: $e');
      return couleurDefaut;
    }
  }
}
