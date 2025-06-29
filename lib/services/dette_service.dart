import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/dette.dart';
import '../models/compte.dart';
import 'firebase_service.dart';

class DetteService {
  final CollectionReference dettesRef = FirebaseFirestore.instance.collection(
    'dettes',
  );

  Future<void> creerDette(
    Dette dette, {
    bool creerCompteAutomatique = true,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("Aucun utilisateur connecté");

    print(
      'DEBUG: DetteService.creerDette appelé pour dette ID: ${dette.id}, nomTiers: ${dette.nomTiers}, type: ${dette.type}, creerCompteAutomatique: $creerCompteAutomatique',
    );

    final detteAvecUser = Dette(
      id: dette.id,
      nomTiers: dette.nomTiers,
      montantInitial: dette.montantInitial,
      solde: dette.solde,
      type: dette.type,
      historique: dette.historique,
      archive: dette.archive,
      dateCreation: dette.dateCreation,
      dateArchivage: dette.dateArchivage,
      userId: user.uid,
    );

    // Créer la dette dans Firestore
    await dettesRef.doc(dette.id).set(detteAvecUser.toMap());
    print('DEBUG: Dette sauvegardée dans Firestore: ${dette.id}');
  }

  Future<void> ajouterMouvement(
    String detteId,
    MouvementDette mouvement,
  ) async {
    final doc = dettesRef.doc(detteId);

    // Ajouter le mouvement à l'historique
    await doc.update({
      'historique': FieldValue.arrayUnion([mouvement.toMap()]),
    });

    // Recalculer et mettre à jour le solde automatiquement
    await _recalculerSolde(detteId);
  }

  Future<void> _recalculerSolde(String detteId) async {
    try {
      // Récupérer la dette avec son historique complet
      final doc = dettesRef.doc(detteId);
      final detteDoc = await doc.get();
      if (!detteDoc.exists) return;

      final detteData = detteDoc.data() as Map<String, dynamic>;
      final montantInitial = (detteData['montantInitial'] as num).toDouble();
      final historique = (detteData['historique'] as List<dynamic>? ?? [])
          .map((item) => MouvementDette.fromMap(item as Map<String, dynamic>))
          .toList();

      // Calculer le nouveau solde basé sur l'historique
      double nouveauSolde = montantInitial;

      for (MouvementDette mouvement in historique) {
        // Les remboursements sont stockés avec un montant négatif, donc on les additionne directement
        if (mouvement.type == 'remboursement_recu' ||
            mouvement.type == 'remboursement_effectue') {
          nouveauSolde += mouvement.montant; // montant est déjà négatif
        }
      }

      // S'assurer que le solde ne devient pas négatif
      nouveauSolde = nouveauSolde < 0 ? 0 : nouveauSolde;

      // Mettre à jour le solde dans Firestore
      await doc.update({'solde': nouveauSolde});

      // Si le solde est maintenant à 0, archiver automatiquement la dette
      if (nouveauSolde == 0) {
        await doc.update({'archive': true, 'dateArchivage': Timestamp.now()});
      }
    } catch (e) {
      print('Erreur lors du recalcul du solde: $e');
    }
  }

  Future<void> archiverDette(String detteId) async {
    final doc = dettesRef.doc(detteId);

    // Archiver la dette
    await doc.update({'archive': true, 'dateArchivage': Timestamp.now()});
  }

  Future<Dette?> getDette(String detteId) async {
    final doc = await dettesRef.doc(detteId).get();
    if (!doc.exists) return null;
    return Dette.fromMap(doc.data() as Map<String, dynamic>);
  }

  Stream<List<Dette>> dettesActives() {
    final user = FirebaseAuth.instance.currentUser;
    print('DEBUG - Utilisateur connecté: ${user?.uid}');
    if (user == null) return Stream.value([]);

    return dettesRef
        .where('archive', isEqualTo: false)
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .map((snap) {
          print('DEBUG - Nombre de dettes trouvées: ${snap.docs.length}');
          final dettes = snap.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            print(
              'DEBUG - Dette trouvée: ${doc.id}, userId: ${data['userId']}, nomTiers: ${data['nomTiers']}',
            );
            return Dette.fromMap(data);
          }).toList();
          return dettes;
        });
  }

  Stream<List<Dette>> dettesArchivees() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value([]);
    return dettesRef
        .where('archive', isEqualTo: true)
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => Dette.fromMap(doc.data() as Map<String, dynamic>))
              .toList(),
        );
  }

  // Nouvelle méthode pour gérer les remboursements en cascade
  Future<void> effectuerRemboursementCascade(
    String nomTiers,
    double montantTotal,
    String typeRemboursement,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("Aucun utilisateur connecté");

    // Récupérer toutes les dettes actives du tiers, triées par date de création (FIFO)
    final dettesQuery = await dettesRef
        .where('userId', isEqualTo: user.uid)
        .where('nomTiers', isEqualTo: nomTiers)
        .where('archive', isEqualTo: false)
        .where('solde', isGreaterThan: 0)
        .get();

    if (dettesQuery.docs.isEmpty) {
      throw Exception("Aucune dette active trouvée pour $nomTiers");
    }

    // Convertir en objets Dette et trier par date de création
    List<Dette> dettesActives = dettesQuery.docs
        .map((doc) => Dette.fromMap(doc.data() as Map<String, dynamic>))
        .toList();

    dettesActives.sort((a, b) => a.dateCreation.compareTo(b.dateCreation));

    double montantRestant = montantTotal;

    // Traitement en cascade
    for (Dette dette in dettesActives) {
      if (montantRestant <= 0) break;

      double montantPourCetteDette = montantRestant;
      bool detteTerminee = false;

      if (montantPourCetteDette >= dette.solde) {
        // Le montant couvre entièrement cette dette
        montantPourCetteDette = dette.solde;
        montantRestant -= dette.solde;
        detteTerminee = true;
      } else {
        // Le montant ne couvre que partiellement cette dette
        montantRestant = 0;
      }

      // Créer le mouvement de remboursement
      final mouvement = MouvementDette(
        id: FirebaseFirestore.instance.collection('mouvements').doc().id,
        date: DateTime.now(),
        montant: -montantPourCetteDette, // Négatif car c'est un remboursement
        type: typeRemboursement,
        note: 'Remboursement automatique en cascade',
      );

      // Ajouter le mouvement à la dette
      await ajouterMouvement(dette.id, mouvement);

      // Si la dette est terminée, l'archiver automatiquement
      if (detteTerminee) {
        await ajusterSoldeEtArchiver(dette.id, 0);
      }
    }

    if (montantRestant > 0) {
      throw Exception(
        "Montant excédentaire de ${montantRestant.toStringAsFixed(2)}\$ - toutes les dettes de $nomTiers sont remboursées",
      );
    }
  }

  // Méthode pour obtenir le total des dettes d'un tiers
  Future<double> getTotalDettesActives(String nomTiers) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 0;

    final dettesQuery = await dettesRef
        .where('userId', isEqualTo: user.uid)
        .where('nomTiers', isEqualTo: nomTiers)
        .where('archive', isEqualTo: false)
        .where('solde', isGreaterThan: 0)
        .get();

    double total = 0;
    for (var doc in dettesQuery.docs) {
      final dette = Dette.fromMap(doc.data() as Map<String, dynamic>);
      total += dette.solde;
    }

    return total;
  }

  // Méthode pour obtenir la liste des tiers avec dettes actives
  Future<List<String>> getTiersAvecDettesActives() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    final dettesQuery = await dettesRef
        .where('userId', isEqualTo: user.uid)
        .where('archive', isEqualTo: false)
        .where('solde', isGreaterThan: 0)
        .get();

    Set<String> tiers = {};
    for (var doc in dettesQuery.docs) {
      final dette = Dette.fromMap(doc.data() as Map<String, dynamic>);
      tiers.add(dette.nomTiers);
    }

    return tiers.toList()..sort();
  }

  /// Nouvelle méthode : Remboursement en cascade automatique
  /// Gère le remboursement de plusieurs dettes d'un même tiers dans l'ordre
  /// Archive automatiquement les dettes soldées et continue sur la suivante
  Future<List<String>> remboursementEnCascade({
    required String nomTiers,
    required double montantTotal,
    required String
    typeRemboursement, // 'remboursement_recu' ou 'remboursement_effectue'
    required String transactionId,
    String? note,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("Aucun utilisateur connecté");

    final typeDetteRecherche = typeRemboursement == 'remboursement_recu'
        ? 'pret'
        : 'dette';
    final dettes = await dettesActives().first;

    // Filtrer et trier les dettes du tiers par date de création (plus ancien en premier)
    final dettesATiers = dettes
        .where((d) => d.nomTiers == nomTiers && d.type == typeDetteRecherche)
        .toList();

    // Trier par date de création (plus ancien en premier)
    dettesATiers.sort((a, b) => a.dateCreation.compareTo(b.dateCreation));

    double montantRestant = montantTotal;
    final List<String> messagesArchivage = [];
    final DateTime maintenant = DateTime.now();

    for (final dette in dettesATiers) {
      if (montantRestant <= 0) break;

      final soldeAbsolu = dette.solde.abs();
      final montantAPayer = montantRestant >= soldeAbsolu
          ? soldeAbsolu
          : montantRestant;

      // Créer le mouvement pour cette dette
      final mouvement = MouvementDette(
        id: '${transactionId}_${dette.id}',
        date: maintenant,
        montant: typeRemboursement == 'remboursement_recu'
            ? -montantAPayer
            : montantAPayer, // Positif pour remboursement effectué, négatif pour remboursement reçu
        type: typeRemboursement,
        note: note ?? 'Remboursement automatique en cascade',
      );

      // Ajouter le mouvement à l'historique (sans modifier le solde automatiquement)
      await ajouterMouvement(dette.id, mouvement);

      // Calculer le nouveau solde selon le type
      double nouveauSolde;
      if (typeRemboursement == 'remboursement_recu') {
        // Pour un prêt : le solde diminue quand on reçoit un remboursement
        nouveauSolde = dette.solde - montantAPayer;
      } else {
        // Pour une dette contractée : le solde diminue quand on rembourse
        nouveauSolde = dette.solde - montantAPayer;
      }

      // Ajuster le solde et archiver si nécessaire
      await ajusterSoldeEtArchiver(dette.id, nouveauSolde);

      // Déduire le montant payé du montant restant
      montantRestant -= montantAPayer;

      // Vérifier si la dette est soldée
      if (nouveauSolde <= 0) {
        messagesArchivage.add(
          '${typeDetteRecherche == 'pret' ? 'Prêt à' : 'Dette envers'} ${dette.nomTiers} de ${dette.montantInitial.toStringAsFixed(2)}\$ soldé et archivé.',
        );
      }
    }

    // Si il reste encore de l'argent et aucune dette active trouvée
    if (montantRestant > 0) {
      messagesArchivage.add(
        'Remboursement partiel : ${(montantTotal - montantRestant).toStringAsFixed(2)}\$ appliqué. ${montantRestant.toStringAsFixed(2)}\$ non utilisé (aucune dette active trouvée).',
      );
    }

    return messagesArchivage;
  }

  /// Méthode utilitaire pour obtenir le total des dettes d'un tiers
  Future<double> getTotalDettesTiers(String nomTiers, String typeDette) async {
    final dettes = await dettesActives().first;
    return dettes
        .where((d) => d.nomTiers == nomTiers && d.type == typeDette)
        .fold<double>(
          0.0,
          (double total, Dette dette) => total + dette.solde.abs(),
        );
  }

  Future<void> ajusterSoldeEtArchiver(
    String detteId,
    double nouveauSolde,
  ) async {
    final doc = dettesRef.doc(detteId);

    if (nouveauSolde <= 0) {
      // Dette remboursée complètement
      await doc.update({
        'solde': 0,
        'archive': true,
        'dateArchivage': Timestamp.now(),
      });
    } else {
      await doc.update({'solde': nouveauSolde});
    }
  }

  Future<void> ajouterDette(Dette dette) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("Aucun utilisateur connecté");

    print(
      'DEBUG: DetteService.ajouterDette appelé pour dette ID: ${dette.id}, nomTiers: ${dette.nomTiers}, type: ${dette.type}',
    );

    final detteAvecUser = Dette(
      id: dette.id,
      nomTiers: dette.nomTiers,
      montantInitial: dette.montantInitial,
      solde: dette.solde,
      type: dette.type,
      historique: dette.historique,
      archive: dette.archive,
      dateCreation: dette.dateCreation,
      dateArchivage: dette.dateArchivage,
      userId: user.uid,
    );

    // Créer la dette dans Firestore
    await dettesRef.doc(dette.id).set(detteAvecUser.toMap());
    print('DEBUG: Dette sauvegardée dans Firestore: ${dette.id}');
  }

  /// Sauvegarde les paramètres d'intérêt d'une dette manuelle
  Future<void> sauvegarderParametresInteret({
    required String detteId,
    required double tauxInteret,
    required DateTime dateFinObjectif,
    required double montantMensuelCalcule,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("Aucun utilisateur connecté");

    try {
      await dettesRef.doc(detteId).update({
        'tauxInteret': tauxInteret,
        'dateFinObjectif': Timestamp.fromDate(dateFinObjectif),
        'montantMensuelCalcule': montantMensuelCalcule,
      });

      print('DEBUG: Paramètres d\'intérêt sauvegardés pour dette: $detteId');
    } catch (e) {
      print('Erreur lors de la sauvegarde des paramètres d\'intérêt: $e');
      throw Exception('Erreur lors de la sauvegarde des paramètres d\'intérêt');
    }
  }

  /// Sauvegarde tous les paramètres d'une dette manuelle
  Future<void> sauvegarderParametresDette(Dette dette) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("Aucun utilisateur connecté");

    try {
      final updates = <String, dynamic>{};

      if (dette.tauxInteret != null) {
        updates['tauxInteret'] = dette.tauxInteret;
      }
      if (dette.dateDebut != null) {
        updates['dateDebut'] = Timestamp.fromDate(dette.dateDebut!);
      }
      if (dette.dateFin != null) {
        updates['dateFin'] = Timestamp.fromDate(dette.dateFin!);
      }
      if (dette.montantMensuel != null) {
        updates['montantMensuel'] = dette.montantMensuel;
      }
      if (dette.prixAchat != null) {
        updates['prixAchat'] = dette.prixAchat;
      }
      if (dette.nombrePaiements != null) {
        updates['nombrePaiements'] = dette.nombrePaiements;
      }
      if (dette.paiementsEffectues != null) {
        updates['paiementsEffectues'] = dette.paiementsEffectues;
      }

      await dettesRef.doc(dette.id).update(updates);
      print('DEBUG: Paramètres de dette sauvegardés pour dette: ${dette.id}');
    } catch (e) {
      print('Erreur lors de la sauvegarde des paramètres de dette: $e');
      throw Exception('Erreur lors de la sauvegarde des paramètres de dette');
    }
  }
}
