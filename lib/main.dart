import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:convert';
import 'dart:io';
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
  bool _isLoading = false;

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
    return '${dir.path}/tips_final_v14.json';
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
    
    for (int i = 0; i < 6; i++) {
      String dateStr = DateTime.now().add(Duration(days: i)).toString().substring(0, 10);
      try {
        var req = await client.getUrl(Uri.parse('https://v3.football.api-sports.io/fixtures?date=$dateStr'));
        req.headers.add('x-rapidapi-key', '1c45d28585a3aac87ced5ab96062b57f');
        var res = await req.close();
        if (res.statusCode == 200) {
          var data = json.decode(await res.transform(utf8.decoder).join())['response'];
          for (var m in data) {
            String league = m['league']['name'].toString().toLowerCase();
            if (league.contains("friendly")) continue; // Szigorú szűrés

            loaded.add({
              "home": m['teams']['home']['name'],
              "away": m['teams']['away']['name'],
              "league": m['league']['name'],
              "logo": m['league']['logo'],
              "status": m['fixture']['status']['short'],
              "time": (m['fixture']['status']['short'] == '1H' || m['fixture']['status']['short'] == '2H') 
                      ? "ÉLŐ" 
                      : DateTime.fromMillisecondsSinceEpoch(m['fixture']['timestamp'] * 1000).toString().substring(11, 16)
            });
          }
        }
      } catch (_) {}
    }
    setState(() { _allMatches = loaded; _isLoading = false; });
  }

  void _analyze(Map<String, dynamic> m) {
    final rnd = Random();
    double conf = 70.0 + rnd.nextDouble() * 25.0;
    int hG = rnd.nextInt(3), aG = rnd.nextInt(3);
    String tipText = "Várható: $hG-$aG, O/U: ${(hG+aG>2.5?'Over':'Under')}, Szöglet: ${8+rnd.nextInt(6)}";
    
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: Text("${m['home']} vs ${m['away']}"),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        LinearProgressIndicator(value: conf / 100, color: Colors.cyanAccent),
        const SizedBox(height: 15),
        _statRow("Várható eredmény", "$hG - $aG", Icons.score),
        _statRow("Over/Under 2.5", (hG+aG>2.5) ? "Over" : "Under", Icons.trending_up),
        _statRow("Szöglet tipp", "${8+rnd.nextInt(6)} db", Icons.circle_outlined),
        _statRow("Szabálytalanság", "${18+rnd.nextInt(12)} db", Icons.sports),
      ]),
      actions: [
        IconButton(icon: const Icon(Icons.copy), onPressed: () => Clipboard.setData(ClipboardData(text: tipText))),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Bezár")),
        ElevatedButton(onPressed: () {
          setState(() => _savedTips.add({"match": "${m['home']} - ${m['away']}", "pick": tipText, "status": "függőben"}));
          _saveTips(); Navigator.pop(context);
        }, child: const Text("Mentés")),
      ],
    ));
  }

  Widget _statRow(String label, String value, IconData icon) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [Icon(icon, size: 18, color: Colors.blueAccent), const SizedBox(width: 10), Text(label), const Spacer(), Text(value, style: const TextStyle(fontWeight: FontWeight.bold))]),
  );

  @override
  Widget build(BuildContext context) {
    int won = _savedTips.where((t) => t['status'] == 'NYERT').length;
    double rate = _savedTips.isEmpty ? 0 : (won / _savedTips.length) * 100;

    return Scaffold(
      appBar: AppBar(title: const Text("AI TIPPELEMZŐ PRO")),
      body: _selectedIndex == 0 
        ? ListView.builder(itemCount: _allMatches.length, itemBuilder: (_, i) => Card(margin: const EdgeInsets.all(8), color: const Color(0xFF1E293B), child: ListTile(
            leading: Image.network(_allMatches[i]['logo'] ?? "", width: 30, errorBuilder: (_,__,___) => const Icon(Icons.sports_soccer)),
            title: Text("${_allMatches[i]['home']} - ${_allMatches[i]['away']}"),
            trailing: Text(_allMatches[i]['time'], style: TextStyle(color: _allMatches[i]['time'] == "ÉLŐ" ? Colors.red : Colors.greenAccent)),
            onTap: () => _analyze(_allMatches[i]),
          )))
        : Column(children: [
            Card(margin: const EdgeInsets.all(16), child: Padding(padding: const EdgeInsets.all(16), child: Text("Találati arány: ${rate.toStringAsFixed(1)}%"))),
            Expanded(child: ListView.builder(itemCount: _savedTips.length, itemBuilder: (_, i) => ListTile(
              title: Text(_savedTips[i]['match']),
              subtitle: Text(_savedTips[i]['pick']),
              trailing: IconButton(icon: Icon(Icons.check_circle, color: _savedTips[i]['status'] == 'NYERT' ? Colors.green : Colors.grey), onPressed: () => setState(() => _savedTips[i]['status'] = 'NYERT')),
            )))
          ]),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        items: const [BottomNavigationBarItem(icon: Icon(Icons.sports_soccer), label: "Meccsek"), BottomNavigationBarItem(icon: Icon(Icons.analytics), label: "Profit")],
      ),
    );
  }
}
