import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'fingerspelling_rules.dart';
import 'landmark_painter.dart';
import 'letter_composer.dart';
import 'sign_camera.dart';

class TranslatorScreen extends StatefulWidget {
  const TranslatorScreen({super.key});

  @override
  State<TranslatorScreen> createState() => _TranslatorScreenState();
}

class _TranslatorScreenState extends State<TranslatorScreen> with WidgetsBindingObserver {
  final _composer = LetterComposer();
  final _tts = FlutterTts();
  StreamSubscription<HandFrame>? _frames;
  CameraPermission? _permission;
  HandFrame? _lastFrame;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _requestCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back from Settings: no dialog is shown when permanently denied, so this just re-checks.
    if (state == AppLifecycleState.resumed && _permission == CameraPermission.permanentlyDenied) {
      _requestCamera();
    }
  }

  Future<void> _requestCamera() async {
    final status = await SignCamera.requestPermission();
    if (!mounted) return;
    setState(() => _permission = status);
    if (status == CameraPermission.granted) _listen();
  }

  void _listen() {
    _frames?.cancel();
    _frames = SignCamera.frames().listen(
      (frame) => setState(() {
        _lastFrame = frame;
        _error = null;
        _composer.add(
          FingerspellingRules.classify(frame.landmarks, aspect: frame.aspect),
          frame.timestampMs,
        );
      }),
      onError: (Object e) => setState(() {
        _error = e is PlatformException ? e.message : '$e';
      }),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _frames?.cancel();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ASL Translator'),
        actions: [
          if (_permission == CameraPermission.granted)
            IconButton(
              tooltip: 'Switch camera',
              icon: const Icon(Icons.cameraswitch_outlined),
              onPressed: SignCamera.switchCamera,
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: Center(child: _cameraArea(context))),
            _TranscriptPanel(
              text: _composer.text,
              onSpace: () => setState(_composer.addSpace),
              onBackspace: () => setState(_composer.backspace),
              onClear: () => setState(_composer.clear),
              onSpeak: _composer.text.trim().isEmpty ? null : () => _tts.speak(_composer.text),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cameraArea(BuildContext context) {
    final permission = _permission;
    if (permission == null) return const CircularProgressIndicator();
    if (permission != CameraPermission.granted) {
      return _Message(
        icon: Icons.no_photography_outlined,
        text: 'Camera access is needed to read signs.',
        action: permission == CameraPermission.permanentlyDenied
            ? FilledButton(onPressed: SignCamera.openSettings, child: const Text('Open settings'))
            : FilledButton(onPressed: _requestCamera, child: const Text('Allow camera')),
      );
    }

    final frame = _lastFrame;
    final scheme = Theme.of(context).colorScheme;
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const SignCameraPreview(),
            if (frame != null)
              IgnorePointer(
                child: CustomPaint(
                  painter: LandmarkPainter(
                    landmarks: frame.landmarks,
                    mirrored: frame.mirrored,
                    color: scheme.primary,
                  ),
                ),
              ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: _error != null
                  ? _Message(icon: Icons.error_outline, text: _error!)
                  : _SignChip(frame: frame, composer: _composer),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows the sign being held and how close it is to being typed.
class _SignChip extends StatelessWidget {
  const _SignChip({required this.frame, required this.composer});

  final HandFrame? frame;
  final LetterComposer composer;

  @override
  Widget build(BuildContext context) {
    final frame = this.frame;
    final candidate = composer.candidate;
    final String title;
    final String subtitle;
    if (candidate != null) {
      title = candidate;
      subtitle = 'Hold to type';
    } else if (frame == null || frame.landmarks.isEmpty) {
      title = '—';
      subtitle = 'Show your hand to the camera';
    } else {
      title = '?';
      subtitle = 'Letter not recognised';
    }

    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.surface.withValues(alpha: 0.9),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(value: composer.progress, strokeWidth: 4),
                  Text(title, style: Theme.of(context).textTheme.headlineSmall),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(subtitle)),
          ],
        ),
      ),
    );
  }
}

class _TranscriptPanel extends StatelessWidget {
  const _TranscriptPanel({
    required this.text,
    required this.onSpace,
    required this.onBackspace,
    required this.onClear,
    required this.onSpeak,
  });

  final String text;
  final VoidCallback onSpace;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final VoidCallback? onSpeak;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            constraints: const BoxConstraints(minHeight: 72),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              text.isEmpty ? 'Fingerspell a word…' : text,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: text.isEmpty ? theme.colorScheme.onSurfaceVariant : null,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(tooltip: 'Space', onPressed: onSpace, icon: const Icon(Icons.space_bar)),
              IconButton(tooltip: 'Delete', onPressed: onBackspace, icon: const Icon(Icons.backspace_outlined)),
              IconButton(tooltip: 'Clear', onPressed: onClear, icon: const Icon(Icons.clear_all)),
              const Spacer(),
              FilledButton.icon(
                onPressed: onSpeak,
                icon: const Icon(Icons.volume_up),
                label: const Text('Speak'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32),
            const SizedBox(height: 8),
            Text(text, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 12), action!],
          ],
        ),
      ),
    );
  }
}
