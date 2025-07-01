import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/ajout_transaction_controller.dart';
import '../models/transaction_model.dart';
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
        // TODO: Implémenter la restauration du fractionnement
        // Debug silencieux - fractionnement à restaurer
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
          ),
        );
      },
    );
  }

  Future<void> _sauvegarderTransaction() async {
    setState(() => _isLoading = true);

    try {
      final result = await _controller.sauvegarderTransaction();

      // Si result n'est pas null, la transaction a réussi
      // Si result est null mais qu'aucune exception n'a été levée, la transaction a aussi réussi
      if (mounted) {
        final tiersTexte = _controller.payeController.text.trim();
        String message = '';

        // Différencier les messages selon le mode (ajout ou modification)
        final estModification = widget.transactionExistante != null;
        final prefix = estModification
            ? 'Transaction modifiée'
            : 'Transaction ajoutée';

        switch (_controller.typeMouvementSelectionne) {
          case TypeMouvementFinancier.depenseNormale:
            message = '$prefix chez $tiersTexte';
            break;
          case TypeMouvementFinancier.revenuNormal:
            message = estModification
                ? 'Votre solde a été mis à jour avec succès'
                : 'Votre solde a été mis à jour avec succès';
            break;
          case TypeMouvementFinancier.pretAccorde:
            message = estModification
                ? 'Prêt à $tiersTexte modifié avec succès'
                : 'Prêt à $tiersTexte créé avec succès';
            break;
          case TypeMouvementFinancier.detteContractee:
            message = estModification
                ? 'Votre dette à $tiersTexte modifiée avec succès'
                : 'Votre dette à $tiersTexte créée avec succès';
            break;
          case TypeMouvementFinancier.remboursementRecu:
            message = estModification
                ? 'Le solde du prêt à $tiersTexte a été mis à jour'
                : 'Le solde du prêt à $tiersTexte a été mis à jour';
            break;
          case TypeMouvementFinancier.remboursementEffectue:
            message = estModification
                ? 'Votre prêt à $tiersTexte a été mis à jour'
                : 'Votre prêt à $tiersTexte a été mis à jour';
            break;
          case TypeMouvementFinancier.ajustement:
            message = 'Ajustement de solde pour $tiersTexte enregistré';
            break;
        }

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));

        // Afficher le message de finalisation si applicable
        if (result != null && result['finalisee'] == true) {
          await Future.delayed(
            const Duration(milliseconds: 500),
          ); // Petit délai pour séparer les messages

          String messageFinalisation = '';
          if (result['typeMouvement'] ==
              TypeMouvementFinancier.remboursementRecu) {
            messageFinalisation = '${result['nomTiers']} a finalisé son prêt !';
          } else if (result['typeMouvement'] ==
              TypeMouvementFinancier.remboursementEffectue) {
            if (result['estManuelle'] == true) {
              messageFinalisation = 'Félicitations, votre dette est terminée !';
            } else {
              messageFinalisation = 'Félicitations, votre prêt est terminé !';
            }
          }

          if (mounted && messageFinalisation.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(messageFinalisation),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }

        widget.onTransactionSaved?.call();
      }
    } catch (e) {
      if (mounted) {
        // Afficher le message d'erreur spécifique pour la validation du remboursement
        final errorMessage = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
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
        appBar: AppBar(
          title: Text(
            widget.transactionExistante != null
                ? 'Modifier Transaction'
                : 'Ajouter Transaction',
          ),
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
                    color: Theme.of(context).scaffoldBackgroundColor,
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
