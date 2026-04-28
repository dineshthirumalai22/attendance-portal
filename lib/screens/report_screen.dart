import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/app_models.dart';
import '../services/api_service.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:path/path.dart' as p;

class ReportScreen extends StatefulWidget {
  final Classroom classroom;
  const ReportScreen({super.key, required this.classroom});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _apiService = ApiService();
  List<Map<String, dynamic>> _summary = [];
  List<Map<String, dynamic>> _dateSummary = [];
  List<Map<String, dynamic>> _monthSummary = [];
  List<Map<String, dynamic>> _rawAttendance = [];
  bool _isLoading = true;
  
  DateTimeRange? _selectedDateRange;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAllSummaries();
  }

  Future<void> _loadAllSummaries() async {
    setState(() => _isLoading = true);
    
    String? startStr = _selectedDateRange?.start != null 
        ? DateFormat('yyyy-MM-dd').format(_selectedDateRange!.start) 
        : null;
    String? endStr = _selectedDateRange?.end != null 
        ? DateFormat('yyyy-MM-dd').format(_selectedDateRange!.end) 
        : null;

    try {
      final rawData = await _apiService.getRawAttendance(widget.classroom.id!);
      
      // Local aggregation for summaries since we switched to Firebase
      Map<String, Map<String, dynamic>> dateMap = {};
      Map<String, Map<String, dynamic>> monthMap = {};
      Map<String, Map<String, dynamic>> studentSummaryMap = {};

      for (var record in rawData) {
        final date = record['date'] as String;
        final month = date.substring(0, 7); // YYYY-MM
        final status = record['is_present'] as int;
        final sId = record['student_id']?.toString() ?? '';

        // Filter by date range
        if (startStr != null && date.compareTo(startStr) < 0) continue;
        if (endStr != null && date.compareTo(endStr) > 0) continue;

        // Date-wise agg
        dateMap.putIfAbsent(date, () => {'date': date, 'present_count': 0, 'absent_count': 0, 'leave_count': 0, 'od_count': 0});
        if (status == 1) dateMap[date]!['present_count']++;
        else if (status == 0) dateMap[date]!['absent_count']++;
        else if (status == 2) dateMap[date]!['leave_count']++;
        else if (status == 3) dateMap[date]!['od_count']++;

        // Month-wise agg
        monthMap.putIfAbsent(month, () => {'month': month, 'present_count': 0, 'absent_count': 0, 'leave_count': 0, 'od_count': 0, 'total_attendance': 0});
        monthMap[month]!['total_attendance']++;
        if (status == 1) monthMap[month]!['present_count']++;
        else if (status == 0) monthMap[month]!['absent_count']++;
        else if (status == 2) monthMap[month]!['leave_count']++;
        else if (status == 3) monthMap[month]!['od_count']++;

        // Student summary agg
        studentSummaryMap.putIfAbsent(sId, () => {'student_id': sId, 'student_name': record['student_name'], 'present_count': 0, 'absent_count': 0, 'leave_count': 0, 'od_count': 0, 'total_days': 0});
        studentSummaryMap[sId]!['total_days']++;
        if (status == 1) studentSummaryMap[sId]!['present_count']++;
        else if (status == 0) studentSummaryMap[sId]!['absent_count']++;
        else if (status == 2) studentSummaryMap[sId]!['leave_count']++;
        else if (status == 3) studentSummaryMap[sId]!['od_count']++;
      }

      setState(() {
        _rawAttendance = rawData;
        _dateSummary = dateMap.values.toList()..sort((a, b) => b['date'].compareTo(a['date']));
        _monthSummary = monthMap.values.toList()..sort((a, b) => b['month'].compareTo(a['month']));
        _summary = studentSummaryMap.values.toList();
        _isLoading = false;
      });
    } catch (e) {
      print("Error loading reports: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: _selectedDateRange,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.indigo,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDateRange) {
      setState(() => _selectedDateRange = picked);
      _loadAllSummaries();
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedDateRange = null;
      _searchQuery = '';
      _searchController.clear();
    });
    _loadAllSummaries();
  }

@override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Attendance Reports'),
          actions: [
            IconButton(
              icon: const Icon(Icons.filter_list),
              tooltip: 'Select Date Range',
              onPressed: _selectDateRange,
            ),
            if (_selectedDateRange != null)
              IconButton(
                icon: const Icon(Icons.filter_list_off),
                tooltip: 'Clear Filters',
                onPressed: _clearFilters,
              ),
            IconButton(
              icon: const Icon(Icons.download),
              tooltip: 'Export to Excel',
              onPressed: _exportToExcel,
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'By Date', icon: Icon(Icons.calendar_today)),
              Tab(text: 'Month-wise', icon: Icon(Icons.calendar_month)),
              Tab(text: 'Full Report', icon: Icon(Icons.grid_on)),
            ],
          ),
        ),
        body: Column(
          children: [
            if (_selectedDateRange != null)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                color: Colors.indigo.shade50,
                width: double.infinity,
                child: Row(
                  children: [
                    const Icon(Icons.date_range, size: 16, color: Colors.indigo),
                    const SizedBox(width: 8),
                    Text(
                      'Filtered: ${DateFormat('dd MMM').format(_selectedDateRange!.start)} - ${DateFormat('dd MMM yyyy').format(_selectedDateRange!.end)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      children: [
                        _buildDateSummary(),
                        _buildMonthSummary(),
                        _buildFullReport(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSummary() {
    if (_dateSummary.isEmpty) {
      return const Center(child: Text('No attendance records found'));
    }
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 25,
          headingRowColor: WidgetStateProperty.all(Colors.indigo.shade50),
          columns: const [
            DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Present', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green))),
            DataColumn(label: Text('Absent', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red))),
            DataColumn(label: Text('Leave', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange))),
            DataColumn(label: Text('OD', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple))),
            DataColumn(label: Text('Daily %', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: _dateSummary.map((row) {
            final dateStr = row['date'] ?? '';
            final present = row['present_count'] ?? 0;
            final absent = row['absent_count'] ?? 0;
            final od = row['od_count'] ?? 0;
            final total = present + absent + od;
            
            final dt = DateTime.tryParse(dateStr) ?? DateTime.now();
            final formattedDate = DateFormat('dd MMM yyyy').format(dt);
            final percent = total == 0 ? 0.0 : ((present + od) / total) * 100;

            return DataRow(cells: [
              DataCell(Text(formattedDate)),
              DataCell(Text(present.toString(), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
              DataCell(Text(absent.toString(), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
              DataCell(Text(row['leave_count']?.toString() ?? '0', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold))),
              DataCell(Text(od.toString(), style: const TextStyle(color: Colors.purple, fontWeight: FontWeight.bold))),
              DataCell(
                Text(
                  '${percent.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: percent >= 75 ? Colors.green : Colors.red,
                  ),
                ),
              ),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildMonthSummary() {
    if (_monthSummary.isEmpty) {
      return const Center(child: Text('No monthly records found'));
    }
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 25,
          headingRowColor: WidgetStateProperty.all(Colors.indigo.shade50),
          columns: const [
            DataColumn(label: Text('Month', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Total Records', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('P', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green))),
            DataColumn(label: Text('A', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red))),
            DataColumn(label: Text('L', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange))),
            DataColumn(label: Text('OD', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple))),
            DataColumn(label: Text('Avg %', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: _monthSummary.map((row) {
            final monthStr = row['month'] ?? ''; // YYYY-MM
            final present = row['present_count'] ?? 0;
            final absent = row['absent_count'] ?? 0;
            final od = row['od_count'] ?? 0;
            final total = row['total_attendance'] ?? 0;
            
            final dt = DateFormat('yyyy-MM').parse(monthStr);
            final formattedMonth = DateFormat('MMMM yyyy').format(dt);
            final percent = (present + absent + od) == 0 ? 0.0 : ((present + od) / (present + absent + od)) * 100;

            return DataRow(cells: [
              DataCell(Text(formattedMonth, style: const TextStyle(fontWeight: FontWeight.bold))),
              DataCell(Text(total.toString())),
              DataCell(Text(present.toString(), style: const TextStyle(color: Colors.green))),
              DataCell(Text(absent.toString(), style: const TextStyle(color: Colors.red))),
              DataCell(Text(row['leave_count']?.toString() ?? '0', style: const TextStyle(color: Colors.orange))),
              DataCell(Text(od.toString(), style: const TextStyle(color: Colors.purple))),
              DataCell(
                Text(
                  '${percent.toStringAsFixed(1)}%',
                  style: TextStyle(fontWeight: FontWeight.bold, color: percent >= 75 ? Colors.green : Colors.red),
                ),
              ),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, Color color) {
    return Expanded(
      child: Card(
        elevation: 2,
        color: color.withOpacity(0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Column(
            children: [
              Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportToExcel() async {
    print("Exporting to Excel. Date Summary length: ${_dateSummary.length}");
    if (_dateSummary.isEmpty && _monthSummary.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No attendance data available to export')));
      return;
    }

    try {
      final excel = Excel.createExcel();
      
      // Remove default sheet if it exists
      if (excel.sheets.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }

      // 1. Monthly Summary Sheet
      if (_monthSummary.isNotEmpty) {
        final Sheet sheetM = excel['Monthly Summary'];
        sheetM.appendRow([
          TextCellValue('Month'),
          TextCellValue('Total Records'),
          TextCellValue('Present'),
          TextCellValue('Absent'),
          TextCellValue('Leave'),
          TextCellValue('OD'),
          TextCellValue('Average %'),
        ]);
        
        for (var row in _monthSummary) {
          final present = row['present_count'] ?? 0;
          final absent = row['absent_count'] ?? 0;
          final leave = row['leave_count'] ?? 0;
          final od = row['od_count'] ?? 0;
          final total = row['total_attendance'] ?? (present + absent + leave + od);
          final percent = (present + absent + od) == 0 ? 0.0 : ((present + od) / (present + absent + od)) * 100;
          
          sheetM.appendRow([
            TextCellValue(row['month']?.toString() ?? ''),
            IntCellValue(total),
            IntCellValue(present),
            IntCellValue(absent),
            IntCellValue(leave),
            IntCellValue(od),
            TextCellValue('${percent.toStringAsFixed(1)}%'),
          ]);
        }
      }

      // 2. Daily Detail Sheet
      if (_dateSummary.isNotEmpty) {
        final Sheet sheetD = excel['Daily Detail'];
        sheetD.appendRow([
          TextCellValue('Month'),
          TextCellValue('Date'),
          TextCellValue('Present'),
          TextCellValue('Absent'),
          TextCellValue('Leave'),
          TextCellValue('OD'),
          TextCellValue('Daily %'),
        ]);
        
        for (var row in _dateSummary) {
          final dateStr = row['date'] ?? '';
          final dt = DateTime.tryParse(dateStr) ?? DateTime.now();
          final present = row['present_count'] ?? 0;
          final absent = row['absent_count'] ?? 0;
          final od = row['od_count'] ?? 0;
          final total = present + absent + od;
          final percent = total == 0 ? 0.0 : ((present + od) / total) * 100;
          
          sheetD.appendRow([
            TextCellValue(DateFormat('MMMM yyyy').format(dt)),
            TextCellValue(DateFormat('dd MMM yyyy').format(dt)),
            IntCellValue(present),
            IntCellValue(absent),
            IntCellValue(row['leave_count'] ?? 0),
            IntCellValue(od),
            TextCellValue('${percent.toStringAsFixed(1)}%'),
          ]);
        }
      }

      // 3. Attendance Matrix
      List<Map<String, dynamic>> filteredRaw = _rawAttendance;
      if (_selectedDateRange != null) {
        filteredRaw = _rawAttendance.where((r) {
          final dt = DateTime.tryParse(r['date'] as String) ?? DateTime.now();
          return dt.isAfter(_selectedDateRange!.start.subtract(const Duration(days: 1))) &&
                 dt.isBefore(_selectedDateRange!.end.add(const Duration(days: 1)));
        }).toList();
      }

      if (filteredRaw.isNotEmpty) {
        final Sheet sheetMatrix = excel['Attendance Matrix'];
        final dates = filteredRaw.map((e) => e['date'] as String).toSet().toList();
        dates.sort();
        final students = <String, String>{};
        for (var record in filteredRaw) {
          students[record['student_id']?.toString() ?? ''] = record['student_name'] as String;
        }
        final studentIds = students.keys.toList();
        studentIds.sort((a, b) => students[a]!.compareTo(students[b]!));

        // Header
        sheetMatrix.appendRow([
          TextCellValue('Student Name'),
          ...dates.map((d) => TextCellValue(DateFormat('dd/MM').format(DateTime.parse(d)))),
        ]);

        // Rows
        final matrixMap = <String, Map<String, int>>{};
        for (var record in filteredRaw) {
          final sId = record['student_id']?.toString() ?? '';
          final date = record['date'] as String;
          final status = record['is_present'] as int;
          matrixMap.putIfAbsent(sId, () => {})[date] = status;
        }

        for (var sId in studentIds) {
          List<CellValue> rowValues = [TextCellValue(students[sId]!)];
          for (var date in dates) {
            final status = matrixMap[sId]?[date];
            String val = '-';
            if (status == 1) val = 'P';
            else if (status == 0) val = 'A';
            else if (status == 2) val = 'L';
            else if (status == 3) val = 'OD';
            rowValues.add(TextCellValue(val));
          }
          sheetMatrix.appendRow(rowValues);
        }
      }

      // 4. Student Monthly Summary Sheet (Student vs Month)
      if (_rawAttendance.isNotEmpty) {
        final Sheet sheetStudentMonthly = excel['Student Monthly Summary'];
        
        final studentNames = <String, String>{};
        final months = <String>{};
        final studentMonthMatrix = <String, Map<String, List<int>>>{}; // studentId -> {month -> [isPresent values]}

        for (var record in _rawAttendance) {
          final sId = record['student_id']?.toString() ?? '';
          final sName = record['student_name'] as String;
          final dateStr = record['date'] as String;
          final isPresent = record['is_present'] as int;
          
          final dt = DateTime.tryParse(dateStr) ?? DateTime.now();
          final monthKey = DateFormat('MMM yyyy').format(dt);
          
          studentNames[sId] = sName;
          months.add(monthKey);
          
          studentMonthMatrix.putIfAbsent(sId, () => {});
          studentMonthMatrix[sId]!.putIfAbsent(monthKey, () => []);
          studentMonthMatrix[sId]![monthKey]!.add(isPresent);
        }

        final sortedMonths = months.toList()..sort((a, b) {
          final df = DateFormat('MMM yyyy');
          return df.parse(a).compareTo(df.parse(b));
        });
        final sortedStudentIds = studentNames.keys.toList()..sort((a, b) => studentNames[a]!.compareTo(studentNames[b]!));

        // Header
        sheetStudentMonthly.appendRow([
          TextCellValue('Student Name'),
          ...sortedMonths.map((m) => TextCellValue(m)),
          TextCellValue('Overall %'),
        ]);

        // Rows
        for (var sId in sortedStudentIds) {
          List<CellValue> row = [TextCellValue(studentNames[sId]!)];
          int totalPresentAll = 0;
          int totalRecordsAll = 0;

          for (var month in sortedMonths) {
            final records = studentMonthMatrix[sId]?[month] ?? [];
            if (records.isEmpty) {
              row.add(TextCellValue('-'));
            } else {
              final present = records.where((r) => r == 1).length;
              final absent = records.where((r) => r == 0).length;
              final od = records.where((r) => r == 3).length;
              final monthTotal = present + absent + od;
              final monthPercent = monthTotal == 0 ? 0.0 : ((present + od) / monthTotal) * 100;
              
              totalPresentAll += (present + od);
              totalRecordsAll += monthTotal;
              
              row.add(TextCellValue('${monthPercent.toStringAsFixed(1)}%'));
            }
          }

          final overallPercent = totalRecordsAll == 0 ? 0.0 : (totalPresentAll / totalRecordsAll) * 100;
          row.add(TextCellValue('${overallPercent.toStringAsFixed(1)}%'));
          sheetStudentMonthly.appendRow(row);
        }
      }

      final directory = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
      String filterSuffix = _selectedDateRange != null 
          ? '_Filtered_${DateFormat('yyyyMMdd').format(_selectedDateRange!.start)}' 
          : '';
      final fileName = 'Attendance_${widget.classroom.name.replaceAll(RegExp(r'[^\w\s-]'), '')}$filterSuffix.xlsx';
      final filePath = p.join(directory.path, fileName);
      final fileBytes = excel.encode();
      
      if (fileBytes != null) {
        final file = File(filePath);
        await file.create(recursive: true);
        await file.writeAsBytes(fileBytes);
        print("Excel file saved at: $filePath, Size: ${fileBytes.length}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Report exported to: $filePath')),
        );
      } else {
        throw Exception("Failed to encode Excel file");
      }
    } catch (e, stack) {
      print("Export error: $e");
      print(stack);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  Widget _buildFullReport() {
    if (_rawAttendance.isEmpty) {
      return const Center(child: Text('No attendance records found'));
    }

    // Filter raw attendance by date range if selected
    List<Map<String, dynamic>> filteredRaw = _rawAttendance;
    if (_selectedDateRange != null) {
      filteredRaw = _rawAttendance.where((r) {
        final dt = DateTime.tryParse(r['date'] as String) ?? DateTime.now();
        return dt.isAfter(_selectedDateRange!.start.subtract(const Duration(days: 1))) &&
               dt.isBefore(_selectedDateRange!.end.add(const Duration(days: 1)));
      }).toList();
    }

    if (filteredRaw.isEmpty) {
      return const Center(child: Text('No attendance for the selected range'));
    }

    // Get unique sorted dates
    final dates = filteredRaw.map((e) => e['date'] as String).toSet().toList();
    dates.sort();

    // Get unique students
    final students = <String, String>{};
    for (var record in filteredRaw) {
      final sId = record['student_id']?.toString() ?? '';
      students[sId] = record['student_name'] as String;
    }
    final studentIds = students.keys.toList();
    studentIds.sort((a, b) => students[a]!.compareTo(students[b]!));

    // Map records for easy lookup: {studentId: {date: status}}
    final matrix = <String, Map<String, int>>{};
    for (var record in filteredRaw) {
      final sId = record['student_id']?.toString() ?? '';
      final date = record['date'] as String;
      final status = record['is_present'] as int;
      matrix.putIfAbsent(sId, () => {})[date] = status;
    }

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 15,
          headingRowColor: WidgetStateProperty.all(Colors.indigo.shade50),
          dividerThickness: 0.5,
          columns: [
            const DataColumn(label: Text('Student', style: TextStyle(fontWeight: FontWeight.bold))),
            const DataColumn(label: Text('%', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo))),
            ...dates.map((date) {
              final dt = DateTime.tryParse(date) ?? DateTime.now();
              return DataColumn(
                label: Text(
                  DateFormat('dd/MM').format(dt),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.indigo),
                ),
              );
            }),
          ],
          rows: studentIds.map((sId) {
            final studentAttendance = matrix[sId] ?? {};
            final presentCount = studentAttendance.values.where((v) => v == 1 || v == 3).length;
            final totalMarked = studentAttendance.values.length;
            final percent = totalMarked == 0 ? 0.0 : (presentCount / totalMarked) * 100;

            return DataRow(cells: [
              DataCell(Text(students[sId]!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
              DataCell(
                Text(
                  '${percent.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: percent >= 75 ? Colors.green : Colors.red,
                  ),
                ),
              ),
              ...dates.map((date) {
                final status = matrix[sId]?[date];
                String text = '-';
                Color color = Colors.grey;
                Color bgColor = Colors.transparent;
                if (status == 1) {
                  text = 'P';
                  color = Colors.green.shade700;
                  bgColor = Colors.green.shade50;
                } else if (status == 0) {
                  text = 'A';
                  color = Colors.red.shade700;
                  bgColor = Colors.red.shade50;
                } else if (status == 2) {
                  text = 'L';
                  color = Colors.orange.shade700;
                  bgColor = Colors.orange.shade50;
                } else if (status == 3) {
                  text = 'OD';
                  color = Colors.purple.shade700;
                  bgColor = Colors.purple.shade50;
                }
                return DataCell(
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(4)),
                    child: Text(
                      text,
                      style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                );
              }),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  Widget _statItem(String label, dynamic count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}
