import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../core/models.dart';
import '../core/money.dart';
import '../core/storage.dart';
import 'dialogs.dart';
import 'hub.dart';
import 'words.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key,required this.controller,required this.currency});
  final SavingsController controller;
  final String currency;
  @override Widget build(BuildContext context){
    final w=Words(context),ledger=controller.data;
    final goals=ledger.goals.where((g)=>g.currency==currency).toList()
      ..sort((a,b)=>ledger.remainingMinor(a).compareTo(ledger.remainingMinor(b)));
    final count=ledger.tasks.where((t)=>t.done).length;
    return ListView(padding:const EdgeInsets.all(16),children:[
      Text(ledger.profile,style:Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height:8),
      Card(child:Padding(padding:const EdgeInsets.all(20),child:Column(
        crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(w.t('totalSaved'),style:Theme.of(context).textTheme.titleMedium),
          const SizedBox(height:6),Text(money(ledger.totalSaved(currency),currency,w.tag),
            style:Theme.of(context).textTheme.headlineLarge),
          Text('${goals.length} ${w.t('goals')} • $count ${w.t('trophy')}'),
        ]))),
      const SizedBox(height:20),
      Text(w.t('goals'),style:Theme.of(context).textTheme.titleLarge),
      if(goals.isEmpty) Padding(padding:const EdgeInsets.all(20),child:Text(w.t('noGoals'))),
      ...goals.take(6).map((g)=>goalCard(context,ledger,g)),
      const SizedBox(height:14),
      Card(child:ListTile(leading:const Icon(Icons.shield_outlined),
        title:Text(w.t('settings')),subtitle:Text(w.t('privacy')))),
    ]);
  }
}

Widget goalCard(BuildContext context,SavingsLedger ledger,SavingsGoal goal) {
  final w=Words(context);
  final saved=ledger.savedMinor(goal.id);
  return Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(
    crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[Expanded(child:Text(goal.title,style:Theme.of(context).textTheme.titleMedium)),
        Text('${(ledger.progress(goal)*100).round()}%')]),
      Text('${money(saved,goal.currency,w.tag)} / ${money(goal.targetMinor,goal.currency,w.tag)}'),
      const SizedBox(height:8),LinearProgressIndicator(value:ledger.progress(goal),minHeight:8,
        semanticsLabel:'${w.t('progress')} ${(ledger.progress(goal)*100).round()}%'),
      const SizedBox(height:8),Text('${w.t('owner')}: ${goal.owner}'),
      if(goal.deadline!=null)Text('${w.t('deadline')}: ${DateFormat.yMd(w.tag).format(goal.deadline!)}'),
    ])));
}

class GoalsPage extends StatelessWidget {
  const GoalsPage({super.key,required this.controller,required this.currency});
  final SavingsController controller;
  final String currency;
  @override Widget build(BuildContext context){
    final w=Words(context),ledger=controller.data;
    final goals=ledger.goals.where((g)=>g.currency==currency).toList();
    return ListView(padding:const EdgeInsets.fromLTRB(16,12,16,110),children:[
      Text(w.t('goals'),style:Theme.of(context).textTheme.headlineSmall),
      if(goals.isEmpty)Padding(padding:const EdgeInsets.all(24),child:Text(w.t('noGoals'))),
      ...goals.map((goal)=>Card(child:ExpansionTile(
        key:ValueKey(goal.id),title:Text(goal.title),
        subtitle:Text('${money(ledger.savedMinor(goal.id),currency,w.tag)} / ${money(goal.targetMinor,currency,w.tag)}'),
        children:[
          Padding(padding:const EdgeInsets.symmetric(horizontal:16),child:LinearProgressIndicator(
            value:ledger.progress(goal),minHeight:8)),
          const SizedBox(height:12),
          Text('${w.t('remaining')}: ${money(ledger.remainingMinor(goal),currency,w.tag)}'),
          if(goal.deadline!=null)Text('${w.t('monthlyNeed')}: ${monthlyNeeded(
            ledger.remainingMinor(goal),goal.deadline!,DateTime.now())==null?'—':money(
              monthlyNeeded(ledger.remainingMinor(goal),goal.deadline!,DateTime.now())!,currency,w.tag)}'),
          Wrap(alignment:WrapAlignment.center,spacing:8,children:[
            OutlinedButton.icon(onPressed:()=>editGoalDialog(context,controller,goal),
              icon:const Icon(Icons.edit_outlined),label:Text(w.t('editGoal'))),
            FilledButton.tonalIcon(onPressed:()=>contributionDialog(context,controller,goal),
              icon:const Icon(Icons.add),label:Text(w.t('deposit'))),
            OutlinedButton.icon(onPressed:ledger.savedMinor(goal.id)>0?
              ()=>contributionDialog(context,controller,goal,withdraw:true):null,
              icon:const Icon(Icons.remove),label:Text(w.t('withdraw'))),
            TextButton.icon(onPressed:()async{
              if(await confirmAction(context,w.t('confirmDelete'))&&context.mounted){
                await notifyResult(context,()=>controller.deleteGoal(goal.id));
              }
            },icon:const Icon(Icons.delete_outline),label:Text(w.t('delete'))),
          ]),
          if(ledger.movements.any((m)=>m.goalId==goal.id))
            Text(w.t('history'),style:Theme.of(context).textTheme.titleSmall),
          ...ledger.movements.where((m)=>m.goalId==goal.id).take(20).map((m)=>ListTile(
            dense:true,leading:Icon(m.kind=='deposit'?Icons.arrow_downward:Icons.arrow_upward),
            title:Text('${m.kind=='deposit'?'+':'−'}${money(m.amountMinor,currency,w.tag)}'),
            subtitle:Text('${DateFormat.yMd(w.tag).add_Hm().format(m.when)} ${m.note}'),
            trailing:IconButton(tooltip:w.t('delete'),icon:const Icon(Icons.delete_outline),
              onPressed:()async{
                if(await confirmAction(context,w.t('confirmMovementDelete'))&&context.mounted){
                  await notifyResult(context,()=>controller.removeMovement(m.id));
                }
              }),
          )),
        ],
      ))),
    ]);
  }
}

class PlannerPage extends StatelessWidget {
  const PlannerPage({super.key,required this.controller,required this.currency});
  final SavingsController controller;
  final String currency;
  @override Widget build(BuildContext context){
    final w=Words(context),data=controller.data;
    final rules=data.rules.where((rule)=>data.goals.any(
      (g)=>g.id==rule.goalId&&g.currency==currency)).toList();
    return ListView(padding:const EdgeInsets.all(16),children:[
      Text(w.t('planner'),style:Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height:12),
      FilledButton.icon(onPressed:()=>createRuleDialog(context,controller,currency),
        icon:const Icon(Icons.add_circle_outline),label:Text(w.t('newRule'))),
      const SizedBox(height:12),
      Card(child:Padding(padding:const EdgeInsets.all(12),child:Text(w.t('localOnly')))),
      if(rules.isEmpty)Padding(padding:const EdgeInsets.all(20),child:Text(w.t('empty'))),
      ...rules.map((rule){
        final goal=data.goals.firstWhere((g)=>g.id==rule.goalId);
        final due=!rule.nextDue.isAfter(DateTime.now());
        return Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(
          crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(goal.title,style:Theme.of(context).textTheme.titleMedium),
            Text('${money(rule.amountMinor,currency,w.tag)} • ${w.t(rule.frequency)}'),
            Text('${w.t('due')}: ${DateFormat.yMd(w.tag).format(rule.nextDue)}'),
            Text(rule.enabled?w.t('active'):w.t('paused')),
            Wrap(spacing:6,children:[
              FilledButton.tonal(onPressed:rule.enabled&&due?()=>notifyResult(context,
                ()=>controller.confirmScheduledDeposit(rule.id)):null,
                child:Text(w.t('markSaved'))),
              OutlinedButton(onPressed:()=>notifyResult(context,
                ()=>controller.toggleRule(rule.id)),child:Text(w.t('toggle'))),
              IconButton(tooltip:w.t('delete'),onPressed:()=>notifyResult(context,
                ()=>controller.removeRule(rule.id)),icon:const Icon(Icons.delete_outline)),
            ]),
          ])));
      }),
      const SizedBox(height:16),
      Text(w.t('insights'),style:Theme.of(context).textTheme.titleLarge),
      ...data.goals.where((g)=>g.currency==currency).map((g){
        final remaining=data.remainingMinor(g);
        final projection=projectedFinish(remaining,g.monthlyPlanMinor,DateTime.now());
        return ListTile(leading:const Icon(Icons.query_stats),title:Text(g.title),
          subtitle:Text('${w.t('monthlyPlan')}: ${money(g.monthlyPlanMinor,currency,w.tag)}'),
          trailing:Text(projection==null?'—':DateFormat.yM(w.tag).format(projection)));
      }),
    ]);
  }
}

class FamilyPage extends StatefulWidget {
  const FamilyPage({super.key,required this.controller,required this.currency});
  final SavingsController controller;
  final String currency;
  @override State<FamilyPage> createState()=>_FamilyPageState();
}
class _FamilyPageState extends State<FamilyPage>{
  final profile=TextEditingController();
  @override void initState(){super.initState();profile.text=widget.controller.data.profile;}
  @override void dispose(){profile.dispose();super.dispose();}
  @override Widget build(BuildContext context){
    final w=Words(context),data=widget.controller.data;
    final grouped=<String,int>{};
    for(final g in data.goals.where((g)=>g.currency==widget.currency)){
      grouped[g.owner]=(grouped[g.owner]??0)+data.savedMinor(g.id);
    }
    return ListView(padding:const EdgeInsets.all(16),children:[
      Text(w.t('family'),style:Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height:16),
      TextField(controller:profile,maxLength:80,
        decoration:InputDecoration(labelText:w.t('profile'),suffixIcon:IconButton(
          tooltip:w.t('save'),icon:const Icon(Icons.save_outlined),
          onPressed:()=>notifyResult(context,()=>widget.controller.setProfile(profile.text))))),
      Text(w.t('members'),style:Theme.of(context).textTheme.titleLarge),
      if(grouped.isEmpty)Padding(padding:const EdgeInsets.all(12),child:Text(w.t('empty'))),
      ...grouped.entries.map((e)=>Card(child:ListTile(leading:const Icon(Icons.person_outline),
        title:Text(e.key),trailing:Text(money(e.value,widget.currency,w.tag))))),
      const SizedBox(height:16),
      Text(w.t('tasks'),style:Theme.of(context).textTheme.titleLarge),
      OutlinedButton.icon(onPressed:()=>addTaskDialog(context,widget.controller),
        icon:const Icon(Icons.add_task),label:Text(w.t('newTask'))),
      ...data.tasks.map((task)=>CheckboxListTile(
        title:Text(task.title),value:task.done,
        onChanged:(_)=>notifyResult(context,()=>widget.controller.toggleTask(task.id)),
        secondary:IconButton(tooltip:w.t('delete'),icon:const Icon(Icons.delete_outline),
          onPressed:()=>notifyResult(context,()=>widget.controller.removeTask(task.id))),
      )),
      const SizedBox(height:16),
      Text(w.t('challenge'),style:Theme.of(context).textTheme.titleLarge),
      Text(w.t('challengeText')),
      OutlinedButton.icon(icon:const Icon(Icons.emoji_events_outlined),
        onPressed:() async {
          await notifyResult(context,() async {
            final existing=widget.controller.data.tasks.map((t)=>t.title).toSet();
            for(var i=1;i<=30;i++){
              final title='${w.t('challenge')} • $i';
              if(!existing.contains(title))await widget.controller.addTask(title);
            }
          });
        },label:Text(w.t('createChallenge'))),
    ]);
  }
}

class ToolkitPage extends StatelessWidget {
  const ToolkitPage({super.key,required this.controller,required this.currency,required this.onJump});
  final SavingsController controller;
  final String currency;
  final ValueChanged<int> onJump;
  @override Widget build(BuildContext context){
    final w=Words(context);
    final goals=controller.data.goals.where((g)=>g.currency==currency).toList();
    return ListView(padding:const EdgeInsets.all(16),children:[
      Text(w.t('tools'),style:Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height:12),
      Text(w.t('calculator'),style:Theme.of(context).textTheme.titleLarge),
      Text(w.t('calculatorDescription')),
      ...goals.map((g){
        final forecast=projectedFinish(controller.data.remainingMinor(g),g.monthlyPlanMinor,DateTime.now());
        return Card(child:ListTile(title:Text(g.title),subtitle:Text(
          '${w.t('remaining')}: ${money(controller.data.remainingMinor(g),currency,w.tag)}\n'
          '${w.t('monthlyPlan')}: ${money(g.monthlyPlanMinor,currency,w.tag)}'),
          trailing:Text(forecast==null?'—':DateFormat.yM(w.tag).format(forecast))));
      }),
      const SizedBox(height:16),
      Text(w.t('learning'),style:Theme.of(context).textTheme.titleLarge),
      for(var i=1;i<=4;i++)Card(child:ListTile(leading:CircleAvatar(child:Text('$i')),
        title:Text(w.t('lesson$i')))),
      const SizedBox(height:16),
      Card(child:ListTile(leading:const Icon(Icons.info_outline),title:Text(w.t('privacy')),
        subtitle:Text(w.t('localOnly')))),
      const SizedBox(height:16),
      FeatureHub(controller:controller,currency:currency,onJump:onJump),
      const SizedBox(height:16),
      Text(w.t('settings'),style:Theme.of(context).textTheme.titleLarge),
      OutlinedButton.icon(icon:const Icon(Icons.ios_share),label:Text(w.t('export')),
        onPressed:()async{
          if(!await confirmAction(context,w.t('confirmExport'))||!context.mounted)return;
          final raw=controller.exportJson();
          await Share.share(raw,subject:'Tasarruf 360 JSON backup');
        }),
      OutlinedButton.icon(icon:const Icon(Icons.file_download_outlined),label:Text(w.t('import')),
        onPressed:()=>importDialog(context,controller)),
      const SizedBox(height:8),
      OutlinedButton.icon(icon:const Icon(Icons.delete_forever_outlined),
        label:Text(w.t('deleteAll')),onPressed:()async{
          if(await confirmAction(context,w.t('confirmClear'))&&context.mounted){
            await notifyResult(context,()=>controller.clearAll());
          }
        }),
    ]);
  }
}

Future<void> importDialog(BuildContext context,SavingsController controller) async {
  final w=Words(context),text=TextEditingController();
  try{
    final raw=await showDialog<String>(context:context,builder:(ctx)=>AlertDialog(
      title:Text(w.t('import')),
      content:TextField(controller:text,minLines:3,maxLines:8,maxLength:1500000,
        decoration:InputDecoration(labelText:w.t('backupPaste'))),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:Text(w.t('cancel'))),
        FilledButton(onPressed:()=>Navigator.pop(ctx,text.text),child:Text(w.t('import')))],
    ));
    if(raw==null||!context.mounted)return;
    if(!await confirmAction(context,w.t('confirmImport'))||!context.mounted)return;
    await notifyResult(context,()=>controller.importJson(raw));
  }finally{text.dispose();}
}
