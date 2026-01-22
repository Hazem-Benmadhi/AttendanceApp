class CaptureSessionPayload {
  CaptureSessionPayload({
    required this.id,
    required this.nomSeance,
    required this.date,
    required this.classe,
    required this.profReference,
  });

  final String id;
  final String nomSeance;
  final DateTime date;
  final String classe;
  final String profReference;

  factory CaptureSessionPayload.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'] ?? json['session_id'];
    final id =
        rawId is String && rawId.isNotEmpty
            ? rawId
            : DateTime.now().microsecondsSinceEpoch.toString();

    final rawName =
        json['nom_seance'] ?? json['nomSeance'] ?? json['nom'] ?? 'Session';
    final rawClasse = json['classe'] ?? json['Classe'] ?? 'Unknown';
    final rawProf =
        json['prof'] ?? json['prof_reference'] ?? json['profRef'] ?? '';

    final rawDate = json['date'];
    DateTime parsedDate;
    if (rawDate is String && rawDate.isNotEmpty) {
      parsedDate = DateTime.tryParse(rawDate)?.toLocal() ?? DateTime.now();
    } else if (rawDate is DateTime) {
      parsedDate = rawDate.toLocal();
    } else {
      parsedDate = DateTime.now();
    }

    return CaptureSessionPayload(
      id: id,
      nomSeance: rawName,
      date: parsedDate,
      classe: rawClasse,
      profReference: rawProf,
    );
  }

  Map<String, dynamic> toJson() {
    final payload = <String, dynamic>{
      'id': id,
      'nom_seance': nomSeance,
      'classe': classe,
      'date': date.toUtc().toIso8601String(),
    };

    if (profReference.trim().isNotEmpty) {
      payload['prof'] = profReference;
    }

    return payload;
  }
}
