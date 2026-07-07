import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Tippelemző Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF080C14),
        cardColor: const Color(0xFF111827),
        fontFamily: 'Roboto',
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
  List<Map<String, dynamic>> _filteredMatches = []; 
  List<Map<String, dynamic>> _savedTips = []; // Frissítve dinamikus típusra
  bool _isLoading = false;
  
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSavedTipsFromFile();
    
    _searchController.addListener(() {
      _filterMatches(_searchController.text);
    });
  }

  // --- STATISZTIKA SZÁMÍTÁSA ---
  double get _winRate {
    if (_savedTips.isEmpty) return 0.0;
    final wins = _savedTips.where((t) => t['status'] == 'won').length;
    final totalRated = _savedTips.where((t) => t['status'] != 'pending').length;
    if (totalRated == 0) return 0.0;
    return (wins / totalRated) * 100;
  }

  // --- ADATKEZELÉS ---
  Future<String> _getFilePath() async {
    final directory = await getApplicationDocumentsDirectory(); 
    return '${directory.path}/saved_tips_v2.json';
  }

  Future<void> _loadSavedTipsFromFile() async {
    try {
      final path = await _getFilePath();
      final file = File(path);
      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> decoded = json.decode(content);
        setState(() {
          _savedTips = List<Map<String, dynamic>>.from(decoded);
        });
      }
    } catch (_) {}
  }

  Future<void> _saveTipsToFile() async {
    try {
      final path = await _getFilePath();
      final file = File(path);
      await file.writeAsString(json.encode(_savedTips));
    } catch (_) {}
  }

  void _filterMatches(String query) {
    if (query.isEmpty) {
      setState(() => _filteredMatches = _allMatches);
    } else {
      setState(() {
        _filteredMatches = _allMatches.where((m) {
          final homeTeam = m['home'].toString().toLowerCase();
          final awayTeam = m['away'].toString().toLowerCase();
          final league = m['league'].toString().toLowerCase();
          return homeTeam.contains(query.toLowerCase()) || 
                 awayTeam.contains(query.toLowerCase()) || 
                 league.contains(query.toLowerCase());
        }).toList();
      });
    }
  }

  Future<void> _loadMatches() async {
    setState(() => _isLoading = true);
    try {
      final client = HttpClient();
      final now = DateTime.now();
      final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      final request = await client.getUrl(Uri.parse('https://v3.football.api-sports.io/fixtures?date=$todayStr'));
      
      request.headers.add('x-rapidapi-key', '1c45d28585a3aac87ced5ab96062b57f'); 
      request.headers.add('x-rapidapi-host', 'v3.football.api-sports.io');
      
      final response = await request.close();
      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final dynamic jsonData = json.decode(responseBody);
        final List<dynamic> fixtures = jsonData['response'] ?? [];
        
        List<Map<String, dynamic>> loadedMatches = [];
        for (var item in fixtures) {
          loadedMatches.add({
            "home": item['teams']['home']['name'],
            "away": item['teams']['away']['name'],
            "homeLogo": item['teams']['home']['logo'] ?? '',
            "awayLogo": item['teams']['away']['logo'] ?? '',
            "league": item['league']['name'],
            "time": item['fixture']['date'].toString().substring(11, 16),
            "score": (item['goals']['home'] != null) ? "${item['goals']['home']}-${item['goals']['away']}" : "vs",
            "status": item['fixture']['status']['short'],
          });
        }
        setState(() {
          _allMatches = loadedMatches;
          _filterMatches(_searchController.text);
        });
      }
    } catch (e) {
      debugPrint("Hiba: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // --- OKOSABB PREDIKCIÓS MOTOR ---
  void _analyzeMatch(Map<String, dynamic> match) {
    final String home = match['home'];
    final String away = match['away'];
    final String league = match['league'].toString().toLowerCase();

    final rnd = Random(home.length + away.length);
    
    // Liga súlyozás
    double goalMultiplier = 1.2;
    if (league.contains("premier") || league.contains("bundesliga")) goalMultiplier = 1.5;
    if (league.contains("serie a") || league.contains("laliga")) goalMultiplier = 1.1;

    // "Forma" szimuláció (Intelligensebb faktor)
    double homeForm = 0.8 + (rnd.nextDouble() * 0.7);
    double awayForm = 0.7 + (rnd.nextDouble() * 0.6);

    double hExp = ((home.length % 5) * 0.5 + 0.5) * goalMultiplier * homeForm;
    double aExp = ((away.length % 4) * 0.4 + 0.3) * goalMultiplier * awayForm;

    int hG = _poisson(hExp, rnd);
    int aG = _poisson(aExp, rnd);

    int corners = 7 + rnd.nextInt(6);
    int cards = 2 + rnd.nextInt(5);
    int conf = 70 + rnd.nextInt(28);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: Colors.white10)),
        title: Text("$home - $away", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _statBar("🎯 Várható gólok", "$hG - $aG", Colors.amberAccent, 0.8),
            _statBar("📐 Szögletek", "$corners.5 felett", Colors.blueAccent, corners / 15),
            _statBar("🟨 Lapok", "$cards.5 felett", Colors.orangeAccent, cards / 8),
            const Divider(height: 30, color: Colors.white10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("AI Megbízhatóság:"),
                Text("$conf%", style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Bezár", style: TextStyle(color: Colors.white38))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            onPressed: () {
              setState(() {
                _savedTips.add({
                  "match": "$home - $away",
                  "pick": "$hG-$aG | $corners szöglet",
                  "conf": "$conf%",
                  "status": "pending", // Állapot: Függőben
                  "date": DateTime.now().toString()
                });
              });
              _saveTipsToFile();
              Navigator.pop(context);
            },
            child: const Text("Tipp Mentése", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  int _poisson(double lambda, Random rnd) {
    double p = 1.0, L = exp(-lambda);
    int k = 0;
    do { k++; p *= rnd.nextDouble(); } while (p > L && k < 10);
    return k - 1;
  }

  Widget _statBar(String label, String val, Color col, double prog) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.white60)),
            Text(val, style: TextStyle(color: col, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 4),
          LinearProgressIndicator(value: prog, backgroundColor: Colors.white10, color: col, minHeight: 3),
        ],
      ),
    );
  }

  // --- UI KOMPONENSEK ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text("🔮 AI TIPPELEMZŐ PRO", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        centerTitle: true,
        elevation: 0,
      ),
      body: _selectedIndex == 0 ? _buildMatchList() : _buildStatsPage(),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF0F172A),
        selectedItemColor: const Color(0xFF10B981),
        unselectedItemColor: Colors.white38,
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.analytics), label: "Elemzés"),
          BottomNavigationBarItem(icon: Icon(Icons.show_chart), label: "Saját Profit"),
        ],
      ),
    );
  }

  Widget _buildMatchList() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), minimumSize: const Size.fromHeight(48)),
            onPressed: _isLoading ? null : _loadMatches,
            icon: const Icon(Icons.refresh, color: Colors.black),
            label: Text(_isLoading ? "Betöltés..." : "KÍNÁLAT FRISSÍTÉSE", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: "Keresés...",
              prefixIcon: const Icon(Icons.search, color: Colors.white38),
              filled: true, fillColor: const Color(0xFF1E293B),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _filteredMatches.isEmpty ? const Center(child: Text("Nincs meccs.")) : ListView.builder(
              itemCount: _filteredMatches.length,
              itemBuilder: (context, index) {
                final m = _filteredMatches[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    onTap: () => _analyzeMatch(m),
                    leading: m['homeLogo'] != '' ? Image.network(m['homeLogo'], width: 30) : const Icon(Icons.sports_soccer),
                    title: Text("${m['home']} - ${m['away']}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    subtitle: Text(m['league'], style: const TextStyle(fontSize: 11, color: Colors.white38)),
                    trailing: Text(m['score'], style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsPage() {
    return Column(
      children: [
        // --- STATISZTIKAI DASHBOARD ---
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF1E293B), Color(0xFF0F172A)]),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
          ),
          child: Column(
            children: [
              const Text("MODELL PONTOSSÁGA", style: TextStyle(letterSpacing: 1.5, fontSize: 12, color: Colors.white54)),
              const SizedBox(height: 10),
              Text("${_winRate.toStringAsFixed(1)}%", style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(value: _winRate / 100, minHeight: 8, color: const Color(0xFF10B981), backgroundColor: Colors.white10),
              ),
              const SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _miniStat("Összes", _savedTips.length.toString()),
                  _miniStat("Nyert", _savedTips.where((t) => t['status'] == 'won').length.toString()),
                  _miniStat("Vesztett", _savedTips.where((t) => t['status'] == 'lost').length.toString()),
                ],
              )
            ],
          ),
        ),
        // --- MENTETT TIPPEK LISTÁJA ---
        Expanded(
          child: _savedTips.isEmpty ? const Center(child: Text("Nincs mentett tipped.")) : ListView.builder(
            itemCount: _savedTips.length,
            itemBuilder: (context, index) {
              final item = _savedTips.reversed.toList()[index]; // Legfrissebb felül
              final realIndex = _savedTips.length - 1 - index;
              
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item['match'], style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text(item['pick'], style: const TextStyle(color: Color(0xFF10B981), fontSize: 13)),
                        ],
                      ),
                    ),
                    // NYERT GOMB
                    IconButton(
                      icon: Icon(Icons.check_circle, color: item['status'] == 'won' ? Colors.green : Colors.white10),
                      onPressed: () {
                        setState(() => _savedTips[realIndex]['status'] = 'won');
                        _saveTipsToFile();
                      },
                    ),
                    // VESZTETT GOMB
                    IconButton(
                      icon: Icon(Icons.cancel, color: item['status'] == 'lost' ? Colors.red : Colors.white10),
                      onPressed: () {
                        setState(() => _savedTips[realIndex]['status'] = 'lost');
                        _saveTipsToFile();
                      },
                    ),
                    // TÖRLÉS
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.white38, size: 20),
                      onPressed: () {
                        setState(() => _savedTips.removeAt(realIndex));
                        _saveTipsToFile();
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _miniStat(String label, String val) {
    return Column(
      children: [
        Text(val, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.white38)),
      ],
    );
  }
}
