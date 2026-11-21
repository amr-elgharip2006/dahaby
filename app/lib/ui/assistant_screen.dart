import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/assistant_repository.dart';
import '../logic/assistant_cubit.dart';
import '../logic/portfolio_cubit.dart';
import '../logic/prices_cubit.dart';
import '../logic/valuation.dart';
import 'logo.dart';

const _suggestions = [
  'يعني إيه عيار 21؟',
  'ليه سعر الصاغة مختلف عن السعر العالمي؟',
  'محفظتي كسبانة ولا خسرانة وليه؟',
];

String _failureText(AssistantFailure failure) => switch (failure) {
  AssistantFailure.unavailable => 'المساعد مش متاح دلوقتي. جرب بعد شوية.',
  AssistantFailure.tooManyRequests =>
    'وصلت للحد الأقصى من الأسئلة في الساعة. جرب بعد شوية.',
  AssistantFailure.declined =>
    'المساعد مقدرش يجاوب على السؤال ده. جرب تكتبه بشكل تاني.',
  AssistantFailure.offline =>
    'مش قادرين نوصل للمساعد. اتأكد من الإنترنت وجرب تاني.',
};

/// Chat with the assistant about prices and the user's portfolio.
class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// The portfolio at this moment's prices, sent along with every question.
  Object? _portfolio() {
    final portfolio = context.read<PortfolioCubit>().state;
    final summary = PortfolioSummary.compute(
      portfolio.holdings,
      context.read<PricesCubit>().state.snapshot,
      portfolio.basis,
    );
    return portfolioPayload(summary, portfolio.basis);
  }

  void _send([String? text]) {
    final question = (text ?? _input.text).trim();
    if (question.isEmpty) return;
    context.read<AssistantCubit>().ask(question, portfolio: _portfolio());
    _input.clear();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AssistantCubit, AssistantState>(
      listener: (_, _) => _scrollToEnd(),
      builder: (context, state) {
        final cubit = context.read<AssistantCubit>();
        return Scaffold(
          appBar: AppBar(
            title: const Text('المساعد'),
            actions: [
              if (state.turns.isNotEmpty)
                IconButton(
                  tooltip: 'محادثة جديدة',
                  onPressed: state.waiting ? null : cubit.clear,
                  icon: const Icon(Icons.refresh),
                ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: state.turns.isEmpty
                    ? _Welcome(
                        onSummary: () =>
                            cubit.summarize(portfolio: _portfolio()),
                        onSuggestion: _send,
                      )
                    : ListView(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        children: [
                          for (final turn in state.turns) _Bubble(turn: turn),
                          if (state.waiting) const _Typing(),
                          if (state.failure != null)
                            _Failure(
                              text: _failureText(state.failure!),
                              onRetry: () =>
                                  cubit.retry(portfolio: _portfolio()),
                            ),
                        ],
                      ),
              ),
              _InputBar(
                controller: _input,
                enabled: !state.waiting,
                onSend: _send,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.onSummary, required this.onSuggestion});

  final VoidCallback onSummary;
  final ValueChanged<String> onSuggestion;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      children: [
        const Center(child: DahabyLogo(size: 72)),
        const SizedBox(height: 16),
        Text(
          'اسأل دهبي',
          textAlign: TextAlign.center,
          style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          'بيشرح لك الأسعار ومحفظتك بالأرقام.\nمش بيقول لك تشتري أو تبيع.',
          textAlign: TextAlign.center,
          style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          key: const Key('assistant-summary'),
          onPressed: onSummary,
          icon: const Icon(Icons.auto_awesome),
          label: const Text('لخّص لي السوق ومحفظتي'),
        ),
        const SizedBox(height: 20),
        Text(
          'أو جرّب سؤال',
          style: text.labelLarge?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        for (final suggestion in _suggestions)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                title: Text(suggestion, style: text.bodyLarge),
                trailing: Icon(
                  Icons.arrow_forward,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
                onTap: () => onSuggestion(suggestion),
              ),
            ),
          ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.turn});

  final ChatTurn turn;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mine = turn.fromUser;
    const round = Radius.circular(20);
    const tight = Radius.circular(6);
    return Align(
      alignment: mine
          ? AlignmentDirectional.centerStart
          : AlignmentDirectional.centerEnd,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: mine ? scheme.primary : scheme.surfaceContainerLowest,
          border: mine ? null : Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadiusDirectional.only(
            topStart: round,
            topEnd: round,
            bottomStart: mine ? tight : round,
            bottomEnd: mine ? round : tight,
          ),
        ),
        child: SelectableText(
          turn.text,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: mine ? scheme.onPrimary : scheme.onSurface,
            height: 1.7,
          ),
        ),
      ),
    );
  }
}

class _Typing extends StatelessWidget {
  const _Typing();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Text(
              'دهبي بيكتب…',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure({required this.text, required this.onRetry});

  final String text;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 6, 6, 6),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(text, style: TextStyle(color: scheme.onErrorContainer)),
          ),
          TextButton(onPressed: onRetry, child: const Text('حاول تاني')),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.enabled,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool enabled;
  final void Function([String? text]) onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                key: const Key('assistant-input'),
                controller: controller,
                minLines: 1,
                maxLines: 4,
                maxLength: 500,
                textInputAction: TextInputAction.send,
                onSubmitted: enabled ? (_) => onSend() : null,
                decoration: const InputDecoration(
                  hintText: 'اكتب سؤالك…',
                  counterText: '',
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              key: const Key('assistant-send'),
              tooltip: 'إرسال',
              onPressed: enabled ? onSend : null,
              iconSize: 22,
              constraints: const BoxConstraints.tightFor(width: 52, height: 52),
              icon: const Icon(Icons.arrow_upward),
            ),
          ],
        ),
      ),
    );
  }
}
