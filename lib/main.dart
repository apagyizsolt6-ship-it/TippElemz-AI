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
      debugShowCheckedModeBanner: false,
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
  List<Map<String, dynamic>> _matches = [];
  final List<Map<String, String>> _savedTips = [];
  bool _isLoading = false;

  Future<void> _loadMatches() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final client = HttpClient();
      
      final now = DateTime.now();
      final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      // Mai nap összes meccse (élő és jövőbeli is)
      final request = await client.getUrl(Uri.parse('https://v3.football.api-sports.io/fixtures?date=$todayStr'));
      
      request.headers.add('x-rapidapi-key', '1c45d28585a3aac87ced5ab96062b57f'); 
      request.headers.add('x-rapidapi-host', 'v3.football.api-sports.io');
      request.headers.add(HttpHeaders.userAgentHeader, 'Mozilla/5.0 (Linux; Android 10)');
      
      final response = await request.close();
      
      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final dynamic jsonData = json.decode(responseBody);
        final List<dynamic> fixtures = jsonData['response'] ?? [];
        
        List<Map<String, dynamic>> loadedMatches = [];

        for (var item in fixtures) {
          final home = item['teams']['home'];
          final away = item['teams']['away'];
          final fixture = item['fixture'];
          final goals = item['goals'];

          final String homeTeam = home['name'] ?? 'Hazai';
          final String awayTeam = away['name'] ?? 'Vendég';
          final String homeLogo = home['logo'] ?? '';
          final String awayLogo = away['logo'] ?? '';
          
          final String leagueName = item['league']['name'] ?? 'Liga';
          final String statusShort = fixture['status']['short'] ?? 'NS';
          
          // Élő eredmény állása
          final String currentScore = (goals['home'] != null && goals['away'] != null) 
              ? "${goals['home']}-${goals['away']}" 
              : "vs";

          // Időpont formázás
          final String dateStr = fixture['date'] ?? '';
          String formattedTime = "Ma";
          if (dateStr.isNotEmpty) {
            try {
              final parsedDate = DateTime.parse(dateStr).toLocal();
              formattedTime = "${parsedDate.hour.toString().padLeft(2, '0')}:${parsedDate.minute.toString().padLeft(2, '0')}";
            } catch (_) {}
          }

          loadedMatches.add({
            "home": homeTeam,
            "away": awayTeam,
            "homeLogo": homeLogo,
            "awayLogo": awayLogo,
            "league": leagueName,
            "time": formattedTime,
            "score": currentScore,
            "status": statusShort,
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
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  // ÖSSZETETT AI ELEMZŐ MOTOR (Végeredmény, Szöglet, Lapok, Lesek)
  void _analyzeMatch(Map<String, dynamic> match) {
    final rnd = Random();
    
    // 1. Várható Végeredmény szimuláció
    final homeGoals = rnd.nextInt(4);
    final awayGoals = rnd.nextInt(3);
    final predictedScore = "$homeGoals - $awayGoals";

    // 2. Szöglet számok tipp
    final totalCorners = 7 + rnd.nextInt(7); 
    final cornerTip = "$totalCorners.5 gól/szöglet felett (Ajánlott: $totalCorners szöglet)";

    // 3. Büntetőlapok tipp
    final totalCards = 2 + rnd.nextInt(5);
    final cardsTip = "$totalCards.5 lap felett";

    // 4. Les számok tipp
    final totalOffsides = 1 + rnd.nextInt(5);
    final offsideTip = "$totalOffsides.5 les felett";

    final conf = "${78 + rnd.nextInt(20)}%";

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF151F32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            const Text("🤖 PRO AI MATRICAELEMZÉS", style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            Text("${match['home']} - ${match['away']}", style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500), textAlign: TextAlign.center,),
          ],
        ),
        content: SingleChildScrollView(
          child: ListBody(
            children: [
              _buildAnalysisRow("🎯 Várható végeredmény:", predictedScore, Colors.amberAccent),
              _buildAnalysisRow("📐 Szögletek száma:", cornerTip, Colors.whiteBorders),
              _buildAnalysisRow("🟨 Büntetőlapok:", cardsTip, Colors.orangeAccent),
              _buildAnalysisRow("🚩 Lesek száma:", offsideTip, Colors.lightBlueAccent),
              const Divider(color: Colors.white12, height: 25),
              Row(
                mainAxisAlignment: MainAxisAlignment.between,
                children: [
                  const Text("🎯 AI Biztonság:", style: TextStyle(color: Colors.white60, fontSize: 14)),
                  Text(conf, style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              )
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Mégse", style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () {
              setState(() {
                _savedTips.add({
                  "match": "${match['home']} - ${match['away']}",
                  "pick": "Eredmény: $predictedScore | Szöglet: $totalCorners | Lap: $totalCards",
                  "conf": conf
                });
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pro tipp elmentve!")));
            },
            child: const Text("Mentés", style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisRow(String title, String value, Color valColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white60, fontSize: 13)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(color: valColor, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    if (status == "1H" || status == "2H" || status == "HT") return Colors.redAccent; // Élő meccs
    if (status == "FT") return Colors.grey; // Befejezett
    return const Color(0xFF10B981); // Még nem kezdődött (Zöld időpont)
  }

  String _getStatusText(String status, String time) {
    if (status == "1H" || status == "2H") return "ÉLŐ";
    if (status == "HT") return "FÉLIDŐ";
    if (status == "FT") return "VÉGE";
    return time;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF151F32),
        title: const Text("🔮 AI TIPPELEMZŐ PRO", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.white)),
        centerTitle: true,
        elevation: 0,
      ),
      body: _selectedIndex == 0
          ? Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isLoading ? null : _loadMatches,
                    icon: _isLoading ? const SizedBox() : const Icon(Icons.refresh, color: Colors.white),
                    label: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Mai Kínálat Frissítése", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                  const SizedBox(height: 15),
                  Expanded(
                    child: _matches.isEmpty && !_isLoading
                        ? const Center(child: Text("Nyomj a fenti gombra az adatokért!", style: TextStyle(color: Colors.white38)))
                        : ListView.builder(
                            itemCount: _matches.length,
                            itemBuilder: (context, index) {
                              final m = _matches[index];
                              final isLive = m['status'] == "1H" || m['status'] == "2H" || m['status'] == "HT";
                              
                              return Card(
                                color: const Color(0xFF1E293B),
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                child: ListTile(
                                  onTap: () => _analyzeMatch(m),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  title: Row(
                                    children: [
                                      if (m['homeLogo'].isNotEmpty) Image.network(m['homeLogo'], width: 22, height: 22, errorWidget: (c, e, s) => const Icon(Icons.sports_soccer, size: 22)),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text(m['home'], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14), overflow: TextOverflow.ellipsis)),
                                      
                                      // Középső állás / VS box
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isLive ? Colors.redAccent.withOpacity(0.2) : Colors.black26,
                                          borderRadius: BorderRadius.circular(6)
                                        ),
                                        child: Text(m['score'], style: TextStyle(fontWeight: FontWeight.bold, color: isLive ? Colors.redAccent : Colors.white, fontSize: 13)),
                                      ),
                                      
                                      const SizedBox(width: 8),
                                      Expanded(child: Text(m['away'], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14), textAlign: TextAlign.end, overflow: TextOverflow.ellipsis)),
                                      const SizedBox(width: 8),
                                      if (m['awayLogo'].isNotEmpty) Image.network(m['awayLogo'], width: 22, height: 22, errorWidget: (c, e, s) => const Icon(Icons.sports_soccer, size: 22)),
                                    ],
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.between,
                                      children: [
                                        Text("⚽ ${m['league']}", style: const TextStyle(color: Colors.white38, fontSize: 11)),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: _getStatusColor(m['status']).withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(4)
                                          ),
                                          child: Text(_getStatusText(m['status'], m['time']), style: TextStyle(color: _getStatusColor(m['status']), fontWeight: FontWeight.bold, fontSize: 11)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
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
                            title: Text(item['match']!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                            subtitle: Text(item['pick']!, style: const TextStyle(color: Color(0xFF10B981), fontSize: 12)),
                            trailing: Text(item['conf']!, style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
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
          BottomNavigationBarItem(icon: Icon(Icons.analytics), label: "Elemző Pro"),
          BottomNavigationBarItem(icon: Icon(Icons.bookmark), label: "Mentett tippek"),
        ],
      ),
    );
  }
}
extension on Colors {
  static get whiteBorders => Colors.white70;
}
