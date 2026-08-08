import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/glass.dart';

/// Poll-creation sheet — Dart port of PollCreatorModal.jsx.
Future<void> showPollCreatorBottomSheet(BuildContext context, {required void Function(String question, List<String> options) onCreate}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _PollCreatorSheet(onCreate: onCreate),
  );
}

class _PollCreatorSheet extends StatefulWidget {
  final void Function(String question, List<String> options) onCreate;
  const _PollCreatorSheet({required this.onCreate});

  @override
  State<_PollCreatorSheet> createState() => _PollCreatorSheetState();
}

class _PollCreatorSheetState extends State<_PollCreatorSheet> {
  final _questionController = TextEditingController();
  final List<TextEditingController> _optionControllers = [TextEditingController(), TextEditingController()];

  void _addOption() {
    if (_optionControllers.length >= 6) return;
    setState(() => _optionControllers.add(TextEditingController()));
  }

  void _submit() {
    final question = _questionController.text.trim();
    final options = _optionControllers.map((c) => c.text.trim()).where((o) => o.isNotEmpty).toList();
    if (question.isEmpty || options.length < 2) return;
    widget.onCreate(question, options);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: GlassSurface(
          borderRadius: BorderRadius.circular(24),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(999))),
                ),
                const Text('Create a poll', style: TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextField(
                  controller: _questionController,
                  maxLength: 140,
                  style: const TextStyle(color: AppColors.text),
                  decoration: const InputDecoration(hintText: 'Ask something…'),
                ),
                ...List.generate(
                  _optionControllers.length,
                  (i) => Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: TextField(
                      controller: _optionControllers[i],
                      maxLength: 60,
                      style: const TextStyle(color: AppColors.text),
                      decoration: InputDecoration(hintText: 'Option ${i + 1}'),
                    ),
                  ),
                ),
                if (_optionControllers.length < 6)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(onPressed: _addOption, child: const Text('+ Add option', style: TextStyle(color: AppColors.primary))),
                    ),
                  ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: const StadiumBorder(), padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: const Text('Start poll'),
                  ),
                ),
              ],
            ),
          ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _questionController.dispose();
    for (final c in _optionControllers) {
      c.dispose();
    }
    super.dispose();
  }
}
