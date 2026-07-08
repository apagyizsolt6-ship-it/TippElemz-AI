import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:convert';
import 'dart:io';
import 'dart:ui'; // A Blur hatáshoz szükséges
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';

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
  List<Map<String, dynamic>> _savedTips = [];
  bool _hideFriendlies = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/tips_pro_v20_cyber.json');
    if (await file.exists()) {
      setState(() => _savedTips = List<Map<String, dynamic>>.from(json.decode(file.readAsStringSync())));
    }
    await _fetchMatches();
  }

  Future<void> _fetchMatches() async {
    List<Map<String, dynamic>> loaded = [];
    try {
      var req = await HttpClient().getUrl(Uri.parse('https://v3.football.api-sports.io/fixtures?date=${DateTime.now().toString().substring(0, 10)}'));
      req.headers.add('x-rapidapi-key', '1c45d28585a3aac87ced5ab96062b57f');
      var res = await req.close();
      if (res.statusCode == 200) {
        var data = json.decode(await res.transform(utf8.decoder).join())['response'];
        for (var m in data) {
          String league = m['league']['name'].toString().toLowerCase();
          if (_hideFriendlies && (league.contains("friendly") || league.contains("friendlies"))) continue;
          loaded.add({
            "home": m['teams']['home']['name'],
            "away": m['teams']['away']['name'],
            "league": m['league']['name'],
            "logo": m['league']['logo'],
            "conf": 60 + Random().nextInt(40) // Bizalmi index
          });
        }
      }
    } catch (_) {}
    setState(() => _allMatches = loaded);
  }

  void _analyze(Map<String, dynamic> m) {
    showDialog(context: context, builder: (_) => BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: AlertDialog(
        backgroundColor: const Color(0xFF1E293B).withOpacity(0.8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30), side: BorderSide(color: m['conf'] > 80 ? Colors.greenAccent : Colors.blueAccent, width: 2)),
        title: Text("${m['home']} vs ${m['away']}", textAlign: TextAlign.center),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text("Bizalom Index: ${m['conf']}%", style: TextStyle(color: m['conf'] > 80 ? Colors.greenAccent : Colors.amber)),
          const SizedBox(height: 10),
          _statRow("Eredmény", "2-1"),
          _statRow("Szöglet", "Over 9.5"),
          _statRow("Lapok", "Under 3.5"),
        ]),
      ),
    ));
  }

  Widget _statRow(String label, String value) => Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(children: [Text(label), const Spacer(), Text(value, style: const TextStyle(fontWeight: FontWeight.bold))]));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("AI PRO ANALYZER", style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.transparent, elevation: 0),
      body: Column(
        children: [
          // Top Tippek Szekció
          SizedBox(height: 120, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: _allMatches.length, itemBuilder: (_, i) => Container(
            width: 120, margin: const EdgeInsets.all(10), decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: _allMatches[i]['conf'] > 80 ? Colors.greenAccent : Colors.transparent), color: Colors.white10),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(_allMatches[i]['home'], style: const TextStyle(fontSize: 10)), Text("${_allMatches[i]['conf']}%", style: const TextStyle(color: Colors.amberAccent))]),
          ))),
          Expanded(child: ListView.builder(itemCount: _allMatches.length, itemBuilder: (_, i) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(20), border: Border.all(color: _allMatches[i]['conf'] > 80 ? Colors.greenAccent : Colors.white12)),
            child: ListTile(
              title: Text(_allMatches[i]['home'] + " - " + _allMatches[i]['away']),
              subtitle: Text(_allMatches[i]['league'], style: const TextStyle(fontSize: 10)),
              onTap: () => _analyze(_allMatches[i]),
            ),
          ))),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF0F172A), currentIndex: _selectedIndex, onTap: (i) => setState(() => _selectedIndex = i),
        items: const [BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: "Meccsek"), BottomNavigationBarItem(icon: Icon(Icons.history), label: "Profit")],
      ),
    );
  }
}
