import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:interactive_chart/interactive_chart.dart';
import 'package:trading_app/models/zone_point.dart';
import '../services/api_service.dart';
import 'dart:convert';
import 'dart:collection'; // 👈 Add this line
import 'package:http/http.dart' as http;

class HomeScreen extends StatefulWidget {
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<String> symbols = [
    'RELIANCE.BSE',
    'TATAMOTORS.BSE',
    'INFY.BSE',
    'HDFCBANK.BSE',
    'ICICIBANK.BSE',
    'TCS.BSE',
    'LT.BSE',
    'SBIN.BSE',
    'BHARTIARTL.BSE',
    'AXISBANK.BSE',
    'KOTAKBANK.BSE',
    'BAJFINANCE.BSE',
    'ASIANPAINT.BSE',
    'ITC.BSE',
    'SUNPHARMA.BSE',
    'MARUTI.BSE',
    'ULTRACEMCO.BSE',
    'TECHM.BSE',
    'NTPC.BSE',
    'POWERGRID.BSE',
    'WIPRO.BSE',
    'ONGC.BSE',
    'ADANIENT.BSE',
    'ADANIPORTS.BSE',
    'BAJAJFINSV.BSE',
    'TITAN.BSE',
    'NESTLEIND.BSE',
    'HCLTECH.BSE',
    'GRASIM.BSE',
    'HINDUNILVR.BSE',
    'COALINDIA.BSE',
    'JSWSTEEL.BSE',
    'BPCL.BSE',
    'EICHERMOT.BSE',
    'DIVISLAB.BSE',
    'DRREDDY.BSE',
    'BRITANNIA.BSE',
    'CIPLA.BSE',
    'HEROMOTOCO.BSE',
    'INDUSINDBK.BSE',
    'BAJAJ_AUTO.BSE',
    'SBILIFE.BSE',
    'ICICIPRULI.BSE',
    'HDFCLIFE.BSE',
    'TATACONSUM.BSE',
    'APOLLOHOSP.BSE',
    'HINDALCO.BSE',
    'SHREECEM.BSE',
    'M&M.BSE',
    'UPL.BSE'
  ];

  String? selectedSymbol;
  String selectedTimeframe = '1D';
  List<CandleData> chartCandles = [];
  Map<int, List<String>> patternMarkers = {}; // timestamp -> pattern name
  String selectedFilter = 'All'; // Add near the top in _HomeScreenState

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    loadSymbols();
  }

  Map<double, int> extractSupportResistanceWithStrength(
      List<CandleData> candles) {
    const double tolerance = 0.02; // 2% tolerance
    Map<double, int> levelStrength = {};

    for (int i = 1; i < candles.length - 1; i++) {
      final prev = candles[i - 1];
      final curr = candles[i];
      final next = candles[i + 1];

      // Support
      if ((curr.low ?? 0) < (prev.low ?? 0) &&
          (curr.low ?? 0) < (next.low ?? 0)) {
        final level = curr.low ?? 0;
        final match = levelStrength.keys.firstWhere(
          (l) => (l - level).abs() / level < tolerance,
          orElse: () => -1,
        );
        if (match != -1) {
          levelStrength[match] = levelStrength[match]! + 1;
        } else {
          levelStrength[level] = 1;
        }
      }

      // Resistance
      if ((curr.high ?? 0) > (prev.high ?? 0) &&
          (curr.high ?? 0) > (next.high ?? 0)) {
        final level = curr.high ?? 0;
        final match = levelStrength.keys.firstWhere(
          (l) => (l - level).abs() / level < tolerance,
          orElse: () => -1,
        );
        if (match != -1) {
          levelStrength[match] = levelStrength[match]! + 1;
        } else {
          levelStrength[level] = 1;
        }
      }
    }

    return levelStrength;
  }

  void showSupportResistanceChart(BuildContext context) {
    final levelMap = extractSupportResistanceWithStrength(chartCandles);

    final minPrice =
        chartCandles.map((c) => c.low ?? 0).reduce((a, b) => a < b ? a : b);
    final maxPrice =
        chartCandles.map((c) => c.high ?? 0).reduce((a, b) => a > b ? a : b);
    final midPrice = (minPrice + maxPrice) / 2;

    final supports = levelMap.entries.where((e) => e.key <= midPrice).toList();
    final resistances =
        levelMap.entries.where((e) => e.key > midPrice).toList();

    // Wrap support/resistance in tooltip zones
    final List<ZonePoint> zonePoints = [
      ...supports.map((e) => ZonePoint(e.key, true, e.value)),
      ...resistances.map((e) => ZonePoint(e.key, false, e.value)),
    ];

    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("📐 Support & Resistance Zones",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              SizedBox(
                height: 300,
                child: LineChart(
                  LineChartData(
                    lineBarsData: [
                      // Price Line
                      LineChartBarData(
                        spots: chartCandles
                            .map((c) =>
                                FlSpot(c.timestamp.toDouble(), c.close ?? 0.0))
                            .toList(),
                        isCurved: false,
                        color: Colors.black,
                        barWidth: 1.5,
                        dotData: FlDotData(show: false),
                      ),
                      // Support Lines
                      ...supports.map((e) => LineChartBarData(
                            spots: [
                              FlSpot(chartCandles.first.timestamp.toDouble(),
                                  e.key),
                              FlSpot(chartCandles.last.timestamp.toDouble(),
                                  e.key),
                            ],
                            isCurved: false,
                            color: Colors.blue.withOpacity(0.6),
                            barWidth: 1.5,
                            dashArray: [6, 3],
                            dotData: FlDotData(show: false),
                          )),
                      // Resistance Lines
                      ...resistances.map((e) => LineChartBarData(
                            spots: [
                              FlSpot(chartCandles.first.timestamp.toDouble(),
                                  e.key),
                              FlSpot(chartCandles.last.timestamp.toDouble(),
                                  e.key),
                            ],
                            isCurved: false,
                            color: Colors.red.withOpacity(0.8),
                            barWidth: 2.0,
                            dashArray: [6, 3],
                            dotData: FlDotData(show: false),
                          )),
                    ],
                    titlesData: FlTitlesData(show: false),
                    gridData: FlGridData(show: true),
                    borderData: FlBorderData(show: true),
                    extraLinesData: ExtraLinesData(
                      horizontalLines: [
                        if (supports.isNotEmpty)
                          HorizontalLine(
                            y: supports.first.key,
                            label: HorizontalLineLabel(
                              show: true,
                              alignment: Alignment.centerLeft,
                              style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold),
                              labelResolver: (_) => '🟢 Buy Zone',
                            ),
                            color: Colors.transparent,
                          ),
                        if (resistances.isNotEmpty)
                          HorizontalLine(
                            y: resistances.first.key,
                            label: HorizontalLineLabel(
                              show: true,
                              alignment: Alignment.centerLeft,
                              style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold),
                              labelResolver: (_) => '🔴 Sell Zone',
                            ),
                            color: Colors.transparent,
                          ),
                      ],
                    ),
                    lineTouchData: LineTouchData(
                      handleBuiltInTouches: true,
                      touchTooltipData: LineTouchTooltipData(
                        tooltipBgColor: Colors.black87,
                        getTooltipItems: (touchedSpots) {
                          return touchedSpots.map((spot) {
                            ZonePoint? matchedZone;
                            for (var z in zonePoints) {
                              if ((z.level - spot.y).abs() / z.level < 0.005) {
                                matchedZone = z;
                                break;
                              }
                            }

                            if (matchedZone != null) {
                              final strength = matchedZone.touches >= 4
                                  ? '💪 Strong'
                                  : '⚠️ Weak';
                              final zoneText = matchedZone.isSupport
                                  ? '🟢 Buy Zone'
                                  : '🔴 Sell Zone';
                              final color = matchedZone.isSupport
                                  ? Colors.green
                                  : Colors.red;

                              return LineTooltipItem(
                                '$zoneText\nTouches: ${matchedZone.touches}\n$strength',
                                TextStyle(
                                    color: color, fontWeight: FontWeight.bold),
                              );
                            } else {
                              return LineTooltipItem(
                                '📍 No nearby level',
                                TextStyle(
                                    color: Colors.grey,
                                    fontWeight: FontWeight.normal),
                              );
                            }
                          }).toList();
                        },
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.horizontal_rule, color: Colors.blue, size: 18),
                  Text(" Support Levels  "),
                  Icon(Icons.horizontal_rule, color: Colors.red, size: 18),
                  Text(" Resistance Levels"),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Set<String> getAllDetectedPatterns() {
    final patternSet = <String>{};
    patternMarkers.values.forEach((list) => patternSet.addAll(list));
    return patternSet;
  }

  List<String> getFilterOptions() {
    final allPatterns = getAllDetectedPatterns().toList()..sort();
    return ['All', ...allPatterns];
  }

  bool patternMatchesFilter(String pattern) {
    final lower = pattern.toLowerCase();
    if (selectedFilter == 'All') return true;
    if (selectedFilter == 'Bullish') return lower.contains('bull');
    if (selectedFilter == 'Bearish') return lower.contains('bear');
    return pattern == selectedFilter;
  }

  void showPatternDetails(String patternName) async {
    final info = await ApiService.fetchPatternInfo(patternName);

    if (info == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No detailed info found for $patternName")),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(info.title,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo)),
              const SizedBox(height: 10),
              Text("📘 Type: ${info.type}",
                  style: TextStyle(
                      fontWeight: FontWeight.w500, color: Colors.black87)),
              const SizedBox(height: 10),
              if (info.image.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Image.memory(
                    base64Decode(info.image.split(',').last),
                    height: 150,
                    fit: BoxFit.contain,
                  ),
                ),
              const SizedBox(height: 10),
              Text(info.description,
                  style: TextStyle(color: Colors.black87),
                  textAlign: TextAlign.justify),
              const SizedBox(height: 10),
              Text("💡 Trade Tip:",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(info.tradeTip, textAlign: TextAlign.justify),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void showPatternHistorySheet(BuildContext context) {
    final sortedTimestamps = patternMarkers.keys.toList()..sort();
    final List<Widget> historyWidgets = [];

    for (var ts in sortedTimestamps) {
      final patterns = patternMarkers[ts]!;
      final date = DateTime.fromMillisecondsSinceEpoch(ts)
          .toLocal()
          .toString()
          .split(' ')
          .first;

      for (var pattern in patterns.where(patternMatchesFilter)) {
        Color color;
        IconData icon;

        if (pattern.toLowerCase().contains("bull")) {
          color = Colors.green;
          icon = Icons.trending_up;
        } else if (pattern.toLowerCase().contains("bear")) {
          color = Colors.red;
          icon = Icons.trending_down;
        } else {
          color = Colors.orange;
          icon = Icons.remove_circle_outline;
        }

        historyWidgets.add(
          ListTile(
            leading: Icon(icon, color: color),
            title: Text(pattern),
            subtitle: Text("📅 $date"),
            onTap: () => showPatternDetails(pattern),
          ),
        );
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "📘 Pattern History",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: historyWidgets.isEmpty
                  ? Center(child: Text("No patterns detected yet."))
                  : ListView(children: historyWidgets),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> getPatternSummaryChips() {
    final List<int> sortedTimestamps = patternMarkers.keys.toList()
      ..sort((a, b) => a.compareTo(b)); // sort from oldest to newest

    final LinkedHashSet<String> orderedPatterns = LinkedHashSet();
    for (final ts in sortedTimestamps) {
      for (final pattern in patternMarkers[ts]!) {
        if (patternMatchesFilter(pattern)) {
          orderedPatterns.add(pattern);
        }
      }
    }

    return orderedPatterns.map((pattern) {
      Color chipColor;
      IconData chipIcon;

      if (pattern.toLowerCase().contains("bull")) {
        chipColor = Colors.green;
        chipIcon = Icons.trending_up;
      } else if (pattern.toLowerCase().contains("bear")) {
        chipColor = Colors.red;
        chipIcon = Icons.trending_down;
      } else {
        chipColor = Colors.orange;
        chipIcon = Icons.remove_circle_outline;
      }

      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: () => showPatternDetails(pattern),
          child: Chip(
            label: Text(pattern),
            avatar: Icon(chipIcon, size: 18, color: Colors.white),
            backgroundColor: chipColor,
            labelStyle: TextStyle(color: Colors.white),
          ),
        ),
      );
    }).toList();
  }

  String getTrendLabel(List<CandleData> candles) {
    if (candles.length < 6) return '🔄 Not enough data';

    double avg(List<double> values) =>
        values.reduce((a, b) => a + b) / values.length;

    final last3 =
        candles.sublist(candles.length - 3).map((e) => e.close!).toList();
    final prev3 = candles
        .sublist(candles.length - 6, candles.length - 3)
        .map((e) => e.close!)
        .toList();

    final lastAvg = avg(last3);
    final prevAvg = avg(prev3);

    if (lastAvg > prevAvg * 1.01) return '📈 Uptrend';
    if (lastAvg < prevAvg * 0.99) return '📉 Downtrend';
    return '🔄 Sideways';
  }

  Future<void> loadSymbols() async {
    final fetchedSymbols = await ApiService.fetchSymbols();
    if (fetchedSymbols.isNotEmpty) {
      setState(() {
        // Avoid duplicates
        symbols = [
          ...symbols,
          ...fetchedSymbols.where((s) => !symbols.contains(s)),
        ];
        selectedSymbol ??= symbols.first;
      });
      await loadCandles();
    }
  }

  Future<void> loadCandles() async {
    if (selectedSymbol == null) return;

    setState(() => isLoading = true);
    print("📡 Selected: $selectedSymbol | Timeframe: $selectedTimeframe");

    final stored = await ApiService.fetchAndStoreCandles(
      selectedSymbol!,
      selectedTimeframe,
    );

    if (!stored) {
      print("❌ Alpha fetch failed");
      setState(() => isLoading = false);
      return;
    }

    final url = Uri.parse(
      "${ApiService.baseUrl}/trading_app/fetch_patterns.php?symbol=$selectedSymbol&timeframe=$selectedTimeframe",
    );
    final res = await http.get(url);
    final data = jsonDecode(res.body);

    if (data["status"] == "success") {
      final List candlesJson = data["candles"];
      final List patternsJson = data["patterns"];

      List<CandleData> tempCandles = [];
      patternMarkers.clear();

      for (var item in candlesJson) {
        final dt = DateTime.parse(item['date']);
        tempCandles.add(CandleData(
          timestamp: dt.millisecondsSinceEpoch,
          open: item['open'].toDouble(),
          high: item['high'].toDouble(),
          low: item['low'].toDouble(),
          close: item['close'].toDouble(),
          volume: item['volume'].toDouble(),
        ));
      }

      for (var p in patternsJson) {
        final dt = DateTime.parse(p['date']);
        final timestamp = dt.millisecondsSinceEpoch;
        final pattern = p['pattern'];

        if (!patternMarkers.containsKey(timestamp)) {
          patternMarkers[timestamp] = [];
        }
        patternMarkers[timestamp]!.add(pattern);
      }

      setState(() {
        chartCandles = tempCandles;
        isLoading = false;
      });

      print(
          "✅ Loaded ${chartCandles.length} candles with ${patternMarkers.length} markers");
    } else {
      print("❌ Pattern API failed");
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Trade Mentor'),
        actions: [
          IconButton(
            icon: Icon(Icons.show_chart_rounded),
            tooltip: "Support/Resistance",
            onPressed: () => showSupportResistanceChart(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // 🔽 Dropdowns
            Row(
              children: [
                Expanded(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: selectedSymbol,
                    hint: Text("Select Symbol"),
                    items: symbols
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (val) {
                      setState(() => selectedSymbol = val);
                      loadCandles();
                    },
                  ),
                ),
                SizedBox(width: 10),
                DropdownButton<String>(
                  value: selectedTimeframe,
                  items: ['1D', '1W', '1M', '5min']
                      .map((tf) => DropdownMenuItem(value: tf, child: Text(tf)))
                      .toList(),
                  onChanged: (val) {
                    setState(() => selectedTimeframe = val!);
                    loadCandles();
                  },
                ),
              ],
            ),
            Row(
              children: [
                Text("🧮 Filter: "),
                DropdownButton<String>(
                  value: selectedFilter,
                  items: getFilterOptions()
                      .map((type) =>
                          DropdownMenuItem(value: type, child: Text(type)))
                      .toList(),
                  onChanged: (val) {
                    setState(() => selectedFilter = val!);
                  },
                ),
              ],
            ),
            SizedBox(height: 8),

            // 🟡 Pattern Summary Chips
            if (patternMarkers.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📌 Patterns Detected In Chart',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 6),
                  Container(
                    alignment: Alignment.centerLeft,
                    width: double.infinity, // ✅ Take full width of the screen
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: getPatternSummaryChips(),
                      ),
                    ),
                  ),
                ],
              ),

            SizedBox(height: 10),

            // 📊 Chart Section
            Expanded(
              child: isLoading
                  ? Center(child: CircularProgressIndicator())
                  : chartCandles.isEmpty
                      ? Center(child: Text("No data available"))
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final trend = getTrendLabel(chartCandles);
                            final trendColor = trend.contains('Up')
                                ? Colors.green
                                : trend.contains('Down')
                                    ? Colors.red
                                    : Colors.orange;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 📈 Smart Trend Badge
                                Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: trendColor,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: trendColor.withOpacity(0.3),
                                        blurRadius: 6,
                                        offset: Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    trend,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),

                                SizedBox(height: 10),

                                // Chart
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                        bottom: 60), // 👈 prevent overlap
                                    child: Stack(
                                      children: [
                                        InteractiveChart(
                                          candles: chartCandles,
                                          overlayInfo: (candle) {
                                            final patterns = patternMarkers[
                                                candle.timestamp];
                                            final filtered = patterns
                                                    ?.where(
                                                        patternMatchesFilter)
                                                    .toList() ??
                                                [];
                                            final patternText =
                                                filtered.isNotEmpty
                                                    ? filtered.join("\n")
                                                    : null;

                                            final open = candle.open
                                                    ?.toStringAsFixed(2) ??
                                                '-';
                                            final close = candle.close
                                                    ?.toStringAsFixed(2) ??
                                                '-';
                                            final high = candle.high
                                                    ?.toStringAsFixed(2) ??
                                                '-';
                                            final low = candle.low
                                                    ?.toStringAsFixed(2) ??
                                                '-';

                                            final dateStr = DateTime
                                                    .fromMillisecondsSinceEpoch(
                                                        candle.timestamp)
                                                .toLocal()
                                                .toString()
                                                .split(' ')
                                                .first;

                                            return {
                                              if (patternText != null)
                                                '📌 Patterns': patternText,
                                              '🟢 Open': open,
                                              '🔴 Close': close,
                                              '🔺 High': high,
                                              '🔻 Low': low,
                                              '📅 Date': dateStr,
                                            };
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
            )
          ],
        ),
      ),
      floatingActionButton: patternMarkers.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => showPatternHistorySheet(context),
              icon: Icon(Icons.history, color: Colors.white), // 👈 icon color
              label: Text(
                "Pattern History",
                style: TextStyle(color: Colors.white), // 👈 text color
              ),
              backgroundColor: Colors.indigo, // 👈 button bg
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
