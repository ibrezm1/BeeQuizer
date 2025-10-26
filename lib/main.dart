// pubspec.yaml dependencies needed:
// dependencies:
//   flutter:
//     sdk: flutter
//   http: ^1.1.0
//   shared_preferences: ^2.2.2
//   flutter_markdown: ^0.6.18

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_markdown/flutter_markdown.dart';

void main() {
  runApp(const QuizApp());
}

class QuizApp extends StatefulWidget {
  const QuizApp({Key? key}) : super(key: key);

  @override
  State<QuizApp> createState() => _QuizAppState();
}

class _QuizAppState extends State<QuizApp> {
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('darkMode') ?? false;
    });
  }

  void _toggleTheme(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', value);
    setState(() {
      _isDarkMode = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quiz Master',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
      ),
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: HomePage(onThemeChanged: _toggleTheme, isDarkMode: _isDarkMode),
    );
  }
}

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
      if (mounted) {
        setState(() {
          _knowledgeBases =
              decoded.map((e) => KnowledgeBase.fromJson(e)).toList();
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _knowledgeBases = [];
        });
      }
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
        onDataCleared: _loadKnowledgeBases,
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

class KnowledgeBase {
  final String id;
  final String topic;
  final String difficulty;
  final DateTime createdAt;
  List<QuizCard> cards;

  KnowledgeBase({
    required this.id,
    required this.topic,
    required this.difficulty,
    required this.createdAt,
    this.cards = const [],
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'topic': topic,
    'difficulty': difficulty,
    'createdAt': createdAt.toIso8601String(),
    'cards': cards.map((c) => c.toJson()).toList(),
  };

  factory KnowledgeBase.fromJson(Map<String, dynamic> json) => KnowledgeBase(
    id: json['id'],
    topic: json['topic'],
    difficulty: json['difficulty'],
    createdAt: DateTime.parse(json['createdAt']),
    cards: (json['cards'] as List?)
        ?.map((c) => QuizCard.fromJson(c))
        .toList() ??
        [],
  );
}

class QuizCard {
  final String id;
  final String question;
  final String correctAnswer;
  final List<String> options;
  final String explanation;
  DateTime nextReview;
  int easeFactor; // Stored as a percentage, e.g., 250 for 2.5
  int interval; // In days
  int repetitions;

  QuizCard({
    required this.id,
    required this.question,
    required this.correctAnswer,
    required this.options,
    required this.explanation,
    DateTime? nextReview,
    this.easeFactor = 250,
    this.interval = 0,
    this.repetitions = 0,
  }) : nextReview = nextReview ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'question': question,
    'correctAnswer': correctAnswer,
    'options': options,
    'explanation': explanation,
    'nextReview': nextReview.toIso8601String(),
    'easeFactor': easeFactor,
    'interval': interval,
    'repetitions': repetitions,
  };

  factory QuizCard.fromJson(Map<String, dynamic> json) => QuizCard(
    id: json['id'],
    question: json['question'],
    correctAnswer: json['correctAnswer'],
    options: List<String>.from(json['options']),
    explanation: json['explanation'],
    nextReview: DateTime.parse(json['nextReview']),
    easeFactor: json['easeFactor'],
    interval: json['interval'],
    repetitions: json['repetitions'],
  );

  // CORRECTED: This method implements a more effective spaced repetition algorithm.
  void updateSpacedRepetition(int quality) {
    // Quality ratings: 3 (Hard), 4 (Good), 5 (Easy)
    if (quality < 4) {
      // If the answer is "Hard" or incorrect, reset repetitions.
      repetitions = 0;
      interval = 1;
    } else {
      // If the answer is "Good" or "Easy", calculate next interval.
      repetitions++;
      if (repetitions == 1) {
        interval = 1;
      } else if (repetitions == 2) {
        interval = 6;
      } else {
        interval = (interval * easeFactor / 100).round();
      }

      // Update ease factor based on performance.
      // "Hard" (3) reduces ease, "Good" (4) keeps it stable, "Easy" (5) increases it.
      // This prevents the interval from growing too quickly for difficult cards.
      easeFactor = easeFactor + (quality - 4) * 10;
      if (easeFactor < 130) {
        // Minimum ease factor of 130%
        easeFactor = 130;
      }
    }
    nextReview = DateTime.now().add(Duration(days: interval));
  }
}

class KnowledgeBasePage extends StatelessWidget {
  final List<KnowledgeBase> knowledgeBases;
  final VoidCallback onRefresh;

  const KnowledgeBasePage({
    Key? key,
    required this.knowledgeBases,
    required this.onRefresh,
  }) : super(key: key);

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
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withOpacity(0.5),
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
          return Card(
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

      final response = await http.post(
        Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'contents': [
            {
              'parts': [
                {
                  'text':
                  '''Generate 5 quiz questions about ${_topicController.text} at $_difficulty level.
For each question, provide:
1. A clear question
2. Four multiple choice options (A, B, C, D)
3. The correct answer letter
4. A brief explanation for the correct answer

Format your response as a valid JSON array only, with no other text or markdown formatting:
[
  {
    "question": "question text",
    "options": ["A. option1", "B. option2", "C. option3", "D. option4"],
    "correct": "A",
    "explanation": "explanation text"
  }
]'''
                }
              ]
            }
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final text = data['candidates'][0]['content']['parts'][0]['text'];

        String jsonText = text.trim();
        if (jsonText.startsWith('```json')) {
          jsonText = jsonText.substring(7, jsonText.length - 3).trim();
        } else if (jsonText.startsWith('```')) {
          jsonText = jsonText.substring(3, jsonText.length - 3).trim();
        }

        final List<dynamic> questions = json.decode(jsonText);
        final newKbId = DateTime.now().millisecondsSinceEpoch.toString();

        final kb = KnowledgeBase(
          id: newKbId,
          topic: _topicController.text,
          difficulty: _difficulty,
          createdAt: DateTime.now(),
          cards: questions.map((q) {
            final cardIndex = questions.indexOf(q);
            return QuizCard(
              // IMPROVED: Guarantees unique ID by using the parent KB ID as a prefix.
              id: '${newKbId}_$cardIndex',
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
    _dueCards = widget.knowledgeBase.cards
        .where((c) => c.nextReview.isBefore(DateTime.now()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_dueCards.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.knowledgeBase.topic)),
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
            value: (_currentIndex + 1) / _dueCards.length,
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
                    child: Text(
                      card.question,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ...card.options.map((option) {
                  final isSelected = _selectedAnswer == option[0];
                  final isCorrect = option[0] == card.correctAnswer;

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
                            _selectedAnswer = option[0];
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Radio<String>(
                                value: option[0],
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
                                child: Text(
                                  option,
                                  style: Theme.of(context).textTheme.bodyLarge,
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
                    color: Theme.of(context).colorScheme.primaryContainer,
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
                          Text(
                            card.explanation,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: _showAnswer
                ? Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _rateCard(3), // Hard
                    child: const Text('Hard'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => _rateCard(4), // Good
                    child: const Text('Good'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: () => _rateCard(5), // Easy
                    child: const Text('Easy'),
                  ),
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
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quiz completed!')),
      );
    }
  }
}

class ChatPage extends StatefulWidget {
  final QuizCard card;
  final String topic;

  const ChatPage({Key? key, required this.card, required this.topic})
      : super(key: key);

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _messages.add(ChatMessage(
      text: 'I can help you understand this question better. Ask me anything or tap a suggestion below!',
      isUser: false,
    ));
  }

  final List<String> _quickPrompts = [
    'Explain this like I\'m 12',
    'What are real-world examples?',
    'How does this impact development?',
    'What are common mistakes?',
    'Give me a code example',
    'Why is this important?',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat about this card'),
      ),
      body: Column(
        children: [
          if (_messages.length == 1)
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _quickPrompts.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      label: Text(_quickPrompts[index]),
                      onPressed: () {
                        _controller.text = _quickPrompts[index];
                        _sendMessage();
                      },
                    ),
                  );
                },
              ),
            ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return Align(
                  alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    decoration: BoxDecoration(
                      color: msg.isUser
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: MarkdownBody(
                      data: msg.text,
                      styleSheet: MarkdownStyleSheet(
                        p: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Ask a question...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _sendMessage,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage() async {
    if (_controller.text.trim().isEmpty) return;

    final userMessage = _controller.text.trim();
    _controller.clear();

    setState(() {
      _messages.add(ChatMessage(text: userMessage, isUser: true));
      _isLoading = true;
    });

    _scrollToBottom();

    try {
      final prefs = await SharedPreferences.getInstance();
      final apiKey = prefs.getString('geminiApiKey');
      final model = prefs.getString('geminiModel') ?? 'gemini-1.5-flash';

      if (apiKey == null) {
        throw Exception('API key not set');
      }

      final response = await http.post(
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'contents': [
            {
              'parts': [
                {
                  'text': '''Context: This is a quiz about ${widget.topic}.
Question: ${widget.card.question}
Correct Answer: ${widget.card.correctAnswer}
Explanation: ${widget.card.explanation}

User's question: $userMessage

Please provide a helpful and concise answer to help the user understand this concept better.'''
                }
              ]
            }
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final text = data['candidates'][0]['content']['parts'][0]['text'];
        setState(() {
          _messages.add(ChatMessage(text: text, isUser: false));
        });
        _scrollToBottom();
      }
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          text: 'Sorry, I encountered an error: ${e.toString()}',
          isUser: false,
        ));
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class ChatMessage {
  final String text;
  final bool isUser;

  ChatMessage({required this.text, required this.isUser});
}

class SettingsPage extends StatefulWidget {
  final bool isDarkMode;
  final Function(bool) onThemeChanged;
  final VoidCallback onDataCleared;

  const SettingsPage({
    Key? key,
    required this.isDarkMode,
    required this.onThemeChanged,
    required this.onDataCleared,
  }) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _apiKeyController = TextEditingController();
  String _selectedModel = 'gemini-2.5-flash-lite';
  bool _obscureApiKey = true;

  final List<String> _availableModels = [
    'gemini-1.5-flash',
    'gemini-2.5-flash',
    'gemini-2.0-pro',
    'gemini-2.5-flash-lite',
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _apiKeyController.text = prefs.getString('geminiApiKey') ?? '';
      _selectedModel = prefs.getString('geminiModel') ?? 'gemini-1.5-flash';
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('geminiApiKey', _apiKeyController.text);
    await prefs.setString('geminiModel', _selectedModel);

    if (!mounted) return;
    FocusScope.of(context).unfocus(); // Dismiss keyboard
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings saved successfully')),
    );
  }

  Future<void> _clearAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data?'),
        content: const Text(
          'This will delete all your knowledge bases and quiz cards. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('knowledgeBases');
      widget.onDataCleared(); // <-- ADDED: Refresh the other page
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All data has been cleared')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          ListTile(
            title: Text(
              'Gemini API Configuration',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _apiKeyController,
                    obscureText: _obscureApiKey,
                    decoration: InputDecoration(
                      labelText: 'API Key',
                      hintText: 'Enter your Gemini API key',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureApiKey
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureApiKey = !_obscureApiKey;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedModel,
                    decoration: const InputDecoration(
                      labelText: 'Model',
                      border: OutlineInputBorder(),
                    ),
                    items: _availableModels.map((model) {
                      return DropdownMenuItem(
                        value: model,
                        child: Text(model),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedModel = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _saveSettings,
                    icon: const Icon(Icons.save),
                    label: const Text('Save API Settings'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Get an API key from Google AI Studio'),
                          duration: Duration(seconds: 5),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Get your free API key from Google AI Studio',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          ListTile(
            title: Text(
              'Appearance',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SwitchListTile(
              title: const Text('Dark Mode'),
              value: widget.isDarkMode,
              onChanged: widget.onThemeChanged,
              secondary: Icon(
                widget.isDarkMode ? Icons.dark_mode : Icons.light_mode,
              ),
            ),
          ),
          ListTile(
            title: Text(
              'Data Management',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: Icon(Icons.delete_forever,
                  color: Theme.of(context).colorScheme.error),
              title: const Text('Clear All Data'),
              subtitle:
              const Text('Delete all knowledge bases and quiz cards'),
              onTap: _clearAllData,
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  'Quiz Master',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Version 1.0.0',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'AI-powered quiz generation with spaced repetition',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }
}