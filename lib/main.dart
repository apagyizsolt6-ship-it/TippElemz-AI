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
    _initEverything();
  }

  Future<void> _initEverything() async {
    await _loadSavedTips();
    await _loadMatches();
  }

  Future<String> _getPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/tips_final_v7.json';
  }

  Future<void> _loadSavedTips() async {
    final path = await _getPath();
    final file = File(path);
    if (await file.exists()) {
      try {
        final content = await file.readAsString();
        setState(() => _savedTips = List<Map<String, dynamic>>.from(json.decode(content)));
      } catch (_) {}
    }
  }

  Future<void> _saveTips() async {
    final path = await _getPath();
    await File(path).writeAsString(json.encode(_savedTips));
  }

  Future<void> _loadMatches() async {
    setState(() => _isLoading = true);
    List<Map<String, dynamic>> loaded = [];
    final client = HttpClient();
    final now = DateTime.now();
    
    try {
      for (int i = 0; i < 6; i++) {
        String dateStr = DateTime.now().add(Duration(days: i)).toString().substring(0, 10);
        var req = await client.getUrl(Uri.parse('https://v3.football.api-sports.io/fixtures?date=$dateStr'));
        req.headers.add('x-rapidapi-key', '1c45d28585a3aac87ced5ab96062b57f');
        var res = await req.close();
        if (res.statusCode == 200) {
          var data = json.decode(await res.transform(utf8.decoder).join())['response'];
          for (var m in data) {
            String leagueName = m['league']['name'];
            if (leagueName.contains("Friendlies")) continue;

            int ts = m['fixture']['timestamp'];
            DateTime matchTime = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
            if (matchTime.isAfter(now)) {
              loaded.add({
                "home": m['teams']['home']['name'],
                "away": m['teams']['away']['name'],
                "league": leagueName,
                "date": dateStr,
                "fullDate": matchTime.toString().substring(0, 16)
              });
            }
          }
        }
      }
    } catch (_) {}
    setState(() { 
      _allMatches = loaded; 
      _filteredMatches = loaded; 
      _isLoading = false; 
    });
  }

  void _analyze(Map<String, dynamic> m) {
    var winsInLeague = _savedTips.where((t) => t['match'].contains(m['league']) && t['status'] == 'NYERT').length;
    var totalInLeague = _savedTips.where((t) => t['match'].contains(m['league'])).length;
    double factor = totalInLeague > 0 ? (1.0 + (winsInLeague / totalInLeague - 0.5)) : 1.0;
    
    int hG = (1.45 * factor * (0.9 + Random().nextDouble() * 0.2)).round();
    int aG = (1.15 / factor * (0.9 + Random().nextDouble() * 0.2)).round();
    
    // Algoritmus által generált többpiacos ajánlatok
    String pick1 = (hG + aG > 2.5) ? "Over 2.5 gól" : "Under 2.5 gól";
    String pick2 = (hG > aG) ? "Hazai győzelem (1)" : ((hG < aG) ? "Vendég győzelem (2)" : "Döntetlen (X)");
    String pick3 = (18 + Random().nextInt(10) > 22) ? "Sok szabálytalanság" : "Kevesebb szabálytalanság";

    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text("${m['home']} vs ${m['away']}", textAlign: TextAlign.center),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text("AI Tippek:", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
        const SizedBox(height: 10),
        _tipCard("Alap tipp", pick2),
        _tipCard("Gólok", pick1),
        _tipCard("Speciál", pick3),
        const Divider(),
        _statRow("Várható eredmény", "$hG - $aG", Icons.score),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Mégse")),
        ElevatedButton(onPressed: () {
          setState(() => _savedTips.add({"match": "${m['home']} - ${m['away']}", "pick": "$pick1 | $pick2", "status": "függőben"}));
          _saveTips();
          Navigator.pop(context);
        }, child: const Text("Tipp mentése")),
      ],
    ));
  }

  Widget _tipCard(String title, String pick) => Container(
    margin: const EdgeInsets.symmetric(vertical: 4),
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
    child: Row(children: [Text("$title: ", style: const TextStyle(color: Colors.grey)), Text(pick, style: const TextStyle(fontWeight: FontWeight.bold))]),
  );

  Widget _statRow(String label, String value, IconData icon) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [Icon(icon, size: 16, color: Colors.blueAccent), const SizedBox(width: 10), Text(label), const Spacer(), Text(value, style: const TextStyle(fontWeight: FontWeight.bold))]),
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
                itemBuilder: (_, i) => Card(margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), color: const Color(0xFF1E293B), child: ListTile(
                  title: Text("${_filteredMatches[i]['home']} - ${_filteredMatches[i]['away']}"),
                  subtitle: Text("${_filteredMatches[i]['league']} | ${_filteredMatches[i]['fullDate']}"),
                  onTap: () => _analyze(_filteredMatches[i]),
                )),
              ))
            ])
          : ListView.builder(itemCount: _savedTips.length, itemBuilder: (_, i) => Card(
              color: const Color(0xFF1E293B),
              child: ListTile(
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
