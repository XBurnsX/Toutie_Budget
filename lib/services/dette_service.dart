import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/dette.dart';
import '../models/compte.dart';
import 'firebase_service.dart';

class DetteService {
  final CollectionReference dettesRef = FirebaseFirestore.instance.collection(
    'dettes',
  );

  Future<void> creerDette(Dette dette) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("Aucun utilisateur connecté");

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

    // Si c'est une dette contractée (type 'dette'), créer automatiquement un compte
    if (dette.type == 'dette') {
      await _creerCompteDetteAutomatique(dette);
    }
  }

  Future<void> _creerCompteDetteAutomatique(Dette dette) async {
    try {
      // Générer un ID unique pour le compte
      final compteId = FirebaseFirestore.instance
          .collection('comptes')
          .doc()
          .id;

      // Créer le compte dette avec un nom formaté
      final nomCompte = "Prêt : ${dette.nomTiers}";

      final compteDette = Compte(
        id: compteId,
        userId: FirebaseAuth.instance.currentUser?.uid,
        nom: nomCompte,
        type: 'Dette',
        solde: -dette.montantInitial, // Négatif car c'est une dette
        couleur: 0xFFE53935, // Rouge pour les dettes
        pretAPlacer: 0.0, // Pas applicable pour les dettes
        dateCreation: dette.dateCreation,
        estArchive: false,
        dateSuppression: null,
        // Nouveau champ pour identifier les comptes liés aux prêts personnels
        detteAssocieeId: dette.id, // Lier le compte à la dette
      );

      // Sauvegarder le compte via FirebaseService
      await FirebaseService().ajouterCompte(compteDette);

      // Lier la dette au compte en ajoutant l'ID du compte dans la dette
      // ET marquer que ce compte a été créé automatiquement
      await dettesRef.doc(dette.id).update({
        'compteAssocie': compteId,
        'compteAutoCreated':
            true, // Marqueur pour identifier les comptes auto-créés
      });
    } catch (e) {
      print('Erreur lors de la création du compte dette automatique: $e');
      // Ne pas bloquer la création de la dette si la création du compte échoue
    }
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

    // Ne plus synchroniser ici car c'est fait dans _recalculerSolde
    // Cette ligne était redondante et pouvait causer des problèmes
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

      // Toujours mettre à jour le compte associé, que le solde soit 0 ou non
      await _mettreAJourCompteAssocie(detteId, nouveauSolde);

      // Si le solde est maintenant à 0, archiver automatiquement la dette
      if (nouveauSolde == 0) {
        await doc.update({'archive': true, 'dateArchivage': Timestamp.now()});

        // Archiver le compte associé si la dette est soldée
        await _archiverCompteAssocie(detteId);
      }
    } catch (e) {
      print('Erreur lors du recalcul du solde: $e');
    }
  }

  Future<void> _mettreAJourCompteAssocie(
    String detteId,
    double nouveauSolde,
  ) async {
    try {
      final detteDoc = await dettesRef.doc(detteId).get();
      if (!detteDoc.exists) return;

      final detteData = detteDoc.data() as Map<String, dynamic>;
      final compteAssocieId = detteData['compteAssocie'] as String?;

      if (compteAssocieId != null) {
        // Mettre à jour le solde du compte à la valeur exacte
        await FirebaseService().updateCompte(compteAssocieId, {
          'solde': -nouveauSolde, // Négatif car c'est une dette
        });
      }
    } catch (e) {
      print('Erreur lors de la mise à jour du compte associé: $e');
    }
  }

  Future<void> _supprimerCompteAssocie(String detteId) async {
    try {
      final detteDoc = await dettesRef.doc(detteId).get();
      if (!detteDoc.exists) return;

      final detteData = detteDoc.data() as Map<String, dynamic>;
      final compteAssocieId = detteData['compteAssocie'] as String?;
      final compteAutoCreated =
          detteData['compteAutoCreated'] as bool? ?? false;

      if (compteAssocieId != null && compteAutoCreated) {
        // Archiver SEULEMENT les comptes créés automatiquement
        await FirebaseService().updateCompte(compteAssocieId, {
          'estArchive': true,
          'dateSuppression': DateTime.now().toIso8601String(),
        });
        print(
          'Compte de dette automatique $compteAssocieId archivé (dette soldée)',
        );
      } else if (compteAssocieId != null && !compteAutoCreated) {
        // Pour les comptes créés manuellement, mettre le solde à 0 et nettoyer le nom
        await _archiverCompteManuelAvecNettoyage(compteAssocieId);
        print(
          'Compte de dette manuel $compteAssocieId mis à jour (solde = 0, compte conservé)',
        );
      }
    } catch (e) {
      print('Erreur lors de la gestion du compte associé: $e');
    }
  }

  Future<void> _archiverCompteManuelAvecNettoyage(String compteId) async {
    try {
      // Récupérer les informations du compte
      final compteDoc = await FirebaseFirestore.instance
          .collection('comptes')
          .doc(compteId)
          .get();
      if (!compteDoc.exists) return;

      final compteData = compteDoc.data() as Map<String, dynamic>;
      final nomActuel = compteData['nom'] as String? ?? '';

      // Nettoyer le nom en enlevant le mot "emprunt"
      String nomNettoye = nomActuel;
      nomNettoye = nomNettoye
          .replaceAll(RegExp(r'\bemprunt\b', caseSensitive: false), '')
          .trim();
      // Nettoyer les espaces multiples
      nomNettoye = nomNettoye.replaceAll(RegExp(r'\s+'), ' ').trim();

      // Mettre à jour le compte avec le solde à 0 et le nom nettoyé
      await FirebaseService().updateCompte(compteId, {
        'solde': 0.0,
        'nom': nomNettoye,
      });

      print(
        'Compte manuel mis à jour: "$nomActuel" → "$nomNettoye" (solde = 0)',
      );
    } catch (e) {
      print('Erreur lors du nettoyage du nom du compte manuel: $e');
    }
  }

  Future<void> archiverDette(String detteId) async {
    final doc = dettesRef.doc(detteId);

    // Archiver la dette
    await doc.update({'archive': true, 'dateArchivage': Timestamp.now()});

    // Archiver le compte associé aussi
    await _archiverCompteAssocie(detteId);
  }

  Future<void> _archiverCompteAssocie(String detteId) async {
    try {
      final detteDoc = await dettesRef.doc(detteId).get();
      if (!detteDoc.exists) return;

      final detteData = detteDoc.data() as Map<String, dynamic>;
      final compteAssocieId = detteData['compteAssocie'] as String?;

      if (compteAssocieId != null) {
        await FirebaseService().updateCompte(compteAssocieId, {
          'estArchive': true,
          'dateSuppression': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      print('Erreur lors de l\'archivage du compte associé: $e');
    }
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

      // Supprimer automatiquement le compte associé quand la dette est soldée
      await _supprimerCompteAssocie(detteId);
    } else {
      await doc.update({'solde': nouveauSolde});
      // Mettre à jour le solde du compte associé
      await _mettreAJourCompteAssocie(detteId, nouveauSolde);
    }
  }
}
