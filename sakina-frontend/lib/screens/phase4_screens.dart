import 'package:flutter/material.dart';

import '../services/api_service.dart';

/// PHASE 4 — Guides list/detail (public, sourced).
class GuidesScreen extends StatelessWidget {
  const GuidesScreen({super.key, required this.api});
  final ApiService api;

  static const _guides = [
    ['wudu', 'How to perform Wudu'],
    ['salah', 'How to pray (Salah)'],
    ['ramadan', 'Fasting in Ramadan'],
    ['hajj-umrah', 'Hajj & Umrah'],
    ['new-muslim', 'New Muslim first steps'],
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Guides')),
      body: ListView(
        children: _guides
            .map((g) => ListTile(
                  leading: const Icon(Icons.article_outlined),
                  title: Text(g[1]),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => GuideDetailScreen(api: api, slug: g[0], title: g[1]),
                  )),
                ))
            .toList(),
      ),
    );
  }
}

class GuideDetailScreen extends StatefulWidget {
  const GuideDetailScreen({super.key, required this.api, required this.slug, required this.title});
  final ApiService api;
  final String slug;
  final String title;
  @override
  State<GuideDetailScreen> createState() => _GuideDetailScreenState();
}

class _GuideDetailScreenState extends State<GuideDetailScreen> {
  Map<String, dynamic>? _g;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.api.guide(widget.slug).then((r) {
      if (mounted) setState(() => _g = r);
    }).catchError((e) {
      if (mounted) setState(() => _error = 'Could not load guide: $e');
    });
  }

  @override
  Widget build(BuildContext context) {
    final steps = (_g?['steps'] as List<dynamic>?) ?? [];
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: _error != null
          ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
          : _g == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(padding: const EdgeInsets.all(16), children: [
                  ...steps.map((s) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(s.toString(), style: const TextStyle(fontSize: 16)),
                      )),
                  const SizedBox(height: 12),
                  Text('Source: ${_g?['source_reference']}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ]),
    );
  }
}

/// PHASE 4 — Masjid near me (honest provider fallback).
class MasjidScreen extends StatefulWidget {
  const MasjidScreen({super.key, required this.api});
  final ApiService api;
  @override
  State<MasjidScreen> createState() => _MasjidScreenState();
}

class _MasjidScreenState extends State<MasjidScreen> {
  Map<String, dynamic>? _r;

  @override
  void initState() {
    super.initState();
    widget.api.masjidNearby().then((r) {
      if (mounted) setState(() => _r = r);
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final status = _r?['status']?.toString() ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('Masjid Near Me')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _r == null
              ? const CircularProgressIndicator()
              : Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.mosque, size: 64, color: Colors.teal),
                  const SizedBox(height: 16),
                  Text(
                    status == 'provider_not_configured'
                        ? 'Masjid search needs a maps provider to be configured. '
                            'No fake results are shown.'
                        : 'Masjid search is being set up. No fake results are shown.',
                    textAlign: TextAlign.center,
                  ),
                ]),
        ),
      ),
    );
  }
}

/// PHASE 4 — Kids learning quiz (real flow from backend; saves progress if logged in).
class KidsLearningScreen extends StatefulWidget {
  const KidsLearningScreen({super.key, required this.api, this.loggedIn = false});
  final ApiService api;
  final bool loggedIn;
  @override
  State<KidsLearningScreen> createState() => _KidsLearningScreenState();
}

class _KidsLearningScreenState extends State<KidsLearningScreen> {
  List<dynamic> _questions = [];
  int _index = 0;
  int _score = 0;
  bool _loading = true;
  bool _finished = false;
  int? _selected;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.api.kidsQuiz().then((r) {
      if (mounted) {
        setState(() {
          _questions = (r['questions'] as List<dynamic>?) ?? [];
          _loading = false;
        });
      }
    }).catchError((e) {
      if (mounted) setState(() { _error = 'Could not load quiz: $e'; _loading = false; });
    });
  }

  void _answer(int i) {
    if (_selected != null) return;
    final q = _questions[_index] as Map<String, dynamic>;
    final correct = q['correct_index'] as int;
    setState(() {
      _selected = i;
      if (i == correct) _score++;
    });
  }

  Future<void> _next() async {
    if (_index + 1 < _questions.length) {
      setState(() { _index++; _selected = null; });
    } else {
      setState(() => _finished = true);
      if (widget.loggedIn) {
        try {
          await widget.api.saveKidsProgress(activity: 'quiz', score: _score, total: _questions.length);
        } catch (_) {}
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(appBar: AppBar(title: const Text('Kids Quiz')), body: const Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(appBar: AppBar(title: const Text('Kids Quiz')), body: Center(child: Text(_error!, style: const TextStyle(color: Colors.red))));
    }
    if (_finished) {
      return Scaffold(
        appBar: AppBar(title: const Text('Kids Quiz')),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.star, size: 72, color: Colors.amber),
            const SizedBox(height: 12),
            Text('Score: $_score / ${_questions.length}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(widget.loggedIn ? 'Progress saved to your account.' : 'Log in to save your progress.',
                style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            FilledButton(onPressed: () => setState(() { _index = 0; _score = 0; _finished = false; _selected = null; }), child: const Text('Play again')),
          ]),
        ),
      );
    }
    final q = _questions[_index] as Map<String, dynamic>;
    final options = (q['options'] as List<dynamic>?) ?? [];
    final correct = q['correct_index'] as int;
    return Scaffold(
      appBar: AppBar(title: Text('Kids Quiz (${_index + 1}/${_questions.length})')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(q['question'].toString(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        ...List.generate(options.length, (i) {
          Color? c;
          if (_selected != null) {
            if (i == correct) {
              c = Colors.green.withValues(alpha: 0.2);
            } else if (i == _selected) {
              c = Colors.red.withValues(alpha: 0.2);
            }
          }
          return Card(
            color: c,
            child: ListTile(
              title: Text(options[i].toString()),
              onTap: () => _answer(i),
            ),
          );
        }),
        if (_selected != null) ...[
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(q['explanation'].toString(), style: const TextStyle(color: Colors.black87)),
          ),
          Text('Source: ${q['source_reference']}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 8),
          FilledButton(onPressed: _next, child: Text(_index + 1 < _questions.length ? 'Next' : 'Finish')),
        ],
      ]),
    );
  }
}
