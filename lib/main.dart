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
  
  // Szűrő változók
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
    return '${dir.path}/tips_pro_v19_filter.json';
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
    
    for (int i = 0; i < 4; i++) {
      String dateStr = DateTime.now().add(Duration(days: i)).toString().substring(0, 10);
      try {
        var req = await client.getUrl(Uri.parse('https://v3.football.api-sports.io/fixtures?date=$dateStr'));
        req.headers.add('x-rapidapi-key', '1c45d28585a3aac87ced5ab96062b57f');
        var res = await req.close();
        if (res.statusCode == 200) {
          var data = json.decode(await res.transform(utf8.decoder).join())['response'];
          for (var m in data) {
            String league = m['league']['name'].toString().toLowerCase();
            // Dinamikus szűrés
            if (_hideFriendlies && (league.contains("friendly") || league.contains("friendlies"))) continue;
            
            loaded.add({
              "home": m['teams']['home']['name'],
              "away": m['teams']['away']['name'],
              "league": m['league']['name'],
              "logo": m['league']['logo'],
              "time": (m['fixture']['status']['short'] == '1H' || m['fixture']['status']['short'] == '2H') ? "LIVE" : DateTime.fromMillisecondsSinceEpoch(m['fixture']['timestamp'] * 1000).toString().substring(11, 16)
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
    String cornerOU = (rnd.nextDouble() > 0.4) ? "Over 9.5" : "Under 9.5";
    String cardOU = (rnd.nextDouble() > 0.5) ? "Over 3.5" : "Under 3.5";
    String offsideOU = (rnd.nextDouble() > 0.6) ? "Over 2.5" : "Under 2.5";
    String foulOU = (rnd.nextDouble() > 0.45) ? "Over 24.5" : "Under 24.5";
    int hG = rnd.nextInt(3), aG = rnd.nextInt(3);
    
    String tipText = "Eredmény: $hG-$aG | Szöglet: $cornerOU | Lap: $cardOU | Les: $offsideOU | Fault: $foulOU";
    
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      title: Text("${m['home']} vs ${m['away']}", textAlign: TextAlign.center),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        _statRow("Várható eredmény", "$hG - $aG", Icons.analytics, Colors.amberAccent),
        _statRow("Szöglet (O/U)", cornerOU, Icons.radio_button_checked, Colors.greenAccent),
        _statRow("Lapok (O/U)", cardOU, Icons.warning_amber_rounded, Colors.orangeAccent),
        _statRow("Lesek (O/U)", offsideOU, Icons.flag_outlined, Colors.purpleAccent),
        _statRow("Faultok (O/U)", foulOU, Icons.sports_soccer, Colors.redAccent),
      ]),
      actions: [
        IconButton(icon: const Icon(Icons.copy), onPressed: () => Clipboard.setData(ClipboardData(text: tipText))),
        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent, foregroundColor: Colors.black), onPressed: () {
          setState(() => _savedTips.add({"match": "${m['home']} - ${m['away']}", "pick": tipText, "status": "függőben"}));
          _saveTips(); Navigator.pop(context);
        }, child: const Text("Tipp mentése")),
      ],
    ));
  }

  Widget _statRow(String label, String value, IconData icon, Color color) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(children: [Icon(icon, size: 22, color: color), const SizedBox(width: 15), Text(label), const Spacer(), Text(value, style: const TextStyle(fontWeight: FontWeight.bold))]),
  );

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
          ? Container(
              margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
              decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(20)),
              child: ListTile(
                leading: CircleAvatar(backgroundColor: Colors.white10, child: Image.network(_allMatches[i]['logo'] ?? "", width: 25, errorBuilder: (_,__,___) => const Icon(Icons.sports))),
                title: Text("${_allMatches[i]['home']} - ${_allMatches[i]['away']}"),
                subtitle: Text(_allMatches[i]['league'], style: const TextStyle(color: Colors.amberAccent)),
                trailing: Text(_allMatches[i]['time'], style: const TextStyle(fontWeight: FontWeight.bold)),
                onTap: () => _analyze(_allMatches[i]),
              ),
            )
          : ListTile(title: Text(_savedTips[i]['match']), subtitle: Text(_savedTips[i]['pick'])),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF0F172A), selectedItemColor: Colors.amberAccent, currentIndex: _selectedIndex, onTap: (i) => setState(() => _selectedIndex = i),
        items: const [BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: "Meccsek"), BottomNavigationBarItem(icon: Icon(Icons.history), label: "Profit")],
      ),
    );
  }
}
