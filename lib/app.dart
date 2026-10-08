import 'package:flutter/material.dart';
import 'features/menu_scanner/screens/home_page.dart';

class MenuTranslate extends StatelessWidget {
  const MenuTranslate({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Menu Translate',

      debugShowCheckedModeBanner: false,

      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}
