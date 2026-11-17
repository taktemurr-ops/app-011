import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tasarruf_360/main.dart';
import 'package:tasarruf_360/core/storage.dart';

void main(){
  testWidgets('renders offline savings dashboard and empty goal state',(tester)async{
    await tester.pumpWidget(Tasarruf360App(storage:MemorySavingsStorage()));
    await tester.pumpAndSettle();
    expect(find.text('Savings 360'),findsWidgets);
    expect(find.text('Create your first savings goal.'),findsOneWidget);
    expect(find.byType(NavigationBar),findsOneWidget);
  });
  testWidgets('goal screen launches functional creation dialog',(tester)async{
    await tester.pumpWidget(Tasarruf360App(storage:MemorySavingsStorage()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Goals').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('New goal').last);
    await tester.pumpAndSettle();
    expect(find.text('Goal name'),findsOneWidget);
    expect(find.text('Target amount (TRY)'),findsOneWidget);
  });
  testWidgets('read failure presents safe recovery state instead of overwriting',(tester)async{
    final storage=MemorySavingsStorage()..raw='corrupt';
    await tester.pumpWidget(Tasarruf360App(storage:storage));
    await tester.pumpAndSettle();
    expect(find.text('Encrypted data could not be read and was not overwritten.'),findsOneWidget);
    expect(storage.raw,'corrupt');
  });
}
