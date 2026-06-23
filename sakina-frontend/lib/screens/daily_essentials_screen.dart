import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'phase4_screens.dart';
import 'quran_corpus_screen.dart';

/// PHASE 2 hub: Prayer Times, Islamic Calendar, Dua Library (public),
/// Bookmarks + Reminders (login required), Adhan settings (local-only).
class DailyEssentialsScreen extends StatelessWidget {
  DailyEssentialsScreen({super.key, ApiService? api, this.session})
      : api = api ?? ApiService(baseUrl: ApiConfig.baseUrl) {
    if (session != null) this.api.setAuthToken(session!.accessToken);
  }

  final ApiService api;
  final AuthSession? session;

  void _go(BuildContext c, Widget s) =>
      Navigator.of(c).push(MaterialPageRoute(builder: (_) => s));

  @override
  Widget build(BuildContext context) {
    final loggedIn = session != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Daily Essentials')),
      body: ListView(children: [
        _tile(context, Icons.menu_book_rounded, 'Quran', 'Read & search, with sources',
            () => _go(context, QuranScreen(api: api))),
        _tile(context, Icons.format_quote, 'Hadith', 'Search authentic hadith',
            () => _go(context, HadithScreen(api: api))),
        _tile(context, Icons.access_time, 'Prayer Times', 'No login needed',
            () => _go(context, PrayerTimesScreen(api: api))),
        _tile(context, Icons.calendar_month, 'Islamic Calendar', 'No login needed',
            () => _go(context, IslamicCalendarScreen(api: api))),
        _tile(context, Icons.menu_book, 'Dua Library', 'No login needed',
            () => _go(context, DuaLibraryScreen(api: api, loggedIn: loggedIn))),
        _tile(
            context,
            Icons.bookmark,
            'Bookmarks',
            loggedIn ? 'Your saved items' : 'Login required',
            () => loggedIn
                ? _go(context, BookmarksScreen(api: api))
                : _loginNeeded(context)),
        _tile(
            context,
            Icons.notifications,
            'Reminders',
            loggedIn ? 'Your reminders' : 'Login required',
            () => loggedIn
                ? _go(context, RemindersScreen(api: api))
                : _loginNeeded(context)),
        _tile(context, Icons.volume_up, 'Adhan Settings', 'On this device',
            () => _go(context, const AdhanSettingsScreen())),
        _tile(context, Icons.article_outlined, 'Guides', 'Wudu, Salah, Ramadan, Hajj, New Muslim',
            () => _go(context, GuidesScreen(api: api))),
        _tile(context, Icons.mosque, 'Masjid Near Me', 'Location-based (provider needed)',
            () => _go(context, MasjidScreen(api: api))),
        _tile(context, Icons.child_care, 'Kids Quiz', 'Fun Islamic learning',
            () => _go(context, KidsLearningScreen(api: api, loggedIn: loggedIn))),
      ]),
    );
  }

  void _loginNeeded(BuildContext c) => ScaffoldMessenger.of(c).showSnackBar(
      const SnackBar(content: Text('Please log in to use this feature.')));

  Widget _tile(BuildContext c, IconData i, String t, String s, VoidCallback tap) =>
      Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: ListTile(
          leading: Icon(i),
          title: Text(t),
          subtitle: Text(s),
          trailing: const Icon(Icons.chevron_right),
          onTap: tap,
        ),
      );
}

// --------------------------- Prayer Times ---------------------------
class PrayerTimesScreen extends StatefulWidget {
  const PrayerTimesScreen({super.key, required this.api});
  final ApiService api;
  @override
  State<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen> {
  final _lat = TextEditingController(text: '51.5074');
  final _lng = TextEditingController(text: '-0.1278');
  final _tz = TextEditingController(text: '1');
  Map<String, dynamic>? _times;
  String? _error;
  bool _loading = false;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _times = null;
    });
    final lat = double.tryParse(_lat.text.trim());
    final lng = double.tryParse(_lng.text.trim());
    if (lat == null || lng == null) {
      setState(() {
        _loading = false;
        _error = 'Enter a valid latitude and longitude.';
      });
      return;
    }
    try {
      final now = DateTime.now();
      final date =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final r = await widget.api.prayerTimes(
          lat: lat, lng: lng, date: date, tz: double.tryParse(_tz.text) ?? 0);
      setState(() => _times = r);
    } catch (e) {
      setState(() => _error = 'Could not load prayer times: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Widget _row(String n, String? v) => ListTile(
      title: Text(n), trailing: Text(v ?? '--', style: const TextStyle(fontSize: 18)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Prayer Times')),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        Row(children: [
          Expanded(child: _f(_lat, 'Latitude')),
          const SizedBox(width: 8),
          Expanded(child: _f(_lng, 'Longitude')),
          const SizedBox(width: 8),
          SizedBox(width: 70, child: _f(_tz, 'TZ')),
        ]),
        const SizedBox(height: 8),
        FilledButton(
            onPressed: _loading ? null : _load,
            child: Text(_loading ? 'Loading…' : 'Get Times')),
        if (_error != null)
          Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!, style: const TextStyle(color: Colors.red))),
        if (_times != null) ...[
          _row('Fajr', _times!['fajr']),
          _row('Sunrise', _times!['sunrise']),
          _row('Dhuhr', _times!['dhuhr']),
          _row('Asr', _times!['asr']),
          _row('Maghrib', _times!['maghrib']),
          _row('Isha', _times!['isha']),
          Padding(
              padding: const EdgeInsets.all(12),
              child: Text('${_times!['note']}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey))),
        ],
      ]),
    );
  }
}

// --------------------------- Islamic Calendar ---------------------------
class IslamicCalendarScreen extends StatefulWidget {
  const IslamicCalendarScreen({super.key, required this.api});
  final ApiService api;
  @override
  State<IslamicCalendarScreen> createState() => _IslamicCalendarScreenState();
}

class _IslamicCalendarScreenState extends State<IslamicCalendarScreen> {
  Map<String, dynamic>? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final now = DateTime.now();
      final date =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final r = await widget.api.islamicDates(date);
      if (mounted) setState(() => _data = r);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load calendar: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = _data?['today_hijri'] as Map<String, dynamic>?;
    final dates = (_data?['important_dates'] as List<dynamic>?) ?? [];
    return Scaffold(
      appBar: AppBar(title: const Text('Islamic Calendar')),
      body: _error != null
          ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
          : _data == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(children: [
                  Card(
                    margin: const EdgeInsets.all(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Today',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                            '${h?['day']} ${h?['month_name']} ${h?['year']} AH',
                            style: const TextStyle(fontSize: 20)),
                        Text('Gregorian: ${_data?['gregorian']}'),
                      ]),
                    ),
                  ),
                  const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('Important dates',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  ...dates.map((d) => ListTile(
                        title: Text(d['name'].toString()),
                        subtitle: Text(d['note'].toString()),
                        trailing: Text(
                            '${d['hijri_day']}/${d['hijri_month']}'),
                      )),
                  Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text('${_data?['note']}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey))),
                ]),
    );
  }
}

// --------------------------- Dua Library ---------------------------
class DuaLibraryScreen extends StatefulWidget {
  const DuaLibraryScreen({super.key, required this.api, this.loggedIn = false});
  final ApiService api;
  final bool loggedIn;
  @override
  State<DuaLibraryScreen> createState() => _DuaLibraryScreenState();
}

class _DuaLibraryScreenState extends State<DuaLibraryScreen> {
  final _search = TextEditingController();
  String? _category;
  List<dynamic> _duas = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await widget.api
          .listDuas(category: _category, q: _search.text.trim());
      if (mounted) setState(() => _duas = (r['duas'] as List<dynamic>?) ?? []);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load duas: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _bookmark(Map<String, dynamic> d) async {
    try {
      await widget.api.addBookmark(
          itemType: 'dua', itemRef: d['id'].toString(), label: d['title'].toString());
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Bookmarked.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Bookmark failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dua Library')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: TextField(
            controller: _search,
            decoration: InputDecoration(
              hintText: 'Search duas…',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: _load),
            ),
            onSubmitted: (_) => _load(),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            for (final c in const [
              null, 'morning', 'evening', 'before_sleep', 'after_prayer',
              'protection', 'forgiveness', 'anxiety', 'travel', 'food', 'parents_family'
            ])
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text(c ?? 'all'),
                  selected: _category == c,
                  onSelected: (_) {
                    setState(() => _category = c);
                    _load();
                  },
                ),
              ),
          ]),
        ),
        if (_error != null)
          Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_error!, style: const TextStyle(color: Colors.red))),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  itemCount: _duas.length,
                  itemBuilder: (context, i) {
                    final d = _duas[i] as Map<String, dynamic>;
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: ExpansionTile(
                        title: Text(d['title'].toString()),
                        subtitle: Text(d['category'].toString()),
                        trailing: widget.loggedIn
                            ? IconButton(
                                icon: const Icon(Icons.bookmark_add_outlined),
                                onPressed: () => _bookmark(d))
                            : null,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(d['arabic'].toString(),
                                      textAlign: TextAlign.right,
                                      textDirection: TextDirection.rtl,
                                      style: const TextStyle(fontSize: 22)),
                                  const SizedBox(height: 8),
                                  if (d['transliteration'] != null)
                                    Text(d['transliteration'].toString(),
                                        style: const TextStyle(
                                            fontStyle: FontStyle.italic)),
                                  const SizedBox(height: 8),
                                  Text(d['translation'].toString()),
                                  const SizedBox(height: 8),
                                  Text('Source: ${d['source']}',
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.grey)),
                                ]),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

// --------------------------- Bookmarks ---------------------------
class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key, required this.api});
  final ApiService api;
  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  List<dynamic> _items = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await widget.api.listBookmarks();
      if (mounted) setState(() => _items = (r['bookmarks'] as List<dynamic>?) ?? []);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load bookmarks: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _remove(String id) async {
    try {
      await widget.api.deleteBookmark(id);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Bookmarks')),
      body: _error != null
          ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : _items.isEmpty
                  ? const Center(child: Text('No bookmarks yet.'))
                  : ListView.builder(
                      itemCount: _items.length,
                      itemBuilder: (context, i) {
                        final b = _items[i] as Map<String, dynamic>;
                        return ListTile(
                          leading: const Icon(Icons.bookmark),
                          title: Text(b['label']?.toString() ?? b['item_ref'].toString()),
                          subtitle: Text(b['item_type'].toString()),
                          trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _remove(b['id'].toString())),
                        );
                      },
                    ),
    );
  }
}

// --------------------------- Reminders ---------------------------
class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key, required this.api});
  final ApiService api;
  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  final _title = TextEditingController();
  final _schedule = TextEditingController(text: 'daily 07:00');
  List<dynamic> _items = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await widget.api.listReminders();
      if (mounted) setState(() => _items = (r['reminders'] as List<dynamic>?) ?? []);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load reminders: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add() async {
    if (_title.text.trim().isEmpty) return;
    try {
      await widget.api.addReminder(
          title: _title.text.trim(), schedule: _schedule.text.trim());
      _title.clear();
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Add failed: $e')));
      }
    }
  }

  Future<void> _remove(String id) async {
    try {
      await widget.api.deleteReminder(id);
      await _load();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reminders')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            TextField(
                controller: _title,
                decoration: const InputDecoration(
                    labelText: 'Reminder title', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(
                controller: _schedule,
                decoration: const InputDecoration(
                    labelText: 'Schedule (text, e.g. daily 07:00)',
                    border: OutlineInputBorder())),
            const SizedBox(height: 8),
            FilledButton(onPressed: _add, child: const Text('Add reminder')),
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Reminders are saved to your account. On-device notification firing '
                'is not enabled yet.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ]),
        ),
        if (_error != null)
          Text(_error!, style: const TextStyle(color: Colors.red)),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  itemCount: _items.length,
                  itemBuilder: (context, i) {
                    final r = _items[i] as Map<String, dynamic>;
                    return ListTile(
                      leading: const Icon(Icons.alarm),
                      title: Text(r['title'].toString()),
                      subtitle: Text(r['schedule_rule']?.toString() ?? ''),
                      trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _remove(r['id'].toString())),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

// --------------------------- Adhan Settings (local) ---------------------------
class AdhanSettingsScreen extends StatefulWidget {
  const AdhanSettingsScreen({super.key});
  @override
  State<AdhanSettingsScreen> createState() => _AdhanSettingsScreenState();
}

class _AdhanSettingsScreenState extends State<AdhanSettingsScreen> {
  static const _prayers = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
  final Map<String, bool> _enabled = {for (final p in _prayers) p: true};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    for (final p in _prayers) {
      _enabled[p] = prefs.getBool('adhan_$p') ?? true;
    }
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _set(String p, bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('adhan_$p', v);
    setState(() => _enabled[p] = v);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Adhan Settings')),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'These settings are stored on this device only (no login). '
                  'Audio adhan playback is not enabled yet.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
              for (final p in _prayers)
                SwitchListTile(
                  title: Text('Adhan for $p'),
                  value: _enabled[p] ?? true,
                  onChanged: (v) => _set(p, v),
                ),
            ]),
    );
  }
}

Widget _f(TextEditingController c, String label) => TextField(
      controller: c,
      keyboardType:
          const TextInputType.numberWithOptions(decimal: true, signed: true),
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
    );
