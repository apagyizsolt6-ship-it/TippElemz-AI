        
import 'package:flutter/material.dart';
import 'dart:math';

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

  void _loadMatches() {
    setState(() {
      _matches = [
        {"home": "Real Madrid", "away": "Barcelona", "league": "🇪🇸 La Liga", "time": "21:00", "conf": "88%"},
        {"home": "Man. City", "away": "Liverpool", "league": "🇬🇧 Premier League", "time": "18:30", "conf": "74%"},
        {"home": "Bayern München", "away": "Dortmund", "league": "🇩🇪 Bundesliga", "time": "15:30", "conf": "81%"},
        {"home": "Inter", "away": "AC Milan", "league": "🇮🇹 Serie A", "time": "20:45", "conf": "69%"}
      ];
    });
  }

  void _analyzeMatch(String home, String away, String conf) {
    final predictions = ["1X", "X2", "2.5 gól felett", "Mindkét csapat lő gólt"];
    final randomPick = predictions[Random().nextInt(predictions.length)];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF151F32),
        title: const Text("🤖 AI Tippelemzés", style: TextStyle(color: Colors.white)),
        content: Text("Meccs: $home - $away\n\n🔮 Ajánlott tipp: $randomPick\n🎯 Biztonság: $conf", style: const TextStyle(color: Colors.white70)),
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
                const SnackBar(content: Text("Tipp elmentve!")),
              );
            },
            child: const Text("Mentés", style: TextStyle(color: Color(0xFF10B981))),
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
                    onPressed: _loadMatches,
                    child: const Text("Meccsek Lekérése", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                  const SizedBox(height: 10),
                  ..._matches.map((m) => Card(
                        color: const Color(0xFF1E293B),
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          onTap: () => _analyzeMatch(m['home']!, m['away']!, m['conf']!),
                          title: Text("${m['home']} VS ${m['away']}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                          subtitle: Text("${m['league']} • ${m['time']}", style: const TextStyle(color: Colors.white60)),
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
                          child: ListTile(
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
                          ),
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
}
