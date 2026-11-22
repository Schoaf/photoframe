import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../services/ha_client.dart';
import '../state/ha_info.dart';
import '../utils/ha_icons.dart';
import 'ha_overlay.dart';

/// Closes on its own, so it doesn't stay over the photos all day.
const _openFor = Duration(minutes: 1);

/// Shows what the running appliance [name] reports. Live, and closes when
/// the appliance stops.
Future<void> showDeviceCard(BuildContext context, String name) =>
    showDialog<void>(
      context: context,
      builder: (_) => _DeviceCard(name: name),
    );

/// `40` °C → `40 °C`, a time → `14:30` (with the date when not today).
String formatPropertyValue(
  DeviceProperty property,
  String locale,
  DateTime now,
) {
  final value = property.value;
  if (RegExp(r'^\d{4}-\d{2}-\d{2}T').hasMatch(value)) {
    final time = DateTime.tryParse(value)?.toLocal();
    if (time != null) {
      final isToday =
          time.year == now.year &&
          time.month == now.month &&
          time.day == now.day;
      return (isToday
              ? DateFormat.Hm(locale)
              : DateFormat.MMMd(locale).add_Hm())
          .format(time);
    }
  }
  final number = num.tryParse(value);
  final text = number == null
      ? value
      : NumberFormat('#,##0.#', locale).format(number);
  final unit = property.unit;
  return unit == null || unit.isEmpty ? text : '$text $unit';
}

class _DeviceCard extends ConsumerStatefulWidget {
  const _DeviceCard({required this.name});

  final String name;

  @override
  ConsumerState<_DeviceCard> createState() => _DeviceCardState();
}

class _DeviceCardState extends ConsumerState<_DeviceCard> {
  late final Timer _close;
  bool _isClosed = false;

  @override
  void initState() {
    super.initState();
    _close = Timer(_openFor, _pop);
  }

  @override
  void dispose() {
    _close.cancel();
    super.dispose();
  }

  void _pop() {
    if (_isClosed || !mounted) return;
    _isClosed = true;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final device = ref
        .watch(haInfoProvider)
        .running
        .where((device) => device.name == widget.name)
        .firstOrNull;
    if (device == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _pop());
      return const SizedBox.shrink();
    }
    final now = DateTime.now();
    final remaining = device.remaining(now);
    final fraction = device.fraction(now);
    final theme = Theme.of(context);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 160, vertical: 48),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 16,
            children: [
              Row(
                spacing: 16,
                children: [
                  Icon(warningIcon(device.icon), size: 56),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(device.name, style: theme.textTheme.headlineSmall),
                        if (remaining != null || device.isOverdue(now))
                          Text(
                            remainingText(
                              l10n,
                              remaining == null
                                  ? null
                                  : (remaining.inSeconds / 60).ceil(),
                            ),
                            style: theme.textTheme.titleMedium,
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    iconSize: 32,
                    onPressed: _pop,
                  ),
                ],
              ),
              if (fraction != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(value: fraction, minHeight: 8),
                ),
              Flexible(
                child: SingleChildScrollView(
                  child: Table(
                    columnWidths: const {
                      0: FlexColumnWidth(),
                      1: IntrinsicColumnWidth(),
                    },
                    children: [
                      for (final property in device.properties)
                        TableRow(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Text(
                                property.name,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 24,
                                top: 6,
                                bottom: 6,
                              ),
                              child: Text(
                                formatPropertyValue(property, locale, now),
                                style: theme.textTheme.bodyLarge,
                                textAlign: TextAlign.end,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
