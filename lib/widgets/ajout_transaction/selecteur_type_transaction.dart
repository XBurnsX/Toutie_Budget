import 'package:flutter/material.dart';
import '../../models/transaction_model.dart';

class SelecteurTypeTransaction extends StatelessWidget {
  final TypeTransaction typeSelectionne;
  final TypeMouvementFinancier typeMouvementSelectionne;
  final Function(TypeTransaction, TypeMouvementFinancier) onTypeChanged;

  const SelecteurTypeTransaction({
    super.key,
    required this.typeSelectionne,
    required this.typeMouvementSelectionne,
    required this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color selectorBackgroundColor = isDark
        ? Colors.grey[800]!
        : Colors.grey[300]!;
    final Color selectedOptionColor = isDark
        ? Colors.black54
        : Colors.blueGrey[700]!;
    final Color unselectedTextColor = isDark
        ? Colors.grey[400]!
        : Colors.grey[600]!;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20.0),
      decoration: BoxDecoration(
        color: selectorBackgroundColor,
        borderRadius: BorderRadius.circular(25.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _buildOptionType(
            TypeTransaction.depense,
            '- Dépense',
            selectedOptionColor,
            unselectedTextColor,
          ),
          _buildOptionType(
            TypeTransaction.revenu,
            '+ Revenu',
            selectedOptionColor,
            unselectedTextColor,
          ),
        ],
      ),
    );
  }

  Widget _buildOptionType(
    TypeTransaction type,
    String libelle,
    Color selectedBackgroundColor,
    Color unselectedTextColor,
  ) {
    final estSelectionne = typeSelectionne == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          TypeMouvementFinancier nouveauTypeMouvement =
              typeMouvementSelectionne;

          if (type == TypeTransaction.depense) {
            if (!typeMouvementSelectionne.estDepense) {
              nouveauTypeMouvement = TypeMouvementFinancier.depenseNormale;
            }
          } else {
            if (!typeMouvementSelectionne.estRevenu) {
              nouveauTypeMouvement = TypeMouvementFinancier.revenuNormal;
            }
          }

          onTypeChanged(type, nouveauTypeMouvement);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 20.0),
          decoration: BoxDecoration(
            color: estSelectionne
                ? selectedBackgroundColor
                : Colors.transparent,
            borderRadius: BorderRadius.circular(25.0),
          ),
          child: Text(
            libelle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: estSelectionne ? Colors.white : unselectedTextColor,
              fontWeight: estSelectionne ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
