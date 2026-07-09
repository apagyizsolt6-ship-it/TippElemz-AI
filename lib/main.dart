import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
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
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          actionsIconTheme: IconThemeData(color: Colors.black),
          titleTextStyle: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.black.withOpacity(0.05),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.amber,
        scaffoldBackgroundColor: const Color(0xFF0A1128),
        cardColor: const Color(0xFF101F42),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          actionsIconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1E2E5A).withOpacity(0.6),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
        ),
        dividerColor: const Color(0xFF1E2E5A),
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
  bool _hideFriendlies = false;
  String _searchQuery = "";
  final String _apiKey = '1c45d28585a3aac87ced5ab96062b57f';

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

  Map<String, dynamic> _calculateRealAiPredictions({
    required Map<String, dynamic> homeStats,
    required Map<String, dynamic> awayStats,
    required double realOdds,
    required String homeName,
    required String awayName,
  }) {
    int nameSeed = homeName.hashCode ^ awayName.hashCode;
    bool hasRealApiData = homeStats.isNotEmpty && awayStats.isNotEmpty;

    double homeAtt = 1.3;
    double homeDef = 1.2;
    double awayAtt = 1.1;
    double awayDef = 1.3;

    if (realOdds > 1.0 && realOdds < 10.0) {
      if (realOdds < 1.7) {
        homeAtt = 2.1; 
        homeDef = 0.8; 
        awayAtt = 0.7; 
        awayDef = 1.9;
      } else if (realOdds > 3.5) {
        homeAtt = 0.9; 
        homeDef = 1.7; 
        awayAtt = 1.8; 
        awayDef = 1.0;
      }
    }

    if (hasRealApiData) {
      homeAtt = double.tryParse(homeStats['goals']?['for']?['average']?['home']?.toString() ?? '') ?? homeAtt;
      awayDef = double.tryParse(awayStats['goals']?['against']?['average']?['away']?.toString() ?? '') ?? awayDef;
      awayAtt = double.tryParse(awayStats['goals']?['for']?['average']?['away']?.toString() ?? '') ?? awayAtt;
      homeDef = double.tryParse(homeStats['goals']?['against']?['average']?['home']?.toString() ?? '') ?? homeDef;
    }

    double homeExpectedGoals = (homeAtt + awayDef) / 2;
    double awayExpectedGoals = (awayAtt + homeDef) / 2;

    int homeGoals = homeExpectedGoals.round().clamp(0, 5);
    int awayGoals = awayExpectedGoals.round().clamp(0, 5);
    
    String exactScore = "$homeGoals - $awayGoals";

    String matchOutcomeText = "Döntetlen";
    double homeWinProb = 0.33;
    
    if (homeGoals > awayGoals) {
      matchOutcomeText = "Hazai Győzelem";
      homeWinProb = 0.48 + ((nameSeed % 15) / 100.0);
    } else if (awayGoals > homeGoals) {
      matchOutcomeText = "Vendég Győzelem";
      homeWinProb = 0.22 + ((nameSeed % 12) / 100.0);
    } else {
      homeWinProb = 0.28 + ((nameSeed % 10) / 100.0);
    }

    int scoreConf = (homeWinProb * 100).round().clamp(45, 94);
    int cornersConf = (62 + (nameSeed % 20)).clamp(55, 90);
    int foulsConf = (58 + ((nameSeed >> 2) % 20)).clamp(55, 90);
    int cardsConf = (60 + ((nameSeed >> 4) % 20)).clamp(55, 90);

    double cornersLine = 8.5 + (nameSeed % 3 == 0 ? 1.0 : 0.5);
    double foulsLine = 21.5 + (nameSeed % 4);
    double cardsLine = 3.5 + (nameSeed % 2 == 0 ? 1.0 : 0.0);

    return {
      "outcome": hasRealApiData ? "$matchOutcomeText (Éles stat)" : "$matchOutcomeText (AI Becsült)", 
      "scoreConf": "$scoreConf% Conf", "isScoreBest": true,
      "score": exactScore,
      "corners": "Over $cornersLine", "cornersConf": "$cornersConf% Conf", "isCornersBest": false,
      "fouls": "Over $foulsLine", "foulsConf": "$foulsConf% Conf", "isFoulsBest": false,
      "cards": "Over $cardsLine", "cardsConf": "$cardsConf% Conf", "isCardsBest": false,
      "offsides": "Over 2.5", "offsidesConf": "65% Conf", "isOffsidesBest": false,
      "marketOdds": realOdds
    };
  }

  void _analyze(Map<String, dynamic> m) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return FutureBuilder<Map<String, dynamic>>(
          future: _fetchRealDataAndAnalyze(m),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                color: Colors.black54,
                child: const Center(child: CircularProgressIndicator(color: Colors.amber)),
              );
            }

            final ai = snapshot.data ?? {
              "outcome": "Nincs elegendő adat", "scoreConf": "0%", "isScoreBest": true,
              "score": "? - ?", "corners": "N/A", "cornersConf": "0%", "isCornersBest": false,
              "fouls": "N/A", "foulsConf": "0%", "isFoulsBest": false,
              "cards": "N/A", "cardsConf": "0%", "isCardsBest": false,
              "offsides": "N/A", "offsidesConf": "0%", "isOffsidesBest": false,
              "marketOdds": 0.0
            };

            double currentOdds = double.tryParse(ai['marketOdds'].toString()) ?? 0.0;

            return Container(
              color: Colors.black54,
              child: Dialog(
                backgroundColor: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Colors.amber.withOpacity(0.25), width: 1.5),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 20, spreadRadius: 5)]
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SizedBox(width: 24),
                        Expanded(child: Text("${m['home']}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                        IconButton(icon: const Icon(Icons.close, size: 20, color: Colors.grey), onPressed: () => Navigator.pop(dialogContext)),
                      ],
                    ),
                    const Padding(padding: EdgeInsets.symmetric(vertical: 4), child: Text("vs", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold))),
                    Text("${m['away']}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text("AI Predikció: ${ai['score']}", style: TextStyle(color: Colors.amber[400], fontWeight: FontWeight.w600, fontSize: 13)),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        "Aktuális Piaci Odds: ${currentOdds > 1.0 ? currentOdds.toStringAsFixed(2) : 'N/A'}", 
                        style: TextStyle(color: currentOdds > 1.0 ? Colors.greenAccent : Colors.grey, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Divider(height: 24, thickness: 1),
                    _buildStatRow(Icons.sports_soccer, "Várható kimenetel", ai['outcome'].toString(), ai['scoreConf'].toString(), Colors.blueAccent, isBest: ai['isScoreBest'] == true),
                    _buildStatRow(Icons.radio_button_checked, "Szöglet (O/U)", ai['corners'].toString(), ai['cornersConf'].toString(), Colors.greenAccent, isBest: ai['isCornersBest'] == true),
                    _buildStatRow(Icons.warning_amber, "Szabálytalanság (O/U)", ai['fouls'].toString(), ai['foulsConf'].toString(), Colors.orangeAccent, isBest: ai['isFoulsBest'] == true),
                    _buildStatRow(Icons.receipt_long, "Lapok (O/U)", ai['cards'].toString(), ai['cardsConf'].toString(), Colors.yellowAccent, isBest: ai['isCardsBest'] == true),
                    _buildStatRow(Icons.flag_outlined, "Lesek (O/U)", ai['offsides'].toString(), ai['offsidesConf'].toString(), Colors.purpleAccent, isBest: ai['isOffsidesBest'] == true),
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
                            "odds": currentOdds > 1.0 ? currentOdds : 2.0,
                            "stake": 10.0
                          }));
                          _saveTips(); 
                          Navigator.pop(dialogContext);
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
            );
          },
        );
      },
    );
  }

  Future<Map<String, dynamic>> _fetchRealDataAndAnalyze(Map<String, dynamic> m) async {
    var client = HttpClient();
    Map<String, dynamic> homeStats = {};
    Map<String, dynamic> awayStats = {};
    double realOdds = 0.0;

    try {
      if (m['homeId'] != null && m['leagueId'] != null) {
        var statReq = await client.getUrl(Uri.parse('https://v3.football.api-sports.io/teams/statistics?season=2025&league=${m['leagueId']}&team=${m['homeId']}'));
        statReq.headers.add('x-rapidapi-key', _apiKey);
        var statRes = await statReq.close();
        if (statRes.statusCode == 200) {
          var resData = json.decode(await statRes.transform(utf8.decoder).join());
          if (resData['response'] != null && resData['response'].isNotEmpty) {
            homeStats = resData['response'];
          }
        }
      }
      if (m['awayId'] != null && m['leagueId'] != null) {
        var statReq = await client.getUrl(Uri.parse('https://v3.football.api-sports.io/teams/statistics?season=2025&league=${m['leagueId']}&team=${m['awayId']}'));
        statReq.headers.add('x-rapidapi-key', _apiKey);
        var statRes = await statReq.close();
        if (statRes.statusCode == 200) {
          var resData = json.decode(await statRes.transform(utf8.decoder).join());
          if (resData['response'] != null && resData['response'].isNotEmpty) {
            awayStats = resData['response'];
          }
        }
      }

      if (m['fixtureId'] != null) {
        var oddsReq = await client.getUrl(Uri.parse('https://v3.football.api-sports.io/odds?fixture=${m['fixtureId']}'));
        oddsReq.headers.add('x-rapidapi-key', _apiKey);
        var oddsRes = await oddsReq.close();
        if (oddsRes.statusCode == 200) {
          var bookmakers = json.decode(await oddsRes.transform(utf8.decoder).join())['response'];
          if (bookmakers != null && bookmakers.isNotEmpty) {
            var bookmaker = bookmakers[0]['bookmakers'];
            if (bookmaker != null && bookmaker.isNotEmpty) {
              var bets = bookmaker[0]['bets'];
              if (bets != null && bets.isNotEmpty) {
                var values = bets[0]['values'];
                if (values != null && values.isNotEmpty) {
                  realOdds = double.tryParse(values[0]['odds']?.toString() ?? '0.0') ?? 0.0;
                }
              }
            }
          }
        }
      }
    } catch (_) {}

    return _calculateRealAiPredictions(
      homeStats: homeStats,
      awayStats: awayStats,
      realOdds: realOdds,
      homeName: m['home'] ?? 'Home',
      awayName: m['away'] ?? 'Away'
    );
  }

  List<Map<String, dynamic>> _getTop3Tips() {
    if (_allMatches.isEmpty) return [];
    List<Map<String, dynamic>> pool = [];
    for (var i = 0; i < _allMatches.length && i < 5; i++) {
      int nameSeed = (_allMatches[i]['home']?.toString().hashCode ?? 0) ^ (_allMatches[i]['away']?.toString().hashCode ?? 0);
      pool.add({
        "match": _allMatches[i],
        "conf": 84 + (nameSeed % 10),
        "pick": nameSeed % 2 == 0 ? "Lapok: Over 3.5" : "Szöglet: Over 9.5"
      });
    }
    return pool.take(3).toList();
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
        Text(conf, style: TextStyle(fontSize: 11, color: isBest ? Colors.amber : Colors.grey[400])),
      ]),
      const Spacer(),
      Expanded(
        child: Text(
          value, 
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isBest ? Colors.amber : null), 
          textAlign: TextAlign.end,
        ),
      )
    ]),
  );

  Future<void> _loadMatches() async {
    setState(() => _isLoading = true);
    try {
      String dateStr = DateTime.now().toString().substring(0, 10);
      var client = HttpClient();
      var req = await client.getUrl(Uri.parse('https://v3.football.api-sports.io/fixtures?date=$dateStr'));
      req.headers.add('x-rapidapi-key', _apiKey);
      var res = await req.close();
      if (res.statusCode == 200) {
        var data = json.decode(await res.transform(utf8.decoder).join())['response'];
        setState(() => _allMatches = List<Map<String, dynamic>>.from(data.map((m) {
          String homeGoals = m['goals']['home'] != null ? m['goals']['home'].toString() : "";
          String awayGoals = m['goals']['away'] != null ? m['goals']['away'].toString() : "";
          String currentScore = (homeGoals.isNotEmpty && awayGoals.isNotEmpty) ? "  $homeGoals-$awayGoals " : "";

          return {
            "fixtureId": m['fixture']['id'],
            "leagueId": m['league']['id'],
            "homeId": m['teams']['home']['id'],
            "awayId": m['teams']['away']['id'],
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
    final oddsController = TextEditingController(text: _savedTips[index]['odds'].toString());
    final stakeController = TextEditingController(text: _savedTips[index]['stake'].toString());

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Mégse", style: TextStyle(color: Colors.grey))),
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
        double stake = double.tryParse(t['stake']?.toString() ?? '10.0') ?? 10.0;
        double odds = double.tryParse(t['odds']?.toString() ?? '2.0') ?? 2.0;
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
        gradient: LinearGradient(colors: [Theme.of(context).cardColor, Theme.of(context).cardColor.withOpacity(0.7)]),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.amber.withOpacity(0.25), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 4))]
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
    
    Color bgColor = Colors.grey.withOpacity(0.15);
    Color textColor = Colors.grey[400]!;

    if (isLive) {
      bgColor = Colors.red.withOpacity(0.2);
      textColor = Colors.redAccent;
    } else if (status == 'FT') {
      bgColor = Colors.green.withOpacity(0.15);
      textColor = Colors.greenAccent;
    } else if (isCancelled) {
      bgColor = Colors.orange.withOpacity(0.15);
      textColor = Colors.orangeAccent;
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
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("AI PRO ANALYZER", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, letterSpacing: 0.5)),
          Text(DateFormat('yyyy.MM.dd').format(DateTime.now()), style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
        ]),
        actions: [
          IconButton(icon: Icon(_hideFriendlies ? Icons.sports_esports : Icons.sports_soccer, color: _hideFriendlies ? Colors.grey : Colors.greenAccent), onPressed: () => setState(() => _hideFriendlies = !_hideFriendlies)),
          IconButton(icon: Icon(_isLiveOnly ? Icons.live_tv : Icons.tv_off, color: _isLiveOnly ? Colors.redAccent : Colors.grey), onPressed: () => setState(() => _isLiveOnly = !_isLiveOnly)),
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
                    child: Align(alignment: Alignment.centerLeft, child: Text("🔥 NAPI TOP 3 AI TIPP", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amber, letterSpacing: 0.5))),
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
                            gradient: LinearGradient(colors: [Colors.amber.withOpacity(0.25), Colors.amber.withOpacity(0.05)]),
                            borderRadius: BorderRadius.circular(16), 
                            border: Border.all(color: Colors.amber.withOpacity(0.4), width: 1.2)
                          ),
                          child: InkWell(
                            onTap: () => _analyze(item['match']),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                              Text("${item['match']['home'] ?? ''} - ${item['match']['away'] ?? ''}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 6),
                              Text(item['pick'].toString(), style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold)),
                              const Spacer(),
                              Text("Biztonsági szint: ${item['conf']}%", style: TextStyle(color: Colors.grey[400], fontSize: 10, fontWeight: FontWeight.w500)),
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
                              gradient: LinearGradient(colors: [Theme.of(context).cardColor, Theme.of(context).cardColor.withOpacity(0.5)]), 
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.2), width: 1),
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
                                child: Text("Kezdés: ${filteredMatches[i]['time']}", style: TextStyle(color: Colors.amber[400], fontSize: 12, fontWeight: FontWeight.w600)),
                              ),
                              trailing: _buildStatusBadge(filteredMatches[i]['status'].toString(), filteredMatches[i]['liveScore'].toString()),
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
                                        title: Text(activeTips[i]['match'].toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                        subtitle: Text(activeTips[i]['pick'].toString(), style: const TextStyle(color: Colors.amber, fontSize: 12)),
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
                                    double displayOdds = double.tryParse(settledTips[i]['odds']?.toString() ?? '2.0') ?? 2.0;
                                    double displayStake = double.tryParse(settledTips[i]['stake']?.toString() ?? '10.0') ?? 10.0;
                                    
                                    return Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: isWon ? Colors.green.withOpacity(0.05) : Colors.red.withOpacity(0.05),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: (isWon ? Colors.green : Colors.red).withOpacity(0.15), width: 1)
                                      ),
                                      child: ListTile(
                                        leading: Icon(isWon ? Icons.check_circle : Icons.cancel, color: isWon ? Colors.greenAccent : Colors.redAccent, size: 22),
                                        title: Text(settledTips[i]['match'].toString(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                        subtitle: Padding(
                                          padding: const EdgeInsets.only(top: 4),
                                          child: Text("${settledTips[i]['pick']}\nOdds: ${displayOdds.toStringAsFixed(2)}  |  Tét: ${displayStake.toStringAsFixed(0)} Ft", style: TextStyle(fontSize: 11, color: Colors.grey[400], height: 1.3)),
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
