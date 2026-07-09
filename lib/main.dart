import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
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
  List<dynamic> _matches = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMatches();
  }

  Future<void> _fetchMatches() async {
    try {
      final client = HttpClient();
      // A football-data.org nyilvános végpontja a mai meccsekre
      final uri = Uri.parse('https://api.football-data.org/v4/matches');
      final req = await client.getUrl(uri);
      
      // Ide nem kell bonyolult kulcs, ez egy nyitottabb API
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      
      if (res.statusCode == 200) {
        final data = json.decode(body);
        setState(() {
          _matches = data['matches'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Hiba: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("FOCI MECCSEK (STABIL)")),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _matches.length,
              itemBuilder: (context, index) {
                final match = _matches[index];
                return Card(
                  margin: const EdgeInsets.all(8),
                  child: ListTile(
                    title: Text("${match['homeTeam']['name']} - ${match['awayTeam']['name']}"),
                    subtitle: Text("Státusz: ${match['status']}"),
                  ),
                );
              },
            ),
    );
  }
}
