class UserCard {
  final int? id;
  final String name;
  final int color;

  UserCard({
    this.id,
    required this.name,
    required this.color,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'color': color,
    };
  }

  factory UserCard.fromMap(Map<String, dynamic> map) {
    return UserCard(
      id: map['id'],
      name: map['name'],
      color: map['color'],
    );
  }
}