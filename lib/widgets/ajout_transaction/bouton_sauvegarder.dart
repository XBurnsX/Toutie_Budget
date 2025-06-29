import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/ajout_transaction_controller.dart';
import '../../models/transaction_model.dart';

class BoutonSauvegarder extends StatelessWidget {
  final bool estValide;
  final VoidCallback onSauvegarder;
  final bool isLoading;

  const BoutonSauvegarder({
    Key? key,
    required this.estValide,
    required this.onSauvegarder,
    this.isLoading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<AjoutTransactionController>(
      builder: (context, controller, child) {
        final messageAide = _getMessageAide(controller);

        return Column(
          children: [
            // Message d'aide
            if (!estValide && !isLoading && messageAide.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 16,
                ),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.orange[700],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        messageAide,
                        style: TextStyle(
                          color: Colors.orange[700],
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Bouton
            Center(
              child: SizedBox(
                width: 250,
                child: ElevatedButton(
                  onPressed: estValide && !isLoading ? onSauvegarder : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 30),
                    minimumSize: const Size(250, 60),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text(
                          'Sauvegarder',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _getMessageAide(AjoutTransactionController controller) {
    // Améliorer le parsing du montant pour accepter différents formats
    String montantTexte = controller.montantController.text.trim();
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

    final montant = double.tryParse(montantTexte) ?? 0.0;
    final tiersTexte = controller.payeController.text.trim();

    List<String> messages = [];

    // Vérifier le montant
    if (montant <= 0) {
      messages.add('Entrez un montant valide');
    }

    // Vérifier le tiers
    if (tiersTexte.isEmpty) {
      messages.add('Entrez un tiers');
    }

    // Vérifier le compte
    if (controller.compteSelectionne == null) {
      messages.add('Sélectionnez un compte');
    }

    // Vérifier l'enveloppe (seulement pour les transactions normales)
    if (!controller.estFractionnee &&
        !(controller.typeMouvementSelectionne ==
                TypeMouvementFinancier.pretAccorde ||
            controller.typeMouvementSelectionne ==
                TypeMouvementFinancier.remboursementRecu ||
            controller.typeMouvementSelectionne ==
                TypeMouvementFinancier.detteContractee ||
            controller.typeMouvementSelectionne ==
                TypeMouvementFinancier.remboursementEffectue) &&
        (controller.enveloppeSelectionnee == null ||
            controller.enveloppeSelectionnee!.isEmpty)) {
      messages.add('Sélectionnez une enveloppe');
    }

    // Vérifier le fractionnement
    if (controller.estFractionnee &&
        controller.transactionFractionnee != null) {
      if (!controller.transactionFractionnee!.estValide) {
        messages.add('Le fractionnement n\'est pas valide');
      }
    }

    return messages.join(', ');
  }
}
