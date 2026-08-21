import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../core/api_client.dart';
import '../theme/app_colors.dart';
import '../theme/glass.dart';
import 'mention_text_field.dart';

class _TypeDef {
  final String key;
  final String label;
  const _TypeDef(this.key, this.label);
}

const _kTypes = [
  _TypeDef('text', '📝 Text'),
  _TypeDef('image', '🖼️ Photo'),
  _TypeDef('voice', '🎵 Song'),
  _TypeDef('reel', '🎥 Video (15s)'),
  _TypeDef('poll', '📊 Poll'),
  _TypeDef('video_link', '🎬 Link'),
];

/// Post-creation sheet — Dart port of PostComposer.jsx (text/photo/song/
/// short-video/poll/video-link post types, plus the "share as a 24h story"
/// toggle). Presented as a bottom sheet rather than an inline expanding
/// card to match the app's spatial-UI bottom-sheet convention.
Future<void> showPostComposerSheet(BuildContext context, {required VoidCallback onPosted, bool initialIsStory = false}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _PostComposerSheet(onPosted: onPosted, initialIsStory: initialIsStory),
  );
}

class _PostComposerSheet extends StatefulWidget {
  final VoidCallback onPosted;
  final bool initialIsStory;
  const _PostComposerSheet({required this.onPosted, this.initialIsStory = false});

  @override
  State<_PostComposerSheet> createState() => _PostComposerSheetState();
}

class _PostComposerSheetState extends State<_PostComposerSheet> {
  String _mediaType = 'text';
  final _textController = TextEditingController();
  final _videoUrlController = TextEditingController();
  String? _imageDataUri;
  String? _voiceDataUri;
  String? _videoDataUri;
  late bool _isStory;
  bool _posting = false;
  final List<TextEditingController> _pollControllers = [TextEditingController(), TextEditingController()];

  @override
  void initState() {
    super.initState();
    _isStory = widget.initialIsStory;
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    final ext = file.name.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';
    if (!mounted) return;
    setState(() => _imageDataUri = 'data:image/$ext;base64,${base64Encode(bytes)}');
  }

  Future<void> _pickVoice() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio, withData: true);
    final file = result?.files.firstOrNull;
    if (file?.bytes == null || !mounted) return;
    setState(() => _voiceDataUri = 'data:audio/mpeg;base64,${base64Encode(file!.bytes!)}');
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final file = await picker.pickVideo(source: ImageSource.gallery, maxDuration: const Duration(seconds: 20));
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    if (bytes.length > 12000000) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Keep clips to about 15 seconds')));
      return;
    }
    setState(() => _videoDataUri = 'data:video/mp4;base64,${base64Encode(bytes)}');
  }

  void _addPollOption() {
    if (_pollControllers.length >= 6) return;
    setState(() => _pollControllers.add(TextEditingController()));
  }

  Future<void> _submit() async {
    setState(() => _posting = true);
    try {
      final body = <String, dynamic>{'mediaType': _mediaType, 'text': _textController.text.trim(), 'isStory': _isStory};
      if (_mediaType == 'image' && _imageDataUri != null) body['imageData'] = _imageDataUri;
      if (_mediaType == 'voice' && _voiceDataUri != null) body['voiceData'] = _voiceDataUri;
      if (_mediaType == 'reel' && _videoDataUri != null) body['videoData'] = _videoDataUri;
      if (_mediaType == 'video_link') body['videoUrl'] = _videoUrlController.text.trim();
      if (_mediaType == 'poll') {
        body['pollOptions'] = _pollControllers.map((c) => c.text.trim()).where((o) => o.isNotEmpty).toList();
      }
      await ApiClient.post('/feed', body: body);
      widget.onPosted();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to post')));
    } finally {
      if (mounted) setState(() => _posting = false);
    }
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
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _kTypes.map((t) {
                    final selected = _mediaType == t.key;
                    return GestureDetector(
                      onTap: () => setState(() => _mediaType = t.key),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: selected ? AppColors.primary.withValues(alpha: 0.15) : AppColors.surface2,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(t.label, style: TextStyle(color: selected ? AppColors.primary : AppColors.textDim, fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                MentionTextField(
                  controller: _textController,
                  maxLines: 3,
                  maxLength: 1000,
                  hintText: 'Say something… (@ to mention someone)',
                ),
                if (_mediaType == 'image') ...[
                  const SizedBox(height: 8),
                  _pickerButton('Choose photo', _pickImage),
                  if (_imageDataUri != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(base64Decode(_imageDataUri!.split(',').last), height: 160, fit: BoxFit.cover)),
                    ),
                ],
                if (_mediaType == 'voice') ...[
                  const SizedBox(height: 8),
                  _pickerButton('Choose a song', _pickVoice),
                  if (_voiceDataUri != null) const Padding(padding: EdgeInsets.only(top: 8), child: Text('🎵 Song attached', style: TextStyle(color: AppColors.textDim, fontSize: 12))),
                ],
                if (_mediaType == 'reel') ...[
                  const SizedBox(height: 8),
                  _pickerButton('Choose a video', _pickVideo),
                  if (_videoDataUri != null) const Padding(padding: EdgeInsets.only(top: 8), child: Text('🎥 Video attached', style: TextStyle(color: AppColors.textDim, fontSize: 12))),
                ],
                if (_mediaType == 'video_link') ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _videoUrlController,
                    style: const TextStyle(color: AppColors.text),
                    decoration: const InputDecoration(hintText: 'https://youtube.com/embed/…'),
                  ),
                ],
                if (_mediaType == 'poll') ...[
                  const SizedBox(height: 8),
                  ...List.generate(
                    _pollControllers.length,
                    (i) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TextField(
                        controller: _pollControllers[i],
                        style: const TextStyle(color: AppColors.text),
                        decoration: InputDecoration(hintText: 'Option ${i + 1}'),
                      ),
                    ),
                  ),
                  if (_pollControllers.length < 6)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(onPressed: _addPollOption, child: const Text('+ Add option', style: TextStyle(color: AppColors.primary))),
                    ),
                ],
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () => setState(() => _isStory = !_isStory),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(child: Text('Share as a 24h story instead', style: const TextStyle(color: AppColors.textDim, fontSize: 13))),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 36,
                          height: 20,
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            gradient: _isStory ? const LinearGradient(colors: AppGradients.brand) : null,
                            color: _isStory ? null : AppColors.surface2,
                          ),
                          alignment: _isStory ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(width: 16, height: 16, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _posting ? null : _submit,
                  child: Container(
                    width: double.infinity,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: _posting ? null : const LinearGradient(colors: AppGradients.brand),
                      color: _posting ? AppColors.surface2 : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(_posting ? 'Posting…' : 'Post', style: TextStyle(color: _posting ? AppColors.textFaint : Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
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

  Widget _pickerButton(String label, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
          child: Text(label, style: const TextStyle(color: AppColors.textDim, fontSize: 12.5, fontWeight: FontWeight.w600)),
        ),
      );

  @override
  void dispose() {
    _textController.dispose();
    _videoUrlController.dispose();
    for (final c in _pollControllers) {
      c.dispose();
    }
    super.dispose();
  }
}
