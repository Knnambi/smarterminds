import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../constants.dart';
import '../models/chat_message.dart';
import '../widgets/bouncing_dot.dart';
import 'syllabus_loader_screen.dart';

class ChatScreen extends StatefulWidget {
  final Uint8List pdfBytes;
  final String pdfName;

  const ChatScreen(
      {super.key, required this.pdfBytes, required this.pdfName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];

  bool _isLoading = false;
  bool _isPdfSeeding = true;
  bool _isListening = false;
  String _recognizedWords = '';

  late final GenerativeModel _model;
  late final ChatSession _chatSession;
  final FlutterTts _tts = FlutterTts();
  final SpeechToText _stt = SpeechToText();

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initGemini();
    _initTts();
    _initPulseAnimation();
    _seedPdfContext();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _tts.stop();
    _pulseController.dispose();
    super.dispose();
  }

  void _initGemini() {
    _model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: GEMINI_API_KEY,
      systemInstruction: Content.system(kSystemInstruction),
      generationConfig:
          GenerationConfig(temperature: 0.4, maxOutputTokens: 1024),
    );
    _chatSession = _model.startChat();
  }

  /// Sends the PDF as the first (hidden) turn so Gemini has full syllabus
  /// context for every subsequent student question.
  Future<void> _seedPdfContext() async {
    try {
      await _chatSession.sendMessage(
        Content.multi([
          DataPart('application/pdf', widget.pdfBytes),
          TextPart(kPdfContextPrompt),
        ]),
      );
    } on GenerativeAIException catch (e) {
      if (mounted) {
        _showSnackBar('PDF ஏற்றுவதில் பிழை: ${e.message}', isError: true);
      }
    } catch (_) {
      if (mounted) {
        _showSnackBar(
            'PDF ஏற்றுவதில் பிழை. இணைப்பை சரிபாருங்கள்.',
            isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isPdfSeeding = false);
        _addWelcomeMessage();
      }
    }
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('ta-IN');
    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }

  void _initPulseAnimation() {
    _pulseController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  void _addWelcomeMessage() {
    final welcome =
        'வணக்கம்! "${widget.pdfName}" PDF வெற்றிகரமாக ஏற்றப்பட்டது. '
        'இப்போது இந்த பாடத்திட்டம் பற்றி எந்த கேள்வியும் கேளுங்கள். '
        'தமிழில் பேசலாம் அல்லது தட்டச்சு செய்யலாம்! 📚';
    setState(() =>
        _messages.add(ChatMessage(text: welcome, sender: MessageSender.tutor)));
    Future.delayed(const Duration(milliseconds: 300), () => _speak(welcome));
  }

  Future<void> _sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isPdfSeeding) return;

    setState(() {
      _messages.add(ChatMessage(text: trimmed, sender: MessageSender.user));
      _isLoading = true;
    });
    _textController.clear();
    _scrollToBottom();

    try {
      final response =
          await _chatSession.sendMessage(Content.text(trimmed));
      final reply =
          response.text ?? 'மன்னிக்கவும், பதில் கிடைக்கவில்லை.';
      setState(() {
        _messages
            .add(ChatMessage(text: reply, sender: MessageSender.tutor));
        _isLoading = false;
      });
      _scrollToBottom();
      await _speak(reply);
    } on GenerativeAIException catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('API பிழை: ${e.message}', isError: true);
    } catch (_) {
      setState(() => _isLoading = false);
      _showSnackBar('இணைப்பு பிழை. இணையதளத்தை சரிபாருங்கள்.',
          isError: true);
    }
  }

  Future<void> _speak(String text) async {
    final cleaned = text
        .replaceAll(RegExp(r'\*+'), '')
        .replaceAll(RegExp(r'#+\s'), '')
        .replaceAll(RegExp(r'`+'), '');
    await _tts.stop();
    await _tts.speak(cleaned);
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _stopListening();
      return;
    }

    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      _showSnackBar(
        'மைக்ரோஃபோன் அனுமதி தேவை. அமைப்புகளில் இயக்குங்கள்.',
        isError: true,
        action: SnackBarAction(
            label: 'அமைப்புகள்', onPressed: openAppSettings),
      );
      return;
    }

    final available = await _stt.initialize(
      onError: (error) {
        setState(() => _isListening = false);
        _pulseController.stop();
        _pulseController.reset();
        _showSnackBar('STT பிழை: ${error.errorMsg}', isError: true);
      },
      onStatus: (status) {
        if ((status == 'done' || status == 'notListening') &&
            _isListening) {
          _stopListening();
        }
      },
    );

    if (!available) {
      _showSnackBar(
          'Speech-to-Text இந்த சாதனத்தில் கிடைக்கவில்லை.',
          isError: true);
      return;
    }

    setState(() {
      _isListening = true;
      _recognizedWords = '';
    });
    _pulseController.repeat(reverse: true);
    await _stt.listen(
      onResult: _onSpeechResult,
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      localeId: 'ta_IN',
      partialResults: true,
      cancelOnError: true,
    );
  }

  Future<void> _stopListening() async {
    await _stt.stop();
    _pulseController.stop();
    _pulseController.reset();
    setState(() => _isListening = false);
    if (_recognizedWords.isNotEmpty) {
      await _sendMessage(_recognizedWords);
      _recognizedWords = '';
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    setState(() {
      _recognizedWords = result.recognizedWords;
      _textController.text = _recognizedWords;
      _textController.selection = TextSelection.fromPosition(
          TextPosition(offset: _textController.text.length));
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showSnackBar(String message,
      {bool isError = false, SnackBarAction? action}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError
          ? Theme.of(context).colorScheme.error
          : Theme.of(context).colorScheme.primary,
      behavior: SnackBarBehavior.floating,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      action: action,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: _buildAppBar(scheme),
      body: _isPdfSeeding
          ? _buildSeedingOverlay(scheme)
          : Column(
              children: [
                Expanded(
                  child: _messages.isEmpty
                      ? _buildEmptyState(scheme)
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 16),
                          itemCount:
                              _messages.length + (_isLoading ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _messages.length) {
                              return _buildTypingIndicator(scheme);
                            }
                            return _buildMessageBubble(
                                _messages[index], scheme);
                          },
                        ),
                ),
                if (_isListening) _buildListeningBanner(scheme),
                _buildInputBar(scheme),
              ],
            ),
    );
  }

  Widget _buildSeedingOverlay(ColorScheme scheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
                color: scheme.primary, strokeWidth: 3),
            const SizedBox(height: 24),
            Text('PDF பாடத்திட்டம் ஏற்றுகிறது...',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: scheme.onSurface)),
            const SizedBox(height: 8),
            Text(widget.pdfName,
                style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurface.withOpacity(0.5)),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('Gemini PDF ஐ படிக்கிறது — கொஞ்சம் காத்திருங்கள்',
                style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurface.withOpacity(0.5)),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(ColorScheme scheme) {
    return AppBar(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      elevation: 2,
      title: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: scheme.onPrimary.withOpacity(0.2),
            child: Icon(Icons.school_rounded,
                color: scheme.onPrimary, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tamil AI Tutor',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: scheme.onPrimary)),
                Text(widget.pdfName,
                    style: TextStyle(
                        fontSize: 10,
                        color: scheme.onPrimary.withOpacity(0.75)),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.volume_off_rounded),
          tooltip: 'குரலை நிறுத்து',
          onPressed: () => _tts.stop(),
        ),
        IconButton(
          icon: const Icon(Icons.swap_horiz_rounded),
          tooltip: 'PDF மாற்றுக',
          onPressed: () {
            _tts.stop();
            Navigator.of(context).pushReplacement(MaterialPageRoute(
                builder: (_) => const SyllabusLoaderScreen()));
          },
        ),
      ],
    );
  }

  Widget _buildEmptyState(ColorScheme scheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.menu_book_rounded, size: 80, color: scheme.primary),
          const SizedBox(height: 16),
          Text('கேள்வி கேளுங்கள்!',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface)),
          const SizedBox(height: 8),
          Text('தட்டச்சு செய்யுங்கள் அல்லது மைக்கை அழுத்துங்கள்',
              style:
                  TextStyle(color: scheme.onSurface.withOpacity(0.6))),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, ColorScheme scheme) {
    final isTutor = message.sender == MessageSender.tutor;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isTutor ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isTutor) ...[
            _buildTutorAvatar(scheme),
            const SizedBox(width: 8)
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isTutor
                    ? scheme.primaryContainer
                    : scheme.secondaryContainer,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isTutor ? 4 : 18),
                  bottomRight: Radius.circular(isTutor ? 18 : 4),
                ),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 2))
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isTutor)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('AI ஆசிரியர்',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: scheme.primary)),
                    ),
                  Text(
                    message.text,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: isTutor
                          ? scheme.onPrimaryContainer
                          : scheme.onSecondaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!isTutor) const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildTutorAvatar(ColorScheme scheme) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [scheme.primary, scheme.tertiary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
              color: scheme.primary.withOpacity(0.3),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child:
          Icon(Icons.school_rounded, color: scheme.onPrimary, size: 20),
    );
  }

  Widget _buildTypingIndicator(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          _buildTutorAvatar(scheme),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dot(scheme, 0),
                _dot(scheme, 150),
                _dot(scheme, 300),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot(ColorScheme scheme, int delayMs) => BouncingDot(
      color: scheme.primary,
      delay: Duration(milliseconds: delayMs));

  Widget _buildListeningBanner(ColorScheme scheme) {
    return Container(
      color: scheme.errorContainer,
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.mic_rounded,
              color: scheme.onErrorContainer, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _recognizedWords.isEmpty
                  ? 'கேட்கிறோம்... பேசுங்கள்'
                  : _recognizedWords,
              style: TextStyle(color: scheme.onErrorContainer),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: _stopListening,
            child: Text('அனுப்பு',
                style: TextStyle(color: scheme.onErrorContainer)),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(ColorScheme scheme) {
    final blocked = _isLoading || _isPdfSeeding;
    return SafeArea(
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: scheme.surface,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, -2))
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _textController,
                enabled: !blocked,
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: blocked ? null : _sendMessage,
                decoration: InputDecoration(
                  hintText: 'கேள்வி கேளுங்கள்...',
                  hintStyle: TextStyle(
                      color: scheme.onSurface.withOpacity(0.5)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: scheme.outline)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(
                          color: scheme.primary, width: 1.5)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(
                          color: scheme.outline.withOpacity(0.5))),
                  filled: true,
                  fillColor:
                      scheme.surfaceContainerHighest.withOpacity(0.5),
                ),
              ),
            ),
            const SizedBox(width: 8),
            blocked
                ? Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: scheme.primary),
                    ),
                  )
                : IconButton(
                    onPressed: () =>
                        _sendMessage(_textController.text),
                    icon: Icon(Icons.send_rounded,
                        color: scheme.primary),
                    tooltip: 'அனுப்பு',
                    style: IconButton.styleFrom(
                      backgroundColor: scheme.primaryContainer,
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
            const SizedBox(width: 4),
            ScaleTransition(
              scale: _isListening
                  ? _pulseAnimation
                  : const AlwaysStoppedAnimation(1.0),
              child: GestureDetector(
                onTap: blocked ? null : _toggleListening,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isListening
                        ? scheme.error
                        : (blocked
                            ? scheme.primary.withOpacity(0.4)
                            : scheme.primary),
                    boxShadow: [
                      BoxShadow(
                        color: (_isListening
                                ? scheme.error
                                : scheme.primary)
                            .withOpacity(0.4),
                        blurRadius: _isListening ? 12 : 6,
                        spreadRadius: _isListening ? 2 : 0,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    _isListening
                        ? Icons.stop_rounded
                        : Icons.mic_rounded,
                    color: _isListening
                        ? scheme.onError
                        : scheme.onPrimary,
                    size: 26,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
