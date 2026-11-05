import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';

const _animation = Duration(milliseconds: 800);
const _pastAnimation = Duration(milliseconds: 1000);

Future<void> _show(WidgetTester tester, Flushbar flushbar) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => flushbar.show(context),
          child: const Text('show'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('show'));
  await tester.pump();
  await tester.pump(_pastAnimation);
  expect(find.text('hello'), findsOneWidget);
}

Future<void> _dismissAndPump(WidgetTester tester, Flushbar flushbar) async {
  flushbar.dismiss();
  await tester.pump();
  await tester.pump(_pastAnimation);
  expect(find.text('hello'), findsNothing);
}

void main() {
  LeakTesting.enable();
  LeakTesting.settings = LeakTesting.settings.withIgnored(allNotGCed: true);

  testWidgets('plain flushbar does not leak', (tester) async {
    final flushbar = Flushbar(message: 'hello', animationDuration: _animation);
    await _show(tester, flushbar);
    await _dismissAndPump(tester, flushbar);
  });

  testWidgets('pulsing icon does not leak', (tester) async {
    final flushbar = Flushbar(
      message: 'hello',
      animationDuration: _animation,
      icon: const Icon(Icons.info),
    );
    await _show(tester, flushbar);
    await _dismissAndPump(tester, flushbar);
  });

  testWidgets('routeBlur and routeColor do not leak', (tester) async {
    final flushbar = Flushbar(
      message: 'hello',
      animationDuration: _animation,
      routeBlur: 4,
      routeColor: Colors.black54,
    );
    await _show(tester, flushbar);
    await _dismissAndPump(tester, flushbar);
  });

  testWidgets('progress indicator does not leak', (tester) async {
    // The caller owns the controller; the flushbar must not dispose it.
    final controller = AnimationController(
      vsync: const TestVSync(),
      duration: const Duration(seconds: 1),
    );
    final flushbar = Flushbar(
      message: 'hello',
      animationDuration: _animation,
      showProgressIndicator: true,
      progressIndicatorController: controller,
    );
    await _show(tester, flushbar);
    await _dismissAndPump(tester, flushbar);
    controller.dispose();
  });

  testWidgets('flushbar dismissed by its own timer does not leak',
      (tester) async {
    final flushbar = Flushbar(
      message: 'hello',
      animationDuration: _animation,
      duration: const Duration(seconds: 2),
    );
    await _show(tester, flushbar);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    await tester.pump(_pastAnimation);
    expect(find.text('hello'), findsNothing);
  });
}
