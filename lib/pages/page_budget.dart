import 'package:flutter/material.dart';
import 'package:toutie_budget/services/firebase_service.dart';
import 'package:toutie_budget/services/rollover_service.dart';
import '../models/compte.dart';
import '../models/categorie.dart';
import '../widgets/liste_categories_enveloppes.dart';
import 'page_categories_enveloppes.dart';
import '../widgets/month_picker.dart';
import 'page_virer_argent.dart';
import 'page_pret_personnel.dart';
import 'page_parametres.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'page_situations_urgence.dart';

/// Page d'affichage du budget et des enveloppes
class PageBudget extends StatefulWidget {
  const PageBudget({super.key});

  @override
  State<PageBudget> createState() => _PageBudgetState();
}

class _PageBudgetState extends State<PageBudget> {
  DateTime selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  final RolloverService _rolloverService = RolloverService();
  int refreshKey = 0;

  @override
  void initState() {
    super.initState();
    _triggerRollover();
  }

  Future<void> _triggerRollover() async {
    final bool rolloverProcessed = await _rolloverService.processRollover();
    if (rolloverProcessed) {
      if (mounted) {
        setState(() {
          refreshKey++; // Force a refresh of the UI
        });
      }
    }
  }

  Future<void> handleMonthChange(DateTime date) async {
    setState(() {
      selectedMonth = date;
    });
  }

  String get selectedMonthKey =>
      "${selectedMonth.year.toString().padLeft(4, '0')}-${selectedMonth.month.toString().padLeft(2, '0')}";

  /// Calcule le montant total en négatif (comptes + enveloppes)
  double _calculerMontantNegatifTotal(
    List<Compte> comptes,
    List<Categorie> categories,
  ) {
    double total = 0.0;

    // Comptes chèques avec prêt à placer négatif
    for (var compte in comptes) {
      if (compte.pretAPlacer < 0 && compte.type == 'Chèque') {
        total += compte.pretAPlacer.abs();
      }
    }

    // Enveloppes avec solde négatif
    for (var categorie in categories) {
      for (var enveloppe in categorie.enveloppes) {
        if (enveloppe.solde < 0) {
          total += enveloppe.solde.abs();
        }
      }
    }

    return total;
  }

  /// Vérifie s'il y a des situations d'urgence
  bool _aSituationsUrgence(List<Compte> comptes, List<Categorie> categories) {
    // Vérifier les comptes négatifs (seulement comptes chèques)
    final comptesNegatifs = comptes.any(
      (compte) => compte.pretAPlacer < 0 && compte.type == 'Chèque',
    );

    // Vérifier les enveloppes négatives
    final enveloppesNegatives = categories.any(
      (categorie) =>
          categorie.enveloppes.any((enveloppe) => enveloppe.solde < 0),
    );

    return comptesNegatifs || enveloppesNegatives;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: SafeArea(
          child: Stack(
            children: [
              // Sélecteur de mois avec padding
              Positioned(
                left: 25,
                top: 0,
                bottom: 0,
                child: MonthPickerWidget(
                  selectedMonth: selectedMonth,
                  onChanged: handleMonthChange,
                ),
              ),
              // Actions à droite (icône paramètres tout à droite)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: SvgPicture.asset(
                        'assets/icons/transfert_argent.svg',
                        width: 25,
                        height: 25,
                        colorFilter: ColorFilter.mode(
                          Theme.of(context).iconTheme.color ?? Colors.white,
                          BlendMode.srcIn,
                        ),
                      ),
                      tooltip: 'Virer de l\'argent',
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const PageVirerArgent(),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: SvgPicture.asset(
                        'assets/icons/gerer_categorie.svg',
                        width: 20,
                        height: 20,
                        colorFilter: ColorFilter.mode(
                          Theme.of(context).iconTheme.color ?? Colors.white,
                          BlendMode.srcIn,
                        ),
                      ),
                      tooltip: 'Catégories',
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>
                                const PageCategoriesEnveloppes(),
                          ),
                        );
                      },
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.menu),
                      tooltip: 'Menu',
                      onSelected: (value) async {
                        if (value == 'pret_personnel') {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const PagePretPersonnel(),
                            ),
                          );
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem<String>(
                          value: 'pret_personnel',
                          child: Row(
                            children: [
                              Icon(Icons.account_balance_wallet, size: 20),
                              SizedBox(width: 8),
                              Text('Prêt personnel'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings),
                      tooltip: 'Paramètres',
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const PageParametres(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: StreamBuilder<List<Compte>>(
        stream: FirebaseService().lireComptes(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final comptes = snapshot.data ?? [];
          if (comptes.isEmpty) {
            return const Center(
              child: Text(
                'Aucun compte disponible',
                style: TextStyle(color: Colors.white70),
              ),
            );
          }
          return StreamBuilder<List<Categorie>>(
            key: ValueKey(refreshKey),
            stream: FirebaseService().lireCategories(),
            builder: (context, catSnapshot) {
              final categories = catSnapshot.data ?? [];
              final montantNegatif = _calculerMontantNegatifTotal(
                comptes,
                categories,
              );
              final aSituationsUrgence = _aSituationsUrgence(
                comptes,
                categories,
              );

              return Column(
                children: [
                  const SizedBox(height: 20),
                  ...comptes
                      .where(
                        (compte) =>
                            compte.type == 'Chèque' && compte.pretAPlacer != 0,
                      )
                      .map(
                        (compte) => Container(
                          width: MediaQuery.of(context).size.width * 0.92,
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: compte.pretAPlacer < 0
                                ? Colors.red[700]
                                : Color(compte.couleur),
                            borderRadius: const BorderRadius.all(
                              Radius.circular(32),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(64),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                            gradient: compte.pretAPlacer < 0
                                ? null
                                : LinearGradient(
                                    colors: [
                                      Color(compte.couleur),
                                      Color(compte.couleur).withAlpha(217),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 4,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    compte.pretAPlacer < 0
                                        ? Icons.warning
                                        : Icons.account_balance_wallet,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    compte.nom,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Prêt à placer',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white.withAlpha(217),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${compte.pretAPlacer.toStringAsFixed(2)} \$',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: compte.pretAPlacer < 0
                                          ? Colors.red[100]
                                          : Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                  // Bandeau d'alerte rouge pour les situations d'urgence
                  if (aSituationsUrgence) ...[
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const PageSituationsUrgence(),
                          ),
                        );
                      },
                      child: Container(
                        width: MediaQuery.of(context).size.width * 0.92,
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.red[700],
                          borderRadius: const BorderRadius.all(
                            Radius.circular(32),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(64),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.warning,
                              color: Colors.white,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'ATTENTION',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  Text(
                                    '${montantNegatif.toStringAsFixed(2)} \$ dans le rouge',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.white70,
                                    ),
                                  ),
                                  const Text(
                                    'Situation en besoin de votre attention',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.white60,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios,
                              color: Colors.white70,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 50),
                  Expanded(
                    child: ListeCategoriesEnveloppes(
                      categories: categories
                          .map(
                            (c) => {
                              'id': c.id,
                              'nom': c.nom,
                              'enveloppes': c.enveloppes
                                  .map((e) => e.toMap())
                                  .toList(),
                            },
                          )
                          .toList(),
                      comptes: comptes
                          .map(
                            (compte) => {
                              'id': compte.id,
                              'couleur': compte.couleur,
                            },
                          )
                          .toList(),
                      selectedMonthKey: selectedMonthKey,
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
