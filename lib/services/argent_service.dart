import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/categorie.dart';
import '../models/compte.dart';
import 'firebase_service.dart';
import 'cache_service.dart';

class ArgentService {
  final FirebaseService _firebaseService = FirebaseService();

  /// Alloue un montant du Prêt à placer d'un compte vers une enveloppe (ou autre usage)
  Future<void> allouerPretAPlacer({
    required Compte compte,
    required double montant,
  }) async {
    if (compte.pretAPlacer < montant) {
      throw Exception('Montant insuffisant');
    }
    await _firebaseService.comptesRef.doc(compte.id).update({
      'pretAPlacer': compte.pretAPlacer - montant,
    });
  }

  /// Virement entre deux comptes (ajuste le Prêt à placer des deux comptes)
  Future<void> virementEntreComptes({
    required Compte source,
    required Compte destination,
    required double montant,
  }) async {
    if (source.pretAPlacer < montant) {
      throw Exception('Montant insuffisant');
    }
    await _firebaseService.comptesRef.firestore.runTransaction((
      transaction,
    ) async {
      final docSource = _firebaseService.comptesRef.doc(source.id);
      final docDest = _firebaseService.comptesRef.doc(destination.id);
      final snapSource = await transaction.get(docSource);
      final snapDest = await transaction.get(docDest);
      if (!snapSource.exists || !snapDest.exists) return;
      final pretAPlacerSource =
          (snapSource.data() as Map<String, dynamic>)['pretAPlacer']
                  ?.toDouble() ??
              0;
      final pretAPlacerDest =
          (snapDest.data() as Map<String, dynamic>)['pretAPlacer']
                  ?.toDouble() ??
              0;
      if (pretAPlacerSource < montant) throw Exception('Montant insuffisant');
      transaction.update(docSource, {
        'pretAPlacer': pretAPlacerSource - montant,
      });
      transaction.update(docDest, {'pretAPlacer': pretAPlacerDest + montant});
    });
  }

  /// Virement d'une enveloppe vers une autre enveloppe
  Future<void> virementEnveloppeVersEnveloppe({
    required Enveloppe source,
    required Enveloppe destination,
    required double montant,
  }) async {
    if (source.solde < montant) {
      throw Exception('Montant insuffisant dans l\'enveloppe source');
    }
    final categoriesRef = _firebaseService.categoriesRef;
    final now = DateTime.now();
    final moisCourant =
        "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}";
    await categoriesRef.firestore.runTransaction((transaction) async {
      QuerySnapshot catSnap = await categoriesRef.get();
      DocumentSnapshot? catSource;
      DocumentSnapshot? catDest;
      for (var doc in catSnap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final enveloppes = (data['enveloppes'] as List<dynamic>? ?? []);
        if (enveloppes.any((e) => e['id'] == source.id)) catSource = doc;
        if (enveloppes.any((e) => e['id'] == destination.id)) catDest = doc;
      }
      if (catSource == null || catDest == null) {
        throw Exception('Catégorie non trouvée');
      }

      // Source
      final srcData = catSource.data() as Map<String, dynamic>;
      final srcEnvs = (srcData['enveloppes'] as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final srcIdx = srcEnvs.indexWhere((e) => e['id'] == source.id);

      // Destination
      final destData = catDest.data() as Map<String, dynamic>;
      final destEnvs = (destData['enveloppes'] as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final destIdx = destEnvs.indexWhere((e) => e['id'] == destination.id);

      // Vérification des provenances - BLOQUER le mélange
      final List<dynamic> provenancesSource =
          srcEnvs[srcIdx]['provenances'] ?? [];
      final List<dynamic> provenancesDest =
          destEnvs[destIdx]['provenances'] ?? [];

      // Si l'enveloppe destination a déjà des fonds, vérifier la compatibilité
      if (provenancesDest.isNotEmpty && provenancesSource.isNotEmpty) {
        final comptesSource = provenancesSource
            .map((prov) => prov['compte_id'].toString())
            .toSet();
        final comptesDest =
            provenancesDest.map((prov) => prov['compte_id'].toString()).toSet();

        // Bloquer si les comptes de provenance sont différents
        if (!comptesSource.every(
              (compteId) => comptesDest.contains(compteId),
            ) ||
            !comptesDest.every(
              (compteId) => comptesSource.contains(compteId),
            )) {
          throw Exception(
            "Impossible de mélanger des fonds provenant de comptes différents. Cette enveloppe contient déjà de l'argent d'un autre compte.",
          );
        }
      }

      final srcOldSolde = (srcEnvs[srcIdx]['solde'] as num?)?.toDouble() ?? 0.0;
      srcEnvs[srcIdx]['solde'] = srcOldSolde - montant;

      final destOldSolde =
          (destEnvs[destIdx]['solde'] as num?)?.toDouble() ?? 0.0;
      destEnvs[destIdx]['solde'] = destOldSolde + montant;

      // Transférer les provenances proportionnellement SEULEMENT si compatible
      if (provenancesSource.isNotEmpty) {
        double totalSource = provenancesSource.fold(
          0.0,
          (sum, prov) => sum + (prov['montant'] as num).toDouble(),
        );

        // Réduire proportionnellement les provenances de la source
        for (var prov in provenancesSource) {
          double montantProv = (prov['montant'] as num).toDouble();
          double proportionATransferer = (montantProv / totalSource) * montant;
          prov['montant'] = montantProv - proportionATransferer;

          // Ajouter à la destination
          if (destEnvs[destIdx]['provenances'] == null) {
            destEnvs[destIdx]['provenances'] = [];
          }

          List<dynamic> provenancesDestFinal = destEnvs[destIdx]['provenances'];
          int existingIndex = provenancesDestFinal.indexWhere(
            (p) => p['compte_id'] == prov['compte_id'],
          );
          if (existingIndex != -1) {
            provenancesDestFinal[existingIndex]['montant'] =
                ((provenancesDestFinal[existingIndex]['montant'] as num)
                        .toDouble() +
                    proportionATransferer);
          } else {
            provenancesDestFinal.add({
              'compte_id': prov['compte_id'],
              'montant': proportionATransferer,
            });
          }
        }

        // Nettoyer les provenances avec montant négligeable
        srcEnvs[srcIdx]['provenances'] = provenancesSource
            .where((prov) => (prov['montant'] as num).toDouble() > 0.01)
            .toList();
      }

      // --- MAJ historique source ---
      Map<String, dynamic> histoSrc = srcEnvs[srcIdx]['historique'] != null
          ? Map<String, dynamic>.from(srcEnvs[srcIdx]['historique'])
          : {};
      histoSrc[moisCourant] = {
        'depense': srcEnvs[srcIdx]['depense'] ?? 0.0,
        'solde': srcEnvs[srcIdx]['solde'],
        'objectif': srcEnvs[srcIdx]['objectif'] ?? 0.0,
      };
      srcEnvs[srcIdx]['historique'] = histoSrc;
      transaction.update(catSource.reference, {'enveloppes': srcEnvs});

      // --- MAJ historique destination ---
      Map<String, dynamic> histoDest = destEnvs[destIdx]['historique'] != null
          ? Map<String, dynamic>.from(destEnvs[destIdx]['historique'])
          : {};
      histoDest[moisCourant] = {
        'depense': destEnvs[destIdx]['depense'] ?? 0.0,
        'solde': destEnvs[destIdx]['solde'],
        'objectif': destEnvs[destIdx]['objectif'] ?? 0.0,
      };
      destEnvs[destIdx]['historique'] = histoDest;
      transaction.update(catDest.reference, {'enveloppes': destEnvs});
    });
  }

  /// Applique une dépense à une enveloppe et met à jour son historique
  Future<void> appliquerDepenseAEnveloppe({
    required String enveloppeId,
    required double montant,
  }) async {
    final categoriesRef = _firebaseService.categoriesRef;
    final now = DateTime.now();
    final moisCourant =
        "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}";

    await categoriesRef.firestore.runTransaction((transaction) async {
      QuerySnapshot catSnap = await categoriesRef.get();
      DocumentSnapshot? catDoc;
      for (var doc in catSnap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final enveloppes = (data['enveloppes'] as List<dynamic>? ?? []);
        if (enveloppes.any((e) => e['id'] == enveloppeId)) {
          catDoc = doc;
          break;
        }
      }

      if (catDoc == null) {
        throw Exception('Catégorie pour l\'enveloppe $enveloppeId non trouvée');
      }

      final catData = catDoc.data() as Map<String, dynamic>;
      final envs = (catData['enveloppes'] as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final idx = envs.indexWhere((e) => e['id'] == enveloppeId);

      if (idx == -1) {
        throw Exception('Enveloppe $enveloppeId non trouvée dans la catégorie');
      }

      var env = envs[idx];
      final oldSolde = (env['solde'] as num? ?? 0.0).toDouble();

      // Mettre à jour solde et dépense
      env['solde'] = oldSolde - montant;
      env['depense'] = (env['depense'] as num? ?? 0.0).toDouble() + montant;

      // Gérer les provenances proportionnellement
      if ((env['solde'] as double) == 0.0) {
        // Si le solde tombe à 0, réinitialiser complètement les provenances
        env['provenances'] = [];
      } else if (env['provenances'] != null &&
          (env['provenances'] as List).isNotEmpty) {
        // Réduire proportionnellement les provenances
        final List<dynamic> provenances = env['provenances'];
        double totalProvenances = provenances.fold(
          0.0,
          (sum, prov) => sum + (prov['montant'] as num).toDouble(),
        );

        if (totalProvenances > 0) {
          for (var prov in provenances) {
            double montantProv = (prov['montant'] as num).toDouble();
            double proportionADeduire =
                (montantProv / totalProvenances) * montant;
            prov['montant'] = montantProv - proportionADeduire;
          }

          // Nettoyer les provenances avec montant négligeable
          env['provenances'] = provenances
              .where((prov) => (prov['montant'] as num).toDouble() > 0.01)
              .toList();
        }
      }

      // Mettre à jour l'historique
      Map<String, dynamic> historique =
          (env['historique'] as Map<String, dynamic>?) ?? {};
      historique[moisCourant] = {
        'depense': env['depense'],
        'solde': env['solde'],
        'objectif': env['objectif'] ?? 0.0,
      };
      env['historique'] = historique;

      envs[idx] = env;

      transaction.update(catDoc.reference, {'enveloppes': envs});
    });
  }

  /// Virement d'une enveloppe vers un compte (ajoute au prêt à placer du compte)
  Future<void> enveloppeVersCompte({
    required Enveloppe source,
    required Compte destination,
    required double montant,
  }) async {
    if (source.solde < montant) {
      throw Exception('Montant insuffisant dans l\'enveloppe');
    }
    final categoriesRef = _firebaseService.categoriesRef;
    // 1. Mise à jour de l'enveloppe dans une transaction
    await categoriesRef.firestore.runTransaction((transaction) async {
      QuerySnapshot catSnap = await categoriesRef.get();
      DocumentSnapshot? catSource;
      for (var doc in catSnap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final enveloppes = (data['enveloppes'] as List<dynamic>? ?? []);
        if (enveloppes.any((e) => e['id'] == source.id)) catSource = doc;
      }
      if (catSource == null) {
        throw Exception('Catégorie non trouvée');
      }
      final srcData = catSource.data() as Map<String, dynamic>;
      final srcEnvs = (srcData['enveloppes'] as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final srcIdx = srcEnvs.indexWhere((e) => e['id'] == source.id);
      if (srcIdx == -1) {
        throw Exception('Enveloppe source non trouvée dans la catégorie');
      }

      // VÉRIFICATION DE PROVENANCE - L'enveloppe ne peut être vidée que vers son compte d'origine
      final List<dynamic> provenances = srcEnvs[srcIdx]['provenances'] ?? [];
      if (provenances.isNotEmpty) {
        final comptesProvenance =
            provenances.map((prov) => prov['compte_id'].toString()).toSet();

        if (!comptesProvenance.contains(destination.id)) {
          throw Exception(
            "Cette enveloppe contient de l'argent qui ne provient pas de ce compte. Vous ne pouvez retourner l'argent que vers son compte d'origine.",
          );
        }
      }

      // Sécurisation en cas de champ solde null pour l'enveloppe source
      final srcOldSolde = (srcEnvs[srcIdx]['solde'] as num?)?.toDouble() ?? 0.0;
      srcEnvs[srcIdx]['solde'] = srcOldSolde - montant;
      // Réinitialiser la provenance si le solde tombe à 0
      if ((srcEnvs[srcIdx]['solde'] as double) == 0.0) {
        srcEnvs[srcIdx]['provenances'] = [];
      }
      transaction.update(catSource.reference, {'enveloppes': srcEnvs});
    });
    // 2. Mise à jour du compte hors transaction enveloppe
    final docDest = _firebaseService.comptesRef.doc(destination.id);
    final snapDest = await docDest.get();
    if (!snapDest.exists) {
      throw Exception('Compte destination non trouvé');
    }
    final snapData = snapDest.data() as Map<String, dynamic>?;
    if (snapData == null) {
      throw Exception('Données du compte destination null');
    }
    final pretAPlacerDest = snapData['pretAPlacer']?.toDouble() ?? 0;
    await docDest.update({'pretAPlacer': pretAPlacerDest + montant});
  }

  /// Ajoute un montant à une enveloppe (utilisé pour Compte -> Enveloppe)
  Future<void> crediterEnveloppe({
    required Enveloppe enveloppe,
    required double montant,
    required String compteId,
  }) async {
    final categoriesRef = _firebaseService.categoriesRef;
    await categoriesRef.firestore.runTransaction((transaction) async {
      QuerySnapshot catSnap = await categoriesRef.get();
      DocumentSnapshot? catDoc;
      for (var doc in catSnap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final enveloppes = (data['enveloppes'] as List<dynamic>? ?? []);
        if (enveloppes.any((e) => e['id'] == enveloppe.id)) catDoc = doc;
      }
      if (catDoc == null) throw Exception('Catégorie non trouvée');
      final catData = catDoc.data() as Map<String, dynamic>;
      final envs = (catData['enveloppes'] as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final idx = envs.indexWhere((e) => e['id'] == enveloppe.id);

      // Sécurisation en cas de champ solde null
      final oldSolde = (envs[idx]['solde'] as num?)?.toDouble() ?? 0.0;

      // NETTOYAGE AGRESSIF des provenances corrompues
      if (envs[idx]['provenances'] != null) {
        final List<dynamic> provenancesRaw =
            envs[idx]['provenances'] as List<dynamic>;
        // Nettoyer TOUTES les provenances avec montant <= 0.01 ou invalides
        final provenancesValides = provenancesRaw.where((prov) {
          if (prov == null || prov is! Map) return false;
          final montantProv = (prov['montant'] as num?)?.toDouble();
          return montantProv != null && montantProv > 0.01;
        }).toList();
        envs[idx]['provenances'] = provenancesValides;
      }

      // Réinitialiser la provenance si le solde est exactement à zéro OU proche de zéro
      if (oldSolde <= 0.01) {
        envs[idx]['provenances'] = [];
        // Aussi effacer l'ancien champ de compatibilité
        envs[idx].remove('provenance_compte_id');
      } else {
        final provenances = envs[idx]['provenances'] as List<dynamic>? ?? [];
        // Blocage uniquement si la liste provenances nettoyée est non vide
        if (provenances.isNotEmpty) {
          final comptesExistants =
              provenances.map((prov) => prov['compte_id'].toString()).toSet();
          if (!comptesExistants.contains(compteId)) {
            throw Exception(
              "L'argent de cette enveloppe provient déjà d'un autre compte.",
            );
          }
        }
      }

      envs[idx]['solde'] = oldSolde + montant;

      // --- Ajout de la mise à jour de l'historique ---
      final now = DateTime.now();
      final moisCourant =
          "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}";
      Map<String, dynamic> historique =
          (envs[idx]['historique'] as Map<String, dynamic>?) ?? {};
      historique[moisCourant] = {
        'depense': envs[idx]['depense'] ?? 0.0,
        'solde': envs[idx]['solde'],
        'objectif': envs[idx]['objectif'] ?? 0.0,
      };
      envs[idx]['historique'] = historique;
      // --- Fin de la mise à jour ---

      // Mise à jour de la provenance multi-comptes
      ajouterOuMettreAJourProvenance(envs[idx], compteId, montant);
      envs[idx]['provenance_compte_id'] = compteId;
      // Sauvegarde aussi la clé 'provenances' dans Firestore
      transaction.update(catDoc.reference, {'enveloppes': envs});
    });
  }

  void ajouterOuMettreAJourProvenance(
    Map<String, dynamic> enveloppe,
    String compteId,
    double montant,
  ) {
    if (enveloppe['provenances'] == null) {
      enveloppe['provenances'] = [];
    }
    final List provenances = enveloppe['provenances'];
    final index = provenances.indexWhere(
      (prov) => prov['compte_id'] == compteId,
    );
    if (index >= 0) {
      provenances[index]['montant'] =
          (provenances[index]['montant'] as num).toDouble() + montant;
    } else {
      provenances.add({'compte_id': compteId, 'montant': montant});
    }
  }

  /// Méthode de nettoyage pour corriger les provenances corrompues dans toute la base de données
  Future<void> nettoyerProvenancesCorrrompues() async {
    final categoriesRef = _firebaseService.categoriesRef;

    await categoriesRef.firestore.runTransaction((transaction) async {
      QuerySnapshot catSnap = await categoriesRef.get();

      for (var catDoc in catSnap.docs) {
        final catData = catDoc.data() as Map<String, dynamic>;
        final envs = (catData['enveloppes'] as List<dynamic>? ?? [])
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        bool modifie = false;

        for (int i = 0; i < envs.length; i++) {
          final env = envs[i];
          final solde = (env['solde'] as num?)?.toDouble() ?? 0.0;

          // Si le solde est proche de zéro, nettoyer complètement les provenances
          if (solde <= 0.01) {
            if (env['provenances'] != null &&
                (env['provenances'] as List).isNotEmpty) {
              env['provenances'] = [];
              env.remove('provenance_compte_id');
              modifie = true;
            }
          } else if (env['provenances'] != null) {
            // Nettoyer les provenances invalides
            final List<dynamic> provenancesOriginales =
                env['provenances'] as List<dynamic>;
            final provenancesValides = provenancesOriginales.where((prov) {
              if (prov == null || prov is! Map) return false;
              final montantProv = (prov['montant'] as num?)?.toDouble();
              return montantProv != null && montantProv > 0.01;
            }).toList();

            if (provenancesValides.length != provenancesOriginales.length) {
              env['provenances'] = provenancesValides;
              modifie = true;
            }
          }
        }

        if (modifie) {
          transaction.update(catDoc.reference, {'enveloppes': envs});
        }
      }
    });
  }

  /// Méthode de DEBUG pour vérifier l'état des provenances
  Future<void> debugProvenances() async {
    final categoriesRef = _firebaseService.categoriesRef;
    QuerySnapshot catSnap = await categoriesRef.get();

    for (var catDoc in catSnap.docs) {
      // Debug silencieux - plus de logs console
    }
  }

  /// Méthode générique pour virer de l'argent entre comptes et/ou enveloppes
  Future<void> virerArgent({
    required String sourceId,
    required String destinationId,
    required double montant,
  }) async {
    // Récupérer tous les comptes et enveloppes
    final comptes = await _firebaseService.lireComptes().first;
    final categories = await _firebaseService.lireCategories().first;
    final enveloppes = categories.expand((cat) => cat.enveloppes).toList();

    // Identifier la source et la destination
    final source = [...comptes, ...enveloppes].firstWhere(
      (item) => (item is Compte ? item.id : (item as Enveloppe).id) == sourceId,
      orElse: () => throw Exception('Source non trouvée'),
    );

    final destination = [...comptes, ...enveloppes].firstWhere(
      (item) =>
          (item is Compte ? item.id : (item as Enveloppe).id) == destinationId,
      orElse: () => throw Exception('Destination non trouvée'),
    );

    // Déterminer le type de virement et appeler la méthode appropriée
    if (source is Compte && destination is Compte) {
      await virementEntreComptes(
        source: source,
        destination: destination,
        montant: montant,
      );
    } else if (source is Enveloppe && destination is Enveloppe) {
      await virementEnveloppeVersEnveloppe(
        source: source,
        destination: destination,
        montant: montant,
      );
    } else if (source is Compte && destination is Enveloppe) {
      // Compte vers Enveloppe : débiter le compte puis créditer l'enveloppe
      await allouerPretAPlacer(compte: source, montant: montant);
      await crediterEnveloppe(
        enveloppe: destination,
        montant: montant,
        compteId: source.id,
      );
    } else if (source is Enveloppe && destination is Compte) {
      await enveloppeVersCompte(
        source: source,
        destination: destination,
        montant: montant,
      );
    } else {
      throw Exception('Type de virement non supporté');
    }

    // Invalider le cache après un virement réussi
    // Invalider seulement les comptes et catégories, pas les transactions
    CacheService.invalidateComptes();
    CacheService.invalidateCategories();
  }

  /// Vide une enveloppe et retourne l'argent dans le prêt à placer du compte d'origine
  Future<void> viderEnveloppe({
    required String enveloppeId,
  }) async {
    print('DEBUG: Début du vidage de l\'enveloppe $enveloppeId');
    final categoriesRef = _firebaseService.categoriesRef;
    final comptesRef = _firebaseService.comptesRef;

    // Récupérer les données avant la transaction
    QuerySnapshot catSnap = await categoriesRef.get();
    DocumentSnapshot? catDoc;
    int envIndex = -1;
    Map<String, dynamic>? enveloppeData;

    // Trouver la catégorie contenant l'enveloppe
    for (var doc in catSnap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final enveloppes = (data['enveloppes'] as List<dynamic>? ?? []);
      final index = enveloppes.indexWhere((e) => e['id'] == enveloppeId);
      if (index != -1) {
        catDoc = doc;
        envIndex = index;
        enveloppeData = Map<String, dynamic>.from(enveloppes[index]);
        break;
      }
    }

    if (catDoc == null || envIndex == -1 || enveloppeData == null) {
      throw Exception('Enveloppe non trouvée');
    }

    final solde = (enveloppeData['solde'] as num?)?.toDouble() ?? 0.0;
    print('DEBUG: Solde de l\'enveloppe: $solde');
    if (solde <= 0) {
      throw Exception('L\'enveloppe est déjà vide');
    }

    // Récupérer les provenances de l'enveloppe
    final List<dynamic> provenances = enveloppeData['provenances'] ?? [];
    print('DEBUG: Provenances trouvées: $provenances');
    print('DEBUG: Type des provenances: ${provenances.runtimeType}');
    print('DEBUG: Nombre de provenances: ${provenances.length}');

    if (provenances.isEmpty) {
      print('DEBUG: ERREUR - Aucune provenance trouvée pour cette enveloppe');
      print('DEBUG: Données complètes de l\'enveloppe: $enveloppeData');
      throw Exception('Aucune provenance trouvée pour cette enveloppe');
    }

    // Maintenant faire la transaction
    await categoriesRef.firestore.runTransaction((transaction) async {
      // Récupérer les données fraîches dans la transaction
      final catSnapFresh = await transaction.get(catDoc!.reference);
      if (!catSnapFresh.exists) {
        throw Exception('Catégorie non trouvée');
      }

      final catData = catSnapFresh.data() as Map<String, dynamic>;
      final envs = (catData['enveloppes'] as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      // Vérifier que l'enveloppe existe toujours
      if (envIndex >= envs.length) {
        throw Exception('Index d\'enveloppe invalide');
      }

      // RÉCUPÉRER D'ABORD TOUTES LES LECTURES
      print('DEBUG: Récupération des prêts à placer actuels');
      final Map<String, double> pretAPlacerActuels = {};

      for (var provenance in provenances) {
        final compteId = provenance['compte_id']?.toString();
        if (compteId != null && compteId.isNotEmpty) {
          final compteDoc = comptesRef.doc(compteId);
          final compteSnap = await transaction.get(compteDoc);

          if (compteSnap.exists) {
            final compteData = compteSnap.data() as Map<String, dynamic>;
            final pretAPlacer =
                (compteData['pretAPlacer'] as num?)?.toDouble() ?? 0.0;
            pretAPlacerActuels[compteId] = pretAPlacer;
            print(
                'DEBUG: Prêt à placer actuel du compte $compteId: $pretAPlacer');
          }
        }
      }

      // MAINTENANT FAIRE TOUTES LES ÉCRITURES
      print('DEBUG: Début des écritures');

      // 1. Vider l'enveloppe
      envs[envIndex]['solde'] = 0.0;
      envs[envIndex]['provenances'] = [];
      envs[envIndex].remove('provenance_compte_id');

      // Mettre à jour l'historique
      final now = DateTime.now();
      final moisCourant =
          "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}";
      Map<String, dynamic> historique =
          (envs[envIndex]['historique'] as Map<String, dynamic>?) ?? {};
      historique[moisCourant] = {
        'depense': envs[envIndex]['depense'] ?? 0.0,
        'solde': 0.0,
        'objectif': envs[envIndex]['objectif'] ?? 0.0,
      };
      envs[envIndex]['historique'] = historique;

      // 2. Mettre à jour la catégorie
      transaction.update(catDoc.reference, {'enveloppes': envs});

      // 3. Mettre à jour les comptes avec les données déjà lues
      for (var provenance in provenances) {
        final compteId = provenance['compte_id']?.toString();
        final montantRaw = provenance['montant'];

        if (compteId != null &&
            compteId.isNotEmpty &&
            pretAPlacerActuels.containsKey(compteId)) {
          double montant = 0.0;
          if (montantRaw is num) {
            montant = montantRaw.toDouble();
          } else if (montantRaw is String) {
            montant = double.tryParse(montantRaw) ?? 0.0;
          }

          if (montant > 0) {
            final pretAPlacerActuel = pretAPlacerActuels[compteId]!;
            final nouveauPretAPlacer = pretAPlacerActuel + montant;

            print(
                'DEBUG: Mise à jour compte $compteId: $pretAPlacerActuel -> $nouveauPretAPlacer');

            final compteDoc = comptesRef.doc(compteId);
            transaction.update(compteDoc, {
              'pretAPlacer': nouveauPretAPlacer,
            });
          }
        }
      }
      print('DEBUG: Fin des écritures');
    });

    print('DEBUG: Transaction terminée, invalidation du cache');
    // Invalider le cache
    CacheService.invalidateComptes();
    CacheService.invalidateCategories();
    print('DEBUG: Vidage de l\'enveloppe terminé');
  }
}
