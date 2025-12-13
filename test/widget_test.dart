import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:metabolicapp/main.dart';

void main() {
  testWidgets('App builds without crashing', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MetabolicHealthApp()),
    );

    // basic smoke test
    expect(find.byType(MetabolicHealthApp), findsOneWidget);
  });
}
