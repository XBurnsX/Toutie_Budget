import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/ajout_transaction_controller.dart';
import '../models/transaction_model.dart';
import '../models/fractionnement_model.dart';
import '../services/color_service.dart';
import '../widgets/ajout_transaction/selecteur_type_transaction.dart';
import '../widgets/ajout_transaction/champ_montant.dart';
import '../widgets/ajout_transaction/section_informations_cles.dart';
import '../widgets/ajout_transaction/section_fractionnement.dart';
import '../widgets/ajout_transaction/bouton_sauvegarder.dart';
import '../widgets/modale_fractionnement.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class EcranAjoutTransactionRefactored extends StatefulWidget {
  final List<String> comptesExistants;
  final Transaction? transactionExistante;
  final bool modeModification;
  final VoidCallback? onTransactionSaved;
  final String? nomTiers;
  final String? typeRemboursement;
  final double? montantSuggere;

  const EcranAjoutTransactionRefactored({
    super.key,
    required this.comptesExistants,
    this.transactionExistante,
    this.modeModification = false,
    this.onTransactionSaved,
    this.nomTiers,
    this.typeRemboursement,
    this.montantSuggere,
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
    // Pré-remplissage si arguments fournis
    if (widget.nomTiers != null && widget.nomTiers!.isNotEmpty) {
      _controller.payeController.text = widget.nomTiers!;
    }
    if (widget.montantSuggere != null) {
      _controller.montantController.text =
          widget.montantSuggere!.toStringAsFixed(2);
    }
    if (widget.typeRemboursement != null) {
      // On mappe la string sur l'enum TypeMouvementFinancier si possible
      switch (widget.typeRemboursement) {
        case 'remboursement_effectue':
          _controller
              .setTypeMouvement(TypeMouvementFinancier.remboursementEffectue);
          break;
        case 'remboursement_recu':
          _controller
              .setTypeMouvement(TypeMouvementFinancier.remboursementRecu);
          break;
        // Ajoute d'autres cas si besoin
      }
    }
  }

  void _initialiserController() {
    if (widget.transactionExistante != null) {
      final t = widget.transactionExistante!;

      // Définir la transaction existante dans le contrôleur pour le mode modification
      _controller.setTransactionExistante(t);

      _controller.setTypeTransaction(t.type);
      _controller.setTypeMouvement(t.typeMouvement);
      _controller.montantController.text = t.montant.toStringAsFixed(2);
      _controller.payeController.text = t.tiers ?? '';
      _controller.setCompteSelectionne(t.compteId);
      _controller.setDateSelectionnee(t.date);
      _controller.setEnveloppeSelectionnee(t.enveloppeId);
      _controller.setMarqueurSelectionne(t.marqueur);
      _controller.noteController.text = t.note ?? '';

      // Gérer le fractionnement si la transaction était fractionnée
      if (t.estFractionnee == true && t.sousItems != null) {
        // Créer une nouvelle instance de TransactionFractionnee
        final sousItems = t.sousItems!
            .map((item) => SousItemFractionnement(
                  id: item['id'] as String,
                  description: item['description'] as String? ?? '',
                  montant: (item['montant'] as num).toDouble(),
                  enveloppeId: item['enveloppeId'] as String,
                  transactionParenteId: t.id,
                ))
            .toList();

        final transactionFractionnee = TransactionFractionnee(
          transactionParenteId: t.id,
          sousItems: sousItems,
          montantTotal: t.montant,
        );

        _controller.setFractionnement(transactionFractionnee);
      }
    }
  }

  Future<void> _chargerDonnees() async {
    await _controller.chargerDonnees();
  }

  void _ouvrirModaleFractionnement() async {
    // Nettoyer le montant du symbole $ et des espaces
    String montantTexte = _controller.montantController.text.trim();
    montantTexte = montantTexte.replaceAll('\$', '').replaceAll(' ', '');

    final double montant =
        double.tryParse(montantTexte.replaceAll(',', '.')) ?? 0.0;

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
        // Exclure les pseudo-enveloppes correspondant au « Prêt à placer »
        final nomEnv = (env['nom'] as String?)?.toLowerCase() ?? '';
        final idEnv = env['id']?.toString() ?? '';
        if (nomEnv.contains('prêt à placer') || idEnv.startsWith('pret_')) {
          continue; // On saute cette enveloppe
        }

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
            categoriesFirebase: _controller.categoriesFirebase,
            comptesFirebase: _controller.listeComptesAffichables,
          ),
        );
      },
    );
  }

  Future<void> _sauvegarderTransaction() async {
    setState(() => _isLoading = true);

    try {
      final result = await _controller.sauvegarderTransaction();

      // Gestion des erreurs retournées par le contrôleur (ex: compte source non sélectionné)
      if (result != null && result['erreur'] != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['erreur']),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _isLoading = false);
        }
        return;
      }

      print('DEBUG: Sauvegarde terminée');
      print(
          'DEBUG: Transaction existante: ${_controller.transactionExistante?.id}');

      // Détecter le contexte de navigation
      final bool estDansNavigationOnglets = widget.onTransactionSaved != null;
      print('DEBUG: Contexte détecté - Onglets: $estDansNavigationOnglets');

      if (estDansNavigationOnglets) {
        // Navigation par onglets - utiliser le callback
        print('DEBUG: Appel du callback onTransactionSaved');
        widget.onTransactionSaved!();
        print('DEBUG: Callback onTransactionSaved terminé');
      } else {
        // Navigation normale (push/pop) - retourner à la page précédente
        if (mounted) {
          print('DEBUG: Navigation.pop() appelé');
          Navigator.of(context).pop(_controller.transactionExistante);
          print('DEBUG: Navigation.pop() terminé');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la sauvegarde : $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Color _getCouleurCompteEnveloppe(Map<String, dynamic> enveloppe) {
    // Obtenir le solde de l'enveloppe
    final double solde = (enveloppe['solde'] as num?)?.toDouble() ?? 0.0;

    // Déterminer la couleur par défaut du compte de provenance
    Color couleurDefaut = Colors.grey;

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
      couleurDefaut = Color(compte.couleur);
    } else {
      // Fallback avec l'ancien système de provenance unique
      final String? provenanceCompteId = enveloppe['provenance_compte_id'];
      if (provenanceCompteId != null && provenanceCompteId.isNotEmpty) {
        final compte = _controller.listeComptesAffichables.firstWhere(
          (c) => c.id == provenanceCompteId,
          orElse: () => _controller.listeComptesAffichables.first,
        );
        couleurDefaut = Color(compte.couleur);
      }
    }

    // Utiliser le service de couleur pour appliquer les règles
    return ColorService.getCouleurMontant(solde, couleurDefaut);
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: _buildAjoutTransactionContent(context),
        ),
      );
    }
    return _buildAjoutTransactionContent(context);
  }

  Widget _buildAjoutTransactionContent(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _controller,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.transactionExistante != null
                ? 'Modifier Transaction'
                : 'Ajouter Transaction',
          ),
          backgroundColor: const Color(0xFF18191A),
          foregroundColor: Colors.white,
          elevation: 0,
          surfaceTintColor: const Color(0xFF18191A),
        ),
        body: Consumer<AjoutTransactionController>(
          builder: (context, controller, child) {
            return Column(
              children: <Widget>[
                // Contenu principal avec scroll
                Expanded(
                  child: SingleChildScrollView(
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
                          listeComptesAffichables:
                              controller.listeComptesAffichables,
                          onCompteChanged: controller.setCompteSelectionne,
                          enveloppeSelectionnee:
                              controller.enveloppeSelectionnee,
                          categoriesFirebase: controller.categoriesFirebase,
                          comptesFirebase: controller.listeComptesAffichables,
                          typeSelectionne: controller.typeSelectionne,
                          onEnveloppeChanged:
                              controller.setEnveloppeSelectionnee,
                          getCouleurCompteEnveloppe: _getCouleurCompteEnveloppe,
                          dateSelectionnee: controller.dateSelectionnee,
                          onDateChanged: controller.setDateSelectionnee,
                          marqueurSelectionne: controller.marqueurSelectionne,
                          onMarqueurChanged: controller.setMarqueurSelectionne,
                          noteController: controller.noteController,
                          onTypeMouvementChanged: controller.setTypeMouvement,
                          ajoutController: controller,
                        ),

                        const SizedBox(height: 20),

                        // Section fractionnement (affichage seulement)
                        if (controller.estFractionnee)
                          SectionFractionnement(
                            estFractionnee: controller.estFractionnee,
                            transactionFractionnee:
                                controller.transactionFractionnee,
                            onSupprimerFractionnement: () =>
                                controller.setFractionnement(null),
                            onOuvrirModaleFractionnement:
                                _ouvrirModaleFractionnement,
                          ),

                        // Espace en bas pour éviter que le contenu soit caché par le bouton
                        const SizedBox(height: 60),
                      ],
                    ),
                  ),
                ),

                // Bouton sauvegarder fixe en bas
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFF18191A),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: BoutonSauvegarder(
                    estValide: controller.estValide,
                    onSauvegarder: _sauvegarderTransaction,
                    isLoading: _isLoading,
                    onFractionner: controller.estFractionnee
                        ? null
                        : _ouvrirModaleFractionnement,
                    estFractionnee: controller.estFractionnee,
                  ),
                ),
              ],
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
