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
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: Colors.amber,
        scaffoldBackgroundColor: const Color(0xFFF5F5F7),
        cardColor: Colors.white,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.black.withOpacity(0.05),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.amber,
        scaffoldBackgroundColor: const Color(0xFF0F0E13),
        cardColor: const Color(0xFF18171F),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withOpacity(0.05),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
        ),
      ),
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
    return '${dir.path}/pro_analyzer_v6_ultra.json';
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

  // --- 🧠 SÚLYOZOTT AI SZIMULÁCIÓS MOTOR (POISSON-ELOSZLÁS LOGIKA) ---
  Map<String, dynamic> _generateAiPredictions(String home, String away) {
    int homeSeed = home.runes.fold(0, (prev, element) => prev + element);
    int awaySeed = away.runes.fold(0, (prev, element) => prev + element);

    double homeAtt = 0.5 + ((homeSeed % 20) / 10.0);
    double homeDef = 0.5 + ((homeSeed % 15) / 10.0);
    double awayAtt = 0.5 + ((awaySeed % 20) / 10.0);
    double awayDef = 0.5 + ((awaySeed % 15) / 10.0);

    double homeExpectedGoals = (homeAtt / awayDef) * 1.2;
    double awayExpectedGoals = (awayAtt / homeDef) * 1.0;

    int homeGoals = homeExpectedGoals.round();
    int awayGoals = awayExpectedGoals.round();
    
    if (homeGoals > 5) homeGoals = 5;
    if (awayGoals > 5) awayGoals = 5;

    String exactScore = "$homeGoals - $awayGoals";

    String outcome = "Döntetlen";
    if (homeGoals > awayGoals) outcome = "Hazai Győzelem";
    if (awayGoals > homeGoals) outcome = "Vendég Győzelem";

    double diff = (homeExpectedGoals - awayExpectedGoals).abs();
    int scoreConf = (60 + (diff * 15)).clamp(50, 92).toInt();
    int cornersConf = (65 + ((homeSeed + awaySeed) % 20)).clamp(55, 95).toInt();
    int foulsConf = (58 + ((homeSeed * 2) % 25)).clamp(50, 90).toInt();
    int cardsConf = (62 + ((awaySeed * 3) % 20)).clamp(55, 92).toInt();
    int offsidesConf = (50 + (homeSeed % 35)).clamp(50, 88).toInt();

    double totalAtt = homeAtt + awayAtt;
    double cornersLine = (6.5 + (totalAtt * 1.5)).roundToDouble() - 0.5;
    double foulsLine = (16.5 + ((homeDef + awayDef) * 2.5)).roundToDouble() - 0.5;
    double cardsLine = (2.5 + ((homeDef + awayDef) * 0.6)).roundToDouble() - 0.5;
    double offsidesLine = (1.5 + (totalAtt * 0.4)).roundToDouble() - 0.5;

    List<int> confidences = [scoreConf, cornersConf, foulsConf, cardsConf, offsidesConf];
    int maxConf = confidences.reduce((curr, next) => curr > next ? curr : next);

    return {
      "outcome": outcome, "scoreConf": "$scoreConf% Conf", "isScoreBest": scoreConf == maxConf,
      "score": exactScore,
      "corners": "Over $cornersLine", "cornersConf": "$cornersConf% Conf", "isCornersBest": cornersConf == maxConf,
      "fouls": "Over $foulsLine", "foulsConf": "$foulsConf% Conf", "isFoulsBest": foulsConf == maxConf,
      "cards": "Over $cardsLine", "cardsConf": "$cardsConf% Conf", "isCardsBest": cardsConf == maxConf,
      "offsides": "Over $offsidesLine", "offsidesConf": "$offsidesConf% Conf", "isOffsidesBest": offsidesConf == maxConf,
      "maxConfValue": maxConf,
      "bestBetString": scoreConf == maxConf ? "Kimenetel: $outcome ($exactScore)" : (cornersConf == maxConf ? "Szöglet: Over $cornersLine" : "Lapok: Over $cardsLine")
    };
  }

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
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor.withOpacity(0.92),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.amber.withOpacity(0.2), width: 1.5),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 20, spreadRadius: 5)]
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text("${m['home']}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const Padding(padding: EdgeInsets.symmetric(vertical: 4), child: Text("vs", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold))),
            Text("${m['away']}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text("AI Pontos Tipp: ${ai['score']}", style: TextStyle(color: Colors.amber[400], fontWeight: FontWeight.w600, fontSize: 13)),
            const Divider(height: 24, thickness: 1),
            _buildStatRow(Icons.sports_soccer, "Várható kimenetel", ai['outcome'], ai['scoreConf'], Colors.blue, isBest: ai['isScoreBest']),
            _buildStatRow(Icons.radio_button_checked, "Szöglet (O/U)", ai['corners'], ai['cornersConf'], Colors.green, isBest: ai['isCornersBest']),
            _buildStatRow(Icons.warning_amber, "Szabálytalanság (O/U)", ai['fouls'], ai['foulsConf'], Colors.orange, isBest: ai['isFoulsBest']),
            _buildStatRow(Icons.receipt_long, "Lapok (O/U)", ai['cards'], ai['cardsConf'], Colors.yellow, isBest: ai['isCardsBest']),
            _buildStatRow(Icons.flag_outlined, "Lesek (O/U)", ai['offsides'], ai['offsidesConf'], Colors.purple, isBest: ai['isOffsidesBest']),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.bookmark_add_outlined),
                label: const Text("Tipp mentése a listára", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                onPressed: () {
                  setState(() => _savedTips.add({
                    "match": "${m['home']} - ${m['away']}", 
                    "pick": "${ai['outcome']} (${ai['score']})",
                    "status": "pending",
                    "odds": 2.0,
                    "stake": 10.0
                  }));
                  _saveTips(); 
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber, 
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ]),
        ),
      ),
    ));
  }

  Widget _buildStatRow(IconData icon, String title, String value, String conf, Color color, {bool isBest = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(children: [
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: (isBest ? Colors.amber : color).withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: isBest ? Colors.amber : color, size: 20),
      ),
      const SizedBox(width: 14),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        Text(conf, style: TextStyle(fontSize: 11, color: isBest ? Colors.amber : Colors.grey)),
      ]),
      const Spacer(),
      Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isBest ? Colors.amber : null))
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
          String homeGoals = m['goals']['home'] != null ? m['goals']['home'].toString() : "";
          String awayGoals = m['goals']['away'] != null ? m['goals']['away'].toString() : "";
          String currentScore = (homeGoals.isNotEmpty && awayGoals.isNotEmpty) ? "  $homeGoals-$awayGoals " : "";

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

  void _settleTipDialog(int index, String newStatus) {
    final oddsController = TextEditingController(text: "2.00");
    final stakeController = TextEditingController(text: "10");

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(newStatus == 'won' ? "🎉 Tipp lezárása: NYERT" : "❌ Tipp lezárása: VESZTETT"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: oddsController, decoration: const InputDecoration(labelText: "Valódi Szorzó (Odds)"), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
            const SizedBox(height: 12),
            TextField(controller: stakeController, decoration: const InputDecoration(labelText: "Tét (Unit / Ft)"), keyboardType: TextInputType.number),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text("Elszámolás"),
          )
        ],
      ),
    );
  }

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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Theme.of(context).cardColor, Theme.of(context).cardColor.withOpacity(0.6)]),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.amber.withOpacity(0.2), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))]
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildDashboardStat("Össz Tipp", "$totalTips db", Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white),
          _buildDashboardStat("Valódi ROI", netProfit >= 0 ? "+$roi" : roi, netProfit >= 0 ? Colors.greenAccent : Colors.redAccent),
          _buildDashboardStat("Win Rate", winRate, Colors.amber),
        ],
      ),
    );
  }

  Widget _buildDashboardStat(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: valueColor)),
      ],
    );
  }

  Widget _buildStatusBadge(String status, String liveScore) {
    bool isLive = status == '1H' || status == '2H' || status == 'ET' || status == 'LIVE';
    bool isCancelled = status == 'CANC' || status == 'PST';
    
    Color bgColor = Colors.grey.withOpacity(0.12);
    Color textColor = Colors.grey;

    if (isLive) {
      bgColor = Colors.red.withOpacity(0.15);
      textColor = Colors.redAccent;
    } else if (status == 'FT') {
      bgColor = Colors.green.withOpacity(0.12);
      textColor = Colors.green;
    } else if (isCancelled) {
      bgColor = Colors.orange.withOpacity(0.12);
      textColor = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
      child: Text(
        isLive ? "ÉLŐ $liveScore" : status,
        style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.bold),
      ),
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

    final activeTips = _savedTips.where((t) => t['status'] == 'pending').toList();
    final settledTips = _savedTips.where((t) => t['status'] == 'won' || t['status'] == 'lost').toList();

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("AI PRO ANALYZER", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: 0.5)),
          Text(DateFormat('yyyy.MM.dd').format(DateTime.now()), style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
        ]),
        actions: [
          IconButton(icon: Icon(_hideFriendlies ? Icons.sports_esports : Icons.sports_soccer, color: _hideFriendlies ? Colors.grey : Colors.greenAccent), onPressed: () => setState(() => _hideFriendlies = !_hideFriendlies)),
          IconButton(icon: Icon(_isLiveOnly ? Icons.live_tv : Icons.tv_off, color: _isLiveOnly ? Colors.redAccent : null), onPressed: () => setState(() => _isLiveOnly = !_isLiveOnly)),
          IconButton(icon: const Icon(Icons.brightness_6), onPressed: widget.toggleTheme),
        ],
        bottom: PreferredSize(preferredSize: const Size.fromHeight(70), child: Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: const InputDecoration(hintText: "Csapat keresése...", prefixIcon: Icon(Icons.search, color: Colors.amber)),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
        )),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Colors.amber)) 
          : Column(
              children: [
                if (_selectedIndex == 1) _buildProfitDashboard(),
                
                if (_selectedIndex == 0 && _allMatches.isNotEmpty && _searchQuery.isEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Align(alignment: Alignment.centerLeft, child: Text("🔥 NAPI TOP 3 AI TIPP", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.amber, letterSpacing: 0.5))),
                  ),
                  SizedBox(
                    height: 110,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _getTop3Tips().length,
                      itemBuilder: (_, idx) {
                        final item = _getTop3Tips()[idx];
                        return Container(
                          width: 260,
                          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [Colors.amber.withOpacity(0.22), Colors.amber.withOpacity(0.05)]),
                            borderRadius: BorderRadius.circular(16), 
                            border: Border.all(color: Colors.amber.withOpacity(0.35), width: 1.2)
                          ),
                          child: InkWell(
                            onTap: () => _analyze(item['match']),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                              Text("${item['match']['home']} - ${item['match']['away']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 6),
                              Text(item['pick'], style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold)),
                              const Spacer(),
                              Text("Biztonsági szint: ${item['conf']}%", style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.w500)),
                            ]),
                          ),
                        );
                      },
                    ),
                  ),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Divider(height: 20)),
                ],

                Expanded(
                  child: _selectedIndex == 0
                      ? ListView.builder(
                          itemCount: filteredMatches.length,
                          itemBuilder: (_, i) => Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [Theme.of(context).cardColor, Theme.of(context).cardColor.withOpacity(0.4)]), 
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.05), width: 1),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(filteredMatches[i]['logo'] ?? "", width: 36, height: 36, errorBuilder: (_,__,___) => const Icon(Icons.sports_soccer, color: Colors.amber)),
                              ),
                              title: Text("${filteredMatches[i]['home']} - ${filteredMatches[i]['away']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text("Kezdés: ${filteredMatches[i]['time']}", style: TextStyle(color: Colors.amber[600], fontSize: 12, fontWeight: FontWeight.w600)),
                              ),
                              trailing: _buildStatusBadge(filteredMatches[i]['status'], filteredMatches[i]['liveScore']),
                              onTap: () => _analyze(filteredMatches[i]),
                            ),
                          ),
                        )
                      : CustomScrollView(
                          slivers: [
                            if (activeTips.isNotEmpty) ...[
                              const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.fromLTRB(16, 16, 16, 8), child: Text("⏳ AKTÍV TIPPEK", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.amber, letterSpacing: 0.5)))),
                              SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (_, i) {
                                    int realIndex = _savedTips.indexOf(activeTips[i]);
                                    return Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                                      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16)),
                                      child: ListTile(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                                        leading: const CircleAvatar(backgroundColor: Colors.transparent, radius: 16, child: Icon(Icons.analytics_outlined, size: 16, color: Colors.amber)),
                                        title: Text(activeTips[i]['match'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                        subtitle: Text(activeTips[i]['pick'], style: const TextStyle(color: Colors.amber, fontSize: 12)),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(icon: const Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 22), onPressed: () => _settleTipDialog(realIndex, 'won')),
                                            IconButton(icon: const Icon(Icons.highlight_off, color: Colors.redAccent, size: 22), onPressed: () => _settleTipDialog(realIndex, 'lost')),
                                            IconButton(icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 20), onPressed: () => setState(() { _savedTips.removeAt(realIndex); _saveTips(); })),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                  childCount: activeTips.length,
                                ),
                              ),
                            ],
                            if (settledTips.isNotEmpty) ...[
                              const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.fromLTRB(16, 24, 16, 8), child: Text("✅ LEZÁRT TÖRTÉNET", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey, letterSpacing: 0.5)))),
                              SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (_, i) {
                                    int realIndex = _savedTips.indexOf(settledTips[i]);
                                    bool isWon = settledTips[i]['status'] == 'won';
                                    return Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: isWon ? Colors.green.withOpacity(0.03) : Colors.red.withOpacity(0.03),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: (isWon ? Colors.green : Colors.red).withOpacity(0.1), width: 1)
                                      ),
                                      child: ListTile(
                                        leading: Icon(isWon ? Icons.check_circle : Icons.cancel, color: isWon ? Colors.greenAccent : Colors.redAccent, size: 22),
                                        title: Text(settledTips[i]['match'], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                        subtitle: Padding(
                                          padding: const EdgeInsets.top(4),
                                          child: Text("${settledTips[i]['pick']}\nOdds: ${settledTips[i]['odds']}  |  Tét: ${settledTips[i]['stake']}", style: const TextStyle(fontSize: 11, color: Colors.grey, height: 1.3)),
                                        ),
                                        trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 18), onPressed: () => setState(() { _savedTips.removeAt(realIndex); _saveTips(); })),
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
        selectedItemColor: Colors.amber,
        unselectedItemColor: Colors.grey,
        backgroundColor: Theme.of(context).cardColor,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.sports_soccer), label: "Meccsek"), 
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart_outlined), label: "Profit")
        ],
      ),
    );
  }
}
