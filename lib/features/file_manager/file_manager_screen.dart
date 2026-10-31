import 'package:flutter/material.dart';

/// Lists saved surveys (SQLite `surveys` table + exported JSON files).
/// See lib/services/storage/survey_db.dart for the schema.
class FileManagerScreen extends StatelessWidget {
  const FileManagerScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('File Manager')),
        body: const Center(child: Text('Saved surveys appear here')),
      );
}
