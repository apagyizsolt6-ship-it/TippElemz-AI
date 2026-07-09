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
        appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, elevation: 0, actionsIconTheme: IconThemeData(color: Colors.black), titleTextStyle: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 20)),
        inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: Colors.black.withOpacity(0.05), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none)),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.amber,
        scaffoldBackgroundColor: const Color(0xFF0A1128),
        cardColor: const Color(0xFF101F42),
        appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, elevation: 0, actionsIconTheme: IconThemeData(color: Colors.white), titleTextStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
        inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: const Color(0xFF1E2E5A).withOpacity(0.6), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none)),
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
  bool _isSaving = false; // Új változó a mentési folyamathoz
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

  // Új mentő függvény
  Future<void> _handleSaveTip(Map<String, dynamic> tip) async {
    setState(() => _isSaving = true);
    _savedTips.add(tip);
    await _saveTips();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Tipp sikeresen elmentve a listára!", textAlign: TextAlign.center), backgroundColor: Colors.green, duration: Duration(seconds: 2)),
      );
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() => _isSaving = false);
          Navigator.pop(context);
        }
      });
    }
  }

  // ... (A függvények többi része marad változatlan)
  // [A kódod többi részét (analyze, fetchRealData, stb.) ide illeszd be változatlanul]
  
  // A gombot a showDialog belsejében cseréld erre:
  /*
    SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        icon: Icon(_isSaving ? Icons.check : Icons.bookmark_add_outlined),
        label: Text(_isSaving ? "Elmentve!" : "Tipp mentése a listára"),
        onPressed: _isSaving ? null : () => _handleSaveTip({
          "match": "${m['home']} - ${m['away']}", 
          "pick": "${ai['outcome']} (${ai['score']})",
          "status": "pending",
          "odds": currentOdds > 1.0 ? currentOdds : 2.0,
          "stake": 10.0
        }),
        style: ElevatedButton.styleFrom(
          backgroundColor: _isSaving ? Colors.green : Colors.amber, 
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    ),
  */

  // ... (A fájl többi része: build metódus, stb.)
}
