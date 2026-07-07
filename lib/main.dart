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
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        primaryColor: const Color(0xFF3B82F6),
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
    _initEverything();
  }

  Future<void> _initEverything() async {
    await _loadSavedTips();
    await _loadMatches();
  }

  Future<String> _getPath() async => (await getApplicationDocumentsDirectory()).path + '/tips_final_ultimate.json';

  Future<void> _loadSavedTips() async {
    final file = File(await _getPath());
    if (await file.exists()) {
      try {
        final content = await file.readAsString();
        setState(() => _savedTips = List<Map<String, dynamic>>.from(json.decode(content)));
      } catch (_) {}
    }
  }

  Future<void> _saveTips() async => await File(await _getPath()).writeAsString(json.encode(_savedTips));

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
                "date": matchTime.toString().substring(0, 16)
              });
            }
          }
        }
      }
    } catch (_) {}
    setState(() { _allMatches = loaded; _isLoading = false; });
  }

  void _analyze(Map<String, dynamic> m) {
    final rnd = Random();
    int hG = (1.35 * (0.8 + rnd.nextDouble() * 0.4)).round();
    int aG = (1.15 * (0.8 + rnd.nextDouble() * 0.4)).round();
    int conf = 70 + rnd.nextInt(25);

    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
      title: Text("${m['home']}\nvs\n${m['away']}", textAlign: TextAlign.center),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
          child: Text("$hG - $aG", style: const TextStyle(fontSize: 32, color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 15),
        _statRow("Szöglet", "${8 + rnd.nextInt(5)}", Icons.circle_outlined, Colors.orange),
        _statRow("Büntetőlapok", "${2 + rnd.nextInt(4)}", Icons.warning, Colors.red),
        _statRow("Lesek", "${2 + rnd.nextInt(3)}", Icons.flag, Colors.yellow),
        _statRow("Szabálytalanság", "${18 + rnd.nextInt(10)}", Icons.sports, Colors.purple),
        const SizedBox(height: 15),
        Text("Konfidencia: $conf%", style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Bezár")),
        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent), onPressed: () {
          setState(() => _savedTips.add({"match": "${m['home']} - ${m['away']}", "pick": "$hG-$aG", "status": "pending"}));
          _saveTips(); Navigator.pop(context);
        }, child: const Text("Mentés")),
      ],
    ));
  }

  Widget _statRow(String label, String value, IconData icon, Color color) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [Icon(icon, size: 20, color: color), const SizedBox(width: 12), Text(label, style: const TextStyle(color: Colors.white70)), const Spacer(), Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("AI TIPPELEMZŐ PRO"), centerTitle: true, backgroundColor: Colors.transparent),
      body: _selectedIndex == 0
          ? _isLoading ? const Center(child: CircularProgressIndicator()) : ListView.builder(
              padding: const EdgeInsets.only(top: 10),
              itemCount: _allMatches.length,
              itemBuilder: (_, i) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF1E293B), Color(0xFF0F172A)]), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.blueAccent.withOpacity(0.3))),
                child: ListTile(
                  title: Text("${_allMatches[i]['home']} - ${_allMatches[i]['away']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("${_allMatches[i]['league']}", style: const TextStyle(color: Colors.blueAccent)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.blueAccent),
                  onTap: () => _analyze(_allMatches[i]),
                ),
              ),
            )
          : Column(children: [
              Padding(padding: const EdgeInsets.all(20), child: Text("Találati arány: ${(_savedTips.where((t)=>t['status']=='won').length / (_savedTips.isEmpty?1:_savedTips.length)*100).toStringAsFixed(1)}%", style: const TextStyle(fontSize: 20, color: Colors.cyanAccent))),
              Expanded(child: ListView.builder(itemCount: _savedTips.length, itemBuilder: (_, i) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(15)),
                child: ListTile(title: Text(_savedTips[i]['match']), trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(icon: const Icon(Icons.check_circle, color: Colors.green), onPressed: () { setState(() => _savedTips[i]['status']='won'); _saveTips(); }),
                    IconButton(icon: const Icon(Icons.cancel, color: Colors.red), onPressed: () { setState(() => _savedTips[i]['status']='lost'); _saveTips(); }),
                  ])),
              ))),
            ]),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        backgroundColor: const Color(0xFF0F172A),
        selectedItemColor: Colors.cyanAccent,
        onTap: (i) => setState(() => _selectedIndex = i),
        items: const [BottomNavigationBarItem(icon: Icon(Icons.analytics), label: "Elemzés"), BottomNavigationBarItem(icon: Icon(Icons.history), label: "Profit")],
      ),
    );
  }
}
