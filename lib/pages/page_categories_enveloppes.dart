import 'package:flutter/material.dart';
import '../models/categorie.dart';
import '../services/firebase_service.dart';
import 'page_set_objectif.dart';
import 'dart:async';

class PageCategoriesEnveloppes extends StatefulWidget {
  const PageCategoriesEnveloppes({super.key});

  @override
  State<PageCategoriesEnveloppes> createState() =>
      _PageCategoriesEnveloppesState();
}

class _PageCategoriesEnveloppesState extends State<PageCategoriesEnveloppes> {
  bool _editionMode = false;
  List<Categorie> _categories = [];
  bool _isLoading = true;
  StreamSubscription<List<Categorie>>? _categoriesSubscription;
  bool _isReordering = false;

  @override
  void initState() {
    super.initState();
    _initCategories();
  }

  @override
  void dispose() {
    _categoriesSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initCategories() async {
    // Charger les catégories initiales
    _categoriesSubscription = FirebaseService().lireCategories().listen((
      categories,
    ) {
      if (mounted && !_editionMode) {
        final sortedCategories = _sortCategoriesWithDetteFirst(categories);

        // Ne mettre à jour que si l'ordre a changé
        if (!_areListsEqual(_categories, sortedCategories)) {
          setState(() {
            _categories = sortedCategories;
            _isLoading = false;
          });
        } else if (_isLoading) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    });
  }

  // Méthode pour trier les catégories avec "Dette" toujours en première position
  List<Categorie> _sortCategoriesWithDetteFirst(List<Categorie> categories) {
    final sorted = List<Categorie>.from(categories);
    sorted.sort((a, b) {
      // Forcer "Dette" en premier, insensible à la casse
      final aNom = a.nom.toLowerCase();
      final bNom = b.nom.toLowerCase();
      if (aNom == 'dette' || aNom == 'dettes') return -1;
      if (bNom == 'dette' || bNom == 'dettes') return 1;
      // Ensuite trier par ordre
      final aOrdre = a.ordre ?? 999999;
      final bOrdre = b.ordre ?? 999999;
      return aOrdre.compareTo(bOrdre);
    });
    return sorted;
  }

  // Méthode pour comparer deux listes de catégories
  bool _areListsEqual(List<Categorie> list1, List<Categorie> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      if (list1[i].id != list2[i].id || list1[i].ordre != list2[i].ordre) {
        return false;
      }
    }
    return true;
  }

  // Méthode pour réorganiser les catégories
  Future<void> _reorderCategories(int oldIndex, int newIndex) async {
    // Vérifier si la catégorie "Dette" est déplacée ou si on la déplace à sa place
    if (_categories.isNotEmpty) {
      final Categorie categorieADeplacer = _categories[oldIndex];
      if (categorieADeplacer.nom.toLowerCase() == 'dette' ||
          categorieADeplacer.nom.toLowerCase() == 'dettes') {
        // La catégorie "Dette" ne peut pas être déplacée
        return;
      }
      if (newIndex == 0) {
        final Categorie categorieEnPremierePosition = _categories[0];
        if (categorieEnPremierePosition.nom.toLowerCase() == 'dette' ||
            categorieEnPremierePosition.nom.toLowerCase() == 'dettes') {
          // On ne peut pas déplacer une autre catégorie à la place de "Dette"
          return;
        }
      }
    }

    // Ajuster l'index comme d'habitude
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    // Créer une nouvelle liste avec le nouvel ordre
    final updatedCategories = List<Categorie>.from(_categories);
    final item = updatedCategories.removeAt(oldIndex);
    updatedCategories.insert(newIndex, item);

    // Mettre à jour l'état local immédiatement
    setState(() {
      _categories = updatedCategories;
    });

    // Mettre à jour l'ordre dans Firebase
    try {
      // Mettre à jour chaque catégorie individuellement avec son nouvel ordre
      for (int i = 0; i < updatedCategories.length; i++) {
        final cat = updatedCategories[i];
        await FirebaseService()
            .firestore
            .collection('categories')
            .doc(cat.id)
            .update({'ordre': i});
      }
    } catch (e) {
      // En cas d'erreur, afficher un message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de la réorganisation des catégories'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    // Finalement, on remet le flag à false pour réafficher les enveloppes
    setState(() {
      _isReordering = false;
    });
  }

  Future<void> _reorderEnveloppes(
    Categorie categorie,
    int oldIndex,
    int newIndex,
  ) async {
    if (categorie.nom.toLowerCase() == 'dette') return;

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    // Trouver l'index de la catégorie dans la liste principale
    final categorieIndex = _categories.indexWhere((c) => c.id == categorie.id);
    if (categorieIndex == -1) return;

    // Créer une nouvelle liste d'enveloppes avec le nouvel ordre
    final newEnveloppes = List<Enveloppe>.from(categorie.enveloppes);
    final item = newEnveloppes.removeAt(oldIndex);
    newEnveloppes.insert(newIndex, item);

    // Mettre à jour l'ordre des enveloppes
    final updatedEnveloppes = newEnveloppes.asMap().entries.map((entry) {
      final enveloppe = entry.value;
      return Enveloppe(
        id: enveloppe.id,
        nom: enveloppe.nom,
        objectif: enveloppe.objectif,
        solde: enveloppe.solde,
        objectifDate: enveloppe.objectifDate,
        depense: enveloppe.depense,
        archivee: enveloppe.archivee,
        provenanceCompteId: enveloppe.provenanceCompteId,
        frequenceObjectif: enveloppe.frequenceObjectif,
        dateDernierAjout: enveloppe.dateDernierAjout,
        objectifJour: enveloppe.objectifJour,
        historique: enveloppe.historique,
        ordre: entry.key,
      );
    }).toList();

    // Mettre à jour la catégorie localement
    setState(() {
      _categories[categorieIndex] = Categorie(
        id: categorie.id,
        nom: categorie.nom,
        enveloppes: updatedEnveloppes,
        ordre: categorie.ordre,
      );
    });

    // Sauvegarder dans Firebase
    await FirebaseService().ajouterCategorie(_categories[categorieIndex]);
  }

  void _ajouterCategorie(List<Categorie> categories) async {
    final TextEditingController controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nouvelle catégorie'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Nom de la catégorie'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Créer'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      final newCat = Categorie(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        nom: result,
        enveloppes: [],
        ordre: _categories.length, // Ajouter à la fin
      );
      await FirebaseService().ajouterCategorie(newCat);

      // Mettre à jour la liste locale
      setState(() {
        _categories = _sortCategoriesWithDetteFirst([..._categories, newCat]);
      });
    }
  }

  void _ajouterEnveloppe(Categorie categorie) async {
    final TextEditingController controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Nouvelle enveloppe pour "${categorie.nom}"'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Nom de l\'enveloppe'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Créer'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      final newEnv = Enveloppe(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        nom: result,
      );
      final updatedCat = Categorie(
        id: categorie.id,
        nom: categorie.nom,
        enveloppes: [...categorie.enveloppes, newEnv],
        ordre: categorie.ordre,
        userId: categorie.userId,
      );

      // Sauvegarder dans Firebase
      await FirebaseService().ajouterCategorie(updatedCat);

      // Mettre à jour l'état local immédiatement
      final categorieIndex = _categories.indexWhere(
        (c) => c.id == categorie.id,
      );
      if (categorieIndex != -1) {
        setState(() {
          _categories[categorieIndex] = updatedCat;
        });
      }
    }
  }

  void _renommerCategorie(Categorie categorie) async {
    final TextEditingController controller = TextEditingController(
      text: categorie.nom,
    );
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Renommer la catégorie'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Nouveau nom'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Renommer'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty && result != categorie.nom) {
      final updatedCat = Categorie(
        id: categorie.id,
        nom: result,
        enveloppes: categorie.enveloppes,
        ordre: categorie.ordre,
        userId: categorie.userId,
      );

      // Sauvegarder dans Firebase
      await FirebaseService().ajouterCategorie(updatedCat);

      // Mettre à jour l'état local immédiatement
      final categorieIndex = _categories.indexWhere(
        (c) => c.id == categorie.id,
      );
      if (categorieIndex != -1) {
        setState(() {
          _categories[categorieIndex] = updatedCat;
        });
      }
    }
  }

  void _supprimerCategorie(Categorie categorie) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la catégorie'),
        content: Text(
          'Voulez-vous vraiment supprimer la catégorie "${categorie.nom}" et toutes ses enveloppes ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await FirebaseService().supprimerCategorie(categorie.id);

      // Mettre à jour l'état local pour refléter la suppression immédiatement
      setState(() {
        _categories.removeWhere((c) => c.id == categorie.id);
      });
    }
  }

  void _renommerEnveloppe(Categorie categorie, Enveloppe enveloppe) async {
    final TextEditingController controller = TextEditingController(
      text: enveloppe.nom,
    );
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Renommer l\'enveloppe'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Nouveau nom'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Renommer'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty && result != enveloppe.nom) {
      final newEnveloppes = categorie.enveloppes
          .map(
            (e) => e.id == enveloppe.id ? Enveloppe(id: e.id, nom: result) : e,
          )
          .toList();
      final updatedCat = Categorie(
        id: categorie.id,
        nom: categorie.nom,
        enveloppes: newEnveloppes,
        ordre: categorie.ordre,
        userId: categorie.userId,
      );

      // Sauvegarder dans Firebase
      await FirebaseService().ajouterCategorie(updatedCat);

      // Mettre à jour l'état local immédiatement
      final categorieIndex = _categories.indexWhere(
        (c) => c.id == categorie.id,
      );
      if (categorieIndex != -1) {
        setState(() {
          _categories[categorieIndex] = updatedCat;
        });
      }
    }
  }

  void _supprimerEnveloppe(Categorie categorie, Enveloppe enveloppe) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archiver l\'enveloppe'),
        content: Text(
          'Voulez-vous vraiment archiver l\'enveloppe "${enveloppe.nom}" ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Archiver'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await FirebaseService().archiverEnveloppe(categorie.id, enveloppe.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catégories & Enveloppes'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        actions: [
          IconButton(
            icon: Icon(_editionMode ? Icons.check : Icons.edit),
            tooltip: _editionMode ? 'Terminer l\'édition' : 'Mode édition',
            onPressed: () async {
              if (_editionMode) {
                try {
                  // Désactiver temporairement la synchronisation
                  _categoriesSubscription?.pause();

                  // Mettre à jour l'ordre de toutes les catégories
                  for (int i = 0; i < _categories.length; i++) {
                    final cat = _categories[i];
                    await FirebaseService()
                        .firestore
                        .collection('categories')
                        .doc(cat.id)
                        .update({'ordre': i});
                  }

                  setState(() {
                    _editionMode = false;
                  });

                  // Réactiver la synchronisation
                  _categoriesSubscription?.resume();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Erreur lors de la sauvegarde de l\'ordre',
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              } else {
                // Désactiver la synchronisation en mode édition
                _categoriesSubscription?.pause();
                setState(() {
                  _editionMode = true;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.white),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Maintenez et déplacez les éléments pour réorganiser leur position',
                          ),
                        ),
                      ],
                    ),
                    duration: Duration(seconds: 4),
                  ),
                );
              }
            },
          ),
          if (_editionMode)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0),
              child: Icon(Icons.drag_handle, color: Colors.white54, size: 24),
            ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Créer une catégorie',
            onPressed: () => _ajouterCategorie(_categories),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_editionMode)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Card(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.1),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Maintenez et déplacez les éléments pour réorganiser leur position',
                                  style: TextStyle(fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 40),
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ReorderableListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _categories.length,
                            onReorder: _reorderCategories,
                            onReorderStart: (index) {
                              setState(() {
                                _isReordering = true;
                              });
                            },
                            buildDefaultDragHandles:
                                false, // On utilise une poignée personnalisée
                            itemBuilder: (context, index) {
                              final categorie = _categories[index];
                              return _buildCategorieItem(
                                categorie,
                                index: index,
                                key: ValueKey(categorie.id),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildCategorieItem(Categorie categorie, {Key? key, int? index}) {
    final enveloppes = List<Enveloppe>.from(categorie.enveloppes);
    if (_editionMode) {
      enveloppes.sort((a, b) => (a.ordre ?? 0).compareTo(b.ordre ?? 0));
    }

    final isDette = categorie.nom.toLowerCase() == 'dette' ||
        categorie.nom.toLowerCase() == 'dettes';

    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                categorie.nom,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white70,
                ),
              ),
            ),
            if (_editionMode) ...[
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.white70, size: 22),
                tooltip: 'Renommer la catégorie',
                onPressed: isDette ? null : () => _renommerCategorie(categorie),
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  color: Colors.redAccent,
                  size: 22,
                ),
                tooltip: 'Supprimer la catégorie',
                onPressed:
                    isDette ? null : () => _supprimerCategorie(categorie),
              ),
              ReorderableDragStartListener(
                index: index!,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Icon(
                    isDette ? Icons.lock : Icons.drag_handle,
                    color: isDette ? Colors.grey : Colors.white54,
                    size: 24,
                  ),
                ),
              ),
            ] else ...[
              IconButton(
                icon: const Icon(
                  Icons.add_circle_outline,
                  color: Colors.white70,
                  size: 22,
                ),
                tooltip: 'Ajouter une enveloppe',
                onPressed: () => _ajouterEnveloppe(categorie),
              ),
            ],
          ],
        ),
        AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: _isReordering ? 0.0 : 1.0,
          child: IgnorePointer(
            ignoring: _isReordering,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_editionMode)
                  ReorderableListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    onReorder: (oldIndex, newIndex) =>
                        _reorderEnveloppes(categorie, oldIndex, newIndex),
                    children: enveloppes
                        .asMap()
                        .entries
                        .map(
                          (entry) => _buildEnveloppeItem(
                            categorie,
                            entry.value,
                            index: entry.key,
                            key: ValueKey(entry.value.id),
                          ),
                        )
                        .toList(),
                  )
                else
                  ...enveloppes.map(
                    (enveloppe) => _buildEnveloppeItem(categorie, enveloppe),
                  ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEnveloppeItem(
    Categorie categorie,
    Enveloppe enveloppe, {
    Key? key,
    int? index,
  }) {
    final isDette = categorie.nom.toLowerCase() == 'dette' ||
        categorie.nom.toLowerCase() == 'dettes';

    return Card(
      key: key,
      color: const Color(0xFF232526),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        child: SizedBox(
          height: 40,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  enveloppe.nom,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_editionMode) ...[
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.white70, size: 18),
                  tooltip: 'Renommer l\'enveloppe',
                  onPressed: isDette
                      ? null
                      : () => _renommerEnveloppe(categorie, enveloppe),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                    size: 18,
                  ),
                  tooltip: 'Archiver l\'enveloppe',
                  onPressed: isDette
                      ? null
                      : () => _supprimerEnveloppe(categorie, enveloppe),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                ReorderableDragStartListener(
                  index: index!,
                  enabled: !isDette,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Icon(
                      isDette ? Icons.lock : Icons.drag_handle,
                      color: isDette ? Colors.grey : Colors.white38,
                      size: 20,
                    ),
                  ),
                ),
              ] else ...[
                Builder(
                  builder: (context) {
                    return GestureDetector(
                      onTap: () async {
                        final nouveauObjectif = await Navigator.push<double>(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PageSetObjectif(
                              categorie: categorie,
                              enveloppe: enveloppe,
                            ),
                          ),
                        );

                        if (nouveauObjectif != null && mounted) {
                          setState(() {
                            final categorieIndex = _categories.indexWhere(
                              (c) => c.id == categorie.id,
                            );
                            if (categorieIndex != -1) {
                              final enveloppeIndex = _categories[categorieIndex]
                                  .enveloppes
                                  .indexWhere((e) => e.id == enveloppe.id);
                              if (enveloppeIndex != -1) {
                                // Mettre à jour l'enveloppe
                                _categories[categorieIndex]
                                        .enveloppes[enveloppeIndex] =
                                    _categories[categorieIndex]
                                        .enveloppes[enveloppeIndex]
                                        .copyWith(objectif: nouveauObjectif);
                              }
                            }
                          });
                        }
                      },
                      child: Text(
                        (enveloppe.objectif > 0)
                            ? '${enveloppe.objectif.toStringAsFixed(2)} \$'
                            : 'Objectif',
                        style: TextStyle(
                          color: (enveloppe.objectif > 0)
                              ? Colors.greenAccent
                              : Theme.of(context).colorScheme.primary,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
