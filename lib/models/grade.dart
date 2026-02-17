class Grade {
  final String id;
  final String studentId;
  final String studentName;
  final String teacherId;
  final String normId;
  final String normName;
  final String academicYear;
  final int course;
  final int semester;
  final int score;
  final DateTime date;
  final String? comment;
  final List<Map<String, dynamic>> history;

  Grade({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.teacherId,
    required this.normId,
    required this.normName,
    required this.academicYear,
    required this.course,
    required this.semester,
    required this.score,
    required this.date,
    this.comment,
    this.history = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'studentId': studentId,
        'studentName': studentName,
        'teacherId': teacherId,
        'normId': normId,
        'normName': normName,
        'academicYear': academicYear,
        'course': course,
        'semester': semester,
        'score': score,
        'date': date.toIso8601String(),
        'comment': comment,
        'history': history,
      };

  factory Grade.fromJson(Map<String, dynamic> json) {
    return Grade(
      id: json['id'],
      studentId:
          json['studentId'] ?? json['student_id'], // Handle API snake_case
      studentName: json['studentName'] ??
          'Студент', // API might not return name directly in Grade
      teacherId: json['teacherId'] ?? json['teacher_id'] ?? '',
      normId: json['normId'] ?? json['norm_id'] ?? '',
      normName: json['normName'] ?? 'Норматив', // API might not return name
      academicYear:
          (json['academicYear'] ?? json['academic_year'] ?? '').toString(),
      course: (json['course'] as num?)?.toInt() ?? 1,
      semester: (json['semester'] as num?)?.toInt() ?? 1,
      score: json['score'],
      date: DateTime.parse(json['date']),
      comment: json['comment'],
      history: json['history'] != null
          ? List<Map<String, dynamic>>.from(json['history'])
          : [],
    );
  }
}
