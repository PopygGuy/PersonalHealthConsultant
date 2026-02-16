class Group {
  final String id;
  final String name;
  final String facultyId; 
  Group({required this.id, required this.name, required this.facultyId});

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'faculty_id': facultyId,
      };

  factory Group.fromJson(Map<String, dynamic> json) => Group(
        id: json['id'],
        name: json['name'],
        facultyId: json['faculty_id'] ?? json['facultyId'],
      );
}
