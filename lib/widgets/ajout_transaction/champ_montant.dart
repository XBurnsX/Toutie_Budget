import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/transaction_model.dart';
import '../../controllers/ajout_transaction_controller.dart';
import '../numeric_keyboard.dart';

class ChampMontant extends StatefulWidget {
  final TextEditingController controller;
  final bool estFractionnee;
  final VoidCallback onFractionnementSupprime;
  final VoidCallback onMontantChange;

  const ChampMontant({
    super.key,
    required this.controller,
    required this.estFractionnee,
    required this.onFractionnementSupprime,
    required this.onMontantChange,
  });

  @override
  State<ChampMontant> createState() => _ChampMontantState();
}

class _ChampMontantState extends State<ChampMontant> {
  String? _montantOriginal;

  @override
  Widget build(BuildContext context) {
    return Consumer<AjoutTransactionController>(
      builder: (context, controller, child) {
        // Logique pour déterminer la couleur selon le type de mouvement
        final Color couleurMontant = _getCouleurMontant(controller);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 30.0),
          child: TextField(
            controller: widget.controller,
            readOnly: true,
            onTap: () => _openNumericKeyboard(context),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: couleurMontant,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: '0.00',
              hintStyle: TextStyle(color: Colors.grey[600]),
            ),
          ),
        );
      },
    );
  }

  Color _getCouleurMontant(AjoutTransactionController controller) {
    // Remboursements reçus et dettes contractées = revenus (vert)
    if (controller.typeMouvementSelectionne ==
            TypeMouvementFinancier.remboursementRecu ||
        controller.typeMouvementSelectionne ==
            TypeMouvementFinancier.detteContractee) {
      return Colors.greenAccent[300] ?? Colors.green;
    }

    // Remboursements effectués et prêts accordés = dépenses (rouge)
    if (controller.typeMouvementSelectionne ==
            TypeMouvementFinancier.remboursementEffectue ||
        controller.typeMouvementSelectionne ==
            TypeMouvementFinancier.pretAccorde) {
      return const Color(0xFF8A0707);
    }

    // Pour les autres types, utiliser la logique basée sur typeSelectionne
    final couleur = controller.typeSelectionne == TypeTransaction.depense
        ? const Color(0xFF8A0707)
        : Colors.greenAccent[300] ?? Colors.green;
    return couleur;
  }

  void _openNumericKeyboard(BuildContext context) {
    if (widget.estFractionnee) {
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Modifier le montant'),
          content: const Text(
            'Modifier le montant va supprimer le fractionnement actuel. Voulez-vous continuer ?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                widget.onFractionnementSupprime();
                _ouvrirClavierNumerique(context);
              },
              child: const Text('Continuer'),
            ),
          ],
        ),
      );
    } else {
      _ouvrirClavierNumerique(context);
    }
  }

  void _ouvrirClavierNumerique(BuildContext context) {
    // Sauvegarder la valeur actuelle et réinitialiser le contrôleur
    setState(() {
      _montantOriginal = widget.controller.text;
      widget.controller.text = '0.00';
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled:
          true, // Permet au clavier de prendre plus de place si nécessaire
      builder: (_) => NumericKeyboard(
        controller: widget.controller,
        onClear: widget.onMontantChange,
        onValueChanged: (value) {
          widget.onMontantChange();
        },
        showDecimal: true,
      ),
    ).whenComplete(() {
      // Si l'utilisateur ferme sans entrer de valeur, restaurer la valeur originale
      if (widget.controller.text == '0.00' || widget.controller.text.isEmpty) {
        setState(() {
          widget.controller.text = _montantOriginal ?? '0.00';
        });
      }
      widget.onMontantChange();
    });
  }
}
