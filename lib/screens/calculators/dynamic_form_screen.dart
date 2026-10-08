import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
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

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

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
        child: Form(
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
              const Text('أدخل بياناتك:',
                  style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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
