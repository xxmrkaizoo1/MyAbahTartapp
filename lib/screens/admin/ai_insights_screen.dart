import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/order.dart';
import '../../services/format.dart';
import '../../services/local_ai_service.dart';
import '../../services/sales_forecast.dart';
import '../../services/shop_repository.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';

/// Sales forecast, revenue forecast and trend analysis, with a written summary
/// from a model running on the shop's own computer.
class AiInsightsScreen extends StatefulWidget {
  const AiInsightsScreen({super.key});

  /// Six months of orders: enough to spot weekly patterns and compare two periods.
  static const historyDays = 180;

  @override
  State<AiInsightsScreen> createState() => _AiInsightsScreenState();
}

class _AiInsightsScreenState extends State<AiInsightsScreen> {
  late final Stream<List<ShopOrder>> _orders = context.read<ShopRepository>().ordersSince(DateTime.now().subtract(const Duration(days: AiInsightsScreen.historyDays)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI insights')),
      body: StreamBuilder<List<ShopOrder>>(
        stream: _orders,
        builder: (context, snapshot) {
          if (snapshot.hasError) return ErrorView(snapshot.error);
          if (!snapshot.hasData) return const LoadingView();
          return AiInsightsView(orders: snapshot.data!, now: DateTime.now());
        },
      ),
    );
  }
}

class AiInsightsView extends StatefulWidget {
  const AiInsightsView({super.key, required this.orders, required this.now, this.aiFactory = _realService});

  final List<ShopOrder> orders;
  final DateTime now;
  final LocalAiService Function(String url) aiFactory;

  static LocalAiService _realService(String url) => LocalAiService(baseUrl: url);

  @override
  State<AiInsightsView> createState() => _AiInsightsViewState();
}

class _AiInsightsViewState extends State<AiInsightsView> {
  int _days = 7;

  @override
  Widget build(BuildContext context) {
    final history = SalesHistory.fromOrders(widget.orders, widget.now);
    final revenue = Forecast.compute(history.revenue, history.firstDay, _days);
    final sales = Forecast.compute(history.items, history.firstDay, _days);
    final trend = TrendReport.fromOrders(widget.orders, widget.now);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: staggered([
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 7, label: Text('Next 7 days')),
            ButtonSegment(value: 14, label: Text('14 days')),
            ButtonSegment(value: 30, label: Text('30 days')),
          ],
          selected: {_days},
          onSelectionChanged: (value) => setState(() => _days = value.first),
        ),
        const SectionTitle('AI Revenue Forecast', padding: EdgeInsets.fromLTRB(4, 20, 0, 8)),
        if (revenue == null)
          const _NotEnoughData()
        else
          _ForecastPanel(forecast: revenue, format: rm, recent: history.revenue, label: 'Expected net sales'),
        const SectionTitle('AI Sales Forecast', padding: EdgeInsets.fromLTRB(4, 20, 0, 8)),
        if (sales == null)
          const _NotEnoughData()
        else
          _ForecastPanel(forecast: sales, format: (value) => '${value.round()} items', recent: history.items, label: 'Expected items sold'),
        const SectionTitle('AI Trend Analysis', padding: EdgeInsets.fromLTRB(4, 20, 0, 8)),
        _TrendPanel(trend: trend),
        const SectionTitle('AI summary', padding: EdgeInsets.fromLTRB(4, 20, 0, 8)),
        _AiSummaryPanel(
          key: ValueKey(_days),
          factory: widget.aiFactory,
          buildPrompt: () => buildInsightPrompt(days: _days, revenue: revenue, sales: sales, trend: trend),
        ),
      ]),
    );
  }
}

class _NotEnoughData extends StatelessWidget {
  const _NotEnoughData();

  @override
  Widget build(BuildContext context) => const Panel(
    child: Text('Not enough sales yet. A forecast needs at least ${Forecast.minDays} days of history with sales on ${Forecast.minDaysWithSales} or more of them.'),
  );
}

class _ForecastPanel extends StatelessWidget {
  const _ForecastPanel({required this.forecast, required this.format, required this.recent, required this.label});

  final Forecast forecast;
  final String Function(double value) format;
  final List<double> recent;
  final String label;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final error = forecast.pastError;

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label · next ${forecast.daily.length} days', style: TextStyle(color: muted)),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: CountUpText(value: forecast.total, format: format, style: displayFont(context, size: 32, color: context.tart.accent)),
          ),
          Text('Likely ${format(forecast.low)} to ${format(forecast.high)}', style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          _ForecastChart(recent: recent, forecast: forecast),
          const SizedBox(height: 12),
          Text('${forecast.confidence.label} confidence', style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(
            error == null
                ? 'Not enough history yet to test this against real sales.'
                : 'Tested on the latest 7 days of real sales: ${(error * 100).toStringAsFixed(0)}% off.',
            style: TextStyle(fontSize: 13, color: muted),
          ),
        ],
      ),
    );
  }
}

/// The last two weeks in solid bars, then the forecast in lighter ones.
class _ForecastChart extends StatelessWidget {
  const _ForecastChart({required this.recent, required this.forecast});

  static const _pastDays = 14;
  static const _height = 90.0;

  final List<double> recent;
  final Forecast forecast;

  @override
  Widget build(BuildContext context) {
    final past = recent.skip(recent.length > _pastDays ? recent.length - _pastDays : 0).toList();
    final bars = [...past, ...forecast.daily];
    final peak = bars.fold(0.0, (acc, value) => value > acc ? value : acc);
    final accent = context.tart.accent;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return Semantics(
      label: 'Bar chart of the last ${past.length} days followed by ${forecast.daily.length} forecast days',
      child: Column(
        children: [
          Container(
            height: _height,
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.outline)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final (index, value) in bars.indexed)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: Container(
                        height: peak <= 0 || value <= 0 ? 0 : (value / peak * _height).clamp(2.0, _height),
                        decoration: BoxDecoration(
                          color: index < past.length ? accent : accent.withValues(alpha: 0.35),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text('Last ${past.length} days', style: TextStyle(fontSize: 11, color: muted)),
              const Spacer(),
              Text('Forecast', style: TextStyle(fontSize: 11, color: muted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrendPanel extends StatelessWidget {
  const _TrendPanel({required this.trend});

  final TrendReport trend;

  String _changeText(double? change) => change == null ? '' : ' (${change >= 0 ? '▲' : '▼'} ${change.abs().toStringAsFixed(1)}%)';

  String _productText(ProductTrend product) {
    final change = product.change;
    return '${product.previousUnits} → ${product.recentUnits}${change == null ? ' · new' : ' · ${change >= 0 ? '+' : ''}${change.toStringAsFixed(0)}%'}';
  }

  @override
  Widget build(BuildContext context) {
    if (trend.orders == 0) return Panel(child: Text('No sales in the last ${trend.days} days.'));

    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(value, textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Last ${trend.days} days${trend.hasComparison ? ', compared with the ${trend.days} days before' : ''}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 6),
          row('Net sales', '${rm(trend.revenue)}${_changeText(trend.revenueChange)}'),
          row('Orders', '${trend.orders}${_changeText(trend.ordersChange)}'),
          row('Items sold', '${trend.items}${_changeText(trend.itemsChange)}'),
          if (trend.bestWeekday != null) row('Best day', trend.bestWeekday!),
          if (trend.slowestWeekday != null) row('Slowest day', trend.slowestWeekday!),
          if (trend.onlineShare != null) row('Online / counter', '${trend.onlineShare!.toStringAsFixed(0)}% / ${(100 - trend.onlineShare!).toStringAsFixed(0)}%'),
          if (trend.rising.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text('Selling more', style: TextStyle(fontWeight: FontWeight.w800)),
            for (final product in trend.rising) row(product.name, _productText(product)),
          ],
          if (trend.falling.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text('Selling less', style: TextStyle(fontWeight: FontWeight.w800)),
            for (final product in trend.falling) row(product.name, _productText(product)),
          ],
          if (!trend.hasComparison) ...[
            const SizedBox(height: 10),
            Text(
              'Rising and falling products appear once there are ${trend.days * 2} days of sales to compare.',
              style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

class _AiSummaryPanel extends StatefulWidget {
  const _AiSummaryPanel({super.key, required this.factory, required this.buildPrompt});

  final LocalAiService Function(String url) factory;
  final String Function() buildPrompt;

  @override
  State<_AiSummaryPanel> createState() => _AiSummaryPanelState();
}

class _AiSummaryPanelState extends State<_AiSummaryPanel> {
  static const _urlKey = 'local_ai_url';
  static const _modelKey = 'local_ai_model';

  SharedPreferences? _preferences;
  LocalAiService? _service;
  List<String> _models = const [];
  String? _model;
  String? _usedModel;
  String? _summary;
  String? _error;
  bool _connecting = true;
  bool _writing = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _service?.close();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      _preferences = await SharedPreferences.getInstance();
    } catch (error) {
      debugPrint('Device storage unavailable, the AI server address won’t be remembered: $error');
    }
    await _connect(_preferences?.getString(_urlKey) ?? LocalAiService.defaultUrl);
  }

  Future<void> _connect(String url) async {
    _service?.close();
    final service = widget.factory(url);
    _service = service;
    if (mounted) {
      setState(() {
        _connecting = true;
        _error = null;
      });
    }
    try {
      final models = await service.models();
      if (!mounted || !identical(service, _service)) return;
      setState(() {
        _models = models;
        _model = LocalAiService.pickModel(models, _preferences?.getString(_modelKey));
        _error = models.isEmpty ? 'Ollama is running but has no models. Install one with: ollama pull phi3:mini' : null;
      });
    } on LocalAiException catch (error) {
      if (!mounted || !identical(service, _service)) return;
      setState(() {
        _models = const [];
        _model = null;
        _error = error.message;
      });
    } finally {
      if (mounted && identical(service, _service)) setState(() => _connecting = false);
    }
  }

  Future<void> _write() async {
    final service = _service;
    final model = _model;
    if (service == null || model == null) return;
    setState(() {
      _writing = true;
      _error = null;
      _summary = null;
    });
    try {
      final summary = await service.generate(model: model, prompt: widget.buildPrompt());
      if (!mounted || !identical(service, _service)) return;
      setState(() {
        _summary = summary;
        _usedModel = model;
      });
    } on LocalAiException catch (error) {
      if (mounted && identical(service, _service)) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _writing = false);
    }
  }

  Future<void> _editServer() async {
    final controller = TextEditingController(text: _service?.baseUrl ?? LocalAiService.defaultUrl);
    final url = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('AI server address'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(labelText: 'Address', hintText: 'http://192.168.1.10:11434'),
            ),
            const SizedBox(height: 10),
            const Text('On a phone, use the network address of the computer running Ollama.', style: TextStyle(fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Save')),
        ],
      ),
    );
    if (url == null || url.trim().isEmpty || !mounted) return;
    final clean = LocalAiService.normalizeUrl(url);
    _preferences?.setString(_urlKey, clean).catchError((Object error) {
      debugPrint('Couldn’t save the AI server address: $error');
      return false;
    });
    await _connect(clean);
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _connecting
                      ? 'Connecting to the AI server…'
                      : _models.isEmpty
                      ? 'Not connected'
                      : 'Runs on your own computer',
                  style: TextStyle(color: muted),
                ),
              ),
              IconButton(tooltip: 'AI server address', icon: const Icon(Icons.settings_outlined), onPressed: _editServer),
              if (!_connecting) IconButton(tooltip: 'Try connecting again', icon: const Icon(Icons.refresh_rounded), onPressed: () => _connect(_service?.baseUrl ?? LocalAiService.defaultUrl)),
            ],
          ),
          if (_models.isNotEmpty) ...[
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              key: ValueKey(_models.join()),
              initialValue: _model,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Model'),
              items: [for (final model in _models) DropdownMenuItem(value: model, child: Text(model))],
              onChanged: _writing
                  ? null
                  : (value) {
                      setState(() => _model = value);
                      if (value != null) {
                        _preferences?.setString(_modelKey, value).catchError((Object error) {
                          debugPrint('Couldn’t save the AI model: $error');
                          return false;
                        });
                      }
                    },
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _writing ? null : _write,
                icon: const Icon(Icons.auto_awesome_rounded),
                label: Text(_writing ? 'Writing… this can take a minute' : 'Explain these numbers'),
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          if (_summary != null) ...[
            const SizedBox(height: 14),
            SelectableText(_summary!, style: const TextStyle(height: 1.45)),
            const SizedBox(height: 10),
            Text('Written by $_usedModel, which can make mistakes. Trust the figures above over this text.', style: TextStyle(fontSize: 12, color: muted)),
          ],
        ],
      ),
    );
  }
}
