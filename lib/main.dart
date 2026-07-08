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
    return '${dir.path}/tips_pro_ultimate.json';
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
            if (league.contains("friendly")) continue;
            loaded.add({
              "home": m['teams']['home']['name'],
              "away": m['teams']['away']['name'],
              "league": m['league']['name'],
              "logo": m['league']['logo'],
              "time": m['fixture']['status']['short'] == '1H' || m['fixture']['status']['short'] == '2H' ? "ÉLŐ" : DateTime.fromMillisecondsSinceEpoch(m['fixture']['timestamp'] * 1000).toString().substring(11, 16)
            });
          }
        }
      } catch (_) {}
    }
    setState(() { _allMatches = loaded; _filteredMatches = loaded; _isLoading = false; });
  }

  void _analyze(Map<String, dynamic> m) {
    double confidence = 70.0 + Random().nextDouble() * 25.0;
    String tipText = "Eredmény: ${Random().nextInt(3)}-${Random().nextInt(3)} | Bizalom: ${confidence.toStringAsFixed(0)}%";
    
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: Text("${m['home']} vs ${m['away']}"),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        LinearProgressIndicator(value: confidence / 100, color: Colors.cyanAccent),
        const SizedBox(height: 15),
        Text(tipText),
      ]),
      actions: [
        IconButton(icon: const Icon(Icons.copy), onPressed: () => Clipboard.setData(ClipboardData(text: tipText))),
        ElevatedButton(onPressed: () {
          setState(() => _savedTips.add({"match": "${m['home']} - ${m['away']}", "pick": tipText, "status": "függőben"}));
          _saveTips(); Navigator.pop(context);
        }, child: const Text("Mentés")),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    int won = _savedTips.where((t) => t['status'] == 'NYERT').length;
    double rate = _savedTips.isEmpty ? 0 : (won / _savedTips.length) * 100;

    return Scaffold(
      appBar: AppBar(title: const Text("AI TIPPELEMZŐ PRO")),
      body: _selectedIndex == 0 
        ? ListView.builder(itemCount: _filteredMatches.length, itemBuilder: (_, i) => Card(margin: const EdgeInsets.all(8), color: const Color(0xFF1E293B), child: ListTile(
            leading: Image.network(_filteredMatches[i]['logo'] ?? "", width: 30, errorBuilder: (_,__,___) => const Icon(Icons.sports_soccer)),
            title: Text("${_filteredMatches[i]['home']} - ${_filteredMatches[i]['away']}"),
            trailing: Text(_filteredMatches[i]['time'], style: TextStyle(color: _filteredMatches[i]['time'] == "ÉLŐ" ? Colors.red : Colors.greenAccent)),
            onTap: () => _analyze(_filteredMatches[i]),
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
