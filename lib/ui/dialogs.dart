import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/models.dart';
import '../core/money.dart';
import '../core/storage.dart';
import 'words.dart';

Future<void> notifyResult(BuildContext context, Future<void> Function() operation) async {
  final w=Words(context);
  try{
    await operation();
    if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(w.t('success'))));
  }catch(error){
    if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content:Text('${w.t('failed')}: $error')));
  }
}

Future<bool> confirmAction(BuildContext context,String message) async {
  final w=Words(context);
  return await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
    title:Text(w.t('confirm')),content:Text(message),actions:[
      TextButton(onPressed:()=>Navigator.pop(ctx,false),child:Text(w.t('cancel'))),
      FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text(w.t('confirm'))),
    ]))??false;
}

Future<void> createGoalDialog(BuildContext context,SavingsController controller,String currency) async {
  final w=Words(context);
  final title=TextEditingController(),target=TextEditingController();
  final owner=TextEditingController(text:controller.data.profile);
  final monthly=TextEditingController();
  DateTime? due;
  try{
    final result=await showDialog<SavingsGoal>(context:context,builder:(ctx)=>StatefulBuilder(
      builder:(ctx,redraw)=>AlertDialog(title:Text(w.t('addGoal')),
        content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
          TextField(controller:title,maxLength:160,decoration:InputDecoration(labelText:w.t('goalName'))),
          const SizedBox(height:8),
          TextField(controller:target,keyboardType:const TextInputType.numberWithOptions(decimal:true),
            decoration:InputDecoration(labelText:'${w.t('target')} ($currency)')),
          const SizedBox(height:12),
          TextField(controller:owner,maxLength:80,decoration:InputDecoration(labelText:w.t('owner'))),
          TextField(controller:monthly,keyboardType:const TextInputType.numberWithOptions(decimal:true),
            decoration:InputDecoration(labelText:w.t('monthlyPlan'))),
          const SizedBox(height:12),
          OutlinedButton.icon(icon:const Icon(Icons.calendar_today_outlined),
            label:Text(due==null?w.t('chooseDate'):DateFormat.yMd(w.tag).format(due!)),
            onPressed:()async{
              final now=DateTime.now();
              final chosen=await showDatePicker(context:ctx,initialDate:due??DateTime(now.year,now.month+6),
                firstDate:DateTime(now.year,now.month,now.day),lastDate:DateTime(2100));
              if(chosen!=null)redraw(()=>due=chosen);
            }),
        ])),actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx),child:Text(w.t('cancel'))),
          FilledButton(onPressed:(){
            final amount=parseMinor(target.text,locale:w.tag);
            final plan=monthly.text.trim().isEmpty?0:parseMinor(monthly.text,locale:w.tag);
            if(title.text.trim().isEmpty||owner.text.trim().isEmpty||amount==null||plan==null){
              ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content:Text(w.t('invalid'))));return;
            }
            Navigator.pop(ctx,SavingsGoal(id:identifier(),title:title.text.trim(),targetMinor:amount,
              currency:currency,owner:owner.text.trim(),createdAt:DateTime.now(),deadline:due,monthlyPlanMinor:plan));
          },child:Text(w.t('save'))),
        ],
      )));
    if(result!=null&&context.mounted)await notifyResult(context,()=>controller.addGoal(result));
  }finally{title.dispose();target.dispose();owner.dispose();monthly.dispose();}
}

Future<void> contributionDialog(BuildContext context,SavingsController controller,SavingsGoal goal,
  {bool withdraw=false}) async {
  final w=Words(context);final amount=TextEditingController(),note=TextEditingController();
  try{
    final parsed=await showDialog<int>(context:context,builder:(ctx)=>AlertDialog(
      title:Text(w.t(withdraw?'withdraw':'deposit')),
      content:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:amount,keyboardType:const TextInputType.numberWithOptions(decimal:true),
          decoration:InputDecoration(labelText:'${w.t('amount')} (${goal.currency})')),
        const SizedBox(height:12),TextField(controller:note,maxLength:400,
          decoration:InputDecoration(labelText:w.t('note'))),
      ]),actions:[
        TextButton(onPressed:()=>Navigator.pop(ctx),child:Text(w.t('cancel'))),
        FilledButton(onPressed:(){
          final value=parseMinor(amount.text,locale:w.tag);
          if(value==null){ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content:Text(w.t('invalid'))));return;}
          Navigator.pop(ctx,value);
        },child:Text(w.t('confirm'))),
      ],
    ));
    if(parsed!=null&&context.mounted){
      await notifyResult(context,()=>controller.contribute(goal.id,parsed,
        withdraw:withdraw,note:note.text.trim()));
    }
  }finally{amount.dispose();note.dispose();}
}

Future<void> createRuleDialog(BuildContext context,SavingsController controller,String currency) async {
  final w=Words(context);
  final goals=controller.data.goals.where((g)=>g.currency==currency).toList();
  if(goals.isEmpty){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(w.t('atLeastOne'))));return;}
  final amount=TextEditingController();
  String goalId=goals.first.id,frequency='monthly';
  DateTime due=DateTime.now();
  try{
    final result=await showDialog<SavingsRule>(context:context,builder:(ctx)=>StatefulBuilder(
      builder:(ctx,refresh)=>AlertDialog(title:Text(w.t('newRule')),
        content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
          DropdownButtonFormField<String>(initialValue:goalId,
            decoration:InputDecoration(labelText:w.t('goals')),
            items:goals.map((g)=>DropdownMenuItem(value:g.id,child:Text(g.title))).toList(),
            onChanged:(v){if(v!=null)refresh(()=>goalId=v);}),
          const SizedBox(height:12),
          TextField(controller:amount,keyboardType:const TextInputType.numberWithOptions(decimal:true),
            decoration:InputDecoration(labelText:'${w.t('amount')} ($currency)')),
          const SizedBox(height:12),
          DropdownButtonFormField<String>(initialValue:frequency,
            decoration:InputDecoration(labelText:w.t('planRule')),
            items:['weekly','monthly'].map((f)=>DropdownMenuItem(value:f,
              child:Text(w.t(f)))).toList(),
            onChanged:(v){if(v!=null)refresh(()=>frequency=v);}),
          const SizedBox(height:12),
          OutlinedButton.icon(icon:const Icon(Icons.date_range),
            label:Text(DateFormat.yMd(w.tag).format(due)),onPressed:() async {
              final v=await showDatePicker(context:ctx,initialDate:due,
                firstDate:DateTime(2020),lastDate:DateTime(2100));
              if(v!=null)refresh(()=>due=v);
            }),
        ])),actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx),child:Text(w.t('cancel'))),
          FilledButton(onPressed:(){final value=parseMinor(amount.text,locale:w.tag);
            if(value==null){ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content:Text(w.t('invalid'))));return;}
            Navigator.pop(ctx,SavingsRule(id:identifier(),goalId:goalId,
              amountMinor:value,frequency:frequency,nextDue:due));
          },child:Text(w.t('save'))),
        ],
      )));
    if(result!=null&&context.mounted)await notifyResult(context,()=>controller.addRule(result));
  }finally{amount.dispose();}
}

Future<void> addTaskDialog(BuildContext context,SavingsController controller)async{
  final w=Words(context);final text=TextEditingController();
  try{
    final task=await showDialog<String>(context:context,builder:(ctx)=>AlertDialog(
      title:Text(w.t('newTask')),content:TextField(controller:text,maxLength:160,
        decoration:InputDecoration(labelText:w.t('newTask'))),actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx),child:Text(w.t('cancel'))),
          FilledButton(onPressed:(){if(text.text.trim().isEmpty)return;
            Navigator.pop(ctx,text.text.trim());},child:Text(w.t('add'))),
        ]));
    if(task!=null&&context.mounted)await notifyResult(context,()=>controller.addTask(task));
  }finally{text.dispose();}
}

Future<void> editGoalDialog(BuildContext context,SavingsController controller,SavingsGoal goal)async{
  final w=Words(context);
  final title=TextEditingController(text:goal.title),owner=TextEditingController(text:goal.owner);
  final target=TextEditingController(text:(goal.targetMinor/100).toStringAsFixed(2));
  final monthly=TextEditingController(text:goal.monthlyPlanMinor==0?'':
    (goal.monthlyPlanMinor/100).toStringAsFixed(2));
  try{
    final updated=await showDialog<SavingsGoal>(context:context,builder:(ctx)=>AlertDialog(
      title:Text(w.t('editGoal')),
      content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:title,maxLength:160,decoration:InputDecoration(labelText:w.t('goalName'))),
        TextField(controller:owner,maxLength:80,decoration:InputDecoration(labelText:w.t('owner'))),
        TextField(controller:target,keyboardType:const TextInputType.numberWithOptions(decimal:true),
          decoration:InputDecoration(labelText:'${w.t('target')} (${goal.currency})')),
        TextField(controller:monthly,keyboardType:const TextInputType.numberWithOptions(decimal:true),
          decoration:InputDecoration(labelText:w.t('monthlyPlan'))),
      ])),actions:[
        TextButton(onPressed:()=>Navigator.pop(ctx),child:Text(w.t('cancel'))),
        FilledButton(onPressed:(){
          final amount=parseMinor(target.text,locale:w.tag);
          final plan=monthly.text.trim().isEmpty?0:parseMinor(monthly.text,locale:w.tag);
          if(title.text.trim().isEmpty||owner.text.trim().isEmpty||amount==null||plan==null){
            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content:Text(w.t('invalid'))));return;
          }
          Navigator.pop(ctx,goal.copyWith(title:title.text.trim(),owner:owner.text.trim(),
            targetMinor:amount,monthlyPlanMinor:plan));
        },child:Text(w.t('save'))),
      ],
    ));
    if(updated!=null&&context.mounted)await notifyResult(context,()=>controller.updateGoal(updated));
  }finally{title.dispose();owner.dispose();target.dispose();monthly.dispose();}
}
