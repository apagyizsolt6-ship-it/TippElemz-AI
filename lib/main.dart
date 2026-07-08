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
        colorScheme: const ColorScheme.dark(primary: Colors.amberAccent),
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
    return '${dir.path}/tips_pro_full.json';
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
              "logo": m['league']['logo'],
              "time": DateTime.fromMillisecondsSinceEpoch(m['fixture']['timestamp'] * 1000).toString().substring(11, 16)
            });
          }
        }
      } catch (_) {}
    }
    setState(() { _allMatches = loaded; _isLoading = false; });
  }

  void _showFilterDialog() {
    showDialog(context: context, builder: (_) => StatefulBuilder(builder: (context, setStateInDialog) => AlertDialog(
      title: const Text("Szűrési beállítások"),
      content: SwitchListTile(
        title: const Text("Barátságos meccsek elrejtése"),
        value: _hideFriendlies,
        onChanged: (val) {
          setStateInDialog(() => _hideFriendlies = val);
          setState(() => _hideFriendlies = val);
          _loadMatches();
        },
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))],
    )));
  }

  void _analyze(Map<String, dynamic> m) {
    final rnd = Random();
    String tipText = "Eredmény: ${rnd.nextInt(3)}-${rnd.nextInt(3)} | Szöglet: O/U 9.5 | Lap: ${rnd.nextInt(5)} db | Fault: ${20 + rnd.nextInt(10)} db";
    
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text("${m['home']} vs ${m['away']}", textAlign: TextAlign.center),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(tipText, textAlign: TextAlign.center),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Bezár")),
        ElevatedButton(onPressed: () {
          setState(() => _savedTips.add({"match": "${m['home']} - ${m['away']}", "pick": tipText}));
          _saveTips(); Navigator.pop(context);
        }, child: const Text("Mentés")),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("AI PRO ANALYZER"),
        actions: [IconButton(icon: const Icon(Icons.filter_list), onPressed: _showFilterDialog)],
      ),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : ListView.builder(
        itemCount: _selectedIndex == 0 ? _allMatches.length : _savedTips.length,
        itemBuilder: (_, i) => _selectedIndex == 0 
          ? ListTile(
              leading: Image.network(_allMatches[i]['logo'] ?? "", width: 30, errorBuilder: (_,__,___) => const Icon(Icons.sports)),
              title: Text("${_allMatches[i]['home']} - ${_allMatches[i]['away']}"),
              subtitle: Text(_allMatches[i]['league']),
              trailing: Text(_allMatches[i]['time']),
              onTap: () => _analyze(_allMatches[i]),
            )
          : ListTile(title: Text(_savedTips[i]['match']), subtitle: Text(_savedTips[i]['pick'])),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.sports_soccer), label: "Meccsek"),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: "Profit"),
        ],
      ),
    );
  }
}
