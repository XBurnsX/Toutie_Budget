import 'package:flutter/material.dart';
import '../models/transaction_model.dart';
import '../models/compte.dart';
import '../models/fractionnement_model.dart';
import '../models/dette.dart';
import '../services/firebase_service.dart';
import '../services/dette_service.dart';

class AjoutTransactionController extends ChangeNotifier {
  // Variables d'état
  TypeTransaction _typeSelectionne = TypeTransaction.depense;
  TypeMouvementFinancier _typeMouvementSelectionne =
      TypeMouvementFinancier.depenseNormale;
  final TextEditingController montantController = TextEditingController(
    text: '0.00',
  );
  final TextEditingController payeController = TextEditingController();
  final TextEditingController noteController = TextEditingController();

  String? _enveloppeSelectionnee;
  String? _compteSelectionne;
  DateTime _dateSelectionnee = DateTime.now();
  String? _marqueurSelectionne;

  List<Compte> _listeComptesAffichables = [];
  List<Compte> _comptesFirebase = [];
  List<String> _listeTiersConnus = [];
  List<Map<String, dynamic>> _categoriesFirebase = [];

  bool _estFractionnee = false;
  TransactionFractionnee? _transactionFractionnee;

  // Getters
  TypeTransaction get typeSelectionne => _typeSelectionne;
  TypeMouvementFinancier get typeMouvementSelectionne =>
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

    print('DEBUG: Validation - montantTexte final: "$montantTexte"');
    final montant = double.tryParse(montantTexte) ?? 0.0;
    print('DEBUG: Validation - montant parsé: $montant');

    final tiersTexte = payeController.text.trim();
    print('DEBUG: Validation - tiersTexte: "$tiersTexte"');
    print('DEBUG: Validation - _compteSelectionne: $_compteSelectionne');

    if (montant <= 0 || tiersTexte.isEmpty || _compteSelectionne == null) {
      print(
        'DEBUG: Validation - ÉCHEC: montant=$montant, tiersTexte="$tiersTexte", compte=$_compteSelectionne',
      );
      return false;
    }

    // Validation spécifique pour les transactions fractionnées
    if (_estFractionnee && _transactionFractionnee != null) {
      if (!_transactionFractionnee!.estValide) {
        print('DEBUG: Validation - ÉCHEC: fractionnement invalide');
        return false;
      }
    }

    // Validation pour les transactions normales
    if (!_estFractionnee &&
        _typeMouvementSelectionne == TypeMouvementFinancier.depenseNormale &&
        (_enveloppeSelectionnee == null || _enveloppeSelectionnee!.isEmpty)) {
      print('DEBUG: Validation - ÉCHEC: enveloppe manquante pour dépense');
      return false;
    }

    print('DEBUG: Validation - SUCCÈS');
    return true;
  }

  // Méthodes de mise à jour
  void setTypeTransaction(TypeTransaction type) {
    _typeSelectionne = type;
    if (type == TypeTransaction.depense &&
        !_typeMouvementSelectionne.estDepense) {
      _typeMouvementSelectionne = TypeMouvementFinancier.depenseNormale;
    } else if (type == TypeTransaction.revenu &&
        !_typeMouvementSelectionne.estRevenu) {
      _typeMouvementSelectionne = TypeMouvementFinancier.revenuNormal;
    }
    notifyListeners();
  }

  void setTypeMouvement(TypeMouvementFinancier type) {
    _typeMouvementSelectionne = type;
    if (type.estDepense) {
      _typeSelectionne = TypeTransaction.depense;
    } else if (type.estRevenu) {
      _typeSelectionne = TypeTransaction.revenu;
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
        .where((c) => c.type == 'Chèque' || c.type == 'Carte de crédit')
        .toList();
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
      print('DEBUG: Validation - tiersTexte: "$tiersTexte"');
      print('DEBUG: Validation - _compteSelectionne: $_compteSelectionne');

      final compte = _comptesFirebase.firstWhere(
        (c) => c.id == _compteSelectionne,
      );

      final firebaseService = FirebaseService();
      final detteService = DetteService();
      final transactionId = DateTime.now().millisecondsSinceEpoch.toString();

      Map<String, dynamic>? infoFinalisation;

      // Gérer les dettes/prêts
      if (_typeMouvementSelectionne == TypeMouvementFinancier.detteContractee ||
          _typeMouvementSelectionne == TypeMouvementFinancier.pretAccorde) {
        await _creerDetteViaDettesService(
          tiersTexte,
          montant,
          _typeMouvementSelectionne,
          detteService,
        );
      }

      // Gérer les remboursements
      if (_typeMouvementSelectionne ==
              TypeMouvementFinancier.remboursementRecu ||
          _typeMouvementSelectionne ==
              TypeMouvementFinancier.remboursementEffectue) {
        infoFinalisation = await _traiterRemboursementViaDettesService(
          tiersTexte,
          montant,
          _typeMouvementSelectionne,
          transactionId,
          detteService,
        );
      }

      // Gérer les revenus normaux - augmenter automatiquement le prêt à placer et le solde
      if (_typeMouvementSelectionne == TypeMouvementFinancier.revenuNormal) {
        await _traiterRevenuNormal(compte, montant, firebaseService);
      }

      // Créer la transaction
      final transaction = Transaction(
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

      await firebaseService.ajouterTransaction(transaction);

      // Retourner l'information de finalisation si applicable
      return infoFinalisation;
    } catch (e) {
      print('Erreur lors de la sauvegarde: $e');
      // Relancer l'exception pour qu'elle soit capturée par la page
      rethrow;
    }
  }

  // Méthodes pour les dettes (complètes)
  Future<void> _creerDetteViaDettesService(
    String nomTiers,
    double montant,
    TypeMouvementFinancier typeMouvement,
    DetteService detteService,
  ) async {
    try {
      final user = FirebaseService().auth.currentUser;
      if (user == null) return;

      print(
        'DEBUG: Création de dette - nomTiers: $nomTiers, montant: $montant, typeMouvement: $typeMouvement',
      );

      // Déterminer le type de dette selon le mouvement
      String typeDette;
      if (typeMouvement == TypeMouvementFinancier.detteContractee) {
        typeDette = 'dette'; // Je dois de l'argent
      } else if (typeMouvement == TypeMouvementFinancier.pretAccorde) {
        typeDette = 'pret'; // On me doit de l'argent
      } else {
        return; // Pour les remboursements, on ne crée pas de nouvelle dette
      }

      // Vérifier s'il existe déjà une dette active pour ce tiers
      final dettesActives = await detteService.dettesActives().first;
      final dettesExistantes = dettesActives
          .where(
            (d) =>
                normaliserChaine(d.nomTiers) == normaliserChaine(nomTiers) &&
                d.type == typeDette,
          )
          .toList();

      // Si une dette existe déjà, ajouter le montant à cette dette
      if (dettesExistantes.isNotEmpty) {
        final detteExistante =
            dettesExistantes.first; // Prendre la première trouvée

        print('DEBUG: Dette existante trouvée: ${detteExistante.id}');

        // Créer un mouvement pour ajouter le montant à la dette existante
        final mouvement = MouvementDette(
          id: '${DateTime.now().millisecondsSinceEpoch}_ajout',
          type: typeDette,
          montant: typeDette == 'dette' ? montant : -montant,
          date: DateTime.now(),
          note: 'Ajout via transaction',
        );

        // Ajouter le mouvement à la dette existante
        await detteService.ajouterMouvement(detteExistante.id, mouvement);
        print(
          'DEBUG: Montant ajouté à la dette existante: ${detteExistante.id}',
        );
        return;
      }

      // Si aucune dette existante, créer une nouvelle dette
      final String detteId = DateTime.now().millisecondsSinceEpoch.toString();

      print('DEBUG: Type de dette déterminé: $typeDette, ID: $detteId');

      // Créer la dette
      final nouvelleDette = Dette(
        id: detteId,
        nomTiers: nomTiers.trim().isNotEmpty
            ? nomTiers.trim()
            : 'Tiers générique',
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
      );

      print(
        'DEBUG: Appel de detteService.creerDette pour la dette: ${nouvelleDette.id}',
      );
      await detteService.creerDette(
        nouvelleDette,
        creerCompteAutomatique: false,
      );
      print('DEBUG: Dette créée avec succès: ${nouvelleDette.id}');

      // Plus besoin de créer un compte de dette automatique
      // Les dettes sont maintenant affichées directement dans la page comptes
    } catch (e) {
      print('Erreur lors de la création de la dette: $e');
    }
  }

  Future<Map<String, dynamic>?> _traiterRemboursementViaDettesService(
    String nomTiers,
    double montant,
    TypeMouvementFinancier typeMouvement,
    String transactionId,
    DetteService detteService,
  ) async {
    try {
      final user = FirebaseService().auth.currentUser;
      if (user == null) return null;

      // Déterminer le type de remboursement
      String typeRemboursement;
      String typeDetteRecherche;

      if (typeMouvement == TypeMouvementFinancier.remboursementRecu) {
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
        print(
          'Aucune dette trouvée pour "$nomTiers" de type "$typeDetteRecherche"',
        );
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
      if (montant > totalSoldeRestant) {
        final message =
            typeMouvement == TypeMouvementFinancier.remboursementEffectue
            ? 'Seulement ${totalSoldeRestant.abs().toStringAsFixed(2)} dollars sont nécessaires pour rembourser votre dette à $nomTiers'
            : 'Seulement ${totalSoldeRestant.abs().toStringAsFixed(2)} dollars peuvent être remboursés par $nomTiers';

        throw Exception(message);
      }

      double montantRestant = montant;
      bool detteFinalisee = false;

      // Traitement en cascade pour rembourser les dettes dans l'ordre
      for (final dette in dettesATiers) {
        if (montantRestant <= 0) break;

        final montantAPayer = montantRestant >= dette.solde
            ? dette.solde
            : montantRestant;

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
        await detteService.ajouterMouvement(dette.id, mouvement);

        montantRestant -= montantAPayer;
      }

      // Retourner l'information sur la finalisation de la dette
      if (detteFinalisee) {
        return {
          'finalisee': true,
          'typeMouvement': typeMouvement,
          'nomTiers': nomTiers,
        };
      }

      return null;
    } catch (e) {
      print('Erreur lors du traitement du remboursement: $e');
      rethrow; // Relancer l'exception pour qu'elle soit capturée par la fonction appelante
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
      print('Erreur lors du traitement du revenu normal: $e');
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
