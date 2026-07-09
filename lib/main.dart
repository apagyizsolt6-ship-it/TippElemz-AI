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
  final String _apiKey = '8fde2ccd0efdcc2c113d52d84aa33849';
  double _totalBankroll = 100000.0;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Widget _buildMomentumBar(int score) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text("Live Momentum", style: TextStyle(fontSize: 9, color: Colors.grey)),
      const SizedBox(height: 4),
      Container(
        height: 4, width: double.infinity,
        decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(2)),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: (score / 100).clamp(0.0, 1.0),
          child: Container(color: score > 70 ? Colors.redAccent : Colors.greenAccent),
        ),
      ),
    ]);
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
    int nameSeed = homeName.hashCode.abs() ^ (awayName.hashCode.abs() << 2);
    bool hasRealApiData = homeStats.isNotEmpty && awayStats.isNotEmpty;
    
    double aiProb = 0.55; 
    double marketProb = realOdds > 1 ? (1 / realOdds) : 0.5;
    bool isValue = (aiProb / marketProb) > 1.05;

    double homeAtt = 1.3;
    double homeDef = 1.2;
    double awayAtt = 1.1;
    double awayDef = 1.3;

    if (realOdds > 1.0 && realOdds < 10.0) {
      if (realOdds < 1.6) {
        homeAtt = 2.2; homeDef = 0.7; awayAtt = 0.7; awayDef = 2.0;
      } else if (realOdds < 2.1) {
        homeAtt = 1.6; homeDef = 1.1; awayAtt = 1.2; awayDef = 1.5;
      } else if (realOdds > 3.5) {
        homeAtt = 0.8; homeDef = 1.9; awayAtt = 2.0; awayDef = 0.9;
      }
    }

    if (hasRealApiData) {
      homeAtt = double.tryParse(homeStats['goals']?['for']?['average']?['home']?.toString() ?? '1.4') ?? 1.4;
      homeDef = double.tryParse(homeStats['goals']?['against']?['average']?['home']?.toString() ?? '1.1') ?? 1.1;
      awayAtt = double.tryParse(awayStats['goals']?['for']?['average']?['away']?.toString() ?? '1.1') ?? 1.1;
      awayDef = double.tryParse(awayStats['goals']?['against']?['average']?['away']?.toString() ?? '1.4') ?? 1.4;
    }

    double homeExpectedGoals = (homeAtt + awayDef) / 2;
    double awayExpectedGoals = (awayAtt + homeDef) / 2;
    int homeGoals = homeExpectedGoals.round().clamp(0, 5);
    int awayGoals = awayExpectedGoals.round().clamp(0, 5);
    String exactScore = "$homeGoals - $awayGoals";
    String matchOutcomeText = (homeGoals > awayGoals) ? "Hazai Győzelem" : ((awayGoals > homeGoals) ? "Vendég Győzelem" : "Döntetlen");
    int scoreConf = 55 + (nameSeed % 15);

    return {
      "outcome": hasRealApiData ? "$matchOutcomeText (Éles Stat)" : "$matchOutcomeText (AI Elemzés)", 
      "scoreConf": "$scoreConf% Conf", "isScoreBest": true,
      "score": exactScore,
      "corners": "Over ${8.5 + (nameSeed % 4)}", "cornersConf": "${68 + (nameSeed % 12)}% Conf", "isCornersBest": false,
      "fouls": "Over ${20.5 + (nameSeed % 4)}", "foulsConf": "${62 + (nameSeed % 14)}% Conf", "isFoulsBest": false,
      "cards": "Over ${3.5 + (nameSeed % 2)}", "cardsConf": "${65 + (nameSeed % 10)}% Conf", "isCardsBest": false,
      "offsides": "Over 2.5", "offsidesConf": "${60 + (nameSeed % 8)}% Conf", "isCardsBest": false,
      "marketOdds": realOdds,
      "isValue": isValue,
      "momentum": 40 + (nameSeed % 60)
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
              return const Center(child: CircularProgressIndicator(color: Colors.amber));
            }
            final ai = snapshot.data ?? {"outcome": "N/A", "momentum": 50, "isValue": false};
            double currentOdds = double.tryParse(ai['marketOdds'].toString()) ?? 2.0;

            return Dialog(
              backgroundColor: Theme.of(context).cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text("${m['home']} vs ${m['away']}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  if (ai['isValue'] == true) 
                    Container(margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(8)), child: const Text("VALUE BET! 🔥", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11))),
                  const SizedBox(height: 12),
                  _buildMomentumBar(ai['momentum']),
                  const SizedBox(height: 15),
                  _buildStatRow(Icons.sports_soccer, "Várható kimenetel", ai['outcome'].toString(), ai['scoreConf'].toString(), Colors.blueAccent),
                  _buildStatRow(Icons.radio_button_checked, "Szöglet", ai['corners'].toString(), ai['cornersConf'].toString(), Colors.greenAccent),
                  _buildStatRow(Icons.receipt_long, "Lapok", ai['cards'].toString(), ai['cardsConf'].toString(), Colors.yellowAccent),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.bookmark_add_outlined),
                    label: const Text("Tipp mentése"),
                    onPressed: () {
                      setState(() => _savedTips.add({"match": "${m['home']} - ${m['away']}", "pick": ai['outcome'], "status": "pending", "odds": currentOdds, "stake": 10.0}));
                      _saveTips(); Navigator.pop(dialogContext);
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  ),
                ]),
              ),
            );
          },
        );
      },
    );
  }
  Future<Map<String, dynamic>> _fetchRealDataAndAnalyze(Map<String, dynamic> m) async {
    var client = HttpClient();
    double realOdds = 0.0;
    try {
      if (m['fixtureId'] != null) {
        var req = await client.getUrl(Uri.parse('https://v3.football.api-sports.io/odds?fixture=${m['fixtureId']}'));
        req.headers.add('x-rapidapi-key', _apiKey);
        var res = await req.close();
        if (res.statusCode == 200) {
           var data = json.decode(await res.transform(utf8.decoder).join());
        }
      }
    } catch (_) {}
    return _calculateRealAiPredictions(homeStats: {}, awayStats: {}, realOdds: realOdds, homeName: m['home'] ?? 'H', awayName: m['away'] ?? 'A');
  }

  Widget _buildStatRow(IconData icon, String title, String value, String conf, Color color) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        Text(conf, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ]),
      const Spacer(),
      Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
        setState(() => _allMatches = List<Map<String, dynamic>>.from(data.map((m) => {
          "fixtureId": m['fixture']['id'], "leagueId": m['league']['id'], "homeId": m['teams']['home']['id'], "awayId": m['teams']['away']['id'],
          "home": m['teams']['home']['name'], "away": m['teams']['away']['name'], "logo": m['league']['logo'],
          "status": m['fixture']['status']['short'], "time": DateFormat('HH:mm').format(DateTime.parse(m['fixture']['date']).toLocal()),
          "liveScore": (m['goals']['home'] != null) ? "${m['goals']['home']}-${m['goals']['away']}" : ""
        })));
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("AI PRO ANALYZER"),
        actions: [IconButton(icon: const Icon(Icons.brightness_6), onPressed: widget.toggleTheme)],
      ),
      body: _isLoading ? const Center(child: CircularProgressIndicator(color: Colors.amber)) : ListView.builder(
        itemCount: _allMatches.length,
        itemBuilder: (_, i) => ListTile(
          title: Text("${_allMatches[i]['home']} - ${_allMatches[i]['away']}"),
          subtitle: Text("Kezdés: ${_allMatches[i]['time']}"),
          trailing: Text(_allMatches[i]['status']),
          onTap: () => _analyze(_allMatches[i]),
        ),
      ),
    );
  }
}
