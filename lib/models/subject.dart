class Subject {
  final String id;
  final String name;
  final String? code; // invite code shown to teacher, null for students
  final bool isOwner; // true only if current user owns the subject
  final String? roleInSubject; // "student" | "rep" | null

  const Subject({
    required this.id,
    required this.name,
    this.code,
    this.isOwner = false,
    this.roleInSubject,
  });
}
