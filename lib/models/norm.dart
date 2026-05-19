class Norm {
  final String id;
  final String name;
  final bool isActive;
  Norm({required this.id, required this.name, this.isActive = true});

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'is_active': isActive};
  factory Norm.fromJson(Map<String, dynamic> json) => Norm(
      id: json['id'],
      name: json['name'],
      isActive: json['is_active'] == null ? true : json['is_active'] == true);
}
