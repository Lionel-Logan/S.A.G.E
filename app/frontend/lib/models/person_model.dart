class PersonModel {
  final int id;
  final String name;
  final String description;

  PersonModel({
    required this.id,
    required this.name,
    required this.description,
  });

  factory PersonModel.fromJson(Map<String, dynamic> json) {
    return PersonModel(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
    };
  }
}
