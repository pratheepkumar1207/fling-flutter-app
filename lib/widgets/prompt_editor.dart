import 'package:flutter/material.dart';
import '../core/prompt_options.dart';
import '../theme/app_colors.dart';

/// Hinge-style prompt Q&A editor — Dart port of PromptEditor.jsx. Up to
/// kMaxPrompts { prompt, answer } maps. Stateful so each answer field keeps
/// its own persistent TextEditingController (a fresh one per rebuild would
/// reset the cursor to the end on every keystroke).
class PromptEditor extends StatefulWidget {
  final List<Map<String, dynamic>> prompts;
  final ValueChanged<List<Map<String, dynamic>>> onChanged;
  final int max;

  const PromptEditor({super.key, required this.prompts, required this.onChanged, this.max = kMaxPrompts});

  @override
  State<PromptEditor> createState() => _PromptEditorState();
}

class _PromptEditorState extends State<PromptEditor> {
  final List<TextEditingController> _controllers = [];

  @override
  void initState() {
    super.initState();
    _syncControllers();
  }

  @override
  void didUpdateWidget(covariant PromptEditor old) {
    super.didUpdateWidget(old);
    if (old.prompts.length != widget.prompts.length) _syncControllers();
  }

  void _syncControllers() {
    while (_controllers.length < widget.prompts.length) {
      final i = _controllers.length;
      _controllers.add(TextEditingController(text: widget.prompts[i]['answer'] as String? ?? ''));
    }
    while (_controllers.length > widget.prompts.length) {
      _controllers.removeLast().dispose();
    }
  }

  void _updateSlot(int i, Map<String, dynamic> patch) {
    final next = List<Map<String, dynamic>>.from(widget.prompts);
    next[i] = {...next[i], ...patch};
    widget.onChanged(next);
  }

  void _addSlot() {
    if (widget.prompts.length >= widget.max) return;
    widget.onChanged([...widget.prompts, {'prompt': '', 'answer': ''}]);
  }

  void _removeSlot(int i) {
    final next = List<Map<String, dynamic>>.from(widget.prompts)..removeAt(i);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < widget.prompts.length; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: (widget.prompts[i]['prompt'] as String?)?.isNotEmpty == true ? widget.prompts[i]['prompt'] as String : null,
                        isExpanded: true,
                        dropdownColor: AppColors.surface2,
                        hint: const Text('Choose a prompt…', style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
                        items: [
                          for (final opt in kPromptOptions)
                            if (opt == widget.prompts[i]['prompt'] || !widget.prompts.any((p) => p['prompt'] == opt))
                              DropdownMenuItem(value: opt, child: Text(opt, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                        ],
                        onChanged: (v) => _updateSlot(i, {'prompt': v ?? ''}),
                      ),
                    ),
                    TextButton(onPressed: () => _removeSlot(i), child: const Text('Remove', style: TextStyle(color: AppColors.danger, fontSize: 12))),
                  ],
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _controllers[i],
                  onChanged: (v) => _updateSlot(i, {'answer': v}),
                  maxLength: 300,
                  maxLines: 2,
                  style: const TextStyle(color: AppColors.text, fontSize: 13),
                  decoration: const InputDecoration(hintText: 'Your answer…'),
                ),
              ],
            ),
          ),
        if (widget.prompts.length < widget.max)
          OutlinedButton(
            onPressed: _addSlot,
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.textDim, side: const BorderSide(color: AppColors.border)),
            child: const Text('+ Add a prompt'),
          ),
      ],
    );
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }
}
