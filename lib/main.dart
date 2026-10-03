import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'services/audio/player_engine.dart';
import 'services/smb/smb_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final smb = SmbManager();
  await smb.init();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: smb),
        ChangeNotifierProvider(create: (_) => PlayerEngine()),
      ],
      child: const AudiophileApp(),
    ),
  );
}
