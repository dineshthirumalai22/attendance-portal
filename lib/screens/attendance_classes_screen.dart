import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_models.dart';
import '../services/api_service.dart';
import 'attendance_options_screen.dart';

class AttendanceClassesScreen extends StatefulWidget {
  const AttendanceClassesScreen({super.key});

  @override
  State<AttendanceClassesScreen> createState() => _AttendanceClassesScreenState();
}

class _AttendanceClassesScreenState extends State<AttendanceClassesScreen> {
  final _apiService = ApiService();
  final _userId = FirebaseAuth.instance.currentUser?.uid ?? '';
  List<Classroom> _classrooms = [];

  @override
  void initState() {
    super.initState();
    _loadClassrooms();
  }

  Future<void> _loadClassrooms() async {
    if (_userId.isEmpty) return;
    final data = await _apiService.getClassrooms(_userId);
    setState(() => _classrooms = data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Class for Attendance')),
      body: _classrooms.isEmpty
          ? const Center(child: Text('No classes found.\nCreate a class in "Classes" first.'))
          : ListView.builder(
              itemCount: _classrooms.length,
              itemBuilder: (ctx, index) => Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.class_)),
                  title: Text(_classrooms[index].name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AttendanceOptionsScreen(classroom: _classrooms[index]),
                      ),
                    );
                  },
                ),
              ),
            ),
    );
  }
}
