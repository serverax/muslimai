import 'package:flutter/material.dart';

import '../services/api_service.dart';

/// PHASE 3 — Quran reader + search + tafsir, all from the backend corpus
/// (every ayah shows its source reference). Public, no login.
class QuranScreen extends StatefulWidget {
  const QuranScreen({super.key, required this.api});
  final ApiService api;
  @override
  State<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends State<QuranScreen> {
  List<dynamic> _surahs = [];
  List<dynamic> _searchResults = [];
  final _search = TextEditingController();
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await widget.api.quranSurahs();
      if (mounted) setState(() => _surahs = (r['surahs'] as List<dynamic>?) ?? []);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load Quran: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _doSearch() async {
    if (_search.text.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    try {
      final r = await widget.api.quranSearch(_search.text.trim());
      if (mounted) setState(() => _searchResults = (r['results'] as List<dynamic>?) ?? []);
    } catch (e) {
      if (mounted) setState(() => _error = 'Search failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quran')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: TextField(
            controller: _search,
            decoration: InputDecoration(
              hintText: 'Search Quran (English)…',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: _doSearch),
            ),
            onSubmitted: (_) => _doSearch(),
          ),
        ),
        if (_error != null)
          Padding(padding: const EdgeInsets.all(8), child: Text(_error!, style: const TextStyle(color: Colors.red))),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _searchResults.isNotEmpty
                  ? ListView(children: _searchResults.map((a) => _ayahTile(a as Map<String, dynamic>)).toList())
                  : ListView.builder(
                      itemCount: _surahs.length,
                      itemBuilder: (context, i) {
                        final s = _surahs[i] as Map<String, dynamic>;
                        return ListTile(
                          leading: CircleAvatar(child: Text('${s['surah_number']}')),
                          title: Text('${s['name_en']}  (${s['name_ar']})'),
                          subtitle: Text('${s['ayah_count']} ayahs'),
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => SurahScreen(api: widget.api, surah: s['surah_number'] as int, name: s['name_en'].toString()),
                          )),
                        );
                      },
                    ),
        ),
      ]),
    );
  }

  Widget _ayahTile(Map<String, dynamic> a) => Card(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a['text_arabic'].toString(),
                textAlign: TextAlign.right, textDirection: TextDirection.rtl, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 6),
            Text(a['translation_en'].toString()),
            const SizedBox(height: 4),
            Text('${a['source_reference']} · ${a['translation_source']}',
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ]),
        ),
      );
}

class SurahScreen extends StatefulWidget {
  const SurahScreen({super.key, required this.api, required this.surah, required this.name});
  final ApiService api;
  final int surah;
  final String name;
  @override
  State<SurahScreen> createState() => _SurahScreenState();
}

class _SurahScreenState extends State<SurahScreen> {
  List<dynamic> _ayahs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    widget.api.quranSurah(widget.surah).then((r) {
      if (mounted) setState(() { _ayahs = (r['ayahs'] as List<dynamic>?) ?? []; _loading = false; });
    }).catchError((_) { if (mounted) setState(() => _loading = false); });
  }

  Future<void> _showTafsir(int ayah) async {
    try {
      final r = await widget.api.quranTafsir(widget.surah, ayah);
      final t = (r['tafsir'] as List<dynamic>?) ?? [];
      if (!mounted) return;
      showDialog(context: context, builder: (_) => AlertDialog(
        title: Text('Tafsir ${widget.surah}:$ayah'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
          children: t.map((x) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(x['tafsir_text'].toString()),
            Text(x['source_reference'].toString(), style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ]))).toList())),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No tafsir seeded for this ayah.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.name)),
      body: _loading ? const Center(child: CircularProgressIndicator()) : ListView.builder(
        itemCount: _ayahs.length,
        itemBuilder: (context, i) {
          final a = _ayahs[i] as Map<String, dynamic>;
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('${a['surah_number']}:${a['ayah_number']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  TextButton(onPressed: () => _showTafsir(a['ayah_number'] as int), child: const Text('Tafsir')),
                ]),
                Text(a['text_arabic'].toString(), textAlign: TextAlign.right, textDirection: TextDirection.rtl, style: const TextStyle(fontSize: 22)),
                const SizedBox(height: 6),
                Text(a['translation_en'].toString()),
                const SizedBox(height: 4),
                Text(a['source_reference'].toString(), style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ]),
            ),
          );
        },
      ),
    );
  }
}

class HadithScreen extends StatefulWidget {
  const HadithScreen({super.key, required this.api});
  final ApiService api;
  @override
  State<HadithScreen> createState() => _HadithScreenState();
}

class _HadithScreenState extends State<HadithScreen> {
  final _search = TextEditingController(text: 'intention');
  List<dynamic> _results = [];
  List<dynamic> _collections = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.api.hadithCollections().then((r) {
      if (mounted) setState(() => _collections = (r['collections'] as List<dynamic>?) ?? []);
    }).catchError((_) {});
    _doSearch();
  }

  Future<void> _doSearch() async {
    if (_search.text.trim().isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      final r = await widget.api.hadithSearch(_search.text.trim());
      if (mounted) setState(() => _results = (r['results'] as List<dynamic>?) ?? []);
    } catch (e) {
      if (mounted) setState(() => _error = 'Search failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _gradeColor(String g) => g.toLowerCase().contains('sahih') ? Colors.green : Colors.orange;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hadith')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: TextField(
            controller: _search,
            decoration: InputDecoration(
              hintText: 'Search hadith…',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: _doSearch),
            ),
            onSubmitted: (_) => _doSearch(),
          ),
        ),
        if (_collections.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text('${_collections.length} collections seeded', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ),
        if (_error != null) Padding(padding: const EdgeInsets.all(8), child: Text(_error!, style: const TextStyle(color: Colors.red))),
        Expanded(
          child: _loading ? const Center(child: CircularProgressIndicator()) : ListView.builder(
            itemCount: _results.length,
            itemBuilder: (context, i) {
              final h = _results[i] as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Expanded(child: Text('${h['collection']} #${h['hadith_number']}', style: const TextStyle(fontWeight: FontWeight.bold))),
                      Chip(label: Text(h['grading'].toString()), backgroundColor: _gradeColor(h['grading'].toString()).withValues(alpha: 0.15)),
                    ]),
                    if (h['text_arabic'] != null)
                      Padding(padding: const EdgeInsets.only(top: 6), child: Text(h['text_arabic'].toString(), textAlign: TextAlign.right, textDirection: TextDirection.rtl, style: const TextStyle(fontSize: 18))),
                    const SizedBox(height: 6),
                    Text(h['text_english'].toString()),
                    const SizedBox(height: 4),
                    Text('${h['narrator'] ?? ''} · ${h['source_reference']}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ]),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}
