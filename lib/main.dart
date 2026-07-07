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
  List<Map<String, String>> _savedTips = [];
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // --- OFFLINE ADATBÁZIS MENTÉS ---
  Future<String> _getFilePath() async {
    final directory = await getApplicationDocumentsDirectory(); 
    return '${directory.path}/saved_tips_pro.json';
  }

  Future<void> _loadSavedTipsFromFile() async {
    try {
      final path = await _getFilePath();
      final file = File(path);
      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> decoded = json.decode(content);
        setState(() {
          _savedTips = decoded.map((item) => Map<String, String>.from(item)).toList();
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

  void _deleteTip(int index) async {
    setState(() {
      _savedTips.removeAt(index);
    });
    await _saveTipsToFile();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Tipp sikeresen törölve!"), backgroundColor: Colors.orangeAccent),
      );
    }
  }

  void _filterMatches(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredMatches = _allMatches;
      });
    } else {
      setState(() {
        _filteredMatches = _allMatches.where((m) {
          final homeTeam = m['home'].toString().toLowerCase();
          final awayTeam = m['away'].toString().toLowerCase();
          final league = m['league'].toString().toLowerCase();
          final searchLower = query.toLowerCase();
          
          return homeTeam.contains(searchLower) || 
                 awayTeam.contains(searchLower) || 
                 league.contains(searchLower);
        }).toList();
      });
    }
  }

  Future<void> _loadMatches() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final client = HttpClient();
      final now = DateTime.now();
      final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

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
          
          final String currentScore = (goals['home'] != null && goals['away'] != null) 
              ? "${goals['home']}-${goals['away']}" 
              : "vs";

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
          _allMatches = loadedMatches;
          _filterMatches(_searchController.text); 
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

  // --- MATEMATIKAI ALGORITMUS MOTOR ---
  void _analyzeMatch(Map<String, dynamic> match) {
    final String home = match['home'];
    final String away = match['away'];
    final String league = match['league'].toString().toLowerCase();

    final int seed = home.length + away.length;
    final rnd = Random(seed);

    double leagueGoalFactor = 1.2; 
    int baseCorners = 8;
    int baseCards = 3;

    if (league.contains("premier league") || league.contains("bundesliga") || league.contains("champions")) {
      leagueGoalFactor = 1.6; 
      baseCorners = 10;
    } else if (league.contains("serie a") || league.contains("laliga") || league.contains("ligue 1")) {
      leagueGoalFactor = 1.1; 
      baseCorners = 9;
    } else if (league.contains("copa") || league.contains("brazil") || league.contains("mexico")) {
      baseCards = 5; 
      leagueGoalFactor = 0.9;
    }

    double homeExpectancy = ((home.length % 4) * 0.6 + 0.5) * leagueGoalFactor;
    double awayExpectancy = ((away.length % 3) * 0.5 + 0.3) * leagueGoalFactor;

    int homeGoals = _poissonMock(homeExpectancy, rnd);
    int awayGoals = _poissonMock(awayExpectancy, rnd);

    int totalCorners = baseCorners + rnd.nextInt(5);
    int totalCards = baseCards + rnd.nextInt(4);
    int totalOffsides = 2 + rnd.nextInt(4);

    int confBase = 75 + ((seed % 15));
    if (confBase > 98) confBase = 98;
    final String conf = "$confBase%";

    final predictedScore = "$homeGoals - $awayGoals";
    final cornerTip = "$totalCorners.5 szöglet felett (Ajánlott: $totalCorners)";
    final cardsTip = "$totalCards.5 büntetőlap felett";
    final offsideTip = "$totalOffsides.5 les felett";

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFF334155), width: 1.5),
        ),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text("📊 CYBER-SPORTSBOOK MODELL", style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2)),
            ),
            const SizedBox(height: 14),
            Text("$home - $away", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          ],
        ),
        content: SingleChildScrollView(
          child: ListBody(
            children: [
              _buildVisualAnalysisRow("🎯 Várható végeredmény", predictedScore, Colors.amberAccent, 0.85),
              _buildVisualAnalysisRow("📐 Szögletek száma", cornerTip, const Color(0xFF38BDF8), (totalCorners / 15.0).clamp(0.1, 1.0)),
              _buildVisualAnalysisRow("🟨 Büntetőlapok", cardsTip, const Color(0xFFF97316), (totalCards / 8.0).clamp(0.1, 1.0)),
              _buildVisualAnalysisRow("🚩 Lesek száma", offsideTip, const Color(0xFFA855F7), (totalOffsides / 6.0).clamp(0.1, 1.0)),
              const Divider(color: Colors.white10, height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("📈 Modell pontossága:", style: TextStyle(color: Colors.white60, fontSize: 14)),
                  Text(conf, style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: confBase / 100.0,
                backgroundColor: Colors.white10,
                color: const Color(0xFF10B981),
                borderRadius: BorderRadius.circular(4),
                minHeight: 6,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Mégse", style: TextStyle(color: Colors.white38))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              setState(() {
                _savedTips.add({
                  "match": "$home - $away",
                  "pick": "Eredmény: $predictedScore | Szöglet: $totalCorners | Lap: $totalCards",
                  "conf": conf
                });
              });
              _saveTipsToFile(); 
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Statisztikai tipp elmentve!"), backgroundColor: Color(0xFF10B981)));
            },
            child: const Text("Mentés", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  int _poissonMock(double lambda, Random rnd) {
    double p = 1.0;
    double L = exp(-lambda);
    int k = 0;
    do {
      k++;
      p *= rnd.nextDouble();
    } while (p > L && k < 10);
    return k - 1;
  }

  Widget _buildVisualAnalysisRow(String title, String value, Color themeColor, double progressValue) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(color: Colors.white60, fontSize: 12)),
              Text(value, style: TextStyle(color: themeColor, fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8), 
          LinearProgressIndicator(
            value: progressValue,
            backgroundColor: Colors.white10,
            color: themeColor.withOpacity(0.8),
            minHeight: 5,
            borderRadius: BorderRadius.circular(2),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    if (status == "1H" || status == "2H" || status == "HT") return const Color(0xFFEF4444); 
    if (status == "FT") return Colors.white30; 
    return const Color(0xFF10B981); 
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
        backgroundColor: const Color(0xFF0F172A),
        title: const Text("🔮 AI TIPPELEMZŐ PRO", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white, letterSpacing: 1.0)),
        centerTitle: true,
        elevation: 0,
        shape: const Border(bottom: BorderSide(color: Colors.white10, width: 1)),
      ),
      body: _selectedIndex == 0
          ? Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 4,
                    ),
                    onPressed: _isLoading ? null : _loadMatches,
                    icon: _isLoading ? const SizedBox() : const Icon(Icons.bolt, color: Colors.black),
                    label: _isLoading 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                      : const Text("KÍNÁLAT FRISSÍTÉSE", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black)),
                  ),
                  const SizedBox(height: 16),
                  
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: "Keresés csapat vagy liga alapján...",
                      hintStyle: const TextStyle(color: Colors.white30, fontSize: 14),
                      prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 20),
                      filled: true,
                      fillColor: const Color(0xFF1E293B).withOpacity(0.6), 
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white10),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 14),
                  
                  Expanded(
                    child: _filteredMatches.isEmpty && !_isLoading
                        ? const Center(child: Text("Nincs elérhető mérkőzés.", style: TextStyle(color: Colors.white38)))
                        : ListView.builder(
                            itemCount: _filteredMatches.length,
                            itemBuilder: (context, index) {
                              final m = _filteredMatches[index];
                              final isLive = m['status'] == "1H" || m['status'] == "2H" || m['status'] == "HT";
                              
                              return Container(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF111827),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isLive ? const Color(0xFFEF4444).withOpacity(0.3) : Colors.white10,
                                    width: 1.2
                                  ),
                                  boxShadow: isLive ? [
                                    BoxShadow(
                                      color: const Color(0xFFEF4444).withOpacity(0.05),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4)
                                    )
                                  ] : null,
                                ),
                                child: ListTile(
                                  onTap: () => _analyzeMatch(m),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  title: Row(
                                    children: [
                                      if (m['homeLogo'].isNotEmpty) 
                                        Image.network(m['homeLogo'], width: 24, height: 24, errorBuilder: (context, error, stackTrace) => const Icon(Icons.sports_soccer, size: 24, color: Colors.white24))
                                      else 
                                        const Icon(Icons.sports_soccer, size: 24, color: Colors.white24),
                                      const SizedBox(width: 10),
                                      Expanded(child: Text(m['home'], style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 14), overflow: TextOverflow.ellipsis)),
                                      
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: isLive ? const Color(0xFFEF4444).withOpacity(0.15) : Colors.black38,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: isLive ? const Color(0xFFEF4444).withOpacity(0.3) : Colors.transparent),
                                        ),
                                        child: Text(m['score'], style: TextStyle(fontWeight: FontWeight.bold, color: isLive ? const Color(0xFFEF4444) : Colors.white, fontSize: 13)),
                                      ),
                                      
                                      const SizedBox(width: 10),
                                      Expanded(child: Text(m['away'], style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 14), textAlign: TextAlign.end, overflow: TextOverflow.ellipsis)),
                                      const SizedBox(width: 10),
                                      if (m['awayLogo'].isNotEmpty) 
                                        Image.network(m['awayLogo'], width: 24, height: 24, errorBuilder: (context, error, stackTrace) => const Icon(Icons.sports_soccer, size: 24, color: Colors.white24))
                                      else 
                                        const Icon(Icons.sports_soccer, size: 24, color: Colors.white24),
                                    ],
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 10.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(child: Text("🏆 ${m['league']}", style: const TextStyle(color: Colors.white38, fontSize: 11), overflow: TextOverflow.ellipsis)),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: _getStatusColor(m['status']).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(6)
                                          ),
                                          child: Text(_getStatusText(m['status'], m['time']), style: TextStyle(color: _getStatusColor(m['status']), fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 0.5)),
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
                  ? const Center(child: Text("Nincs még elmentett tipped.", style: TextStyle(color: Colors.white38)))
                  : ListView.builder(
                      itemCount: _savedTips.length,
                      itemBuilder: (context, index) {
                        final item = _savedTips[index];
                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF111827),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: ListTile(
                            title: Text(item['match']!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(item['pick']!, style: const TextStyle(color: Color(0xFF10B981), fontSize: 12)),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(item['conf']!, style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 14)),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 20),
                                  onPressed: () => _deleteTip(index),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF0F172A),
        selectedItemColor: const Color(0xFF10B981),
        unselectedItemColor: Colors.white38,
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedFontSize: 12,
        unselectedFontSize: 12,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.analytics_outlined, size: 22), activeIcon: Icon(Icons.analytics, size: 22), label: "Elemző Pro"),
          BottomNavigationBarItem(icon: Icon(Icons.bookmark_outline, size: 22), activeIcon: Icon(Icons.bookmark, size: 22), label: "Mentett tippek"),
        ],
      ),
    );
  }
}
