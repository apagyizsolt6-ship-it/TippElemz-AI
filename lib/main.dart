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
        primaryColor: Colors.amberAccent,
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
  bool _isLiveOnly = false;
  String _searchQuery = "";

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
    return '${dir.path}/pro_analyzer_v32.json';
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

  void _analyze(Map<String, dynamic> m) {
    showDialog(context: context, builder: (_) => Dialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text("${m['home']} vs ${m['away']}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.amberAccent)),
          const SizedBox(height: 15),
          _buildStatRow(Icons.analytics, "Várható eredmény", "2-1", "78% Conf", Colors.cyanAccent),
          _buildStatRow(Icons.radio_button_checked, "Szöglet (O/U)", "Over 9.5", "85% Conf", Colors.greenAccent, isBest: true),
          _buildStatRow(Icons.warning_amber, "Szabálytalanság (O/U)", "Over 24.5", "68% Conf", Colors.orangeAccent),
          _buildStatRow(Icons.track_changes, "Kapuralövés (O/U)", "Over 8.5", "72% Conf", Colors.redAccent),
          _buildStatRow(Icons.receipt_long, "Lapok (O/U)", "Over 3.5", "65% Conf", Colors.yellowAccent),
          _buildStatRow(Icons.flag_outlined, "Lesek (O/U)", "Over 2.5", "60% Conf", Colors.purpleAccent),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              setState(() => _savedTips.add({"match": "${m['home']} - ${m['away']}", "pick": "Best: Szöglet Over 9.5"}));
              _saveTips(); Navigator.pop(context);
            }, 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent, foregroundColor: Colors.black), 
            child: const Text("Tipp mentése")
          ),
        ]),
      ),
    ));
  }

  Widget _buildStatRow(IconData icon, String title, String value, String conf, Color color, {bool isBest = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(children: [
      Icon(icon, color: isBest ? Colors.amberAccent : color, size: 22),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        Text(conf, style: TextStyle(fontSize: 10, color: Colors.grey[400])),
      ]),
      const Spacer(),
      Text(value, style: const TextStyle(fontWeight: FontWeight.bold))
    ]),
  );

  Future<void> _loadMatches() async {
    setState(() => _isLoading = true);
    try {
      // Itt az API hívásod maradjon, ez csak egy példa a felépítésre:
      await Future.delayed(const Duration(seconds: 1)); // API szimuláció
      setState(() {
        _allMatches = [
          {"home": "Flora Tallinn", "away": "Saburtalo", "status": "NS", "logo": "https://media.api-sports.io/football/leagues/1.png"},
        ];
      });
    } catch (e) {
      print("Hiba: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredMatches = _allMatches.where((m) => 
      (m['home']?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? true) &&
      (!_isLiveOnly || m['status'] == 'Live')
    ).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("AI PRO ANALYZER", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        bottom: PreferredSize(preferredSize: const Size.fromHeight(60), child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Expanded(child: TextField(decoration: const InputDecoration(hintText: "Csapat keresése...", prefixIcon: Icon(Icons.search)), onChanged: (v) => setState(() => _searchQuery = v))),
            Switch(value: _isLiveOnly, onChanged: (v) => setState(() => _isLiveOnly = v)),
            const Text("Élő")
          ]),
        )),
      ),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : ListView.builder(
        itemCount: _selectedIndex == 0 ? filteredMatches.length : _savedTips.length,
        itemBuilder: (_, i) => _selectedIndex == 0 ? Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading: Image.network(filteredMatches[i]['logo'] ?? "", width: 40, errorBuilder: (_,__,___) => const Icon(Icons.sports_soccer)),
            title: Text("${filteredMatches[i]['home']} - ${filteredMatches[i]['away']}"),
            onTap: () => _analyze(filteredMatches[i]),
          ),
        ) : Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            title: Text(_savedTips[i]['match']),
            subtitle: Text(_savedTips[i]['pick'], style: const TextStyle(color: Colors.amberAccent)),
            trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: () => setState(() => _savedTips.removeAt(i))),
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.amberAccent,
        onTap: (i) => setState(() => _selectedIndex = i),
        items: const [BottomNavigationBarItem(icon: Icon(Icons.sports_soccer), label: "Meccsek"), BottomNavigationBarItem(icon: Icon(Icons.history), label: "Profit")],
      ),
    );
  }
}
