import 'package:flutter/material.dart';
import '../../services/calculator_service.dart';
import '../../services/landscape_satellite_access_service.dart';

class LandscapeSatelliteAccessAdminScreen extends StatefulWidget {
  const LandscapeSatelliteAccessAdminScreen({super.key});
  @override State<LandscapeSatelliteAccessAdminScreen> createState() => _LandscapeSatelliteAccessAdminScreenState();
}

class _LandscapeSatelliteAccessAdminScreenState extends State<LandscapeSatelliteAccessAdminScreen> {
  final uidController = TextEditingController();
  bool checking = true, admin = false, enabled = false, busy = false;
  @override void initState() { super.initState(); CalculatorService.isCurrentUserAdmin().then((v) { if (mounted) setState(() { admin=v; checking=false; }); }); }
  @override void dispose() { uidController.dispose(); super.dispose(); }
  Future<void> lookup() async { final uid=uidController.text.trim(); if(uid.isEmpty)return; setState(()=>busy=true); try { final value=await LandscapeSatelliteAccessService.hasAccess(uid); if(mounted)setState(()=>enabled=value); } finally { if(mounted)setState(()=>busy=false); } }
  Future<void> save() async { final uid=uidController.text.trim(); if(uid.isEmpty)return; setState(()=>busy=true); try { await LandscapeSatelliteAccessService.setAccess(uid:uid, enabled:enabled); if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(enabled?'تم تفعيل خدمة أقمار اللاندسكيب':'تم إيقاف خدمة أقمار اللاندسكيب'))); } finally { if(mounted)setState(()=>busy=false); } }
  @override Widget build(BuildContext context) => Directionality(textDirection:TextDirection.rtl, child:Scaffold(appBar:AppBar(title:const Text('أقمار اللاندسكيب')), body:checking ? const Center(child:CircularProgressIndicator()) : !admin ? const Center(child:Text('هذه الصفحة للأدمن فقط')) : Padding(padding:const EdgeInsets.all(20), child:Column(children:[TextField(controller:uidController, decoration:const InputDecoration(labelText:'UID المستخدم', hintText:'أدخل UID ثم اضغط فحص')), const SizedBox(height:12), Row(children:[Expanded(child:OutlinedButton(onPressed:busy?null:lookup, child:const Text('فحص الحالة'))), const SizedBox(width:12), Expanded(child:SwitchListTile(value:enabled,onChanged:busy?null:(v)=>setState(()=>enabled=v),title:const Text('مفعّلة'),contentPadding:EdgeInsets.zero))]), const SizedBox(height:12), FilledButton.icon(onPressed:busy?null:save, icon:const Icon(Icons.save), label:const Text('حفظ صلاحية اللاندسكيب'))])));
}
