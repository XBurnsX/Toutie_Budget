import 'package:flutter/material.dart';
import 'package:toutie_budget/pages/page_ajout_transaction.dart';
import '../models/compte.dart';
import '../models/transaction_model.dart' as app_model;
import '../models/categorie.dart';
import '../services/firebase_service.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/cache_service.dart';

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

  // Pagination
  static const int pageSize = 25;
  static const int searchPageSize = 10;
  List<app_model.Transaction> _transactions = [];
  DocumentSnapshot? _lastDoc;
  bool _hasMore = true;
  bool _isLoading = false;
  bool _firstLoadDone = false;

  // Recherche pro
  List<app_model.Transaction> _searchResults = [];
  DocumentSnapshot? _lastSearchDoc;
  bool _hasMoreSearch = true;
  bool _isSearching = false;
  bool _searchLoading = false;

  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fetchNextPage();
    _searchController.addListener(_onSearchChangedPro);
    _scrollController.addListener(_onScroll);
  }

  void _onSearchChangedPro() {
    final value = _searchController.text;
    if (_searchQuery == value) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      setState(() {
        _searchQuery = value;
        _searchResults.clear();
        _lastSearchDoc = null;
        _hasMoreSearch = true;
      });
      if (_searchQuery.isNotEmpty) {
        _fetchSearchPage();
      }
    });
  }

  void _onScroll() {
    if (_searchQuery.isEmpty &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _hasMore) {
      _fetchNextPage();
    }
  }

  void _fetchNextPage() async {
    if (_isLoading || !_hasMore) return;
    setState(() => _isLoading = true);
    final user = FirebaseService().auth.currentUser;
    if (user == null) return;
    Query query = FirebaseFirestore.instance
        .collection('transactions')
        .where('userId', isEqualTo: user.uid)
        .where('compteId', isEqualTo: widget.compte.id)
        .orderBy('date', descending: true)
        .limit(pageSize);
    if (_lastDoc != null) {
      query = query.startAfterDocument(_lastDoc!);
    }
    final snap = await query.get();
    final newTransactions = snap.docs
        .map((doc) =>
            app_model.Transaction.fromJson(doc.data() as Map<String, dynamic>))
        .toList();
    setState(() {
      _transactions.addAll(newTransactions);
      _lastDoc = snap.docs.isNotEmpty ? snap.docs.last : _lastDoc;
      _hasMore = newTransactions.length == pageSize;
      _isLoading = false;
      _firstLoadDone = true;
    });
  }

  void _fetchSearchPage() async {
    if (_searchLoading || !_hasMoreSearch || _searchQuery.isEmpty) return;
    setState(() => _searchLoading = true);
    final user = FirebaseService().auth.currentUser;
    if (user == null) return;
    Query query = FirebaseFirestore.instance
        .collection('transactions')
        .where('userId', isEqualTo: user.uid)
        .where('compteId', isEqualTo: widget.compte.id)
        .orderBy('date', descending: true)
        .limit(searchPageSize);
    if (_lastSearchDoc != null) {
      query = query.startAfterDocument(_lastSearchDoc!);
    }
    // On ne peut pas faire de requête "or" sur Firestore, donc on charge 10 par 10 et filtre côté client
    final snap = await query.get();
    final results = snap.docs
        .map((doc) =>
            app_model.Transaction.fromJson(doc.data() as Map<String, dynamic>))
        .where((transaction) {
      final q = _searchQuery.toLowerCase();
      return (transaction.tiers?.toLowerCase().contains(q) ?? false) ||
          transaction.montant.toString().contains(q) ||
          (transaction.enveloppeId?.toLowerCase().contains(q) ?? false) ||
          (transaction.note?.toLowerCase().contains(q) ?? false) ||
          transaction.typeMouvement.name.toLowerCase().contains(q);
    }).toList();
    setState(() {
      _searchResults.addAll(results);
      _lastSearchDoc = snap.docs.isNotEmpty ? snap.docs.last : _lastSearchDoc;
      _hasMoreSearch = snap.docs.length == searchPageSize;
      _searchLoading = false;
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
      appBar: AppBar(
        title: Text('Transactions - ${widget.compte.nom}'),
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: _buildTransactionsCompteContent(context),
    );
  }

  Widget _buildTransactionsCompteContent(BuildContext context) {
    // On charge les enveloppes une seule fois
    return FutureBuilder<List<Categorie>>(
      future: CacheService.getCategories(FirebaseService()),
      builder: (context, catSnapshot) {
        final enveloppeIdToNom = <String, String>{};
        if (catSnapshot.hasData) {
          for (final cat in catSnapshot.data!) {
            for (final env in cat.enveloppes) {
              enveloppeIdToNom[env.id] = env.nom;
            }
          }
        }
        if (_searchQuery.isNotEmpty) {
          // Recherche pro : résultats filtrés Firestore (max 10 à la fois)
          if (_searchLoading && _searchResults.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_searchResults.isEmpty) {
            return Center(
              child: Text(
                'Aucun résultat pour "$_searchQuery"',
                style: TextStyle(fontSize: 18, color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            );
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Rechercher',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _searchResults.length + (_hasMoreSearch ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _searchResults.length) {
                      if (_searchLoading) {
                        return const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: ElevatedButton(
                          onPressed: _fetchSearchPage,
                          child: const Text('Charger plus'),
                        ),
                      );
                    }
                    final t = _searchResults[index];
                    return _buildTransactionTile(t, enveloppeIdToNom);
                  },
                ),
              ),
            ],
          );
        }
        // Sinon, pagination classique par date (25 par 25)
        final transactionsFiltrees = filtrerTransactions(
          _transactions,
          enveloppeIdToNom,
        );
        if (!_firstLoadDone && _isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (transactionsFiltrees.isEmpty) {
          return Center(
            child: Text(
              'Aucune transaction pour ce compte',
              style: TextStyle(fontSize: 18, color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          );
        }
        // Regrouper les transactions par date (formatée)
        final Map<String, List<app_model.Transaction>> transactionsParDate = {};
        final Map<String, DateTime> dateStringToDateTime = {};
        for (final t in transactionsFiltrees) {
          final dateStr =
              '${t.date.day.toString().padLeft(2, '0')}/${t.date.month.toString().padLeft(2, '0')}/${t.date.year}';
          transactionsParDate.putIfAbsent(dateStr, () => []).add(t);
          dateStringToDateTime[dateStr] = t.date;
        }
        final datesTriees = transactionsParDate.keys.toList()
          ..sort((a, b) =>
              dateStringToDateTime[b]!.compareTo(dateStringToDateTime[a]!));
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Rechercher',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                itemCount: datesTriees.length + (_isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == datesTriees.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final dateStr = datesTriees[index];
                  final transactions = transactionsParDate[dateStr]!;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 8.0, horizontal: 16.0),
                        child: Text(
                          dateStr,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                      ...transactions.map(
                          (t) => _buildTransactionTile(t, enveloppeIdToNom)),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTransactionTile(
      app_model.Transaction t, Map<String, String> enveloppeIdToNom) {
    final isDepense = t.type.estDepense;
    final montantColor = isDepense ? Colors.red : Colors.green;
    String sousTitre = '';
    // --- Ajout pour transaction fractionnée ---
    if (t.estFractionnee == true &&
        t.sousItems != null &&
        t.sousItems!.isNotEmpty) {
      // Afficher la liste des enveloppes et montants avec format demandé
      final enveloppesFormatees = t.sousItems!.map((
        item,
      ) {
        final nomEnv =
            enveloppeIdToNom[item['enveloppeId']] ?? 'Enveloppe inconnue';
        final montant = (item['montant'] as num?)?.toDouble() ?? 0.0;
        return '$nomEnv - ${montant.toStringAsFixed(0)}\$';
      }).toList();
      sousTitre = enveloppesFormatees.join(' , ');
    } else if (t.typeMouvement ==
        app_model.TypeMouvementFinancier.pretAccorde) {
      sousTitre = 'Prêt accordé';
    } else if (t.typeMouvement ==
        app_model.TypeMouvementFinancier.detteContractee) {
      sousTitre = 'Dette contractée';
    } else if (t.typeMouvement ==
        app_model.TypeMouvementFinancier.remboursementRecu) {
      sousTitre = 'Remboursement reçu';
    } else if (t.typeMouvement ==
        app_model.TypeMouvementFinancier.remboursementEffectue) {
      sousTitre = 'Remboursement effectué';
    } else if (t.enveloppeId != null && t.enveloppeId!.startsWith('pret_')) {
      sousTitre = '${widget.compte.nom} - prêt à placer';
    } else if (t.enveloppeId != null && t.enveloppeId!.isNotEmpty) {
      sousTitre = enveloppeIdToNom[t.enveloppeId!] ?? '-';
    } else {
      sousTitre = '-';
    }
    return GestureDetector(
      onLongPress: () async {
        final result = await showModalBottomSheet<String>(
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
            builder: (context) => EcranAjoutTransactionRefactored(
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.tiers != null && t.tiers!.isNotEmpty ? t.tiers! : '-',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      height: 1.1,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    sousTitre,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      height: 1.2,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
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
