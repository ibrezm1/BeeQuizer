import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../models/models.dart';
import 'create_knowledge_base_page.dart';
import 'quiz_page.dart';

class KnowledgeBasePage extends StatelessWidget {
  final List<KnowledgeBase> knowledgeBases;
  final VoidCallback onRefresh;

  const KnowledgeBasePage({
    Key? key,
    required this.knowledgeBases,
    required this.onRefresh,
  }) : super(key: key);

  Future<void> _deleteKnowledgeBase(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final String? kbJson = prefs.getString('knowledgeBases');
    if (kbJson != null) {
      final List<dynamic> decoded = json.decode(kbJson);
      decoded.removeWhere((kb) => kb['id'] == id);
      await prefs.setString('knowledgeBases', json.encode(decoded));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz Master'),
        centerTitle: true,
      ),
      body: knowledgeBases.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.school_outlined,
                    size: 80,
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.5),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'No Knowledge Bases Yet',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create your first knowledge base to start learning',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: knowledgeBases.length,
              itemBuilder: (context, index) {
                final kb = knowledgeBases[index];
                final dueCards = kb.cards
                    .where((c) => c.nextReview.isBefore(DateTime.now()))
                    .length;
                return Dismissible(
                  key: Key(kb.id),
                  onDismissed: (direction) async {
                    await _deleteKnowledgeBase(kb.id);
                    onRefresh();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${kb.topic} deleted')),
                    );
                  },
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20.0),
                    child: const Icon(
                      Icons.delete,
                      color: Colors.white,
                    ),
                  ),
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(kb.topic[0].toUpperCase()),
                      ),
                      title: Text(kb.topic),
                      subtitle: Text(
                        '${kb.difficulty} • ${kb.cards.length} cards • $dueCards due',
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => QuizPage(knowledgeBase: kb),
                          ),
                        );
                        onRefresh();
                      },
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const CreateKnowledgeBasePage()),
          );
          onRefresh();
        },
        icon: const Icon(Icons.add),
        label: const Text('New Topic'),
      ),
    );
  }
}
