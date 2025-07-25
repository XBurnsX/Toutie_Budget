import 'package:flutter/material.dart';
import '../../models/transaction_model.dart';
import '../../controllers/ajout_transaction_controller.dart';
import 'champ_tiers.dart';
import 'champ_remboursement.dart';
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
  final List<dynamic> comptes;
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
    required this.comptes,
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
    final cardColor = Theme.of(context).cardTheme.color ??
        (Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[850]!
            : Colors.white);
    final cardShape = Theme.of(context).cardTheme.shape ??
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0));

    // Filtrer les comptes affichables pour le champ "Compte"
    // On ne veut pas pouvoir sélectionner une carte de crédit comme source
    // de paiement pour un remboursement.
    final List<dynamic> comptesSourcesFiltres;
    if (typeMouvementSelectionne ==
        TypeMouvementFinancier.remboursementEffectue) {
      comptesSourcesFiltres = listeComptesAffichables
          .where((c) => c.type != 'Carte de crédit')
          .toList();
    } else {
      comptesSourcesFiltres = listeComptesAffichables;
    }

    return Card(
      color: cardColor,
      shape: cardShape,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Column(
          children: <Widget>[
            // Champ Type Mouvement
            _buildChampDetail(
              context,
              icone: Icons.compare_arrows,
              libelle: 'Transaction',
              widgetContenu: _buildDropdownTypeMouvement(context),
            ),
            _buildSeparateurDansCarte(),

            // Champ Tiers
            _buildChampDetail(
              context,
              icone: Icons.person_outline,
              libelle: typeMouvementSelectionne ==
                          TypeMouvementFinancier.detteContractee ||
                      typeMouvementSelectionne ==
                          TypeMouvementFinancier.remboursementEffectue
                  ? 'Prêteur'
                  : 'Tiers',
              widgetContenu: typeMouvementSelectionne ==
                      TypeMouvementFinancier.remboursementEffectue
                  ? ChampRemboursement(
                      controller: payeController,
                      ajoutController: ajoutController,
                    )
                  : ChampTiers(
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
              context,
              icone: Icons.account_balance_wallet_outlined,
              libelle: typeMouvementSelectionne ==
                      TypeMouvementFinancier.detteContractee
                  ? 'Vers Compte Actif'
                  : 'Compte',
              widgetContenu: ChampCompte(
                compteSelectionne: compteSelectionne,
                listeComptesAffichables: comptesSourcesFiltres.cast(),
                typeMouvementSelectionne: typeMouvementSelectionne,
                onCompteChanged: onCompteChanged,
              ),
            ),
            _buildSeparateurDansCarte(),

            // Champ Date
            _buildChampDetail(
              context,
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
                context,
                icone: Icons.label_outline,
                libelle: 'Enveloppe',
                widgetContenu: ChampEnveloppe(
                  enveloppeSelectionnee: enveloppeSelectionnee,
                  categoriesFirebase: categoriesFirebase,
                  comptes: comptes
                      .map((c) => {
                            'id': c.id,
                            'nom': c.nom,
                            'couleur': c.couleur,
                            'collection': '', // Compte n'a pas de collection
                          })
                      .toList(),
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
              context,
              icone: Icons.flag_outlined,
              libelle: 'Marqueur',
              widgetContenu: _buildDropdownMarqueur(context),
            ),
            _buildSeparateurDansCarte(),

            // Champ Note
            _buildChampDetail(
              context,
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
                textAlign: TextAlign.left,
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
            textAlign: TextAlign.left,
          ),
        );
      }).toList(),
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
      alignment: Alignment.centerLeft,
    );
  }

  Widget _buildDropdownMarqueur(BuildContext context) {
    // Couleur automatique du thème pour les dropdowns
    final dropdownColor = Theme.of(context).dropdownColor;

    final listeMarqueurs = ['Aucun', 'Important', 'À vérifier'];

    return DropdownButtonFormField<String>(
      value: marqueurSelectionne ?? listeMarqueurs.first,
      items: listeMarqueurs.map((String marqueur) {
        return DropdownMenuItem<String>(
          value: marqueur,
          child: Text(
            marqueur,
            textAlign: TextAlign.left,
          ),
        );
      }).toList(),
      onChanged: onMarqueurChanged,
      decoration: const InputDecoration(
        border: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 10.0),
      ),
      isExpanded: true,
      dropdownColor: dropdownColor,
      alignment: Alignment.centerLeft,
    );
  }

  Widget _buildChampDetail(
    BuildContext ctx, {
    required IconData icone,
    required String libelle,
    required Widget widgetContenu,
    CrossAxisAlignment alignementVerticalIcone = CrossAxisAlignment.center,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: alignementVerticalIcone,
            children: [
              Icon(icone, color: Theme.of(ctx).colorScheme.primary),
              const SizedBox(width: 12),
              Text(
                libelle,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(ctx).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: widgetContenu,
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
