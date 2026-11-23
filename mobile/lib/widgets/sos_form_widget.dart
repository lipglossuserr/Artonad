// SOS form (N1's component, agreed interface). Input only: no networking, GPS
// or validation beyond what the controls allow; Dev3's app layer owns those.
//
// N1's original delivery (dropdown + stepper, no loading/error state, no
// limits) is kept for reference in tool/n1/sos_form_widget.original.dart.txt.
// This version adds the agreed interface (SosFormData, isSubmitting,
// errorMessage), people count 1-100, a 500-character note limit and the
// accessibility/UX work, and keeps N1's optional initialEmergencyType and
// initialPeopleCount parameters.
import 'dart:math' as math;

import 'package:flutter/material.dart';

class SosFormData {
  const SosFormData({
    required this.type,
    required this.peopleCount,
    required this.note,
  });

  /// 'FIRE' or 'DROWNING'.
  final String type;
  final int peopleCount;
  final String note;
}

class SosFormWidget extends StatefulWidget {
  const SosFormWidget({
    super.key,
    required this.onSubmit,
    this.isSubmitting = false,
    this.errorMessage,
    this.initialEmergencyType,
    this.initialPeopleCount = 1,
  });

  final void Function(SosFormData data) onSubmit;
  final bool isSubmitting;
  final String? errorMessage;

  /// Optional preselection: 'FIRE' or 'DROWNING'. Anything else (or null)
  /// leaves nothing selected, so the user must choose explicitly.
  final String? initialEmergencyType;

  /// Starting people count; clamped to 1..100.
  final int initialPeopleCount;

  @override
  State<SosFormWidget> createState() => _SosFormWidgetState();
}

class _SosFormWidgetState extends State<SosFormWidget> {
  static const int _minPeople = 1;
  static const int _maxPeople = 100;

  final _noteController = TextEditingController();
  late String? _type;
  late int _peopleCount;
  bool _showTypeError = false;
  final _errorKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    final initial = widget.initialEmergencyType;
    _type = (initial == 'FIRE' || initial == 'DROWNING') ? initial : null;
    _peopleCount = math.max(
        _minPeople, math.min(_maxPeople, widget.initialPeopleCount));
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(SosFormWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialEmergencyType != widget.initialEmergencyType) {
      final initial = widget.initialEmergencyType;
      _type = (initial == 'FIRE' || initial == 'DROWNING') ? initial : null;
      _showTypeError = false;
    }
    if (oldWidget.initialPeopleCount != widget.initialPeopleCount) {
      _peopleCount = math.max(
          _minPeople, math.min(_maxPeople, widget.initialPeopleCount));
    }
    // A new failure: make sure it is on screen (small phones scroll).
    if (widget.errorMessage != null && oldWidget.errorMessage == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _errorKey.currentContext;
        if (ctx != null && ctx.mounted) {
          Scrollable.ensureVisible(ctx,
              alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd);
        }
      });
    }
  }

  void _selectType(String type) => setState(() {
        _type = type;
        _showTypeError = false;
      });

  void _submit() {
    if (widget.isSubmitting) return;
    if (_type == null) {
      setState(() => _showTypeError = true);
      return;
    }
    widget.onSubmit(SosFormData(
      type: _type!,
      peopleCount: _peopleCount,
      note: _noteController.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final busy = widget.isSubmitting;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Emergency type: two large, mutually exclusive choices.
        Text('1. What is the emergency?',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _TypeCard(
                label: 'Fire',
                icon: Icons.local_fire_department,
                selected: _type == 'FIRE',
                onTap: busy ? null : () => _selectType('FIRE'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _TypeCard(
                label: 'Drowning',
                icon: Icons.pool,
                selected: _type == 'DROWNING',
                onTap: busy ? null : () => _selectType('DROWNING'),
              ),
            ),
          ],
        ),
        if (_showTypeError)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Select the type of emergency',
                key: const Key('type_error'),
                style: theme.textTheme.bodyLarge?.copyWith(
                    color: scheme.error, fontWeight: FontWeight.w600)),
          ),

        // 2. People count: big -/+ buttons around a large number.
        const SizedBox(height: 24),
        Text('2. How many people need help?',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton.filledTonal(
              key: const Key('people_decrement'),
              tooltip: 'Fewer people',
              iconSize: 32,
              style: IconButton.styleFrom(minimumSize: const Size(56, 56)),
              icon: const Icon(Icons.remove),
              onPressed: (busy || _peopleCount <= _minPeople)
                  ? null
                  : () => setState(() => _peopleCount--),
            ),
            SizedBox(
              width: 112,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$_peopleCount',
                    key: const Key('people_count_value'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.displaySmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    _peopleCount == 1 ? 'person' : 'people',
                    key: const Key('people_count_unit'),
                    style: theme.textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
            IconButton.filledTonal(
              key: const Key('people_increment'),
              tooltip: 'More people',
              iconSize: 32,
              style: IconButton.styleFrom(minimumSize: const Size(56, 56)),
              icon: const Icon(Icons.add),
              onPressed: (busy || _peopleCount >= _maxPeople)
                  ? null
                  : () => setState(() => _peopleCount++),
            ),
          ],
        ),

        // 3. Optional note.
        const SizedBox(height: 24),
        Text('3. Add details (optional)',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          key: const Key('note_field'),
          controller: _noteController,
          enabled: !busy,
          minLines: 2,
          maxLines: 4,
          maxLength: 500, // backend limit; the service enforces it too
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Note (optional)',
            helperText: 'Anything that helps responders find or help you.',
            border: OutlineInputBorder(),
          ),
        ),

        if (widget.errorMessage != null) ...[
          const SizedBox(height: 16),
          Semantics(
            key: _errorKey,
            liveRegion: true,
            child: Container(
              key: const Key('sos_error'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline, color: scheme.onErrorContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('SOS not confirmed',
                            key: const Key('sos_error_title'),
                            style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: scheme.onErrorContainer)),
                        const SizedBox(height: 4),
                        Text(widget.errorMessage!,
                            style: theme.textTheme.bodyLarge
                                ?.copyWith(color: scheme.onErrorContainer)),
                        const SizedBox(height: 8),
                        Text('Tap SEND SOS to try again.',
                            style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: scheme.onErrorContainer)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        const SizedBox(height: 24),
        FilledButton(
          key: const Key('sos_submit_button'),
          onPressed: busy ? null : _submit,
          style: FilledButton.styleFrom(
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
            // Lighter red while sending, still readable with white content.
            disabledBackgroundColor:
                Color.alphaBlend(scheme.surface.withAlpha(80), scheme.error),
            disabledForegroundColor: scheme.onError,
            minimumSize: const Size.fromHeight(72),
            textStyle:
                const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          child: busy
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    SizedBox(
                      height: 26,
                      width: 26,
                      child: CircularProgressIndicator(
                          strokeWidth: 3, color: Colors.white),
                    ),
                    SizedBox(width: 12),
                    Flexible(child: Text('Sending SOS…')),
                  ],
                )
              : const Text('SEND SOS'),
        ),
        if (busy)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Semantics(
              liveRegion: true,
              child: Text(
                'Getting your location and sending your SOS. Please wait.',
                key: const Key('sos_sending_status'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
            ),
          ),
      ],
    );
  }
}

/// A large selectable choice. Selection is shown by a thick border, a tinted
/// fill AND a check icon, so it does not rely on colour alone.
class _TypeCard extends StatelessWidget {
  const _TypeCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final radius = BorderRadius.circular(16);
    return Semantics(
      button: true,
      selected: selected,
      enabled: onTap != null,
      child: Material(
        color: selected ? scheme.primaryContainer : scheme.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: selected ? scheme.primary : scheme.outline,
            width: selected ? 3 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 104),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon,
                      size: 40,
                      color: selected
                          ? scheme.onPrimaryContainer
                          : scheme.onSurface),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: selected
                            ? scheme.onPrimaryContainer
                            : scheme.onSurface,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 24,
                    child: selected
                        ? Icon(Icons.check_circle, color: scheme.primary)
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
