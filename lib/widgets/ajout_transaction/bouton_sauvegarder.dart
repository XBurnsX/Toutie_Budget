import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/ajout_transaction_controller.dart';
import '../../models/transaction_model.dart';

class BoutonSauvegarder extends StatelessWidget {
  final bool estValide;
  final VoidCallback onSauvegarder;
  final bool isLoading;
  final VoidCallback? onFractionner;
  final bool estFractionnee;

  const BoutonSauvegarder({
    Key? key,
    required this.estValide,
    required this.onSauvegarder,
    this.isLoading = false,
    this.onFractionner,
    this.estFractionnee = false,
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

            // Boutons
            Row(
              children: [
                // Bouton Fractionner (si disponible)
                if (onFractionner != null && !estFractionnee)
                  Expanded(
                    child: ElevatedButton(
                      onPressed:
                          _estValidePourFractionnement(controller) && !isLoading
                          ? onFractionner
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _estValidePourFractionnement(controller) &&
                                !isLoading
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey[600],
                        foregroundColor:
                            _estValidePourFractionnement(controller) &&
                                !isLoading
                            ? Theme.of(context).colorScheme.onPrimary
                            : Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        minimumSize: const Size(0, 40),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.call_split, size: 16),
                          const SizedBox(width: 4),
                          const Text(
                            'Fractionner',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Espace entre les boutons
                if (onFractionner != null && !estFractionnee)
                  const SizedBox(width: 12),

                // Bouton Sauvegarder
                Expanded(
                  child: ElevatedButton(
                    onPressed: estValide && !isLoading ? onSauvegarder : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: estValide && !isLoading
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey[600],
                      foregroundColor: estValide && !isLoading
                          ? Theme.of(context).colorScheme.onPrimary
                          : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      minimumSize: const Size(0, 40),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            height: 16,
                            width: 16,
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
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  bool _estValidePourFractionnement(AjoutTransactionController controller) {
    // Nettoyer le montant du symbole $ et des espaces
    String montantTexte = controller.montantController.text.trim();
    montantTexte = montantTexte.replaceAll('\$', '').replaceAll(' ', '');
    montantTexte = montantTexte.replaceAll(',', '.');

    final montant = double.tryParse(montantTexte) ?? 0.0;

    // Vérifier si c'est un type de transaction de prêt personnel
    final estPretPersonnel =
        controller.typeMouvementSelectionne ==
            TypeMouvementFinancier.pretAccorde ||
        controller.typeMouvementSelectionne ==
            TypeMouvementFinancier.remboursementRecu ||
        controller.typeMouvementSelectionne ==
            TypeMouvementFinancier.detteContractee ||
        controller.typeMouvementSelectionne ==
            TypeMouvementFinancier.remboursementEffectue;

    // Pour fractionner, il faut un montant valide ET ne pas être un prêt personnel
    return montant > 0 && !estPretPersonnel;
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
