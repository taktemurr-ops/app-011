import 'dart:math';
import 'money.dart';

String identifier() => '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(0x7fffffff)}';

String validText(Object? v, String name, {int max = 160}) {
  if (v is! String || v.trim().isEmpty || v.length > max) throw FormatException('Invalid $name');
  return v.trim();
}

int positive(Object? v, String name) {
  if (v is! int || v <= 0 || v > maxMinor) throw FormatException('Invalid $name');
  return v;
}

DateTime date(Object? v, String name) {
  if (v is! String) throw FormatException('Invalid $name');
  final out = DateTime.tryParse(v);
  if (out == null || out.year < 2000 || out.year > 2200) throw FormatException('Invalid $name');
  return out;
}

String currencyOf(Object? v) {
  final s = validText(v, 'currency', max: 3);
  if (!currencies.contains(s)) throw const FormatException('Invalid currency');
  return s;
}

class SavingsGoal {
  const SavingsGoal({required this.id, required this.title, required this.targetMinor,
    required this.currency, required this.owner, required this.createdAt,
    this.deadline, this.note = '', this.monthlyPlanMinor = 0});
  final String id, title, currency, owner, note;
  final int targetMinor, monthlyPlanMinor;
  final DateTime createdAt;
  final DateTime? deadline;

  SavingsGoal copyWith({String? title, String? owner, int? targetMinor,
    int? monthlyPlanMinor,DateTime? deadline}) => SavingsGoal(
    id: id, title: title ?? this.title, targetMinor: targetMinor ?? this.targetMinor,
    currency: currency, owner: owner ?? this.owner, createdAt: createdAt,
    deadline: deadline ?? this.deadline, note: note,
    monthlyPlanMinor: monthlyPlanMinor ?? this.monthlyPlanMinor);

  Map<String, Object?> toJson() => {
    'id':id,'title':title,'targetMinor':targetMinor,'currency':currency,'owner':owner,
    'createdAt':createdAt.toIso8601String(),'deadline':deadline?.toIso8601String(),
    'note':note,'monthlyPlanMinor':monthlyPlanMinor,
  };
  factory SavingsGoal.fromJson(Map<String,dynamic> m) {
    final monthly = m['monthlyPlanMinor'] ?? 0;
    if (monthly is! int || monthly < 0 || monthly > maxMinor) throw const FormatException('Invalid plan');
    final note = m['note'] ?? '';
    if (note is! String || note.length > 400) throw const FormatException('Invalid note');
    return SavingsGoal(id:validText(m['id'],'id',max:90),title:validText(m['title'],'title'),
      targetMinor:positive(m['targetMinor'],'target'),currency:currencyOf(m['currency']),
      owner:validText(m['owner'],'owner',max:80),createdAt:date(m['createdAt'],'created'),
      deadline:m['deadline']==null?null:date(m['deadline'],'deadline'),
      note:note,monthlyPlanMinor:monthly);
  }
}

class SavingsMovement {
  const SavingsMovement({required this.id, required this.goalId, required this.amountMinor,
    required this.kind, required this.when, this.note = ''});
  final String id, goalId, kind, note;
  final int amountMinor;
  final DateTime when;
  Map<String,Object?> toJson() => {'id':id,'goalId':goalId,'amountMinor':amountMinor,
    'kind':kind,'when':when.toIso8601String(),'note':note};
  factory SavingsMovement.fromJson(Map<String,dynamic> m) {
    final kind = validText(m['kind'],'kind',max:20);
    if (kind != 'deposit' && kind != 'withdrawal') throw const FormatException('Invalid kind');
    final note = m['note'] ?? '';
    if (note is! String || note.length > 400) throw const FormatException('Invalid note');
    return SavingsMovement(id:validText(m['id'],'id',max:90),goalId:validText(m['goalId'],'goalId',max:90),
      amountMinor:positive(m['amountMinor'],'amount'),kind:kind,when:date(m['when'],'when'),note:note);
  }
}

class SavingsRule {
  const SavingsRule({required this.id, required this.goalId, required this.amountMinor,
    required this.frequency,required this.nextDue,this.enabled=true});
  final String id,goalId,frequency;
  final int amountMinor;
  final DateTime nextDue;
  final bool enabled;
  SavingsRule copyWith({DateTime? nextDue,bool? enabled}) => SavingsRule(id:id,goalId:goalId,
    amountMinor:amountMinor,frequency:frequency,nextDue:nextDue??this.nextDue,enabled:enabled??this.enabled);
  Map<String,Object?> toJson() => {'id':id,'goalId':goalId,'amountMinor':amountMinor,
    'frequency':frequency,'nextDue':nextDue.toIso8601String(),'enabled':enabled};
  factory SavingsRule.fromJson(Map<String,dynamic> m) {
    final frequency = validText(m['frequency'],'frequency',max:12);
    if (frequency!='weekly' && frequency!='monthly') throw const FormatException('Invalid frequency');
    if (m['enabled'] is! bool) throw const FormatException('Invalid enabled');
    return SavingsRule(id:validText(m['id'],'id',max:90),goalId:validText(m['goalId'],'goalId',max:90),
      amountMinor:positive(m['amountMinor'],'amount'),frequency:frequency,
      nextDue:date(m['nextDue'],'nextDue'),enabled:m['enabled'] as bool);
  }
}

DateTime nextRuleDate(DateTime due,String frequency) {
  if (frequency=='weekly') return due.add(const Duration(days:7));
  if (frequency=='monthly') {
    final target = DateTime(due.year,due.month+2,0).day;
    return DateTime(due.year,due.month+1,due.day>target?target:due.day);
  }
  throw ArgumentError('frequency');
}

class SavingsTask {
  const SavingsTask({required this.id,required this.title,this.done=false});
  final String id,title;
  final bool done;
  SavingsTask copyWith({bool? done}) => SavingsTask(id:id,title:title,done:done??this.done);
  Map<String,Object?> toJson() => {'id':id,'title':title,'done':done};
  factory SavingsTask.fromJson(Map<String,dynamic> m) {
    if(m['done'] is! bool) throw const FormatException('Invalid task state');
    return SavingsTask(id:validText(m['id'],'id',max:90),title:validText(m['title'],'title'),done:m['done'] as bool);
  }
}

/// Local household information, financial data never leaves the device.
class SavingsLedger {
  const SavingsLedger({this.profile='My household',this.goals=const [],
    this.movements=const [],this.rules=const [],this.tasks=const []});
  final String profile;
  final List<SavingsGoal> goals;
  final List<SavingsMovement> movements;
  final List<SavingsRule> rules;
  final List<SavingsTask> tasks;
  SavingsLedger copyWith({String? profile,List<SavingsGoal>? goals,
    List<SavingsMovement>? movements,List<SavingsRule>? rules,List<SavingsTask>? tasks}) =>
    SavingsLedger(profile:profile??this.profile,goals:goals??this.goals,movements:movements??this.movements,
      rules:rules??this.rules,tasks:tasks??this.tasks);

  Map<String,Object?> toJson() => {
    'schemaVersion':1,'profile':profile,
    'goals':goals.map((x)=>x.toJson()).toList(),
    'movements':movements.map((x)=>x.toJson()).toList(),
    'rules':rules.map((x)=>x.toJson()).toList(),
    'tasks':tasks.map((x)=>x.toJson()).toList(),
  };

  factory SavingsLedger.fromJson(Map<String,dynamic> m) {
    if(m['schemaVersion'] != 1) throw const FormatException('Unsupported version');
    List<T> parseList<T>(Object? raw,T Function(Map<String,dynamic>) decode,String name) {
      if(raw is! List || raw.length > 10000) throw FormatException('Invalid $name');
      return raw.map((e) {
        if(e is! Map) throw FormatException('Invalid $name entry');
        return decode(Map<String,dynamic>.from(e));
      }).toList();
    }
    final goals = parseList(m['goals'],SavingsGoal.fromJson,'goals');
    final moves = parseList(m['movements'],SavingsMovement.fromJson,'movements');
    final rules = parseList(m['rules'],SavingsRule.fromJson,'rules');
    final tasks = parseList(m['tasks'],SavingsTask.fromJson,'tasks');
    void unique(Iterable<String> ids) {
      final list=ids.toList();if(list.toSet().length!=list.length) throw const FormatException('Duplicate ID');
    }
    unique(goals.map((x)=>x.id));unique(moves.map((x)=>x.id));unique(rules.map((x)=>x.id));unique(tasks.map((x)=>x.id));
    final goalIds=goals.map((g)=>g.id).toSet();
    if(moves.any((x)=>!goalIds.contains(x.goalId))||rules.any((x)=>!goalIds.contains(x.goalId))) {
      throw const FormatException('Unknown goal reference');
    }
    final ledger=SavingsLedger(profile:validText(m['profile'],'profile',max:80),goals:goals,
      movements:moves,rules:rules,tasks:tasks);
    for(final goal in goals){if(ledger.savedMinor(goal.id)<0)throw const FormatException('Overdrawn goal');}
    return ledger;
  }

  int savedMinor(String goalId) => movements.where((x)=>x.goalId==goalId).fold(0,
    (sum,x)=>sum+(x.kind=='deposit'?x.amountMinor:-x.amountMinor));
  int remainingMinor(SavingsGoal goal) => max(0,goal.targetMinor-savedMinor(goal.id));
  double progress(SavingsGoal goal) => (savedMinor(goal.id)/goal.targetMinor).clamp(0.0,1.0);
  int totalSaved(String currency) => goals.where((x)=>x.currency==currency)
    .fold(0,(sum,x)=>sum+savedMinor(x.id));
}
