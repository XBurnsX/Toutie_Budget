import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/compte.dart';
import '../models/transaction_model.dart' as app_model;
import '../services/firebase_service.dart';
import '../widgets/numeric_keyboard.dart';

/// Page de réconciliation bancaire
class PageReconciliation extends StatefulWidget {
  final Compte compte;

  const PageReconciliation({super.key, required this.compte});

  @override
  State<PageReconciliation> createState() => _PageReconciliationState();
}

class _PageReconciliationState extends State<PageReconciliation> {
  final _formKey = GlobalKey<FormState>();
  final _soldeReelController = TextEditingController();
  double? _soldeReel;
  double? _ecart;
  bool _showEcart = false;
  String? _montantOriginal;

  @override
  void dispose() {
    _soldeReelController.dispose();
    super.dispose();
  }

  void _calculerEcart() {
    if (_soldeReel != null) {
      setState(() {
        _ecart = _soldeReel! - widget.compte.solde;
        _showEcart = true;
      });
    }
  }

  void _ouvrirClavierNumerique() {
    // Sauvegarder la valeur actuelle et réinitialiser le contrôleur
    setState(() {
      _montantOriginal = _soldeReelController.text;
      _soldeReelController.text = '0.00';
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => NumericKeyboard(
        controller: _soldeReelController,
        onClear: () {
          setState(() {
            _soldeReelController.text = '';
            _soldeReel = null;
            _showEcart = false;
          });
        },
        onValueChanged: (value) {
          setState(() {
            _soldeReel = double.tryParse(
              value
                  .replaceAll('\$', '')
                  .replaceAll(' ', '')
                  .replaceAll(',', '.'),
            );
            if (_soldeReel != null) {
              _calculerEcart();
            } else {
              _showEcart = false;
            }
          });
        },
        showDecimal: true,
      ),
    ).whenComplete(() {
      // Si l'utilisateur ferme sans entrer de valeur, restaurer la valeur originale
      if (_soldeReelController.text == '0.00' ||
          _soldeReelController.text.isEmpty) {
        setState(() {
          _soldeReelController.text = _montantOriginal ?? '';
          _soldeReel = double.tryParse(
                  _montantOriginal?.replaceAll(',', '.') ?? '0.0') ??
              0.0;
          if (_soldeReel != 0) {
            _calculerEcart();
          } else {
            _showEcart = false;
          }
        });
      }
    });
  }

  Future<void> _creerTransactionAjustement() async {
    if (_ecart == null || _ecart == 0) return;

    final transactionId =
        FirebaseService().firestore.collection('transactions').doc().id;
    final transaction = app_model.Transaction(
      id: transactionId,
      userId: '', // Sera rempli par FirebaseService
      type: _ecart! > 0
          ? app_model.TypeTransaction.revenu
          : app_model.TypeTransaction.depense,
      typeMouvement: _ecart! > 0
          ? app_model.TypeMouvementFinancier.revenuNormal
          : app_model.TypeMouvementFinancier.depenseNormale,
      montant: _ecart!.abs(),
      compteId: widget.compte.id,
      date: DateTime.now(),
      tiers: 'Ajustement de réconciliation',
      compteDePassifAssocie: '',
      enveloppeId: '',
      marqueur: '',
      note:
          'Ajustement automatique lors de la réconciliation du ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
    );

    await FirebaseService().ajouterTransaction(transaction);

    // Mettre à jour le solde du compte
    final nouveauSolde = widget.compte.solde + _ecart!;
    final nouveauPretAPlacer = widget.compte.pretAPlacer + _ecart!;

    await FirebaseService().updateCompte(widget.compte.id, {
      'solde': nouveauSolde,
      'pretAPlacer': nouveauPretAPlacer,
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Réconciliation terminée. Transaction d\'ajustement créée.',
          ),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Réconciliation')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Informations du compte
                  Card(
                    color: const Color(0xFF232526),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Compte : ${widget.compte.nom}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Solde actuel dans l\'app : ${widget.compte.solde.toStringAsFixed(2)} \$',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Solde réel
                  GestureDetector(
                    onTap: () => _ouvrirClavierNumerique(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Solde réel sur le relevé bancaire',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _soldeReelController.text.isEmpty
                                      ? '0.00'
                                      : _soldeReelController.text,
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                          const Text('\$', style: TextStyle(fontSize: 16)),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Affichage de l'écart
                  if (_showEcart) ...[
                    Card(
                      color: _ecart == 0
                          ? Colors.green.withValues(alpha: 0.2)
                          : Colors.orange.withValues(alpha: 0.2),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _ecart == 0
                                  ? '✅ Comptes réconciliés'
                                  : '⚠️ Écart détecté',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color:
                                    _ecart == 0 ? Colors.green : Colors.orange,
                              ),
                            ),
                            if (_ecart != 0) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Écart : ${_ecart! < 0 ? '-' : ''}${_ecart!.abs().toStringAsFixed(2)} \$',
                                style: const TextStyle(fontSize: 14),
                              ),
                              Text(
                                _ecart! > 0
                                    ? 'La réconciliation montre un solde supérieur'
                                    : 'La réconciliation montre un solde inférieur',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[400],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Boutons d'action
                    if (_ecart == 0)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            if (_soldeReel == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Veuillez saisir le solde réel',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Réconciliation terminée. Aucun ajustement nécessaire.',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                            Navigator.of(context).pop();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('Terminer la réconciliation'),
                        ),
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            if (_soldeReel == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Veuillez saisir le solde réel',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text(
                                  'Créer une transaction d\'ajustement',
                                ),
                                content: Text(
                                  'Une transaction d\'ajustement de ${_ecart!.toStringAsFixed(2)} \$ '
                                  'sera créée pour réconcilier les comptes.\n\n'
                                  'Le solde du compte sera ajusté automatiquement.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Annuler'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Confirmer'),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true) {
                              await _creerTransactionAjustement();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text(
                            'Créer une transaction d\'ajustement',
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
