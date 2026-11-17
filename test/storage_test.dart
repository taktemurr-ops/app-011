import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:tasarruf_360/core/models.dart';
import 'package:tasarruf_360/core/storage.dart';

SavingsGoal makeGoal([String id='goal'])=>SavingsGoal(id:id,title:'Emergency fund',
  targetMinor:120000,currency:'TRY',owner:'Family',createdAt:DateTime(2026));

void main(){
  late MemorySavingsStorage storage;
  late SavingsController controller;
  setUp(()async{storage=MemorySavingsStorage();controller=SavingsController(storage);await controller.load();});
  tearDown((){controller.dispose();});
  test('state persists and reloads securely through storage boundary',()async{
    await controller.addGoal(makeGoal());
    await controller.contribute('goal',1000);
    final reload=SavingsController(storage);await reload.load();
    expect(reload.data.goals.single.title,'Emergency fund');
    expect(reload.data.savedMinor('goal'),1000);
    reload.dispose();
  });
  test('atomic failed writes never change memory or persisted bytes',()async{
    await controller.addGoal(makeGoal());
    final previous=storage.raw;
    storage.failWrite=true;
    await expectLater(controller.contribute('goal',900),throwsStateError);
    expect(controller.data.savedMinor('goal'),0);
    expect(storage.raw,previous);
  });
  test('queue continues after failed operation',()async{
    await controller.addGoal(makeGoal());
    await expectLater(controller.contribute('missing',900),throwsArgumentError);
    await controller.contribute('goal',500);
    expect(controller.data.savedMinor('goal'),500);
  });
  test('concurrent contributions serialize without loss',()async{
    await controller.addGoal(makeGoal());
    await Future.wait(List.generate(15,(_)=>controller.contribute('goal',100)));
    expect(controller.data.savedMinor('goal'),1500);
    expect(controller.data.movements.length,15);
  });
  test('cannot withdraw beyond balance',()async{
    await controller.addGoal(makeGoal());
    await expectLater(controller.contribute('goal',100,withdraw:true),throwsStateError);
    await controller.contribute('goal',200);
    await controller.contribute('goal',100,withdraw:true);
    expect(controller.data.savedMinor('goal'),100);
  });
  test('deleting goal cascades only linked transactions and rules',()async{
    await controller.addGoal(makeGoal());await controller.addGoal(makeGoal('other'));
    await controller.contribute('goal',100);
    await controller.addRule(SavingsRule(id:'rule',goalId:'goal',amountMinor:50,
      frequency:'monthly',nextDue:DateTime(2026,1)));
    await controller.deleteGoal('goal');
    expect(controller.data.goals.single.id,'other');
    expect(controller.data.movements,isEmpty);expect(controller.data.rules,isEmpty);
  });
  test('manual scheduled contribution advances date exactly once',()async{
    await controller.addGoal(makeGoal());
    await controller.addRule(SavingsRule(id:'rule',goalId:'goal',amountMinor:700,
      frequency:'monthly',nextDue:DateTime(2026,1,31)));
    await controller.confirmScheduledDeposit('rule');
    expect(controller.data.savedMinor('goal'),700);
    expect(controller.data.rules.single.nextDue,DateTime(2026,2,28));
  });
  test('cannot execute future or disabled recurring plan',()async{
    await controller.addGoal(makeGoal());
    await controller.addRule(SavingsRule(id:'future',goalId:'goal',amountMinor:200,
      frequency:'weekly',nextDue:DateTime(2099)));
    await expectLater(controller.confirmScheduledDeposit('future'),throwsStateError);
    await controller.toggleRule('future');
    await expectLater(controller.confirmScheduledDeposit('future'),throwsStateError);
  });
  test('todo challenge and toggles survive restore',()async{
    await controller.addTask('No spend day');
    final task=controller.data.tasks.single;
    await controller.toggleTask(task.id);
    final reloaded=SavingsController(storage);await reloaded.load();
    expect(reloaded.data.tasks.single.done,isTrue);
    reloaded.dispose();
  });
  test('export import round trip preserves exact positive minor units',()async{
    await controller.addGoal(makeGoal());
    await controller.contribute('goal',32145,note:'تنظيم € 🇹🇷');
    final json=controller.exportJson();
    final second=SavingsController(MemorySavingsStorage());await second.load();
    await second.importJson(json);
    expect(second.data.savedMinor('goal'),32145);
    expect(second.data.movements.single.note,'تنظيم € 🇹🇷');
    second.dispose();
  });
  test('wrong product import fails without overwriting previous data',()async{
    await controller.addGoal(makeGoal());
    final previous=storage.raw;
    await expectLater(controller.importJson(jsonEncode({'product':'other'})),throwsFormatException);
    expect(storage.raw,previous);expect(controller.data.goals.length,1);
  });
  test('malformed import never partially commits',()async{
    await controller.addGoal(makeGoal());
    final previous=storage.raw;
    final malformed=jsonDecode(controller.exportJson()) as Map<String,dynamic>;
    malformed['movements']=[{'goalId':'missing'}];
    await expectLater(controller.importJson(jsonEncode(malformed)),throwsFormatException);
    expect(storage.raw,previous);
  });
  test('corrupt disk remains untouched and mutations are blocked',()async{
    storage.raw='garbled';
    final c=SavingsController(storage);await c.load();
    expect(c.error,isNotNull);
    await expectLater(c.addGoal(makeGoal()),throwsStateError);
    expect(storage.raw,'garbled');
    c.dispose();
  });
  test('clear all removes storage then memory',()async{
    await controller.addGoal(makeGoal());await controller.clearAll();
    expect(storage.raw,isNull);expect(controller.data.goals,isEmpty);
  });
  test('failed delete preserves state and persisted bytes',()async{
    await controller.addGoal(makeGoal());
    final previous=storage.raw;storage.failDelete=true;
    await expectLater(controller.clearAll(),throwsStateError);
    expect(controller.data.goals.length,1);expect(storage.raw,previous);
  });
  test('can edit template target and owner while preserving savings',()async{
    await controller.addGoal(makeGoal());
    await controller.contribute('goal',1500);
    await controller.updateGoal(makeGoal().copyWith(title:'Revised',owner:'Partner',
      targetMinor:450000,monthlyPlanMinor:10000));
    expect(controller.data.goals.single.title,'Revised');
    expect(controller.data.goals.single.owner,'Partner');
    expect(controller.data.savedMinor('goal'),1500);
  });
  test('cannot shrink goal target below saved balance',()async{
    await controller.addGoal(makeGoal());await controller.contribute('goal',4500);
    await expectLater(controller.updateGoal(makeGoal().copyWith(targetMinor:2000)),throwsStateError);
    expect(controller.data.goals.single.targetMinor,120000);
  });
  test('undo withdrawal and deposit without creating negative savings',()async{
    await controller.addGoal(makeGoal());
    await controller.contribute('goal',4000);
    final depositId=controller.data.movements.single.id;
    await controller.contribute('goal',1000,withdraw:true);
    await expectLater(controller.removeMovement(depositId),throwsStateError);
    expect(controller.data.savedMinor('goal'),3000);
    final withdrawal=controller.data.movements.first.id;
    await controller.removeMovement(withdrawal);
    await controller.removeMovement(depositId);
    expect(controller.data.savedMinor('goal'),0);
  });
}
