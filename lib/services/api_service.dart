import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_models.dart';

class ApiService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Classroom Methods
  Future<List<Classroom>> getClassrooms(String userId) async {
    final snapshot = await _db
        .collection('classrooms')
        .where('user_id', isEqualTo: userId)
        .get();
    return snapshot.docs.map((doc) => Classroom.fromMap({...doc.data(), 'id': doc.id})).toList();
  }

  Future<Classroom> addClassroom(String name, String subject, String userId) async {
    final docRef = await _db.collection('classrooms').add({
      'name': name,
      'subject': subject,
      'user_id': userId,
      'created_at': FieldValue.serverTimestamp(),
    });
    return Classroom(id: docRef.id, name: name, subject: subject);
  }

  Future<void> updateClassroom(String id, String name, String subject) async {
    await _db.collection('classrooms').doc(id).update({
      'name': name,
      'subject': subject,
    });
  }

  Future<void> deleteClassroom(String id) async {
    // Delete the classroom document
    await _db.collection('classrooms').doc(id).delete();
    // Note: In a production app, you might want to also delete students and attendance records
    // but for now we'll keep it simple as Firestore doesn't support recursive deletes easily.
  }

  // Student Methods
  Future<List<Student>> getStudents(String classroomId) async {
    final snapshot = await _db
        .collection('students')
        .where('classroom_id', isEqualTo: classroomId)
        .get();
    return snapshot.docs.map((doc) => Student.fromMap({...doc.data(), 'id': doc.id})).toList();
  }

  Future<Student> addStudent(Student student) async {
    await _db.collection('students').add(student.toMap());
    return student;
  }

  Future<void> updateStudent(Student student) async {
    final snapshot = await _db.collection('students').where('register_number', isEqualTo: student.registerNumber).get();
    for (var doc in snapshot.docs) {
      await doc.reference.update(student.toMap());
    }
  }

  Future<void> deleteStudent(String id) async {
    await _db.collection('students').doc(id).delete();
  }

  // Attendance Methods
  Future<void> saveAttendance(List<Attendance> reports) async {
    final batch = _db.batch();
    for (var report in reports) {
      final docRef = _db.collection('attendance').doc();
      batch.set(docRef, {
        ...report.toMap(),
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Future<List<Attendance>> getAttendanceForDate(String classroomId, String date) async {
    final snapshot = await _db
        .collection('attendance')
        .where('classroom_id', isEqualTo: classroomId)
        .where('date', isEqualTo: date)
        .get();
    return snapshot.docs.map((doc) => Attendance.fromMap({...doc.data(), 'id': doc.id})).toList();
  }

  // Reports - Firebase basic summaries
  Future<List<Map<String, dynamic>>> getSummary(String classroomId, {String? startDate, String? endDate}) async {
    var query = _db.collection('attendance').where('classroom_id', isEqualTo: classroomId);
    if (startDate != null) query = query.where('date', isGreaterThanOrEqualTo: startDate);
    if (endDate != null) query = query.where('date', isLessThanOrEqualTo: endDate);
    
    final snapshot = await query.get();
    // Manual aggregation as Firestore doesn't do complex GROUP BY easily
    Map<String, Map<String, dynamic>> studentStats = {};
    for (var doc in snapshot.docs) {
      final data = doc.data();
      String sId = data['student_id']?.toString() ?? 'unknown';
      int status = data['is_present'] ?? 0;
      
      studentStats.putIfAbsent(sId, () => {
        'total_days': 0, 'present_days': 0, 'absent_days': 0, 'leave_days': 0, 'od_days': 0, 'name': data['student_name'] ?? 'Student'
      });
      
      studentStats[sId]!['total_days']++;
      if (status == 1) studentStats[sId]!['present_days']++;
      else if (status == 0) studentStats[sId]!['absent_days']++;
      else if (status == 2) studentStats[sId]!['leave_days']++;
      else if (status == 3) studentStats[sId]!['od_days']++;
    }
    return studentStats.values.toList();
  }

  // Authentication Methods
  Future<UserProfile?> login(String email, String password) async {
    try {
      print("ApiService: Attempting login for $email");
      final credential = await _auth.signInWithEmailAndPassword(email: email, password: password);
      print("ApiService: Auth success, UID: ${credential.user?.uid}");
      
      if (credential.user != null) {
        print("ApiService: Fetching profile from Firestore...");
        final doc = await _db.collection('profiles').doc(credential.user!.uid).get();
        print("ApiService: Profile fetch complete, exists: ${doc.exists}");
        
        if (doc.exists) {
          final data = doc.data()!;
          return UserProfile.fromMap({...data, 'user_id': credential.user!.uid});
        } else {
          print("ApiService: No profile document found, using default.");
          return UserProfile(
            userId: credential.user!.uid,
            name: credential.user!.email?.split('@')[0] ?? 'User',
            designation: 'Staff',
            institution: 'BDU',
            role: 'admin',
          );
        }
      }
    } catch (e) {
      print("ApiService: Login error: $e");
    }
    return null;
  }

  Future<bool> sendForgotPasswordOtp(String email) async {
    try {
      print("ApiService: Requesting password reset for $email");
      await _auth.sendPasswordResetEmail(email: email);
      print("ApiService: Password reset email sent successfully.");
      return true;
    } catch (e) {
      print("ApiService: Password reset error: $e");
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getRawAttendance(String classroomId) async {
    final snapshot = await _db
        .collection('attendance')
        .where('classroom_id', isEqualTo: classroomId)
        .orderBy('date', descending: true)
        .get();
    
    // We need to join with student names which are in a different collection
    final studentSnapshot = await _db.collection('students').where('classroom_id', isEqualTo: classroomId).get();
    final studentNames = { for (var doc in studentSnapshot.docs) doc.id : doc.data()['name'] ?? 'Student' };

    return snapshot.docs.map((doc) {
      final data = doc.data();
      final sId = data['student_id']?.toString() ?? '';
      return {
        ...data,
        'id': doc.id,
        'student_name': studentNames[sId] ?? 'Student',
      };
    }).toList();
  }

  Future<bool> register({
    required String username,
    required String password,
    required String name,
    required String designation,
    required String institution,
    required String email,
    required String otp, // OTP not needed for Firebase link auth, but we use email/pass
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      if (credential.user != null) {
        await _db.collection('profiles').doc(credential.user!.uid).set({
          'name': name,
          'designation': designation,
          'institution': institution,
          'email': email,
          'role': 'admin',
        });
        return true;
      }
    } catch (e) {
      print("Register error: $e");
    }
    return false;
  }

  // Profile Methods
  Future<UserProfile?> getProfile(String userId) async {
    final doc = await _db.collection('profiles').doc(userId).get();
    if (doc.exists) {
      return UserProfile.fromMap({...doc.data()!, 'id': doc.id, 'userId': userId});
    }
    return null;
  }

  Future<void> updateProfile(UserProfile profile) async {
    if (profile.userId != null) {
      await _db.collection('profiles').doc(profile.userId).update(profile.toMap());
    }
  }

  // Backup - Excel is handled on client now or cloud function
  Future<List<int>> downloadBackup(String userId) async {
    throw Exception('Client-side Excel backup not implemented yet');
  }

  // Timetable
  Future<List<TimetableEntry>> getTimetable(String classroomId) async {
    final snapshot = await _db
        .collection('timetable')
        .where('classroom_id', isEqualTo: classroomId)
        .get();
    return snapshot.docs.map((doc) => TimetableEntry.fromMap({...doc.data(), 'id': doc.id})).toList();
  }

  Future<void> addTimetableEntry(TimetableEntry entry) async {
    await _db.collection('timetable').add(entry.toMap());
  }

  Future<void> deleteTimetableEntry(String id) async {
    await _db.collection('timetable').doc(id).delete();
  }

  // Staff/User Management
  Future<List<Map<String, dynamic>>> getStaff() async {
    final snapshot = await _db.collection('profiles').get();
    return snapshot.docs.map((doc) => {
      ...doc.data(),
      'id': doc.id,
      'username': doc.data()['email'] ?? 'User', // Fallback
    }).toList();
  }

  Future<void> addStaff(String email, String password) async {
    // In a real app, this would use a Cloud Function to avoid logging out the admin.
    // For now, we'll suggest using the Register screen or provide a placeholder.
    await _auth.createUserWithEmailAndPassword(email: email, password: password);
    // After creation, the admin would be logged out, so we need to be careful.
    // I'll provide a more robust way in the documentation.
  }

  // Legacy/Compatibility support for reporting
  Future<List<Map<String, dynamic>>> getDateWiseSummary(String classroomId) async {
    // This is now handled on client side in ReportScreen, but keeping for compatibility
    return getRawAttendance(classroomId);
  }
}
