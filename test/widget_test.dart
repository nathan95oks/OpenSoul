import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/screens/home_screen.dart';
import 'package:lsb_legal_app/app/splash_screen.dart';
import 'package:lsb_legal_app/app/app.dart';

void main() {
  testWidgets('App load smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: AppScope()));

    // Verify that the SplashScreen is rendered.
    expect(find.byType(SplashScreen), findsOneWidget);

    // Advance time by 3 seconds to let the splash screen Timer fire and navigate
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();

    // Verify that the HomeScreen is rendered after splash transitions.
    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
