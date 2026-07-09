import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
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
  List<Map<String, dynamic>> _matches = [];
  bool _isLoading = true;
  String _errorMessage = "";
  final String _apiKey = '56760560446768218fd8a38865651edd';

  @override
  void initState() {
    super.initState();
    _loadMatches();
  }

  Future<void> _loadMatches() async {
    setState(() {
      _isLoading = true;
      _errorMessage = "";
    });

    try {
      final client = HttpClient();
      final dateStr = DateTime.now().toString().substring(0, 10);
      
      // Hozzáadva az időzóna paraméter, hogy biztosan a mai magyar meccseket hozza
      final uri = Uri.parse('https://v3.football.api-sports.io/fixtures?date=$dateStr&timezone=Europe/Budapest');
      
      final req = await client.getUrl(uri);
      
      req.headers.set('x-rapidapi-key', _apiKey);
      req.headers.set('User-Agent', 'Mozilla/5.0');
      
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      
      if (res.statusCode == 200) {
        final decoded = json.decode(body);
        final List<dynamic> data = decoded['response'] ?? [];
        
        if (data.isEmpty) {
          setState(() => _errorMessage = "Nincs mára kiírt meccs az API-ban.");
        } else {
          setState(() {
            _matches = data.map((m) => {
              "home": m['teams']?['home']?['name'] ?? "Ismeretlen",
              "away": m['teams']?['away']?['name'] ?? "Ismeretlen",
              "status": m['fixture']?['status']?['short'] ?? "-",
              "time": m['fixture']?['date'] != null 
                  ? DateFormat('HH:mm').format(DateTime.parse(m['fixture']['date']).toLocal()) 
                  : "--:--",
              "homeGoals": m['goals']?['home']?.toString() ?? "",
              "awayGoals": m['goals']?['away']?.toString() ?? "",
            }).toList().cast<Map<String, dynamic>>();
          });
        }
      } else {
        setState(() => _errorMessage = "API Hiba!\nKód: ${res.statusCode}\nVálasz: $body");
      }
    } catch (e) {
      setState(() => _errorMessage = "Hálózati Hiba Történt!\n$e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("AI PRO - ALAP TESZT"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMatches,
          ),
          IconButton(
            icon: const Icon(Icons.brightness_6),
            onPressed: widget.toggleTheme,
          ),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text(
                      _errorMessage, 
                      style: const TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: _matches.length,
                  itemBuilder: (context, index) {
                    final match = _matches[index];
                    
                    // Score megjelenítése ha már megy a meccs vagy vége
                    bool hasScore = match['homeGoals'].toString().isNotEmpty && match['awayGoals'].toString().isNotEmpty;
                    String scoreText = hasScore ? " ${match['homeGoals']} - ${match['awayGoals']} " : "";
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        title: Text("${match['home']} - ${match['away']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("Kezdés: ${match['time']}$scoreText"),
                        trailing: Text(match['status'], style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                      ),
                    );
                  },
                ),
    );
  }
}
