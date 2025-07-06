import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'pie_chart_with_legend.dart';
import 'package:toutie_budget/widgets/assignation_bottom_sheet.dart';
import 'package:toutie_budget/services/argent_service.dart';

/// Widget pour afficher dynamiquement les catégories et enveloppes
class ListeCategoriesEnveloppes extends StatefulWidget {
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> comptes;
  final bool editionMode;
  final void Function(String catId, String envId)? onRename;
  final void Function(String catId, String envId)? onDelete;
  final String? selectedMonthKey;

  const ListeCategoriesEnveloppes({
    super.key,
    required this.categories,
    required this.comptes,
    this.editionMode = false,
    this.onRename,
    this.onDelete,
    this.selectedMonthKey,
  });

  @override
  State<ListeCategoriesEnveloppes> createState() =>
      _ListeCategoriesEnveloppesState();
}

class _ListeCategoriesEnveloppesState extends State<ListeCategoriesEnveloppes> {
  static const int pageSize = 20;
  List<Map<String, dynamic>> _displayedCategories = [];
  int _currentPage = 0;
  bool _isLoading = false;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();
  int enveloppesAffichees = 20;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ListeCategoriesEnveloppes oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.categories != widget.categories) {
      _loadInitialData();
    }
  }

  void _loadInitialData() {
    setState(() {
      _currentPage = 0;
      _hasMore = true;
      _displayedCategories = [];
    });
    _loadNextPage();
  }

  void _loadNextPage() {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
    });

    // Simuler un délai pour éviter les rebuilds trop rapides
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;

      final sortedCategories = _getSortedCategories();
      final startIndex = _currentPage * pageSize;
      final endIndex = startIndex + pageSize;

      if (startIndex >= sortedCategories.length) {
        setState(() {
          _hasMore = false;
          _isLoading = false;
        });
        return;
      }

      final newCategories = sortedCategories.sublist(
          startIndex,
          endIndex > sortedCategories.length
              ? sortedCategories.length
              : endIndex);

      setState(() {
        _displayedCategories.addAll(newCategories);
        _currentPage++;
        _hasMore = endIndex < sortedCategories.length;
        _isLoading = false;
      });
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _hasMore) {
      _loadNextPage();
    }
  }

  void _showViderEnveloppeMenu(
      BuildContext context, Map<String, dynamic> enveloppe) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Vider l\'enveloppe "${enveloppe['nom']}" ?',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Cette action va vider l\'enveloppe et retourner ${(enveloppe['solde'] ?? 0.0).toStringAsFixed(2)} \$ dans le prêt à placer du compte d\'origine.',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[700],
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Annuler',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await _viderEnveloppe(enveloppe);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Vider',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _viderEnveloppe(Map<String, dynamic> enveloppe) async {
    try {
      await ArgentService().viderEnveloppe(enveloppeId: enveloppe['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Enveloppe "${enveloppe['nom']}" vidée avec succès',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('DEBUG: Erreur lors du vidage de l\'enveloppe: $e');
      if (mounted) {
        String messageErreur = 'Erreur lors du vidage';

        if (e.toString().contains('Enveloppe non trouvée')) {
          messageErreur = 'Enveloppe non trouvée dans la base de données';
        } else if (e.toString().contains('déjà vide')) {
          messageErreur = 'L\'enveloppe est déjà vide';
        } else if (e.toString().contains('Aucune provenance trouvée')) {
          messageErreur = 'Aucune provenance trouvée pour cette enveloppe';
        } else if (e.toString().contains('Catégorie non trouvée')) {
          messageErreur = 'Catégorie non trouvée dans la base de données';
        } else if (e.toString().contains('Index d\'enveloppe invalide')) {
          messageErreur = 'Erreur interne : index d\'enveloppe invalide';
        } else {
          messageErreur = 'Erreur lors du vidage : ${e.toString()}';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              messageErreur,
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> _getSortedCategories() {
    final sortedCategories = List<Map<String, dynamic>>.from(widget.categories);
    sortedCategories.sort((a, b) {
      final aNom = (a['nom'] as String).toLowerCase();
      final bNom = (b['nom'] as String).toLowerCase();
      if (aNom == 'dette' || aNom == 'dettes') return -1;
      if (bNom == 'dette' || bNom == 'dettes') return 1;
      final aOrdre = (a['ordre'] as int?) ?? 999999;
      final bOrdre = (b['ordre'] as int?) ?? 999999;
      return aOrdre.compareTo(bOrdre);
    });
    return sortedCategories;
  }

  Color _getEtatColor(double solde, double objectif) {
    if (solde < 0) return Colors.red;
    if (objectif == 0) return Colors.grey;
    if (solde >= objectif) return Colors.green;
    if (solde >= objectif * 0.7) return Colors.yellow;
    return Colors.orange;
  }

  void chargerPlusEnveloppes() {
    setState(() {
      enveloppesAffichees += 20;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.categories.isEmpty) {
      return const SizedBox.shrink();
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _displayedCategories.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _displayedCategories.length) {
          if (_isLoading) {
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return const SizedBox.shrink();
        }

        final categorie = _displayedCategories[index];
        // Filtrer les enveloppes archivées
        final enveloppes =
            (categorie['enveloppes'] as List<Map<String, dynamic>>)
                .where((env) => env['archivee'] != true)
                .toList();

        // Vérifier si la catégorie a des enveloppes négatives
        final aEnveloppesNegatives = enveloppes.any(
          (env) => (env['solde'] ?? 0.0).toDouble() < 0,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Icône d'avertissement pour les catégories avec enveloppes négatives
                if (aEnveloppesNegatives) ...[
                  Icon(Icons.warning, color: Colors.red[700], size: 20),
                  const SizedBox(width: 8),
                ],
                Text(
                  categorie['nom'],
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: aEnveloppesNegatives
                        ? Colors.red[400]
                        : Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            ...enveloppes.take(enveloppesAffichees).map((enveloppe) {
              // --- Logique d'affichage de l'historique ---
              Map<String, dynamic> historique = enveloppe['historique'] != null
                  ? Map<String, dynamic>.from(enveloppe['historique'])
                  : {};
              Map<String, dynamic>? histoMois =
                  (widget.selectedMonthKey != null &&
                          historique[widget.selectedMonthKey] != null)
                      ? Map<String, dynamic>.from(
                          historique[widget.selectedMonthKey])
                      : null;

              final now = DateTime.now();
              final currentMonthKey =
                  "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}";
              final selectedDate = widget.selectedMonthKey != null
                  ? DateFormat('yyyy-MM').parse(widget.selectedMonthKey!)
                  : now;
              final isFutureMonth = selectedDate.year > now.year ||
                  (selectedDate.year == now.year &&
                      selectedDate.month > now.month);

              double solde;
              double objectif;
              double depense;

              if (widget.selectedMonthKey == null ||
                  widget.selectedMonthKey == currentMonthKey) {
                // Mois courant -> valeurs globales
                solde = (enveloppe['solde'] ?? 0.0).toDouble();
                objectif = (enveloppe['objectif'] ?? 0.0).toDouble();
                depense = (enveloppe['depense'] ?? 0.0).toDouble();
              } else if (histoMois != null) {
                // Mois passé avec historique -> valeurs de l'historique
                solde = (histoMois['solde'] ?? 0.0).toDouble();
                objectif = (histoMois['objectif'] ?? 0.0).toDouble();
                depense = (histoMois['depense'] ?? 0.0).toDouble();
              } else if (isFutureMonth) {
                // Mois futur -> valeurs projetées
                solde = (enveloppe['solde'] ?? 0.0)
                    .toDouble(); // Report du solde actuel
                objectif = (enveloppe['objectif'] ?? 0.0)
                    .toDouble(); // Report de l'objectif actuel
                depense = 0.0; // Dépenses futures sont à 0
              } else {
                // Mois passé sans historique -> 0
                solde = 0.0;
                objectif = 0.0;
                depense = 0.0;
              }

              // Détection si l'enveloppe est négative
              final bool estNegative = solde < 0;

              final bool estDepenseAtteint =
                  (depense >= objectif && objectif > 0);
              final double progression = (objectif > 0)
                  ? (estDepenseAtteint
                      ? 1.0
                      : (solde / objectif).clamp(0.0, 1.0))
                  : 0.0;
              final Color etatColor = _getEtatColor(solde, objectif);
              // log(
              //   '[DEBUG ENVELOPPE] mois=${selectedMonthKey ?? "courant"} | nom=${enveloppe['nom']} | solde=$solde | objectif=$objectif | depense=$depense',
              // );
              if (objectif == 0) {
                // Cas : aucun objectif attribué
                final String compteId = enveloppe['provenance_compte_id'] ?? '';
                Color bulleColor;
                // log(
                //   '[BULLE-DEBUG] enveloppe=${enveloppe.toString()} | compteId="$compteId"',
                // );
                if (solde == 0) {
                  bulleColor = const Color(
                    0xFF44474A,
                  ); // gris foncé si aucun argent assigné
                } else if (estNegative) {
                  bulleColor = Colors.red; // Rouge pour les montants négatifs
                } else if (compteId.isNotEmpty) {
                  final compte = widget.comptes.firstWhere(
                    (c) => c['id'].toString() == compteId.toString(),
                    orElse: () => <String, Object>{},
                  );
                  // log(
                  //   '[BULLE] compteId=$compteId | comptes=${comptes.map((c) => c['id']).toList()} | compteTrouve=${compte['id']?.toString() ?? 'null'} | couleur=${compte['couleur']?.toString() ?? 'null'}',
                  // );
                  if (compte['couleur'] != null && compte['couleur'] is int) {
                    try {
                      bulleColor = Color(compte['couleur'] as int);
                    } catch (_) {
                      bulleColor = Colors.amber;
                    }
                  } else {
                    bulleColor = Colors.amber;
                  }
                } else {
                  bulleColor = Colors.amber;
                }
                // Couleur de la barre latéralerd automa
                Color barreColor;
                if (solde < 0) {
                  barreColor = Colors.red;
                } else if (solde == 0) {
                  barreColor = const Color(0xFF44474A);
                } else {
                  barreColor = Colors.amber;
                }
                final cardWidget = Card(
                  color: estNegative
                      ? Theme.of(
                          context,
                        ).colorScheme.error.withValues(alpha: 0.15)
                      : const Color(0xFF232526),
                  child: Stack(
                    children: [
                      Positioned(
                        right: 0,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: 8,
                          decoration: BoxDecoration(
                            color: barreColor,
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(12),
                              bottomRight: Radius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 12,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Icône d'avertissement pour les enveloppes négatives
                            if (estNegative) ...[
                              Icon(
                                Icons.warning,
                                color: Colors.red[700],
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              child: Text(
                                enveloppe['nom'],
                                style: TextStyle(
                                  color: estNegative
                                      ? Colors.red[800]
                                      : Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            if (widget.editionMode) ...[
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit,
                                      color: Colors.white70,
                                      size: 20,
                                    ),
                                    tooltip: 'Renommer',
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 2,
                                    ),
                                    constraints: BoxConstraints(),
                                    onPressed: () => widget.onRename?.call(
                                      categorie['id'],
                                      enveloppe['id'],
                                    ),
                                  ),
                                  SizedBox(width: 2),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.close,
                                      color: Colors.redAccent,
                                      size: 20,
                                    ),
                                    tooltip: 'Supprimer',
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 2,
                                    ),
                                    constraints: BoxConstraints(),
                                    onPressed: () => widget.onDelete?.call(
                                      categorie['id'],
                                      enveloppe['id'],
                                    ),
                                  ),
                                ],
                              ),
                            ] else ...[
                              // Remplacement de la bulle par le camembert avec légende
                              Builder(
                                builder: (context) {
                                  final List<dynamic> provenances =
                                      enveloppe['provenances'] ?? [];
                                  if (provenances.isEmpty) {
                                    // Si pas de provenance, bulle classique
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: bulleColor,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '${solde.toStringAsFixed(2)} \$',
                                        style: TextStyle(
                                          color: estNegative
                                              ? Colors.white
                                              : (solde == 0
                                                  ? Colors.white70
                                                  : Colors.black),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    );
                                  }
                                  // Construction des contributions pour le camembert
                                  final List<Contribution> contributions =
                                      provenances.map<Contribution>((prov) {
                                    final compte = widget.comptes.firstWhere(
                                      (c) =>
                                          c['id'].toString() ==
                                          prov['compte_id'].toString(),
                                      orElse: () => <String, Object>{},
                                    );
                                    final couleur =
                                        (compte['couleur'] != null &&
                                                compte['couleur'] is int)
                                            ? Color(compte['couleur'] as int)
                                            : Colors.amber;
                                    final nom = compte['nom'] ?? 'Compte';
                                    return Contribution(
                                      compte: nom.toString(),
                                      couleur: couleur,
                                      montant: (prov['montant'] as num?)
                                              ?.toDouble() ??
                                          0.0,
                                    );
                                  }).toList();
                                  return PieChartWithLegend(
                                    contributions: contributions,
                                    size: 40,
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );

                return widget.editionMode
                    ? cardWidget
                    : InkWell(
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            builder: (_) => AssignationBottomSheet(
                              enveloppe: enveloppe,
                              comptes: widget.comptes,
                            ),
                          );
                        },
                        onLongPress: () {
                          if (solde > 0) {
                            _showViderEnveloppeMenu(context, enveloppe);
                          }
                        },
                        child: cardWidget,
                      );
              }
              // Pour les enveloppes avec objectif, barre latérale à droite
              Color barreColor;
              if (solde < 0) {
                barreColor = Colors.red;
              } else if (solde == 0) {
                barreColor = const Color(0xFF44474A);
              } else if (solde >= objectif) {
                barreColor = Colors.green;
              } else {
                barreColor = Colors.amber;
              }

              // Couleur de la bulle basée sur la provenance (même logique que les enveloppes sans objectif)
              Color bulleColor;
              final String compteId = enveloppe['provenance_compte_id'] ?? '';
              // log(
              //   '[BULLE-DEBUG] enveloppe=${enveloppe.toString()} | compteId="$compteId"',
              // );
              if (solde == 0) {
                bulleColor = const Color(
                  0xFF44474A,
                ); // gris foncé si aucun argent assigné
              } else if (estNegative) {
                bulleColor = Colors.red; // Rouge pour les montants négatifs
              } else if (compteId.isNotEmpty) {
                final compte = widget.comptes.firstWhere(
                  (c) => c['id'].toString() == compteId.toString(),
                  orElse: () => <String, Object>{},
                );
                // log(
                //   '[BULLE] compteId=$compteId | comptes=${comptes.map((c) => c['id']).toList()} | compteTrouve=${compte['id']?.toString() ?? 'null'} | couleur=${compte['couleur']?.toString() ?? 'null'}',
                // );
                if (compte['couleur'] != null && compte['couleur'] is int) {
                  try {
                    bulleColor = Color(compte['couleur'] as int);
                  } catch (_) {
                    bulleColor = Colors.amber;
                  }
                } else {
                  bulleColor = Colors.amber;
                }
              } else {
                bulleColor = Colors.amber;
              }
              final cardWidget = Card(
                color: estNegative
                    ? Theme.of(
                        context,
                      ).colorScheme.error.withValues(alpha: 0.15)
                    : const Color(0xFF232526),
                child: Stack(
                  children: [
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 8,
                        decoration: BoxDecoration(
                          color: barreColor,
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(12),
                            bottomRight: Radius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Icône d'avertissement pour les enveloppes négatives
                              if (estNegative) ...[
                                Icon(
                                  Icons.warning,
                                  color: Colors.red[700],
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                              ],
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      enveloppe['nom'],
                                      style: TextStyle(
                                        color: estNegative
                                            ? Colors.red[800]
                                            : Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    if ([
                                      "mensuel",
                                      "datefixe",
                                      "date",
                                      "bihebdo",
                                      "annuel"
                                    ].any(
                                      (f) => (enveloppe['frequence_objectif']
                                                  ?.toString() ??
                                              '')
                                          .toLowerCase()
                                          .contains(f),
                                    ))
                                      Builder(
                                        builder: (_) {
                                          String freq =
                                              (enveloppe['frequence_objectif']
                                                          ?.toString() ??
                                                      '')
                                                  .toLowerCase();
                                          if (freq.contains('mensuel')) {
                                            return Text(
                                              '${objectif.toStringAsFixed(2)}\u00A0\$${(enveloppe['objectifJour'] ?? enveloppe['objectif_jour']) != null ? " d'ici le ${enveloppe['objectifJour'] ?? enveloppe['objectif_jour']}" : ''}',
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 13,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            );
                                          } else if (freq.contains('bihebdo')) {
                                            // Affichage pour la fréquence toutes les 2 semaines
                                            double montantObjectif =
                                                (enveloppe['objectif'] as num?)
                                                        ?.toDouble() ??
                                                    0.0;

                                            DateTime lastDate;
                                            if (enveloppe[
                                                    'date_dernier_ajout'] !=
                                                null) {
                                              try {
                                                lastDate = DateTime.parse(
                                                    enveloppe[
                                                        'date_dernier_ajout']);
                                              } catch (_) {
                                                lastDate = DateTime.now();
                                              }
                                            } else {
                                              lastDate = DateTime.now();
                                            }

                                            // Prochaine échéance = dernier ajout + 14 jours
                                            DateTime prochaineDate = lastDate
                                                .add(const Duration(days: 14));

                                            // S'assurer qu'on tombe bien sur le bon jour de la semaine si objectifJour est défini
                                            int? objectifJour = enveloppe[
                                                'objectif_jour']; // 1=lundi … 7=dim
                                            if (objectifJour != null) {
                                              // Avancer jusqu'au prochain jour de la semaine correspondant
                                              while (prochaineDate.weekday !=
                                                  objectifJour) {
                                                prochaineDate = prochaineDate
                                                    .add(const Duration(
                                                        days: 1));
                                              }
                                            }

                                            String dateStr =
                                                '${prochaineDate.day.toString().padLeft(2, '0')}/${prochaineDate.month.toString().padLeft(2, '0')}';

                                            return Text(
                                              '${montantObjectif.toStringAsFixed(2)}\u00A0\$ d\'ici le $dateStr',
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 13,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            );
                                          } else if (freq.contains('date')) {
                                            double montantNecessaire = 0;
                                            if (enveloppe['objectif'] != null &&
                                                enveloppe['objectif_date'] !=
                                                    null) {
                                              try {
                                                DateTime dateCible =
                                                    DateTime.parse(
                                                  enveloppe['objectif_date'],
                                                );

                                                // Utiliser le mois sélectionné pour le calcul du statut
                                                DateTime dateReference =
                                                    widget.selectedMonthKey !=
                                                            null
                                                        ? DateFormat(
                                                            'yyyy-MM',
                                                          ).parse(widget
                                                            .selectedMonthKey!)
                                                        : DateTime.now();

                                                // CORRECTION : Utiliser une date de création fixe au lieu du mois consulté
                                                DateTime dateCreationObjectif;
                                                if (enveloppe[
                                                        'date_creation_objectif'] !=
                                                    null) {
                                                  // Si on a la vraie date de création de l'objectif
                                                  dateCreationObjectif =
                                                      DateTime.parse(
                                                    enveloppe[
                                                        'date_creation_objectif'],
                                                  );
                                                } else {
                                                  // Fallback : utiliser juin 2025 comme exemple (à ajuster selon vos données)
                                                  dateCreationObjectif =
                                                      DateTime(2025, 6, 1);
                                                }

                                                // Calculer le nombre total de mois depuis la VRAIE création jusqu'à la date cible
                                                int moisTotal = (dateCible
                                                                .year -
                                                            dateCreationObjectif
                                                                .year) *
                                                        12 +
                                                    (dateCible.month -
                                                        dateCreationObjectif
                                                            .month) +
                                                    1;

                                                // Calculer le nombre de mois restants depuis le mois de référence
                                                int moisRestants = (dateCible
                                                                .year -
                                                            dateReference
                                                                .year) *
                                                        12 +
                                                    (dateCible.month -
                                                        dateReference.month) +
                                                    1;

                                                if (moisRestants < 1) {
                                                  moisRestants = 1;
                                                }

                                                // Le montant nécessaire chaque mois est fixe : objectif total / nombre total de mois
                                                double objectifTotal =
                                                    (enveloppe['objectif']
                                                                as num?)
                                                            ?.toDouble() ??
                                                        0.0;
                                                montantNecessaire = moisTotal >
                                                        0
                                                    ? objectifTotal / moisTotal
                                                    : 0;

                                                // Si on est en retard, calculer le rattrapage
                                                double soldeActuel =
                                                    solde; // Utiliser le solde du mois sélectionné

                                                // Pour les mois futurs, utiliser le solde actuel réel au lieu du solde projeté
                                                if (isFutureMonth) {
                                                  soldeActuel =
                                                      (enveloppe['solde'] ??
                                                              0.0)
                                                          .toDouble();
                                                }

                                                if (soldeActuel <
                                                    objectifTotal) {
                                                  if (moisRestants == 1) {
                                                    // Dernier mois : afficher simplement ce qui manque pour atteindre l'objectif
                                                    double manquant =
                                                        objectifTotal -
                                                            soldeActuel;
                                                    montantNecessaire =
                                                        manquant > 0
                                                            ? manquant
                                                            : 0;
                                                  } else {
                                                    // Autres mois : calculer ce qui manque réparti sur les mois restants
                                                    double manquant =
                                                        objectifTotal -
                                                            soldeActuel;
                                                    montantNecessaire =
                                                        manquant > 0
                                                            ? (manquant /
                                                                moisRestants)
                                                            : 0;
                                                  }
                                                } else {
                                                  // Objectif déjà atteint
                                                  montantNecessaire = 0;
                                                }
                                              } catch (_) {
                                                montantNecessaire = 0;
                                              }
                                            }
                                            return Text(
                                              'Nécessaire ce mois-ci : ${montantNecessaire > 0 ? '${montantNecessaire.toStringAsFixed(2)}\$' : '—'}',
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 13,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            );
                                          } else if (freq.contains('annuel')) {
                                            double montantObjectif =
                                                (enveloppe['objectif'] as num?)
                                                        ?.toDouble() ??
                                                    0.0;

                                            DateTime maintenant =
                                                DateTime.now();

                                            // Date cible stockée dans objectif_date (on ignore l'année)
                                            DateTime? cible;
                                            if (enveloppe['objectif_date'] !=
                                                null) {
                                              try {
                                                DateTime temp = DateTime.parse(
                                                    enveloppe['objectif_date']);
                                                cible = DateTime(
                                                    maintenant.year,
                                                    temp.month,
                                                    temp.day);
                                              } catch (_) {}
                                            }

                                            cible ??= DateTime(
                                                maintenant.year,
                                                maintenant.month,
                                                maintenant.day);

                                            // Si date passée cette année, prendre l'année prochaine
                                            if (cible.isBefore(maintenant)) {
                                              cible = DateTime(
                                                  maintenant.year + 1,
                                                  cible.month,
                                                  cible.day);
                                            }

                                            // Calcul du nombre de mois restants (inclusif)
                                            int moisRestants =
                                                (cible.year - maintenant.year) *
                                                        12 +
                                                    (cible.month -
                                                        maintenant.month) +
                                                    1;
                                            if (moisRestants < 1) {
                                              moisRestants = 1;
                                            }

                                            double montantMensuelNecessaire =
                                                montantObjectif / moisRestants;

                                            return Text(
                                              'Nécessaire par mois : ${montantMensuelNecessaire.toStringAsFixed(2)}\u00A0\$',
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 13,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            );
                                          }
                                          return const SizedBox.shrink();
                                        },
                                      ),
                                  ],
                                ),
                              ),
                              if ([
                                "mensuel",
                                "datefixe",
                                "date",
                                "bihebdo",
                                "annuel"
                              ].any(
                                (f) => (enveloppe['frequence_objectif']
                                            ?.toString() ??
                                        '')
                                    .toLowerCase()
                                    .contains(f),
                              ))
                                Container(
                                  margin: const EdgeInsets.only(
                                    left: 8,
                                    top: 2,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: bulleColor,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${solde.toStringAsFixed(2)}\u00A0\$',
                                    style: TextStyle(
                                      color: estNegative
                                          ? Colors.white
                                          : (solde == 0
                                              ? Colors.white70
                                              : Colors.black),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                )
                              else if (widget.editionMode) ...[
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit,
                                    color: Colors.white70,
                                    size: 20,
                                  ),
                                  tooltip: 'Renommer',
                                  onPressed: () => widget.onRename?.call(
                                    categorie['id'],
                                    enveloppe['id'],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.close,
                                    color: Colors.redAccent,
                                    size: 20,
                                  ),
                                  tooltip: 'Supprimer',
                                  onPressed: () => widget.onDelete?.call(
                                    categorie['id'],
                                    enveloppe['id'],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (objectif > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 35),
                                      child: LinearProgressIndicator(
                                        value: progression,
                                        backgroundColor: Colors.white12,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          estDepenseAtteint
                                              ? Colors.green[800]!
                                              : etatColor,
                                        ),
                                        minHeight: 6,
                                      ),
                                    ),
                                  ),
                                  Transform.translate(
                                    offset: Offset(-17, 0),
                                    child: Row(
                                      children: [
                                        Text(
                                          '${(progression * 100).toStringAsFixed(0)} %',
                                          style: TextStyle(
                                            color: estDepenseAtteint
                                                ? Colors.green[800]!
                                                : etatColor,
                                            fontSize: 12,
                                          ),
                                        ),
                                        if (estDepenseAtteint) ...[
                                          SizedBox(width: 4),
                                          Icon(
                                            Icons.check_circle,
                                            color: Colors.green[800],
                                            size: 18,
                                          ),
                                          SizedBox(width: 2),
                                          Text(
                                            'Dépensé !',
                                            style: TextStyle(
                                              color: Colors.green[800],
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );

              return widget.editionMode
                  ? cardWidget
                  : InkWell(
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => AssignationBottomSheet(
                            enveloppe: enveloppe,
                            comptes: widget.comptes,
                          ),
                        );
                      },
                      onLongPress: () {
                        if (solde > 0) {
                          _showViderEnveloppeMenu(context, enveloppe);
                        }
                      },
                      child: cardWidget,
                    );
            }),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }
}
