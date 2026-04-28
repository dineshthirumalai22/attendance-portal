import 'dart:io';
import 'package:http/http.dart' as http;

Future<void> main() async {
  final url = Uri.parse('https://www.bdu.ac.in/forms/logo/emp-png.png');
  final response = await http.get(url);
  
  if (response.statusCode == 200) {
    final file = File('assets/images/logo.png');
    await file.writeAsBytes(response.bodyBytes);
    print('Logo downloaded successfully.');
  } else {
    print('Failed to download logo. Status code: ${response.statusCode}');
    exit(1);
  }
}
