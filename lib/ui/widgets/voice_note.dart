import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:record/record.dart';

import '../../data/api.dart';
import '../../data/audio_bytes.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../theme/kwik_theme.dart';
import 'common.dart';

/// Hold-to-record button.
///
/// Audio is encoded at 24 kbps mono before it ever leaves the device — that is
/// the whole point of KwikChat on a 2G/3G connection.
class VoiceRecordButton extends ConsumerStatefulWidget {
  const VoiceRecordButton({super.key, required this.onRecorded});
  final Future<void> Function(Uint8List bytes, int durationMs, String extension, String contentType) onRecorded;

  @override
  ConsumerState<VoiceRecordButton> createState() => _VoiceRecordButtonState();
}

class _VoiceRecordButtonState extends ConsumerState<VoiceRecordButton> {
  final AudioRecorder _recorder = AudioRecorder();
  Timer? _ticker;
  Stopwatch? _stopwatch;
  String? _path;
  bool _recording = false;
  bool _permissionAsked = false;
  Duration _elapsed = Duration.zero;

  @override
  void dispose() {
    _ticker?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (_recording) return;
    try {
      var allowed = await _recorder.hasPermission();
      if (!allowed && !_permissionAsked) {
        _permissionAsked = true;
        allowed = await _recorder.hasPermission();
      }
      if (!allowed) {
        if (mounted) showKwikSnack(context, 'Microphone permission is needed for voice notes.', error: true);
        return;
      }
      _path = newRecordingPath();
      final config = kIsWeb
          ? const RecordConfig(encoder: AudioEncoder.opus, bitRate: 24000, sampleRate: 48000, numChannels: 1)
          : const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 24000, sampleRate: 24000, numChannels: 1);
      await _recorder.start(config, path: _path!);
      _stopwatch = Stopwatch()..start();
      setState(() {
        _recording = true;
        _elapsed = Duration.zero;
      });
      _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (!mounted) return;
        final elapsed = _stopwatch?.elapsed ?? Duration.zero;
        setState(() => _elapsed = elapsed);
        if (elapsed.inSeconds >= 120) _stop(send: true);
      });
    } catch (_) {
      if (mounted) showKwikSnack(context, 'Could not start recording.', error: true);
    }
  }

  Future<void> _stop({required bool send}) async {
    if (!_recording) return;
    _ticker?.cancel();
    final elapsedMs = _stopwatch?.elapsed.inMilliseconds ?? 0;
    _stopwatch?.stop();
    String? recordedPath;
    try {
      recordedPath = await _recorder.stop();
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _recording = false;
      _elapsed = Duration.zero;
    });

    if (!send || recordedPath == null || elapsedMs < 600) {
      if (recordedPath != null) await deleteAudioFile(recordedPath);
      return;
    }

    try {
      final bytes = await readAudioBytes(recordedPath);
      final extension = kIsWeb ? 'webm' : 'm4a';
      final contentType = kIsWeb ? 'audio/webm' : 'audio/mp4';
      await widget.onRecorded(bytes, elapsedMs, extension, contentType);
    } catch (_) {
      if (mounted) showKwikSnack(context, 'Could not read the recording.', error: true);
    } finally {
      await deleteAudioFile(recordedPath);
    }
  }

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    return GestureDetector(
      onLongPressStart: (_) => _start(),
      onLongPressEnd: (_) => _stop(send: true),
      onLongPressCancel: () => _stop(send: false),
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _recording ? kc.danger : kc.surface2,
          shape: BoxShape.circle,
          border: Border.all(color: _recording ? kc.danger : kc.border),
        ),
        child: _recording
            ? Text(
                '${_elapsed.inSeconds}s',
                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
              )
            : Icon(Icons.mic_none, color: kc.text, size: 21),
      ),
    );
  }
}

/// Inline player for a received voice note.
class VoiceNoteBubble extends ConsumerStatefulWidget {
  const VoiceNoteBubble({
    super.key,
    required this.message,
    required this.isMine,
    required this.accentColor,
    required this.textColor,
  });
  final ChatMessage message;
  final bool isMine;
  final Color accentColor;
  final Color textColor;

  @override
  ConsumerState<VoiceNoteBubble> createState() => _VoiceNoteBubbleState();
}

class _VoiceNoteBubbleState extends ConsumerState<VoiceNoteBubble> {
  AudioPlayer? _player;
  StreamSubscription<PlayerState>? _sub;
  bool _loading = false;
  bool _playing = false;

  @override
  void dispose() {
    _sub?.cancel();
    _player?.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player?.pause();
      if (mounted) setState(() => _playing = false);
      return;
    }
    final path = widget.message.mediaPath;
    if (path == null) return;

    setState(() => _loading = true);
    try {
      if (_player == null) {
        final url = await ref.read(apiProvider).signedMediaUrl(path);
        final player = AudioPlayer();
        await player.setUrl(url);
        _sub = player.playerStateStream.listen((state) {
          if (!mounted) return;
          if (state.processingState == ProcessingState.completed) {
            setState(() => _playing = false);
            player.seek(Duration.zero);
            player.pause();
          }
        });
        _player = player;
      } else {
        await _player!.seek(Duration.zero);
      }
      await _player!.play();
      if (mounted) {
        setState(() {
          _playing = true;
          _loading = false;
        });
      }
    } on KwikError catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showKwikSnack(context, e.message, error: true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      showKwikSnack(context, 'Could not play this voice note.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final duration = formatDuration(widget.message.durationMs);
    return GestureDetector(
      onTap: _toggle,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: widget.accentColor.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: _loading
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 1.6, color: widget.accentColor),
                  )
                : Icon(
                    _playing ? Icons.pause : Icons.play_arrow_rounded,
                    size: 20,
                    color: widget.accentColor,
                  ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: List.generate(18, (i) {
                  final height = 4.0 + ((i * 7) % 13);
                  return Container(
                    width: 2.4,
                    height: height,
                    margin: const EdgeInsets.only(right: 2.2),
                    decoration: BoxDecoration(
                      color: widget.textColor.withValues(alpha: i.isEven ? 0.55 : 0.28),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 3),
              Text(
                'Voice · $duration',
                style: TextStyle(
                  color: widget.textColor.withValues(alpha: 0.72),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
