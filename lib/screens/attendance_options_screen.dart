import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../services/api_service.dart';
import 'mark_attendance_screen.dart';
import 'report_screen.dart';

class AttendanceOptionsScreen extends StatefulWidget {
  final Classroom classroom;
  const AttendanceOptionsScreen({super.key, required this.classroom});

  @override
  State<AttendanceOptionsScreen> createState() => _AttendanceOptionsScreenState();
}

class _AttendanceOptionsScreenState extends State<AttendanceOptionsScreen> {
  final _apiService = ApiService();
  List<Student> _students = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    final data = await _apiService.getStudents(widget.classroom.id!);
    setState(() {
      _students = data;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.classroom.name)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _actionButton(
                    context,
                    icon: Icons.check_circle_outline,
                    label: 'Mark Attendance',
                    color: Colors.green,
                    enabled: _students.isNotEmpty,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MarkAttendanceScreen(classroom: widget.classroom, students: _students),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _actionButton(
                    context,
                    icon: Icons.assessment_outlined,
                    label: 'View Reports',
                    color: Colors.blue,
                    enabled: _students.isNotEmpty,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReportScreen(classroom: widget.classroom),
                      ),
                    ),
                  ),
                  if (_students.isEmpty) ...[
                    const SizedBox(height: 30),
                    const Text(
                      'This class has no students.\nPlease add students in the "Classes" section first.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                  ]
                ],
              ),
            ),
    );
  }

  Widget _actionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 20),
        backgroundColor: enabled ? color : Colors.grey,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: enabled ? onTap : null,
      icon: Icon(icon, size: 28),
      label: Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }
}
