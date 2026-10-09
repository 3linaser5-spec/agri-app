import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/egypt_data.dart';
import '../../models/calculator_models.dart';
import 'calculator_result_screen.dart';

class DynamicFormScreen extends StatefulWidget {
  final CalculatorTemplate template;
  final Color primaryColor;

  const DynamicFormScreen({
    super.key,
    required this.template,
    required this.primaryColor,
  });

  @override
  State<DynamicFormScreen> createState() => _DynamicFormScreenState();
}

class _DynamicFormScreenState extends State<DynamicFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, dynamic> _values = {};

  String? _selectedGovernorate;
  String? _selectedZone;
  bool _loadingGov = true;

  @override
  void initState() {
    super.initState();
    _loadSavedGovernorate();

    for (var field in widget.template.fields) {
      if (field.defaultValue != null) {
        _values[field.id] = field.defaultValue;
      } else if (field.type == 'dropdown' && field.options.isNotEmpty) {
        _values[field.id] = field.options.first['value'];
      }
    }
    if (widget.template.fields.isEmpty) {
      _values['area'] = 1.0;
    }
  }

  Future<void> _loadSavedGovernorate() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('user_governorate');
    if (saved != null && saved.isNotEmpty) {
      setState(() {
        _selectedGovernorate = saved;
        _selectedZone = EgyptData.getZoneByGovernorate(saved);
        _loadingGov = false;
      });
    } else {
      setState(() => _loadingGov = false);
    }
  }

  Future<void> _saveGovernorate(String gov) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_governorate', gov);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedGovernorate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ الرجاء اختيار المحافظة'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    _values['governorate'] = _selectedGovernorate;
    _values['climate_zone'] = _selectedZone;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CalculatorResultScreen(
          template: widget.template,
          inputValues: Map<String, dynamic>.from(_values),
          primaryColor: widget.primaryColor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.template.emoji} ${widget.template.name}',
            style: const TextStyle(color: Colors.white)),
        backgroundColor: widget.primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: _loadingGov
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: widget.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Text(widget.template.emoji,
                              style: const TextStyle(fontSize: 40)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(widget.template.name,
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: widget.primaryColor)),
                                const SizedBox(height: 4),
                                Text(widget.template.description,
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    _buildGovernorateSelector(),

                    if (_selectedZone != null) _buildZoneInfo(),

                    const SizedBox(height: 20),

                    const Text('أدخل بياناتك:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 12),

                    ...widget.template.fields.map((f) => _buildField(f)),

                    if (widget.template.fields.isEmpty)
                      _buildDefaultAreaField(),

                    const SizedBox(height: 30),

                    ElevatedButton.icon(
                      onPressed: _submit,
                      icon: const Icon(Icons.calculate),
                      label: const Text('احسب برنامجي',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.primaryColor,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(55),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildGovernorateSelector() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: widget.primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _selectedGovernorate == null
              ? Colors.red.shade300
              : widget.primaryColor.withOpacity(0.3),
          width: _selectedGovernorate == null ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on, color: widget.primaryColor, size: 22),
              const SizedBox(width: 8),
              const Text('المحافظة',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(width: 6),
              const Text('*',
                  style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
            ],
          ),
          const SizedBox(height: 8),
          if (_selectedGovernorate == null)
            InkWell(
              onTap: _showGovernoratePicker,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.search, color: Colors.grey, size: 20),
                    SizedBox(width: 8),
                    Text('اضغط لاختيار المحافظة...',
                        style: TextStyle(color: Colors.grey)),
                    Spacer(),
                    Icon(Icons.arrow_drop_down, color: Colors.grey),
                  ],
                ),
              ),
            )
          else
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: widget.primaryColor.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle,
                      color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Text(_selectedGovernorate!,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  const Spacer(),
                  InkWell(
                    onTap: _showGovernoratePicker,
                    child: Text('تغيير',
                        style: TextStyle(
                            color: widget.primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildZoneInfo() {
    final zone = EgyptData.getZoneDetails(_selectedZone!);
    if (zone == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(zone.emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('المنطقة: ${zone.name}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(zone.description,
                        style: const TextStyle(
                            fontSize: 11, color: Colors.black54)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 8),
          const Text('ملاحظات الزراعة في منطقتك:',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.black87)),
          const SizedBox(height: 6),
          ...zone.plantingNotes.map((note) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(fontSize: 12)),
                    Expanded(
                      child: Text(note,
                          style: const TextStyle(
                              fontSize: 11, height: 1.5)),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  void _showGovernoratePicker() {
    String? tempSelected = _selectedGovernorate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Directionality(
          textDirection: TextDirection.rtl,
          child: DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.9,
            expand: false,
            builder: (context, scrollController) => Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.location_on, color: Color(0xFF047857)),
                      SizedBox(width: 8),
                      Text('اختر محافظتك',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: EgyptData.climateZones.map((zone) {
                      final govs =
                          EgyptData.governoratesByZone[zone.id] ?? [];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            child: Row(
                              children: [
                                Text(zone.emoji,
                                    style: const TextStyle(fontSize: 20)),
                                const SizedBox(width: 8),
                                Text(zone.name,
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: widget.primaryColor)),
                              ],
                            ),
                          ),
                          ...govs.map((g) => ListTile(
                                leading: Icon(
                                  tempSelected == g
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_off,
                                  color: tempSelected == g
                                      ? widget.primaryColor
                                      : Colors.grey,
                                ),
                                title: Text(g),
                                onTap: () =>
                                    setSheetState(() => tempSelected = g),
                              )),
                          const Divider(height: 1),
                        ],
                      );
                    }).toList(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: tempSelected == null
                              ? null
                              : () async {
                                  setState(() {
                                    _selectedGovernorate = tempSelected;
                                    _selectedZone = EgyptData
                                        .getZoneByGovernorate(tempSelected!);
                                  });
                                  await _saveGovernorate(tempSelected!);
                                  if (context.mounted) Navigator.pop(context);
                                },
                          icon: const Icon(Icons.check),
                          label: const Text('تأكيد'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.primaryColor,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(50),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultAreaField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        initialValue: '1',
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: 'المساحة (${widget.template.areaUnit})',
          prefixIcon: const Icon(Icons.crop_free),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12)),
          filled: true,
        ),
        validator: (v) {
          if (v == null || v.trim().isEmpty) return 'ادخل المساحة';
          final n = double.tryParse(v);
          if (n == null || n <= 0) return 'ادخل رقم صحيح أكبر من صفر';
          return null;
        },
        onChanged: (v) => _values['area'] = double.tryParse(v) ?? 1,
      ),
    );
  }

  Widget _buildField(FormFieldConfig field) {
    switch (field.type) {
      case 'number':
      case 'slider':
        return _buildNumberField(field);
      case 'dropdown':
        return _buildDropdownField(field);
      case 'text':
      default:
        return _buildTextField(field);
    }
  }

  Widget _buildNumberField(FormFieldConfig field) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        keyboardType: TextInputType.number,
        initialValue: field.defaultValue?.toString(),
        decoration: InputDecoration(
          labelText:
              '${field.label}${field.unit != null ? ' (${field.unit})' : ''}',
          hintText: field.hint,
          prefixIcon: const Icon(Icons.numbers),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12)),
          filled: true,
        ),
        validator: (v) {
          if (field.required && (v == null || v.trim().isEmpty)) {
            return 'ادخل ${field.label}';
          }
          if (v != null && v.trim().isNotEmpty) {
            final n = double.tryParse(v);
            if (n == null) return 'ادخل رقم صحيح';
            if (field.min != null && n < field.min!) {
              return 'أقل قيمة ${field.min}';
            }
            if (field.max != null && n > field.max!) {
              return 'أعلى قيمة ${field.max}';
            }
          }
          return null;
        },
        onChanged: (v) => _values[field.id] = double.tryParse(v) ?? 0,
      ),
    );
  }

  Widget _buildDropdownField(FormFieldConfig field) {
    final current = _values[field.id] ?? field.options.first['value'];
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: current,
        decoration: InputDecoration(
          labelText: field.label,
          prefixIcon: const Icon(Icons.arrow_drop_down_circle),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12)),
          filled: true,
        ),
        items: field.options
            .map((o) => DropdownMenuItem(
                  value: o['value'],
                  child: Text(o['label'] ?? ''),
                ))
            .toList(),
        onChanged: (v) => setState(() => _values[field.id] = v),
        validator: (v) =>
            field.required && v == null ? 'اختر ${field.label}' : null,
      ),
    );
  }

  Widget _buildTextField(FormFieldConfig field) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        decoration: InputDecoration(
          labelText: field.label,
          hintText: field.hint,
          prefixIcon: const Icon(Icons.text_fields),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12)),
          filled: true,
        ),
        validator: (v) => field.required && (v == null || v.trim().isEmpty)
            ? 'ادخل ${field.label}'
            : null,
        onChanged: (v) => _values[field.id] = v,
      ),
    );
  }
}
