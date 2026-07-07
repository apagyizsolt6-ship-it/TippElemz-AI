import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:convert';
import 'dart:io';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Tippelemző Pro',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B0F19),
        cardColor: const Color(0xFF151F32),
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
  List<Map<String, String>> _matches = [];
  final List<Map<String, String>> _savedTips = [];
  bool _isLoading = false;

  Future<void> _loadMatches() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final client = HttpClient();
      // JAVÍTÁS: A live=all végpont lekéri a világon jelenleg zajló összes élő meccset
      final request = await client.getUrl(Uri.parse('https://v3.football.api-sports.io/fixtures?live=all'));
      
      // Kötelező hitelesítési fejlécek a te saját API kulcsoddal
      request.headers.add('x-rapidapi-key', '1c45d28585a3aac87ced5ab96062b57f'); 
      request.headers.add('x-rapidapi-host', 'v3.football.api-sports.io');
      request.headers.add(HttpHeaders.userAgentHeader, 'Mozilla/5.0 (Linux; Android 10)');
      
      final response = await request.close();
      
      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final dynamic jsonData = json.decode(responseBody);
        final List<dynamic> fixtures = jsonData['response'] ?? [];
        
        List<Map<String, String>> loadedMatches = [];

        for (var item in fixtures) {
          final String homeTeam = item['teams']['home']['name'] ?? 'Hazai';
          final String awayTeam = item['teams']['away']['name'] ?? 'Vendég';
          final String leagueName = item['league']['name'] ?? 'Liga';
          final randomConf = "${75 + Random().nextInt(23)}%";
          
          loadedMatches.add({
            "home": homeTeam,
            "away": awayTeam,
            "league": "⚽ $leagueName",
            "time": "Élő Meccs",
            "conf": randomConf
          });
        }

        setState(() {
          _matches = loadedMatches;
        });
      } else {
        _showErrorSnackBar("API Hiba! Kód: ${response.statusCode}");
      }
    } catch (e) {
      _showErrorSnackBar("Hálózati hiba lépett fel.");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  void _analyzeMatch(String home, String away, String conf) {
    final predictions = [
      "1X (Hazai vagy Döntetlen)", 
      "X2 (Vendég vagy Döntetlen)", 
      "2.5 gól felett", 
      "Mindkét csapat lő gólt: IGEN",
      "Hazai csapat nyer",
      "Kevesebb mint 3.5 gól"
    ];
    final randomPick = predictions[Random().nextInt(predictions.length)];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF151F32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("🤖 AI Tippelemzés", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        content: Text("Meccs: $home - $away\n\n🔮 Ajánlott tipp: $randomPick\n🎯 Biztonság: $conf", style: const TextStyle(color: Colors.white70, fontSize: 15)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Mégse", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _savedTips.add({"match": "$home - $away", "pick": randomPick, "conf": conf});
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Tipp sikeresen elmentve!")),
              );
            },
            child: const Text("Mentés", style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF151F32),
        title: const Text("🔮 AI TIPPELEMZŐ PRO", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
        centerTitle: true,
        elevation: 0,
      ),
      body: _selectedIndex == 0
          ? Padding(
              padding: const EdgeInsets.all(16.0),
              child: ListView(
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      padding: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isLoading ? null : _loadMatches,
                    child: _isLoading 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("Valódi Meccsek Lekérése", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                  const SizedBox(height: 15),
                  if (_matches.isEmpty && !_isLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 40.0),
                      child: Center(child: Text("Nyomj a fenti gombra az élő meccsekért!", style: TextStyle(color: Colors.white38))),
                    ),
                  ..._matches.map((m) => Card(
                        color: const Color(0xFF1E293B),
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          onTap: () => _analyzeMatch(m['home']!, m['away']!, m['conf']!),
                          title: Text("${m['home']} VS ${m['away']}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                          subtitle: Text("${m['league']} • ${m['time']}", style: const TextStyle(color: Colors.white60, fontSize: 12)),
                          trailing: Text(m['conf']!, style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      )),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: _savedTips.isEmpty
                  ? const Center(child: Text("Nincs még elmentett tipped.", style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: _savedTips.length,
                      itemBuilder: (context, index) {
                        final item = _savedTips[index];
                        return Card(
                          color: const Color(0xFF1E293B),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: buildTipListItem(item),
                        );
                      },
                    ),
            ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF151F32),
        selectedItemColor: const Color(0xFF10B981),
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.sports_soccer), label: "Elemző"),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: "Tippek"),
        ],
      ),
    );
  }

  Widget buildTipListItem(Map<String, String> item) {
    return ListTile(
      title: Text(item['match']!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      subtitle: Text("🔮 Tipp: ${item['pick']}", style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w600)),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withOpacity(0.2),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(item['conf']!, style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
      ),
    );
  }
}
