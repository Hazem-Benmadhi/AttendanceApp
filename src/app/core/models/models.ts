export interface Student {
  id: string; // Document ID
  cin: string;
  nom: string;
  classe?: string;
  image?: string;
  // Add other fields if present in DB, e.g., classe
}

export interface Teacher {
  id: string; // Document ID
  cin: string;
  nom: string;
  matiere: string;
}

export interface Session {
  id: string; // Document ID
  nom_seance: string;
  date: any; // Timestamp or Date
  classe: string;
  prof: any; // DocumentReference
}

export interface Attendance {
  id: string; // Document ID
  Etudiant_id: any; // DocumentReference
  Seance_id: any; // DocumentReference
  status: 'present' | 'absent';
}

