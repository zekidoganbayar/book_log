import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'pages/splash_screen.dart';
import 'pages/home_page.dart';
import 'pages/book_detail_page.dart';
import 'pages/add_book_page.dart';
import 'pages/reading_stats_page.dart';
import 'pages/reading_lists_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "", // paste your api key here
      appId: "", //paste your app id here
      messagingSenderId: "", //paste your messaging Sender Id here
      projectId: "", //paste your project id here
    ),
  );
  runApp(const BookLogApp());
}

class BookLogApp extends StatelessWidget {
  const BookLogApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BookLog',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        fontFamily: 'Raleway',
        textTheme: const TextTheme(
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/home': (context) => const HomePage(),
        '/book-detail': (context) => const BookDetailPage(),
        '/add-book': (context) => const AddBookPage(),
        '/reading-stats': (context) => const ReadingStatsPage(),
        '/reading-lists': (context) => const ReadingListsPage(),
      },
    );
  }
}