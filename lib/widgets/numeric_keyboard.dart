import 'package:flutter/material.dart';

class NumericKeyboard extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback? onClear;
  final bool showDecimal;
  final Function(String)? onValueChanged;
  final VoidCallback? onDone;
  final bool isMoney;
  final bool showDone;

  const NumericKeyboard({
    super.key,
    required this.controller,
    this.onClear,
    this.showDecimal = true,
    this.onValueChanged,
    this.onDone,
    this.isMoney = true,
    this.showDone = true,
  });

  @override
  State<NumericKeyboard> createState() => _NumericKeyboardState();
}

class _NumericKeyboardState extends State<NumericKeyboard> {
  void _onKeyTap(String key) {
    if (widget.isMoney) {
      String currentText = widget.controller.text;
      if (currentText != '0.00 \$') {
        currentText = currentText.replaceAll('\$', '').replaceAll(' ', '');
      }
      if (currentText == '0.00' ||
          currentText == '0.00 \$' ||
          currentText.isEmpty) {
        if (key == '-') {
          widget.controller.text = '-0.00 \$';
        } else {
          widget.controller.text = '0.0$key \$';
        }
      } else if (key == '-') {
        if (currentText.startsWith('-')) {
          widget.controller.text = '${currentText.substring(1)} \$';
        } else {
          widget.controller.text = '-$currentText \$';
        }
      } else {
        bool isNegative = currentText.startsWith('-');
        String positiveText =
            (isNegative ? currentText.substring(1) : currentText).replaceAll(
          '.',
          '',
        );

        String newText = positiveText + key;

        while (newText.length > 1 && newText.startsWith('0')) {
          newText = newText.substring(1);
        }

        if (newText.length < 3) {
          newText = newText.padLeft(3, '0');
        }

        String partieEntiere = newText.substring(0, newText.length - 2);
        String partieDecimale = newText.substring(newText.length - 2);

        String result = '$partieEntiere.$partieDecimale \$';
        widget.controller.text = isNegative ? '-$result' : result;
      }
    } else {
      String currentText = widget.controller.text;

      if (key == '.') {
        if (!currentText.contains('.')) {
          widget.controller.text = currentText.isEmpty ? '0.' : '$currentText.';
        }
      } else {
        if (currentText == '0') {
          widget.controller.text = key;
        } else {
          widget.controller.text = currentText + key;
        }
      }
    }
    widget.controller.selection = TextSelection.fromPosition(
      TextPosition(offset: widget.controller.text.length),
    );
    widget.onValueChanged?.call(widget.controller.text);
  }

  void _onBackspace() {
    if (widget.isMoney) {
      String currentText =
          widget.controller.text.replaceAll('\$', '').replaceAll(' ', '');

      bool isNegative = currentText.startsWith('-');
      String positiveText =
          (isNegative ? currentText.substring(1) : currentText).replaceAll(
        '.',
        '',
      );

      if (positiveText.length > 1) {
        positiveText = positiveText.substring(0, positiveText.length - 1);
      } else {
        positiveText = '0';
      }

      if (positiveText.length < 3) {
        positiveText = positiveText.padLeft(3, '0');
      }

      String partieEntiere = positiveText.substring(0, positiveText.length - 2);
      String partieDecimale = positiveText.substring(positiveText.length - 2);
      String result = '$partieEntiere.$partieDecimale \$';

      if (isNegative && result != '0.00 \$') {
        widget.controller.text = '-$result';
      } else {
        widget.controller.text = result;
      }
    } else {
      String currentText = widget.controller.text;
      if (currentText.length > 1) {
        widget.controller.text = currentText.substring(
          0,
          currentText.length - 1,
        );
      } else {
        widget.controller.text = '0';
      }
    }
    widget.controller.selection = TextSelection.fromPosition(
      TextPosition(offset: widget.controller.text.length),
    );
    widget.onValueChanged?.call(widget.controller.text);
  }

  Widget _buildOvalButton(
    String label, {
    VoidCallback? onTap,
    Color? color,
    Color? textColor,
    IconData? icon,
    bool filled = true,
    bool zeroPadding = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 2.0),
      child: SizedBox(
        width: 85,
        height: 44,
        child: ElevatedButton(
          onPressed: onTap ?? () => _onKeyTap(label),
          style: ElevatedButton.styleFrom(
            backgroundColor: filled
                ? (color ?? Theme.of(context).colorScheme.primary)
                : Colors.transparent,
            foregroundColor:
                textColor ?? Theme.of(context).colorScheme.onPrimary,
            elevation: filled ? 2 : 0,
            shape: const StadiumBorder(),
            textStyle: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
            padding: zeroPadding ? EdgeInsets.zero : null,
          ),
          child: icon != null
              ? Icon(
                  icon,
                  size: 22,
                  color: textColor ?? Theme.of(context).colorScheme.onPrimary,
                )
              : Text(
                  label,
                  style: TextStyle(
                    color: textColor ?? Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.only(top: 12, left: 16, right: 16, bottom: 8),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SizedBox(
                  width: 213,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: widget.controller,
                        builder: (context, value, child) {
                          String displayText = value.text.isEmpty
                              ? (widget.isMoney ? '0.00 \$' : '0')
                              : value.text;
                          return Text(
                            displayText,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            textAlign: TextAlign.left,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          );
                        },
                      ),
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        height: 2,
                        width: 213,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 35),
                widget.showDone
                    ? Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 6.0,
                          horizontal: 2.0,
                        ),
                        child: SizedBox(
                          width: 85,
                          height: 44,
                          child: ElevatedButton(
                            onPressed: widget.onDone ??
                                () => Navigator.of(context).maybePop(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .secondaryContainer,
                              foregroundColor:
                                  Theme.of(context).colorScheme.primary,
                              elevation: 2,
                              shape: const StadiumBorder(),
                              padding: EdgeInsets.zero,
                            ),
                            child: const Icon(
                              Icons.check,
                              size: 22,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      )
                    : const SizedBox(width: 85),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildOvalButton('1'),
                const SizedBox(width: 35),
                _buildOvalButton('2'),
                const SizedBox(width: 35),
                _buildOvalButton('3'),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildOvalButton('4'),
                const SizedBox(width: 35),
                _buildOvalButton('5'),
                const SizedBox(width: 35),
                _buildOvalButton('6'),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildOvalButton('7'),
                const SizedBox(width: 35),
                _buildOvalButton('8'),
                const SizedBox(width: 35),
                _buildOvalButton('9'),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildOvalButton(
                  widget.isMoney ? '-' : (widget.showDecimal ? '.' : ''),
                ),
                const SizedBox(width: 35),
                _buildOvalButton('0'),
                const SizedBox(width: 35),
                _buildOvalButton(
                  '',
                  onTap: _onBackspace,
                  color: Colors.grey.shade200,
                  textColor: Colors.black,
                  icon: Icons.backspace_outlined,
                  filled: true,
                  zeroPadding: true,
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
