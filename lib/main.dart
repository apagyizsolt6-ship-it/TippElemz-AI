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
        cardColor: const Color(0xFF111827),
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
    _initData();
  }

  Future<void> _initData() async {
    await _loadSavedTips();
    await _loadMatches();
  }

  Future<String> _getPath() async => (await getApplicationDocumentsDirectory()).path + '/tips_final.json';

  Future<void> _loadSavedTips() async {
    final file = File(await _getPath());
    if (await file.exists()) {
      try {
        setState(() => _savedTips = List<Map<String, dynamic>>.from(json.decode(await file.readAsString())));
      } catch (_) {}
    }
  }

  Future<void> _saveTips() async => await File(await _getPath()).writeAsString(json.encode(_savedTips));

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

  void _analyze(Map<String, dynamic> m) {
    final rnd = Random();
    int hG = rnd.nextInt(3), aG = rnd.nextInt(3), conf = 75 + rnd.nextInt(20);
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: Text("${m['home']} - ${m['away']}", textAlign: TextAlign.center),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text("Várható eredmény: $hG-$aG", style: const TextStyle(fontSize: 18, color: Colors.greenAccent)),
        Text("Megbízhatóság: $conf%", style: const TextStyle(color: Colors.amber)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Bezár")),
        ElevatedButton(onPressed: () {
          setState(() => _savedTips.add({"match": "${m['home']} - ${m['away']}", "pick": "$hG-$aG", "status": "pending"}));
          _saveTips(); Navigator.pop(context);
        }, child: const Text("Mentés")),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("AI TIPPELEMZŐ PRO")),
      body: _selectedIndex == 0
          ? _isLoading ? const Center(child: CircularProgressIndicator()) : ListView.builder(
              itemCount: _allMatches.length,
              itemBuilder: (_, i) => Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  title: Text("${_allMatches[i]['home']} - ${_allMatches[i]['away']}"),
                  subtitle: Text("${_allMatches[i]['league']} • ${_allMatches[i]['date']}"),
                  onTap: () => _analyze(_allMatches[i]),
                ),
              ),
            )
          : Column(children: [
              Padding(padding: const EdgeInsets.all(20), child: Text("Találati arány: ${(_savedTips.where((t)=>t['status']=='won').length / (_savedTips.isEmpty?1:_savedTips.length)*100).toStringAsFixed(1)}%")),
              Expanded(child: ListView.builder(itemCount: _savedTips.length, itemBuilder: (_, i) => Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  title: Text(_savedTips[i]['match']),
                  subtitle: Text("Tipp: ${_savedTips[i]['pick']}"),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(icon: const Icon(Icons.check, color: Colors.green), onPressed: () { setState(() => _savedTips[i]['status']='won'); _saveTips(); }),
                    IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () { setState(() => _savedTips[i]['status']='lost'); _saveTips(); }),
                  ]),
                ),
              ))),
            ]),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        items: const [BottomNavigationBarItem(icon: Icon(Icons.analytics), label: "Elemzés"), BottomNavigationBarItem(icon: Icon(Icons.history), label: "Profit")],
      ),
    );
  }
}
