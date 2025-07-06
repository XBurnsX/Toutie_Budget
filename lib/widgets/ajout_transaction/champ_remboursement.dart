import 'package:flutter/material.dart';
import '../../controllers/ajout_transaction_controller.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../themes/dropdown_theme_extension.dart';

/// Dropdown permettant de sélectionner une carte de crédit ou une dette lorsque
/// le type de mouvement est `remboursementEffectue`.
/// - Les cartes de crédit proviennent de `ajoutController.listeComptesAffichables`
/// - Les dettes sont chargées dynamiquement depuis la collection `dettes` dans
///   Firestore. Le champ `nomTiers` est utilisé comme libellé.
/// Le widget met à jour `controller.text` afin de conserver la compatibilité
/// avec le reste du flux qui s'attend à trouver le nom du tiers dans ce champ.
class ChampRemboursement extends StatefulWidget {
  final TextEditingController controller;
  final AjoutTransactionController ajoutController;

  const ChampRemboursement({
    super.key,
    required this.controller,
    required this.ajoutController,
  });

  @override
  State<ChampRemboursement> createState() => _ChampRemboursementState();
}

class _ChampRemboursementState extends State<ChampRemboursement> {
  late Future<List<_OptionItem>>
      _futureDettes; // Les dettes sont récupérées une seule fois

  @override
  void initState() {
    super.initState();
    _futureDettes = _chargerDettes();
    // Re-construire quand les comptes sont chargés/rafraîchis
    widget.ajoutController.addListener(_onControllerChange);
  }

  @override
  void dispose() {
    widget.ajoutController.removeListener(_onControllerChange);
    super.dispose();
  }

  void _onControllerChange() {
    // Déclenche un rebuild pour afficher les nouvelles cartes
    if (mounted) setState(() {});
  }

  Future<List<_OptionItem>> _chargerDettes() async {
    final options = <_OptionItem>[];
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return options;
    final snapshot = await FirebaseFirestore.instance
        .collection('dettes')
        .where('userId', isEqualTo: user.uid)
        .get();
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final nomTiers = (data['nomTiers'] ?? data['nom'] ?? '').toString();
      final type = (data['type'] ?? '').toString();

      if (nomTiers.isEmpty) continue;

      // Pour les remboursements effectués, on ne montre que les dettes contractées
      // (pas les prêts accordés car on ne peut pas "rembourser" un prêt qu'on a accordé)
      if (type == 'dette') {
        // Récupérer la couleur de la dette (par défaut rouge pour les dettes)
        final couleur = data['couleur'] != null
            ? Color(data['couleur'] as int)
            : Colors.red;

        options.add(_OptionItem(
          id: doc.id,
          label: nomTiers,
          type: 'dette',
          couleur: couleur,
        ));
      }
    }
    return options;
  }

  @override
  Widget build(BuildContext context) {
    // Couleur automatique du thème pour les dropdowns
    final dropdownColor = Theme.of(context).dropdownColor;

    return FutureBuilder<List<_OptionItem>>(
      future: _futureDettes,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        // Construire la liste complète (cartes en premier, puis dettes)
        final options = <_OptionItem>[];

        // 1. Cartes de crédit (en haut)
        final cartes = widget.ajoutController.listeComptesAffichables
            .where((c) => c.type == 'Carte de crédit')
            .toList();
        for (final carte in cartes) {
          options.add(_OptionItem(
            id: carte.id,
            label: carte.nom,
            type: 'compte',
            couleur: Color(carte.couleur),
          ));
        }

        // 2. Dettes depuis Future (en bas)
        final dettes = snapshot.data ?? [];
        for (final dette in dettes) {
          options.add(_OptionItem(
            id: dette.id,
            label: dette.label,
            type: dette.type,
            couleur: dette.couleur,
          ));
        }
        if (options.isEmpty) {
          return const Text('Aucune carte ou dette trouvée');
        }
        // Supprimer les doublons éventuels (même libellé)
        final seenLabels = <String>{};
        final deduped = <_OptionItem>[];
        for (final o in options) {
          final key = o.label.toLowerCase().trim();
          if (!seenLabels.contains(key)) {
            deduped.add(o);
            seenLabels.add(key);
          }
        }

        // Tri : cartes de crédit d'abord, puis dettes, puis tri alphabétique dans chaque groupe
        deduped.sort((a, b) {
          // D'abord par type (compte avant dette)
          if (a.type != b.type) {
            return a.type == 'compte' ? -1 : 1;
          }
          // Puis alphabétiquement dans le même type
          return a.label.toLowerCase().compareTo(b.label.toLowerCase());
        });

        // Déterminer la valeur sélectionnée actuelle à partir du controller
        String? selectedId;
        final currentLabel = widget.controller.text.trim();
        if (currentLabel.isNotEmpty) {
          final match = deduped.firstWhere(
            (o) => o.label.toLowerCase() == currentLabel.toLowerCase(),
            orElse: () =>
                _OptionItem(id: '', label: '', type: '', couleur: Colors.grey),
          );
          if (match.id.isNotEmpty) selectedId = match.id;
        }

        return DropdownButtonFormField<String>(
          value: selectedId,
          items: deduped
              .map(
                (o) => DropdownMenuItem<String>(
                  value: o.id,
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: o.couleur,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          o.label,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: o.couleur),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
          onChanged: (value) {
            final opt = options.firstWhere((o) => o.id == value);
            // Mettre à jour le TextEditingController pour conserver la logique existante
            widget.controller.text = opt.label;
            // Informer le controller principal
            widget.ajoutController.setRemboursementSelection(opt.id, opt.type);
            setState(() {}); // Met à jour la sélection locale
          },
          decoration: const InputDecoration(
            hintText: 'Sélectionner une carte ou une dette',
            border: InputBorder.none,
            isDense: true,
            contentPadding:
                EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
          ),
          isExpanded: true,
          dropdownColor: dropdownColor,
          alignment: Alignment.centerLeft,
        );
      },
    );
  }
}

class _OptionItem {
  final String id;
  final String label;
  final String type; // 'compte' ou 'dette'
  final Color couleur;

  _OptionItem({
    required this.id,
    required this.label,
    required this.type,
    required this.couleur,
  });
}
