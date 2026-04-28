import 'package:flutter/material.dart';
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import '../models/app_models.dart';
import '../services/api_service.dart';

class ClassroomDetailScreen extends StatefulWidget {
  final Classroom classroom;
  const ClassroomDetailScreen({super.key, required this.classroom});

  @override
  State<ClassroomDetailScreen> createState() => _ClassroomDetailScreenState();
}

class _ClassroomDetailScreenState extends State<ClassroomDetailScreen> {
  final _apiService = ApiService();
  List<Student> _students = [];

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    final data = await _apiService.getStudents(widget.classroom.id!);
    setState(() => _students = data);
  }

  void _showAddStudentDialog() {
    final nameController = TextEditingController();
    final regController = TextEditingController();
    final emailController = TextEditingController();
    String selectedGender = 'Other';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Student'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: regController,
                  decoration: const InputDecoration(labelText: 'Register Number'),
                ),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Student Name'),
                ),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Parent Email (Optional)'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: selectedGender,
                  decoration: const InputDecoration(labelText: 'Gender'),
                  items: ['Male', 'Female', 'Other']
                      .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedGender = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isNotEmpty && regController.text.isNotEmpty) {
                  final student = Student(
                    name: nameController.text,
                    registerNumber: regController.text,
                    gender: selectedGender,
                    classroomId: widget.classroom.id!,
                    parentEmail: emailController.text.trim(),
                  );
                  await _apiService.addStudent(student);
                  if (!mounted) return;
                  Navigator.pop(ctx);
                  _loadStudents();
                }
              },
              child: const Text('Add'),
            )
          ],
        ),
      ),
    );
  }

  void _showEditStudentDialog(Student student) {
    final nameController = TextEditingController(text: student.name);
    final regController = TextEditingController(text: student.registerNumber);
    final emailController = TextEditingController(text: student.parentEmail ?? '');
    String selectedGender = student.gender;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Student'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: regController,
                  decoration: const InputDecoration(labelText: 'Register Number'),
                ),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Student Name'),
                ),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Parent Email (Optional)'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: selectedGender.isEmpty ? 'Other' : selectedGender,
                  decoration: const InputDecoration(labelText: 'Gender'),
                  items: ['Male', 'Female', 'Other']
                      .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedGender = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isNotEmpty && regController.text.isNotEmpty) {
                  final updatedStudent = Student(
                    id: student.id,
                    name: nameController.text,
                    registerNumber: regController.text,
                    gender: selectedGender,
                    classroomId: widget.classroom.id!,
                    parentEmail: emailController.text.trim(),
                  );
                  await _apiService.updateStudent(updatedStudent);
                  if (!mounted) return;
                  Navigator.pop(ctx);
                  _loadStudents();
                }
              },
              child: const Text('Update'),
            )
          ],
        ),
      ),
    );
  }

  Future<void> _uploadExcel() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result != null) {
        List<int>? bytes = result.files.first.bytes;
        if (bytes == null && result.files.first.path != null) {
          bytes = File(result.files.first.path!).readAsBytesSync();
        }

        if (bytes == null) {
          throw 'Could not read file data';
        }

        var excel = Excel.decodeBytes(bytes);
        int count = 0;

        for (var table in excel.tables.keys) {
          var sheet = excel.tables[table];
          if (sheet == null) continue;

          for (int i = 1; i < sheet.maxRows; i++) {
            var row = sheet.rows[i];
            if (row.isEmpty) continue;
            final name = row[1]?.value?.toString() ?? "";
            final reg = row[0]?.value?.toString() ?? ""; // Assuming col 0 is reg
            if (name.isNotEmpty) {
              await _apiService.addStudent(Student(
                name: name,
                registerNumber: reg,
                gender: 'Other',
                classroomId: widget.classroom.id!,
              ));
              count++;
            }
          }
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Imported $count students!')));
          _loadStudents();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.classroom.name} - Students')),
      body: _students.isEmpty
          ? const Center(child: Text('No students yet.\nAdd manually or via Excel.', textAlign: TextAlign.center))
          : ListView.builder(
              itemCount: _students.length,
              itemBuilder: (ctx, i) => Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _students[i].gender == 'Male' 
                        ? Colors.blue.shade100 
                        : _students[i].gender == 'Female' 
                            ? Colors.pink.shade100 
                            : Colors.grey.shade200,
                    child: Icon(
                      _students[i].gender == 'Male' ? Icons.male : 
                      _students[i].gender == 'Female' ? Icons.female : Icons.person,
                      size: 20,
                    ),
                  ),
                  title: Text(_students[i].name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Reg: ${_students[i].registerNumber}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_students[i].gender, style: const TextStyle(color: Colors.grey)),
                      PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'edit') {
                            _showEditStudentDialog(_students[i]);
                          } else if (value == 'delete') {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Delete Student?'),
                                content: Text('Are you sure you want to delete ${_students[i].name}?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
                                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes')),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              await _apiService.deleteStudent(_students[i].id!);
                              _loadStudents();
                            }
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit), title: Text('Edit'))),
                          const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete, color: Colors.red), title: Text('Delete', style: TextStyle(color: Colors.red)))),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            mini: true,
            heroTag: 'upload',
            onPressed: _uploadExcel,
            tooltip: 'Import Excel',
            child: const Icon(Icons.upload_file),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: 'add',
            onPressed: _showAddStudentDialog,
            tooltip: 'Add Student',
            child: const Icon(Icons.person_add),
          ),
        ],
      ),
    );
  }
}
