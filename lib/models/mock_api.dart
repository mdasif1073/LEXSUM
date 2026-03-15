import 'dart:async';
import '../models/subject.dart';
import '../models/lecture.dart';
import '../models/quiz.dart';

class MockApi {
  final List<Subject> _subjects = [
  const Subject(id: "sub1", name: "Operating Systems", code: "OS-9214", isOwner: true),
  const Subject(id: "sub2", name: "DBMS", code: "DB-1180", isOwner: true),
  ];

  final Map<String, List<Lecture>> _lecturesBySubject = {
    "sub1": [
      Lecture(
        id: "lec1",
        subjectId: "sub1",
        dateTime: DateTime.now().subtract(const Duration(days: 2, hours: 3)),
        status: LectureStatus.ready,
        englishSummaryPreview: "Deadlock: definition, 4 conditions, examples.",
      ),
      Lecture(
        id: "lec2",
        subjectId: "sub1",
        dateTime: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
        status: LectureStatus.ready,
        englishSummaryPreview: "CPU scheduling basics and metrics discussed.",
      ),
    ],
    "sub2": [
      Lecture(
        id: "lec3",
        subjectId: "sub2",
        dateTime: DateTime.now().subtract(const Duration(days: 1, hours: 5)),
        status: LectureStatus.ready,
        englishSummaryPreview: "Normalization: 1NF to 3NF, examples.",
      ),
    ],
  };

  final Map<String, Map<String, dynamic>> _lectureDetails = {
    "lec1": {
      "notes": """
### Deadlock
**Definition**
- Deadlock is a situation where a set of processes are blocked because each process is holding a resource and waiting for another resource held by another process.

**Necessary Conditions (Coffman conditions)**
1. Mutual Exclusion
2. Hold and Wait
3. No Preemption
4. Circular Wait

**Key Discussion**
- Why deadlocks happen in resource allocation
- Simple examples with two processes and two resources
- How the conditions relate to each other

### Deadlock Handling (Overview)
- Prevention (break a condition)
- Avoidance (safe state concept)
- Detection & Recovery (detect cycles, recover)
""",
      "summary": """
- Defined deadlock and gave intuition with resource waiting.
- Explained the four necessary conditions.
- Showed small examples and discussed why deadlock is hard to resolve.
- Introduced high-level approaches: prevention, avoidance, detection/recovery.
""",
      "quiz": LectureQuiz(
        lectureId: "lec1",
        mcqs: [
          QuizQuestion(
            question: "Which is NOT a necessary condition for deadlock?",
            options: ["Mutual Exclusion", "Hold and Wait", "Preemption", "Circular Wait"],
            correctIndex: 2,
          ),
          QuizQuestion(
            question: "Circular wait means:",
            options: [
              "All processes finish in a cycle",
              "Processes hold resources in a circular chain",
              "CPU cycles are wasted",
              "Resources are always shared"
            ],
            correctIndex: 1,
          ),
        ],
        shortAnswers: [
          {"q": "Define deadlock.", "a": "A set of processes are blocked waiting for resources held by each other."},
          {"q": "List the four necessary conditions.", "a": "Mutual exclusion, hold and wait, no preemption, circular wait."},
        ],
      ),
    },
    "lec2": {
      "notes": """
### CPU Scheduling
- Why scheduling is needed (multiple ready processes)
- Goals: throughput, turnaround time, waiting time, response time

### Common Algorithms (high-level)
- FCFS
- SJF (idea)
- Round Robin (time quantum concept)
- Priority scheduling

### Metrics
- Waiting time vs turnaround time
- How time quantum impacts responsiveness
""",
      "summary": """
- Introduced CPU scheduling goals and key metrics.
- Discussed common scheduling approaches and their intuition.
- Connected algorithm choice with waiting/response time tradeoffs.
""",
      "quiz": LectureQuiz(
        lectureId: "lec2",
        mcqs: [
          QuizQuestion(
            question: "Round Robin scheduling primarily improves:",
            options: ["Disk throughput", "Response time", "Memory size", "File indexing"],
            correctIndex: 1,
          ),
        ],
        shortAnswers: [
          {"q": "What is turnaround time?", "a": "Total time from submission to completion of a process."},
        ],
      ),
    },
    "lec3": {
      "notes": """
### Normalization
- Motivation: reduce redundancy and anomalies
- 1NF: atomic attributes
- 2NF: remove partial dependency
- 3NF: remove transitive dependency

### Examples
- How splitting tables reduces anomalies
""",
      "summary": """
- Explained why normalization is used.
- Covered 1NF, 2NF, 3NF with dependency intuition.
- Discussed how decomposition reduces anomalies.
""",
      "quiz": LectureQuiz(
        lectureId: "lec3",
        mcqs: [
          QuizQuestion(
            question: "3NF aims to remove:",
            options: ["Atomic attributes", "Partial dependency", "Transitive dependency", "Foreign keys"],
            correctIndex: 2,
          ),
        ],
        shortAnswers: [
          {"q": "Why do we normalize tables?", "a": "To reduce redundancy and prevent update anomalies."},
        ],
      ),
    },
  };

  // --- Subjects ---
  Future<List<Subject>> listSubjects() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return List.unmodifiable(_subjects);
  }

  Future<Subject> createSubject(String name) async {
    await Future.delayed(const Duration(milliseconds: 700));
    final id = "sub${_subjects.length + 1}";
    final code = "${name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase()}-${1000 + _subjects.length * 17}";
    final s = Subject(id: id, name: name, code: code, isOwner: true);
    _subjects.insert(0, s);
    _lecturesBySubject[id] = [];
    return s;
  }

  Future<bool> joinSubjectByCode(String code) async {
    await Future.delayed(const Duration(milliseconds: 650));
    // mock: accept if any subject has same code
    return _subjects.any((s) => s.code.toUpperCase() == code.toUpperCase());
  }

  // --- Lectures ---
  Future<List<Lecture>> listLectures(String subjectId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return List.unmodifiable(_lecturesBySubject[subjectId] ?? const []);
  }

  /// Mock upload: creates a lecture and simulates status progression.
  Future<Lecture> uploadLecture({
    required String subjectId,
    required DateTime dateTime,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));

    final newLecture = Lecture(
      id: "lec${DateTime.now().millisecondsSinceEpoch}",
      subjectId: subjectId,
      dateTime: dateTime,
      status: LectureStatus.uploaded,
      englishSummaryPreview: "Processing…",
    );

    _lecturesBySubject.putIfAbsent(subjectId, () => []);
    _lecturesBySubject[subjectId] = [newLecture, ..._lecturesBySubject[subjectId]!];

    // simulate processing in background
    unawaited(_simulateProcessing(newLecture));

    return newLecture;
  }

  Future<void> _simulateProcessing(Lecture lecture) async {
    // uploaded -> processing -> ready
    await Future.delayed(const Duration(seconds: 1));

    _updateLecture(lecture, LectureStatus.processing, "Transcribing & generating notes…");
    await Future.delayed(const Duration(seconds: 2));

    _updateLecture(lecture, LectureStatus.ready, "Lecture notes generated. Quiz ready.");
  }

  void _updateLecture(Lecture lecture, LectureStatus status, String preview) {
    final list = _lecturesBySubject[lecture.subjectId];
    if (list == null) return;

    final idx = list.indexWhere((l) => l.id == lecture.id);
    if (idx == -1) return;

    list[idx] = Lecture(
      id: lecture.id,
      subjectId: lecture.subjectId,
      dateTime: lecture.dateTime,
      status: status,
      englishSummaryPreview: preview,
    );
  }

  // --- Details ---
  Future<Map<String, dynamic>> getLectureDetail(String lectureId) async {
    await Future.delayed(const Duration(milliseconds: 550));
    // If unknown (new lecture), return placeholder
    return _lectureDetails[lectureId] ??
        {
          "notes": "Processing… Please check back shortly.",
          "summary": "Processing…",
          "quiz": const LectureQuiz(lectureId: "x", mcqs: [], shortAnswers: []),
        };
  }

  // --- Search ---
  Future<List<Lecture>> searchWithinSubject({
    required String subjectId,
    required String query,
  }) async {
    await Future.delayed(const Duration(milliseconds: 450));
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];

    final lectures = _lecturesBySubject[subjectId] ?? const [];
    return lectures
        .where((l) => l.englishSummaryPreview.toLowerCase().contains(q))
        .toList(growable: false);
  }
}
