import 'package:flutter/material.dart';
import 'package:toutie_budget/pages/page_ajout_transaction.dart';
import '../models/compte.dart';
import '../models/transaction_model.dart' as app_model;
import '../models/categorie.dart';
import '../services/firebase_service.dart';
import 'dart:async';

/// Page affichant la liste des transactions d'un compte chèque
class PageTransactionsCompte extends StatefulWidget {
  final Compte compte;
  const PageTransactionsCompte({super.key, required this.compte});

  @override
  State<PageTransactionsCompte> createState() => _PageTransactionsCompteState();
}

class _PageTransactionsCompteState extends State<PageTransactionsCompte> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounceTimer;

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  // Méthode pour gérer la recherche avec délai
  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _searchQuery = value;
      });
    });
  }

  // Méthode pour normaliser les chaînes de caractères (comme dans le contrôleur)
  String normaliserChaine(String chaine) {
    return chaine
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll('à', 'a')
        .replaceAll('â', 'a')
        .replaceAll('ä', 'a')
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('ë', 'e')
        .replaceAll('ï', 'i')
        .replaceAll('î', 'i')
        .replaceAll('ô', 'o')
        .replaceAll('ö', 'o')
        .replaceAll('ù', 'u')
        .replaceAll('û', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ÿ', 'y')
        .replaceAll('ç', 'c');
  }

  // Méthode pour filtrer les transactions
  List<app_model.Transaction> filtrerTransactions(
    List<app_model.Transaction> transactions,
    Map<String, String> enveloppeIdToNom,
  ) {
    if (_searchQuery.isEmpty) {
      return transactions;
    }

    final queryNormalise = normaliserChaine(_searchQuery);

    return transactions.where((transaction) {
      // Filtrer par tiers
      if (transaction.tiers != null &&
          normaliserChaine(transaction.tiers!).contains(queryNormalise)) {
        return true;
      }

      // Filtrer par montant (recherche exacte ou partielle)
      final montantStr = transaction.montant.toStringAsFixed(2);
      if (montantStr.contains(_searchQuery.replaceAll(',', '.'))) {
        return true;
      }

      // Filtrer par enveloppe
      if (transaction.enveloppeId != null &&
          transaction.enveloppeId!.isNotEmpty) {
        final nomEnveloppe = enveloppeIdToNom[transaction.enveloppeId!];
        if (nomEnveloppe != null &&
            normaliserChaine(nomEnveloppe).contains(queryNormalise)) {
          return true;
        }
      }

      // Filtrer par enveloppes dans les transactions fractionnées
      if (transaction.estFractionnee == true && transaction.sousItems != null) {
        for (var sousItem in transaction.sousItems!) {
          final enveloppeId = sousItem['enveloppeId'] as String?;
          if (enveloppeId != null) {
            final nomEnveloppe = enveloppeIdToNom[enveloppeId];
            if (nomEnveloppe != null &&
                normaliserChaine(nomEnveloppe).contains(queryNormalise)) {
              return true;
            }
          }
        }
      }

      // Filtrer par type de mouvement (pour les recherches comme "prêt", "dette", etc.)
      final typeMouvementStr = transaction.typeMouvement.name.toLowerCase();
      if (typeMouvementStr.contains(queryNormalise)) {
        return true;
      }

      // Filtrer par note si présente
      if (transaction.note != null &&
          normaliserChaine(transaction.note!).contains(queryNormalise)) {
        return true;
      }

      return false;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Transactions - ${widget.compte.nom}')),
      body: FutureBuilder<List<Categorie>>(
        future: FirebaseService().lireCategories().first,
        builder: (context, catSnapshot) {
          final enveloppeIdToNom = <String, String>{};
          if (catSnapshot.hasData) {
            for (final cat in catSnapshot.data!) {
              for (final env in cat.enveloppes) {
                enveloppeIdToNom[env.id] = env.nom;
              }
            }
          }
          return StreamBuilder<List<app_model.Transaction>>(
            stream: FirebaseService().lireTransactions(widget.compte.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(
                  child: Text(
                    'Aucune transaction pour ce compte',
                    style: TextStyle(fontSize: 18, color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                );
              }
              final transactions = snapshot.data!;

              // DEBUG : Afficher l'id du compte, les compteId/userId des transactions et le userId courant
              print('DEBUG: compte.id = \\${widget.compte.id}');
              for (final t in transactions) {
                print(
                  'DEBUG: transaction compteId = \\${t.compteId}, userId = \\${t.userId}',
                );
              }
              // Afficher le userId courant
              print(
                'DEBUG: userId courant = \\${FirebaseService().auth.currentUser?.uid}',
              );

              // Filtrer les transactions selon la recherche
              final transactionsFiltrees = filtrerTransactions(
                transactions,
                enveloppeIdToNom,
              );

              // Regrouper les transactions par date (formatée)
              final Map<String, List<app_model.Transaction>>
              transactionsParDate = {};
              for (final t in transactionsFiltrees) {
                final dateStr =
                    '${t.date.day.toString().padLeft(2, '0')}/${t.date.month.toString().padLeft(2, '0')}/${t.date.year}';
                transactionsParDate.putIfAbsent(dateStr, () => []).add(t);
              }
              final datesTriees = transactionsParDate.keys.toList()
                ..sort((a, b) => b.compareTo(a)); // dates descendantes

              return Column(
                children: [
                  // Barre de recherche
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        TextField(
                          controller: _searchController,
                          onChanged: _onSearchChanged,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                          ),
                          decoration: InputDecoration(
                            hintText:
                                'Rechercher par tiers, montant, enveloppe...',
                            hintStyle: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 16,
                            ),
                            prefixIcon: Icon(
                              Icons.search,
                              color: Colors.grey.shade700,
                            ),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: Icon(
                                      Icons.clear,
                                      color: Colors.grey.shade700,
                                    ),
                                    onPressed: () {
                                      _searchController.clear();
                                      _debounceTimer?.cancel();
                                      setState(() {
                                        _searchQuery = '';
                                      });
                                    },
                                  )
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.grey.shade400,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.grey.shade400,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Theme.of(context).colorScheme.primary,
                                width: 2,
                              ),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),

                        // Indicateur du nombre de résultats
                        if (_searchQuery.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 16,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${transactionsFiltrees.length} transaction${transactionsFiltrees.length > 1 ? 's' : ''} trouvée${transactionsFiltrees.length > 1 ? 's' : ''}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              if (transactionsFiltrees.length !=
                                  transactions.length) ...[
                                Text(
                                  ' sur ${transactions.length}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Liste des transactions
                  Expanded(
                    child: transactionsFiltrees.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search_off,
                                  size: 64,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _searchQuery.isEmpty
                                      ? 'Aucune transaction pour ce compte'
                                      : 'Aucune transaction trouvée pour "$_searchQuery"',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey.shade600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                if (_searchQuery.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'Essayez de modifier votre recherche',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade500,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ],
                            ),
                          )
                        : ListView(
                            children: [
                              for (final date in datesTriees) ...[
                                // Bandeau séparateur compact VISIBLE
                                Container(
                                  color: const Color(0xFFB71C1C).withAlpha(
                                    20,
                                  ), // Remplacement de withOpacity déprécié
                                  height: 20, // Hauteur réduite
                                  alignment: Alignment.centerLeft,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  child: Text(
                                    date,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      fontSize: 13,
                                      height: 1.1,
                                    ),
                                  ),
                                ),
                                ...transactionsParDate[date]!.map((t) {
                                  final isDepense = t.type.estDepense;
                                  final montantColor = isDepense
                                      ? Colors.red
                                      : Colors.green;
                                  String sousTitre = '';
                                  // --- Ajout pour transaction fractionnée ---
                                  if (t.estFractionnee == true &&
                                      t.sousItems != null &&
                                      t.sousItems!.isNotEmpty) {
                                    // DEBUG: Afficher les données pour comprendre le problème
                                    print('DEBUG Transaction fractionnée:');
                                    print('  - tiers: ${t.tiers}');
                                    print('  - sousItems: ${t.sousItems}');
                                    print(
                                      '  - enveloppeIdToNom: $enveloppeIdToNom',
                                    );

                                    // Afficher la liste des enveloppes et montants avec format demandé
                                    final enveloppesFormatees = t.sousItems!.map((
                                      item,
                                    ) {
                                      final nomEnv =
                                          enveloppeIdToNom[item['enveloppeId']] ??
                                          'Enveloppe inconnue';
                                      final montant =
                                          (item['montant'] as num?)
                                              ?.toDouble() ??
                                          0.0;
                                      print(
                                        '  - Enveloppe: ${item['enveloppeId']} -> $nomEnv, Montant: $montant',
                                      );
                                      return '$nomEnv - ${montant.toStringAsFixed(0)}\$';
                                    }).toList();
                                    sousTitre = enveloppesFormatees.join(', ');
                                  } else if (t.typeMouvement ==
                                      app_model
                                          .TypeMouvementFinancier
                                          .pretAccorde) {
                                    sousTitre = 'Prêt accordé';
                                  } else if (t.typeMouvement ==
                                      app_model
                                          .TypeMouvementFinancier
                                          .detteContractee) {
                                    sousTitre = 'Dette contractée';
                                  } else if (t.typeMouvement ==
                                      app_model
                                          .TypeMouvementFinancier
                                          .remboursementRecu) {
                                    sousTitre = 'Remboursement reçu';
                                  } else if (t.typeMouvement ==
                                      app_model
                                          .TypeMouvementFinancier
                                          .remboursementEffectue) {
                                    sousTitre = 'Remboursement effectué';
                                  } else if (t.enveloppeId != null &&
                                      t.enveloppeId!.startsWith('pret_')) {
                                    sousTitre =
                                        '${widget.compte.nom} - prêt à placer';
                                  } else if (t.enveloppeId != null &&
                                      t.enveloppeId!.isNotEmpty) {
                                    sousTitre =
                                        enveloppeIdToNom[t.enveloppeId!] ?? '-';
                                  } else {
                                    sousTitre = '-';
                                  }
                                  return GestureDetector(
                                    onLongPress: () async {
                                      final result =
                                          await showModalBottomSheet<String>(
                                            context: context,
                                            builder: (context) => SafeArea(
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  ListTile(
                                                    leading: Icon(
                                                      Icons.delete,
                                                      color: Colors.red,
                                                    ),
                                                    title: Text(
                                                      'Annuler la transaction',
                                                      style: TextStyle(
                                                        color: Colors.red,
                                                      ),
                                                    ),
                                                    onTap: () => Navigator.of(
                                                      context,
                                                    ).pop('delete'),
                                                  ),
                                                  ListTile(
                                                    leading: Icon(Icons.close),
                                                    title: Text('Annuler'),
                                                    onTap: () => Navigator.of(
                                                      context,
                                                    ).pop(),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                      if (result == 'delete') {
                                        await annulerTransaction(context, t);
                                      }
                                    },
                                    onTap: () async {
                                      await Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              EcranAjoutTransactionRefactored(
                                                comptesExistants: const [],
                                                transactionExistante: t,
                                                modeModification: true,
                                              ),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      margin: const EdgeInsets.only(bottom: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.blueGrey.withAlpha(
                                          (0.08 * 255).toInt(),
                                        ),
                                        border: Border(
                                          bottom: BorderSide(
                                            color: Colors.grey.shade300,
                                            width: 0.7,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  t.tiers != null &&
                                                          t.tiers!.isNotEmpty
                                                      ? t.tiers!
                                                      : '-',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                    height: 1.1,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                Text(
                                                  sousTitre,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey,
                                                    height: 1.1,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                          Text(
                                            '${isDepense ? '-' : '+'}${t.montant.toStringAsFixed(2)} \$',
                                            style: TextStyle(
                                              color: montantColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            ],
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

  Future<void> annulerTransaction(
    BuildContext context,
    app_model.Transaction t,
  ) async {
    try {
      // 1. Rollback de l'effet de la transaction sur les soldes
      await FirebaseService().rollbackTransaction(t);

      // 2. Supprimer la transaction de Firestore
      await FirebaseService().supprimerDocument('transactions', t.id);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Transaction annulée avec succès'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Erreur lors de l\'annulation de la transaction: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'annulation: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
}
