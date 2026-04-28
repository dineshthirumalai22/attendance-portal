import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_models.dart';
import '../services/api_service.dart';
import 'report_screen.dart';

class ReportClassesScreen extends StatefulWidget {
  const ReportClassesScreen({super.key});

  @override
  State<ReportClassesScreen> createState() => _ReportClassesScreenState();
}

class _ReportClassesScreenState extends State<ReportClassesScreen> {
  final _apiService = ApiService();
  final _userId = FirebaseAuth.instance.currentUser?.uid ?? '';
  List<Classroom> _classrooms = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadClassrooms();
  }

  Future<void> _loadClassrooms() async {
    setState(() => _isLoading = true);
    if (_userId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }
    final data = await _apiService.getClassrooms(_userId);
    setState(() {
      _classrooms = data;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Class for Reports')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _classrooms.isEmpty
              ? const Center(child: Text('No classes found.\nCreate a class in "Classes" first.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _classrooms.length,
                  itemBuilder: (ctx, index) => Card(
                    elevation: 3,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: const CircleAvatar(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        child: Icon(Icons.analytics_outlined),
                      ),
                      title: Text(
                        _classrooms[index].name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      subtitle: const Text('Tap to view attendance report'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ReportScreen(classroom: _classrooms[index]),
                          ),
                        );
                      },
                    ),
                  ),
                ),
    );
  }
}
