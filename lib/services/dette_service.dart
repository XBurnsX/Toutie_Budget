import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/dette.dart';
import '../models/categorie.dart';
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

    // Debug silencieux

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

    // Créer automatiquement une enveloppe pour cette dette
    await _creerEnveloppePourDette(detteAvecUser);
  }

  Future<void> ajouterMouvement(
    String detteId,
    MouvementDette mouvement, {
    bool estModification = false,
  }) async {
    final doc = dettesRef.doc(detteId);

    final updates = <String, dynamic>{
      'historique': FieldValue.arrayUnion([mouvement.toMap()]),
    };

    // N'incrémenter que si ce n'est PAS une modification
    if ((mouvement.type == 'remboursement_recu' ||
            mouvement.type == 'remboursement_effectue') &&
        !estModification) {
      updates['paiementsEffectues'] = FieldValue.increment(1);
    }

    // Ajouter le mouvement à l'historique
    await doc.update(updates);

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

      // Compter les paiements effectués directement depuis l'historique
      final paiementsCompteur = historique
          .where((m) =>
              m.type == 'remboursement_recu' ||
              m.type == 'remboursement_effectue')
          .length;

      // Vérifier si c'est un prêt amortissable (avec taux d'intérêt)
      final tauxInteret = detteData['tauxInteret'] != null
          ? (detteData['tauxInteret'] as num).toDouble()
          : null;
      final prixAchat = detteData['prixAchat'] != null
          ? (detteData['prixAchat'] as num).toDouble()
          : null;
      final coutTotal = detteData['coutTotal'] != null
          ? (detteData['coutTotal'] as num).toDouble()
          : null;

      // Logique de calcul du solde simplifiée et corrigée
      final baseCalcul = coutTotal ?? montantInitial;

      double totalRemboursements = 0.0;
      for (final mouvement in historique) {
        if (mouvement.type == 'remboursement_recu' ||
            mouvement.type == 'remboursement_effectue') {
          totalRemboursements += mouvement.montant.abs();
        }
      }

      double nouveauSolde = baseCalcul - totalRemboursements;

      // S'assurer que le solde ne devient pas négatif
      if (nouveauSolde < 0) nouveauSolde = 0;

      // Mettre à jour le solde et le compteur de paiements
      Map<String, dynamic> updates = {
        'solde': nouveauSolde,
        'paiementsEffectues': paiementsCompteur,
      };

      await doc.update(updates);

      // Si le solde est maintenant à 0 (ou très proche de 0), archiver automatiquement la dette
      if (nouveauSolde.abs() <= 0.01) {
        // Tolérance de 1 cent
        await doc.update({'archive': true, 'dateArchivage': Timestamp.now()});

        // Supprimer l'enveloppe correspondante seulement si c'était une dette (pas un prêt)
        final typeDette = detteData['type'] as String?;
        final nomTiersDette = detteData['nomTiers'] as String?;
        if (nomTiersDette != null && typeDette == 'dette') {
          await _supprimerEnveloppeDette(nomTiersDette);
        }
      }
    } catch (e) {
      // Erreur silencieuse
    }
  }

  Future<void> archiverDette(String detteId) async {
    final doc = dettesRef.doc(detteId);

    // Récupérer les infos de la dette avant archivage
    String? nomTiersDette;
    final detteDoc = await doc.get();
    if (detteDoc.exists) {
      final data = detteDoc.data() as Map<String, dynamic>;
      nomTiersDette = data['nomTiers'] as String?;
    }

    // Archiver la dette
    await doc.update({'archive': true, 'dateArchivage': Timestamp.now()});

    // Supprimer l'enveloppe correspondante
    if (nomTiersDette != null) {
      await _supprimerEnveloppeDette(nomTiersDette);
    }
  }

  Future<Dette?> getDette(String detteId) async {
    final doc = await dettesRef.doc(detteId).get();
    if (!doc.exists) return null;
    return Dette.fromMap(doc.data() as Map<String, dynamic>);
  }

  Stream<List<Dette>> dettesActives() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value([]);

    return dettesRef
        .where('archive', isEqualTo: false)
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .map((snap) {
      final dettes = snap.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
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

      // Si la dette est manuelle, incrémenter le nombre de paiements effectués
      if (dette.estManuelle) {
        await dettesRef.doc(dette.id).update({
          'paiementsEffectues': FieldValue.increment(1),
        });
      }

      // Si la dette était terminée, vérifier si elle doit être archivée
      // Le solde est maintenant calculé automatiquement par _recalculerSolde()
      if (detteTerminee) {
        final detteActuelle = await getDette(dette.id);
        if (detteActuelle != null && detteActuelle.solde.abs() <= 0.01) {
          await ajusterSoldeEtArchiver(dette.id, 0);
        }
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

    final typeDetteRecherche =
        typeRemboursement == 'remboursement_recu' ? 'pret' : 'dette';
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
    bool aDejaIncremente = false;

    for (final dette in dettesATiers) {
      if (montantRestant <= 0) break;

      final soldeAbsolu = dette.solde.abs();
      final montantAPayer =
          montantRestant >= soldeAbsolu ? soldeAbsolu : montantRestant;

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

      // Si la dette est manuelle, incrémenter le nombre de paiements une seule fois par transaction
      if (dette.estManuelle && !aDejaIncremente) {
        await dettesRef.doc(dette.id).update({
          'paiementsEffectues': FieldValue.increment(1),
        });
        aDejaIncremente = true;
      }

      // Le solde est maintenant calculé automatiquement par _recalculerSolde()
      // lors de l'ajout du mouvement. Plus besoin de calcul linéaire.
      // On vérifie juste si la dette doit être archivée en récupérant le solde actuel.
      final detteActuelle = await getDette(dette.id);
      if (detteActuelle != null && detteActuelle.solde.abs() <= 0.01) {
        await ajusterSoldeEtArchiver(dette.id, 0);
      }

      // Déduire le montant payé du montant restant
      montantRestant -= montantAPayer;

      // Vérifier si la dette est soldée après recalcul automatique
      final detteApresRecalcul = await getDette(dette.id);
      if (detteApresRecalcul != null &&
          detteApresRecalcul.solde.abs() <= 0.01) {
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
    final docRef = dettesRef.doc(detteId);
    final compteRef =
        FirebaseFirestore.instance.collection('comptes').doc(detteId);

    // Récupérer les infos de la dette avant archivage
    String? nomTiersDette;
    if (nouveauSolde <= 0) {
      final detteDoc = await docRef.get();
      if (detteDoc.exists) {
        final data = detteDoc.data() as Map<String, dynamic>;
        nomTiersDette = data['nomTiers'] as String?;
      }
    }

    // Mettre à jour le solde dans la collection 'dettes'
    await docRef.update({'solde': nouveauSolde});

    // Mettre à jour le solde dans la collection 'comptes' (en négatif)
    await compteRef.update({'solde': -nouveauSolde});

    if (nouveauSolde.abs() <= 0.01) {
      // Tolérance de 1 cent
      await docRef.update({
        'archive': true,
        'dateArchivage': FieldValue.serverTimestamp(),
      });
      await compteRef.update({
        'estArchive': true,
        'dateSuppression': DateTime.now().toIso8601String(),
      });

      // Supprimer l'enveloppe correspondante
      if (nomTiersDette != null) {
        await _supprimerEnveloppeDette(nomTiersDette);
      }
    }
  }

  Future<void> ajouterDette(Dette dette) async {
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
      estManuelle: dette.estManuelle,
      tauxInteret: dette.tauxInteret,
      dateFinObjectif: dette.dateFinObjectif,
      montantMensuelCalcule: dette.montantMensuelCalcule,
      dateFin: dette.dateFin,
      montantMensuel: dette.montantMensuel,
      prixAchat: dette.prixAchat,
      coutTotal: dette.coutTotal,
      nombrePaiements: dette.nombrePaiements,
      dateDebut: dette.dateDebut,
      paiementsEffectues: dette.paiementsEffectues,
    );

    // Créer la dette dans Firestore
    await dettesRef.doc(dette.id).set(detteAvecUser.toMap());

    // Créer automatiquement une enveloppe pour cette dette
    await _creerEnveloppePourDette(detteAvecUser);
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

      // Mettre à jour l'objectif de l'enveloppe avec les nouveaux paramètres
      final dette = await getDette(detteId);
      if (dette != null) {
        await _mettreAJourObjectifEnveloppeDette(dette);
      }
    } catch (e) {
      throw Exception('Erreur lors de la sauvegarde des paramètres d\'intérêt');
    }
  }

  /// Sauvegarde tous les paramètres d'une dette manuelle
  Future<void> sauvegarderDetteManuelleComplet(Dette dette) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("Aucun utilisateur connecté");

    final docRef = dettesRef.doc(dette.id);

    try {
      // 1. Mettre à jour l'intégralité du document dans la collection 'dettes'
      await docRef.set(dette.toMap());

      // 2. Mettre à jour l'objectif de l'enveloppe correspondante
      await _mettreAJourObjectifEnveloppeDette(dette);

      // 3. Gérer l'archivage de la dette si le solde est nul ou négatif
      if (dette.solde.abs() <= 0.01) {
        // Tolérance de 1 cent
        await docRef.update({
          'archive': true,
          'dateArchivage': FieldValue.serverTimestamp(),
        });

        // Supprimer l'enveloppe correspondante
        await _supprimerEnveloppeDette(dette.nomTiers);
      }

      // Note: Les dettes manuelles n'ont pas de compte associé dans la collection 'comptes'
      // Elles sont affichées directement depuis la collection 'dettes' dans la page des comptes
    } catch (e) {
      throw Exception('Erreur lors de la sauvegarde complète de la dette');
    }
  }

  /// Met à jour les dettes existantes pour ajouter le champ estManuelle si manquant
  Future<void> mettreAJourDettesExistantes() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("Aucun utilisateur connecté");

    try {
      final dettesQuery = await dettesRef
          .where('userId', isEqualTo: user.uid)
          .where('archive', isEqualTo: false)
          .get();

      for (var doc in dettesQuery.docs) {
        final data = doc.data() as Map<String, dynamic>;

        // Si le champ estManuelle n'existe pas, l'ajouter
        if (!data.containsKey('estManuelle')) {
          await dettesRef.doc(doc.id).update({'estManuelle': true});
        }

        // Vérifier si le solde est proche de 0 et archiver si nécessaire
        final solde = (data['solde'] as num?)?.toDouble() ?? 0.0;
        if (solde.abs() <= 0.01) {
          await doc.reference.update({
            'archive': true,
            'dateArchivage': FieldValue.serverTimestamp(),
          });

          // Supprimer l'enveloppe correspondante
          final nomTiers = data['nomTiers'] as String?;
          if (nomTiers != null) {
            await _supprimerEnveloppeDette(nomTiers);
          }
        }
      }
    } catch (e) {
      // Erreur silencieuse
    }
  }

  /// Crée automatiquement une catégorie "Dette" (ou "Dettes") et une enveloppe pour la dette
  /// Seulement pour les dettes où l'utilisateur doit de l'argent (type 'dette'), pas les prêts
  Future<void> _creerEnveloppePourDette(Dette dette) async {
    try {
      // Ne créer une enveloppe que pour les dettes (pas les prêts)
      if (dette.type != 'dette') {
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Aucun utilisateur connecté");

      final firebaseService = FirebaseService();

      // 1. Vérifier si la catégorie "Dettes" existe déjà
      final categories = await firebaseService.lireCategories().first;
      Categorie? categorieDettes = categories
          .where(
            (cat) =>
                cat.nom.toLowerCase() == 'dettes' ||
                cat.nom.toLowerCase() == 'dette',
          )
          .firstOrNull;

      // 2. Si la catégorie n'existe pas, la créer
      if (categorieDettes == null) {
        final nomCategorie =
            categories.any((cat) => cat.nom.toLowerCase().contains('dette'))
                ? 'Dettes'
                : 'Dettes';
        categorieDettes = Categorie(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          nom: nomCategorie,
          enveloppes: [],
          userId: user.uid,
        );
        await firebaseService.ajouterCategorie(categorieDettes);
      }

      // 3. Créer l'enveloppe pour cette dette
      final enveloppeId = DateTime.now().millisecondsSinceEpoch.toString();

      // Déterminer l'objectif selon les règles spécifiées
      Map<String, dynamic> enveloppeData = {
        'id': enveloppeId,
        'nom': dette.nomTiers,
        'solde': 0.0,
        'depense': 0.0,
        'historique': <String, dynamic>{},
        'provenances': <dynamic>[],
      };

      // À la création initiale, pas d'objectif configuré (sera mis à jour lors de la sauvegarde des paramètres)
      enveloppeData['objectif'] = 0.0;
      enveloppeData['frequence_objectif'] = null;
      enveloppeData['objectif_jour'] = null;

      // 4. Ajouter l'enveloppe à la catégorie
      final nouvellesEnveloppes = [
        ...categorieDettes.enveloppes.map((e) => e.toMap()),
        enveloppeData,
      ];

      final categorieModifiee = Categorie(
        id: categorieDettes.id,
        nom: categorieDettes.nom,
        enveloppes:
            nouvellesEnveloppes.map((e) => Enveloppe.fromMap(e)).toList(),
        userId: user.uid,
      );

      await firebaseService.ajouterCategorie(categorieModifiee);
    } catch (e) {
      // Ne pas faire échouer la création de la dette si l'enveloppe échoue
    }
  }

  /// Supprime l'enveloppe correspondante à une dette lors de son archivage
  Future<void> _supprimerEnveloppeDette(String nomTiersDette) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final firebaseService = FirebaseService();

      // 1. Trouver la catégorie "Dettes"
      final categories = await firebaseService.lireCategories().first;
      final categorieDettes = categories
          .where(
            (cat) =>
                cat.nom.toLowerCase() == 'dettes' ||
                cat.nom.toLowerCase() == 'dette',
          )
          .firstOrNull;

      if (categorieDettes == null) return;

      // 2. Trouver et supprimer l'enveloppe correspondante
      final enveloppesRestantes = categorieDettes.enveloppes
          .where((env) => env.nom != nomTiersDette)
          .toList();

      // 3. Si plus d'enveloppes dans la catégorie "Dettes", supprimer la catégorie entière
      if (enveloppesRestantes.isEmpty) {
        await firebaseService.supprimerCategorie(categorieDettes.id);
      } else {
        // 4. Sinon, mettre à jour la catégorie avec les enveloppes restantes
        final categorieModifiee = Categorie(
          id: categorieDettes.id,
          nom: categorieDettes.nom,
          enveloppes: enveloppesRestantes,
          userId: user.uid,
        );

        await firebaseService.ajouterCategorie(categorieModifiee);
      }
    } catch (e) {
      // Ne pas faire échouer l'archivage si la suppression d'enveloppe échoue
    }
  }

  /// Met à jour l'objectif de l'enveloppe correspondante à une dette
  /// Seulement pour les dettes où l'utilisateur doit de l'argent (type 'dette'), pas les prêts
  Future<void> _mettreAJourObjectifEnveloppeDette(Dette dette) async {
    try {
      // Ne mettre à jour l'objectif que pour les dettes (pas les prêts)
      if (dette.type != 'dette') {
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final firebaseService = FirebaseService();

      // 1. Trouver la catégorie "Dettes"
      final categories = await firebaseService.lireCategories().first;
      final categorieDettes = categories
          .where(
            (cat) =>
                cat.nom.toLowerCase() == 'dettes' ||
                cat.nom.toLowerCase() == 'dette',
          )
          .firstOrNull;

      if (categorieDettes == null) {
        throw Exception("Catégorie 'Dettes' non trouvée.");
      }

      // 2. Trouver l'enveloppe correspondante
      final enveloppes =
          categorieDettes.enveloppes.map((e) => e.toMap()).toList();
      final indexEnveloppe = enveloppes.indexWhere(
        (env) => env['nom'] == dette.nomTiers,
      );

      if (indexEnveloppe == -1) {
        throw Exception(
          "Enveloppe '${dette.nomTiers}' non trouvée dans la catégorie 'Dettes'.",
        );
      }
      // 3. Mettre à jour l'objectif selon les nouvelles règles
      if (dette.estManuelle &&
          dette.coutTotal != null &&
          dette.dateDebut != null) {
        // Dette manuelle avec coût total → objectif mensuel au jour du début
        enveloppes[indexEnveloppe]['objectif'] = dette.montantMensuel ?? 0.0;
        enveloppes[indexEnveloppe]['frequence_objectif'] = 'mensuel';
        enveloppes[indexEnveloppe]['objectif_jour'] = dette.dateDebut!.day;
      } else {
        // Dette automatique ou dette manuelle sans coût total → aucun objectif
        enveloppes[indexEnveloppe]['objectif'] = 0.0;
        enveloppes[indexEnveloppe]['frequence_objectif'] = null;
        enveloppes[indexEnveloppe]['objectif_jour'] = null;
      }

      // 4. Sauvegarder la catégorie modifiée
      final categorieModifiee = Categorie(
        id: categorieDettes.id,
        nom: categorieDettes.nom,
        enveloppes: enveloppes.map((e) => Enveloppe.fromMap(e)).toList(),
        userId: user.uid,
      );

      await firebaseService.ajouterCategorie(categorieModifiee);
    } catch (e) {
      // Propage l'erreur pour qu'elle soit visible dans l'UI
      rethrow;
    }
  }

  /// Ajoute une série de paiements passés à une dette
  Future<void> ajouterPaiementsPasses(
    String detteId,
    List<MouvementDette> mouvements,
  ) async {
    final doc = dettesRef.doc(detteId);

    // Mettre à jour en une seule opération
    await doc.update({
      'historique':
          FieldValue.arrayUnion(mouvements.map((m) => m.toMap()).toList()),
    });

    // Recalculer le solde une seule fois après l'ajout de tous les mouvements
    await _recalculerSolde(detteId);
  }

  Future<void> enregistrerPaiementsPasses(
      String detteId,
      double nouveauSolde,
      int nouveauCompteurPaiements,
      List<MouvementDette> nouveauxMouvements) async {
    final doc = dettesRef.doc(detteId);
    await doc.update({
      'solde': nouveauSolde,
      'paiementsEffectues': nouveauCompteurPaiements,
      'historique': FieldValue.arrayUnion(
          nouveauxMouvements.map((m) => m.toMap()).toList()),
    });
  }

  Future<void> definirObjectifEnveloppeDette(
      String nomTiers, double montantObjectif, int jourDuMois) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final enveloppesRef = FirebaseFirestore.instance.collection('enveloppes');

    // Le nom de l'enveloppe est directement le nom du tiers pour les dettes
    final nomEnveloppe = nomTiers;

    final query = await enveloppesRef
        .where('userId', isEqualTo: user.uid)
        .where('nom', isEqualTo: nomEnveloppe)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      final docId = query.docs.first.id;
      await enveloppesRef.doc(docId).update({
        'objectif': montantObjectif,
        'typeObjectif': 'mensuel',
        'jourObjectif': jourDuMois,
        'dateObjectif': null, // On s'assure que l'ancien type est nettoyé
      });
    }
  }
}
