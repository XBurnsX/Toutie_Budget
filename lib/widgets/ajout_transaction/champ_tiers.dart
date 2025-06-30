import 'package:flutter/material.dart';
import '../../models/transaction_model.dart';
import '../../controllers/ajout_transaction_controller.dart';
import '../../themes/dropdown_theme_extension.dart';

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
    // Utiliser la même couleur que les cartes du thème
    final cardColor =
        Theme.of(context).cardTheme.color ??
        (Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[850]!
            : Colors.white);

    // Couleur automatique du thème pour les dropdowns
    final dropdownColor = Theme.of(context).dropdownColor;

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
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted &&
                  controller.text != fieldTextEditingController.text) {
                fieldTextEditingController.text = controller.text;
              }
            });

            fieldTextEditingController.addListener(() {
              if (context.mounted &&
                  controller.text != fieldTextEditingController.text) {
                controller.text = fieldTextEditingController.text;
                // Forcer la validation du contrôleur
                ajoutController.notifyListeners();
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
                hintStyle: TextStyle(
                  color: Theme.of(context).hintColor.withOpacity(0.7),
                  fontSize: 16,
                ),
                prefixIcon: Icon(
                  typeMouvementSelectionne ==
                              TypeMouvementFinancier.detteContractee ||
                          typeMouvementSelectionne ==
                              TypeMouvementFinancier.remboursementEffectue
                      ? Icons.account_balance
                      : Icons.person_outline,
                  color: Theme.of(context).hintColor,
                  size: 20,
                ),
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: fieldTextEditingController,
                  builder: (context, value, child) {
                    return value.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.clear,
                              color: Theme.of(context).hintColor,
                              size: 20,
                            ),
                            onPressed: () {
                              fieldTextEditingController.clear();
                              controller.clear();
                              ajoutController.notifyListeners();
                            },
                          )
                        : Icon(
                            Icons.arrow_drop_down,
                            color: Theme.of(context).hintColor,
                          );
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: BorderSide(
                    color: Theme.of(context).dividerColor.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: BorderSide(
                    color: Theme.of(context).dividerColor.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: BorderSide(
                    color: Theme.of(context).primaryColor,
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: cardColor,
                isDense: false,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 16.0,
                  horizontal: 16.0,
                ),
              ),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
              onChanged: (value) {
                // Synchronisation immédiate lors de la saisie
                if (controller.text != value) {
                  controller.text = value;
                  ajoutController.notifyListeners();
                }
              },
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
        // Forcer la validation du contrôleur après la sélection
        ajoutController.notifyListeners();
        FocusScope.of(context).unfocus();
      },
      optionsViewBuilder: (context, onSelected, options) {
        return TapRegion(
          onTapOutside: (event) {
            // Fermer la liste quand on clique en dehors
            FocusScope.of(context).unfocus();
          },
          child: Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 8.0,
              borderRadius: BorderRadius.circular(12.0),
              shadowColor: Colors.black.withOpacity(0.2),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12.0),
                  color: dropdownColor,
                  border: Border.all(
                    color: Theme.of(context).dividerColor.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 250,
                    minWidth: 200,
                  ),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    itemCount: options.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      thickness: 0.5,
                      color: Theme.of(context).dividerColor.withOpacity(0.3),
                      indent: 16,
                      endIndent: 16,
                    ),
                    itemBuilder: (BuildContext context, int index) {
                      final String option = options.elementAt(index);
                      final bool isAddOption = option.startsWith("Ajouter : ");

                      return InkWell(
                        onTap: () => onSelected(option),
                        borderRadius: BorderRadius.circular(8.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 12.0,
                          ),
                          child: Row(
                            children: [
                              if (isAddOption) ...[
                                Icon(
                                  Icons.add_circle_outline,
                                  size: 20,
                                  color: Theme.of(context).primaryColor,
                                ),
                                const SizedBox(width: 12),
                              ] else ...[
                                Icon(
                                  Icons.person_outline,
                                  size: 20,
                                  color: Theme.of(context).hintColor,
                                ),
                                const SizedBox(width: 12),
                              ],
                              Expanded(
                                child: Text(
                                  option,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: isAddOption
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: isAddOption
                                        ? Theme.of(context).primaryColor
                                        : Theme.of(
                                            context,
                                          ).textTheme.bodyLarge?.color,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
