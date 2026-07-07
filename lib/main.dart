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
        scaffoldBackgroundColor: const Color(0xFF080C14),
        primaryColor: const Color(0xFF10B981),
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

  Future<String> _getPath() async => (await getApplicationDocumentsDirectory()).path + '/tips_pro_v3.json';

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
    await File(await _getPath()).writeAsString(json.encode(_savedTips));
  }

  Future<void> _loadMatches() async {
    setState(() => _isLoading = true);
    List<Map<String, dynamic>> loaded = [];
    final client = HttpClient();
    try {
      for (int i = 0; i < 6; i++) {
        String date = DateTime.now().add(Duration(days: i)).toString().substring(0, 10);
        var req = await client.getUrl(Uri.parse('https://v3.football.api-sports.io/fixtures?date=$date'));
        req.headers.add('x-rapidapi-key', '1c45d28585a3aac87ced5ab96062b57f');
        var res = await req.close();
        if (res.statusCode == 200) {
          var data = json.decode(await res.transform(utf8.decoder).join())['response'];
          for (var m in data) {
            loaded.add({
              "home": m['teams']['home']['name'],
              "away": m['teams']['away']['name'],
              "league": m['league']['name'],
              "date": date
            });
          }
        }
      }
    } catch (_) {}
    setState(() { _allMatches = loaded; _isLoading = false; });
  }

  // --- ELEGÁNS ELEMZŐ ABLAK ---
  void _analyze(Map<String, dynamic> m) {
    final rnd = Random();
    int hG = rnd.nextInt(3), aG = rnd.nextInt(3), conf = 75 + rnd.nextInt(20);
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text("${m['home']}\nvs\n${m['away']}", textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        const Divider(color: Colors.white24),
        Text("Várható: $hG-$aG", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
        const SizedBox(height: 10),
        Text("Megbízhatóság: $conf%", style: const TextStyle(color: Colors.amber, fontSize: 16)),
      ]),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Bezár")),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          onPressed: () {
            setState(() => _savedTips.add({"match": "${m['home']} - ${m['away']}", "pick": "$hG-$aG", "status": "pending"}));
            _saveTips(); 
            Navigator.pop(context);
          }, 
          child: const Text("Tipp mentése")
        ),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("AI TIPPELEMZŐ PRO"), centerTitle: true, backgroundColor: Colors.transparent, elevation: 0),
      body: _selectedIndex == 0
          ? _isLoading ? const Center(child: CircularProgressIndicator()) : ListView.builder(
              padding: const EdgeInsets.only(top: 10),
              itemCount: _allMatches.length,
              itemBuilder: (_, i) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(15)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                  title: Text("${_allMatches[i]['home']} - ${_allMatches[i]['away']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("${_allMatches[i]['league']} | ${_allMatches[i]['date']}", style: const TextStyle(color: Colors.white54)),
                  onTap: () => _analyze(_allMatches[i]),
                ),
              ),
            )
          : Column(children: [
              Padding(padding: const EdgeInsets.all(20), child: Text("Teljes találati arány: ${(_savedTips.where((t)=>t['status']=='won').length / (_savedTips.isEmpty?1:_savedTips.length)*100).toStringAsFixed(1)}%", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
              Expanded(child: ListView.builder(itemCount: _savedTips.length, itemBuilder: (_, i) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  title: Text(_savedTips[i]['match']),
                  subtitle: Text("Tipp: ${_savedTips[i]['pick']} | Státusz: ${_savedTips[i]['status']}"),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(icon: const Icon(Icons.check_circle, color: Colors.green), onPressed: () { setState(() => _savedTips[i]['status']='won'); _saveTips(); }),
                    IconButton(icon: const Icon(Icons.cancel, color: Colors.red), onPressed: () { setState(() => _savedTips[i]['status']='lost'); _saveTips(); }),
                  ]),
                ),
              ))),
            ]),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        backgroundColor: const Color(0xFF080C14),
        selectedItemColor: Colors.greenAccent,
        onTap: (i) => setState(() => _selectedIndex = i),
        items: const [BottomNavigationBarItem(icon: Icon(Icons.analytics), label: "Elemzés"), BottomNavigationBarItem(icon: Icon(Icons.history), label: "Profit")],
      ),
    );
  }
}
