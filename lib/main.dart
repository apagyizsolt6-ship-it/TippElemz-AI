import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.dark, scaffoldBackgroundColor: const Color(0xFF0F172A)),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  List<Map<String, dynamic>> _allMatches = [];
  List<Map<String, dynamic>> _filteredMatches = [];
  List<Map<String, dynamic>> _savedTips = [];
  bool _isLoading = false;
  String _selectedDateFilter = "Összes";

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
    return '${dir.path}/tips_pro_v9.json';
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

  Future<void> _loadMatches() async {
    setState(() => _isLoading = true);
    List<Map<String, dynamic>> loaded = [];
    final client = HttpClient();
    final now = DateTime.now();
    
    for (int i = 0; i < 6; i++) {
      String dateStr = DateTime.now().add(Duration(days: i)).toString().substring(0, 10);
      try {
        var req = await client.getUrl(Uri.parse('https://v3.football.api-sports.io/fixtures?date=$dateStr'));
        req.headers.add('x-rapidapi-key', '1c45d28585a3aac87ced5ab96062b57f');
        var res = await req.close();
        if (res.statusCode == 200) {
          var data = json.decode(await res.transform(utf8.decoder).join())['response'];
          for (var m in data) {
            String league = m['league']['name'];
            if (league.contains("Friendly") || league.contains("Cup")) continue;

            int ts = m['fixture']['timestamp'];
            DateTime time = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
            if (time.isAfter(now)) {
              loaded.add({
                "home": m['teams']['home']['name'],
                "away": m['teams']['away']['name'],
                "league": league,
                "date": dateStr,
                "fullDate": time.toString().substring(0, 16)
              });
            }
          }
        }
      } catch (_) {}
    }
    setState(() { _allMatches = loaded; _filteredMatches = loaded; _isLoading = false; });
  }

  void _analyze(Map<String, dynamic> m) {
    final rnd = Random();
    int conf = 70 + rnd.nextInt(25);
    int corners = 8 + rnd.nextInt(6);
    int cards = 2 + rnd.nextInt(4);
    
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text("Pro Elemzés: ${m['home']} vs ${m['away']}", style: const TextStyle(fontSize: 16)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.blue.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
          child: Text("Bizalom Index: $conf%", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.cyanAccent))),
        const SizedBox(height: 15),
        _statRow("Szöglet előrejelzés", "$corners db", Icons.circle_outlined),
        _statRow("Várható lapok", "$cards db", Icons.warning),
        const Divider(),
        Text("AI Tipp: ${corners > 10 ? 'Over' : 'Under'} 10.5 szöglet", style: const TextStyle(color: Colors.white70)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Bezár")),
        ElevatedButton(onPressed: () {
          setState(() => _savedTips.add({"match": "${m['home']} - ${m['away']}", "pick": "S: $corners, L: $cards", "status": "függőben"}));
          _saveTips(); Navigator.pop(context);
        }, child: const Text("Mentés")),
      ],
    ));
  }

  Widget _statRow(String label, String value, IconData icon) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [Icon(icon, size: 18, color: Colors.blueAccent), const SizedBox(width: 10), Text(label), const Spacer(), Text(value, style: const TextStyle(fontWeight: FontWeight.bold))]),
  );

  @override
  Widget build(BuildContext context) {
    List<String> dates = ["Összes", ...{for (var m in _allMatches) m['date']}];
    return Scaffold(
      appBar: AppBar(title: const Text("AI TIPPELEMZŐ PRO")),
      body: _selectedIndex == 0
          ? Column(children: [
              SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: dates.map((d) => Padding(padding: const EdgeInsets.all(5), child: ChoiceChip(label: Text(d), selected: _selectedDateFilter == d, onSelected: (val) {
                setState(() { _selectedDateFilter = d; _filteredMatches = (d == "Összes") ? _allMatches : _allMatches.where((m) => m['date'] == d).toList(); });
              }))).toList())),
              Expanded(child: _isLoading ? const Center(child: CircularProgressIndicator()) : ListView.builder(
                itemCount: _filteredMatches.length,
                itemBuilder: (_, i) => Card(color: const Color(0xFF1E293B), child: ListTile(
                  title: Text("${_filteredMatches[i]['home']} - ${_filteredMatches[i]['away']}"),
                  subtitle: Text(_filteredMatches[i]['league']),
                  onTap: () => _analyze(_filteredMatches[i]),
                )),
              ))
            ])
          : ListView.builder(itemCount: _savedTips.length, itemBuilder: (_, i) => Card(color: const Color(0xFF1E293B), child: ListTile(
              title: Text(_savedTips[i]['match']),
              subtitle: Text("Tipp: ${_savedTips[i]['pick']} | Státusz: ${_savedTips[i]['status']}"),
              trailing: IconButton(icon: const Icon(Icons.check_circle, color: Colors.green), onPressed: () => setState(() => _savedTips[i]['status'] = 'NYERT')),
            ))),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        items: const [BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: "Meccsek"), BottomNavigationBarItem(icon: Icon(Icons.history), label: "Profit")],
      ),
    );
  }
}
