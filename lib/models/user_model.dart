class UserModel {
  final String id;
  final String email;
  final String name;
  final String? photoURL;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    this.photoURL,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] ?? '',
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      photoURL: map['avatar'] ?? map['photoURL'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'avatar': photoURL,
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    String? photoURL,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      photoURL: photoURL ?? this.photoURL,
    );
  }

  @override
  String toString() {
    return 'UserModel(id: $id, email: $email, name: $name, photoURL: $photoURL)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel &&
        other.id == id &&
        other.email == email &&
        other.name == name &&
        other.photoURL == photoURL;
  }

  @override
  int get hashCode {
    return id.hashCode ^ email.hashCode ^ name.hashCode ^ photoURL.hashCode;
  }
}
