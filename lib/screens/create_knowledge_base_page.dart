import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

class CreateKnowledgeBasePage extends StatefulWidget {
  const CreateKnowledgeBasePage({Key? key}) : super(key: key);

  @override
  State<CreateKnowledgeBasePage> createState() =>
      _CreateKnowledgeBasePageState();
}

class _CreateKnowledgeBasePageState extends State<CreateKnowledgeBasePage> {
  final _formKey = GlobalKey<FormState>();
  final _topicController = TextEditingController();
  String _difficulty = 'Beginner';
  bool _isGenerating = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Knowledge Base'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'What do you want to learn?',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _topicController,
              decoration: const InputDecoration(
                labelText: 'Topic',
                hintText: 'e.g., Spring Boot, React, Python',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.topic),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a topic';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            Text(
              'Difficulty Level',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'Beginner', label: Text('Beginner')),
                ButtonSegment(
                    value: 'Intermediate', label: Text('Intermediate')),
                ButtonSegment(value: 'Advanced', label: Text('Advanced')),
              ],
              selected: {_difficulty},
              onSelectionChanged: (Set<String> selection) {
                setState(() {
                  _difficulty = selection.first;
                });
              },
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _isGenerating ? null : _generateQuizCards,
              icon: _isGenerating
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Icon(Icons.auto_awesome),
              label: Text(
                  _isGenerating ? 'Generating...' : 'Generate Quiz Cards'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateQuizCards() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isGenerating = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final apiKey = prefs.getString('geminiApiKey');
      final model = prefs.getString('geminiModel') ?? 'gemini-1.5-flash';

      if (apiKey == null || apiKey.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Please set your Gemini API key in settings')),
        );
        setState(() {
          _isGenerating = false;
        });
        return;
      }
      final prompt = '''
Generate 5 quiz questions about ${_topicController.text} at $_difficulty level.
For each question, provide:
1. A clear question
2. Four multiple choice options (A, B, C, D)
3. The correct answer letter
4. A brief explanation

Format your response as a valid JSON array like this:
[
  {
    "question": "question text",
    "options": ["A. option1", "B. option2", "C. option3", "D. option4"],
    "correct": "A",
    "explanation": "explanation text"
  }
]
''';
      final response = await http.post(
        Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final text = data['candidates'][0]['content']['parts'][0]['text'];

        String jsonText = text;
        if (text.contains('```json')) {
          jsonText = text.split('```json')[1].split('```').first.trim();
        } else if (text.contains('```')) {
          jsonText = text.split('```')[1].split('```').first.trim();
        }

        final List<dynamic> questions = json.decode(jsonText);

        final kb = KnowledgeBase(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          topic: _topicController.text,
          difficulty: _difficulty,
          createdAt: DateTime.now(),
          cards: questions.map((q) {
            final index = questions.indexOf(q);
            return QuizCard(
              id: '${DateTime.now().millisecondsSinceEpoch}_$index',
              question: q['question'],
              correctAnswer: q['correct'],
              options: List<String>.from(q['options']),
              explanation: q['explanation'],
            );
          }).toList(),
        );

        final kbJson = prefs.getString('knowledgeBases');
        List<dynamic> kbList = kbJson != null ? json.decode(kbJson) : [];
        kbList.add(kb.toJson());
        await prefs.setString('knowledgeBases', json.encode(kbList));

        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Generated ${questions.length} quiz cards!')),
        );
      } else {
        throw Exception('Failed to generate questions: ${response.body}');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }
}
