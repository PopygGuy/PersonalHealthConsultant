class Norm {
  final String id;
  final String name;
  Norm({required this.id, required this.name});

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
  factory Norm.fromJson(Map<String, dynamic> json) => Norm(id: json['id'], name: json['name']);
}
