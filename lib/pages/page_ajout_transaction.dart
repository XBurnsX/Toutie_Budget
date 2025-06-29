import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/ajout_transaction_controller.dart';
import '../models/transaction_model.dart';
import '../models/compte.dart';
import '../models/fractionnement_model.dart';
import '../widgets/ajout_transaction/selecteur_type_transaction.dart';
import '../widgets/ajout_transaction/champ_montant.dart';
import '../widgets/ajout_transaction/section_informations_cles.dart';
import '../widgets/ajout_transaction/section_fractionnement.dart';
import '../widgets/ajout_transaction/bouton_sauvegarder.dart';
import '../widgets/modale_fractionnement.dart';

class EcranAjoutTransactionRefactored extends StatefulWidget {
  final List<String> comptesExistants;
  final Transaction? transactionExistante;
  final bool modeModification;
  final VoidCallback? onTransactionSaved;

  const EcranAjoutTransactionRefactored({
    super.key,
    required this.comptesExistants,
    this.transactionExistante,
    this.modeModification = false,
    this.onTransactionSaved,
  });

  @override
  State<EcranAjoutTransactionRefactored> createState() =>
      _EcranAjoutTransactionRefactoredState();
}

class _EcranAjoutTransactionRefactoredState
    extends State<EcranAjoutTransactionRefactored> {
  late AjoutTransactionController _controller;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _controller = AjoutTransactionController();
    _initialiserController();
    _chargerDonnees();
  }

  void _initialiserController() {
    if (widget.transactionExistante != null) {
      final t = widget.transactionExistante!;
      _controller.setTypeTransaction(t.type);
      _controller.setTypeMouvement(t.typeMouvement);
      _controller.montantController.text = t.montant.toStringAsFixed(2);
      _controller.payeController.text = t.tiers ?? '';
      _controller.setCompteSelectionne(t.compteId);
      _controller.setDateSelectionnee(t.date);
      _controller.setEnveloppeSelectionnee(t.enveloppeId);
      _controller.setMarqueurSelectionne(t.marqueur);
      _controller.noteController.text = t.note ?? '';
    }
  }

  Future<void> _chargerDonnees() async {
    await _controller.chargerDonnees();
  }

  void _ouvrirModaleFractionnement() async {
    final double montant =
        double.tryParse(
          _controller.montantController.text.replaceAll(',', '.'),
        ) ??
        0.0;

    if (montant <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Veuillez d\'abord entrer un montant valide.'),
          ),
        );
      }
      return;
    }

    // Obtenir toutes les enveloppes pour la modale
    final List<Map<String, dynamic>> toutesEnveloppes = [];
    for (var cat in _controller.categoriesFirebase) {
      final List<dynamic> enveloppes = cat['enveloppes'] ?? [];
      for (var env in enveloppes) {
        toutesEnveloppes.add({
          'id': env['id'],
          'nom': env['nom'],
          'categorieNom': cat['nom'],
          'solde': env['solde'] ?? 0.0,
          'provenances': env['provenances'],
          'provenance_compte_id': env['provenance_compte_id'],
          'comptes': _controller.listeComptesAffichables
              .map((c) => {'id': c.id, 'nom': c.nom, 'couleur': c.couleur})
              .toList(),
        });
      }
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.8,
          child: ModaleFractionnement(
            montantTotal: montant,
            enveloppes: toutesEnveloppes,
            onConfirmer: (TransactionFractionnee transactionFractionnee) {
              _controller.setFractionnement(transactionFractionnee);
            },
          ),
        );
      },
    );
  }

  Future<void> _sauvegarderTransaction() async {
    setState(() => _isLoading = true);

    try {
      final success = await _controller.sauvegarderTransaction();

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaction sauvegardée avec succès !'),
          ),
        );
        widget.onTransactionSaved?.call();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de la sauvegarde de la transaction.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: ${e.toString()}')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Color _getCouleurCompteEnveloppe(Map<String, dynamic> enveloppe) {
    // D'abord essayer avec les provenances multi-comptes
    final List<dynamic>? provenances = enveloppe['provenances'];
    if (provenances != null && provenances.isNotEmpty) {
      // Prendre le compte avec le plus gros montant
      var provenance = provenances.reduce(
        (a, b) => (a['montant'] as num) > (b['montant'] as num) ? a : b,
      );
      final compteId = provenance['compte_id'] as String;
      final compte = _controller.listeComptesAffichables.firstWhere(
        (c) => c.id == compteId,
        orElse: () => _controller.listeComptesAffichables.first,
      );
      return Color(compte.couleur);
    }

    // Fallback avec l'ancien système de provenance unique
    final String? provenanceCompteId = enveloppe['provenance_compte_id'];
    if (provenanceCompteId != null && provenanceCompteId.isNotEmpty) {
      final compte = _controller.listeComptesAffichables.firstWhere(
        (c) => c.id == provenanceCompteId,
        orElse: () => _controller.listeComptesAffichables.first,
      );
      return Color(compte.couleur);
    }

    // Couleur par défaut si aucune provenance
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _controller,
      child: Scaffold(
        appBar: AppBar(title: const Text('Ajouter Transaction')),
        body: Consumer<AjoutTransactionController>(
          builder: (context, controller, child) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: <Widget>[
                  // Sélecteur de type de transaction
                  SelecteurTypeTransaction(
                    typeSelectionne: controller.typeSelectionne,
                    typeMouvementSelectionne:
                        controller.typeMouvementSelectionne,
                    onTypeChanged: (type, typeMouvement) {
                      controller.setTypeTransaction(type);
                      controller.setTypeMouvement(typeMouvement);
                    },
                  ),

                  // Champ montant
                  ChampMontant(
                    controller: controller.montantController,
                    estFractionnee: controller.estFractionnee,
                    onFractionnementSupprime: () =>
                        controller.setFractionnement(null),
                    onMontantChange: () {
                      // Déclencher la validation du contrôleur
                      controller.notifyListeners();
                    },
                  ),

                  // Section informations clés
                  SectionInformationsCles(
                    typeMouvementSelectionne:
                        controller.typeMouvementSelectionne,
                    payeController: controller.payeController,
                    listeTiersConnus: controller.listeTiersConnus,
                    onTiersAjoute: controller.ajouterNouveauTiers,
                    compteSelectionne: controller.compteSelectionne,
                    listeComptesAffichables: controller.listeComptesAffichables,
                    onCompteChanged: controller.setCompteSelectionne,
                    enveloppeSelectionnee: controller.enveloppeSelectionnee,
                    categoriesFirebase: controller.categoriesFirebase,
                    comptesFirebase: controller.listeComptesAffichables,
                    typeSelectionne: controller.typeSelectionne,
                    onEnveloppeChanged: controller.setEnveloppeSelectionnee,
                    getCouleurCompteEnveloppe: _getCouleurCompteEnveloppe,
                    dateSelectionnee: controller.dateSelectionnee,
                    onDateChanged: controller.setDateSelectionnee,
                    marqueurSelectionne: controller.marqueurSelectionne,
                    onMarqueurChanged: controller.setMarqueurSelectionne,
                    noteController: controller.noteController,
                    onTypeMouvementChanged: controller.setTypeMouvement,
                  ),

                  const SizedBox(height: 20),

                  // Section fractionnement
                  SectionFractionnement(
                    estFractionnee: controller.estFractionnee,
                    transactionFractionnee: controller.transactionFractionnee,
                    onSupprimerFractionnement: () =>
                        controller.setFractionnement(null),
                    onOuvrirModaleFractionnement: _ouvrirModaleFractionnement,
                  ),

                  const SizedBox(height: 5),

                  // Bouton sauvegarder
                  BoutonSauvegarder(
                    estValide: controller.estValide,
                    onSauvegarder: _sauvegarderTransaction,
                    isLoading: _isLoading,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
