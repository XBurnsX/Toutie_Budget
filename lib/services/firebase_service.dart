import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/compte.dart';
import '../models/categorie.dart';
import '../models/transaction_model.dart' as app_model;
import '../models/dette.dart';
import 'dette_service.dart';
import 'firebase_monitor_service.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Getter pour accéder à l'instance de Firestore
  FirebaseFirestore get firestore => FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  final CollectionReference comptesRef = FirebaseFirestore.instance.collection(
    'comptes',
  );
  final CollectionReference categoriesRef =
      FirebaseFirestore.instance.collection('categories');
  final CollectionReference tiersRef = FirebaseFirestore.instance.collection(
    'tiers',
  );

  FirebaseAuth get auth => _auth;

  Future<UserCredential> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    final GoogleSignInAuthentication? googleAuth =
        await googleUser?.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth?.accessToken,
      idToken: googleAuth?.idToken,
    );
    return await _auth.signInWithCredential(credential);
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  Future<void> ajouterCompte(Compte compte) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("Aucun utilisateur n'est connecté.");

    // Logger l'écriture
    FirebaseMonitorService.logWrite(
      collection: 'comptes',
      document: compte.id,
      count: 1,
      userId: user.uid,
      details: 'Ajout compte: ${compte.nom}',
    );

    final compteAvecUser = Compte(
      id: compte.id,
      userId: user.uid,
      nom: compte.nom,
      type: compte.type,
      solde: compte.solde,
      couleur: compte.couleur,
      pretAPlacer: compte.pretAPlacer,
      dateCreation: compte.dateCreation,
      estArchive: compte.estArchive,
    );

    await comptesRef.doc(compte.id).set(compteAvecUser.toMap());
  }

  Future<void> ajouterCategorie(Categorie categorie) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("Aucun utilisateur n'est connecté.");

    // Logger l'écriture
    FirebaseMonitorService.logWrite(
      collection: 'categories',
      document: categorie.id,
      count: 1,
      userId: user.uid,
      details: 'Ajout catégorie: ${categorie.nom}',
    );

    // Assure que la catégorie est bien associée à l'utilisateur actuel
    final categorieAvecUser = Categorie(
      id: categorie.id,
      userId: user.uid, // On force l'ID de l'utilisateur connecté
      nom: categorie.nom,
      enveloppes: categorie.enveloppes,
      ordre: categorie.ordre,
    );
    await categoriesRef.doc(categorie.id).set(categorieAvecUser.toMap());
  }

  Stream<List<Categorie>> lireCategories() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value([]); // Retourne un stream vide si pas d'utilisateur
    }

    // Logger la requête
    FirebaseMonitorService.logQuery(
      collection: 'categories',
      document: 'user_${user.uid}',
      count: 1,
      userId: user.uid,
      details: 'Lecture des catégories utilisateur',
    );

    return categoriesRef
        .where(
          'userId',
          isEqualTo: user.uid,
        ) // Ne lit que les catégories de l'utilisateur
        .snapshots()
        .map((snapshot) {
      final categories = snapshot.docs
          .map(
            (doc) => Categorie.fromMap(doc.data() as Map<String, dynamic>),
          )
          .toList();

      // Logger le nombre de documents lus
      FirebaseMonitorService.logRead(
        collection: 'categories',
        document: 'user_${user.uid}',
        count: snapshot.docs.length,
        userId: user.uid,
        details: '${snapshot.docs.length} catégories lues',
      );

      // Trier les catégories : Dette toujours en premier, puis par ordre
      categories.sort((a, b) {
        // Forcer "Dette" en premier, insensible à la casse
        final aNom = a.nom.toLowerCase();
        final bNom = b.nom.toLowerCase();
        if (aNom == 'dette' || aNom == 'dettes') return -1;
        if (bNom == 'dette' || bNom == 'dettes') return 1;
        // Ensuite trier par ordre
        final aOrdre = a.ordre ?? 999999;
        final bOrdre = b.ordre ?? 999999;
        return aOrdre.compareTo(bOrdre);
      });

      return categories;
    });
  }

  Future<void> ajouterTransaction(app_model.Transaction transaction) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("Aucun utilisateur n'est connecté.");

    final transactionAvecUser = app_model.Transaction(
      id: transaction.id,
      userId: user.uid,
      type: transaction.type,
      typeMouvement: transaction.typeMouvement,
      montant: transaction.montant,
      compteId: transaction.compteId,
      date: transaction.date,
      tiers: transaction.tiers,
      compteDePassifAssocie: transaction.compteDePassifAssocie,
      enveloppeId: transaction.enveloppeId,
      marqueur: transaction.marqueur,
      note: transaction.note,
      estFractionnee: transaction.estFractionnee,
      sousItems: transaction.sousItems,
    );

    // Logger l'écriture de la transaction
    FirebaseMonitorService.logWrite(
      collection: 'transactions',
      document: transaction.id,
      count: 1,
      userId: user.uid,
      details:
          'Ajout transaction: ${transaction.tiers ?? 'Sans tiers'} - ${transaction.montant}€',
    );

    // 1. Sauvegarder la transaction
    await firestore
        .collection('transactions')
        .doc(transaction.id)
        .set(transactionAvecUser.toJson());

    // 2. Mettre à jour le solde du compte (avec gestion des prêts à placer)
    await _mettreAJourSoldeCompte(
      transaction.compteId,
      transaction.montant,
      transaction.type,
      transaction.typeMouvement,
    );

    // 2.5. Mettre à jour le compte de passif associé si présent (pour les prêts/dettes)
    if (transaction.compteDePassifAssocie != null &&
        transaction.compteDePassifAssocie!.isNotEmpty) {
      await _mettreAJourComptePassifAssocie(
        transaction.compteDePassifAssocie!,
        transaction.montant,
        transaction.typeMouvement,
      );
    }

    // 3. Mettre à jour les soldes des enveloppes
    if (transaction.estFractionnee == true && transaction.sousItems != null) {
      // Transaction fractionnée - mettre à jour plusieurs enveloppes
      for (var sousItem in transaction.sousItems!) {
        final enveloppeId = sousItem['enveloppeId'] as String?;
        final montantSousItem =
            (sousItem['montant'] as num?)?.toDouble() ?? 0.0;

        if (enveloppeId != null && montantSousItem > 0) {
          await _mettreAJourSoldeEnveloppe(
            enveloppeId,
            montantSousItem,
            transaction.type,
          );
        }
      }
    } else if (transaction.enveloppeId != null &&
        transaction.enveloppeId!.isNotEmpty) {
      // Transaction normale - mettre à jour une seule enveloppe
      await _mettreAJourSoldeEnveloppe(
        transaction.enveloppeId!,
        transaction.montant,
        transaction.type,
      );
    }

    // 4. Si la transaction est un remboursement effectué sur une dette manuelle,
    //    créer un mouvement pour mettre à jour automatiquement la dette (historique,
    //    solde, paiementsEffectues).
    if (transaction.typeMouvement ==
            app_model.TypeMouvementFinancier.remboursementEffectue &&
        transaction.compteDePassifAssocie != null &&
        transaction.compteDePassifAssocie!.isNotEmpty) {
      try {
        final detteDoc = await firestore
            .collection('dettes')
            .doc(transaction.compteDePassifAssocie!)
            .get();

        if (detteDoc.exists) {
          final data = detteDoc.data() as Map<String, dynamic>;
          final estManuelle = data['estManuelle'] == true;

          if (estManuelle) {
            final mouvement = MouvementDette(
              id: firestore.collection('mouvements').doc().id,
              date: transaction.date,
              montant: -transaction
                  .montant, // négatif pour un remboursement effectué
              type: 'remboursement_effectue',
              note:
                  transaction.note ?? 'Remboursement effectué via transaction',
            );

            await DetteService().ajouterMouvement(
              transaction.compteDePassifAssocie!,
              mouvement,
            );
          }
        }
      } catch (e) {
        // Ne pas faire échouer toute la transaction si la mise à jour de la dette échoue.
        // Erreur silencieuse
      }
    }
  }

  /// Crée une transaction interne pour refléter un ajustement de solde sur une dette manuelle
  Future<void> creerTransactionAjustementSoldeDette({
    required String detteId,
    required String nomCompte,
    required double montantAjustement,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("Aucun utilisateur n'est connecté.");

    // Le montant de l'ajustement est la différence, on le considère comme une "dépense"
    // si le solde a diminué (remboursement), ou un "revenu" si le solde a augmenté.
    final typeTransaction = montantAjustement > 0
        ? app_model.TypeTransaction.depense
        : app_model.TypeTransaction.revenu;

    final transaction = app_model.Transaction(
      id: firestore.collection('transactions').doc().id,
      userId: user.uid,
      type: typeTransaction,
      typeMouvement: app_model.TypeMouvementFinancier.ajustement,
      montant: montantAjustement.abs(),
      compteId: detteId, // L'ID de la dette est utilisé comme compteId
      date: DateTime.now(),
      tiers: 'Ajustement de solde',
      note: 'Ajustement automatique du solde de la dette: $nomCompte',
      estFractionnee: false,
      // On ne lie pas à une enveloppe pour ne pas impacter le budget
      enveloppeId: null,
    );

    // On sauvegarde la transaction SANS mettre à jour les soldes d'enveloppe
    await firestore
        .collection('transactions')
        .doc(transaction.id)
        .set(transaction.toJson());
  }

  // Méthode helper pour mettre à jour le solde d'un compte
  Future<void> _mettreAJourSoldeCompte(
    String compteId,
    double montant,
    app_model.TypeTransaction typeTransaction,
    app_model.TypeMouvementFinancier typeMouvement,
  ) async {
    final compteRef = comptesRef.doc(compteId);

    await firestore.runTransaction((transaction) async {
      final compteSnapshot = await transaction.get(compteRef);

      if (compteSnapshot.exists) {
        final compteData = compteSnapshot.data() as Map<String, dynamic>;
        final soldeActuel = (compteData['solde'] as num?)?.toDouble() ?? 0.0;
        final pretAPlacerActuel =
            (compteData['pretAPlacer'] as num?)?.toDouble() ?? 0.0;

        double nouveauSolde;
        double nouveauPretAPlacer = pretAPlacerActuel;

        // Calculer le nouveau solde
        if (typeTransaction == app_model.TypeTransaction.depense) {
          nouveauSolde = soldeActuel - montant;
        } else {
          nouveauSolde = soldeActuel + montant;
        }

        // Gérer les prêts à placer selon le type de mouvement
        switch (typeMouvement) {
          case app_model.TypeMouvementFinancier.revenuNormal:
            // Revenu normal (import CSV) : augmenter le prêt à placer
            nouveauPretAPlacer = pretAPlacerActuel + montant;
            break;

          case app_model.TypeMouvementFinancier.depenseNormale:
            // Dépense normale (import CSV) : NE PAS toucher au prêt à placer
            // Le prêt à placer sera ajusté à la fin par la remise à zéro des enveloppes
            // Ici on ne modifie que le solde du compte
            break;

          case app_model.TypeMouvementFinancier.remboursementRecu:
            // Remboursement reçu : augmenter le prêt à placer
            nouveauPretAPlacer = pretAPlacerActuel + montant;
            break;

          case app_model.TypeMouvementFinancier.pretAccorde:
            // Prêt accordé : diminuer le prêt à placer
            nouveauPretAPlacer = pretAPlacerActuel - montant;
            if (nouveauPretAPlacer < 0) nouveauPretAPlacer = 0;
            break;

          case app_model.TypeMouvementFinancier.detteContractee:
            // Dette contractée : augmenter le prêt à placer (argent emprunté disponible pour prêter)
            nouveauPretAPlacer = pretAPlacerActuel + montant;
            break;

          case app_model.TypeMouvementFinancier.remboursementEffectue:
            // Remboursement effectué : diminuer le prêt à placer (argent utilisé pour rembourser)
            nouveauPretAPlacer = pretAPlacerActuel - montant;
            if (nouveauPretAPlacer < 0) nouveauPretAPlacer = 0;
            break;

          default:
            // Pour les autres types de mouvement, pas de changement du prêt à placer
            break;
        }

        transaction.update(compteRef, {
          'solde': nouveauSolde,
          'pretAPlacer': nouveauPretAPlacer,
        });
      }
    });
  }

  // Nouvelle méthode pour mettre à jour le compte de passif associé (prêts/dettes)
  Future<void> _mettreAJourComptePassifAssocie(
    String comptePassifId,
    double montant,
    app_model.TypeMouvementFinancier typeMouvement,
  ) async {
    final compteRef = comptesRef.doc(comptePassifId);

    await firestore.runTransaction((transaction) async {
      final compteSnapshot = await transaction.get(compteRef);

      if (compteSnapshot.exists) {
        final compteData = compteSnapshot.data() as Map<String, dynamic>;
        final soldeActuel = (compteData['solde'] as num?)?.toDouble() ?? 0.0;
        final pretAPlacerActuel =
            (compteData['pretAPlacer'] as num?)?.toDouble() ?? 0.0;

        double nouveauSolde = soldeActuel;
        double nouveauPretAPlacer = pretAPlacerActuel;

        switch (typeMouvement) {
          case app_model.TypeMouvementFinancier.detteContractee:
            // Dette contractée : diminuer le solde (plus négatif)
            nouveauSolde = soldeActuel - montant;
            break;

          case app_model.TypeMouvementFinancier.pretAccorde:
            // Prêt accordé : augmenter le solde et le prêt à placer
            nouveauSolde = soldeActuel + montant;
            nouveauPretAPlacer = pretAPlacerActuel + montant;
            break;

          case app_model.TypeMouvementFinancier.remboursementRecu:
            // Remboursement reçu : diminuer le solde (se rapprocher de 0) et le prêt à placer
            nouveauSolde = soldeActuel - montant;
            nouveauPretAPlacer = pretAPlacerActuel - montant;
            // S'assurer que le prêt à placer ne devienne pas négatif
            if (nouveauPretAPlacer < 0) nouveauPretAPlacer = 0;
            break;

          case app_model.TypeMouvementFinancier.remboursementEffectue:
            // Remboursement effectué : augmenter le solde (se rapprocher de 0)
            nouveauSolde = soldeActuel + montant;
            break;

          default:
            // Autres types de mouvement : pas de modification
            break;
        }

        transaction.update(compteRef, {
          'solde': nouveauSolde,
          'pretAPlacer': nouveauPretAPlacer,
        });
      }
    });
  }

  // Méthode helper pour mettre à jour le solde d'une enveloppe
  Future<void> _mettreAJourSoldeEnveloppe(
    String enveloppeId,
    double montant,
    app_model.TypeTransaction typeTransaction,
  ) async {
    // Trouver la catégorie contenant cette enveloppe
    final categoriesSnapshot = await categoriesRef
        .where('userId', isEqualTo: _auth.currentUser?.uid)
        .get();

    for (var catDoc in categoriesSnapshot.docs) {
      final catData = catDoc.data() as Map<String, dynamic>;
      final enveloppes = List<Map<String, dynamic>>.from(
        catData['enveloppes'] ?? [],
      );

      final enveloppeIndex = enveloppes.indexWhere(
        (env) => env['id'] == enveloppeId,
      );

      if (enveloppeIndex != -1) {
        // Utiliser une transaction pour cette catégorie spécifique
        await firestore.runTransaction((transaction) async {
          final catRef = catDoc.reference;
          final catSnapshot = await transaction.get(catRef);

          if (catSnapshot.exists) {
            final catData = catSnapshot.data() as Map<String, dynamic>;
            final enveloppes = List<Map<String, dynamic>>.from(
              catData['enveloppes'] ?? [],
            );
            final enveloppeIndex = enveloppes.indexWhere(
              (env) => env['id'] == enveloppeId,
            );

            if (enveloppeIndex != -1) {
              final enveloppe = Map<String, dynamic>.from(
                enveloppes[enveloppeIndex],
              );
              final soldeActuel =
                  (enveloppe['solde'] as num?)?.toDouble() ?? 0.0;
              final depenseActuelle =
                  (enveloppe['depense'] as num?)?.toDouble() ?? 0.0;

              // Calculer les nouveaux soldes
              double nouveauSolde;
              double nouvelleDepense = depenseActuelle;

              if (typeTransaction == app_model.TypeTransaction.depense) {
                nouveauSolde = soldeActuel - montant;
                nouvelleDepense = depenseActuelle + montant;
              } else {
                nouveauSolde = soldeActuel + montant;
                // Pour les revenus, on ne change pas le montant dépensé
              }

              // Mettre à jour l'enveloppe
              enveloppe['solde'] = nouveauSolde;
              enveloppe['depense'] = nouvelleDepense;

              // Gestion de l'objectif bihebdomadaire : lorsque la dépense atteint
              // ou dépasse l'objectif, on enregistre la date pour pouvoir
              // réinitialiser plus tard dans le service de rollover.
              try {
                final String? frequence =
                    (enveloppe['frequence_objectif'] as String?)?.toLowerCase();
                final double objectif =
                    (enveloppe['objectif'] as num?)?.toDouble() ?? 0.0;

                if ((frequence == 'bihebdo' || frequence == 'annuel') &&
                    objectif > 0) {
                  // Si l'objectif est atteint, on mémorise la date
                  if (nouvelleDepense >= objectif) {
                    enveloppe['date_dernier_ajout'] =
                        DateTime.now().toIso8601String();
                  }
                }
              } catch (_) {
                // Sécurité : ne pas planter la transaction
              }

              enveloppes[enveloppeIndex] = enveloppe;

              // Sauvegarder la catégorie modifiée
              transaction.update(catRef, {'enveloppes': enveloppes});
            }
          }
        });
        break;
      }
    }
  }

  Future<void> ajouterTiers(String nom) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("Aucun utilisateur n'est connecté.");
    final doc = tiersRef.doc('${user.uid}_$nom');
    final snapshot = await doc.get();
    if (!snapshot.exists) {
      await doc.set({'nom': nom, 'userId': user.uid});
    }
  }

  Future<List<String>> lireTiers() async {
    final user = _auth.currentUser;
    if (user == null) return [];
    final snapshot = await tiersRef.where('userId', isEqualTo: user.uid).get();
    return snapshot.docs.map((doc) => doc['nom'] as String).toList();
  }

  Future<void> supprimerDocument(String collection, String docId) async {
    await FirebaseFirestore.instance.collection(collection).doc(docId).delete();
  }

  Future<void> supprimerCategorie(String categorieId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("Aucun utilisateur n'est connecté.");
    await categoriesRef.doc(categorieId).delete();
  }

  Future<void> archiverEnveloppe(String categorieId, String enveloppeId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("Aucun utilisateur n'est connecté.");

    final categorieDoc = await categoriesRef.doc(categorieId).get();
    if (!categorieDoc.exists) {
      throw Exception("Catégorie non trouvée");
    }

    final categorie = Categorie.fromMap(
      categorieDoc.data() as Map<String, dynamic>,
    );
    final enveloppesMisesAJour = categorie.enveloppes.map((env) {
      if (env.id == enveloppeId) {
        return Enveloppe(
          id: env.id,
          nom: env.nom,
          solde: env.solde,
          objectif: env.objectif,
          objectifDate: env.objectifDate,
          depense: env.depense,
          archivee: true, // On archive l'enveloppe
          provenanceCompteId: env.provenanceCompteId,
          frequenceObjectif: env.frequenceObjectif,
          dateDernierAjout: env.dateDernierAjout,
          objectifJour: env.objectifJour,
          historique: env.historique,
          ordre: env.ordre,
        );
      }
      return env;
    }).toList();

    final categorieMiseAJour = Categorie(
      id: categorie.id,
      userId: categorie.userId,
      nom: categorie.nom,
      enveloppes: enveloppesMisesAJour,
      ordre: categorie.ordre,
    );

    await ajouterCategorie(categorieMiseAJour);
  }

  Future<void> restaurerEnveloppe(
    String categorieId,
    String enveloppeId,
  ) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("Aucun utilisateur n'est connecté.");

    final categorieDoc = await categoriesRef.doc(categorieId).get();
    if (!categorieDoc.exists) {
      throw Exception("Catégorie non trouvée");
    }

    final categorie = Categorie.fromMap(
      categorieDoc.data() as Map<String, dynamic>,
    );
    final enveloppesMisesAJour = categorie.enveloppes.map((env) {
      if (env.id == enveloppeId) {
        return Enveloppe(
          id: env.id,
          nom: env.nom,
          solde: env.solde,
          objectif: env.objectif,
          objectifDate: env.objectifDate,
          depense: env.depense,
          archivee: false, // On restaure l'enveloppe
          provenanceCompteId: env.provenanceCompteId,
          frequenceObjectif: env.frequenceObjectif,
          dateDernierAjout: env.dateDernierAjout,
          objectifJour: env.objectifJour,
          historique: env.historique,
          ordre: env.ordre,
        );
      }
      return env;
    }).toList();

    final categorieMiseAJour = Categorie(
      id: categorie.id,
      userId: categorie.userId,
      nom: categorie.nom,
      enveloppes: enveloppesMisesAJour,
      ordre: categorie.ordre,
    );

    await ajouterCategorie(categorieMiseAJour);
  }

  Future<void> updateCompte(String compteId, Map<String, dynamic> data) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("Aucun utilisateur n'est connecté.");
    await comptesRef.doc(compteId).update(data);
  }

  // Méthode pour annuler l'effet d'une transaction (rollback)
  Future<void> rollbackTransaction(app_model.Transaction transaction) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("Aucun utilisateur n'est connecté.");

    try {
      // 1. Rollback du solde du compte principal
      await _rollbackSoldeCompte(
        transaction.compteId,
        transaction.montant,
        transaction.type,
        transaction.typeMouvement,
      );

      // 2. Rollback du compte de passif associé si présent
      if (transaction.compteDePassifAssocie != null &&
          transaction.compteDePassifAssocie!.isNotEmpty) {
        await _rollbackComptePassifAssocie(
          transaction.compteDePassifAssocie!,
          transaction.montant,
          transaction.typeMouvement,
        );
      }

      // 3. Rollback des soldes des enveloppes
      if (transaction.estFractionnee == true && transaction.sousItems != null) {
        // Transaction fractionnée - rollback de plusieurs enveloppes
        for (var sousItem in transaction.sousItems!) {
          final enveloppeId = sousItem['enveloppeId'] as String?;
          final montantSousItem =
              (sousItem['montant'] as num?)?.toDouble() ?? 0.0;

          if (enveloppeId != null && montantSousItem > 0) {
            await _rollbackSoldeEnveloppe(
              enveloppeId,
              montantSousItem,
              transaction.type,
            );
          }
        }
      } else if (transaction.enveloppeId != null &&
          transaction.enveloppeId!.isNotEmpty) {
        // Transaction normale - rollback d'une seule enveloppe
        await _rollbackSoldeEnveloppe(
          transaction.enveloppeId!,
          transaction.montant,
          transaction.type,
        );
      }

      // 4. Rollback des dettes/prêts si applicable
      await _rollbackDette(transaction);
    } catch (e) {
      rethrow;
    }
  }

  // Méthode helper pour rollback du solde d'un compte
  Future<void> _rollbackSoldeCompte(
    String compteId,
    double montant,
    app_model.TypeTransaction typeTransaction,
    app_model.TypeMouvementFinancier typeMouvement,
  ) async {
    final compteRef = comptesRef.doc(compteId);

    await firestore.runTransaction((transaction) async {
      final compteSnapshot = await transaction.get(compteRef);

      if (compteSnapshot.exists) {
        final compteData = compteSnapshot.data() as Map<String, dynamic>;
        final soldeActuel = (compteData['solde'] as num?)?.toDouble() ?? 0.0;
        final pretAPlacerActuel =
            (compteData['pretAPlacer'] as num?)?.toDouble() ?? 0.0;

        double nouveauSolde;
        double nouveauPretAPlacer = pretAPlacerActuel;

        // Calculer le nouveau solde (inverse de l'effet original)
        if (typeTransaction == app_model.TypeTransaction.depense) {
          nouveauSolde = soldeActuel + montant; // Annuler la dépense
        } else {
          nouveauSolde = soldeActuel - montant; // Annuler le revenu
        }

        // Gérer les prêts à placer selon le type de mouvement (inverse de l'effet original)
        switch (typeMouvement) {
          case app_model.TypeMouvementFinancier.remboursementRecu:
            // Remboursement reçu : diminuer le prêt à placer (inverse de l'effet original)
            nouveauPretAPlacer = pretAPlacerActuel - montant;
            break;

          case app_model.TypeMouvementFinancier.pretAccorde:
            // Prêt accordé : augmenter le prêt à placer (inverse de l'effet original)
            nouveauPretAPlacer = pretAPlacerActuel + montant;
            break;

          case app_model.TypeMouvementFinancier.detteContractee:
            // Dette contractée : diminuer le prêt à placer (inverse de l'effet original)
            nouveauPretAPlacer = pretAPlacerActuel - montant;
            break;

          case app_model.TypeMouvementFinancier.remboursementEffectue:
            // Remboursement effectué : augmenter le prêt à placer (inverse de l'effet original)
            nouveauPretAPlacer = pretAPlacerActuel + montant;
            break;

          default:
            // Pour les autres types de mouvement, pas de changement du prêt à placer
            break;
        }

        // S'assurer que le prêt à placer ne devienne pas négatif
        if (nouveauPretAPlacer < 0) nouveauPretAPlacer = 0;

        transaction.update(compteRef, {
          'solde': nouveauSolde,
          'pretAPlacer': nouveauPretAPlacer,
        });
      }
    });
  }

  // Méthode helper pour rollback du compte de passif associé
  Future<void> _rollbackComptePassifAssocie(
    String comptePassifId,
    double montant,
    app_model.TypeMouvementFinancier typeMouvement,
  ) async {
    final compteRef = comptesRef.doc(comptePassifId);

    await firestore.runTransaction((transaction) async {
      final compteSnapshot = await transaction.get(compteRef);

      if (compteSnapshot.exists) {
        final compteData = compteSnapshot.data() as Map<String, dynamic>;
        final soldeActuel = (compteData['solde'] as num?)?.toDouble() ?? 0.0;
        final pretAPlacerActuel =
            (compteData['pretAPlacer'] as num?)?.toDouble() ?? 0.0;

        double nouveauSolde = soldeActuel;
        double nouveauPretAPlacer = pretAPlacerActuel;

        // Inverse de l'effet original
        switch (typeMouvement) {
          case app_model.TypeMouvementFinancier.detteContractee:
            // Dette contractée : augmenter le solde (inverse de l'effet original)
            nouveauSolde = soldeActuel + montant;
            break;

          case app_model.TypeMouvementFinancier.pretAccorde:
            // Prêt accordé : diminuer le solde et le prêt à placer (inverse de l'effet original)
            nouveauSolde = soldeActuel - montant;
            nouveauPretAPlacer = pretAPlacerActuel - montant;
            break;

          case app_model.TypeMouvementFinancier.remboursementRecu:
            // Remboursement reçu : augmenter le solde et le prêt à placer (inverse de l'effet original)
            nouveauSolde = soldeActuel + montant;
            nouveauPretAPlacer = pretAPlacerActuel + montant;
            break;

          case app_model.TypeMouvementFinancier.remboursementEffectue:
            // Remboursement effectué : diminuer le solde (inverse de l'effet original)
            nouveauSolde = soldeActuel - montant;
            break;

          default:
            // Autres types de mouvement : pas de modification
            break;
        }

        // S'assurer que le prêt à placer ne devienne pas négatif
        if (nouveauPretAPlacer < 0) nouveauPretAPlacer = 0;

        transaction.update(compteRef, {
          'solde': nouveauSolde,
          'pretAPlacer': nouveauPretAPlacer,
        });
      }
    });
  }

  // Méthode helper pour rollback du solde d'une enveloppe
  Future<void> _rollbackSoldeEnveloppe(
    String enveloppeId,
    double montant,
    app_model.TypeTransaction typeTransaction,
  ) async {
    // Trouver la catégorie contenant cette enveloppe
    final categoriesSnapshot = await categoriesRef
        .where('userId', isEqualTo: _auth.currentUser?.uid)
        .get();

    for (var catDoc in categoriesSnapshot.docs) {
      final catData = catDoc.data() as Map<String, dynamic>;
      final enveloppes = List<Map<String, dynamic>>.from(
        catData['enveloppes'] ?? [],
      );

      final enveloppeIndex = enveloppes.indexWhere(
        (env) => env['id'] == enveloppeId,
      );

      if (enveloppeIndex != -1) {
        // Utiliser une transaction pour cette catégorie spécifique
        await firestore.runTransaction((transaction) async {
          final catRef = catDoc.reference;
          final catSnapshot = await transaction.get(catRef);

          if (catSnapshot.exists) {
            final catData = catSnapshot.data() as Map<String, dynamic>;
            final enveloppes = List<Map<String, dynamic>>.from(
              catData['enveloppes'] ?? [],
            );
            final enveloppeIndex = enveloppes.indexWhere(
              (env) => env['id'] == enveloppeId,
            );

            if (enveloppeIndex != -1) {
              final enveloppe = Map<String, dynamic>.from(
                enveloppes[enveloppeIndex],
              );
              final soldeActuel =
                  (enveloppe['solde'] as num?)?.toDouble() ?? 0.0;
              final depenseActuelle =
                  (enveloppe['depense'] as num?)?.toDouble() ?? 0.0;

              // Calculer les nouveaux soldes (inverse de l'effet original)
              double nouveauSolde;
              double nouvelleDepense = depenseActuelle;

              if (typeTransaction == app_model.TypeTransaction.depense) {
                nouveauSolde = soldeActuel + montant; // Annuler la dépense
                nouvelleDepense =
                    depenseActuelle - montant; // Annuler la dépense
              } else {
                nouveauSolde = soldeActuel - montant; // Annuler le revenu
                // Pour les revenus, on ne change pas le montant dépensé
              }

              // S'assurer que la dépense ne devienne pas négative
              if (nouvelleDepense < 0) nouvelleDepense = 0;

              // Mettre à jour l'enveloppe
              enveloppe['solde'] = nouveauSolde;
              enveloppe['depense'] = nouvelleDepense;

              // Gestion de l'objectif bihebdomadaire : lorsque la dépense atteint
              // ou dépasse l'objectif, on enregistre la date pour pouvoir
              // réinitialiser plus tard dans le service de rollover.
              try {
                final String? frequence =
                    (enveloppe['frequence_objectif'] as String?)?.toLowerCase();
                final double objectif =
                    (enveloppe['objectif'] as num?)?.toDouble() ?? 0.0;

                if ((frequence == 'bihebdo' || frequence == 'annuel') &&
                    objectif > 0) {
                  // Si l'objectif est atteint, on mémorise la date
                  if (nouvelleDepense >= objectif) {
                    enveloppe['date_dernier_ajout'] =
                        DateTime.now().toIso8601String();
                  }
                }
              } catch (_) {
                // Sécurité : ne pas planter la transaction
              }

              enveloppes[enveloppeIndex] = enveloppe;

              // Sauvegarder la catégorie modifiée
              transaction.update(catRef, {'enveloppes': enveloppes});
            }
          }
        });
        break;
      }
    }
  }

  // Méthode helper pour rollback des dettes/prêts
  Future<void> _rollbackDette(app_model.Transaction transaction) async {
    // Cette méthode sera implémentée plus tard si nécessaire
    // Pour l'instant, on se concentre sur les soldes de comptes et enveloppes
    // Rollback silencieux
  }

  Stream<List<app_model.Transaction>> lireTransactions(String compteId) {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    // Logger la requête
    FirebaseMonitorService.logQuery(
      collection: 'transactions',
      document: 'compte_$compteId',
      count: 1,
      userId: user.uid,
      details: 'Lecture transactions compte: $compteId',
    );

    // Requête optimisée avec index composite : userId + compteId + date
    return firestore
        .collection('transactions')
        .where('userId', isEqualTo: user.uid)
        .where('compteId', isEqualTo: compteId)
        .orderBy('date', descending: true)
        .limit(100) // Limiter à 100 transactions par compte
        .snapshots()
        .map(
      (snapshot) {
        // Logger le nombre de documents lus
        FirebaseMonitorService.logRead(
          collection: 'transactions',
          document: 'compte_$compteId',
          count: snapshot.docs.length,
          userId: user.uid,
          details:
              '${snapshot.docs.length} transactions lues pour compte $compteId',
        );

        return snapshot.docs
            .map((doc) => app_model.Transaction.fromJson(doc.data()))
            .toList();
      },
    );
  }

  Stream<List<Compte>> lireComptes() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value([]); // Retourne un stream vide si pas d'utilisateur
    }

    // Logger la requête
    FirebaseMonitorService.logQuery(
      collection: 'comptes',
      document: 'user_${user.uid}',
      count: 1,
      userId: user.uid,
      details: 'Lecture des comptes utilisateur',
    );

    return comptesRef
        .where(
          'userId',
          isEqualTo: user.uid,
        ) // Ne lit que les comptes de l'utilisateur
        .snapshots()
        .map(
      (snapshot) {
        // Logger le nombre de documents lus
        FirebaseMonitorService.logRead(
          collection: 'comptes',
          document: 'user_${user.uid}',
          count: snapshot.docs.length,
          userId: user.uid,
          details: '${snapshot.docs.length} comptes lus',
        );

        return snapshot.docs
            .map(
              (doc) =>
                  Compte.fromMap(doc.data() as Map<String, dynamic>, doc.id),
            )
            .toList();
      },
    );
  }

  Future<void> setCarteCredit(
      String compteId, Map<String, dynamic> data) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("Aucun utilisateur n'est connecté.");
    await comptesRef.doc(compteId).set(data, SetOptions(merge: true));
  }
}
