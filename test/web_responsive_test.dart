import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayfound/core/widgets/web_responsive_wrapper.dart';

void main() {
  group('WebResponsiveWrapper (T1)', () {
    testWidgets('limits content width to 720 at 1200-wide surface', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: WebResponsiveWrapper(
            child: Builder(
              builder: (context) {
                return Container(
                  key: const Key('child_box'),
                  color: Colors.blue,
                );
              },
            ),
          ),
        ),
      );

      final childBox = tester.getRect(find.byKey(const Key('child_box')));
      expect(childBox.width, equals(720.0));
    });

    testWidgets(
      'does not constrain content width below 720 at 400-wide surface',
      (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            home: WebResponsiveWrapper(
              child: Builder(
                builder: (context) {
                  return Container(
                    key: const Key('child_box'),
                    color: Colors.blue,
                  );
                },
              ),
            ),
          ),
        );

        final childBox = tester.getRect(find.byKey(const Key('child_box')));
        expect(childBox.width, equals(400.0));
      },
    );
  });
}
