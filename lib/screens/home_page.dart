import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import 'knowledge_base_page.dart';
import 'settings_page.dart';

class HomePage extends StatefulWidget {
  final Function(bool) onThemeChanged;
  final bool isDarkMode;

  const HomePage({
    Key? key,
    required this.onThemeChanged,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  List<KnowledgeBase> _knowledgeBases = [];

  @override
  void initState() {
    super.initState();
    _loadKnowledgeBases();
  }

  Future<void> _loadKnowledgeBases() async {
    final prefs = await SharedPreferences.getInstance();
    final String? kbJson = prefs.getString('knowledgeBases');
    if (kbJson != null) {
      final List<dynamic> decoded = json.decode(kbJson);
      setState(() {
        _knowledgeBases =
            decoded.map((e) => KnowledgeBase.fromJson(e)).toList();
      });
    } else {
      setState(() {
        _knowledgeBases = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      KnowledgeBasePage(
        knowledgeBases: _knowledgeBases,
        onRefresh: _loadKnowledgeBases,
      ),
      SettingsPage(
        isDarkMode: widget.isDarkMode,
        onThemeChanged: widget.onThemeChanged,
      ),
    ];

    return Scaffold(
      body: pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.school_outlined),
            selectedIcon: Icon(Icons.school),
            label: 'Learn',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
