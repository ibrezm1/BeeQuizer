import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

class GenerateMoreCardsDialog extends StatefulWidget {
  final KnowledgeBase knowledgeBase;
  final VoidCallback onGenerated;

  const GenerateMoreCardsDialog({
    Key? key,
    required this.knowledgeBase,
    required this.onGenerated,
  }) : super(key: key);

  @override
  State<GenerateMoreCardsDialog> createState() =>
      _GenerateMoreCardsDialogState();
}

class _GenerateMoreCardsDialogState extends State<GenerateMoreCardsDialog> {
  int _numberOfCards = 5;
  bool _isGenerating = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Generate More Cards'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How many new cards would you like to generate?',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _numberOfCards.toDouble(),
                  min: 1,
                  max: 10,
                  divisions: 9,
                  label: _numberOfCards.toString(),
                  onChanged: _isGenerating
                      ? null
                      : (value) {
                    setState(() {
                      _numberOfCards = value.round();
                    });
                  },
                ),
              ),
              SizedBox(
                width: 40,
                child: Text(
                  '$_numberOfCards',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isGenerating ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _isGenerating ? null : _generateCards,
          icon: _isGenerating
              ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : const Icon(Icons.auto_awesome),
          label: Text(_isGenerating ? 'Generating...' : 'Generate'),
        ),
      ],
    );
  }

  Future<void> _generateCards() async {
    setState(() {
      _isGenerating = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final apiKey = prefs.getString('geminiApiKey');
      final model = prefs.getString('geminiModel') ?? 'gemini-1.5-flash';

      if (apiKey == null || apiKey.isEmpty) {
        throw Exception('API key not set');
      }

      final existingQuestions =
      widget.knowledgeBase.cards.map((c) => c.question).join('\n- ');

      final contextPrompt = '''
You are a smart quiz generation assistant.
The user wants to learn about "${widget.knowledgeBase.topic}" at a "${widget.knowledgeBase.difficulty}" level.
They have already seen the following questions:
- $existingQuestions

Generate $_numberOfCards NEW and DISTINCT quiz questions based on the topic. Do not repeat the existing questions.
For each question, provide:
1. A clear question
2. Four multiple choice options (A, B, C, D)
3. The correct answer letter
4. A brief explanation

Format your response as a valid JSON array like this:
[
  {
    "question": "new question text",
    "options": ["A. option1", "B. option2", "C. option3", "D. option4"],
    "correct": "B",
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
                {'text': contextPrompt}
              ]
            }
          ],
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

        final newCards = questions.map((q) {
          final index = questions.indexOf(q);
          return QuizCard(
            id: '${DateTime.now().millisecondsSinceEpoch}_${index}_new',
            question: q['question'],
            correctAnswer: q['correct'],
            options: List<String>.from(q['options']),
            explanation: q['explanation'],
          );
        }).toList();

        widget.knowledgeBase.cards.addAll(newCards);

        final kbJson = prefs.getString('knowledgeBases');
        if (kbJson != null) {
          List<dynamic> kbList = json.decode(kbJson);
          final index =
          kbList.indexWhere((kb) => kb['id'] == widget.knowledgeBase.id);
          if (index != -1) {
            kbList[index] = widget.knowledgeBase.toJson();
            await prefs.setString('knowledgeBases', json.encode(kbList));
          }
        }

        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Generated ${newCards.length} new cards!')),
        );
        widget.onGenerated();
      } else {
        throw Exception('Failed to generate questions: ${response.body}');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
      Navigator.pop(context);
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }
}
