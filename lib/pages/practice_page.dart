import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../config/api_config.dart';

enum PracticeState { ready, recording, paused }

class PracticePage extends StatefulWidget {
  final String userId;
  final Function(Map<String, dynamic>)? onFinish; 

  const PracticePage({super.key, required this.userId, this.onFinish});

  @override
  State<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends State<PracticePage> {
  PracticeState _state = PracticeState.ready;
  Timer? _timer;
  int _seconds = 0;
  bool _isUploading = false; 
  
  bool _isEnglish = true; 

  final AudioRecorder _audioRecorder = AudioRecorder();
  String? _audioPath;

  @override
  void dispose() {
    _timer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        _timer?.cancel();
        if (_state == PracticeState.ready) {
          _seconds = 0;
          final Directory tempDir = await getTemporaryDirectory();
          _audioPath = '${tempDir.path}/ispeak_${DateTime.now().millisecondsSinceEpoch}.wav';
          
          // Configured for Whisper AI
          await _audioRecorder.start(
            const RecordConfig(
              encoder: AudioEncoder.wav,
              sampleRate: 16000,
              numChannels: 1,
            ), 
            path: _audioPath!,
          );
        } else if (_state == PracticeState.paused) {
          await _audioRecorder.resume();
        }

        setState(() => _state = PracticeState.recording);
        _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => _seconds++));
      }
    } catch (e) {
      debugPrint("Error starting record: $e");
    }
  }

  Future<void> _pause() async {
    _timer?.cancel();
    await _audioRecorder.pause();
    setState(() => _state = PracticeState.paused);
  }

  Future<void> _reset() async {
    _timer?.cancel();
    await _audioRecorder.stop();
    if (_audioPath != null) {
      final file = File(_audioPath!);
      if (await file.exists()) await file.delete();
    }
    setState(() {
      _state = PracticeState.ready;
      _seconds = 0;
      _audioPath = null;
    });
  }

  String get _time {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF0F0F3),
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView( 
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
          child: Column(
            children: [
              const SizedBox(height: 10),
              
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Practice Session', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                        SizedBox(height: 8),
                        Text('Record your speech to get instant feedback', style: TextStyle(color: Colors.grey, fontSize: 13)),
                      ],
                    ),
                  ),
                  _buildLanguageToggle(),
                ],
              ),
              
              const SizedBox(height: 30),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.language, 
                    size: 16, 
                    color: _isEnglish ? const Color(0xFF3F7CF4) : const Color(0xFFF5A623)
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Practicing in ${_isEnglish ? "English" : "Filipino"}',
                    style: TextStyle(
                      color: _isEnglish ? const Color(0xFF3F7CF4) : const Color(0xFFF5A623),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _recordCard(),

              const SizedBox(height: 40),

              // ---> CONDITION FIX: Changed to 10 seconds <---
              if (_state == PracticeState.paused && _seconds >= 10) 
                _finishButton(),
                
              const SizedBox(height: 140), 
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: _state == PracticeState.recording ? null : () => setState(() => _isEnglish = true),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _isEnglish ? const Color(0xFF3F7CF4) : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                boxShadow: _isEnglish 
                    ? [BoxShadow(color: const Color(0xFF3F7CF4).withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))]
                    : [],
              ),
              child: Text(
                'EN', 
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _isEnglish ? Colors.white : Colors.grey.shade600),
              ),
            ),
          ),
          GestureDetector(
            onTap: _state == PracticeState.recording ? null : () => setState(() => _isEnglish = false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: !_isEnglish ? const Color(0xFFF5A623) : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                boxShadow: !_isEnglish 
                    ? [BoxShadow(color: const Color(0xFFF5A623).withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))]
                    : [],
              ),
              child: Text(
                'FIL', 
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: !_isEnglish ? Colors.white : Colors.grey.shade600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _recordCard() {
    final isRecording = _state == PracticeState.recording;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 15, offset: Offset(0, 5))],
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: _isUploading ? null : () {
              if (_state == PracticeState.ready) {
                _start();
              } else if (_state == PracticeState.recording) _pause();
              else _start();
            },
            child: CircleAvatar(
              radius: 50,
              backgroundColor: isRecording ? Colors.redAccent : const Color(0xFF3F7CF4),
              child: Icon(isRecording ? Icons.pause : Icons.mic, color: Colors.white, size: 40),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _state == PracticeState.ready ? 'Ready to Record' : _state == PracticeState.recording ? 'Recording...' : 'Paused',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 12),
          Text(_time, style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Color(0xFF3F7CF4))),
          const SizedBox(height: 10),
          if (_state == PracticeState.paused && !_isUploading)
            TextButton(onPressed: _reset, child: const Text("Reset Session", style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
  }

  Widget _finishButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF3F7CF4),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
        ),
        onPressed: _isUploading ? null : () async {
          _timer?.cancel();
          setState(() => _isUploading = true); 
          
          try {
            final finalPath = await _audioRecorder.stop();
            
            if (finalPath != null) {
              var request = http.MultipartRequest('POST', Uri.parse('${ApiConfig.baseUrl}/upload-audio'));
              
              request.fields['userId'] = widget.userId;
              request.fields['language'] = _isEnglish ? 'English' : 'Filipino'; 
              
              request.files.add(await http.MultipartFile.fromPath('audio', finalPath));

              var streamedResponse = await request.send();
              var response = await http.Response.fromStream(streamedResponse);

              if (response.statusCode == 200 || response.statusCode == 201) {
                final resultData = jsonDecode(response.body);
                widget.onFinish?.call(resultData); 
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload Failed: ${response.body}')));
                }
              }
            }
          } catch (e) {
             debugPrint("Error uploading: $e");
             if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connection Error')));
          }
          setState(() => _isUploading = false);
        },
        child: _isUploading 
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Text('Finish & Analyze Speech', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }
}