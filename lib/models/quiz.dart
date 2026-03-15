class QuizQuestion {
  final String question;
  final List<String> options; // A/B/C/D
  final int correctIndex;

  const QuizQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
  });
}

class LectureQuiz {
  final String lectureId;
  final List<QuizQuestion> mcqs;
  final List<Map<String, String>> shortAnswers; // {"q": "...", "a": "..."}

  const LectureQuiz({
    required this.lectureId,
    required this.mcqs,
    required this.shortAnswers,
  });
}
