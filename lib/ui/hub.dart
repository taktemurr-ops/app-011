import 'package:flutter/material.dart';
import '../core/models.dart';
import '../core/money.dart';
import '../core/storage.dart';
import 'dialogs.dart';
import 'words.dart';

/// Offline feature hub. No external service is simulated as a live backend.
/// Items that need accounts, social networking, bank APIs or store IAP are
/// transparently represented by private household-first alternatives.
class FeatureHub extends StatelessWidget {
  const FeatureHub({super.key,required this.controller,required this.currency,required this.onJump});
  final SavingsController controller;
  final String currency;
  final ValueChanged<int> onJump;

  static const _modules = <String>[
    'm01','m02','m03','m04','m05','m06','m07','m08','m09','m10',
    'm11','m12','m13','m14','m15','m16','m17','m18','m19','m20',
  ];
  static const _descriptions=<String>[
    'd01','d02','d03','d04','d05','d06','d07','d08','d09','d10',
    'd11','d12','d13','d14','d15','d16','d17','d18','d19','d20',
  ];

  @override Widget build(BuildContext context){
    final w=Words(context);
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(w.t('hub'),style:Theme.of(context).textTheme.titleLarge),
      const SizedBox(height:6),
      Text(w.t('localOnly'),style:Theme.of(context).textTheme.bodySmall),
      const SizedBox(height:8),
      for(var i=0;i<_modules.length;i++) Card(child:ListTile(
        dense:true,leading:CircleAvatar(radius:17,child:Text('${i+1}')),
        title:Text(w.t(_modules[i])),subtitle:Text(w.t(_descriptions[i])),
        trailing:const Icon(Icons.chevron_right),
        onTap:()=>_action(context,i),
      )),
    ]);
  }

  void _action(BuildContext context,int index){
    switch(index){
      case 0: case 10: onJump(1);return;
      case 2: case 6: case 18: onJump(2);return;
      case 3: case 11: case 13: case 14: onJump(3);return;
      case 5: case 17: _showAcademy(context);return;
      case 8: _showTemplates(context);return;
      case 1: case 9: _showCoach(context);return;
      case 4: _showHousehold(context);return;
      case 7: _showHistory(context);return;
      case 12: _showRules(context);return;
      case 15: _showStudio(context);return;
      case 16: onJump(0);return;
      case 19: _showPremiumToolkit(context);return;
      default: onJump(4);
    }
  }

  void _info(BuildContext context,String title,String message){
    final w=Words(context);
    showDialog<void>(context:context,builder:(ctx)=>AlertDialog(title:Text(title),
      content:SingleChildScrollView(child:Text(message)),actions:[
        TextButton(onPressed:()=>Navigator.pop(ctx),child:Text(w.t('confirm'))),
      ]));
  }

  void _showHousehold(BuildContext context){
    final w=Words(context),data=controller.data;
    final ownerNames=data.goals.map((g)=>g.owner).toSet().toList();
    _info(context,w.t('m05'),ownerNames.isEmpty?w.t('noGoals'):
      '${w.t('profile')}: ${data.profile}\n${ownerNames.join(' · ')}\n\n${w.t('localOnly')}');
  }
  void _showRules(BuildContext context){
    final w=Words(context),rules=controller.data.rules;
    _info(context,w.t('m13'),rules.isEmpty?w.t('empty'):
      '${rules.length} ${w.t('planRule')}\n${w.t('ruleExplanation')}');
  }
  void _showStudio(BuildContext context){
    final w=Words(context),d=controller.data;
    _info(context,w.t('m16'),'${d.goals.length} ${w.t('goals')} · '
      '${d.movements.length} ${w.t('history')} · ${d.tasks.length} ${w.t('tasks')}\n'
      '${w.t('backupStudio')}');
  }
  void _showHistory(BuildContext context){
    final w=Words(context),moves=controller.data.movements;
    _info(context,w.t('m08'),moves.isEmpty?w.t('empty'):
      moves.take(30).map((m)=>'${m.kind=='deposit'?'+':'−'} '
        '${money(m.amountMinor,currency,w.tag)} (${m.when.year}-${m.when.month}-${m.when.day})').join('\n'));
  }
  void _showCoach(BuildContext context){
    final w=Words(context),data=controller.data;
    final goals=data.goals.where((g)=>g.currency==currency).toList();
    if(goals.isEmpty){_info(context,w.t('m10'),w.t('noGoals'));return;}
    goals.sort((a,b)=>data.progress(a).compareTo(data.progress(b)));
    final g=goals.first;
    final message='${w.t('coachIntro')}\n\n${g.title}\n'
      '${w.t('remaining')}: ${money(data.remainingMinor(g),currency,w.tag)}\n'
      '${w.t('monthlyPlan')}: ${money(g.monthlyPlanMinor,currency,w.tag)}\n\n'
      '${w.t('coachDisclaimer')}';
    _info(context,w.t('m10'),message);
  }
  void _showPremiumToolkit(BuildContext context){
    final w=Words(context),goals=controller.data.goals.where((g)=>g.currency==currency).toList();
    final totalRemaining=goals.fold<int>(0,(sum,g)=>sum+controller.data.remainingMinor(g));
    final monthPlan=goals.fold<int>(0,(sum,g)=>sum+g.monthlyPlanMinor);
    final finish=projectedFinish(totalRemaining,monthPlan,DateTime.now());
    _info(context,w.t('m20'),'${w.t('remaining')}: ${money(totalRemaining,currency,w.tag)}\n'
      '${w.t('monthlyPlan')}: ${money(monthPlan,currency,w.tag)}\n'
      '${w.t('projected')}: ${finish==null?'—':'${finish.month}/${finish.year}'}\n'
      '${w.t('premiumDisclaimer')}');
  }
  void _showAcademy(BuildContext context){
    final w=Words(context);
    showDialog<void>(context:context,builder:(ctx)=>AlertDialog(
      title:Text(w.t('m18')),content:SingleChildScrollView(child:Column(
        mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
          for(var i=1;i<=4;i++)Padding(padding:const EdgeInsets.symmetric(vertical:6),
            child:Text('$i. ${w.t('lesson$i')}')),
          const SizedBox(height:12),Text(w.t('quizPrompt'),style:Theme.of(ctx).textTheme.titleMedium),
        ])),actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx),child:Text(w.t('cancel'))),
          FilledButton(onPressed:()async{
            Navigator.pop(ctx);
            if(context.mounted){
              final label=w.t('quizBadge');
              if(!controller.data.tasks.any((t)=>t.title==label)){
                await notifyResult(context,()=>controller.addTask(label));
              }
            }
          },child:Text(w.t('quizComplete'))),
        ]));
  }

  void _showTemplates(BuildContext context){
    final w=Words(context);
    final templates=<({String title,int target,int monthly})>[
      (title:w.t('templateEmergency'),target:500000,monthly:25000),
      (title:w.t('templateEducation'),target:2000000,monthly:50000),
      (title:w.t('templateTravel'),target:1000000,monthly:50000),
      (title:w.t('templateHome'),target:10000000,monthly:100000),
    ];
    showModalBottomSheet<void>(context:context,isScrollControlled:true,
      builder:(ctx)=>SafeArea(child:Padding(padding:const EdgeInsets.all(16),child:ListView(
        shrinkWrap:true,children:[
          Text(w.t('m09'),style:Theme.of(ctx).textTheme.headlineSmall),
          Text(w.t('templateDisclaimer')),
          ...templates.map((t)=>ListTile(
            title:Text(t.title),subtitle:Text('${money(t.target,currency,w.tag)} · '
              '${w.t('monthlyPlan')} ${money(t.monthly,currency,w.tag)}'),
            trailing:const Icon(Icons.add_circle_outline),
            onTap:()async{
              Navigator.pop(ctx);
              if(!context.mounted)return;
              if(!await confirmAction(context,'${w.t('addGoal')}: ${t.title}?')||!context.mounted)return;
              await notifyResult(context,()=>controller.addGoal(SavingsGoal(
                id:identifier(),title:t.title,targetMinor:t.target,currency:currency,
                owner:controller.data.profile,createdAt:DateTime.now(),monthlyPlanMinor:t.monthly)));
            },
          )),
        ]))));
  }
}
