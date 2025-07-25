import 'package:flutter/material.dart';
import 'allocation_service.dart';

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

  /// Recherche la couleur du compte source à partir de la liste ou map des comptes.
  /// comptes peut être une List<Map> ou une Map<String, dynamic> (clé = id)
  static Color getCouleurCompteSourceEnveloppe(
    String? compteSourceId,
    String? collectionCompteSource,
    dynamic comptes, // Peut être une Map, une List<Map>, ou une List<Compte>
  ) {
    print('🔍 DEBUG ColorService - compteSourceId: $compteSourceId');
    print(
        '🔍 DEBUG ColorService - collectionCompteSource: $collectionCompteSource');
    print('🔍 DEBUG ColorService - comptes type: ${comptes.runtimeType}');
    print(
        '🔍 DEBUG ColorService - comptes length: ${comptes is List ? comptes.length : 'N/A'}');

    if (compteSourceId == null) {
      print('❌ DEBUG ColorService - compteSourceId est null, retour gris');
      return Colors.grey;
    }

    // Si comptes est une Map
    if (comptes is Map) {
      final compte = comptes[compteSourceId];
      print('🔍 DEBUG ColorService - Map: compte trouvé: ${compte != null}');
      if (compte != null && compte['couleur'] != null) {
        final couleur = compte['couleur'];
        print(
            '🔍 DEBUG ColorService - Map: couleur trouvée: $couleur (${couleur.runtimeType})');
        if (couleur is int) return Color(couleur);
        if (couleur is Color) return couleur;
        if (couleur is Map && couleur['value'] != null)
          return Color(couleur['value']);
      }
    }
    // Si comptes est une List
    if (comptes is List) {
      try {
        // Si c'est une liste de Compte (objet)
        if (comptes.isNotEmpty && comptes.first is! Map) {
          print('🔍 DEBUG ColorService - Liste d\'objets Compte détectée');
          final compte = comptes.firstWhere(
            (c) => c.id.toString() == compteSourceId,
            orElse: () => null,
          );
          print('🔍 DEBUG ColorService - Compte trouvé: ${compte != null}');
          if (compte != null) {
            print('🔍 DEBUG ColorService - Compte nom: ${compte.nom}');
            print('🔍 DEBUG ColorService - Compte couleur: ${compte.couleur}');
            if (compte.couleur != null) {
              final color = Color(compte.couleur);
              print('✅ DEBUG ColorService - Couleur retournée: $color');
              return color;
            }
          }
        } else {
          // Liste de Map
          print('🔍 DEBUG ColorService - Liste de Map détectée');
          final compte = comptes.firstWhere(
            (c) => c['id'].toString() == compteSourceId,
            orElse: () => null,
          );
          print('🔍 DEBUG ColorService - Map trouvée: ${compte != null}');
          if (compte != null && compte['couleur'] != null) {
            final couleur = compte['couleur'];
            print(
                '🔍 DEBUG ColorService - Map couleur: $couleur (${couleur.runtimeType})');
            if (couleur is int) return Color(couleur);
            if (couleur is Color) return couleur;
            if (couleur is Map && couleur['value'] != null)
              return Color(couleur['value']);
          }
        }
      } catch (e) {
        print('❌ DEBUG ColorService - Erreur: $e');
      }
    }
    print('❌ DEBUG ColorService - Aucune couleur trouvée, retour gris');
    return Colors.grey;
  }

  /// Récupère la couleur du compte source d'une enveloppe
  /// Utilise AllocationService pour obtenir les informations de provenance
  static Future<Color> getCouleurCompteSourceEnveloppeAsync({
    required String enveloppeId,
    required List<Map<String, dynamic>> comptes,
    required double solde,
    DateTime? mois,
  }) async {
    // Si solde = 0, retourner gris
    if (solde == 0) {
      return Colors.grey;
    }

    try {
      // Récupérer les informations du compte source via AllocationService
      final compteSourceInfo =
          await AllocationService.obtenirCompteSourceEnveloppe(
        enveloppeId: enveloppeId,
        mois: mois ?? DateTime.now(),
      );

      if (compteSourceInfo['compte_source_id'] != null &&
          compteSourceInfo['collection_compte_source'] != null) {
        final compteSourceId = compteSourceInfo['compte_source_id']!;
        final collectionSource = compteSourceInfo['collection_compte_source']!;

        // Chercher le compte dans la liste des comptes
        Map<String, dynamic>? compte;
        try {
          // Vérifier d'abord si la collection du compte correspond
          final comptesFiltres = comptes
              .where((c) =>
                  c['id'].toString() == compteSourceId &&
                  c['collection']?.toString().toLowerCase() ==
                      collectionSource.toLowerCase())
              .toList();

          if (comptesFiltres.isNotEmpty) {
            compte = comptesFiltres.first;
          } else {
            // Si non trouvé avec la collection, essayer juste avec l'ID
            compte = comptes.firstWhere(
              (c) => c['id'].toString() == compteSourceId,
            );
          }
        } catch (e) {
          // Si non trouvé, prendre le premier compte de la même collection
          final comptesMemeCollection = comptes
              .where((c) =>
                  c['collection']?.toString().toLowerCase() ==
                  collectionSource.toLowerCase())
              .toList();

          if (comptesMemeCollection.isNotEmpty) {
            compte = comptesMemeCollection[0];
          } else if (comptes.isNotEmpty) {
            compte = comptes[0];
          }
        }

        if (compte != null) {
          try {
            // Vérifier si la couleur est un int (valeur brute) ou un champ 'value' dans un objet
            dynamic couleurValue = compte['couleur'];
            if (couleurValue is Map && couleurValue['value'] != null) {
              couleurValue = couleurValue['value'];
            }

            if (couleurValue != null) {
              return Color(couleurValue is int
                  ? couleurValue
                  : int.tryParse(couleurValue.toString()) ?? 0xFF44474A);
            }
          } catch (e) {
            return Colors.amber;
          }
        }
      }
    } catch (e) {
      // En cas d'erreur, retourner amber
      return Colors.amber;
    }

    // Fallback: gris si aucune couleur trouvée
    return Colors.grey;
  }
}
