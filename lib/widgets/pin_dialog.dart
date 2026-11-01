import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

/// Big on-screen keypad (no system keyboard needed). Returns true when
/// [pin] was entered.
Future<bool> showPinDialog(BuildContext context, {required String pin}) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => _PinDialog(pin: pin),
    ) ??
    false;

class _PinDialog extends StatefulWidget {
  const _PinDialog({required this.pin});

  final String pin;

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  String _entered = '';
  bool _isWrong = false;

  void _press(String digit) {
    setState(() {
      _isWrong = false;
      _entered += digit;
    });
    if (_entered.length < widget.pin.length) return;
    if (_entered == widget.pin) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _entered = '';
        _isWrong = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Widget key(String label, {VoidCallback? onPressed}) => SizedBox.square(
      dimension: AppSizes.keypadButton,
      child: FilledButton.tonal(
        onPressed: onPressed ?? () => _press(label),
        style: FilledButton.styleFrom(shape: const CircleBorder()),
        child: Text(label, style: const TextStyle(fontSize: 28)),
      ),
    );
    final rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
    ];
    return AlertDialog(
      title: Text(_isWrong ? l10n.pinWrong : l10n.pinEnter),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '●' * _entered.length + '○' * (widget.pin.length - _entered.length),
            style: const TextStyle(fontSize: 28, letterSpacing: 8),
          ),
          const SizedBox(height: 16),
          for (final row in [...rows, null])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 12,
                children: row == null
                    ? [
                        key('✕', onPressed: () => Navigator.of(context).pop(false)),
                        key('0'),
                        key(
                          '⌫',
                          onPressed: () => setState(
                            () => _entered = _entered.isEmpty
                                ? ''
                                : _entered.substring(0, _entered.length - 1),
                          ),
                        ),
                      ]
                    : [for (final digit in row) key(digit)],
              ),
            ),
        ],
      ),
    );
  }
}
