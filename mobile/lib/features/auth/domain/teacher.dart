class Teacher {
  const Teacher({
    required this.id,
    required this.cin,
    required this.nom,
    this.matiere,
  });

  final String id;
  final String cin;
  final String nom;
  final String? matiere;

  factory Teacher.fromJson(Map<String, dynamic> json) {
    String? _readString(dynamic value) {
      if (value == null) {
        return null;
      }
      if (value is String) {
        return value;
      }
      return value.toString();
    }

    return Teacher(
      id: _readString(json['id']) ?? '',
      cin:
          _readString(json['cin']) ??
          _readString(json['CIN']) ??
          _readString(json['Cin']) ??
          '',
      nom:
          _readString(json['nom']) ??
          _readString(json['Nom']) ??
          _readString(json['name']) ??
          '',
      matiere:
          _readString(json['matiere']) ??
          _readString(json['matière']) ??
          _readString(json['subject']),
    );
  }
}
