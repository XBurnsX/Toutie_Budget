import 'package:flutter/material.dart';
import '../../models/compte.dart';
import '../../models/transaction_model.dart';
import '../../themes/dropdown_theme_extension.dart';
import '../../services/color_service.dart';
import '../../services/allocation_service.dart';
import '../../services/pocketbase_service.dart';

class ChampEnveloppe extends StatefulWidget {
  final String? enveloppeSelectionnee;
  final List<Map<String, dynamic>> categoriesFirebase;
  final List<Map<String, dynamic>> comptes;
  final TypeTransaction typeSelectionne;
  final TypeMouvementFinancier typeMouvementSelectionne;
  final String? compteSelectionne;
  final Function(String?) onEnveloppeChanged;
  final Color Function(Map<String, dynamic>) getCouleurCompteEnveloppe;

  const ChampEnveloppe({
    super.key,
    required this.enveloppeSelectionnee,
    required this.categoriesFirebase,
    required this.comptes,
    required this.typeSelectionne,
    required this.typeMouvementSelectionne,
    required this.compteSelectionne,
    required this.onEnveloppeChanged,
    required this.getCouleurCompteEnveloppe,
  });

  @override
  State<ChampEnveloppe> createState() => _ChampEnveloppeState();
}

class _ChampEnveloppeState extends State<ChampEnveloppe> {
  static List<Map<String, dynamic>> _enveloppesCacheGlobal = [];
  static bool _cacheInitialise = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _chargerEnveloppes();
  }

  Future<void> _chargerEnveloppes() async {
    // Utiliser le cache global si déjà initialisé
    if (_cacheInitialise && _enveloppesCacheGlobal.isNotEmpty) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final enveloppes = await _getEnveloppesCompletes();
      if (mounted) {
        setState(() {
          _enveloppesCacheGlobal = enveloppes;
          _cacheInitialise = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Couleur automatique du thème pour les dropdowns
    final dropdownColor = Theme.of(context).dropdownColor;

    if (_isLoading) {
      return DropdownButtonFormField<String>(
        value: null,
        items: const [],
        onChanged: null,
        decoration: InputDecoration(
          hintText: 'Chargement...',
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 10.0,
            horizontal: 12.0,
          ),
        ),
        isExpanded: true,
        alignment: Alignment.centerLeft,
        dropdownColor: dropdownColor,
      );
    }

    // Construire la liste des items une seule fois
    final items = _buildEnveloppeItems(context, _enveloppesCacheGlobal);

    // S'assurer que la valeur sélectionnée existe dans la liste ; sinon la remettre à null
    String? valeurActuelle = widget.enveloppeSelectionnee;
    final occurences = items.where((item) =>
        item.value == valeurActuelle &&
        item.value != null &&
        !item.value!.startsWith('cat_'));
    if (valeurActuelle != null && occurences.length != 1) {
      valeurActuelle = null;
    }

    return DropdownButtonFormField<String>(
      value: valeurActuelle,
      items: items,
      onChanged: (String? newValue) {
        // Ignorer les en-têtes de catégorie
        if (newValue != null && newValue.startsWith('cat_')) {
          return;
        }
        widget.onEnveloppeChanged(newValue);
      },
      selectedItemBuilder: (context) {
        return items.map((item) {
          if (item.value == null) {
            return const Text('Aucune');
          }
          if (item.value!.startsWith('cat_')) {
            return const SizedBox.shrink(); // Ignorer les en-têtes
          }
          return item.child ?? const SizedBox.shrink();
        }).toList();
      },
      decoration: InputDecoration(
        hintText: 'Optionnel',
        border: InputBorder.none,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 10.0,
          horizontal: 12.0,
        ),
      ),
      isExpanded: true,
      alignment: Alignment.centerLeft,
      dropdownColor: dropdownColor,
    );
  }

  Future<List<Map<String, dynamic>>> _getEnveloppesCompletes() async {
    final List<Map<String, dynamic>> toutesEnveloppes = [];

    // Récupérer toutes les catégories
    final categories = await PocketBaseService.lireCategories().first;

    // Pour chaque catégorie, récupérer ses enveloppes complètes
    for (final categorie in categories) {
      final enveloppesData =
          await PocketBaseService.lireEnveloppesParCategorie(categorie.id);
      for (final enveloppeData in enveloppesData) {
        // Ajouter les informations de la catégorie à l'enveloppe
        enveloppeData['categorie_nom'] = categorie.nom;
        toutesEnveloppes.add(enveloppeData);
      }
    }

    return toutesEnveloppes;
  }

  List<DropdownMenuItem<String>> _buildEnveloppeItems(
      BuildContext context, List<Map<String, dynamic>> enveloppesCompletes) {
    final items = <DropdownMenuItem<String>>[];

    // Option "Aucune"
    items.add(
      const DropdownMenuItem<String>(
        value: null,
        child: Text("Aucune", style: TextStyle(fontStyle: FontStyle.italic)),
      ),
    );

    // Prêts à placer dynamiques (seulement pour les revenus)
    if (widget.typeSelectionne != TypeTransaction.depense &&
        widget.compteSelectionne != null) {
      final comptesAvecPret = widget.comptes.where(
        (c) => c['pretAPlacer'] > 0 && c['id'] == widget.compteSelectionne,
      );

      for (final compte in comptesAvecPret) {
        items.add(
          DropdownMenuItem<String>(
            value: 'pret_${compte['id']}',
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '💰 Prêt à placer (${compte['nom']})',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Color(compte['couleur']),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${compte['pretAPlacer'].toStringAsFixed(2)}\$',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    // Grouper les enveloppes par catégorie
    final Map<String, List<Map<String, dynamic>>> enveloppesParCategorie = {};

    for (final env in enveloppesCompletes) {
      final categorieNom = env['categorie_nom'] as String? ?? 'Sans catégorie';
      if (!enveloppesParCategorie.containsKey(categorieNom)) {
        enveloppesParCategorie[categorieNom] = [];
      }
      enveloppesParCategorie[categorieNom]!.add(env);
    }

    // Ajouter les enveloppes groupées par catégorie
    for (final entry in enveloppesParCategorie.entries) {
      final categorieNom = entry.key;
      final enveloppesCategorie = entry.value;

      // En-tête de catégorie (avec une valeur unique qui ne sera jamais sélectionnée)
      items.add(
        DropdownMenuItem<String>(
          value: 'cat_$categorieNom', // Préfixe unique
          enabled: false,
          child: Text(
            '📁 $categorieNom',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
              fontSize: 16,
            ),
          ),
        ),
      );

      // Enveloppes de cette catégorie
      for (final env in enveloppesCategorie) {
        final solde = (env['solde_enveloppe'] as num?)?.toDouble() ??
            (env['solde'] as num?)?.toDouble() ??
            0.0;

        // Utiliser ColorService pour la couleur de l'enveloppe
        items.add(
          DropdownMenuItem<String>(
            value: env['id'],
            child: FutureBuilder<Color>(
              future: ColorService.getCouleurCompteSourceEnveloppeAsync(
                enveloppeId: env['id'],
                comptes: widget.comptes
                    .map((c) => {
                          'id': c['id'],
                          'nom': c['nom'],
                          'couleur': c['couleur'],
                          'collection': c.containsKey('collection')
                              ? c['collection']
                              : '',
                        })
                    .toList(),
                solde: solde,
                mois: DateTime.now(),
              ),
              builder: (context, couleurSnapshot) {
                final couleurCompte = couleurSnapshot.data ?? Colors.grey;
                return Row(
                  children: [
                    Expanded(
                      child: Text(
                        '  ${env['nom']}', // Indentation pour montrer que c'est sous la catégorie
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: couleurCompte,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${solde.toStringAsFixed(2)}\$',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      }
    }

    return items;
  }

  bool _estEnveloppeAffichable(Map<String, dynamic> env) {
    final solde = (env['solde'] as num?)?.toDouble() ?? 0.0;

    // Vérifier si l'enveloppe est dans la catégorie Dette
    if (widget.typeSelectionne == TypeTransaction.depense) {
      for (final categorie in widget.categoriesFirebase) {
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

    if (widget.typeSelectionne == TypeTransaction.depense &&
        widget.compteSelectionne != null) {
      // Gestion multi-provenances
      if (env['provenances'] != null &&
          (env['provenances'] as List).isNotEmpty) {
        return (env['provenances'] as List).any(
              (prov) => prov['compte_id'] == widget.compteSelectionne,
            ) ||
            solde <= 0;
      }

      // Gestion ancienne provenance unique
      if (env['provenance_compte_id'] != null) {
        return env['provenance_compte_id'] == widget.compteSelectionne ||
            solde <= 0;
      }

      // Sinon, ne pas afficher sauf si solde == 0
      return solde <= 0;
    }

    // Sinon (revenu ou pas de compte sélectionné), tout afficher
    return true;
  }
}
