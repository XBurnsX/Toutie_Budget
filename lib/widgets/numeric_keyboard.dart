import 'package:flutter/material.dart';

class NumericKeyboard extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback? onClear;
  final bool showDecimal;
  final Function(String)? onValueChanged;

  const NumericKeyboard({
    Key? key,
    required this.controller,
    this.onClear,
    this.showDecimal = true,
    this.onValueChanged,
  }) : super(key: key);

  @override
  State<NumericKeyboard> createState() => _NumericKeyboardState();
}

class _NumericKeyboardState extends State<NumericKeyboard> {
  void _onKeyTap(String key) {
    String currentText = widget.controller.text;
    // Nettoyer le symbole $ et les espaces du texte actuel, sauf si c'est exactement "0.00 $"
    if (currentText != '0.00 \$') {
      currentText = currentText.replaceAll('\$', '').replaceAll(' ', '');
    }
    print('DEBUG: _onKeyTap - key: $key, currentText: $currentText');

    // Si c'est le premier chiffre ou si on est à 0.00
    if (currentText == '0.00' ||
        currentText == '0.00 \$' ||
        currentText.isEmpty) {
      if (key == '.') {
        widget.controller.text = '0.';
      } else {
        widget.controller.text = '0.0$key \$';
      }
      print('DEBUG: Premier chiffre - result: ${widget.controller.text}');
    } else if (key == '.') {
      // Gérer le point décimal manuel
      if (!currentText.contains('.')) {
        widget.controller.text = currentText + '.';
      }
      print('DEBUG: Point décimal - result: ${widget.controller.text}');
    } else {
      // Logique de calculatrice : décaler vers la gauche
      if (currentText.contains('.')) {
        List<String> parts = currentText.split('.');
        if (parts.length == 2) {
          // Décaler tous les chiffres vers la gauche
          String newText = parts[0] + parts[1] + key;

          // Si on a 3 chiffres ou plus, insérer le point décimal avant les 2 derniers
          if (newText.length >= 3) {
            String partieEntiere = newText.substring(0, newText.length - 2);
            String partieDecimale = newText.substring(newText.length - 2);
            // Supprimer les zéros en tête
            while (partieEntiere.startsWith('0') && partieEntiere.length > 1) {
              partieEntiere = partieEntiere.substring(1);
            }
            widget.controller.text = '$partieEntiere.$partieDecimale \$';
          } else {
            // Moins de 3 chiffres, ajouter 0. devant
            widget.controller.text = '0.$newText \$';
          }
        }
      } else {
        // Pas de point décimal, ajouter le chiffre
        String newText = currentText + key;
        if (newText.length >= 3) {
          String partieEntiere = newText.substring(0, newText.length - 2);
          String partieDecimale = newText.substring(newText.length - 2);
          // Supprimer les zéros en tête
          while (partieEntiere.startsWith('0') && partieEntiere.length > 1) {
            partieEntiere = partieEntiere.substring(1);
          }
          widget.controller.text = '$partieEntiere.$partieDecimale \$';
        } else {
          widget.controller.text = '0.$newText \$';
        }
      }
      print(
        'DEBUG: Décalage vers la gauche - result: ${widget.controller.text}',
      );
    }

    widget.controller.selection = TextSelection.fromPosition(
      TextPosition(offset: widget.controller.text.length),
    );

    // Appeler le callback si fourni
    widget.onValueChanged?.call(widget.controller.text);
  }

  void _onBackspace() {
    final text = widget.controller.text;
    if (text.length > 1) {
      widget.controller.text = text.substring(0, text.length - 1);
    } else {
      widget.controller.text = '0.00';
    }

    widget.controller.selection = TextSelection.fromPosition(
      TextPosition(offset: widget.controller.text.length),
    );
  }

  void _onClear() {
    widget.controller.text = '0.00 \$';
    widget.onClear?.call();
  }

  Widget _buildKey(String label, {VoidCallback? onTap}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: ElevatedButton(
          onPressed: onTap ?? () => _onKeyTap(label),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(label, style: const TextStyle(fontSize: 22)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(children: [_buildKey('1'), _buildKey('2'), _buildKey('3')]),
        Row(children: [_buildKey('4'), _buildKey('5'), _buildKey('6')]),
        Row(children: [_buildKey('7'), _buildKey('8'), _buildKey('9')]),
        Row(
          children: [
            widget.showDecimal ? _buildKey('.') : const Spacer(),
            _buildKey('0'),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: ElevatedButton(
                  onPressed: _onBackspace,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Icon(Icons.backspace_outlined),
                ),
              ),
            ),
          ],
        ),
        if (widget.onClear != null)
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: ElevatedButton(
                    onPressed: _onClear,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Effacer',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}
