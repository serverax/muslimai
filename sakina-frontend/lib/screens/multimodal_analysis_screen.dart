import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../config/api_config.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class MultimodalAnalysisScreen extends StatefulWidget {
  MultimodalAnalysisScreen({
    super.key,
    this.session,
    ApiService? api,
    ImagePicker? imagePicker,
  })  : api = api ?? ApiService(baseUrl: ApiConfig.baseUrl),
        imagePicker = imagePicker ?? ImagePicker() {
    final currentSession = session;
    if (currentSession != null && api == null) {
      this.api.setAuthToken(currentSession.accessToken);
    }
  }

  final AuthSession? session;
  final ApiService api;
  final ImagePicker imagePicker;

  @override
  State<MultimodalAnalysisScreen> createState() =>
      _MultimodalAnalysisScreenState();
}

class _MultimodalAnalysisScreenState extends State<MultimodalAnalysisScreen> {
  bool _busy = false;
  String? _error;
  MultimodalAnalysisResponse? _result;

  Future<void> _analyzeImage(ImageSource source) async {
    if (_busy) return;
    final file = await widget.imagePicker.pickImage(
      source: source,
      requestFullMetadata: false,
      imageQuality: 92,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final lower = file.name.toLowerCase();
    final mimeType = lower.endsWith('.jpg') || lower.endsWith('.jpeg')
        ? 'image/jpeg'
        : 'image/png';
    await _upload(
      bytes: bytes,
      filename: file.name,
      assetType: 'image',
      mimeType: mimeType,
    );
  }

  Future<void> _analyzeDocument() async {
    if (_busy) return;
    final result = await FilePicker.pickFiles(
      allowMultiple: false,
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['txt', 'pdf'],
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      setState(() => _error = 'Selected file could not be read.');
      return;
    }
    final mimeType = file.extension?.toLowerCase() == 'pdf'
        ? 'application/pdf'
        : 'text/plain';
    await _upload(
      bytes: Uint8List.fromList(bytes),
      filename: file.name,
      assetType: 'document',
      mimeType: mimeType,
    );
  }

  Future<void> _upload({
    required Uint8List bytes,
    required String filename,
    required String assetType,
    required String mimeType,
  }) async {
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });
    try {
      final response = await widget.api.analyzeMultimodal(
        bytes: bytes,
        filename: filename,
        assetType: assetType,
        mimeType: mimeType,
        language: 'en',
        requestId: 'mobile-${DateTime.now().microsecondsSinceEpoch}',
      );
      if (!mounted) return;
      setState(() => _result = response);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _humanize(error));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  String _humanize(Object error) {
    final text = error.toString();
    if (text.contains('401')) return 'Please sign in again.';
    if (text.contains('403')) return 'This account cannot use uploads.';
    if (text.contains('413')) return 'The selected file is too large.';
    if (text.contains('415')) return 'This file type is not supported.';
    if (text.contains('422')) return 'The upload could not be analyzed.';
    if (text.contains('404')) return 'The requested upload result was not found.';
    if (text.contains('409')) return 'This upload conflicts with existing account state.';
    if (text.contains('429')) return 'Too many upload attempts.';
    if (text.contains('500')) return 'The upload service failed.';
    return text;
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed:
                      _busy ? null : () => _analyzeImage(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Camera'),
                ),
                FilledButton.icon(
                  onPressed:
                      _busy ? null : () => _analyzeImage(ImageSource.gallery),
                  icon: const Icon(Icons.image_search_outlined),
                  label: const Text('Image'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _analyzeDocument,
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('Document'),
                ),
              ],
            ),
            if (_busy) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            if (result != null) ...[
              const SizedBox(height: 16),
              Text('Trace ${result.traceId}',
                  style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 8),
              Text(result.answerText,
                  style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 12),
              Text('Extracted', style: Theme.of(context).textTheme.titleSmall),
              Text(result.redactedText),
              if (result.citations.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Sources', style: Theme.of(context).textTheme.titleSmall),
                for (final source in result.citations)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${source.title} | ${source.chapter} | ${source.authenticityGrade}',
                    ),
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
