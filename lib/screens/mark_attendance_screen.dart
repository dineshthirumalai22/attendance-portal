import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/app_models.dart';
import '../services/api_service.dart';

class MarkAttendanceScreen extends StatefulWidget {
  final Classroom classroom;
  final List<Student> students;
  const MarkAttendanceScreen({super.key, required this.classroom, required this.students});

  @override
  State<MarkAttendanceScreen> createState() => _MarkAttendanceScreenState();
}

class _MarkAttendanceScreenState extends State<MarkAttendanceScreen> {
  final _apiService = ApiService();
  DateTime _selectedDate = DateTime.now();
  
  // Status: 1: Present, 0: Absent, 2: Leave, 3: OD
  final Map<String, int> _attendance = {};

  @override
  void initState() {
    super.initState();
    // Default everyone to present (1)
    for (var s in widget.students) {
      if (s.id != null) {
        _attendance[s.id!] = 1;
      }
    }
    _loadExistingAttendance();
  }

  Future<void> _loadExistingAttendance() async {
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final existing = await _apiService.getAttendanceForDate(widget.classroom.id!, dateStr);
    if (existing.isNotEmpty) {
      setState(() {
        for (var record in existing) {
          _attendance[record.studentId] = record.isPresent;
        }
      });
    }
  }

  Future<void> _save() async {
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final reports = widget.students.map((s) => Attendance(
      studentId: s.id!,
      classroomId: widget.classroom.id!,
      date: dateStr,
      isPresent: _attendance[s.id!] ?? 1,
    )).toList();

    await _apiService.saveAttendance(reports);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Attendance Saved Successfully!')));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mark Attendance')),
      body: Column(
        children: [
          Container(
            color: Colors.blue.withOpacity(0.1),
            child: ListTile(
              title: Text(
                "Date: ${DateFormat('dd MMM yyyy').format(_selectedDate)}",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              trailing: const Icon(Icons.calendar_month, color: Colors.blue),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  setState(() => _selectedDate = picked);
                  _loadExistingAttendance();
                }
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatusLegend(color: Colors.green, label: 'Present'),
                _StatusLegend(color: Colors.red, label: 'Absent'),
                _StatusLegend(color: Colors.orange, label: 'Leave'),
                _StatusLegend(color: Colors.purple, label: 'OD'),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: widget.students.length,
              itemBuilder: (ctx, i) {
                final s = widget.students[i];
                final currentStatus = _attendance[s.id] ?? 1;

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            s.name,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _statusButton(s.id!, 1, Icons.check_circle, Colors.green, currentStatus == 1),
                            const SizedBox(width: 8),
                            _statusButton(s.id!, 0, Icons.cancel, Colors.red, currentStatus == 0),
                            const SizedBox(width: 8),
                            _statusButton(s.id!, 2, Icons.event_note, Colors.orange, currentStatus == 2),
                            const SizedBox(width: 8),
                            _statusButton(s.id!, 3, Icons.card_membership, Colors.purple, currentStatus == 3),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _save,
              child: const Text('Submit Attendance', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  Widget _statusButton(String studentId, int status, IconData icon, Color color, bool isSelected) {
    return GestureDetector(
      onTap: () => setState(() => _attendance[studentId] = status),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.grey.withOpacity(0.1),
          shape: BoxShape.circle,
          border: Border.all(color: isSelected ? color : Colors.grey.shade300, width: 1),
        ),
        child: Icon(
          icon,
          size: 24,
          color: isSelected ? Colors.white : Colors.grey.shade400,
        ),
      ),
    );
  }
}

class _StatusLegend extends StatelessWidget {
  final Color color;
  final String label;
  const _StatusLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}
