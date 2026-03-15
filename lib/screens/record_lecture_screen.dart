import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';

import '../core/theme.dart';
import '../models/subject.dart';
import '../services/api.dart';
import '../state/lectures_provider.dart';
import '../state/auth_provider.dart';
import '../widgets/finish_lecture_sheet.dart';

class RecordLectureScreen extends ConsumerStatefulWidget {
  final Subject subject;
  const RecordLectureScreen({super.key, required this.subject});

  @override
  ConsumerState<RecordLectureScreen> createState() => _RecordLectureScreenState();
}

class _RecordLectureScreenState extends ConsumerState<RecordLectureScreen> {
  bool _recording = false;
  bool _uploading = false;
  Duration _elapsed = Duration.zero;
  String? _uploadError;

  Timer? _timer;
  Timer? _waveTimer;

  final _rng = Random();
  List<double> _bars = const [0.25, 0.25, 0.25, 0.25, 0.25];
  
  final _audioRecorder = AudioRecorder();
  String? _audioPath;

  @override
  void dispose() {
    _timer?.cancel();
    _waveTimer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  void _start() async {
    // Request permissions
    final hasPermission = await _audioRecorder.hasPermission();
    if (!mounted) return;
    if (!hasPermission) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Microphone permission required")),
      );
      return;
    }

    setState(() {
      _recording = true;
      _elapsed = Duration.zero;
      _uploadError = null;
    });

    // Start recording
    final recordPath = "${Directory.systemTemp.path}/lecture_${DateTime.now().millisecondsSinceEpoch}.m4a";
    await _audioRecorder.start(
      RecordConfig(encoder: AudioEncoder.aacLc),
      path: recordPath,
    );
    _audioPath = recordPath;

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsed += const Duration(seconds: 1));
    });

    _waveTimer?.cancel();
    _waveTimer = Timer.periodic(const Duration(milliseconds: 220), (_) {
      setState(() {
        if (_recording) {
          _bars = List.generate(5, (i) {
            final v = 0.25 + _rng.nextDouble() * 0.75;
            return v.clamp(0.15, 1.0);
          });
        } else {
          _bars = const [0.25, 0.25, 0.25, 0.25, 0.25];
        }
      });
    });
  }

  Future<void> _stop() async {
    final finish = await showFinishLectureSheet(context);
    if (finish != true) {
      // Cancel recording if user didn't confirm
      await _audioRecorder.stop();
      setState(() => _recording = false);
      return;
    }

    _timer?.cancel();
    _waveTimer?.cancel();
    setState(() => _recording = false);

    // Stop recording and get path
    final recordedPath = await _audioRecorder.stop();
    if (recordedPath == null) {
      setState(() => _uploadError = "Failed to record audio");
      return;
    }

    setState(() => _uploading = true);

    try {
      // Get auth state and create API client with token
      final auth = ref.read(authProvider);
      final api = ApiClient(token: auth.accessToken);
      
      // Read audio file bytes
      final audioFile = File(recordedPath);
      final audioBytes = await audioFile.readAsBytes();
      
      // Create lecture first
      final lecture = await api.createLecture(
        subjectId: widget.subject.id,
      );

      // Upload audio
      await api.lectureApi.uploadAudio(
        lecture.id,
        fileBytes: audioBytes,
        fileName: "lecture_audio.m4a",
      );

      // Invalidate lectures list to refresh
      ref.invalidate(lecturesProvider(widget.subject.id));

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      setState(() => _uploadError = "Upload failed: $e");
    } finally {
      if (mounted) {
        setState(() => _uploading = false);
      }
      // Cleanup temp file
      try {
        await File(recordedPath).delete();
      } catch (_) {}
    }
  }

  Future<void> _pickAndUploadAudio() async {
    if (_uploading || _recording) return;

    setState(() {
      _uploadError = null;
    });

    XFile? picked;
    try {
      const typeGroup = XTypeGroup(
        label: 'audio',
        extensions: [
          'm4a',
          'mp3',
          'wav',
          'aac',
          'flac',
          'ogg',
          'opus',
          'mp4',
        ],
      );
      picked = await openFile(acceptedTypeGroups: [typeGroup]);
    } catch (e) {
      setState(() => _uploadError = "File picker error: $e");
      return;
    }

    if (picked == null) return; // user cancelled

    final fileName = picked.name.isNotEmpty ? picked.name : "lecture_audio.m4a";

    final bytes = await picked.readAsBytes();
    if (bytes.isEmpty) {
      setState(() => _uploadError = "Selected file is empty");
      return;
    }

    setState(() => _uploading = true);

    try {
      final auth = ref.read(authProvider);
      final api = ApiClient(token: auth.accessToken);

      final lecture = await api.createLecture(
        subjectId: widget.subject.id,
      );

      await api.lectureApi.uploadAudio(
        lecture.id,
        fileBytes: bytes,
        fileName: fileName,
      );

      ref.invalidate(lecturesProvider(widget.subject.id));

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      setState(() => _uploadError = "Upload failed: $e");
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  String _fmt(Duration d) {
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$mm:$ss";
  }

  @override
  Widget build(BuildContext context) {
    final bg = AppTheme.backgroundLight;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text("Record Lecture"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () async {
            if (_recording) {
              final finish = await showFinishLectureSheet(context);
              if (finish == true && mounted) Navigator.pop(context);
              return;
            }
            Navigator.pop(context);
          },
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Subject card (matches HTML)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _SubjectCard(subjectName: widget.subject.name),
            ),

            // Error message
            if (_uploadError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.30)),
                  ),
                  child: Text(
                    _uploadError!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              ),

            // Center panel
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _CentralPanel(
                      recording: _recording,
                      timerText: _fmt(_elapsed),
                      bars: _bars,
                    ),
                    const SizedBox(height: 18),
                    if (_uploading)
                      const Text(
                        "UPLOADING AND PROCESSING",
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.0,
                        ),
                        textAlign: TextAlign.center,
                      )
                    else
                      Text(
                        _recording ? "RECORDING IN PROGRESS" : "READY TO RECORD",
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.0,
                        ),
                        textAlign: TextAlign.center,
                      ),
                  ],
                ),
              ),
            ),

            // Bottom buttons
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
              decoration: BoxDecoration(
                color: Colors.white,
                border: const Border(top: BorderSide(color: Color(0xFFF0F0F6))),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        side: const BorderSide(color: Color(0xFFE2E2EC), width: 2),
                        foregroundColor: const Color(0xFF121117),
                      ),
                      onPressed: (_uploading || _recording) ? null : _pickAndUploadAudio,
                      icon: const Icon(Icons.upload_file_rounded),
                      label: const Text(
                        "Upload Audio (Test)",
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            side: const BorderSide(color: Color(0xFFE2E2EC), width: 2),
                            foregroundColor: const Color(0xFF121117),
                          ),
                          onPressed: _uploading
                              ? null
                              : () async {
                                  if (_recording) {
                                    final finish = await showFinishLectureSheet(context);
                                    if (finish == true && mounted) Navigator.pop(context);
                                    return;
                                  }
                                  Navigator.pop(context);
                                },
                          icon: const Icon(Icons.close_rounded),
                          label: const Text("Cancel", style: TextStyle(fontWeight: FontWeight.w900)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                            shadowColor: AppTheme.primary.withOpacity(0.30),
                          ),
                          onPressed: _uploading
                              ? null
                              : () async {
                                  if (_recording) {
                                    await _stop();
                                  } else {
                                    _start();
                                  }
                                },
                          icon: _uploading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                                )
                              : Icon(_recording ? Icons.stop_circle_rounded : Icons.fiber_manual_record_rounded),
                          label: Text(
                            _recording ? "Stop Recording" : "Start Recording",
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8), // iOS home indicator spacing
          ],
        ),
      ),
    );
  }
}

class _SubjectCard extends StatelessWidget {
  final String subjectName;
  const _SubjectCard({required this.subjectName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.backgroundLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0F0F6)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subjectName,
                  style: const TextStyle(
                    color: Color(0xFF121117),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Subject",
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF330DF2), Color(0xFF7E64F7)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CentralPanel extends StatelessWidget {
  final bool recording;
  final String timerText;
  final List<double> bars;

  const _CentralPanel({
    required this.recording,
    required this.timerText,
    required this.bars,
  });

  @override
  Widget build(BuildContext context) {
    final ringColor = recording ? Colors.red.withOpacity(0.12) : AppTheme.primary.withOpacity(0.08);

    return Container(
      width: 280,
      height: 280,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.backgroundLight,
        border: Border.all(color: const Color(0xFFF0F0F6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // subtle ring highlight
          Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ringColor,
            ),
          ),

          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Mic icon bubble
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: recording ? Colors.red.withOpacity(0.12) : AppTheme.primary.withOpacity(0.10),
                ),
                child: Icon(
                  Icons.mic_rounded,
                  size: 54,
                  color: recording ? Colors.red : AppTheme.primary,
                ),
              ),

              const SizedBox(height: 14),

              // Timer pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFE2E2EC)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  timerText,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    fontFamily: "monospace",
                    color: Color(0xFF121117),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Waveform bars
              SizedBox(
                height: 32,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(5, (i) {
                    final h = 6 + (bars[i] * 26);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 4,
                        height: h,
                        decoration: BoxDecoration(
                          color: recording ? AppTheme.primary : AppTheme.primary.withOpacity(0.30),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
