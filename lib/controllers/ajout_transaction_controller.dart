import 'package:flutter/material.dart';
import '../models/transaction_model.dart';
import '../models/compte.dart';
import '../models/fractionnement_model.dart';
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
    final montant =
        double.tryParse(montantController.text.replaceAll(',', '.')) ?? 0.0;
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
        !(_typeMouvementSelectionne == TypeMouvementFinancier.pretAccorde ||
            _typeMouvementSelectionne ==
                TypeMouvementFinancier.remboursementRecu ||
            _typeMouvementSelectionne ==
                TypeMouvementFinancier.detteContractee ||
            _typeMouvementSelectionne ==
                TypeMouvementFinancier.remboursementEffectue) &&
        (_enveloppeSelectionnee == null || _enveloppeSelectionnee!.isEmpty)) {
      return false;
    }

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

  // Ajout de nouveaux tiers
  Future<void> ajouterNouveauTiers(String nomTiers) async {
    if (!_listeTiersConnus.any(
      (t) => t.toLowerCase() == nomTiers.toLowerCase(),
    )) {
      _listeTiersConnus.add(nomTiers);
      _listeTiersConnus.sort(
        (a, b) => a.toLowerCase().compareTo(b.toLowerCase()),
      );
      await FirebaseService().ajouterTiers(nomTiers);
      notifyListeners();
    }
  }

  // Sauvegarde de la transaction
  Future<bool> sauvegarderTransaction() async {
    if (!estValide) return false;

    try {
      final montant =
          double.tryParse(montantController.text.replaceAll(',', '.')) ?? 0.0;
      final tiersTexte = payeController.text.trim();
      final compte = _comptesFirebase.firstWhere(
        (c) => c.id == _compteSelectionne,
      );

      final firebaseService = FirebaseService();
      final detteService = DetteService();
      final transactionId = DateTime.now().millisecondsSinceEpoch.toString();

      // Gérer les dettes/prêts
      if (_typeMouvementSelectionne == TypeMouvementFinancier.detteContractee ||
          _typeMouvementSelectionne == TypeMouvementFinancier.pretAccorde) {
        await _creerDetteViaDettesService(
          tiersTexte,
          montant,
          _typeMouvementSelectionne,
        );
      }

      // Gérer les remboursements
      if (_typeMouvementSelectionne ==
              TypeMouvementFinancier.remboursementRecu ||
          _typeMouvementSelectionne ==
              TypeMouvementFinancier.remboursementEffectue) {
        await _traiterRemboursementViaDettesService(
          tiersTexte,
          montant,
          _typeMouvementSelectionne,
          transactionId,
        );
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
      return true;
    } catch (e) {
      print('Erreur lors de la sauvegarde: $e');
      return false;
    }
  }

  // Méthodes pour les dettes (simplifiées)
  Future<void> _creerDetteViaDettesService(
    String nomTiers,
    double montant,
    TypeMouvementFinancier typeMouvement,
  ) async {
    // Implémentation simplifiée - à compléter selon vos besoins
  }

  Future<void> _traiterRemboursementViaDettesService(
    String nomTiers,
    double montant,
    TypeMouvementFinancier typeMouvement,
    String transactionId,
  ) async {
    // Implémentation simplifiée - à compléter selon vos besoins
  }

  @override
  void dispose() {
    montantController.dispose();
    payeController.dispose();
    noteController.dispose();
    super.dispose();
  }
}
