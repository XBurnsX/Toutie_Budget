import 'package:flutter/material.dart';
import '../models/categorie.dart';
import '../services/firebase_service.dart';
import 'page_set_objectif.dart';

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

  @override
  void initState() {
    super.initState();
    // Charger les catégories initiales
    FirebaseService().lireCategories().first.then((categories) {
      if (mounted) {
        setState(() {
          _categories = categories;
          _isLoading = false;
        });
      }
    });
  }

  // Méthode pour réorganiser les catégories
  Future<void> _reorderCategories(int oldIndex, int newIndex) async {
    // Trouver l'index de la catégorie Dette
    final detteIndex = _categories.indexWhere(
      (c) => c.nom.toLowerCase() == 'dette',
    );
    if (detteIndex == -1) return; // Si pas de Dette, ne rien faire

    // Empêcher le déplacement de la catégorie Dette
    if (oldIndex == detteIndex) return;

    // Empêcher de déplacer une catégorie au-dessus de Dette (qui doit rester en position 0)
    if (newIndex < 1) {
      return;
    }

    // Ajuster l'index comme d'habitude
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    setState(() {
      final item = _categories.removeAt(oldIndex);
      _categories.insert(newIndex, item);
    });

    // Mettre à jour l'ordre dans Firebase en utilisant une transaction
    final firestore = FirebaseService().firestore;
    await firestore.runTransaction((transaction) async {
      // Mettre à jour l'ordre de toutes les catégories en une seule transaction
      for (int i = 0; i < _categories.length; i++) {
        final cat = _categories[i];

        // Créer une nouvelle catégorie avec l'ordre mis à jour
        final updatedCat = Categorie(
          id: cat.id,
          nom: cat.nom,
          enveloppes: cat.enveloppes,
          ordre: i, // L'ordre correspond à la position dans la liste
          userId: cat.userId,
        );

        // Mettre à jour dans la transaction
        transaction.set(
          firestore.collection('categories').doc(cat.id),
          updatedCat.toMap(),
        );
      }
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
      );
      await FirebaseService().ajouterCategorie(newCat);
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
      );
      await FirebaseService().ajouterCategorie(updatedCat);
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
      );
      await FirebaseService().ajouterCategorie(updatedCat);
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
      );
      await FirebaseService().ajouterCategorie(updatedCat);
    }
  }

  void _supprimerEnveloppe(Categorie categorie, Enveloppe enveloppe) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer l\'enveloppe'),
        content: Text(
          'Voulez-vous vraiment supprimer l\'enveloppe "${enveloppe.nom}" ?',
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
      final newEnveloppes = categorie.enveloppes
          .where((e) => e.id != enveloppe.id)
          .toList();
      final updatedCat = Categorie(
        id: categorie.id,
        nom: categorie.nom,
        enveloppes: newEnveloppes,
      );
      await FirebaseService().ajouterCategorie(updatedCat);
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
                // Sauvegarder l'ordre final dans Firebase
                final firestore = FirebaseService().firestore;
                await firestore.runTransaction((transaction) async {
                  for (int i = 0; i < _categories.length; i++) {
                    final cat = _categories[i];

                    final updatedCat = Categorie(
                      id: cat.id,
                      nom: cat.nom,
                      enveloppes: cat.enveloppes,
                      ordre:
                          i, // L'ordre correspond à la position dans la liste
                      userId: cat.userId,
                    );

                    transaction.set(
                      firestore.collection('categories').doc(cat.id),
                      updatedCat.toMap(),
                    );
                  }
                });
              }
              setState(() {
                _editionMode = !_editionMode;
                if (_editionMode) {
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
              });
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
                    child: StreamBuilder<List<Categorie>>(
                      stream: FirebaseService().lireCategories(),
                      builder: (context, snapshot) {
                        if (snapshot.hasData && !_isLoading) {
                          // Ne mettre à jour la liste locale que lors du chargement initial
                          if (_categories.isEmpty) {
                            _categories = snapshot.data!;
                          }

                          // Trier les catégories
                          final displayedCategories = List<Categorie>.from(
                            _categories,
                          );
                          displayedCategories.sort((a, b) {
                            if (a.nom.toLowerCase() == 'dette') return -1;
                            if (b.nom.toLowerCase() == 'dette') return 1;
                            return (a.ordre ?? 999999).compareTo(
                              b.ordre ?? 999999,
                            );
                          });

                          return _editionMode
                              ? ReorderableListView.builder(
                                  itemCount: displayedCategories.length,
                                  onReorder: _reorderCategories,
                                  itemBuilder: (context, index) {
                                    final categorie =
                                        displayedCategories[index];
                                    return _buildCategorieItem(
                                      categorie,
                                      key: ValueKey(categorie.id),
                                    );
                                  },
                                )
                              : ListView.builder(
                                  itemCount: displayedCategories.length,
                                  itemBuilder: (context, index) {
                                    final categorie =
                                        displayedCategories[index];
                                    return _buildCategorieItem(categorie);
                                  },
                                );
                        }
                        return const Center(child: CircularProgressIndicator());
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildCategorieItem(Categorie categorie, {Key? key}) {
    final enveloppes = List<Enveloppe>.from(categorie.enveloppes);
    if (_editionMode) {
      enveloppes.sort((a, b) => (a.ordre ?? 0).compareTo(b.ordre ?? 0));
    }

    final isDette = categorie.nom.toLowerCase() == 'dette';

    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (_editionMode)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Icon(
                  isDette ? Icons.lock : Icons.drag_handle,
                  color: isDette ? Colors.grey : Colors.white54,
                  size: 20,
                ),
              ),
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
                onPressed: () => _renommerCategorie(categorie),
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  color: Colors.redAccent,
                  size: 22,
                ),
                tooltip: 'Supprimer la catégorie',
                onPressed: () => _supprimerCategorie(categorie),
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
        if (_editionMode && !isDette)
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: enveloppes
                .map(
                  (enveloppe) => _buildEnveloppeItem(
                    categorie,
                    enveloppe,
                    key: ValueKey(enveloppe.id),
                  ),
                )
                .toList(),
            onReorder: (oldIndex, newIndex) =>
                _reorderEnveloppes(categorie, oldIndex, newIndex),
          )
        else
          ...enveloppes.map(
            (enveloppe) => _buildEnveloppeItem(categorie, enveloppe),
          ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildEnveloppeItem(
    Categorie categorie,
    Enveloppe enveloppe, {
    Key? key,
  }) {
    final isDette = categorie.nom.toLowerCase() == 'dette';

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
              if (_editionMode)
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Icon(
                    isDette ? Icons.lock : Icons.drag_handle,
                    color: isDette ? Colors.grey : Colors.white38,
                    size: 16,
                  ),
                ),
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
                  onPressed: () => _renommerEnveloppe(categorie, enveloppe),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                    size: 18,
                  ),
                  tooltip: 'Supprimer l\'enveloppe',
                  onPressed: () => _supprimerEnveloppe(categorie, enveloppe),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ] else ...[
                Builder(
                  builder: (context) {
                    return GestureDetector(
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PageSetObjectif(
                              categorie: categorie,
                              enveloppe: enveloppe,
                            ),
                          ),
                        );
                        // TODO: gérer la mise à jour de l'objectif si besoin
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
