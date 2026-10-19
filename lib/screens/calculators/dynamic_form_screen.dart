import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/egypt_data.dart';
import '../../models/calculator_models.dart';
import '../../utils/number_utils.dart';
import 'calculator_result_screen.dart';

class DynamicFormScreen extends StatefulWidget {
  final CalculatorTemplate template;
  final Color primaryColor;
  final String? sectionName;

  const DynamicFormScreen({
    super.key,
    required this.template,
    required this.primaryColor,
    this.sectionName,
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
  bool _isSubmitting = false; // ✅ حماية من الضغط المتكرر

  @override
  void initState() {
    super.initState();
    _loadSavedGovernorate();

    for (var field in widget.template.fields) {
      if (field.type == 'dropdown') {
        final options = _usableDropdownOptions(field);
        if (options.isNotEmpty) {
          final d = field.defaultValue?.toString();
          final available = options.map((o) => o['value']).toList();
          _values[field.id] = (d != null && available.contains(d))
              ? d
              : options.first['value'];
        }
      } else if (field.defaultValue != null) {
        _values[field.id] = field.defaultValue;
      }
    }
    
    // ✅ إضافة حقل المساحة لو مش موجود في القالب (لأنه أساسي للحسابات)
    final hasAreaField = widget.template.fields.any((f) => f.id.toLowerCase() == 'area');
    if (!hasAreaField) {
      _values['area'] = 1.0;
    }
  }

  // ✅ التحقق من وجود حقل المساحة
  bool get _needsAreaField {
    return !widget.template.fields.any((f) => f.id.toLowerCase() == 'area');
  }

  Future<void> _loadSavedGovernorate() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('user_governorate');
    if (!mounted) return;
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

  List<Map<String, String>> _usableDropdownOptions(FormFieldConfig field) {
    final options = <Map<String, String>>[];
    final seen = <String>{};
    for (final option in field.options) {
      final value = option['value']?.trim() ?? '';
      final label = option['label']?.trim() ?? '';
      if (value.isEmpty || label.isEmpty || !seen.add(value)) continue;
      options.add({'value': value, 'label': label});
    }
    return options;
  }

  Future<void> _submit() async {
    if (_isSubmitting) return; // منع الضغط المتكرر

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

    setState(() => _isSubmitting = true);

    _values['governorate'] = _selectedGovernorate;
    _values['climate_zone'] = _selectedZone;

    // في حالة لو المساحة لسه متسجلة
    if (_needsAreaField && _values['area'] == null) {
      _values['area'] = 1.0;
    }

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CalculatorResultScreen(
            template: widget.template,
            inputValues: Map<String, dynamic>.from(_values),
            primaryColor: widget.primaryColor,
            sectionName: widget.sectionName,
          ),
        ),
      );
    }
    
    if (mounted) setState(() => _isSubmitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                    // Header
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: widget.primaryColor.withValues(alpha: isDark ? 0.2 : 0.1),
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
                                    style: TextStyle(
                                        fontSize: 12, 
                                        color: isDark ? Colors.grey[400] : Colors.grey)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    _buildGovernorateSelector(isDark),

                    if (_selectedZone != null) _buildZoneInfo(isDark),

                    const SizedBox(height: 20),

                    Text('أدخل بياناتك:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, 
                            fontSize: 15,
                            color: isDark ? Colors.white : Colors.black87)),
                    const SizedBox(height: 12),

                    ...widget.template.fields.map((f) => _buildField(f, isDark)),

                    // ✅ إضافة حقل المساحة لو مش موجود في القالب
                    if (_needsAreaField) _buildDefaultAreaField(isDark),

                    const SizedBox(height: 30),

                    ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _submit,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.calculate),
                      label: Text(
                          _isSubmitting ? 'جاري التجهيز...' : 'احسب برنامجي',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.primaryColor,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(55),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildGovernorateSelector(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: widget.primaryColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _selectedGovernorate == null
              ? Colors.red.shade300
              : widget.primaryColor.withValues(alpha: 0.3),
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
              Text('المحافظة',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, 
                      fontSize: 15,
                      color: isDark ? Colors.white : Colors.black87)),
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
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: Colors.grey, size: 20),
                    const SizedBox(width: 8),
                    const Text('اضغط لاختيار المحافظة...',
                        style: TextStyle(color: Colors.grey)),
                    const Spacer(),
                    const Icon(Icons.arrow_drop_down, color: Colors.grey),
                  ],
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: widget.primaryColor.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle,
                      color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Text(_selectedGovernorate!,
                      style: TextStyle(
                          fontWeight: FontWeight.bold, 
                          fontSize: 14,
                          color: isDark ? Colors.white : Colors.black87)),
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

  Widget _buildZoneInfo(bool isDark) {
    final zone = EgyptData.getZoneDetails(_selectedZone!);
    if (zone == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.amber.shade900.withValues(alpha: 0.3) : Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? Colors.amber.shade700 : Colors.amber.shade200),
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
                        style: TextStyle(
                            fontWeight: FontWeight.bold, 
                            fontSize: 14,
                            color: isDark ? Colors.white : Colors.black87)),
                    const SizedBox(height: 2),
                    Text(zone.description,
                        style: TextStyle(
                            fontSize: 11, 
                            color: isDark ? Colors.grey[400] : Colors.black54)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: isDark ? Colors.grey[800] : null),
          const SizedBox(height: 8),
          Text('ملاحظات الزراعة في منطقتك:',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 6),
          ...zone.plantingNotes.map((note) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ', 
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.black87)),
                    Expanded(
                      child: Text(note,
                          style: TextStyle(
                              fontSize: 11, 
                              height: 1.5,
                              color: isDark ? Colors.grey[300] : Colors.black87)),
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
      builder: (bottomSheetContext) => StatefulBuilder(
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
                                  if (mounted) {
                                    Navigator.of(bottomSheetContext).pop();
                                  }
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

  Widget _buildDefaultAreaField(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        initialValue: _values['area']?.toString() ?? '1',
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: 'المساحة (${widget.template.areaUnit})',
          prefixIcon: const Icon(Icons.crop_free),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: isDark ? const Color(0xFF1E1E1E) : null,
        ),
        validator: (v) {
          if (v == null || v.trim().isEmpty) return 'ادخل المساحة';
          final n = NumberUtils.tryParseDouble(v);
          if (n == null || n <= 0) return 'ادخل رقم صحيح أكبر من صفر';
          return null;
        },
        onChanged: (v) => _values['area'] = NumberUtils.tryParseDouble(v) ?? 1,
      ),
    );
  }

  Widget _buildField(FormFieldConfig field, bool isDark) {
    switch (field.type) {
      case 'number':
      case 'slider':
        return _buildNumberField(field, isDark);
      case 'dropdown':
        return _buildDropdownField(field, isDark);
      case 'text':
      default:
        return _buildTextField(field, isDark);
    }
  }

  Widget _buildNumberField(FormFieldConfig field, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        initialValue: field.defaultValue?.toString(),
        decoration: InputDecoration(
          labelText:
              '${field.label}${field.unit != null ? ' (${field.unit})' : ''}',
          hintText: field.hint,
          prefixIcon: const Icon(Icons.numbers),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: isDark ? const Color(0xFF1E1E1E) : null,
        ),
        validator: (v) {
          if (field.required && (v == null || v.trim().isEmpty)) {
            return 'ادخل ${field.label}';
          }
          if (v != null && v.trim().isNotEmpty) {
            final n = NumberUtils.tryParseDouble(v);
            if (n == null) return 'ادخل رقم صحيح';
            final id = field.id.toLowerCase();
            final isAreaField = id == 'area' ||
                id.contains('area') || field.label.contains('مساحة');
            if (isAreaField && n <= 0) {
              return 'ادخل مساحة أكبر من صفر';
            }
            if (field.min != null && n < field.min!) {
              return 'أقل قيمة ${field.min}';
            }
            if (field.max != null && n > field.max!) {
              return 'أعلى قيمة ${field.max}';
            }
          }
          return null;
        },
        onChanged: (v) {
          final n = NumberUtils.tryParseDouble(v);
          if (n == null) {
            _values.remove(field.id);
          } else {
            _values[field.id] = n;
          }
        },
      ),
    );
  }

  Widget _buildDropdownField(FormFieldConfig field, bool isDark) {
    final options = _usableDropdownOptions(field);
    if (options.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: FormField<String>(
          validator: (_) => field.required ? 'أضف خيارات صالحة لـ ${field.label}' : null,
          builder: (state) => InputDecorator(
            decoration: InputDecoration(
              labelText: field.label,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: isDark ? const Color(0xFF1E1E1E) : null,
              errorText: state.errorText,
            ),
            child: const Text('لا توجد خيارات متاحة لهذا الحقل'),
          ),
        ),
      );
    }
    final current =
        _values[field.id]?.toString() ?? options.first['value']!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        // ✅ استخدام key عشان نجبر الـ Dropdown يتبني من جديد
        key: ValueKey(current),
        initialValue: current,
        decoration: InputDecoration(
          labelText: field.label,
          prefixIcon: const Icon(Icons.arrow_drop_down_circle),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: isDark ? const Color(0xFF1E1E1E) : null,
        ),
        items: options
            .map((o) => DropdownMenuItem(
                  value: o['value'],
                  child: Text(o['label']!),
                ))
            .toList(),
        onChanged: (v) => setState(() => _values[field.id] = v),
        validator: (v) =>
            field.required && v == null ? 'اختر ${field.label}' : null,
      ),
    );
  }

  Widget _buildTextField(FormFieldConfig field, bool isDark) {
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
          fillColor: isDark ? const Color(0xFF1E1E1E) : null,
        ),
        validator: (v) => field.required && (v == null || v.trim().isEmpty)
            ? 'ادخل ${field.label}'
            : null,
        onChanged: (v) => _values[field.id] = v,
      ),
    );
  }
}
