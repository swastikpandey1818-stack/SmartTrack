import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_track/domain/plant_logic.dart';
import 'package:smart_track/ui/widgets/animated_plant.dart';

void main() {
  for (final state in PlantState.values) {
    testWidgets('AnimatedPlant renders and animates in $state', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: SizedBox(width: 360, child: AnimatedPlant(state: state))),
      ));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(AnimatedPlant), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  test('every state has a visual', () {
    for (final s in PlantState.values) {
      expect(PlantVisual.of(s).title, isNotEmpty);
    }
  });
}
