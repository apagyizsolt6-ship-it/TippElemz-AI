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
  
  late List<DateTime> _nextDays;
  int _selectedDateIndex = 0;

  @override
  void initState() {
    super.initState();
    _nextDays = List.generate(6, (index) => DateTime.now().add(Duration(days: index)));
    _loadMatches();
  }

  Future<void> _loadMatches() async {
    setState(() {
      _isLoading = true;
      _errorMessage = "";
    });

    try {
      final client = HttpClient();
      
      // A valódi, pontos dátum lekérése!
      final dateStr = _nextDays[_selectedDateIndex].toString().substring(0, 10);
      final uri = Uri.parse('https://v3.football.api-sports.io/fixtures?date=$dateStr&timezone=Europe/Budapest');
      
      final req = await client.getUrl(uri);
      req.headers.set('x-rapidapi-key', _apiKey);
      req.headers.set('User-Agent', 'Mozilla/5.0');
      
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      
      if (res.statusCode == 200) {
        final decoded = json.decode(body);
        
        // LIMIT ELLENŐRZÉS: Ha az ingyenes napi limit (100) elfogyott.
        final errors = decoded['errors'];
        if (errors != null && errors is Map && errors.isNotEmpty) {
          setState(() => _errorMessage = "API KORLÁTOZÁS:\n${errors.values.join('\n')}");
          return;
        }

        final List<dynamic> data = decoded['response'] ?? [];
        
        if (data.isEmpty) {
          setState(() => _errorMessage = "Erre a napra ($dateStr) nincs meccs az adatbázisban.");
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
              "league": m['league']?['name'] ?? "",
            }).toList().cast<Map<String, dynamic>>();
          });
        }
      } else {
        setState(() => _errorMessage = "Szerver Hiba!\nKód: ${res.statusCode}");
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
        title: const Text("AI PRO - NAPTÁR"),
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
      body: Column(
        children: [
          Container(
            height: 65,
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _nextDays.length,
              itemBuilder: (context, index) {
                final date = _nextDays[index];
                final isSelected = index == _selectedDateIndex;
                
                final displayDate = DateFormat('MM. dd.').format(date);
                final dayName = DateFormat('E').format(date); 
                
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDateIndex = index;
                    });
                    _loadMatches();
                  },
                  child: Container(
                    width: 75,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.amber : Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isSelected ? Colors.amber : Colors.grey.withOpacity(0.3)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          index == 0 ? "MA" : (index == 1 ? "HOLNAP" : dayName.toUpperCase()),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                            color: isSelected ? Colors.black : Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          displayDate,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: isSelected ? Colors.black : (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          
          Expanded(
            child: _isLoading 
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
                          
                          bool hasScore = match['homeGoals'].toString().isNotEmpty && match['awayGoals'].toString().isNotEmpty;
                          String scoreText = hasScore ? "  ${match['homeGoals']} - ${match['awayGoals']} " : "";
                          
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    match['league'], 
                                    style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          "${match['home']} - ${match['away']}", 
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(8)
                                        ),
                                        child: Text(
                                          match['status'], 
                                          style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12)
                                        ),
                                      )
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    "Kezdés: ${match['time']}$scoreText",
                                    style: TextStyle(color: Colors.grey[400], fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
