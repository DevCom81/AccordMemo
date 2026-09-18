import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/piano/piano.dart';
import '../../domain/tuning/tuning.dart';
import '../app_providers.dart';
import '../formatters/french_date_label.dart';
import '../history/history_providers.dart';
import '../theme/app_colors.dart';
import 'clients_providers.dart';
import 'clients_strings.dart';
import 'correct_tuning_dialog.dart';

Future<void> showPianoTuningsDialog({
  required BuildContext context,
  required WidgetRef ref,
  required PianoId pianoId,
}) async {
  final tunings = await ref.read(tuningServiceProvider).findByPiano(pianoId);
  if (!context.mounted) {
    return;
  }
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return PianoTuningsDialog(
        initialTunings: tunings,
        loadTunings: () => ref.read(tuningServiceProvider).findByPiano(pianoId),
        onSelect: (tuning) {
          return showCorrectTuningDialog(
            context: dialogContext,
            ref: ref,
            tuning: tuning,
          );
        },
        onCorrected: () {
          ref.invalidate(selectedCustomerLatestTuningDatesProvider);
          ref.invalidate(dashboardSnapshotProvider);
          ref.invalidate(historySnapshotProvider);
        },
      );
    },
  );
}

class PianoTuningsDialog extends StatefulWidget {
  const PianoTuningsDialog({
    super.key,
    required this.initialTunings,
    required this.loadTunings,
    required this.onSelect,
    required this.onCorrected,
  });

  final List<Tuning> initialTunings;
  final Future<List<Tuning>> Function() loadTunings;
  final Future<bool> Function(Tuning tuning) onSelect;
  final VoidCallback onCorrected;

  @override
  State<PianoTuningsDialog> createState() => _PianoTuningsDialogState();
}

class _PianoTuningsDialogState extends State<PianoTuningsDialog> {
  late List<Tuning> _tunings;

  @override
  void initState() {
    super.initState();
    _tunings = widget.initialTunings;
  }

  Future<void> _openCorrection(Tuning tuning) async {
    final corrected = await widget.onSelect(tuning);
    if (!corrected || !mounted) {
      return;
    }
    widget.onCorrected();
    final tunings = await widget.loadTunings();
    if (!mounted) {
      return;
    }
    setState(() {
      _tunings = tunings;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(clientsPianoTuningsTitle),
      content: SizedBox(
        width: 420,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: _tunings.length,
            separatorBuilder: (context, index) =>
                const Divider(height: 1, color: AppColors.line),
            itemBuilder: (context, index) {
              final tuning = _tunings[index];
              final notes = tuning.notes;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(formatFrenchNumericDate(tuning.tuningDate)),
                subtitle: notes == null
                    ? null
                    : Text(
                        notes,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                onTap: () => _openCorrection(tuning),
              );
            },
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(clientsCancel),
        ),
      ],
    );
  }
}
