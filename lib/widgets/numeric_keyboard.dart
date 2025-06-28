import 'package:flutter/material.dart';

class NumericKeyboard extends StatelessWidget {
  final void Function(String) onKeyTap;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final bool showDecimal;
  const NumericKeyboard({
    Key? key,
    required this.onKeyTap,
    required this.onBackspace,
    required this.onClear,
    this.showDecimal = true,
  }) : super(key: key);

  Widget _buildKey(String label, {VoidCallback? onTap}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: ElevatedButton(
          onPressed: onTap ?? () => onKeyTap(label),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        Row(
          children: [
            _buildKey('1'),
            _buildKey('2'),
            _buildKey('3'),
          ],
        ),
        Row(
          children: [
            _buildKey('4'),
            _buildKey('5'),
            _buildKey('6'),
          ],
        ),
        Row(
          children: [
            _buildKey('7'),
            _buildKey('8'),
            _buildKey('9'),
          ],
        ),
        Row(
          children: [
            showDecimal
                ? _buildKey('.')
                : const Spacer(),
            _buildKey('0'),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: ElevatedButton(
                  onPressed: onBackspace,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Icon(Icons.backspace_outlined),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
