import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// A reusable on-screen numeric keypad matching the app's "Liquid Glass"
/// look — used wherever a short passcode needs entering without falling
/// back to the OS's full keyboard (see main.dart's kiosk-exit passcode
/// prompt). Auto-fires [onCompleted] once [length] digits are entered;
/// the caller can obtain a [GlobalKey<NumericKeypadState>] to call
/// [NumericKeypadState.clear] after a rejected attempt.
class NumericKeypad extends StatefulWidget {
  const NumericKeypad({
    super.key,
    this.length = 4,
    required this.onCompleted,
    this.errorText,
  });

  final int length;
  final ValueChanged<String> onCompleted;
  final String? errorText;

  @override
  State<NumericKeypad> createState() => NumericKeypadState();
}

class NumericKeypadState extends State<NumericKeypad> {
  String _digits = '';

  void clear() => setState(() => _digits = '');

  void _tapDigit(String digit) {
    if (_digits.length >= widget.length) return;
    setState(() => _digits += digit);
    if (_digits.length == widget.length) {
      widget.onCompleted(_digits);
    }
  }

  void _backspace() {
    if (_digits.isEmpty) return;
    setState(() => _digits = _digits.substring(0, _digits.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.length, (index) {
            final filled = index < _digits.length;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: filled ? colorScheme.primary : Colors.transparent,
                border: Border.all(color: colorScheme.primary, width: 1.6),
              ),
            );
          }),
        ),
        if (widget.errorText != null) ...[
          const SizedBox(height: 10),
          Text(
            widget.errorText!,
            textAlign: TextAlign.center,
            style: TextStyle(color: colorScheme.error, fontWeight: FontWeight.w600),
          ),
        ],
        const SizedBox(height: 20),
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
          ['', '0', 'back'],
        ])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [for (final key in row) _buildKey(key, colorScheme)],
            ),
          ),
      ],
    );
  }

  Widget _buildKey(String key, ColorScheme colorScheme) {
    if (key.isEmpty) {
      return const SizedBox(width: 64, height: 64);
    }

    final isBackspace = key == 'back';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: InkWell(
        key: Key(isBackspace ? 'keypad-backspace' : 'keypad-digit-$key'),
        borderRadius: BorderRadius.circular(32),
        onTap: isBackspace ? _backspace : () => _tapDigit(key),
        child: Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colorScheme.onSurface.withValues(alpha: 0.06),
            border: Border.all(color: colorScheme.onSurface.withValues(alpha: 0.12)),
          ),
          child: isBackspace
              ? FaIcon(FontAwesomeIcons.deleteLeft, size: 20, color: colorScheme.onSurfaceVariant)
              : Text(
                  key,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
        ),
      ),
    );
  }
}
