import 'package:flutter/material.dart';

class OwnerRegisterScreen extends StatelessWidget {
  const OwnerRegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF059669),
        foregroundColor: Colors.white,
        title: const Text('Owner Registration'),
        centerTitle: true,
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.construction, size: 64, color: Color(0xFF059669)),
              SizedBox(height: 16),
              Text(
                'Coming in Sprint 5',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B)),
              ),
              SizedBox(height: 8),
              Text(
                'Owner registration with GSTIN, restaurant details, and document upload will be available in the next sprint.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
