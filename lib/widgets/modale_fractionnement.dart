import 'package:flutter/material.dart';
import '../models/fractionnement_model.dart';
import '../services/color_service.dart';
import '../widgets/numeric_keyboard.dart';
import '../themes/dropdown_theme_extension.dart';
import '../widgets/ajout_transaction/champ_enveloppe.dart';
import '../models/compte.dart';
import '../models/transaction_model.dart';

class ModaleFractionnement extends StatefulWidget {
  final double montantTotal;
  final List<Map<String, dynamic>> enveloppes;
  final Function(TransactionFractionnee) onConfirmer;
  final List<Map<String, dynamic>> categoriesFirebase;
  final List<Compte> comptesFirebase;

  const ModaleFractionnement({
    super.key,
    required this.montantTotal,
    required this.enveloppes,
    required this.onConfirmer,
    required this.categoriesFirebase,
    required this.comptesFirebase,
  });

  @override
  State<ModaleFractionnement> createState() => _ModaleFractionnementState();
}

class _ModaleFractionnementState extends State<ModaleFractionnement> {
  final List<SousItemFractionnement> _sousItems = [];
  int _prochaineId = 1;
  final List<String> _montantInputs = [];

  // Données de Firebase et état de chargement
  bool _comptesCharges = false;

  double get _montantAlloue =>
      _sousItems.fold(0.0, (sum, item) => sum + item.montant);
  double get _montantRestant => widget.montantTotal - _montantAlloue;
  bool get _estValide => _montantRestant.abs() < 0.01; // Tolérance

  @override
  void initState() {
    super.initState();
    if (!_comptesCharges) {
      _chargerDonneesInitiales();
    }
    _ajouterLigneSousItem(); // Restauration de l'appel initial
  }

  Future<void> _chargerDonneesInitiales() async {
    // TEST : on simule un chargement rapide, sans Firebase
    await Future.delayed(Duration(milliseconds: 100));
    if (mounted) {
      setState(() {
        _comptesCharges = true;
      });
    }
  }

  void _ajouterLigneSousItem() {
    setState(() {
      _sousItems.add(
        SousItemFractionnement(
          id: 'temp_${_prochaineId++}',
          description: '',
          montant: 0.0,
          enveloppeId: '',
        ),
      );
      _montantInputs.add('');
    });
  }

  void _supprimerSousItem(int index) {
    if (_sousItems.length > 1) {
      setState(() {
        _sousItems.removeAt(index);
        _montantInputs.removeAt(index);
      });
    }
  }

  void _mettreAJourSousItem(int index, {double? montant, String? enveloppeId}) {
    setState(() {
      String? description;
      if (enveloppeId != null) {
        final enveloppe = widget.enveloppes.firstWhere(
          (env) => env['id'] == enveloppeId,
          orElse: () => {'nom': 'Enveloppe inconnue'},
        );
        description = enveloppe['nom'];
      }

      _sousItems[index] = _sousItems[index].copyWith(
        description: description ?? _sousItems[index].description,
        montant: montant,
        enveloppeId: enveloppeId ?? _sousItems[index].enveloppeId,
      );
    });
  }

  void _mettreAJourMontantInput(int index, String value) {
    // Nettoyer le montant du symbole $ et des espaces
    String montantTexte = value.replaceAll('\$', '').replaceAll(' ', '');
    final montant = double.tryParse(montantTexte.replaceAll(',', '.')) ?? 0.0;
    setState(() {
      _montantInputs[index] = value;
      _mettreAJourSousItem(index, montant: montant);
    });
  }

  void _confirmerFractionnement() {
    if (_estValide &&
        _sousItems.every(
          (item) => item.montant > 0 && item.enveloppeId.isNotEmpty,
        )) {
      final transactionFractionnee = TransactionFractionnee(
        transactionParenteId: 'temp',
        sousItems: _sousItems,
        montantTotal: widget.montantTotal,
      );

      widget.onConfirmer(transactionFractionnee);
      Navigator.of(context).pop();
    }
  }

  void _ouvrirClavierNumerique(int index) {
    // Créer un contrôleur temporaire pour ce montant
    final TextEditingController tempController = TextEditingController(
      text: _montantInputs[index],
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled:
          true, // Important pour que le clavier ne cache pas le contenu
      builder: (_) => NumericKeyboard(
        controller: tempController,
        onClear: () {
          _mettreAJourMontantInput(index, '');
        },
        onValueChanged: (value) {
          // Mettre à jour le montant en temps réel
          _mettreAJourMontantInput(index, value);
        },
        showDecimal: true,
      ),
    ).then((_) {
      // Nettoyer le contrôleur
      try {
        tempController.dispose();
      } catch (e) {
        // Ignorer les erreurs de suppression
      }
    });
  }

  Widget _buildLigneSousItem(int index, {bool isInMainCard = false}) {
    final sousItem = _sousItems[index];
    final theme = Theme.of(context);
    final montantInput =
        _montantInputs.length > index ? _montantInputs[index] : '';

    return Padding(
      padding: EdgeInsets.only(bottom: isInMainCard ? 16 : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Article ${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ),
              const Spacer(),
              if (_sousItems.length > 1)
                IconButton(
                  onPressed: () => _supprimerSousItem(index),
                  icon: const Icon(Icons.close, color: Colors.red),
                  iconSize: 20,
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.center, // centrer verticalement
            children: [
              Expanded(
                flex: 1,
                child: Align(
                  alignment: Alignment.center,
                  child: GestureDetector(
                    onTap: () => _ouvrirClavierNumerique(index),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Montant (\$)',
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 15,
                        ),
                      ),
                      child: Text(
                        montantInput.isEmpty
                            ? '0.00'
                            : double.tryParse(
                                  montantInput
                                      .replaceAll('\$', '')
                                      .replaceAll(' ', '')
                                      .replaceAll(',', '.'),
                                )?.toStringAsFixed(2) ??
                                montantInput,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Enveloppe',
                              border: OutlineInputBorder(),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            child: ChampEnveloppe(
                              enveloppeSelectionnee: sousItem.enveloppeId.isEmpty
                                  ? null
                                  : sousItem.enveloppeId,
                              categoriesFirebase: widget.categoriesFirebase,
                              comptesFirebase: widget.comptesFirebase,
                              typeSelectionne: TypeTransaction.depense,
                              typeMouvementSelectionne:
                                  TypeMouvementFinancier.depenseNormale,
                              compteSelectionne:
                                  null, // Pas de compte spécifique pour le fractionnement
                              onEnveloppeChanged: (value) {
                                final enveloppe = widget.enveloppes.firstWhere(
                                  (env) => env['id'] == value,
                                  orElse: () => {'nom': 'Enveloppe inconnue'},
                                );
                                setState(() {
                                  _sousItems[index] = _sousItems[index].copyWith(
                                    enveloppeId: value ?? '',
                                    description:
                                        enveloppe['nom'] ?? 'Enveloppe inconnue',
                                  );
                                });
                              },
                              getCouleurCompteEnveloppe:
                                  _getCouleurCompteEnveloppe,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Fonction pour obtenir la couleur du compte d'origine d'une enveloppe
  Color _getCouleurCompteEnveloppe(Map<String, dynamic> enveloppe) {
    // Obtenir le solde de l'enveloppe
    final double solde = (enveloppe['solde'] as num?)?.toDouble() ?? 0.0;

    // Déterminer la couleur par défaut du compte de provenance
    Color couleurDefaut = Colors.grey;

    try {
      final List<dynamic>? provenances = enveloppe['provenances'];
      if (provenances != null && provenances.isNotEmpty) {
        var provenance = provenances.reduce(
          (a, b) => (a['montant'] as num) > (b['montant'] as num) ? a : b,
        );
        final compteId = provenance['compte_id'] as String?;
        if (compteId != null && enveloppe['comptes'] != null) {
          final comptes = enveloppe['comptes'] as List<dynamic>;
          try {
            final compte = comptes.firstWhere(
              (c) => c != null && c['id'] == compteId,
            );
            if (compte != null && compte['couleur'] != null) {
              couleurDefaut = Color(compte['couleur'] as int);
            }
          } catch (e) {
            // Compte non trouvé, continuer avec le fallback
          }
        }
      }

      final String? provenanceCompteId = enveloppe['provenance_compte_id'];
      if (provenanceCompteId != null &&
          provenanceCompteId.isNotEmpty &&
          enveloppe['comptes'] != null) {
        final comptes = enveloppe['comptes'] as List<dynamic>;
        try {
          final compte = comptes.firstWhere(
            (c) => c != null && c['id'] == provenanceCompteId,
          );
          if (compte != null && compte['couleur'] != null) {
            couleurDefaut = Color(compte['couleur'] as int);
          }
        } catch (e) {
          // Compte non trouvé, utiliser couleur par défaut
        }
      }
    } catch (e) {
      // Ignorer les erreurs de couleur
    }

    // Utiliser le service de couleur pour appliquer les règles
    return ColorService.getCouleurMontant(solde, couleurDefaut);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!_comptesCharges) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.8,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade800 : Colors.blue.shade50,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color:
                          isDark ? Colors.grey.shade600 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Fractionner ${widget.montantTotal.toStringAsFixed(2)} \$',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Alloué : ${_montantAlloue.toStringAsFixed(2)} \$ / ',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'Restant : ${_montantRestant.toStringAsFixed(2)} \$',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onPrimary.withAlpha(153),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Corps vide (plus de champs, plus de liste)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const ClampingScrollPhysics(),
                      itemCount: _sousItems.length,
                      itemBuilder: (context, index) {
                        return _buildLigneSousItem(index, isInMainCard: true);
                      },
                    ),
                  ),
                ),
              ),
            ),
            // Boutons d'action (désactivés)
            Container(
              padding: const EdgeInsets.all(
                12,
              ).copyWith(bottom: MediaQuery.of(context).padding.bottom + 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _ajouterLigneSousItem,
                      icon: const Icon(Icons.add),
                      label: const Text('Ajouter'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _estValide &&
                              _sousItems.every(
                                (item) =>
                                    item.montant > 0 &&
                                    item.enveloppeId.isNotEmpty,
                              )
                          ? _confirmerFractionnement
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _estValide ? Colors.green : Colors.grey,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Text(
                        'Confirmer',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
