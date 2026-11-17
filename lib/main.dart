import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/models.dart';
import 'core/money.dart';
import 'core/storage.dart';
import 'ui/dialogs.dart';
import 'ui/pages.dart';
import 'ui/words.dart';

void main() => runApp(const Tasarruf360App());

class Tasarruf360App extends StatelessWidget {
  const Tasarruf360App({super.key,this.storage});
  final SavingsStorage? storage;

  @override Widget build(BuildContext context) => MaterialApp(
    onGenerateTitle:(context)=>Words(context).t('app'),
    debugShowCheckedModeBanner:false,
    supportedLocales:const [Locale('tr'),Locale('en'),Locale('ar')],
    localizationsDelegates:const [GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,GlobalCupertinoLocalizations.delegate],
    theme:ThemeData(useMaterial3:true,colorScheme:ColorScheme.fromSeed(seedColor:const Color(0xff267a65)),
      inputDecorationTheme:const InputDecorationTheme(border:OutlineInputBorder())),
    darkTheme:ThemeData(useMaterial3:true,colorScheme:ColorScheme.fromSeed(
      seedColor:const Color(0xff72c7a9),brightness:Brightness.dark)),
    home:SavingsHome(storage:storage??const SecureSavingsStorage()),
  );
}

class SavingsHome extends StatefulWidget {
  const SavingsHome({super.key,required this.storage});
  final SavingsStorage storage;
  @override State<SavingsHome> createState()=>_SavingsHomeState();
}

class _SavingsHomeState extends State<SavingsHome> {
  late final SavingsController controller;
  int selected=0;
  String selectedCurrency='TRY';
  @override void initState(){super.initState();controller=SavingsController(widget.storage);controller.load();}
  @override void dispose(){controller.dispose();super.dispose();}
  @override Widget build(BuildContext context){
    final w=Words(context);
    return ListenableBuilder(listenable:controller,builder:(context,_)=>Scaffold(
      appBar:AppBar(title:Text(w.t('app')),actions:[
        DropdownButtonHideUnderline(child:DropdownButton<String>(
          value:selectedCurrency,tooltip:w.t('currency'),
          items:currencies.map((c)=>DropdownMenuItem(value:c,child:Text(c))).toList(),
          onChanged:(c){if(c!=null)setState(()=>selectedCurrency=c);},
        )),const SizedBox(width:12),
      ]),
      body:!controller.loaded?const Center(child:CircularProgressIndicator()):
        controller.error!=null?Center(child:Padding(padding:const EdgeInsets.all(24),
          child:Text(w.t('unavailable'),textAlign:TextAlign.center))):
        SafeArea(child:switch(selected){
          0=>DashboardPage(controller:controller,currency:selectedCurrency),
          1=>GoalsPage(controller:controller,currency:selectedCurrency),
          2=>PlannerPage(controller:controller,currency:selectedCurrency),
          3=>FamilyPage(controller:controller,currency:selectedCurrency),
          _=>ToolkitPage(controller:controller,currency:selectedCurrency, onJump:(i)=>setState(()=>selected=i)),
        }),
      floatingActionButton:controller.loaded&&controller.error==null&&selected==1?
        FloatingActionButton.extended(tooltip:w.t('addGoal'),
          onPressed:()=>createGoalDialog(context,controller,selectedCurrency),
          icon:const Icon(Icons.add),label:Text(w.t('addGoal'))):null,
      bottomNavigationBar:NavigationBar(selectedIndex:selected,
        labelBehavior:NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected:(v)=>setState(()=>selected=v),destinations:[
          NavigationDestination(icon:const Icon(Icons.dashboard_outlined),label:w.t('dashboard')),
          NavigationDestination(icon:const Icon(Icons.flag_outlined),label:w.t('goals')),
          NavigationDestination(icon:const Icon(Icons.event_repeat_outlined),label:w.t('planner')),
          NavigationDestination(icon:const Icon(Icons.group_outlined),label:w.t('family')),
          NavigationDestination(icon:const Icon(Icons.auto_awesome_outlined),label:w.t('tools')),
        ]),
    ));
  }
}
