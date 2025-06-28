import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'firebase_service.dart';

class RolloverService {
  final FirebaseService _firebaseService = FirebaseService();

  Future<bool> processRollover() async {
    final String currentMonthKey = DateFormat('yyyy-MM').format(DateTime.now());

    final settingsDocRef = FirebaseFirestore.instance.collection('user_settings').doc('main');
    final settingsSnapshot = await settingsDocRef.get();

    String? lastRolloverMonth;
    if (settingsSnapshot.exists) {
      lastRolloverMonth = (settingsSnapshot.data() as Map<String, dynamic>)['lastRolloverMonth'];
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
        Map<String, dynamic> historique = (envMap['historique'] as Map<String, dynamic>?) ?? {};
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
        final catDocRef = FirebaseFirestore.instance.collection('categories').doc(categorie.id);
        batch.update(catDocRef, {'enveloppes': updatedEnveloppes});
      }
    }

    batch.set(settingsDocRef, {'lastRolloverMonth': currentMonthKey}, SetOptions(merge: true));

    await batch.commit();
    return true;
  }
}
