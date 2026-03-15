class Student {
  final String id;
  final String name;
  final bool isRepresentative;

  const Student({required this.id, required this.name, this.isRepresentative = false});

  Student copyWith({String? id, String? name, bool? isRepresentative}) {
    return Student(
      id: id ?? this.id,
      name: name ?? this.name,
      isRepresentative: isRepresentative ?? this.isRepresentative,
    );
  }
}
