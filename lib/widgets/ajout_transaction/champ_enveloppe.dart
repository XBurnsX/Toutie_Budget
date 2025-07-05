import 'package:flutter/material.dart';
import '../../models/compte.dart';
import '../../models/transaction_model.dart';
import '../../themes/dropdown_theme_extension.dart';

class ChampEnveloppe extends StatelessWidget {
  final String? enveloppeSelectionnee;
  final List<Map<String, dynamic>> categoriesFirebase;
  final List<Compte> comptesFirebase;
  final TypeTransaction typeSelectionne;
  final TypeMouvementFinancier typeMouvementSelectionne;
  final String? compteSelectionne;
  final Function(String?) onEnveloppeChanged;
  final Color Function(Map<String, dynamic>) getCouleurCompteEnveloppe;

  const ChampEnveloppe({
    super.key,
    required this.enveloppeSelectionnee,
    required this.categoriesFirebase,
    required this.comptesFirebase,
    required this.typeSelectionne,
    required this.typeMouvementSelectionne,
    required this.compteSelectionne,
    required this.onEnveloppeChanged,
    required this.getCouleurCompteEnveloppe,
  });

  @override
  Widget build(BuildContext context) {
    // Couleur automatique du thème pour les dropdowns
    final dropdownColor = Theme.of(context).dropdownColor;

    // Construire la liste des items une seule fois
    final items = _buildEnveloppeItems();

    // S'assurer que la valeur sélectionnée existe dans la liste ; sinon la remettre à null
    String? valeurActuelle = enveloppeSelectionnee;
    final occurences = items.where((item) => item.value == valeurActuelle);
    if (valeurActuelle != null && occurences.length != 1) {
      valeurActuelle = null;
    }

    return DropdownButtonFormField<String>(
      value: valeurActuelle,
      items: items,
      onChanged: (String? newValue) => onEnveloppeChanged(newValue),
      selectedItemBuilder: (context) {
        return items.map((item) {
          if (item.value == null) {
            return const Center(child: Text('Aucune'));
          }
          return Center(child: item.child!);
        }).toList();
      },
      decoration: InputDecoration(
        hintText: 'Optionnel',
        border: InputBorder.none,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 10.0,
          horizontal: 50.0,
        ),
      ),
      isExpanded: true,
      alignment: Alignment.center,
      dropdownColor: dropdownColor,
    );
  }

  List<DropdownMenuItem<String>> _buildEnveloppeItems() {
    final items = <DropdownMenuItem<String>>[];

    // Option "Aucune"
    items.add(
      const DropdownMenuItem<String>(
        value: null,
        child: Text("Aucune", style: TextStyle(fontStyle: FontStyle.italic)),
      ),
    );

    // Prêts à placer dynamiques (seulement pour les revenus)
    if (typeSelectionne != TypeTransaction.depense &&
        compteSelectionne != null) {
      final comptesAvecPret = comptesFirebase.where(
        (c) => c.pretAPlacer > 0 && c.id == compteSelectionne,
      );

      for (final compte in comptesAvecPret) {
        items.add(
          DropdownMenuItem<String>(
            value: 'pret_${compte.id}',
            child: Text(
              '${compte.nom} : Prêt à placer ${compte.pretAPlacer.toStringAsFixed(2)}',
            ),
          ),
        );
      }
    }

    // Enveloppes classiques filtrées
    final enveloppesFiltrees = categoriesFirebase
        .expand((cat) => (cat['enveloppes'] as List))
        .where((env) => _estEnveloppeAffichable(env))
        .toList();

    for (final env in enveloppesFiltrees) {
      final solde = (env['solde'] as num?)?.toDouble() ?? 0.0;
      final couleurCompte = getCouleurCompteEnveloppe(env);

      items.add(
        DropdownMenuItem<String>(
          value: env['id'],
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(env['nom'], overflow: TextOverflow.ellipsis),
                const SizedBox(width: 6),
                Text(
                  '${solde.toStringAsFixed(2)} \$',
                  style: TextStyle(
                    color: couleurCompte,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return items;
  }

  bool _estEnveloppeAffichable(Map<String, dynamic> env) {
    final solde = (env['solde'] as num?)?.toDouble() ?? 0.0;

    // Vérifier si l'enveloppe est dans la catégorie Dette
    if (typeSelectionne == TypeTransaction.depense) {
      for (final categorie in categoriesFirebase) {
        if ((categorie['nom'] as String).toLowerCase() == 'dette' ||
            (categorie['nom'] as String).toLowerCase() == 'dettes') {
          // Si on trouve l'enveloppe dans la catégorie Dette, on ne l'affiche pas
          if ((categorie['enveloppes'] as List).any(
            (e) => e['id'] == env['id'],
          )) {
            return false;
          }
          break; // On sort de la boucle dès qu'on a trouvé la catégorie Dette
        }
      }
    }

    if (typeSelectionne == TypeTransaction.depense &&
        compteSelectionne != null) {
      // Gestion multi-provenances
      if (env['provenances'] != null &&
          (env['provenances'] as List).isNotEmpty) {
        return (env['provenances'] as List).any(
              (prov) => prov['compte_id'] == compteSelectionne,
            ) ||
            solde == 0;
      }

      // Gestion ancienne provenance unique
      if (env['provenance_compte_id'] != null) {
        return env['provenance_compte_id'] == compteSelectionne || solde == 0;
      }

      // Sinon, ne pas afficher sauf si solde == 0
      return solde == 0;
    }

    // Sinon (revenu ou pas de compte sélectionné), tout afficher
    return true;
  }
}
