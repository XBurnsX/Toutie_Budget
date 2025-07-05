import 'package:flutter/material.dart';
import '../../models/compte.dart';
import '../../models/transaction_model.dart';
import '../../themes/dropdown_theme_extension.dart';

class ChampCompte extends StatelessWidget {
  final String? compteSelectionne;
  final List<Compte> listeComptesAffichables;
  final TypeMouvementFinancier typeMouvementSelectionne;
  final Function(String?) onCompteChanged;

  const ChampCompte({
    super.key,
    required this.compteSelectionne,
    required this.listeComptesAffichables,
    required this.typeMouvementSelectionne,
    required this.onCompteChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Couleur automatique du thème pour les dropdowns
    final dropdownColor = Theme.of(context).dropdownColor;

    return DropdownButtonFormField<String>(
      value: compteSelectionne,
      items: listeComptesAffichables.map((Compte compte) {
        return DropdownMenuItem<String>(
          value: compte.id,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Color(compte.couleur),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  compte.nom,
                  style: Theme.of(context).textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      }).toList(),
      selectedItemBuilder: (context) {
        return listeComptesAffichables.map((compte) {
          return Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Color(compte.couleur),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  compte.nom,
                  style: Theme.of(context).textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        }).toList();
      },
      onChanged: (String? newValue) {
        onCompteChanged(newValue);
      },
      decoration: InputDecoration(
        hintText: 'Sélectionner un compte',
        border: InputBorder.none,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 10.0,
          horizontal: 12.0,
        ),
      ),
      isExpanded: true,
      alignment: Alignment.center,
      dropdownColor: dropdownColor,
    );
  }
}
