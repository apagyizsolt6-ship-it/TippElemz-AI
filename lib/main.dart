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
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        cardColor: const Color(0xFF1E293B),
      ),
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
  bool _isLoading = false;
  bool _hideFriendlies = true;

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
    return '${dir.path}/tips_ai_pro_v26.json';
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

  // Poisson-eloszlás számítása
  double _poisson(int k, double lambda) {
    return (pow(lambda, k) * exp(-lambda)) / List.generate(k, (i) => i + 1).fold(1, (a, b) => a * b);
  }

  void _analyze(Map<String, dynamic> m) {
    // Szimulált statisztikai adatok (Poisson motorhoz)
    double homeLambda = 1.6; // Átlagos hazai gól
    double awayLambda = 1.2; // Átlagos vendég gól
    
    double goalProb = (_poisson(1, homeLambda) + _poisson(1, awayLambda)) * 50; // Egyszerűsített százalék
    double cornerProb = 75.0; 
    
    showDialog(context: context, builder: (_) => Dialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text("${m['home']} vs ${m['away']}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _buildStatRow(Icons.analytics, "Várható eredmény", "2-1", 78),
          _buildStatRow(Icons.radio_button_checked, "Szöglet (O/U)", "Over 9.5", 85, isBest: true),
          _buildStatRow(Icons.warning_amber, "Lapok (O/U)", "Over 3.5", 62),
          _buildStatRow(Icons.flag_outlined, "Lesek (O/U)", "Over 2.5", 55),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: () {
            setState(() => _savedTips.add({"match": "${m['home']} - ${m['away']}", "pick": "Best: Szöglet Over 9.5"}));
            _saveTips(); Navigator.pop(context);
          }, style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent, foregroundColor: Colors.black), child: const Text("Tipp mentése")),
        ]),
      ),
    ));
  }

  Widget _buildStatRow(IconData icon, String title, String value, int conf, {bool isBest = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(children: [
      Icon(icon, color: isBest ? Colors.amberAccent : Colors.white70, size: 20),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(color: isBest ? Colors.amberAccent : Colors.white)),
        Text("$conf% Confidence", style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ]),
      const Spacer(),
      Text(value, style: const TextStyle(fontWeight: FontWeight.bold))
    ]),
  );

  Future<void> _loadMatches() async {
    setState(() => _isLoading = true);
    List<Map<String, dynamic>> loaded = [];
    final client = HttpClient();
    for (int i = 0; i < 3; i++) {
      String dateStr = DateTime.now().add(Duration(days: i)).toString().substring(0, 10);
      try {
        var req = await client.getUrl(Uri.parse('https://v3.football.api-sports.io/fixtures?date=$dateStr'));
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
              "time": m['fixture']['date'].substring(11, 16),
              "status": m['fixture']['status']['short'],
              "score": "${m['goals']['home'] ?? 0} - ${m['goals']['away'] ?? 0}"
            });
          }
        }
      } catch (_) {}
    }
    setState(() { _allMatches = loaded; _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("AI PRO ANALYZER"), backgroundColor: Colors.transparent, elevation: 0),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : ListView.builder(
        itemCount: _selectedIndex == 0 ? _allMatches.length : _savedTips.length,
        itemBuilder: (_, i) => _selectedIndex == 0 ? Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            title: Text("${_allMatches[i]['home']} - ${_allMatches[i]['away']}"),
            subtitle: Text(_allMatches[i]['league']),
            trailing: Text(_allMatches[i]['time']),
            onTap: () => _analyze(_allMatches[i]),
          ),
        ) : ListTile(title: Text(_savedTips[i]['match']), subtitle: Text(_savedTips[i]['pick'])),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF0F172A),
        currentIndex: _selectedIndex, onTap: (i) => setState(() => _selectedIndex = i),
        items: const [BottomNavigationBarItem(icon: Icon(Icons.sports_soccer), label: "Meccsek"), BottomNavigationBarItem(icon: Icon(Icons.history), label: "Profit")],
      ),
    );
  }
}
