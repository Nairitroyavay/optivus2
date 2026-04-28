class HabitModel {
  final String id;
  final String name;
  final String kind;
  final String category;
  final String color;
  final String icon;

  HabitModel({
    required this.id,
    required this.name,
    required this.kind,
    required this.category,
    required this.color,
    required this.icon,
  });

  factory HabitModel.fromMap(Map<String, dynamic> map, String id) {
    return HabitModel(
      id: id,
      name: map['name'] ?? '',
      kind: map['kind'] ?? 'good',
      category: map['category'] ?? '',
      color: map['color'] ?? '',
      icon: map['icon'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'kind': kind,
      'category': category,
      'color': color,
      'icon': icon,
    };
  }
}
