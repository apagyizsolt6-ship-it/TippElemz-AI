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
      theme: ThemeData(brightness: Brightness.dark, scaffoldBackgroundColor: const Color(0xFF0F172A), primaryColor: const Color(0xFF3B82F6)),
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
            int ts = m['fixture']['timestamp'];
            DateTime matchTime = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
            if (matchTime.isAfter(now)) {
              loaded.add({
                "home": m['teams']['home']['name'],
                "away": m['teams']['away']['name'],
                "league": m['league']['name'],
                "date": dateStr,
                "fullDate": matchTime.toString().substring(0, 16)
              });
            }
          }
        }
      }
    } catch (_) {}
    setState(() { _allMatches = loaded; _filteredMatches = loaded; _isLoading = false; });
  }

  void _filterMatches(String date) {
    setState(() {
      _selectedDateFilter = date;
      if (date == "Összes") {
        _filteredMatches = _allMatches;
      } else {
        _filteredMatches = _allMatches.where((m) => m['date'] == date).toList();
      }
    });
  }

  // --- ANALÍZIS ÉS MENTÉS ---
  void _analyze(Map<String, dynamic> m) {
    final rnd = Random();
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
      title: Text("${m['home']}\nvs\n${m['away']}", textAlign: TextAlign.center),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text("Dátum: ${m['fullDate']}", style: const TextStyle(color: Colors.cyanAccent)),
        const SizedBox(height: 15),
        Text("${rnd.nextInt(3)}-${rnd.nextInt(3)}", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
        const SizedBox(height: 15),
        _statRow("Szöglet", "${8 + rnd.nextInt(5)}", Icons.circle_outlined, Colors.orange),
        _statRow("Büntetőlapok", "${2 + rnd.nextInt(4)}", Icons.warning, Colors.red),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Bezár")),
        ElevatedButton(onPressed: () {
          setState(() => _savedTips.add({"match": "${m['home']} - ${m['away']}", "pick": "Generált", "status": "pending"}));
          Navigator.pop(context);
        }, child: const Text("Mentés")),
      ],
    ));
  }

  Widget _statRow(String label, String value, IconData icon, Color color) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [Icon(icon, size: 16, color: color), const SizedBox(width: 10), Text(label), const Spacer(), Text(value, style: const TextStyle(fontWeight: FontWeight.bold))]),
  );

  @override
  Widget build(BuildContext context) {
    List<String> dates = ["Összes", ...{for (var m in _allMatches) m['date']}];
    
    return Scaffold(
      appBar: AppBar(title: const Text("AI TIPPELEMZŐ PRO")),
      body: _selectedIndex == 0
          ? Column(children: [
              SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: dates.map((d) => Padding(padding: const EdgeInsets.all(5), child: ChoiceChip(label: Text(d), selected: _selectedDateFilter == d, onSelected: (_) => _filterMatches(d)))).toList())),
              Expanded(child: _isLoading ? const Center(child: CircularProgressIndicator()) : ListView.builder(
                itemCount: _filteredMatches.length,
                itemBuilder: (_, i) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                  decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(15)),
                  child: ListTile(
                    title: Text("${_filteredMatches[i]['home']} - ${_filteredMatches[i]['away']}"),
                    subtitle: Text("${_filteredMatches[i]['league']} | ${_filteredMatches[i]['fullDate']}"),
                    onTap: () => _analyze(_filteredMatches[i]),
                  ),
                ),
              ))
            ])
          : Container(), // ... egyéb logika ...
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        items: const [BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: "Meccsek"), BottomNavigationBarItem(icon: Icon(Icons.history), label: "Profit")],
      ),
    );
  }

  Future<void> _loadSavedTips() async {} 
}
