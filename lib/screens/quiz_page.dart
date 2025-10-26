import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import 'chat_page.dart';
import 'generate_more_cards_dialog.dart';

class QuizPage extends StatefulWidget {
  final KnowledgeBase knowledgeBase;

  const QuizPage({Key? key, required this.knowledgeBase}) : super(key: key);

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  int _currentIndex = 0;
  String? _selectedAnswer;
  bool _showAnswer = false;
  late List<QuizCard> _dueCards;

  @override
  void initState() {
    super.initState();
    _dueCards = _getDueCards();
  }

  List<QuizCard> _getDueCards() {
    return widget.knowledgeBase.cards
        .where((c) => c.nextReview.isBefore(DateTime.now()))
        .toList();
  }

  void _refreshDueCards() {
    setState(() {
      _dueCards = _getDueCards();
      _currentIndex = 0;
      _selectedAnswer = null;
      _showAnswer = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_dueCards.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.knowledgeBase.topic),
          actions: [
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () => _showGenerateMoreDialog(),
            ),
          ],
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'All Caught Up!',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text('No cards due for review right now.'),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => _showGenerateMoreDialog(),
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Generate More Cards'),
              ),
            ],
          ),
        ),
      );
    }

    final card = _dueCards[_currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.knowledgeBase.topic),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => _showGenerateMoreDialog(),
          ),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatPage(
                    card: card,
                    topic: widget.knowledgeBase.topic,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: (_currentIndex) / _dueCards.length,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'Question ${_currentIndex + 1} of ${_dueCards.length}',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    // Use a Container with BoxConstraints for a flexible height.
                    child: Container(
                      constraints: const BoxConstraints(
                        maxHeight: 400, // Set your maximum desired height here.
                      ),
                      child: SingleChildScrollView(
                        child: MarkdownBody(
                          data: card.question,
                          styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ...card.options.map((option) {
                  final optionLetter = option.substring(0, 1);
                  final isSelected = _selectedAnswer == optionLetter;
                  final isCorrect = optionLetter == card.correctAnswer;

                  Color? cardColor;
                  if (_showAnswer) {
                    if (isCorrect) {
                      cardColor = Colors.green.withOpacity(0.2);
                    } else if (isSelected) {
                      cardColor = Colors.red.withOpacity(0.2);
                    }
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      color: cardColor,
                      child: InkWell(
                        onTap: _showAnswer
                            ? null
                            : () {
                          setState(() {
                            _selectedAnswer = optionLetter;
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Radio<String>(
                                value: optionLetter,
                                groupValue: _selectedAnswer,
                                onChanged: _showAnswer
                                    ? null
                                    : (value) {
                                  setState(() {
                                    _selectedAnswer = value;
                                  });
                                },
                              ),
                              Expanded(
                                child: MarkdownBody(
                                  data: option,
                                  styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                                    // Apply the same text style that you had on the Text widget
                                    p: Theme.of(context).textTheme.bodyLarge,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                if (_showAnswer) ...[
                  const SizedBox(height: 24),
                  Card(
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _selectedAnswer == card.correctAnswer
                                    ? Icons.check_circle
                                    : Icons.cancel,
                                color: _selectedAnswer == card.correctAnswer
                                    ? Colors.green
                                    : Colors.red,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _selectedAnswer == card.correctAnswer
                                    ? 'Correct!'
                                    : 'Incorrect',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          MarkdownBody(data: card.explanation),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: _showAnswer
                ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text("How well did you know this?",
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _rateCard(1),
                        child: const Text('Again'),
                        style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => _rateCard(3),
                        child: const Text('Good'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.tonal(
                        onPressed: () => _rateCard(5),
                        child: const Text('Easy'),
                      ),
                    ),
                  ],
                ),
              ],
            )
                : FilledButton(
              onPressed: _selectedAnswer == null
                  ? null
                  : () {
                setState(() {
                  _showAnswer = true;
                });
              },
              child: const Text('Check Answer'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _rateCard(int quality) async {
    final card = _dueCards[_currentIndex];
    card.updateSpacedRepetition(quality);

    final prefs = await SharedPreferences.getInstance();
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

    if (_currentIndex < _dueCards.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedAnswer = null;
        _showAnswer = false;
      });
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quiz completed!')),
      );
      Navigator.pop(context);
    }
  }

  void _showGenerateMoreDialog() {
    showDialog(
      context: context,
      builder: (context) => GenerateMoreCardsDialog(
        knowledgeBase: widget.knowledgeBase,
        onGenerated: _refreshDueCards,
      ),
    );
  }
}
