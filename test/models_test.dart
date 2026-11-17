import 'package:flutter_test/flutter_test.dart';
import 'package:tasarruf_360/core/models.dart';

SavingsGoal exampleGoal([String id='g1']) => SavingsGoal(id:id,title:'Emergency fund',
  targetMinor:20000,currency:'TRY',owner:'Family',createdAt:DateTime(2026,1),
  monthlyPlanMinor:1500);
SavingsMovement movement(String id,int amount,{String kind='deposit',String goal='g1'}) =>
  SavingsMovement(id:id,goalId:goal,amountMinor:amount,kind:kind,when:DateTime(2026,1));

void main(){
  test('empty ledger round-trips',(){
    final data=SavingsLedger.fromJson(const SavingsLedger().toJson());
    expect(data.goals,isEmpty);expect(data.savedMinor('unknown'),0);
  });
  test('goal and transaction round-trip',(){
    final ledger=SavingsLedger(profile:'The family',goals:[exampleGoal()],
      movements:[movement('e1',10000),movement('e2',1500,kind:'withdrawal')]);
    final restored=SavingsLedger.fromJson(ledger.toJson());
    expect(restored.savedMinor('g1'),8500);
    expect(restored.remainingMinor(restored.goals.first),11500);
    expect(restored.progress(restored.goals.first),closeTo(0.425,0.0001));
    expect(restored.totalSaved('TRY'),8500);
  });
  test('progress saturates above one',(){
    final ledger=SavingsLedger(goals:[exampleGoal()],movements:[movement('1',25000)]);
    expect(ledger.progress(ledger.goals.single),1.0);
    expect(ledger.remainingMinor(ledger.goals.single),0);
  });
  test('blocks duplicate goal and transaction IDs',(){
    final g=exampleGoal();
    expect(()=>SavingsLedger.fromJson(SavingsLedger(goals:[g,g]).toJson()),throwsFormatException);
    expect(()=>SavingsLedger.fromJson(SavingsLedger(goals:[g],
      movements:[movement('x',100),movement('x',200)]).toJson()),throwsFormatException);
  });
  test('blocks unknown goal references',(){
    final ledger=SavingsLedger(goals:[exampleGoal()],movements:[movement('a',100,goal:'missing')]);
    expect(()=>SavingsLedger.fromJson(ledger.toJson()),throwsFormatException);
  });
  test('blocks overdrawn imported savings history',(){
    final ledger=SavingsLedger(goals:[exampleGoal()],movements:[movement('a',100,kind:'withdrawal')]);
    expect(()=>SavingsLedger.fromJson(ledger.toJson()),throwsFormatException);
  });
  test('blocks unknown schema and invalid currency',(){
    final base=const SavingsLedger().toJson();
    expect(()=>SavingsLedger.fromJson({...base,'schemaVersion':2}),throwsFormatException);
    final incorrect=exampleGoal().toJson()..['currency']='BTC';
    expect(()=>SavingsGoal.fromJson(incorrect),throwsFormatException);
  });
  test('monthly rule handles month-end dates',(){
    expect(nextRuleDate(DateTime(2026,1,31),'monthly'),DateTime(2026,2,28));
    expect(nextRuleDate(DateTime(2028,1,31),'monthly'),DateTime(2028,2,29));
    expect(nextRuleDate(DateTime(2026,1,1),'weekly'),DateTime(2026,1,8));
  });
}
