import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Matches PollCreatorDark.dc.html: a plain surface sheet (no glass card),
/// uppercase "Question"/"Options" section labels, bordered fields, a
/// per-option remove (X) icon, and a dashed "+ Add another option" row.
Future<void> showPollCreatorBottomSheet(BuildContext context,
    {required void Function(String question, List<String> options) onCreate}) {
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
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController()
  ];

  void _addOption() {
    if (_optionControllers.length >= 6) return;
    setState(() => _optionControllers.add(TextEditingController()));
  }

  void _removeOption(int i) {
    if (_optionControllers.length <= 1) return;
    setState(() => _optionControllers.removeAt(i).dispose());
  }

  void _submit() {
    final question = _questionController.text.trim();
    final options = _optionControllers
        .map((c) => c.text.trim())
        .where((o) => o.isNotEmpty)
        .toList();
    if (question.isEmpty || options.length < 2) return;
    widget.onCreate(question, options);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
          decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(999))),
                ),
                const Text('Create a poll',
                    style: TextStyle(
                        color: AppColors.text,
                        fontWeight: FontWeight.w700,
                        fontSize: 16)),
                const SizedBox(height: 14),
                const Text('QUESTION',
                    style: TextStyle(
                        color: AppColors.textFaint,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6)),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _field(_questionController,
                      maxLength: 140, hint: 'What should we watch next?'),
                ),
                const SizedBox(height: 16),
                const Text('OPTIONS',
                    style: TextStyle(
                        color: AppColors.textFaint,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6)),
                for (var i = 0; i < _optionControllers.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        Expanded(
                            child: _field(_optionControllers[i],
                                maxLength: 60,
                                hint: 'Option ${i + 1}',
                                dense: true)),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _removeOption(i),
                          child: Icon(Icons.close_rounded,
                              color: AppColors.textFaint, size: 18),
                        ),
                      ],
                    ),
                  ),
                if (_optionControllers.length < 6)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: GestureDetector(
                      onTap: _addOption,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            vertical: 11, horizontal: 14),
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(
                                color: AppColors.border,
                                width: 1.5,
                                style: BorderStyle.solid)),
                        child: const Text('+ Add another option',
                            style: TextStyle(
                                color: AppColors.textFaint, fontSize: 13)),
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: _submit,
                  child: Container(
                    width: double.infinity,
                    height: 48,
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient:
                            const LinearGradient(colors: AppGradients.brand)),
                    alignment: Alignment.center,
                    child: const Text('Start poll',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController controller,
      {required int maxLength, required String hint, bool dense = false}) {
    return Container(
      decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: AppColors.border, width: 1.5)),
      child: TextField(
        controller: controller,
        maxLength: maxLength,
        style: TextStyle(color: AppColors.text, fontSize: dense ? 13 : 13.5),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textFaint),
          border: InputBorder.none,
          counterText: '',
          contentPadding:
              EdgeInsets.symmetric(horizontal: 14, vertical: dense ? 11 : 12),
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
