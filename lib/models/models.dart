
import 'dart:convert';

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
  int easeFactor;
  int interval;
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

  void updateSpacedRepetition(int quality) {
    if (quality < 3) {
      repetitions = 0;
      interval = 1;
    } else {
      if (repetitions == 0) {
        interval = 1;
      } else if (repetitions == 1) {
        interval = 6;
      } else {
        interval = (interval * easeFactor / 100).round();
      }
      repetitions++;
      easeFactor = (easeFactor + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02)) * 100).round();
      if (easeFactor < 130) easeFactor = 130;
    }
    nextReview = DateTime.now().add(Duration(days: interval));
  }
}

class ChatMessage {
  final String text;
  final bool isUser;

  ChatMessage({required this.text, required this.isUser});
}
