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
    super.key,
    required this.estValide,
    required this.onSauvegarder,
    this.isLoading = false,
    this.onFractionner,
    this.estFractionnee = false,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AjoutTransactionController>(
      builder: (context, controller, child) {
        return Column(
          children: [
            // Le bandeau d'aide a été supprimé (design épuré)

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
                        : Text(
                            controller.transactionExistante != null
                                ? 'Modifier'
                                : 'Sauvegarder',
                            style: const TextStyle(
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
}
