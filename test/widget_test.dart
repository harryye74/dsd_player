import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:dsd_player/app.dart';
import 'package:dsd_player/services/audio/player_engine.dart';
import 'package:dsd_player/services/smb/smb_manager.dart';

void main() {
  testWidgets('app launches and shows title', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => SmbManager()),
          ChangeNotifierProvider(create: (_) => PlayerEngine()),
        ],
        child: const AudiophileApp(),
      ),
    );
    expect(find.text('无损 · DSD · SMB 播放器'), findsOneWidget);
  });
}
