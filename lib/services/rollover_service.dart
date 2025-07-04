import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'firebase_service.dart';

class RolloverService {
  final FirebaseService _firebaseService = FirebaseService();

  Future<bool> processRollover() async {
    final String currentMonthKey = DateFormat('yyyy-MM').format(DateTime.now());

    // Toujours traiter les resets bihebdomadaires, même si le rollover mensuel
    // a déjà été effectué.
    await _processBiweeklyResets();
    await _processYearlyResets();

    final settingsDocRef =
        FirebaseFirestore.instance.collection('user_settings').doc('main');
    final settingsSnapshot = await settingsDocRef.get();

    String? lastRolloverMonth;
    if (settingsSnapshot.exists) {
      lastRolloverMonth = (settingsSnapshot.data()
          as Map<String, dynamic>)['lastRolloverMonth'];
    }

    if (lastRolloverMonth == currentMonthKey) {
      return false;
    }

    final categories = await _firebaseService.lireCategories().first;
    final WriteBatch batch = FirebaseFirestore.instance.batch();

    for (var categorie in categories) {
      bool categoryUpdated = false;
      final List<Map<String, dynamic>> updatedEnveloppes = [];

      for (var enveloppe in categorie.enveloppes) {
        final Map<String, dynamic> envMap = enveloppe.toMap();

        double soldeToRollover = (envMap['solde'] as num?)?.toDouble() ?? 0.0;

        // For the new month, expenses are reset
        envMap['depense'] = 0.0;

        // The balance is the amount rolled over
        envMap['solde'] = soldeToRollover;

        // Update the history for the new month
        Map<String, dynamic> historique =
            (envMap['historique'] as Map<String, dynamic>?) ?? {};
        historique[currentMonthKey] = {
          'solde': envMap['solde'],
          'depense': envMap['depense'],
          'objectif': envMap['objectif'] ?? 0.0,
        };
        envMap['historique'] = historique;

        updatedEnveloppes.add(envMap);
        categoryUpdated = true;
      }

      if (categoryUpdated) {
        final catDocRef = FirebaseFirestore.instance
            .collection('categories')
            .doc(categorie.id);
        batch.update(catDocRef, {'enveloppes': updatedEnveloppes});
      }
    }

    batch.set(settingsDocRef, {'lastRolloverMonth': currentMonthKey},
        SetOptions(merge: true));

    await batch.commit();
    return true;
  }

  /// Parcourt toutes les enveloppes "bihebdo" et remet le compteur de dépense à
  /// zéro dès qu'une nouvelle période de 14 jours commence, en respectant
  /// l'option `objectifJour` (jour de la semaine).
  Future<void> _processBiweeklyResets() async {
    final now = DateTime.now();

    final categories = await _firebaseService.lireCategories().first;
    final WriteBatch batch = FirebaseFirestore.instance.batch();

    for (var categorie in categories) {
      bool categoryUpdated = false;
      final List<Map<String, dynamic>> updatedEnveloppes = [];

      for (var enveloppe in categorie.enveloppes) {
        if (enveloppe.frequenceObjectif.toLowerCase() != 'bihebdo') {
          updatedEnveloppes.add(enveloppe.toMap());
          continue;
        }

        final Map<String, dynamic> envMap = enveloppe.toMap();

        DateTime? lastReset;
        if (envMap['date_dernier_ajout'] != null) {
          lastReset = DateTime.tryParse(envMap['date_dernier_ajout']);
        }

        // Si jamais la valeur est nulle, on considère que nous devons
        // déclencher un reset dès que possible (aujourd'hui si le jour
        // correspond).
        final int? objectifJour =
            envMap['objectif_jour']; // 1 = lundi … 7 = dim.

        bool shouldReset = false;

        if (lastReset == null) {
          if (objectifJour == null || now.weekday == objectifJour) {
            shouldReset = true;
          }
        } else {
          final difference = now.difference(lastReset).inDays;
          if (difference >= 14) {
            // Vérifie qu'on est bien sur le bon jour de la semaine, si défini.
            if (objectifJour == null || now.weekday == objectifJour) {
              shouldReset = true;
            }
          }
        }

        if (shouldReset) {
          envMap['depense'] = 0.0;
          envMap['date_dernier_ajout'] = now.toIso8601String();
          categoryUpdated = true;
        }

        updatedEnveloppes.add(envMap);
      }

      if (categoryUpdated) {
        final catDocRef = FirebaseFirestore.instance
            .collection('categories')
            .doc(categorie.id);
        batch.update(catDocRef, {'enveloppes': updatedEnveloppes});
      }
    }

    // S'il y a des modifications, on les applique.
    await batch.commit();
  }

  /// Réinitialise les enveloppes « annuel » une fois par an à la date cible.
  Future<void> _processYearlyResets() async {
    final now = DateTime.now();

    final categories = await _firebaseService.lireCategories().first;
    final WriteBatch batch = FirebaseFirestore.instance.batch();

    for (var categorie in categories) {
      bool catUpdated = false;
      final List<Map<String, dynamic>> updatedEnveloppes = [];

      for (var enveloppe in categorie.enveloppes) {
        if (enveloppe.frequenceObjectif.toLowerCase() != 'annuel') {
          updatedEnveloppes.add(enveloppe.toMap());
          continue;
        }

        final envMap = enveloppe.toMap();

        // Date cible (jour+mois) stockée dans objectif_date
        if (envMap['objectif_date'] == null) {
          updatedEnveloppes.add(envMap);
          continue;
        }

        DateTime? cible;
        try {
          cible = DateTime.parse(envMap['objectif_date']);
        } catch (_) {}

        if (cible == null) {
          updatedEnveloppes.add(envMap);
          continue;
        }

        // Date cible de cette année
        DateTime cibleThisYear = DateTime(now.year, cible.month, cible.day);
        if (now.isBefore(cibleThisYear)) {
          // Pas encore atteint cette année
          updatedEnveloppes.add(envMap);
          continue;
        }

        // Vérifier si l'année a déjà été reset
        DateTime? lastReset;
        if (envMap['date_dernier_ajout'] != null) {
          lastReset = DateTime.tryParse(envMap['date_dernier_ajout']);
        }

        if (lastReset != null && lastReset.year == now.year) {
          // Déjà réinitialisé cette année
          updatedEnveloppes.add(envMap);
          continue;
        }

        // On reset les dépenses et enregistre la date
        envMap['depense'] = 0.0;
        envMap['date_dernier_ajout'] = now.toIso8601String();
        catUpdated = true;

        updatedEnveloppes.add(envMap);
      }

      if (catUpdated) {
        final docRef = FirebaseFirestore.instance
            .collection('categories')
            .doc(categorie.id);
        batch.update(docRef, {'enveloppes': updatedEnveloppes});
      }
    }

    await batch.commit();
  }
}
