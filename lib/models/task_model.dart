class TaskModel {
  final String id;
  final String title;
  final DateTime time;

  TaskModel({
    required this.id,
    required this.title,
    required this.time,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'time': time.toIso8601String(),
    };
  }

  factory TaskModel.fromMap(Map<String, dynamic> map) {
    return TaskModel(
      id: map['id'],
      title: map['title'],
      time: DateTime.parse(map['time']),
    );
  }
}
