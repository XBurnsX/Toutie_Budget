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
            onPressed: () {
              setState(() {
                _editionMode = !_editionMode;
              });
            },
          ),
          StreamBuilder<List<Categorie>>(
            stream: FirebaseService().lireCategories(),
            builder: (context, snapshot) {
              final categories = snapshot.data ?? [];
              return IconButton(
                icon: const Icon(Icons.add),
                tooltip: 'Créer une catégorie',
                onPressed: () => _ajouterCategorie(categories),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),
            Expanded(
              child: StreamBuilder<List<Categorie>>(
                stream: FirebaseService().lireCategories(),
                builder: (context, snapshot) {
                  final categories = snapshot.data ?? [];
                  return ListView.builder(
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final categorie = categories[index];
                      return Column(
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
                                  icon: const Icon(
                                    Icons.edit,
                                    color: Colors.white70,
                                    size: 22,
                                  ),
                                  tooltip: 'Renommer la catégorie',
                                  onPressed: () =>
                                      _renommerCategorie(categorie),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.redAccent,
                                    size: 22,
                                  ),
                                  tooltip: 'Supprimer la catégorie',
                                  onPressed: () =>
                                      _supprimerCategorie(categorie),
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
                          ...categorie.enveloppes.map(
                            (enveloppe) => Card(
                              color: const Color(0xFF232526),
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 0,
                                ),
                                child: SizedBox(
                                  height: 40,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          enveloppe.nom,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (_editionMode) ...[
                                        IconButton(
                                          icon: const Icon(
                                            Icons.edit,
                                            color: Colors.white70,
                                            size: 18,
                                          ),
                                          tooltip: 'Renommer l\'enveloppe',
                                          onPressed: () => _renommerEnveloppe(
                                            categorie,
                                            enveloppe,
                                          ),
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
                                          onPressed: () => _supprimerEnveloppe(
                                            categorie,
                                            enveloppe,
                                          ),
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
                                                    builder: (context) =>
                                                        PageSetObjectif(
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
                                                  color:
                                                      (enveloppe.objectif > 0)
                                                      ? Colors.greenAccent
                                                      : Theme.of(
                                                          context,
                                                        ).colorScheme.primary,
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
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
