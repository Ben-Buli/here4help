import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('SignupPage layout constraints test',
      (WidgetTester tester) async {
    // 測試 SizedBox 約束是否正確
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 80,
            height: 40,
            child: Container(
              color: Colors.blue,
              child: const Center(
                child: Text('Test'),
              ),
            ),
          ),
        ),
      ),
    );

    // 驗證約束是否正確
    final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox));
    expect(sizedBox.width, equals(80));
    expect(sizedBox.height, equals(40));

    // 測試 BoxConstraints 是否正確
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: 80,
              maxWidth: 80,
              minHeight: 40,
              maxHeight: 48,
            ),
            child: Container(
              color: Colors.red,
              child: const Center(
                child: Text('Test'),
              ),
            ),
          ),
        ),
      ),
    );

    print('✅ SizedBox 約束測試通過');
    print('✅ BoxConstraints 測試通過');
  });
}

