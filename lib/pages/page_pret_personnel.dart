import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/dette.dart';
import '../services/dette_service.dart';

class PagePretPersonnel extends StatefulWidget {
  const PagePretPersonnel({super.key});

  @override
  State<PagePretPersonnel> createState() => _PagePretPersonnelState();
}

class _PagePretPersonnelState extends State<PagePretPersonnel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DetteService _detteService = DetteService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prêts & Dettes'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'On me doit'),
            Tab(text: 'Je dois'),
            Tab(text: 'Archivés'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildListeDettes(type: 'pret', archive: false),
          _buildListeDettes(type: 'dette', archive: false),
          _buildListeDettes(type: null, archive: true),
        ],
      ),
    );
  }

  Widget _buildListeDettes({String? type, required bool archive}) {
    return StreamBuilder<List<Dette>>(
      stream: archive
          ? _detteService.dettesArchivees()
          : _detteService.dettesActives(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final dettes =
            snapshot.data
                ?.where((d) => type == null || d.type == type)
                .toList() ??
            [];
        if (dettes.isEmpty) {
          return const Center(child: Text('Aucune donnée.'));
        }
        return ListView.builder(
          itemCount: dettes.length,
          itemBuilder: (context, index) {
            final dette = dettes[index];
            String typeLabel = '';
            if (archive) {
              if (dette.type == 'pret') {
                typeLabel = ' (Prêt accordé)';
              } else if (dette.type == 'dette') {
                // Pour les dettes contractées, afficher "(Emprunt)" seulement si pas manuelle
                typeLabel = dette.estManuelle ? '' : ' (Emprunt)';
              }
            }

            return ListTile(
              title: Text('${dette.nomTiers}${archive ? typeLabel : ''}'),
              subtitle: archive
                  ? Text(
                      'Montant initial : ${dette.montantInitial.toStringAsFixed(2)}',
                    ) // Pas de solde pour les archivées
                  : Text(
                      'Montant initial : ${dette.montantInitial.toStringAsFixed(2)}\nSolde : ${dette.solde.toStringAsFixed(2)}',
                    ), // Avec solde pour les actives
              trailing: archive ? const Icon(Icons.archive) : null,
              onTap: () => _showDetailDette(dette),
            );
          },
        );
      },
    );
  }

  void _showDetailDette(Dette dette) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // En-tête avec informations principales
                  Row(
                    children: [
                      Icon(
                        dette.type == 'pret'
                            ? Icons.call_made
                            : Icons.call_received,
                        color: dette.type == 'pret'
                            ? Colors.green
                            : Colors.orange,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dette.type == 'pret'
                                  ? 'Prêt accordé à'
                                  : 'Dette envers',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              dette.nomTiers,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (dette.archive)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'ARCHIVÉ',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Informations financières
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Montant initial',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                '${dette.montantInitial.toStringAsFixed(2)} \$',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: Colors.grey.withOpacity(0.3),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                'Solde actuel',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                '${dette.solde.toStringAsFixed(2)} \$',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: dette.solde == 0
                                      ? Colors.green
                                      : (dette.type == 'pret'
                                            ? Colors.blue
                                            : Colors.orange),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Dates importantes
                  if (dette.archive && dette.dateArchivage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Soldé le ${DateFormat('dd/MM/yyyy').format(dette.dateArchivage!)}',
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  Text(
                    'Créé le ${DateFormat('dd/MM/yyyy').format(dette.dateCreation)}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),

                  // Historique des mouvements
                  const Text(
                    'Historique des mouvements',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),

                  Expanded(
                    child: dette.historique.isEmpty
                        ? const Center(
                            child: Text(
                              'Aucun mouvement',
                              style: TextStyle(
                                color: Colors.grey,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: dette.historique.length,
                            itemBuilder: (context, index) {
                              final mouvement = dette.historique[index];
                              return _buildMouvementItem(mouvement);
                            },
                          ),
                  ),

                  // Actions en bas
                  if (!dette.archive) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _ajouterRemboursement(dette),
                            icon: Icon(
                              dette.type == 'pret'
                                  ? Icons.call_made
                                  : Icons.call_received,
                            ),
                            label: Text(
                              dette.type == 'pret'
                                  ? 'Remboursement reçu'
                                  : 'Rembourser',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: dette.type == 'pret'
                                  ? Colors.green
                                  : Colors.orange,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => _archiverManuellement(dette),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Archiver'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMouvementItem(MouvementDette mouvement) {
    IconData icone;
    Color couleur;
    String libelle;

    switch (mouvement.type) {
      case 'pret':
        icone = Icons.call_made;
        couleur = Colors.blue;
        libelle = 'Prêt initial';
        break;
      case 'dette':
        icone = Icons.call_received;
        couleur = Colors.orange;
        libelle = 'Dette contractée';
        break;
      case 'remboursement_recu':
        icone = Icons.arrow_downward;
        couleur = Colors.green;
        libelle = 'Remboursement reçu';
        break;
      case 'remboursement_effectue':
        icone = Icons.arrow_upward;
        couleur = Colors.red;
        libelle = 'Remboursement effectué';
        break;
      default:
        icone = Icons.swap_horiz;
        couleur = Colors.grey;
        libelle = mouvement.type;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: couleur.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icone, color: couleur, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  libelle,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  DateFormat('dd/MM/yyyy à HH:mm').format(mouvement.date),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                if (mouvement.note?.isNotEmpty == true)
                  Text(
                    mouvement.note!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            '${mouvement.montant >= 0 ? '+' : ''}${mouvement.montant.toStringAsFixed(2)} \$',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: mouvement.montant >= 0 ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  void _ajouterRemboursement(Dette dette) {
    Navigator.pop(context); // Fermer le modal

    // Rediriger vers la page d'ajout de transaction avec les bonnes valeurs préremplies
    Navigator.pushNamed(
      context,
      '/ajout_transaction',
      arguments: {
        'typeRemboursement': dette.type == 'pret'
            ? 'remboursement_recu'
            : 'remboursement_effectue',
        'nomTiers': dette.nomTiers,
        'montantSuggere': dette.solde,
      },
    );
  }

  void _archiverManuellement(Dette dette) async {
    final bool? confirmer = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archiver cette dette'),
        content: Text(
          'Êtes-vous sûr de vouloir archiver ${dette.type == 'pret' ? 'ce prêt' : 'cette dette'} ? '
          'Cette action marquera la dette comme terminée même si le solde n\'est pas nul.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'Archiver',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmer == true) {
      try {
        await _detteService.archiverDette(dette.id);
        if (mounted) {
          Navigator.pop(context); // Fermer le modal de détails
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Dette archivée avec succès')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur lors de l\'archivage : $e')),
          );
        }
      }
    }
  }
}
