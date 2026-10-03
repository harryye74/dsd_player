import 'package:flutter/material.dart';
import 'ui/home_page.dart';

class AudiophileApp extends StatelessWidget {
  const AudiophileApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '无损 · DSD · SMB 播放器',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121216),
        primaryColor: Colors.amber,
        colorScheme: const ColorScheme.dark(
          primary: Colors.amber,
          secondary: Colors.lightBlue,
          surface: Color(0xFF1c1c22),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF121216),
          elevation: 0,
        ),
      ),
      home: const HomePage(),
    );
  }
}
