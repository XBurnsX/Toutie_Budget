import 'package:flutter/material.dart';
import '../../models/transaction_model.dart';
import '../../controllers/ajout_transaction_controller.dart';

class ChampTiers extends StatelessWidget {
  final TextEditingController controller;
  final TypeMouvementFinancier typeMouvementSelectionne;
  final List<String> listeTiersConnus;
  final Function(String) onTiersAjoute;
  final AjoutTransactionController ajoutController;

  const ChampTiers({
    super.key,
    required this.controller,
    required this.typeMouvementSelectionne,
    required this.listeTiersConnus,
    required this.onTiersAjoute,
    required this.ajoutController,
  });

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      key: ValueKey(typeMouvementSelectionne),
      optionsBuilder: (TextEditingValue textEditingValue) {
        final String texteSaisi = textEditingValue.text;

        if (textEditingValue.text.isEmpty) {
          return listeTiersConnus;
        }

        final suggestionsStandard = listeTiersConnus.where((String option) {
          return ajoutController
              .normaliserChaine(option)
              .contains(ajoutController.normaliserChaine(texteSaisi));
        });

        // Vérifier si le texte saisi existe déjà exactement
        bool existeDeja = listeTiersConnus.any(
          (String option) =>
              ajoutController.normaliserChaine(option) ==
              ajoutController.normaliserChaine(texteSaisi),
        );

        // Si le texte saisi n'est pas vide ET n'existe pas déjà, ajouter l'option "Ajouter"
        if (texteSaisi.isNotEmpty && !existeDeja) {
          return <String>['Ajouter : $texteSaisi', ...suggestionsStandard];
        } else {
          return suggestionsStandard;
        }
      },
      fieldViewBuilder:
          (
            BuildContext context,
            TextEditingController fieldTextEditingController,
            FocusNode fieldFocusNode,
            VoidCallback onFieldSubmitted,
          ) {
            // Synchronisation avec le controller principal
            if (controller.text.isNotEmpty &&
                fieldTextEditingController.text != controller.text) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) {
                  fieldTextEditingController.text = controller.text;
                }
              });
            }

            fieldTextEditingController.addListener(() {
              if (context.mounted &&
                  controller.text != fieldTextEditingController.text) {
                controller.text = fieldTextEditingController.text;
              }
            });

            return TextField(
              controller: fieldTextEditingController,
              focusNode: fieldFocusNode,
              decoration: InputDecoration(
                hintText:
                    typeMouvementSelectionne ==
                            TypeMouvementFinancier.detteContractee ||
                        typeMouvementSelectionne ==
                            TypeMouvementFinancier.remboursementEffectue
                    ? 'Nom du prêteur'
                    : 'Payé à / Reçu de',
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 10.0,
                  horizontal: 10.0,
                ),
              ),
              onSubmitted: (_) => onFieldSubmitted(),
            );
          },
      onSelected: (String selection) async {
        final String prefixeAjout = "Ajouter : ";
        if (selection.startsWith(prefixeAjout)) {
          final String nomAAjouter = selection.substring(prefixeAjout.length);
          controller.text = nomAAjouter;
          onTiersAjoute(nomAAjouter);
        } else {
          controller.text = selection;
        }
        FocusScope.of(context).unfocus();
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4.0,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: options.length,
                itemBuilder: (BuildContext context, int index) {
                  final String option = options.elementAt(index);
                  return InkWell(
                    onTap: () => onSelected(option),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(option),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
