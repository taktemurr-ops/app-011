import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'models.dart';

abstract class SavingsStorage {
  Future<String?> read();
  Future<void> write(String raw);
  Future<void> delete();
}

class SecureSavingsStorage implements SavingsStorage {
  const SecureSavingsStorage();
  static const _key = 'tasarruf360-v1';
  static const _secure = FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences:true));
  @override Future<String?> read() => _secure.read(key:_key);
  @override Future<void> write(String raw) => _secure.write(key:_key,value:raw);
  @override Future<void> delete() => _secure.delete(key:_key);
}

class MemorySavingsStorage implements SavingsStorage {
  String? raw;
  bool failWrite=false,failDelete=false,failRead=false;
  @override Future<String?> read() async {if(failRead)throw StateError('read');return raw;}
  @override Future<void> write(String data) async {if(failWrite)throw StateError('write');raw=data;}
  @override Future<void> delete() async {if(failDelete)throw StateError('delete');raw=null;}
}

/// Storage-first, serialized immutable state commits. Failed writes do not
/// mutate the visible model or strand subsequent operations in the queue.
class SavingsController extends ChangeNotifier {
  SavingsController(this.storage);
  final SavingsStorage storage;
  SavingsLedger _data=const SavingsLedger();
  SavingsLedger get data=>_data;
  bool loaded=false;
  String? error;
  Future<void> _queue=Future<void>.value();

  Future<void> load() async {
    if(loaded)return;
    try{
      final raw=await storage.read();
      if(raw!=null){
        if(raw.length>2000000)throw const FormatException('Data too large');
        final value=jsonDecode(raw);
        if(value is! Map)throw const FormatException('Invalid data');
        _data=SavingsLedger.fromJson(Map<String,dynamic>.from(value));
      }
    }catch(_){error='unreadable';}
    loaded=true;notifyListeners();
  }
  Future<void> _commit(SavingsLedger Function(SavingsLedger) transform){
    final task=_queue.then((_)async{
      if(!loaded || error!=null)throw StateError('Savings data is unavailable');
      final candidate=transform(_data);
      final text=jsonEncode(candidate.toJson());
      if(text.length>1500000)throw StateError('Data size limit');
      // Roundtrip validates referential integrity and schema before persistence.
      final normalized=SavingsLedger.fromJson(Map<String,dynamic>.from(jsonDecode(text) as Map));
      await storage.write(text);
      _data=normalized;notifyListeners();
    });
    _queue=task.catchError((Object _){});
    return task;
  }
  Future<void> setProfile(String name) => _commit((x)=>x.copyWith(profile:validText(name,'profile',max:80)));
  Future<void> addGoal(SavingsGoal goal) => _commit((x){
    if(x.goals.any((g)=>g.id==goal.id))throw ArgumentError('Duplicate goal');
    if(goal.deadline!=null && goal.deadline!.isBefore(DateTime(goal.createdAt.year,goal.createdAt.month,goal.createdAt.day))) {
      throw ArgumentError('Past deadline');
    }
    return x.copyWith(goals:[...x.goals,goal]);
  });
  Future<void> updateGoal(SavingsGoal goal) => _commit((x){
    final existing=x.goals.where((g)=>g.id==goal.id);
    if(existing.isEmpty)throw ArgumentError('Goal missing');
    if(goal.currency!=existing.first.currency)throw ArgumentError('Currency cannot be changed');
    if(goal.targetMinor<x.savedMinor(goal.id))throw StateError('Target below saved amount');
    final normalized=SavingsGoal.fromJson(goal.toJson());
    return x.copyWith(goals:x.goals.map((g)=>g.id==goal.id?normalized:g).toList());
  });
  Future<void> deleteGoal(String id) => _commit((x)=>x.copyWith(
    goals:x.goals.where((g)=>g.id!=id).toList(),
    movements:x.movements.where((m)=>m.goalId!=id).toList(),
    rules:x.rules.where((r)=>r.goalId!=id).toList()));

  Future<void> contribute(String id,int amount,{bool withdraw=false,String note=''}) => _commit((x){
    if(amount<=0)throw ArgumentError('Invalid amount');
    if(!x.goals.any((g)=>g.id==id))throw ArgumentError('Goal missing');
    if(withdraw && x.savedMinor(id)<amount)throw StateError('Insufficient savings');
    if(note.length>400)throw ArgumentError('Note too long');
    final movement=SavingsMovement(id:identifier(),goalId:id,amountMinor:amount,
      kind:withdraw?'withdrawal':'deposit',when:DateTime.now(),note:note);
    return x.copyWith(movements:[movement,...x.movements]);
  });
  Future<void> removeMovement(String id) => _commit((x){
    final left=x.movements.where((m)=>m.id!=id).toList();
    if(left.length==x.movements.length)throw ArgumentError('Movement missing');
    final candidate=x.copyWith(movements:left);
    if(candidate.goals.any((g)=>candidate.savedMinor(g.id)<0)){
      throw StateError('Removing that deposit would overdraw a goal');
    }
    return candidate;
  });
  Future<void> addRule(SavingsRule rule)=>_commit((x){
    if(x.rules.any((r)=>r.id==rule.id))throw ArgumentError('Duplicate rule');
    if(!x.goals.any((g)=>g.id==rule.goalId))throw ArgumentError('Unknown goal');
    return x.copyWith(rules:[...x.rules,rule]);
  });
  Future<void> removeRule(String id)=>_commit((x)=>x.copyWith(rules:x.rules.where((r)=>r.id!=id).toList()));
  Future<void> toggleRule(String id)=>_commit((x)=>x.copyWith(rules:x.rules.map((r)=>r.id==id?r.copyWith(enabled:!r.enabled):r).toList()));

  /// Explicit manual acknowledgement. Does not touch banking accounts or
  /// silently fabricate a deposit based on the calendar.
  Future<void> confirmScheduledDeposit(String id)=>_commit((x){
    final matches=x.rules.where((r)=>r.id==id);
    if(matches.isEmpty)throw ArgumentError('Rule missing');
    final rule=matches.first;
    if(!rule.enabled)throw StateError('Rule paused');
    final now=DateTime.now();
    if(rule.nextDue.isAfter(now))throw StateError('Not due');
    final move=SavingsMovement(id:identifier(),goalId:rule.goalId,
      amountMinor:rule.amountMinor,kind:'deposit',when:now,note:'Manual plan confirmation');
    return x.copyWith(movements:[move,...x.movements],rules:x.rules.map((r)=>
      r.id==id?r.copyWith(nextDue:nextRuleDate(r.nextDue,r.frequency)):r).toList());
  });
  Future<void> addTask(String title)=>_commit((x)=>x.copyWith(tasks:[...x.tasks,
    SavingsTask(id:identifier(),title:validText(title,'task'))]));
  Future<void> toggleTask(String id)=>_commit((x)=>x.copyWith(tasks:x.tasks.map((t)=>
    t.id==id?t.copyWith(done:!t.done):t).toList()));
  Future<void> removeTask(String id)=>_commit((x)=>x.copyWith(tasks:x.tasks.where((t)=>t.id!=id).toList()));

  String exportJson(){
    if(!loaded||error!=null)throw StateError('Not loaded');
    return jsonEncode({..._data.toJson(),'product':'tasarruf_360',
      'exportedAtUtc':DateTime.now().toUtc().toIso8601String()});
  }
  Future<void> importJson(String input) async {
    if(input.length>1500000)throw const FormatException('Import too large');
    final value=jsonDecode(input);
    if(value is! Map||value['product']!='tasarruf_360')throw const FormatException('Wrong backup type');
    final parsed=SavingsLedger.fromJson(Map<String,dynamic>.from(value));
    await _commit((_)=>parsed);
  }
  Future<void> clearAll(){
    final task=_queue.then((_)async{
      if(!loaded || error!=null)throw StateError('Data unavailable');
      await storage.delete();
      _data=const SavingsLedger();notifyListeners();
    });
    _queue=task.catchError((Object _){});return task;
  }
}
