import 'package:flutter/material.dart';
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import '../models/app_models.dart';
import '../services/api_service.dart';

class TimetableScreen extends StatefulWidget {
  final Classroom classroom;
  const TimetableScreen({super.key, required this.classroom});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  final _apiService = ApiService();
  List<TimetableEntry> _entries = [];
  bool _isLoading = true;

  final List<String> _days = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];

  @override
  void initState() {
    super.initState();
    _loadTimetable();
  }

  Future<void> _loadTimetable() async {
    setState(() => _isLoading = true);
    final data = await _apiService.getTimetable(widget.classroom.id!);
    setState(() {
      _entries = data;
      _isLoading = false;
    });
  }

  Future<void> _importTimetable() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (result != null) {
        setState(() => _isLoading = true);
        File file = File(result.files.single.path!);
        var bytes = file.readAsBytesSync();
        var excel = Excel.decodeBytes(bytes);

        for (var table in excel.tables.keys) {
          var sheet = excel.tables[table]!;
          // Assuming Row 1 is header, start from Row 2
          for (int rowIndex = 1; rowIndex < sheet.maxRows; rowIndex++) {
             var row = sheet.rows[rowIndex];
             if (row.isEmpty) continue;

             // Expected format: Day, P1, P2, P3, P4, P5
             // Index 0: Day Name
             // Index 1-5: Subjects for Period 1-5
             
             String day = row[0]?.value?.toString() ?? '';
             if (!_days.contains(day)) continue; // Skip invalid days

             for (int i = 1; i <= 5; i++) {
               if (i < row.length) {
                 String subject = row[i]?.value?.toString() ?? '';
                 if (subject.isNotEmpty && subject != '-') {
                   // Create or update entry
                   // First delete existing for this slot to avoid duplicates? 
                   // Or just add (DB autoincrements ID). Better to just add for now, user can clear first.
                   // Ideally logic: Check if exists, update. But simpler is just insert.
                   
                   final entry = TimetableEntry(
                      day: day,
                      subject: subject,
                      startTime: '', // Default empty as generic import doesn't have time
                      endTime: '',
                      period: i,
                      classroomId: widget.classroom.id!,
                    );
                    await _apiService.addTimetableEntry(entry);
                 }
               }
             }
          }
        }
        await _loadTimetable();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Timetable imported successfully')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showAddEntryDialog() {
    String selectedDay = _days[0];
    int selectedPeriod = 1;
    final subjectController = TextEditingController();
    final startTimeController = TextEditingController();
    final endTimeController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Timetable Entry'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _importTimetable();
                },
                icon: const Icon(Icons.file_upload),
                label: const Text('Import from Excel'),
              ),
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('--- OR ---', style: TextStyle(color: Colors.grey)),
              ),
              DropdownButtonFormField<String>(
                value: selectedDay,
                items: _days.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                onChanged: (v) => selectedDay = v!,
                decoration: const InputDecoration(labelText: 'Day'),
              ),
              DropdownButtonFormField<int>(
                value: selectedPeriod,
                items: [1, 2, 3, 4, 5].map((p) => DropdownMenuItem(value: p, child: Text('Period $p'))).toList(),
                onChanged: (v) => selectedPeriod = v!,
                decoration: const InputDecoration(labelText: 'Period'),
              ),
              TextField(
                controller: subjectController,
                decoration: const InputDecoration(labelText: 'Subject'),
              ),
              TextField(
                controller: startTimeController,
                decoration: const InputDecoration(labelText: 'Start Time (Optional)'),
              ),
              TextField(
                controller: endTimeController,
                decoration: const InputDecoration(labelText: 'End Time (Optional)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              if (subjectController.text.isNotEmpty) {
                final entry = TimetableEntry(
                  day: selectedDay,
                  subject: subjectController.text,
                  startTime: startTimeController.text,
                  endTime: endTimeController.text,
                  period: selectedPeriod,
                  classroomId: widget.classroom.id!,
                );
                await _apiService.addTimetableEntry(entry);
                _loadTimetable();
                if (mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Timetable: ${widget.classroom.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload),
            tooltip: 'Import Excel',
            onPressed: _importTimetable,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 20,
                  headingRowColor: WidgetStateProperty.all(Colors.indigo.shade50),
                  columns: [
                    const DataColumn(label: Text('Day', style: TextStyle(fontWeight: FontWeight.bold))),
                    const DataColumn(label: Text('P1', style: TextStyle(fontWeight: FontWeight.bold))),
                    const DataColumn(label: Text('P2', style: TextStyle(fontWeight: FontWeight.bold))),
                    const DataColumn(label: Text('P3', style: TextStyle(fontWeight: FontWeight.bold))),
                    const DataColumn(label: Text('P4', style: TextStyle(fontWeight: FontWeight.bold))),
                    const DataColumn(label: Text('P5', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: _days.map((day) {
                    final dayEntries = _entries.where((e) => e.day == day).toList();
                    return DataRow(
                      cells: [
                        DataCell(Text(day, style: const TextStyle(fontWeight: FontWeight.bold))),
                        ...List.generate(5, (index) {
                          final period = index + 1;
                          final entry = dayEntries.firstWhere(
                            (e) => e.period == period,
                            orElse: () => TimetableEntry(
                              day: '',
                              startTime: '',
                              endTime: '',
                              subject: '',
                              period: period,
                              classroomId: '',
                            ),
                          );
                          return DataCell(
                            GestureDetector(
                              onLongPress: entry.id != null ? () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Delete Entry?'),
                                    content: Text('Remove ${entry.subject} from $day Period $period?'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
                                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes')),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await _apiService.deleteTimetableEntry(entry.id!);
                                  _loadTimetable();
                                }
                              } : null,
                              child: Text(entry.subject),
                            ),
                          );
                        }),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddEntryDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
