import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:path_provider/path_provider.dart';

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.dark;
  void toggleTheme() => setState(() => _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: _themeMode,
      home: MainScreen(toggleTheme: toggleTheme),
    );
  }
}

class MainScreen extends StatefulWidget {
  final VoidCallback toggleTheme;
  const MainScreen({super.key, required this.toggleTheme});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  List<Map<String, dynamic>> _allMatches = [];
  List<Map<String, dynamic>> _savedTips = [];
  bool _isLoading = false;
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    await _loadSavedTips();
    await _loadMatches();
  }

  Future<String> _getPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/pro_analyzer_turbo.json';
  }

  Future<void> _loadSavedTips() async {
    final file = File(await _getPath());
    if (await file.exists()) {
      try {
        final content = await file.readAsString();
        setState(() => _savedTips = List<Map<String, dynamic>>.from(json.decode(content)));
      } catch (_) {}
    }
  }

  Future<void> _saveTips() async {
    final file = File(await _getPath());
    await file.writeAsString(json.encode(_savedTips));
  }

  void _analyze(Map<String, dynamic> m) {
    showDialog(context: context, builder: (_) => BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor.withOpacity(0.9),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text("${m['home']} vs ${m['away']}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.amber)),
            const SizedBox(height: 15),
            _buildStatRow(Icons.sports_soccer, "Várható kimenetel", "Hazai Győzelem (1)", "78% Conf", Colors.blue),
            _buildStatRow(Icons.radio_button_checked, "Szöglet (O/U)", "Over 9.5", "85% Conf", Colors.green, isBest: true),
            _buildStatRow(Icons.warning_amber, "Szabálytalanság (O/U)", "Over 24.5", "68% Conf", Colors.orange),
            _buildStatRow(Icons.track_changes, "Kapuralövés (O/U)", "Over 8.5", "72% Conf", Colors.red),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                setState(() => _savedTips.add({"match": "${m['home']} - ${m['away']}", "pick": "Hazai Győzelem"}));
                _saveTips(); Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
              child: const Text("Tipp mentése"),
            ),
          ]),
        ),
      ),
    ));
  }

  Widget _buildStatRow(IconData icon, String title, String value, String conf, Color color, {bool isBest = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(children: [
      Icon(icon, color: isBest ? Colors.amber : color, size: 22),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(conf, style: TextStyle(fontSize: 10, color: Colors.grey)),
      ]),
      const Spacer(),
      Text(value, style: const TextStyle(fontWeight: FontWeight.bold))
    ]),
  );

  Future<void> _loadMatches() async {
    setState(() => _isLoading = true);
    try {
      String dateStr = DateTime.now().toString().substring(0, 10);
      var client = HttpClient();
      var req = await client.getUrl(Uri.parse('https://v3.football.api-sports.io/fixtures?date=$dateStr'));
      req.headers.add('x-rapidapi-key', '1c45d28585a3aac87ced5ab96062b57f');
      var res = await req.close();
      if (res.statusCode == 200) {
        var data = json.decode(await res.transform(utf8.decoder).join())['response'];
        setState(() => _allMatches = List<Map<String, dynamic>>.from(data.map((m) => {
          "home": m['teams']['home']['name'],
          "away": m['teams']['away']['name'],
          "logo": m['league']['logo'],
        })));
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("AI PRO ANALYZER", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [IconButton(icon: const Icon(Icons.brightness_6), onPressed: widget.toggleTheme)],
        bottom: PreferredSize(preferredSize: const Size.fromHeight(60), child: Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(decoration: const InputDecoration(hintText: "Csapat keresése...", prefixIcon: Icon(Icons.search)), onChanged: (v) => setState(() => _searchQuery = v)),
        )),
      ),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : ListView.builder(
        itemCount: _selectedIndex == 0 ? _allMatches.length : _savedTips.length,
        itemBuilder: (_, i) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Colors.blueGrey.withOpacity(0.3), Colors.transparent]),
            borderRadius: BorderRadius.circular(15),
          ),
          child: ListTile(
            leading: _selectedIndex == 0 ? Image.network(_allMatches[i]['logo'] ?? "", width: 40, errorBuilder: (_,__,___) => const Icon(Icons.sports_soccer)) : const Icon(Icons.history),
            title: Text(_selectedIndex == 0 ? "${_allMatches[i]['home']} - ${_allMatches[i]['away']}" : _savedTips[i]['match']),
            subtitle: _selectedIndex == 0 ? null : Text(_savedTips[i]['pick'], style: const TextStyle(color: Colors.amber)),
            onTap: () => _selectedIndex == 0 ? _analyze(_allMatches[i]) : null,
            trailing: _selectedIndex == 1 ? IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => setState(() => _savedTips.removeAt(i))) : null,
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        items: const [BottomNavigationBarItem(icon: Icon(Icons.sports_soccer), label: "Meccsek"), BottomNavigationBarItem(icon: Icon(Icons.history), label: "Profit")],
      ),
    );
  }
}
