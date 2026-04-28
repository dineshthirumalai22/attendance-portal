import 'package:flutter/material.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'classes_screen.dart'; 
import 'attendance_classes_screen.dart';
import 'profile_screen.dart';
import 'timetable_classes_screen.dart';
import 'backup_restore_screen.dart';
import 'report_classes_screen.dart';
import 'add_staff_screen.dart';
import '../services/api_service.dart';
import '../models/app_models.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  UserProfile? _profile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final profile = await ApiService().getProfile(user.uid);
      if (mounted) setState(() => _profile = profile);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 80, // Increased height for two lines and logo
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset('assets/images/bdu.png', fit: BoxFit.contain),
        ),
        title: const Column(
          children: [
            Text('BHARATHIDASAN UNIVERSITY', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text('DEPARTMENT OF COMPUTER SCIENCE', style: TextStyle(fontSize: 12)),
            Text('THIRUCHIRAPPALLI - 620 023', style:TextStyle(fontSize: 10)),
          ],
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_profile != null) ...[
                Row(
                  children: [
                    CircleAvatar(
                      radius: 35,
                      backgroundColor: Colors.indigo.shade100,
                      backgroundImage: _profile!.imagePath != null ? FileImage(File(_profile!.imagePath!)) : null,
                      child: _profile!.imagePath == null
                          ? const Icon(Icons.person, size: 40, color: Colors.indigo)
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome, ${_profile!.name}',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.indigo),
                          ),
                          Text(
                            '${_profile!.designation} @ ${_profile!.institution}',
                            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: [
                  _homeCard(
                    icon: Icons.class_,
                    title: 'Classes',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ClassesScreen())),
                  ),
                  _homeCard(
                    icon: Icons.schedule,
                    title: 'Time Table',
                    onTap: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => const TimetableClassesScreen()));
                      _loadProfile();
                    },
                  ),
                  _homeCard(
                    icon: Icons.analytics,
                    title: 'Reports',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportClassesScreen())),
                  ),
                  _homeCard(
                    icon: Icons.check_circle,
                    title: 'Attendance',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceClassesScreen())),
                  ),
                  _homeCard(
                    icon: Icons.person,
                    title: 'Profile',
                    onTap: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
                      _loadProfile();
                    },
                  ),
                  _homeCard(
                    icon: Icons.backup,
                    title: 'Backup & Restore',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BackupRestoreScreen())),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _homeCard({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color color = Colors.blue,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Card(
        elevation: 5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 50, color: color),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            )
          ],
        ),
      ),
    );
  }
}
