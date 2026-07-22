import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lsb_legal_app/app/main_navigation_screen.dart';
import 'package:lsb_legal_app/app/splash_screen.dart';
import 'package:lsb_legal_app/app/app.dart';
import 'package:lsb_legal_app/features/conversation/presentation/screens/conversation_screen.dart';

void main() {
  testWidgets('App load smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: AppScope()));

    // Verify that the SplashScreen is rendered.
    expect(find.byType(SplashScreen), findsOneWidget);

    // Advance time by 3 seconds to let the splash screen Timer fire and navigate
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();

    // Tras el splash se aterriza en la navegación principal, cuya pestaña
    // por defecto es la Conversación — el centro de la app unificada.
    // (IndexedStack es lazy: las demás pestañas se construyen al visitarlas.)
    expect(find.byType(MainNavigationScreen), findsOneWidget);
    expect(find.byType(ConversationScreen), findsOneWidget);
  });
}
