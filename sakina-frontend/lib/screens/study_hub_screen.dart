import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'islamic_library_screen.dart';
import 'quran_corpus_screen.dart';

/// Quran / Tafsir / Hadith / Sources study hub.
class StudyHubScreen extends StatefulWidget {
  const StudyHubScreen({super.key, required this.api, this.session});

  final ApiService api;
  final AuthSession? session;

  @override
  State<StudyHubScreen> createState() => _StudyHubScreenState();
}

class _StudyHubScreenState extends State<StudyHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quran Study'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Quran'),
            Tab(text: 'Tafsir'),
            Tab(text: 'Hadith'),
            Tab(text: 'Sources'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          QuranScreen(api: widget.api),
          _TafsirTab(api: widget.api),
          HadithScreen(api: widget.api),
          const IslamicLibraryScreen(),
        ],
      ),
    );
  }
}

class _TafsirTab extends StatefulWidget {
  const _TafsirTab({required this.api});
  final ApiService api;

  @override
  State<_TafsirTab> createState() => _TafsirTabState();
}

class _TafsirTabState extends State<_TafsirTab> {
  final _surah = TextEditingController(text: '1');
  final _ayah = TextEditingController(text: '1');
  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = false;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final s = int.tryParse(_surah.text.trim());
    final a = int.tryParse(_ayah.text.trim());
    if (s == null || a == null) {
      setState(() {
        _loading = false;
        _error = 'Enter valid surah and ayah numbers.';
      });
      return;
    }
    try {
      final r = await widget.api.quranTafsir(s, a);
      if (mounted) setState(() => _data = r);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load tafsir: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _surah,
                decoration: const InputDecoration(labelText: 'Surah', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _ayah,
                decoration: const InputDecoration(labelText: 'Ayah', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            FilledButton(onPressed: _loading ? null : _load, child: const Text('Load tafsir')),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () {
                _surah.text = '1';
                _ayah.text = '1';
                setState(() {
                  _data = null;
                  _error = null;
                });
              },
              child: const Text('Clear'),
            ),
          ],
        ),
        if (_loading) const LinearProgressIndicator(),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        if (_data != null) ...[
          const SizedBox(height: 12),
          Text(_data!['text']?.toString() ?? _data!['tafsir']?.toString() ?? 'No tafsir text'),
          if (_data!['source'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Source: ${_data!['source']}', style: const TextStyle(color: Colors.grey)),
            ),
        ],
      ],
    );
  }
}
