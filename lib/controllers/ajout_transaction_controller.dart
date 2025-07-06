import 'package:flutter/material.dart';
import '../models/transaction_model.dart' as app_model;
import '../models/compte.dart';
import '../models/fractionnement_model.dart';
import '../models/dette.dart';
import '../services/firebase_service.dart';
import '../services/dette_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AjoutTransactionController extends ChangeNotifier {
  // Variables d'état
  app_model.TypeTransaction _typeSelectionne =
      app_model.TypeTransaction.depense;
  app_model.TypeMouvementFinancier _typeMouvementSelectionne =
      app_model.TypeMouvementFinancier.depenseNormale;
  final TextEditingController montantController = TextEditingController(
    text: '0.00',
  );
  final TextEditingController payeController = TextEditingController();
  final TextEditingController noteController = TextEditingController();

  String? _enveloppeSelectionnee;
  String? _compteSelectionne;
  DateTime _dateSelectionnee = DateTime.now();
  String? _marqueurSelectionne;

  // Sélection dans ChampRemboursement
  String?
      _remboursementId; // id Firestore de la carte ou de la dette sélectionnée
  String? _remboursementType; // 'compte' ou 'dette'

  List<Compte> _listeComptesAffichables = [];
  List<Compte> _comptesFirebase = [];
  List<String> _listeTiersConnus = [];
  List<Map<String, dynamic>> _categoriesFirebase = [];

  bool _estFractionnee = false;
  TransactionFractionnee? _transactionFractionnee;

  // Variable pour le mode modification
  app_model.Transaction? _transactionExistante;

  // Getters
  app_model.TypeTransaction get typeSelectionne => _typeSelectionne;
  app_model.TypeMouvementFinancier get typeMouvementSelectionne =>
      _typeMouvementSelectionne;
  String? get enveloppeSelectionnee => _enveloppeSelectionnee;
  String? get compteSelectionne => _compteSelectionne;
  DateTime get dateSelectionnee => _dateSelectionnee;
  String? get marqueurSelectionne => _marqueurSelectionne;
  List<Compte> get listeComptesAffichables => _listeComptesAffichables;
  List<String> get listeTiersConnus => _listeTiersConnus;
  List<Map<String, dynamic>> get categoriesFirebase => _categoriesFirebase;
  bool get estFractionnee => _estFractionnee;
  TransactionFractionnee? get transactionFractionnee => _transactionFractionnee;
  app_model.Transaction? get transactionExistante => _transactionExistante;

  // Validation
  bool get estValide {
    // Améliorer le parsing du montant pour accepter différents formats
    String montantTexte = montantController.text.trim();
    if (montantTexte.isEmpty ||
        montantTexte == '0.00' ||
        montantTexte == '0.00 \$') {
      montantTexte = '0';
    }

    // Nettoyer le symbole $ et les espaces
    montantTexte = montantTexte.replaceAll('\$', '').replaceAll(' ', '');

    // Remplacer les virgules par des points et nettoyer le texte
    montantTexte = montantTexte.replaceAll(',', '.');

    // Si c'est un nombre entier, ajouter .00
    if (montantTexte.contains('.') == false && montantTexte != '0') {
      montantTexte += '.00';
    }

    final montant = double.tryParse(montantTexte) ?? 0.0;

    final tiersTexte = payeController.text.trim();

    if (montant <= 0 || tiersTexte.isEmpty || _compteSelectionne == null) {
      return false;
    }

    // Validation spécifique pour les transactions fractionnées
    if (_estFractionnee && _transactionFractionnee != null) {
      if (!_transactionFractionnee!.estValide) {
        return false;
      }
    }

    // Validation pour les transactions normales
    if (!_estFractionnee &&
        _typeMouvementSelectionne ==
            app_model.TypeMouvementFinancier.depenseNormale &&
        (_enveloppeSelectionnee == null || _enveloppeSelectionnee!.isEmpty)) {
      return false;
    }

    return true;
  }

  // Setter appelé par ChampRemboursement
  void setRemboursementSelection(String? id, String? type) {
    _remboursementId = id;
    _remboursementType = type;
  }

  // Méthodes de mise à jour
  void setTypeTransaction(app_model.TypeTransaction type) {
    _typeSelectionne = type;
    if (type == app_model.TypeTransaction.depense &&
        !_typeMouvementSelectionne.estDepense) {
      _typeMouvementSelectionne =
          app_model.TypeMouvementFinancier.depenseNormale;
    } else if (type == app_model.TypeTransaction.revenu &&
        !_typeMouvementSelectionne.estRevenu) {
      _typeMouvementSelectionne = app_model.TypeMouvementFinancier.revenuNormal;
    }
    notifyListeners();
  }

  void setTypeMouvement(app_model.TypeMouvementFinancier type) {
    _typeMouvementSelectionne = type;
    if (type.estDepense) {
      _typeSelectionne = app_model.TypeTransaction.depense;
    } else if (type.estRevenu) {
      _typeSelectionne = app_model.TypeTransaction.revenu;
    }
    notifyListeners();
  }

  void setCompteSelectionne(String? compteId) {
    _compteSelectionne = compteId;
    notifyListeners();
  }

  void setEnveloppeSelectionnee(String? enveloppeId) {
    _enveloppeSelectionnee = enveloppeId;
    notifyListeners();
  }

  void setDateSelectionnee(DateTime date) {
    _dateSelectionnee = date;
    notifyListeners();
  }

  void setMarqueurSelectionne(String? marqueur) {
    _marqueurSelectionne = marqueur;
    notifyListeners();
  }

  void setFractionnement(TransactionFractionnee? fractionnement) {
    _estFractionnee = fractionnement != null;
    _transactionFractionnee = fractionnement;
    notifyListeners();
  }

  // Méthode pour définir la transaction existante en mode modification
  void setTransactionExistante(app_model.Transaction? transaction) {
    _transactionExistante = transaction;
  }

  // Chargement des données
  Future<void> chargerDonnees() async {
    await Future.wait([
      _chargerComptesFirebase(),
      _chargerTiersConnus(),
      _chargerCategoriesFirebase(),
    ]);
  }

  Future<void> _chargerComptesFirebase() async {
    final service = FirebaseService();
    final comptes = await service.lireComptes().first;
    _comptesFirebase = comptes;
    _mettreAJourListeComptesAffichables();
    notifyListeners();
  }

  Future<void> _chargerTiersConnus() async {
    final service = FirebaseService();
    final liste = await service.lireTiers();
    _listeTiersConnus = liste
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    notifyListeners();
  }

  Future<void> _chargerCategoriesFirebase() async {
    final service = FirebaseService();
    final categories = await service.lireCategories().first;
    _categoriesFirebase = categories
        .map(
          (cat) => {
            'id': cat.id,
            'nom': cat.nom,
            'enveloppes': cat.enveloppes.map((env) => env.toMap()).toList(),
          },
        )
        .toList();
    notifyListeners();
  }

  void _mettreAJourListeComptesAffichables() {
    _listeComptesAffichables = _comptesFirebase
        .where((c) => !c.estArchive)
        .where((c) => c.type == 'Chèque' || c.type == 'Carte de crédit')
        .toList()
      ..sort((a, b) {
        // Placer les comptes Chèque en premier
        if (a.type == 'Chèque' && b.type != 'Chèque') return -1;
        if (a.type != 'Chèque' && b.type == 'Chèque') return 1;
        // Sinon trier par champ ordre (nulls à la fin)
        return (a.ordre ?? 999999).compareTo(b.ordre ?? 999999);
      });
  }

  // Fonction utilitaire pour normaliser les chaînes de caractères
  String normaliserChaine(String chaine) {
    return chaine
        .toLowerCase()
        .trim()
        .replaceAll(
          RegExp(r'\s+'),
          ' ',
        ) // Remplacer les espaces multiples par un seul
        .replaceAll('à', 'a')
        .replaceAll('â', 'a')
        .replaceAll('ä', 'a')
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('ë', 'e')
        .replaceAll('ï', 'i')
        .replaceAll('î', 'i')
        .replaceAll('ô', 'o')
        .replaceAll('ö', 'o')
        .replaceAll('ù', 'u')
        .replaceAll('û', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ÿ', 'y')
        .replaceAll('ç', 'c');
  }

  // Ajout de nouveaux tiers
  Future<void> ajouterNouveauTiers(String nomTiers) async {
    final nomNormalise = normaliserChaine(nomTiers);
    if (!_listeTiersConnus.any((t) => normaliserChaine(t) == nomNormalise)) {
      _listeTiersConnus.add(nomTiers);
      _listeTiersConnus.sort(
        (a, b) => normaliserChaine(a).compareTo(normaliserChaine(b)),
      );
      await FirebaseService().ajouterTiers(nomTiers);
      notifyListeners();
    }
  }

  // Sauvegarde de la transaction
  Future<Map<String, dynamic>?> sauvegarderTransaction() async {
    if (!estValide) return null;

    try {
      // Nettoyer le montant du symbole $ et des espaces
      String montantTexte = montantController.text.trim();
      montantTexte = montantTexte.replaceAll('\$', '').replaceAll(' ', '');
      final montant = double.tryParse(montantTexte.replaceAll(',', '.')) ?? 0.0;

      final tiersTexte = payeController.text.trim();

      // Si l'utilisateur a sélectionné dans la liste mais que onChanged n'a pas déclenché (valeur identique)
      if (_remboursementId == null && tiersTexte.isNotEmpty) {
        // Déduire l'ID d'une carte de crédit portant ce nom
        for (final c in _comptesFirebase) {
          if (c.type == 'Carte de crédit' &&
              c.nom.toLowerCase() == tiersTexte.toLowerCase()) {
            _remboursementId = c.id;
            _remboursementType = 'compte';
            print('[SauvegardeTx] Id compte déduit: $_remboursementId');
            break;
          }
        }
      }

      final compte = _comptesFirebase.firstWhere(
        (c) => c.id == _compteSelectionne,
      );

      final firebaseService = FirebaseService();
      final detteService = DetteService();
      final transactionId = _transactionExistante?.id ??
          DateTime.now().millisecondsSinceEpoch.toString();

      Map<String, dynamic>? infoFinalisation;

      // GESTION DU MODE MODIFICATION - Rollback de l'ancienne transaction
      if (_transactionExistante != null) {
        try {
          // 1. Rollback de l'effet de l'ancienne transaction sur les soldes
          await firebaseService.rollbackTransaction(_transactionExistante!);

          // ANNULER L'EFFET DU REMBOURSEMENT SUR LA DETTE
          if (_transactionExistante!.typeMouvement ==
                  app_model.TypeMouvementFinancier.remboursementEffectue ||
              _transactionExistante!.typeMouvement ==
                  app_model.TypeMouvementFinancier.remboursementRecu) {
            await _rollbackRemboursementViaDettesService(
              _transactionExistante!,
              detteService,
            );
          }
          // Ne plus supprimer l'ancienne transaction ici !
        } catch (e) {
          rethrow;
        }
      }

      // Gérer les dettes/prêts
      if (_typeMouvementSelectionne ==
              app_model.TypeMouvementFinancier.detteContractee ||
          _typeMouvementSelectionne ==
              app_model.TypeMouvementFinancier.pretAccorde) {
        await _creerDetteViaDettesService(
          tiersTexte,
          montant,
          _typeMouvementSelectionne,
          detteService,
        );
      }

      // Gérer les remboursements
      if (_typeMouvementSelectionne ==
          app_model.TypeMouvementFinancier.remboursementEffectue) {
        // Le remboursement effectué peut être une dette ou un paiement de carte de crédit.
        if (_compteSelectionne == null) {
          return {
            'erreur':
                'Veuillez sélectionner un compte source pour le remboursement.'
          };
        }
        if (_remboursementType == 'compte') {
          // C'est un paiement de carte de crédit.
          await _traiterRemboursementCarteCredit(
            tiersTexte, // Le nom de la carte
            montant,
            transactionId,
            firebaseService,
            detteService,
            compteId: _remboursementId, // L'ID de la carte
          );
        } else {
          // C'est un remboursement de dette standard.
          infoFinalisation = await _traiterRemboursementViaDettesService(
            tiersTexte,
            montant,
            _typeMouvementSelectionne,
            transactionId,
            detteService,
            estModification: _transactionExistante != null,
          );
        }
      } else if (_typeMouvementSelectionne ==
          app_model.TypeMouvementFinancier.remboursementRecu) {
        // Un remboursement reçu est toujours traité comme une dette.
        infoFinalisation = await _traiterRemboursementViaDettesService(
          tiersTexte,
          montant,
          _typeMouvementSelectionne,
          transactionId,
          detteService,
          estModification: _transactionExistante != null,
        );
      }

      // Gérer les revenus normaux - augmenter automatiquement le prêt à placer et le solde
      if (_typeMouvementSelectionne ==
          app_model.TypeMouvementFinancier.revenuNormal) {
        await _traiterRevenuNormal(compte, montant, firebaseService);
      }

      print('DEBUG: Création de l\'objet transaction');
      // Créer la transaction
      final transaction = app_model.Transaction(
        id: transactionId,
        type: _typeSelectionne,
        typeMouvement: _typeMouvementSelectionne,
        montant: montant,
        tiers: tiersTexte,
        compteId: compte.id,
        date: _dateSelectionnee,
        enveloppeId: _estFractionnee ? null : _enveloppeSelectionnee,
        marqueur: _marqueurSelectionne,
        note: noteController.text.trim().isEmpty
            ? null
            : noteController.text.trim(),
        estFractionnee: _estFractionnee,
        sousItems: _estFractionnee
            ? _transactionFractionnee!.sousItems
                .map((item) => item.toJson())
                .toList()
            : null,
      );

      print('DEBUG: Transaction créée, sauvegarde dans Firebase...');
      if (_transactionExistante != null) {
        print('DEBUG: Mise à jour de transaction existante');
        await firebaseService.mettreAJourTransaction(transaction);
      } else {
        print('DEBUG: Ajout de nouvelle transaction');
        await firebaseService.ajouterTransaction(transaction);
      }
      print('DEBUG: Transaction sauvegardée avec succès');
      _transactionExistante = transaction;

      // Retourner l'information de finalisation si applicable
      return infoFinalisation;
    } catch (e) {
      // Relancer l'exception pour qu'elle soit capturée par la page
      rethrow;
    }
  }

  // Méthodes pour les dettes (complètes)
  Future<void> _creerDetteViaDettesService(
    String nomTiers,
    double montant,
    app_model.TypeMouvementFinancier typeMouvement,
    DetteService detteService,
  ) async {
    try {
      final user = FirebaseService().auth.currentUser;
      if (user == null) return;

      // Déterminer le type de dette selon le mouvement
      String typeDette;
      if (typeMouvement == app_model.TypeMouvementFinancier.detteContractee) {
        typeDette = 'dette'; // Je dois de l'argent
      } else if (typeMouvement ==
          app_model.TypeMouvementFinancier.pretAccorde) {
        typeDette = 'pret'; // On me doit de l'argent
      } else {
        return; // Pour les remboursements, on ne crée pas de nouvelle dette
      }

      // Créer une nouvelle dette (permettre plusieurs dettes pour le même tiers)
      // Le système de remboursement FIFO sera géré lors des remboursements

      // Si aucune dette existante, créer une nouvelle dette
      final String detteId = DateTime.now().millisecondsSinceEpoch.toString();

      // Créer la dette
      final nouvelleDette = Dette(
        id: detteId,
        nomTiers:
            nomTiers.trim().isNotEmpty ? nomTiers.trim() : 'Tiers générique',
        montantInitial: montant,
        solde: montant,
        type: typeDette,
        historique: [
          MouvementDette(
            id: '${detteId}_initial',
            type: typeDette,
            montant: typeDette == 'dette'
                ? montant
                : -montant, // Négatif pour les prêts accordés
            date: DateTime.now(),
            note: 'Création initiale',
          ),
        ],
        archive: false,
        dateCreation: DateTime.now(),
        dateArchivage: null,
        userId: user.uid,
        estManuelle: false,
      );

      print(
          'DEBUG: Création de la dette - ID: $detteId, Type: $typeDette, Montant: $montant');

      await detteService.creerDette(
        nouvelleDette,
        creerCompteAutomatique: false,
      );

      print('DEBUG: Dette créée avec succès');
      // Plus besoin de créer un compte de dette automatique
      // Les dettes sont maintenant affichées directement dans la page comptes
    } catch (e) {
      print('DEBUG: Erreur lors de la création de la dette: $e');
      print('DEBUG: Stack trace: ${StackTrace.current}');
      // Relancer l'erreur pour qu'elle soit visible
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> _traiterRemboursementViaDettesService(
    String nomTiers,
    double montant,
    app_model.TypeMouvementFinancier typeMouvement,
    String transactionId,
    DetteService detteService, {
    bool estModification = false,
  }) async {
    try {
      final user = FirebaseService().auth.currentUser;
      if (user == null) return null;

      // Déterminer le type de remboursement
      String typeRemboursement;
      String typeDetteRecherche;

      if (typeMouvement == app_model.TypeMouvementFinancier.remboursementRecu) {
        typeRemboursement = 'remboursement_recu';
        typeDetteRecherche = 'pret'; // Chercher dans les prêts accordés
      } else {
        typeRemboursement = 'remboursement_effectue';
        typeDetteRecherche = 'dette'; // Chercher dans les dettes contractées
      }

      // Trouver les dettes actives pour ce tiers
      final dettesActives = await detteService.dettesActives().first;

      // Recherche plus flexible : d'abord une correspondance exacte, puis une correspondance partielle
      var dettesATiers = dettesActives
          .where(
            (d) =>
                normaliserChaine(d.nomTiers) == normaliserChaine(nomTiers) &&
                d.type == typeDetteRecherche,
          )
          .toList();

      // Si aucune correspondance exacte, essayer une correspondance partielle
      if (dettesATiers.isEmpty) {
        dettesATiers = dettesActives
            .where(
              (d) =>
                  (normaliserChaine(
                        d.nomTiers,
                      ).contains(normaliserChaine(nomTiers)) ||
                      normaliserChaine(
                        nomTiers,
                      ).contains(normaliserChaine(d.nomTiers))) &&
                  d.type == typeDetteRecherche,
            )
            .toList();
      }

      if (dettesATiers.isEmpty) {
        return null;
      }

      // Trier par date de création (plus ancien en premier)
      dettesATiers.sort((a, b) => a.dateCreation.compareTo(b.dateCreation));

      // Calculer le total du solde restant de toutes les dettes
      double totalSoldeRestant = dettesATiers.fold(
        0.0,
        (sum, dette) => sum + dette.solde,
      );

      // Vérifier si le montant du remboursement ne dépasse pas le solde restant
      // Utiliser une marge d'erreur pour éviter les problèmes de précision des nombres à virgule flottante
      const double epsilon = 0.01; // Marge d'erreur de 1 cent
      if (montant > totalSoldeRestant + epsilon) {
        final message = typeMouvement ==
                app_model.TypeMouvementFinancier.remboursementEffectue
            ? 'Seulement ${totalSoldeRestant.abs().toStringAsFixed(2)} dollars sont nécessaires pour rembourser votre dette à $nomTiers'
            : 'Seulement ${totalSoldeRestant.abs().toStringAsFixed(2)} dollars peuvent être remboursés par $nomTiers';

        throw Exception(message);
      }

      double montantRestant = montant;
      bool detteFinalisee = false;

      // Traitement en cascade pour rembourser les dettes dans l'ordre
      for (final dette in dettesATiers) {
        if (montantRestant <= 0) break;

        final montantAPayer =
            montantRestant >= dette.solde ? dette.solde : montantRestant;

        // Vérifier si cette dette sera finalisée
        if (montantAPayer >= dette.solde) {
          detteFinalisee = true;
        }

        // Créer le mouvement de remboursement
        final mouvement = MouvementDette(
          id: '${transactionId}_${dette.id}',
          date: DateTime.now(),
          montant: -montantAPayer, // Négatif car c'est un remboursement
          type: typeRemboursement,
          note: 'Remboursement via transaction $transactionId',
        );

        // Ajouter le mouvement à la dette
        await detteService.ajouterMouvement(
          dette.id,
          mouvement,
          estModification: estModification,
        );

        montantRestant -= montantAPayer;
      }

      // Retourner l'information sur la finalisation de la dette
      if (detteFinalisee) {
        // On prend la dernière dette finalisée pour récupérer estManuelle
        final detteFinaliseeObj = dettesATiers.lastWhere(
          (d) => d.solde <= 0,
          orElse: () => dettesATiers.last,
        );
        return {
          'finalisee': true,
          'typeMouvement': typeMouvement,
          'nomTiers': nomTiers,
          'estManuelle': detteFinaliseeObj.estManuelle,
        };
      }

      return null;
    } catch (e) {
      rethrow; // Relancer l'exception pour qu'elle soit capturée par la fonction appelante
    }
  }

  // Traiter le remboursement d'une carte de crédit sélectionnée dans le champ "Tiers".
  // 1. Met à jour le solde (ou soldeActuel) de la carte.
  // 2. Si rembourserDettesAssociees == true, répartit le montant sur les dettes
  //    listées dans depensesFixes du document compte.
  Future<void> _traiterRemboursementCarteCredit(
    String nomCarte,
    double montant,
    String transactionId,
    FirebaseService firebaseService,
    DetteService detteService, {
    String? compteId,
  }) async {
    try {
      final user = FirebaseService().auth.currentUser;
      if (user == null) return;

      print(
          '[RemboursementCarteCredit] Début. compteId=$compteId nomCarte=$nomCarte montant=$montant');
      // Rechercher la carte de crédit par id s'il est fourni, sinon par nom
      DocumentSnapshot<Map<String, dynamic>>? compteDoc;
      if (compteId != null) {
        compteDoc = await FirebaseFirestore.instance
            .collection('comptes')
            .doc(compteId)
            .get();
        if (!compteDoc.exists) return;
      } else {
        final snap = await FirebaseFirestore.instance
            .collection('comptes')
            .where('userId', isEqualTo: user.uid)
            .where('type', isEqualTo: 'Carte de crédit')
            .where('nom', isEqualTo: nomCarte)
            .limit(1)
            .get();
        if (snap.docs.isEmpty) return;
        compteDoc = snap.docs.first;
      }

      final doc = compteDoc;
      final data = doc.data();
      if (data == null) {
        print('[RemboursementCarteCredit] Doc sans data. Abandon');
        return;
      } // sécurité null

      // Vérifier que le compte appartient bien à l'utilisateur connecté
      if (data['userId'] != user.uid) {
        print(
            '[RemboursementCarteCredit] Compte appartient à ${data['userId']} ≠ ${user.uid}. Ignoré');
        // Sécurité : on ne touche pas aux comptes d'un autre utilisateur
        return;
      }
      // Mettre à jour le solde / soldeActuel
      final double soldeActuel =
          (data['soldeActuel'] ?? data['solde'] ?? 0).toDouble();
      final double nouveauSolde =
          (soldeActuel - montant).clamp(0, double.infinity);
      await firebaseService.updateCompte(doc.id, {
        'soldeActuel': nouveauSolde,
      });

      // Vérifier si on doit rembourser les dettes associées
      final bool rembourserDettesAssociees =
          data['rembourserDettesAssociees'] ?? false;
      print(
          '[RemboursementCarteCredit] rembourserDettesAssociees: $rembourserDettesAssociees');

      if (rembourserDettesAssociees) {
        final List<dynamic> depensesFixes = data['depensesFixes'] ?? [];
        print(
            '[RemboursementCarteCredit] Nombre de dépenses fixes: ${depensesFixes.length}');

        if (depensesFixes.isNotEmpty) {
          print(
              '[RemboursementCarteCredit] Traitement des frais fixes pour $nomCarte');

          try {
            // Pour chaque frais fixe, rembourser automatiquement la dette correspondante
            for (final depenseFixe in depensesFixes) {
              final String nomDette = depenseFixe['nom'] ?? '';
              final double montantDette =
                  (depenseFixe['montant'] as num?)?.toDouble() ?? 0.0;

              if (nomDette.isNotEmpty && montantDette > 0) {
                print(
                    '[RemboursementCarteCredit] Remboursement automatique: $nomDette - $montantDette\$');

                try {
                  // Rembourser la dette correspondante
                  final List<String> messagesArchivage =
                      await detteService.remboursementEnCascade(
                    nomTiers: nomDette,
                    montantTotal: montantDette,
                    typeRemboursement: 'remboursement_effectue',
                    transactionId: '${transactionId}_auto_${nomDette}',
                  );

                  if (messagesArchivage.isNotEmpty) {
                    print(
                        '[RemboursementCarteCredit] Messages pour $nomDette: ${messagesArchivage.join(', ')}');
                  }
                } catch (e) {
                  print(
                      '[RemboursementCarteCredit] Erreur lors du remboursement de $nomDette: $e');
                }
              }
            }
          } catch (e) {
            print(
                '[RemboursementCarteCredit] Erreur lors du traitement des frais fixes: $e');
          }
        } else {
          print('[RemboursementCarteCredit] Aucune dépense fixe trouvée');
        }
      } else {
        print(
            '[RemboursementCarteCredit] rembourserDettesAssociees est désactivé');
      }
    } catch (e) {
      // Laisser silencieux; ne doit pas interrompre la sauvegarde principale
    }
  }

  Future<void> _traiterRevenuNormal(
    Compte compte,
    double montant,
    FirebaseService firebaseService,
  ) async {
    try {
      final user = FirebaseService().auth.currentUser;
      if (user == null) return;

      // Pour les revenus normaux, seul le prêt à placer doit être augmenté
      // Le solde est déjà mis à jour automatiquement par FirebaseService.ajouterTransaction
      final nouveauPretAPlacer = compte.pretAPlacer + montant;

      // Mettre à jour seulement le prêt à placer
      await firebaseService.updateCompte(compte.id, {
        'pretAPlacer': nouveauPretAPlacer,
      });
    } catch (e) {
      // Erreur silencieuse
    }
  }

  Future<void> _rollbackRemboursementViaDettesService(
    app_model.Transaction transaction,
    DetteService detteService,
  ) async {
    try {
      final user = FirebaseService().auth.currentUser;
      if (user == null) return;

      final nomTiers = transaction.tiers;
      if (nomTiers == null) return;
      final transactionId = transaction.id;
      final typeMouvement = transaction.typeMouvement;

      String typeDetteRecherche;
      if (typeMouvement == app_model.TypeMouvementFinancier.remboursementRecu) {
        typeDetteRecherche = 'pret';
      } else {
        typeDetteRecherche = 'dette';
      }

      final dettesActives = await detteService.dettesActives().first;
      final dettesArchivees = await detteService.dettesArchivees().first;
      final toutesLesDettes = [...dettesActives, ...dettesArchivees];

      var dettesDuTiers = toutesLesDettes
          .where((d) =>
              normaliserChaine(d.nomTiers) == normaliserChaine(nomTiers) &&
              d.type == typeDetteRecherche)
          .toList();

      if (dettesDuTiers.isEmpty) {
        dettesDuTiers = toutesLesDettes
            .where((d) =>
                (normaliserChaine(d.nomTiers)
                        .contains(normaliserChaine(nomTiers)) ||
                    normaliserChaine(nomTiers)
                        .contains(normaliserChaine(d.nomTiers))) &&
                d.type == typeDetteRecherche)
            .toList();
      }

      if (dettesDuTiers.isEmpty) {
        return;
      }

      for (final dette in dettesDuTiers) {
        final mouvementId = '${transactionId}_${dette.id}';
        MouvementDette? mouvementASupprimer;
        for (final m in dette.historique) {
          if (m.id == mouvementId) {
            mouvementASupprimer = m;
            break;
          }
        }

        if (mouvementASupprimer != null) {
          final docRef =
              FirebaseFirestore.instance.collection('dettes').doc(dette.id);

          if (dette.archive) {
            await docRef.update({'archive': false, 'dateArchivage': null});
          }
          await docRef.update({
            'historique': FieldValue.arrayRemove([mouvementASupprimer.toMap()])
          });

          // Déclencher le recalcul du solde
          await detteService.ajouterMouvement(
            dette.id,
            MouvementDette(
              id: 'recalc_${DateTime.now().millisecondsSinceEpoch}',
              type: 'ajustement',
              montant: 0,
              date: DateTime.now(),
              note: 'Recalcul après modification de transaction.',
            ),
          );
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  void dispose() {
    montantController.dispose();
    payeController.dispose();
    noteController.dispose();
    super.dispose();
  }
}
