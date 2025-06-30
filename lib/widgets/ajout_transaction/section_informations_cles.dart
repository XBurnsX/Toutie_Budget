import 'package:flutter/material.dart';
import '../../models/transaction_model.dart';
import '../../controllers/ajout_transaction_controller.dart';
import 'champ_tiers.dart';
import 'champ_compte.dart';
import 'champ_enveloppe.dart';
import '../../themes/dropdown_theme_extension.dart';

class SectionInformationsCles extends StatelessWidget {
  final TypeMouvementFinancier typeMouvementSelectionne;
  final TextEditingController payeController;
  final List<String> listeTiersConnus;
  final Function(String) onTiersAjoute;
  final String? compteSelectionne;
  final List<dynamic> listeComptesAffichables;
  final Function(String?) onCompteChanged;
  final String? enveloppeSelectionnee;
  final List<Map<String, dynamic>> categoriesFirebase;
  final List<dynamic> comptesFirebase;
  final TypeTransaction typeSelectionne;
  final Function(String?) onEnveloppeChanged;
  final Color Function(Map<String, dynamic>) getCouleurCompteEnveloppe;
  final DateTime dateSelectionnee;
  final Function(DateTime) onDateChanged;
  final String? marqueurSelectionne;
  final Function(String?) onMarqueurChanged;
  final TextEditingController noteController;
  final Function(TypeMouvementFinancier) onTypeMouvementChanged;
  final AjoutTransactionController ajoutController;

  const SectionInformationsCles({
    super.key,
    required this.typeMouvementSelectionne,
    required this.payeController,
    required this.listeTiersConnus,
    required this.onTiersAjoute,
    required this.compteSelectionne,
    required this.listeComptesAffichables,
    required this.onCompteChanged,
    required this.enveloppeSelectionnee,
    required this.categoriesFirebase,
    required this.comptesFirebase,
    required this.typeSelectionne,
    required this.onEnveloppeChanged,
    required this.getCouleurCompteEnveloppe,
    required this.dateSelectionnee,
    required this.onDateChanged,
    required this.marqueurSelectionne,
    required this.onMarqueurChanged,
    required this.noteController,
    required this.onTypeMouvementChanged,
    required this.ajoutController,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor =
        Theme.of(context).cardTheme.color ??
        (Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[850]!
            : Colors.white);
    final cardShape =
        Theme.of(context).cardTheme.shape ??
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0));

    return Card(
      color: cardColor,
      shape: cardShape,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Column(
          children: <Widget>[
            // Champ Type Mouvement
            _buildChampDetail(
              icone: Icons.compare_arrows,
              libelle: 'Transaction',
              widgetContenu: _buildDropdownTypeMouvement(context),
            ),
            _buildSeparateurDansCarte(),

            // Champ Tiers
            _buildChampDetail(
              icone: Icons.person_outline,
              libelle:
                  typeMouvementSelectionne ==
                          TypeMouvementFinancier.detteContractee ||
                      typeMouvementSelectionne ==
                          TypeMouvementFinancier.remboursementEffectue
                  ? 'Prêteur'
                  : 'Tiers',
              widgetContenu: ChampTiers(
                controller: payeController,
                typeMouvementSelectionne: typeMouvementSelectionne,
                listeTiersConnus: listeTiersConnus,
                onTiersAjoute: onTiersAjoute,
                ajoutController: ajoutController,
              ),
            ),
            _buildSeparateurDansCarte(),

            // Champ Compte
            _buildChampDetail(
              icone: Icons.account_balance_wallet_outlined,
              libelle:
                  typeMouvementSelectionne ==
                      TypeMouvementFinancier.detteContractee
                  ? 'Vers Compte Actif'
                  : 'Compte',
              widgetContenu: ChampCompte(
                compteSelectionne: compteSelectionne,
                listeComptesAffichables: listeComptesAffichables.cast(),
                typeMouvementSelectionne: typeMouvementSelectionne,
                onCompteChanged: onCompteChanged,
              ),
            ),
            _buildSeparateurDansCarte(),

            // Champ Date
            _buildChampDetail(
              icone: Icons.calendar_today_outlined,
              libelle: 'Date',
              widgetContenu: InkWell(
                onTap: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: dateSelectionnee,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2101),
                  );
                  if (picked != null && picked != dateSelectionnee) {
                    onDateChanged(picked);
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12.0,
                    horizontal: 10.0,
                  ),
                  child: Text(
                    "${dateSelectionnee.toLocal()}".split(' ')[0],
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
            ),
            _buildSeparateurDansCarte(),

            // Champ Enveloppe (conditionnel - seulement pour les dépenses)
            if (typeMouvementSelectionne ==
                TypeMouvementFinancier.depenseNormale) ...[
              _buildChampDetail(
                icone: Icons.label_outline,
                libelle: 'Enveloppe',
                widgetContenu: ChampEnveloppe(
                  enveloppeSelectionnee: enveloppeSelectionnee,
                  categoriesFirebase: categoriesFirebase,
                  comptesFirebase: comptesFirebase.cast(),
                  typeSelectionne: typeSelectionne,
                  typeMouvementSelectionne: typeMouvementSelectionne,
                  compteSelectionne: compteSelectionne,
                  onEnveloppeChanged: onEnveloppeChanged,
                  getCouleurCompteEnveloppe: getCouleurCompteEnveloppe,
                ),
              ),
              _buildSeparateurDansCarte(),
            ],

            // Champ Marqueur
            _buildChampDetail(
              icone: Icons.flag_outlined,
              libelle: 'Marqueur',
              widgetContenu: _buildDropdownMarqueur(context),
            ),
            _buildSeparateurDansCarte(),

            // Champ Note
            _buildChampDetail(
              icone: Icons.notes_outlined,
              libelle: 'Note',
              widgetContenu: TextField(
                controller: noteController,
                decoration: const InputDecoration(
                  hintText: 'Optionnel',
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    vertical: 10.0,
                    horizontal: 10.0,
                  ),
                ),
                textCapitalization: TextCapitalization.sentences,
                maxLines: null,
              ),
              alignementVerticalIcone: CrossAxisAlignment.start,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownTypeMouvement(BuildContext context) {
    // Couleur automatique du thème pour les dropdowns
    final dropdownColor = Theme.of(context).dropdownColor;

    return DropdownButtonFormField<TypeMouvementFinancier>(
      value: typeMouvementSelectionne,
      items: TypeMouvementFinancier.values
          .where((type) => type != TypeMouvementFinancier.ajustement)
          .map((TypeMouvementFinancier type) {
            return DropdownMenuItem<TypeMouvementFinancier>(
              value: type,
              child: Text(
                _libellePourTypeMouvement(type),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            );
          })
          .toList(),
      onChanged: (TypeMouvementFinancier? newValue) {
        if (newValue != null) {
          onTypeMouvementChanged(newValue);
        }
      },
      decoration: const InputDecoration(
        hintText: 'Type de mouvement',
        border: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 10.0),
      ),
      isExpanded: true,
      dropdownColor: dropdownColor,
    );
  }

  Widget _buildDropdownMarqueur(BuildContext context) {
    // Couleur automatique du thème pour les dropdowns
    final dropdownColor = Theme.of(context).dropdownColor;

    final listeMarqueurs = ['Aucun', 'Important', 'À vérifier'];

    return DropdownButtonFormField<String>(
      value: marqueurSelectionne ?? listeMarqueurs.first,
      items: listeMarqueurs.map((String marqueur) {
        return DropdownMenuItem<String>(value: marqueur, child: Text(marqueur));
      }).toList(),
      onChanged: onMarqueurChanged,
      decoration: const InputDecoration(
        border: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 10.0),
      ),
      isExpanded: true,
      dropdownColor: dropdownColor,
    );
  }

  Widget _buildChampDetail({
    required IconData icone,
    required String libelle,
    required Widget widgetContenu,
    CrossAxisAlignment alignementVerticalIcone = CrossAxisAlignment.center,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: alignementVerticalIcone,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 16.0, top: 2.0),
            child: Icon(icone, color: Colors.grey[600]),
          ),
          Expanded(
            flex: 2,
            child: Text(
              libelle,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ),
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerRight,
              child: widgetContenu,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeparateurDansCarte() {
    return Divider(
      height: 1,
      color: Colors.grey.withAlpha((0.3 * 255).toInt()),
    );
  }

  String _libellePourTypeMouvement(TypeMouvementFinancier type) {
    switch (type) {
      case TypeMouvementFinancier.depenseNormale:
        return 'Dépense';
      case TypeMouvementFinancier.revenuNormal:
        return 'Revenu';
      case TypeMouvementFinancier.pretAccorde:
        return 'Prêt accordé (Sortie)';
      case TypeMouvementFinancier.remboursementRecu:
        return 'Remboursement reçu (Entrée)';
      case TypeMouvementFinancier.detteContractee:
        return 'Dette contractée (Entrée)';
      case TypeMouvementFinancier.remboursementEffectue:
        return 'Remboursement effectué (Sortie)';
      default:
        return type.name;
    }
  }
}
