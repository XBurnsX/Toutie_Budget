import 'package:flutter/material.dart';
import 'package:toutie_budget/models/compte.dart';
import 'package:toutie_budget/services/firebase_service.dart';
import 'page_creation_compte.dart';
import 'page_transactions_compte.dart';

class PageComptesReorder extends StatefulWidget {
  const PageComptesReorder({super.key});

  @override
  State<PageComptesReorder> createState() => _PageComptesReorderState();
}

class _PageComptesReorderState extends State<PageComptesReorder> {
  bool _editionMode = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes comptes'),
        actions: [
          IconButton(
            tooltip: _editionMode ? 'Valider l\'ordre' : 'Réorganiser',
            icon: Icon(_editionMode ? Icons.check : Icons.swap_vert),
            onPressed: () => setState(() => _editionMode = !_editionMode),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Ajouter',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PageCreationCompte()),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Compte>>(
        stream: FirebaseService().lireComptes(),
        builder: (context, snapshot) {
          final comptes = (snapshot.data ?? [])
              .where((c) => c.estArchive == false)
              .toList()
            ..sort((a, b) => (a.ordre ?? 999999).compareTo(b.ordre ?? 999999));

          final cheques = comptes.where((c) => c.type == 'Chèque').toList();
          final credits =
              comptes.where((c) => c.type == 'Carte de crédit').toList();
          final investissements =
              comptes.where((c) => c.type == 'Investissement').toList();

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: [
              _buildSection('Comptes chèques', Colors.blue, cheques),
              _buildSection('Cartes de crédit', Colors.purple, credits),
              _buildSection('Investissement', Colors.green, investissements),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSection(String title, Color color, List<Compte> comptes) {
    if (comptes.isEmpty) return const SizedBox.shrink();

    if (_editionMode) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            child: Text(title,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white70)),
          ),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: comptes.length,
            onReorder: (oldIndex, newIndex) =>
                _reorder(comptes, oldIndex, newIndex),
            buildDefaultDragHandles: false,
            itemBuilder: (context, index) {
              final compte = comptes[index];
              return ReorderableDragStartListener(
                key: ValueKey(compte.id),
                index: index,
                child: _buildCard(compte, color, editing: true),
              );
            },
          ),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            child: Text(title,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white70)),
          ),
          ...comptes.map((c) => _buildCard(c, color)),
        ],
      );
    }
  }

  Widget _buildCard(Compte compte, Color color, {bool editing = false}) {
    final isCheque = compte.type == 'Chèque';
    final soldeAffiche = compte.solde;

    return Container(
      key: ValueKey(compte.id),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        elevation: 2,
        color: const Color(0xFF232526),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: editing
              ? null
              : () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PageTransactionsCompte(compte: compte),
                    ),
                  );
                },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Color(compte.couleur),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        compte.nom,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        compte.type,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${soldeAffiche.toStringAsFixed(2)} \$',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: soldeAffiche >= 0
                            ? Colors.green[700]
                            : Colors.red[700],
                      ),
                    ),
                    if (isCheque)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Color(compte.couleur),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Prêt à placer: ${compte.pretAPlacer.toStringAsFixed(2)} \$',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.black,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 8),
                editing
                    ? const Icon(Icons.drag_handle, color: Colors.white54)
                    : Icon(Icons.chevron_right, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _reorder(
      List<Compte> section, int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) newIndex -= 1;
    final item = section.removeAt(oldIndex);
    section.insert(newIndex, item);

    // Met à jour l\'ordre dans Firestore pour cette section uniquement.
    for (var i = 0; i < section.length; i++) {
      await FirebaseService().updateCompte(section[i].id, {'ordre': i});
    }

    setState(() {}); // Rafraîchir l\'UI
  }
}
