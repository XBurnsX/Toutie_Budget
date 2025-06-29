import 'package:flutter/material.dart';
import '../../models/fractionnement_model.dart';

class SectionFractionnement extends StatelessWidget {
  final bool estFractionnee;
  final TransactionFractionnee? transactionFractionnee;
  final VoidCallback onSupprimerFractionnement;
  final VoidCallback onOuvrirModaleFractionnement;

  const SectionFractionnement({
    super.key,
    required this.estFractionnee,
    required this.transactionFractionnee,
    required this.onSupprimerFractionnement,
    required this.onOuvrirModaleFractionnement,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Section fractionnement existant
        if (estFractionnee && transactionFractionnee != null)
          _buildSectionFractionnementExistante(),

        // Bouton Fractionner - seulement pour les dépenses normales
        if (!estFractionnee)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            child: OutlinedButton.icon(
              onPressed: onOuvrirModaleFractionnement,
              icon: const Icon(Icons.call_split),
              label: const Text('Fractionner'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: const BorderSide(color: Colors.blue),
                foregroundColor: Colors.blue,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSectionFractionnementExistante() {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.call_split, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Transaction fractionnée',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const Spacer(),
                IconButton(
                  onPressed: onSupprimerFractionnement,
                  icon: const Icon(Icons.close, color: Colors.red),
                  iconSize: 20,
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...transactionFractionnee!.sousItems.map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        item.description,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '${item.montant.toStringAsFixed(2)} \$',
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(),
            Row(
              children: [
                const Text(
                  'Total :',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  '${transactionFractionnee!.montantTotal.toStringAsFixed(2)} \$',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
