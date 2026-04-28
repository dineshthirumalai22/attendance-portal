import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_models.dart';
import '../services/api_service.dart';
import 'classroom_detail_screen.dart';

class ClassesScreen extends StatefulWidget {
  const ClassesScreen({super.key});

  @override
  State<ClassesScreen> createState() => _ClassesScreenState();
}

class _ClassesScreenState extends State<ClassesScreen> {
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

  void _addClassDialog() {
    final nameController = TextEditingController();
    final subjectController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Class'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(hintText: 'Enter class name'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: subjectController,
              decoration: const InputDecoration(hintText: 'Enter subject (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                await _apiService.addClassroom(nameController.text, subjectController.text, _userId);
                if (!mounted) return;
                Navigator.pop(ctx);
                _loadClassrooms();
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _editClassDialog(Classroom classroom) {
    final nameController = TextEditingController(text: classroom.name);
    final subjectController = TextEditingController(text: classroom.subject);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Class'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(hintText: 'Enter new class name'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: subjectController,
              decoration: const InputDecoration(hintText: 'Enter new subject'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty && (nameController.text != classroom.name || subjectController.text != classroom.subject)) {
                await _apiService.updateClassroom(classroom.id!, nameController.text, subjectController.text);
                if (!mounted) return;
                Navigator.pop(ctx);
                _loadClassrooms();
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _deleteClassConfirmation(Classroom classroom) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Class'),
        content: Text('Are you sure you want to delete "${classroom.name}"? This will remove all students and attendance records for this class.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              await _apiService.deleteClassroom(classroom.id!);
              if (!mounted) return;
              Navigator.pop(ctx);
              _loadClassrooms();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Classes'),
      ),
      body: _classrooms.isEmpty
          ? const Center(child: Text('No classes added'))
          : ListView.builder(
              itemCount: _classrooms.length,
              itemBuilder: (ctx, index) {
                final classroom = _classrooms[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.class_),
                    ),
                    title: Text(
                      classroom.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: classroom.subject.isNotEmpty ? Text(classroom.subject) : null,
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          _editClassDialog(classroom);
                        } else if (value == 'delete') {
                          _deleteClassConfirmation(classroom);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: ListTile(
                            leading: Icon(Icons.edit, size: 20),
                            title: Text('Rename'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: ListTile(
                            leading: Icon(Icons.delete, color: Colors.red, size: 20),
                            title: Text('Delete', style: TextStyle(color: Colors.red)),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ClassroomDetailScreen(classroom: classroom),
                        ),
                      );
                      _loadClassrooms(); 
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addClassDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
