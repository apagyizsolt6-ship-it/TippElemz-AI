import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const MatchListScreen(),
    );
  }
}

class MatchListScreen extends StatefulWidget {
  const MatchListScreen({super.key});
  @override
  State<MatchListScreen> createState() => _MatchListScreenState();
}

class _MatchListScreenState extends State<MatchListScreen> {
  // Egy egyszerűsített lista a mai meccsekről
  List<dynamic> matches = [
    {"home": "Spanyolország", "away": "Belgium", "time": "21:00", "status": "NEGYEDDÖNTŐ"},
    {"home": "Norvégia", "away": "Anglia", "time": "23:00", "status": "NEGYEDDÖNTŐ"},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("VB 2026 - MENETREND")),
      body: ListView.builder(
        itemCount: matches.length,
        itemBuilder: (context, index) {
          return Card(
            margin: const EdgeInsets.all(10),
            child: ListTile(
              title: Text("${matches[index]['home']} - ${matches[index]['away']}"),
              subtitle: Text("Kezdés: ${matches[index]['time']} | ${matches[index]['status']}"),
            ),
          );
        },
      ),
    );
  }
}
