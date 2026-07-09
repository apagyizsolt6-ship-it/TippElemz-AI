import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.dark;
  void toggleTheme() => setState(() => _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.light),
      darkTheme: ThemeData(brightness: Brightness.dark),
      themeMode: _themeMode,
      home: MainScreen(toggleTheme: toggleTheme),
    );
  }
}

class MainScreen extends StatefulWidget {
  final VoidCallback toggleTheme;
  const MainScreen({super.key, required this.toggleTheme});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  List<Map<String, dynamic>> _allMatches = [];
  List<Map<String, dynamic>> _savedTips = [];
  bool _isLoading = false;
  bool _isLiveOnly = false;
  bool _hideFriendlies = true;
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
    return '${dir.path}/pro_analyzer_v5_ultimate.json';
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

  // --- AI SZIMULÁCIÓS MOTOR ---
  Map<String, dynamic> _generateAiPredictions(String home, String away) {
    int seed = home.length + away.length;
    int homeGoals = seed % 4;
    int awayGoals = (seed * 3) % 3;
    String exactScore = "$homeGoals - $awayGoals";
    int scoreConf = 55 + (seed % 25);

    double cornersLine = 8.5 + (seed % 3);
    int cornersConf = 65 + (seed * 3 % 25);

    double foulsLine = 21.5 + (seed % 5);
    int foulsConf = 60 + (seed * 7 % 30);

    double cardsLine = 3.5 + (seed % 2);
    int cardsConf = 55 + (seed * 2 % 30);

    double offsidesLine = 1.5 + (seed % 3);
    int offsidesConf = 50 + (seed * 4 % 35);

    List<int> confidences = [scoreConf, cornersConf, foulsConf, cardsConf, offsidesConf];
    int maxConf = confidences.reduce((curr, next) => curr > next ? curr : next);

    return {
      "score": exactScore, "scoreConf": "$scoreConf% Conf", "isScoreBest": scoreConf == maxConf,
      "corners": "Over $cornersLine", "cornersConf": "$cornersConf% Conf", "isCornersBest": cornersConf == maxConf,
      "fouls": "Over $foulsLine", "foulsConf": "$foulsConf% Conf", "isFoulsBest": foulsConf == maxConf,
      "cards": "Over $cardsLine", "cardsConf": "$cardsConf% Conf", "isCardsBest": cardsConf == maxConf,
      "offsides": "Over $offsidesLine", "offsidesConf": "$offsidesConf% Conf", "isOffsidesBest": offsidesConf == maxConf,
      "maxConfValue": maxConf,
      "bestBetString": scoreConf == maxConf ? "Pontos eredmény: $exactScore" : (cornersConf == maxConf ? "Szöglet: Over $cornersLine" : "Lapok: Over $cardsLine")
    };
  }

  // --- KIVÁLASZTJA A NAP 3 LEGBIZTOSABB TIPPJÉT ---
  List<Map<String, dynamic>> _getTop3Tips() {
    List<Map<String, dynamic>> pool = [];
    for (var m in _allMatches) {
      final ai = _generateAiPredictions(m['home'], m['away']);
      pool.add({
        "match": m,
        "conf": ai['maxConfValue'],
        "pick": ai['bestBetString']
      });
    }
    pool.sort((a, b) => b['conf'].compareTo(a['conf']));
    return pool.take(3).toList();
  }

  void _analyze(Map<String, dynamic> m) {
    final ai = _generateAiPredictions(m['home'], m['away']);

    showDialog(context: context, builder: (_) => BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor.withOpacity(0.9),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text("${m['home']} vs ${m['away']}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.amber)),
            const SizedBox(height: 15),
            _buildStatRow(Icons.sports_soccer, "Várható végeredmény", ai['score'], ai['scoreConf'], Colors.blue, isBest: ai['isScoreBest']),
            _buildStatRow(Icons.radio_button_checked, "Szöglet (O/U)", ai['corners'], ai['cornersConf'], Colors.green, isBest: ai['isCornersBest']),
            _buildStatRow(Icons.warning_amber, "Szabálytalanság (O/U)", ai['fouls'], ai['foulsConf'], Colors.orange, isBest: ai['isFoulsBest']),
            _buildStatRow(Icons.receipt_long, "Lapok (O/U)", ai['cards'], ai['cardsConf'], Colors.yellow, isBest: ai['isCardsBest']),
            _buildStatRow(Icons.flag_outlined, "Lesek (O/U)", ai['offsides'], ai['offsidesConf'], Colors.purple, isBest: ai['isOffsidesBest']),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                setState(() => _savedTips.add({
                  "match": "${m['home']} - ${m['away']}", 
                  "pick": "Pontos eredmény: ${ai['score']}",
                  "status": "pending",
                  "odds": 2.0,
                  "stake": 10.0
                }));
                _saveTips(); 
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
              child: const Text("Tipp mentése"),
            ),
          ]),
        ),
      ),
    ));
  }

  Widget _buildStatRow(IconData icon, String title, String value, String conf, Color color, {bool isBest = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(children: [
      Icon(icon, color: isBest ? Colors.amber : color, size: 22),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(conf, style: TextStyle(fontSize: 10, color: Colors.grey)),
      ]),
      const Spacer(),
      Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: isBest ? Colors.amber : null))
    ]),
  );

  Future<void> _loadMatches() async {
    setState(() => _isLoading = true);
    try {
      String dateStr = DateTime.now().toString().substring(0, 10);
      var client = HttpClient();
      var req = await client.getUrl(Uri.parse('https://v3.football.api-sports.io/fixtures?date=$dateStr'));
      req.headers.add('x-rapidapi-key', '1c45d28585a3aac87ced5ab96062b57f');
      var res = await req.close();
      if (res.statusCode == 200) {
        var data = json.decode(await res.transform(utf8.decoder).join())['response'];
        setState(() => _allMatches = List<Map<String, dynamic>>.from(data.map((m) {
          // ÉLŐ MECCSEK AKTÁLIS ÁLLÁSÁNAK LEKÉRÉSE (2. FŐ FUNKCIÓ)
          String homeGoals = m['goals']['home'] != null ? m['goals']['home'].toString() : "";
          String awayGoals = m['goals']['away'] != null ? m['goals']['away'].toString() : "";
          String currentScore = (homeGoals.isNotEmpty && awayGoals.isNotEmpty) ? " | $homeGoals-$awayGoals" : "";

          return {
            "home": m['teams']['home']['name'],
            "away": m['teams']['away']['name'],
            "logo": m['league']['logo'],
            "status": m['fixture']['status']['short'],
            "league": m['league']['name'],
            "time": m['fixture']['date'] != null ? DateFormat('HH:mm').format(DateTime.parse(m['fixture']['date'])) : "--:--",
            "liveScore": currentScore
          };
        })));
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  // --- ODDS ÉS TÉT BEKÉRŐ MODAL WINDOW (1. FŐ FUNKCIÓ) ---
  void _settleTipDialog(int index, String newStatus) {
    final oddsController = TextEditingController(text: "2.00");
    final stakeController = TextEditingController(text: "10");

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(newStatus == 'won' ? "Tipp lezárása: NYERT" : "Tipp lezárása: VESZTETT"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: oddsController, decoration: const InputDecoration(labelText: "Valódi Szorzó (Odds)"), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
            TextField(controller: stakeController, decoration: const InputDecoration(labelText: "Tét (Unit vagy Ft)"), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Mégse")),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _savedTips[index]['status'] = newStatus;
                _savedTips[index]['odds'] = double.tryParse(oddsController.text) ?? 2.0;
                _savedTips[index]['stake'] = double.tryParse(stakeController.text) ?? 10.0;
                _saveTips();
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
            child: const Text("Mentés és elszámolás"),
          )
        ],
      ),
    );
  }

  // --- HAJSZÁLPONTOS PRO PROFIT DASHBOARD SZÁMÍTÁS ---
  Widget _buildProfitDashboard() {
    int totalTips = _savedTips.length;
    int wonTips = _savedTips.where((t) => t['status'] == 'won').length;
    int lostTips = _savedTips.where((t) => t['status'] == 'lost').length;

    double totalStake = 0;
    double netProfit = 0;

    for (var t in _savedTips) {
      if (t['status'] == 'won' || t['status'] == 'lost') {
        double stake = (t['stake'] ?? 10.0).toDouble();
        double odds = (t['odds'] ?? 2.0).toDouble();
        totalStake += stake;
        if (t['status'] == 'won') {
          netProfit += (stake * odds) - stake;
        } else {
          netProfit -= stake;
        }
      }
    }

    int ratedTips = wonTips + lostTips;
    String winRate = ratedTips > 0 ? "${((wonTips / ratedTips) * 100).toStringAsFixed(0)}%" : "0%";
    String roi = totalStake > 0 ? "${((netProfit / totalStake) * 100).toStringAsFixed(1)}%" : "0.0%";

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withOpacity(0.6),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.amber.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildDashboardStat("Össz Tipp", "$totalTips db", Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white),
          _buildDashboardStat("Valódi ROI", netProfit >= 0 ? "+$roi" : roi, netProfit >= 0 ? Colors.green : Colors.red),
          _buildDashboardStat("Win Rate", winRate, Colors.amber),
        ],
      ),
    );
  }

  Widget _buildDashboardStat(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: valueColor)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredMatches = _allMatches.where((m) {
      bool matchesSearch = m['home']?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? true;
      bool matchesLive = !_isLiveOnly || m['status'] == '1H' || m['status'] == '2H' || m['status'] == 'ET' || m['status'] == 'LIVE';
      
      String leagueName = m['league']?.toString().toLowerCase() ?? "";
      String homeName = m['home']?.toString().toLowerCase() ?? "";
      String awayName = m['away']?.toString().toLowerCase() ?? "";
      
      bool isFriendly = leagueName.contains('friendly') || leagueName.contains('friendlies') || leagueName.contains('friend') || leagueName.contains('barátságos') || homeName.contains('friendly') || homeName.contains('friendlies') || awayName.contains('friendly');
      bool matchesFriendly = !_hideFriendlies || !isFriendly;

      bool isFinished = m['status'] == 'FT' || m['status'] == 'AET' || m['status'] == 'PEN' || m['status'] == 'PST';
      bool matchesNotFinished = !isFinished;

      return matchesSearch && matchesLive && matchesFriendly && matchesNotFinished;
    }).toList();

    // 4. FUNKCIÓ: TIPPEK SZÉTVÁLASZTÁSA AKTÍV ÉS LEZÁRT RÉSZRE
    final activeTips = _savedTips.where((t) => t['status'] == 'pending').toList();
    final settledTips = _savedTips.where((t) => t['status'] == 'won' || t['status'] == 'lost').toList();

    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("AI PRO ANALYZER", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          Text(DateFormat('yyyy.MM.dd').format(DateTime.now()), style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ]),
        actions: [
          IconButton(icon: Icon(_hideFriendlies ? Icons.sports_esports : Icons.sports_soccer, color: _hideFriendlies ? Colors.grey : Colors.green), onPressed: () => setState(() => _hideFriendlies = !_hideFriendlies)),
          IconButton(icon: Icon(_isLiveOnly ? Icons.live_tv : Icons.tv_off, color: _isLiveOnly ? Colors.red : null), onPressed: () => setState(() => _isLiveOnly = !_isLiveOnly)),
          IconButton(icon: const Icon(Icons.brightness_6), onPressed: widget.toggleTheme),
        ],
        bottom: PreferredSize(preferredSize: const Size.fromHeight(60), child: Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(decoration: const InputDecoration(hintText: "Csapat keresése...", prefixIcon: Icon(Icons.search)), onChanged: (v) => setState(() => _searchQuery = v)),
        )),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator()) 
          : Column(
              children: [
                if (_selectedIndex == 1) _buildProfitDashboard(),
                
                // 3. FUNKCIÓ: NAPI TOP 3 AI TIPP PANELA MECCSEK FÜLÖN
                if (_selectedIndex == 0 && _allMatches.isNotEmpty && _searchQuery.isEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Align(alignment: Alignment.centerLeft, child: Text("🔥 NAPI TOP 3 AI TIPP", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.amber))),
                  ),
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _getTop3Tips().length,
                      itemBuilder: (_, idx) {
                        final item = _getTop3Tips()[idx];
                        return Container(
                          width: 250,
                          margin: const EdgeInsets.all(8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.amber.withOpacity(0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.amber.withOpacity(0.4))),
                          child: InkWell(
                            onTap: () => _analyze(item['match']),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                              Text("${item['match']['home']} - ${item['match']['away']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 4),
                              Text(item['pick'], style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold)),
                              Text("Konfidencia: ${item['conf']}%", style: const TextStyle(color: Colors.grey, fontSize: 10)),
                            ]),
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(),
                ],

                Expanded(
                  child: _selectedIndex == 0
                      ? ListView.builder(
                          itemCount: filteredMatches.length,
                          itemBuilder: (_, i) => Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(gradient: LinearGradient(colors: [Theme.of(context).cardColor, Colors.transparent]), borderRadius: BorderRadius.circular(15)),
                            child: ListTile(
                              leading: Image.network(filteredMatches[i]['logo'] ?? "", width: 40, errorBuilder: (_,__,___) => const Icon(Icons.sports_soccer)),
                              title: Text("${filteredMatches[i]['home']} - ${filteredMatches[i]['away']}"),
                              subtitle: Text("Kezdés: ${filteredMatches[i]['time']} (${filteredMatches[i]['status']})${filteredMatches[i]['liveScore']}", style: TextStyle(color: Colors.amber[700])),
                              onTap: () => _analyze(filteredMatches[i]),
                            ),
                          ),
                        )
                      : CustomScrollView(
                          slivers: [
                            // --- AKTÍV (FÜGGŐBEN LÉVŐ) TIPPEK RÉSZ ---
                            if (activeTips.isNotEmpty) ...[
                              const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(16), child: Text("⏳ Aktív Tippek", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.amber)))),
                              SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (_, i) {
                                    int realIndex = _savedTips.indexOf(activeTips[i]);
                                    return Card(
                                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                      child: ListTile(
                                        leading: const Icon(Icons.history, color: Colors.amber),
                                        title: Text(activeTips[i]['match']),
                                        subtitle: Text(activeTips[i]['pick']),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(icon: const Icon(Icons.check, color: Colors.green), onPressed: () => _settleTipDialog(realIndex, 'won')),
                                            IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () => _settleTipDialog(realIndex, 'lost')),
                                            IconButton(icon: const Icon(Icons.delete, color: Colors.grey), onPressed: () => setState(() { _savedTips.removeAt(realIndex); _saveTips(); })),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                  childCount: activeTips.length,
                                ),
                              ),
                            ],
                            // --- LEZÁRT TÖRTÉNET RÉSZ ---
                            if (settledTips.isNotEmpty) ...[
                              const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(16), child: Text("✅ Lezárt Történet", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey)))),
                              SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (_, i) {
                                    int realIndex = _savedTips.indexOf(settledTips[i]);
                                    bool isWon = settledTips[i]['status'] == 'won';
                                    return Card(
                                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                      color: isWon ? Colors.green.withOpacity(0.05) : Colors.red.withOpacity(0.05),
                                      child: ListTile(
                                        leading: Icon(isWon ? Icons.check_circle : Icons.cancel, color: isWon ? Colors.green : Colors.red),
                                        title: Text(settledTips[i]['match'], style: const TextStyle(fontSize: 13)),
                                        subtitle: Text("${settledTips[i]['pick']}\nOdds: ${settledTips[i]['odds']} | Tét: ${settledTips[i]['stake']}", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                        trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.grey), onPressed: () => setState(() { _savedTips.removeAt(realIndex); _saveTips(); })),
                                      ),
                                    );
                                  },
                                  childCount: settledTips.length,
                                ),
                              ),
                            ],
                          ],
                        ),
                ),
              ],
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        items: const [BottomNavigationBarItem(icon: Icon(Icons.sports_soccer), label: "Meccsek"), BottomNavigationBarItem(icon: Icon(Icons.history), label: "Profit")],
      ),
    );
  }
}
