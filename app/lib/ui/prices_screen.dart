import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../data/price_snapshot.dart';
import '../logic/prices_cubit.dart';
import 'format.dart';

final _clock = DateFormat('HH:mm:ss', 'en_US');
final _clockShort = DateFormat('HH:mm', 'en_US');

class PricesScreen extends StatelessWidget {
  const PricesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('دهبي'),
        actions: [
          BlocSelector<PricesCubit, PricesState, Connection>(
            selector: (state) => state.connection,
            builder: (context, connection) => Padding(
              padding: const EdgeInsetsDirectional.only(end: 12),
              child: _ConnectionChip(connection),
            ),
          ),
        ],
      ),
      body: BlocBuilder<PricesCubit, PricesState>(
        builder: (context, state) {
          final snapshot = state.snapshot;
          if (snapshot == null) {
            return state.connection == Connection.offline
                ? const _NoData()
                : const Center(child: CircularProgressIndicator());
          }
          return _PricesList(snapshot: snapshot, isStale: state.isStale);
        },
      ),
    );
  }
}

class _PricesList extends StatelessWidget {
  const _PricesList({required this.snapshot, required this.isStale});

  final PriceSnapshot snapshot;
  final bool isStale;

  @override
  Widget build(BuildContext context) {
    final global = snapshot.global;
    final local = snapshot.local;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (isStale) _StaleBanner(updatedAt: snapshot.updatedAt),
        if (global != null) ...[
          _HeroCard(global: global, updatedAt: snapshot.updatedAt),
          const SizedBox(height: 16),
          _Section(
            title: 'السعر العالمي',
            subtitle: 'بيتحدث لوحده · جنيه للجرام',
            children: [
              _PriceRow(label: 'ذهب عيار 24', value: global.gold24),
              _PriceRow(label: 'ذهب عيار 21', value: global.gold21),
              _PriceRow(label: 'ذهب عيار 18', value: global.gold18),
              _PriceRow(label: 'فضة', value: global.silver),
              _PriceRow(
                label: 'أونصة الذهب',
                value: global.goldOunceUsd,
                unit: 'دولار',
              ),
            ],
          ),
        ],
        if (local != null) ...[
          const SizedBox(height: 16),
          _Section(
            title: 'سوق مصر',
            subtitle: local.asOf == null
                ? 'سعر الصاغة · جنيه'
                : 'سعر الصاغة · آخر قراءة ${_clockShort.format(local.asOf!.toLocal())}',
            children: [
              const _QuoteHeader(),
              _QuoteRow(label: 'ذهب عيار 24', quote: local.gold24),
              _QuoteRow(label: 'ذهب عيار 21', quote: local.gold21),
              _QuoteRow(label: 'ذهب عيار 18', quote: local.gold18),
              _QuoteRow(label: 'الجنيه الذهب', quote: local.goldPound),
              _QuoteRow(label: 'فضة', quote: local.silver),
            ],
          ),
        ],
        if (snapshot.usdEgp != null) ...[
          const SizedBox(height: 16),
          _Section(
            title: 'الدولار',
            children: [
              _PriceRow(label: 'دولار أمريكي', value: snapshot.usdEgp),
            ],
          ),
        ],
        const SizedBox(height: 20),
        Text(
          'الأسعار استرشادية وليست نصيحة استثمارية. سعر الصاغة يختلف عن السعر العالمي.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.global, required this.updatedAt});

  final GlobalPrices global;
  final DateTime updatedAt;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'جرام الذهب عيار 21',
              style: text.titleMedium?.copyWith(
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                _AnimatedNumber(
                  value: global.gold21,
                  style: text.displaySmall?.copyWith(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'جنيه',
                  style: text.titleMedium?.copyWith(
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'سعر عالمي · آخر تغيير ${_clock.format(updatedAt.toLocal())}',
              style: text.bodySmall?.copyWith(color: scheme.onPrimaryContainer),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children, this.subtitle});

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: text.titleMedium),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  subtitle!,
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            const SizedBox(height: 6),
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) Divider(height: 1, color: scheme.outlineVariant),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.label, required this.value, this.unit});

  final String label;
  final double? value;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(child: Text(label, style: text.bodyLarge)),
          _AnimatedNumber(
            value: value,
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          if (unit != null) ...[
            const SizedBox(width: 6),
            Text(unit!, style: text.bodySmall),
          ],
        ],
      ),
    );
  }
}

class _QuoteHeader extends StatelessWidget {
  const _QuoteHeader();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Expanded(flex: 4, child: SizedBox()),
          Expanded(
            flex: 3,
            child: Text('تشتري بـ', style: style, textAlign: TextAlign.left),
          ),
          Expanded(
            flex: 3,
            child: Text('تبيع بـ', style: style, textAlign: TextAlign.left),
          ),
        ],
      ),
    );
  }
}

class _QuoteRow extends StatelessWidget {
  const _QuoteRow({required this.label, required this.quote});

  final String label;
  final Quote? quote;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final number = text.titleSmall?.copyWith(fontWeight: FontWeight.w600);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(flex: 4, child: Text(label, style: text.bodyLarge)),
          Expanded(
            flex: 3,
            child: Text(
              egp(quote?.buy),
              style: number,
              textAlign: TextAlign.left,
              textDirection: TextDirection.ltr,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              egp(quote?.sell),
              style: number,
              textAlign: TextAlign.left,
              textDirection: TextDirection.ltr,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows a number and briefly tints it green or red when it moves.
class _AnimatedNumber extends StatefulWidget {
  const _AnimatedNumber({required this.value, this.style});

  final double? value;
  final TextStyle? style;

  @override
  State<_AnimatedNumber> createState() => _AnimatedNumberState();
}

class _AnimatedNumberState extends State<_AnimatedNumber> {
  Color? _flash;

  @override
  void didUpdateWidget(_AnimatedNumber old) {
    super.didUpdateWidget(old);
    final before = old.value;
    final after = widget.value;
    if (before == null || after == null || before == after) return;
    setState(() {
      _flash = after > before ? Colors.green.shade700 : Colors.red.shade700;
    });
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _flash = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.style ?? DefaultTextStyle.of(context).style;
    return AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 300),
      style: base.copyWith(color: _flash ?? base.color),
      child: Text(egp(widget.value), textDirection: TextDirection.ltr),
    );
  }
}

class _ConnectionChip extends StatelessWidget {
  const _ConnectionChip(this.connection);

  final Connection connection;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (label, color) = switch (connection) {
      Connection.live => ('مباشر', Colors.green.shade600),
      Connection.connecting => ('جاري الاتصال', scheme.outline),
      Connection.offline => ('غير متصل', scheme.error),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelLarge),
      ],
    );
  }
}

class _StaleBanner extends StatelessWidget {
  const _StaleBanner({required this.updatedAt});

  final DateTime updatedAt;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final when = DateFormat('d/M HH:mm', 'en_US').format(updatedAt.toLocal());
    return Card(
      color: scheme.errorContainer,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 4, 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'غير محدث · آخر أسعار من $when',
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
            TextButton(
              onPressed: context.read<PricesCubit>().retryNow,
              child: const Text('حاول تاني'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoData extends StatelessWidget {
  const _NoData();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            const Text(
              'مش قادرين نوصل للسيرفر.\nاتأكد من الإنترنت وجرب تاني.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: context.read<PricesCubit>().retryNow,
              child: const Text('حاول تاني'),
            ),
          ],
        ),
      ),
    );
  }
}
