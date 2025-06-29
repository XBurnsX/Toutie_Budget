import 'package:flutter/material.dart';
import '../../models/transaction_model.dart';
import '../numeric_keyboard.dart';

class ChampMontant extends StatelessWidget {
  final TextEditingController controller;
  final TypeTransaction typeSelectionne;
  final bool estFractionnee;
  final VoidCallback onFractionnementSupprime;
  final VoidCallback onMontantChange;

  const ChampMontant({
    Key? key,
    required this.controller,
    required this.typeSelectionne,
    required this.estFractionnee,
    required this.onFractionnementSupprime,
    required this.onMontantChange,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Color couleurMontant = typeSelectionne == TypeTransaction.depense
        ? const Color(0xFF8A0707)
        : Colors.greenAccent[300] ?? Colors.green;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30.0),
      child: TextField(
        controller: controller,
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
  }

  void _openNumericKeyboard(BuildContext context) {
    if (estFractionnee) {
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
                onFractionnementSupprime();
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
    showModalBottomSheet(
      context: context,
      builder: (_) => NumericKeyboard(
        onKeyTap: (key) {
          if (controller.text == '0.00') {
            controller.text = key;
          } else {
            controller.text += key;
          }
          controller.selection = TextSelection.fromPosition(
            TextPosition(offset: controller.text.length),
          );
          onMontantChange();
        },
        onBackspace: () {
          final text = controller.text;
          if (text.length > 1) {
            controller.text = text.substring(0, text.length - 1);
          } else {
            controller.text = '0.00';
          }
          controller.selection = TextSelection.fromPosition(
            TextPosition(offset: controller.text.length),
          );
          onMontantChange();
        },
        onClear: () {
          controller.text = '0.00';
          onMontantChange();
        },
        showDecimal: true,
      ),
    );
  }
}
