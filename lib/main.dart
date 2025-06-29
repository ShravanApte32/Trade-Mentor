import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // 👈 Make sure this is added in pubspec.yaml
import 'screens/home_screen.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: HomeScreen(),
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light().copyWith(
        primaryColor: Colors.indigo,
        scaffoldBackgroundColor: Color(0xFFF7F9FC),
        textTheme: GoogleFonts.poppinsTextTheme(), // Optional: Poppins font
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.indigo[800],
          foregroundColor: Colors.white,
          elevation: 4,
          iconTheme: IconThemeData(color: Colors.white),
        ),
        dropdownMenuTheme: DropdownMenuThemeData(
          inputDecorationTheme: InputDecorationTheme(
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }
}
