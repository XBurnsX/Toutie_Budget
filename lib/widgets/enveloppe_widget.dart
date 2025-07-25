import 'package:flutter/material.dart';
import 'package:toutie_budget/services/allocation_service.dart';
import 'package:toutie_budget/services/color_service.dart';
import 'package:toutie_budget/widgets/assignation_bottom_sheet.dart';

class EnveloppeWidget extends StatefulWidget {
  final Map<String, dynamic> enveloppe;
  final Map<String, dynamic> categorie;
  final List<Map<String, dynamic>> comptes;
  final String? selectedMonthKey;
  final bool editionMode;
  final Function(BuildContext, Map<String, dynamic>) showViderEnveloppeMenu;
  final Function(String, DateTime) getSoldeEnveloppe;
  final Function onAssignationComplete;

  const EnveloppeWidget({
    super.key,
    required this.enveloppe,
    required this.categorie,
    required this.comptes,
    required this.selectedMonthKey,
    required this.editionMode,
    required this.showViderEnveloppeMenu,
    required this.getSoldeEnveloppe,
    required this.onAssignationComplete,
  });

  @override
  State<EnveloppeWidget> createState() => _EnveloppeWidgetState();
}

class _EnveloppeWidgetState extends State<EnveloppeWidget> {
  late Future<double?> _soldeFuture;

  @override
  void initState() {
    super.initState();
    _soldeFuture = _calculateSolde();
  }

  @override
  void didUpdateWidget(EnveloppeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedMonthKey != oldWidget.selectedMonthKey) {
      setState(() {
        _soldeFuture = _calculateSolde();
      });
    }
  }

  Future<double?> _calculateSolde() {
    final enveloppeId = widget.enveloppe['id'] ?? 'unknown';
    final now = DateTime.now();
    final currentMonthKey =
        "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}";
    final moisKey = widget.selectedMonthKey ?? currentMonthKey;
    final moisAllocation = DateTime.parse('${moisKey}-01');
    return widget.getSoldeEnveloppe(enveloppeId, moisAllocation) as Future<double?>;
  }

  @override
  Widget build(BuildContext context) {
    final enveloppeId = widget.enveloppe['id'] ?? 'unknown';
    final enveloppeNom = widget.enveloppe['nom'] ?? 'Sans nom';

    final now = DateTime.now();
    final currentMonthKey =
        "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}";
    final moisKey = widget.selectedMonthKey ?? currentMonthKey;
    final moisAllocation = DateTime.parse('${moisKey}-01');
    final isFutureMonth =
        moisAllocation.isAfter(DateTime(now.year, now.month + 1, 0));

    if (isFutureMonth) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<double?>(
      future: _soldeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return Card(
            key: Key('loading_$enveloppeId'),
            color: const Color(0xFF232526),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                      child: Text('Chargement...',
                          style: TextStyle(color: Colors.white))),
                  SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Card(
            key: Key('error_$enveloppeId'),
            color: const Color(0xFF232526),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              child: Text('Erreur: $enveloppeNom',
                  style: const TextStyle(color: Colors.red)),
            ),
          );
        }

        final soldeAllocation = snapshot.data ?? 0.0;

        Map<String, dynamic> historique = widget.enveloppe['historique'] != null
            ? Map<String, dynamic>.from(widget.enveloppe['historique'])
            : {};
        Map<String, dynamic>? histoMois = (widget.selectedMonthKey != null &&
                historique[widget.selectedMonthKey] != null)
            ? Map<String, dynamic>.from(historique[widget.selectedMonthKey])
            : null;

        double soldeEnveloppe;
        if (widget.selectedMonthKey == null || widget.selectedMonthKey == currentMonthKey) {
          soldeEnveloppe = soldeAllocation;
        } else if (histoMois != null) {
          soldeEnveloppe = (histoMois['solde'] ?? 0.0).toDouble();
        } else {
          soldeEnveloppe = 0.0;
        }

        final bool estNegative = soldeEnveloppe < 0;

        return FutureBuilder<Color>(
          future: ColorService.getCouleurCompteSourceEnveloppeAsync(
            enveloppeId: enveloppeId,
            comptes: widget.comptes
                .map((c) => {
                      'id': c['id'],
                      'nom': c['nom'],
                      'couleur': c['couleur'],
                      'collection': c['collection'] ?? '',
                    })
                .toList(),
            solde: soldeEnveloppe,
            mois: moisAllocation,
          ),
          builder: (context, couleurSnapshot) {
            final bulleColor = couleurSnapshot.data ?? const Color(0xFF44474A);

            final cardWidget = Card(
              color: estNegative
                  ? Theme.of(context).colorScheme.error.withOpacity(0.15)
                  : const Color(0xFF232526),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (estNegative) ...[
                      Icon(Icons.warning, color: Colors.red[700], size: 20),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        enveloppeNom,
                        style: TextStyle(
                          color: estNegative ? Colors.red[800] : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: bulleColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '${soldeEnveloppe.toStringAsFixed(2)}\$',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
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
                          enveloppe: widget.enveloppe,
                          comptes: widget.comptes,
                          onAssignationComplete: () {
                            widget.onAssignationComplete();
                          },
                        ),
                      );
                    },
                    onLongPress: () {
                      if (soldeEnveloppe > 0) {
                        widget.showViderEnveloppeMenu(context, widget.enveloppe);
                      }
                    },
                    child: cardWidget,
                  );
          },
        );
      },
    );
  }
}

