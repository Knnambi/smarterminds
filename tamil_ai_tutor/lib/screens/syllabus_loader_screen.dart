import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'chat_screen.dart';

class SyllabusLoaderScreen extends StatefulWidget {
  const SyllabusLoaderScreen({super.key});

  @override
  State<SyllabusLoaderScreen> createState() => _SyllabusLoaderScreenState();
}

class _SyllabusLoaderScreenState extends State<SyllabusLoaderScreen> {
  bool _isPicking = false;
  String? _errorMessage;

  Future<void> _pickPdf() async {
    setState(() {
      _isPicking = true;
      _errorMessage = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        setState(() => _isPicking = false);
        return;
      }

      final file = result.files.first;
      final bytes = file.bytes;

      if (bytes == null || bytes.isEmpty) {
        setState(() {
          _isPicking = false;
          _errorMessage = 'PDF படிக்க முடியவில்லை. மீண்டும் முயற்சிக்கவும்.';
        });
        return;
      }

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ChatScreen(pdfBytes: bytes, pdfName: file.name),
        ),
      );
    } catch (e) {
      setState(() {
        _isPicking = false;
        _errorMessage = 'கோப்பு தேர்வில் பிழை: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [scheme.primary, scheme.tertiary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.primary.withOpacity(0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(Icons.school_rounded,
                    color: scheme.onPrimary, size: 52),
              ),

              const SizedBox(height: 28),

              Text(
                'Tamil AI Tutor',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'தமிழ்நாடு பாடத்திட்ட AI ஆசிரியர்',
                style: TextStyle(
                    fontSize: 15,
                    color: scheme.onSurface.withOpacity(0.6)),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 52),

              // Instruction card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: scheme.primary.withOpacity(0.2), width: 1),
                ),
                child: Column(
                  children: [
                    Icon(Icons.picture_as_pdf_rounded,
                        color: scheme.primary, size: 36),
                    const SizedBox(height: 12),
                    Text(
                      'பாடத்திட்ட PDF ஏற்றுங்கள்',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'ஆசிரியர் தமிழ்நாடு மாநில வாரிய பாடத்திட்ட PDF ஐ தேர்வு செய்யவும். '
                      'Gemini இந்த PDF ஐ படித்து மாணவர்களின் கேள்விகளுக்கு பதிலளிக்கும்.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: scheme.onPrimaryContainer.withOpacity(0.8),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Pick button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: _isPicking ? null : _pickPdf,
                  icon: _isPicking
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: scheme.onPrimary),
                        )
                      : const Icon(Icons.upload_file_rounded),
                  label: Text(
                    _isPicking
                        ? 'ஏற்றுகிறது...'
                        : 'PDF கோப்பு தேர்வு செய்யுங்கள்',
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
              ),

              // Error
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline_rounded,
                          color: scheme.onErrorContainer, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_errorMessage!,
                            style:
                                TextStyle(color: scheme.onErrorContainer)),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 40),
              Text(
                'Powered by Gemini 1.5 Flash',
                style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurface.withOpacity(0.35)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
