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
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        primaryColor: Colors.deepPurpleAccent,
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
    return '${dir.path}/tips_final_v17_colorful.json';
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
            // Szigorúbb szűrés: nem csak "friendly", hanem "club friendlies" és hasonlók is
            if (league.contains("friendly") || league.contains("friendlies")) continue;
            
            loaded.add({
              "home": m['teams']['home']['name'],
              "away": m['teams']['away']['name'],
              "league": m['league']['name'],
              "logo": m['league']['logo'],
              "time": (m['fixture']['status']['short'] == '1H' || m['fixture']['status']['short'] == '2H') ? "ÉLŐ" : DateTime.fromMillisecondsSinceEpoch(m['fixture']['timestamp'] * 1000).toString().substring(11, 16)
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
    
    String cornerOU = (rnd.nextDouble() > 0.5) ? "Over 9.5" : "Under 9.5";
    String cardOU = (rnd.nextDouble() > 0.5) ? "Over 3.5" : "Under 3.5";
    String offsideOU = (rnd.nextDouble() > 0.5) ? "Over 2.5" : "Under 2.5";
    int hG = rnd.nextInt(3), aG = rnd.nextInt(3);
    
    String tipText = "Eredmény: $hG-$aG | Szöglet: $cornerOU | Lapok: $cardOU | Les: $offsideOU";
    
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
      title: Text("${m['home']} vs ${m['away']}", textAlign: TextAlign.center),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        LinearProgressIndicator(value: conf / 100, color: Colors.amberAccent, backgroundColor: Colors.white10),
        const SizedBox(height: 20),
        _statRow("Várható eredmény", "$hG - $aG", Icons.score, Colors.deepPurpleAccent),
        _statRow("Szöglet (O/U)", cornerOU, Icons.circle_outlined, Colors.amber),
        _statRow("Lapok (O/U)", cardOU, Icons.warning, Colors.redAccent),
        _statRow("Lesek (O/U)", offsideOU, Icons.flag, Colors.tealAccent),
      ]),
      actions: [
        IconButton(icon: const Icon(Icons.copy, color: Colors.white54), onPressed: () => Clipboard.setData(ClipboardData(text: tipText))),
        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurpleAccent), onPressed: () {
          setState(() => _savedTips.add({"match": "${m['home']} - ${m['away']}", "pick": tipText, "status": "függőben"}));
          _saveTips(); Navigator.pop(context);
        }, child: const Text("Tipp mentése")),
      ],
    ));
  }

  Widget _statRow(String label, String value, IconData icon, Color color) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 18, color: color)), 
      const SizedBox(width: 12), Text(label), const Spacer(), Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white70))
    ]),
  );

  @override
  Widget build(BuildContext context) {
    int won = _savedTips.where((t) => t['status'] == 'NYERT').length;
    double rate = _savedTips.isEmpty ? 0 : (won / _savedTips.length) * 100;

    return Scaffold(
      appBar: AppBar(title: const Text("AI TIPPELEMZŐ PRO"), backgroundColor: Colors.transparent, elevation: 0),
      body: _selectedIndex == 0 
        ? ListView.builder(itemCount: _allMatches.length, itemBuilder: (_, i) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF2D1B4E), Color(0xFF1E293B)]), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white12)),
            child: ListTile(
              leading: Image.network(_allMatches[i]['logo'] ?? "", width: 40, height: 40, errorBuilder: (_,__,___) => const Icon(Icons.sports_soccer, color: Colors.amber)),
              title: Text(_allMatches[i]['league'], style: const TextStyle(fontSize: 11, color: Colors.amberAccent, fontWeight: FontWeight.bold)),
              subtitle: Text("${_allMatches[i]['home']} vs ${_allMatches[i]['away']}", style: const TextStyle(fontSize: 15, color: Colors.white)),
              trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: _allMatches[i]['time'] == "ÉLŐ" ? Colors.red : Colors.teal.withOpacity(0.2), borderRadius: BorderRadius.circular(10)), child: Text(_allMatches[i]['time'], style: const TextStyle(fontWeight: FontWeight.bold))),
              onTap: () => _analyze(_allMatches[i]),
            ),
          ))
        : Column(children: [
            Container(margin: const EdgeInsets.all(20), padding: const EdgeInsets.all(20), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Colors.deepPurple, Colors.indigo]), borderRadius: BorderRadius.circular(20)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Találati arány:", style: TextStyle(fontSize: 18)), Text("${rate.toStringAsFixed(1)}%", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold))])),
            Expanded(child: ListView.builder(itemCount: _savedTips.length, itemBuilder: (_, i) => ListTile(
              leading: const Icon(Icons.history, color: Colors.amber),
              title: Text(_savedTips[i]['match']), subtitle: Text(_savedTips[i]['pick']),
              trailing: IconButton(icon: Icon(Icons.check_circle, color: _savedTips[i]['status'] == 'NYERT' ? Colors.tealAccent : Colors.white24), onPressed: () => setState(() => _savedTips[i]['status'] = 'NYERT')),
            )))
          ]),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF0F172A), selectedItemColor: Colors.amberAccent, currentIndex: _selectedIndex, onTap: (i) => setState(() => _selectedIndex = i),
        items: const [BottomNavigationBarItem(icon: Icon(Icons.sports_soccer), label: "Meccsek"), BottomNavigationBarItem(icon: Icon(Icons.analytics), label: "Profit")],
      ),
    );
  }
}
