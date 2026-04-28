class Classroom {
  final String? id;
  final String name;
  final String subject;

  Classroom({this.id, required this.name, this.subject = ''});

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'subject': subject};
  factory Classroom.fromMap(Map<String, dynamic> m) => 
      Classroom(id: m['id']?.toString(), name: m['name'], subject: m['subject'] ?? '');
}

class Student {
  final String? id;
  final String name;
  final String registerNumber;
  final String gender;
  final String classroomId;
  final String? parentEmail;

  Student({
    this.id,
    required this.name,
    required this.registerNumber,
    required this.gender,
    required this.classroomId,
    this.parentEmail,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'register_number': registerNumber,
    'gender': gender,
    'classroom_id': classroomId,
    'parent_email': parentEmail,
  };

  factory Student.fromMap(Map<String, dynamic> m) => Student(
    id: m['id']?.toString(),
    name: m['name'],
    registerNumber: m['register_number'] ?? '',
    gender: m['gender'] ?? '',
    classroomId: m['classroom_id']?.toString() ?? '',
    parentEmail: m['parent_email'],
  );
}

class Attendance {
  final String? id;
  final String studentId;
  final String classroomId;
  final String date;
  final int isPresent;

  Attendance({
    this.id, 
    required this.studentId, 
    required this.classroomId, 
    required this.date, 
    required this.isPresent
  });

  Map<String, dynamic> toMap() => {
    'id': id, 
    'student_id': studentId,
    'classroom_id': classroomId,
    'date': date,
    'is_present': isPresent,
  };

  factory Attendance.fromMap(Map<String, dynamic> m) => Attendance(
    id: m['id']?.toString(),
    studentId: m['student_id']?.toString() ?? '',
    classroomId: m['classroom_id']?.toString() ?? '',
    date: m['date'],
    isPresent: m['is_present'] ?? 0,
  );
}
class UserProfile {
  final String? id;
  final String name;
  final String designation;
  final String institution;
  final String? imagePath;
  final String? userId; 
  final String? role; // Added role

  UserProfile({
    this.id,
    required this.name,
    required this.designation,
    required this.institution,
    this.imagePath,
    this.userId,
    this.role,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'designation': designation,
    'institution': institution,
    'image_path': imagePath,
    'user_id': userId,
    'role': role,
  };

  factory UserProfile.fromMap(Map<String, dynamic> m) => UserProfile(
    id: m['id']?.toString(),
    name: m['name'],
    designation: m['designation'],
    institution: m['institution'],
    imagePath: m['image_path'],
    userId: m['user_id']?.toString(),
    role: m['role'],
  );
}
class TimetableEntry {
  final String? id;
  final String day;
  final String startTime;
  final String endTime;
  final String subject;
  final int period; // Added period
  final String classroomId;

  TimetableEntry({
    this.id,
    required this.day,
    required this.startTime,
    required this.endTime,
    required this.subject,
    required this.period,
    required this.classroomId,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'day': day,
    'start_time': startTime,
    'end_time': endTime,
    'subject': subject,
    'period': period,
    'classroom_id': classroomId,
  };

  factory TimetableEntry.fromMap(Map<String, dynamic> m) => TimetableEntry(
    id: m['id']?.toString(),
    day: m['day'],
    startTime: m['start_time'],
    endTime: m['end_time'],
    subject: m['subject'],
    period: m['period'] ?? 1,
    classroomId: m['classroom_id']?.toString() ?? '',
  );
}
