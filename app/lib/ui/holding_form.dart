import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../data/holding.dart';
import '../logic/portfolio_cubit.dart';
import '../logic/prices_cubit.dart';
import '../logic/valuation.dart';

/// Add a purchase, or edit [existing].
class HoldingForm extends StatefulWidget {
  const HoldingForm({super.key, this.existing});

  final Holding? existing;

  @override
  State<HoldingForm> createState() => _HoldingFormState();
}

class _HoldingFormState extends State<HoldingForm> {
  final _formKey = GlobalKey<FormState>();
  late Asset _asset = widget.existing?.asset ?? Asset.gold21;
  late DateTime _boughtOn = widget.existing?.boughtOn ?? DateTime.now();
  late final _quantity = TextEditingController(
    text: _plain(widget.existing?.quantity),
  );
  late final _price = TextEditingController(
    text: _plain(widget.existing?.buyPrice),
  );
  bool _priceTouched = false;
  bool _saving = false;

  static String _plain(double? v) {
    if (v == null) return '';
    return v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
  }

  @override
  void initState() {
    super.initState();
    if (widget.existing == null) _suggestPrice();
  }

  @override
  void dispose() {
    _quantity.dispose();
    _price.dispose();
    super.dispose();
  }

  /// Fills the price with today's price until the user types their own.
  void _suggestPrice() {
    if (_priceTouched) return;
    final today = unitPrice(
      _asset,
      context.read<PricesCubit>().state.snapshot,
      context.read<PortfolioCubit>().state.basis,
    );
    _price.text = today == null ? '' : today.toStringAsFixed(2);
  }

  String? _positive(String? text) {
    final value = parseNumber(text ?? '');
    if (value == null) return 'اكتب رقم صحيح';
    if (value <= 0) return 'لازم يكون أكبر من صفر';
    return null;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _boughtOn,
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _boughtOn = picked);
  }

  Future<void> _submit() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final cubit = context.read<PortfolioCubit>();
    final quantity = parseNumber(_quantity.text)!;
    final buyPrice = parseNumber(_price.text)!;
    final existing = widget.existing;
    if (existing == null) {
      await cubit.add(
        asset: _asset,
        quantity: quantity,
        buyPrice: buyPrice,
        boughtOn: _boughtOn,
      );
    } else {
      await cubit.save(
        Holding(
          id: existing.id,
          asset: _asset,
          quantity: quantity,
          buyPrice: buyPrice,
          boughtOn: _boughtOn,
        ),
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'تعديل عملية' : 'إضافة عملية شراء')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<Asset>(
              initialValue: _asset,
              decoration: const InputDecoration(labelText: 'النوع'),
              items: [
                for (final asset in Asset.values)
                  DropdownMenuItem(value: asset, child: Text(asset.label)),
              ],
              onChanged: (asset) {
                if (asset == null) return;
                setState(() => _asset = asset);
                if (!editing) _suggestPrice();
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('quantity'),
              controller: _quantity,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: 'الكمية',
                suffix: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(_asset.unit),
                ),
              ),
              validator: _positive,
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('price'),
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: 'سعر الشراء لكل ${_asset.unit}',
                suffix: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text('جنيه'),
                ),
                helperText: editing || _priceTouched
                    ? null
                    : 'مكتوب سعر النهارده، غيّره لو اشتريت بسعر تاني',
              ),
              onChanged: (_) => setState(() => _priceTouched = true),
              validator: _positive,
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(4),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'تاريخ الشراء',
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(
                  DateFormat('d/M/y', 'en_US').format(_boughtOn),
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.right,
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(editing ? 'حفظ التعديل' : 'إضافة'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
