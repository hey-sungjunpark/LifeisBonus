import 'package:flutter/material.dart';

class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          color: Color(0xFF8A8A8A),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
