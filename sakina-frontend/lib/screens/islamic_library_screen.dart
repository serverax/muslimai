import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../services/api_service.dart';
import '../widgets/citation_widget.dart';

class IslamicLibraryScreen extends StatefulWidget {
  const IslamicLibraryScreen({super.key});

  @override
  State<IslamicLibraryScreen> createState() => _IslamicLibraryScreenState();
}

class _IslamicLibraryScreenState extends State<IslamicLibraryScreen> {
  late final ApiService _api;
  bool _loading = true;
  String _language = 'en';
  String _sourceFilter = '';
  String _question = '';
  String? _error;
  IslamicAskResponseDto? _answer;
  List<IslamicSourceDto> _sources = const [];
  List<IslamicDocumentDto> _documents = const [];
  List<IslamicSearchResultDto> _searchResults = const [];

  @override
  void initState() {
    super.initState();
    _api = ApiService(baseUrl: ApiConfig.baseUrl);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sources = await _api.getIslamicSources(language: _language);
      final documents = await _api.getIslamicDocuments(
        language: _language,
        source: _sourceFilter.isEmpty ? null : _sourceFilter,
      );
      if (!mounted) return;
      setState(() {
        _sources = sources;
        _documents = documents;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _searchLocal() async {
    if (_question.trim().isEmpty) {
      return;
    }
    try {
      final results = await _api.searchIslamic(
        query: _question,
        language: _language,
        source: _sourceFilter.isEmpty ? null : _sourceFilter,
      );
      if (!mounted) return;
      setState(() => _searchResults = results);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  Future<void> _ask() async {
    if (_question.trim().isEmpty) {
      return;
    }
    try {
      final response = await _api.askIslamic(
        question: _question.trim(),
        language: _language,
        source: _sourceFilter.isEmpty ? null : _sourceFilter,
      );
      if (!mounted) return;
      setState(() => _answer = response);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = _language == 'ar';
    final answerCitations = _answer?.citations.length ?? 0;
    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HeroCard(
              title: isArabic ? 'المكتبة الإسلامية' : 'Islamic Library',
              subtitle: isArabic
                  ? 'مصادر موثوقة، اقتباسات قابلة للتحقق، وتراجع آمن عندما لا توجد أدلة.'
                  : 'Trusted sources, verifiable citations, and safe fallback when evidence is missing.',
              chips: [
                _MetricChip(label: isArabic ? 'المصادر' : 'Sources', value: _sources.length.toString()),
                _MetricChip(label: isArabic ? 'الوثائق' : 'Documents', value: _documents.length.toString()),
                _MetricChip(label: isArabic ? 'الاستشهادات' : 'Citations', value: answerCitations.toString()),
              ],
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'en', label: Text('English')),
                        ButtonSegment(value: 'ar', label: Text('العربية')),
                      ],
                      selected: {_language},
                      onSelectionChanged: (selection) {
                        final next = selection.first;
                        setState(() => _language = next);
                        _load();
                      },
                    ),
                    DropdownButton<String>(
                      value: _sourceFilter.isEmpty ? null : _sourceFilter,
                      hint: const Text('Source filter'),
                      items: _sources
                          .map((s) => DropdownMenuItem<String>(
                                value: s.sourceKey,
                                child: Text(s.sourceName),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() => _sourceFilter = value ?? '');
                        _load();
                      },
                    ),
                    OutlinedButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              textAlign: isArabic ? TextAlign.right : TextAlign.left,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Ask with evidence-only citations',
              ),
              onChanged: (value) => _question = value,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _ask,
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Ask'),
                ),
                OutlinedButton.icon(
                  onPressed: _searchLocal,
                  icon: const Icon(Icons.search),
                  label: const Text('Search local DB'),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),
            ],
            if (_answer != null) ...[
              const SizedBox(height: 12),
              Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _answer!.answer,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      if (_answer!.fallbackUsed)
                        Container(
                          margin: const EdgeInsets.only(top: 10),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF8E1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Evidence-only fallback active: no verified evidence found.',
                          ),
                        ),
                      if (_answer!.fatwaSensitive)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'Fatwa-sensitive query: response is informational only.',
                            style: TextStyle(fontStyle: FontStyle.italic),
                          ),
                        ),
                      if (_answer!.citations.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _answer!.citations
                              .map((citation) => CitationBadge(source: citation))
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      children: [
                        Text('Documents (${_documents.length})'),
                        const SizedBox(height: 6),
                        ..._documents.take(30).map(
                              (d) => Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  dense: true,
                                  title: Text(d.title),
                                  subtitle: Text('${d.sourceType} • ${d.language}'),
                                ),
                              ),
                            ),
                        if (_searchResults.isNotEmpty) ...[
                          const Divider(),
                          Text('Search results (${_searchResults.length})'),
                          ..._searchResults.take(20).map(
                                (hit) => Card(
                                  margin: const EdgeInsets.only(top: 8),
                                  child: ListTile(
                                    title: Text(hit.documentTitle),
                                    subtitle: Text(hit.chunkText),
                                    trailing: Text(hit.citationLabel),
                                  ),
                                ),
                              ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.title,
    required this.subtitle,
    required this.chips,
  });

  final String title;
  final String subtitle;
  final List<Widget> chips;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.85),
            Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
          ],
        ),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: chips),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$label: $value'),
      side: BorderSide(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)),
    );
  }
}
