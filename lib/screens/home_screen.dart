import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:http/http.dart' as http;
import 'package:interactive_chart/interactive_chart.dart';
import 'package:intl/intl.dart';
import 'package:trading_app/screens/patterns_library_screen.dart';
import 'package:trading_app/screens/settings_screen.dart';
import 'package:trading_app/screens/pattern_detail_screen.dart';
import 'package:trading_app/screens/watchlist_screen.dart';
import 'package:trading_app/themes/app_theme.dart';
import '../services/api_service.dart';
import '../models/candle.dart';
import '../utils/mock_data.dart';

// Global key to access HomeScreen state from anywhere
final GlobalKey<_HomeScreenState> homeScreenKey = GlobalKey<_HomeScreenState>();

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late TabController _tabController;

  // Trading data
  List<String> symbols = [];
  String? selectedSymbol;
  String selectedTimeframe = '1D';
  List<Candle> candles = [];
  Map<int, List<String>> patternMarkers = {};

  // UI States
  bool isLoading = false;
  bool isRefreshing = false;

  // Market metrics
  double currentPrice = 0;
  double priceChange = 0;
  double priceChangePercent = 0;

  // Mock mode for development
  bool useMockData = true;

  // Zoom/Scroll state
  List<Candle> _displayedCandles = [];
  int? _zoomStartIndex;
  int? _zoomEndIndex;
  DateTime? _selectedDateForHighlight;
  bool _isZoomed = false; // Add this variable to track zoom state

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _displayedCandles = []; // Initialize empty
    _loadInitialData();
  }

  // Public method to change symbol from watchlist
  void changeSymbol(String symbol) {
    setState(() {
      selectedSymbol = symbol;
      _resetZoom();
      _loadCandles();
    });
  }

  // Public method to change tab
  void changeTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _resetZoom() {
    _zoomStartIndex = null;
    _zoomEndIndex = null;
    _selectedDateForHighlight = null;
    _isZoomed = false;
  }

  Future<void> _loadInitialData() async {
    setState(() => isLoading = true);

    try {
      final fetchedSymbols = await ApiService.fetchSymbols();

      if (fetchedSymbols.isNotEmpty) {
        setState(() {
          symbols = fetchedSymbols;
          selectedSymbol = symbols.first;
        });
        await _loadCandles();
      } else {
        setState(() {
          symbols = MockDataGenerator.getMockSymbols();
          selectedSymbol = symbols.first;
        });
        await _loadMockCandles();
      }
    } catch (e) {
      print("Error: $e");
      setState(() {
        symbols = MockDataGenerator.getMockSymbols();
        selectedSymbol = symbols.first;
      });
      await _loadMockCandles();
    }

    setState(() => isLoading = false);
  }

  Future<void> _loadMockCandles() async {
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {
      candles = MockDataGenerator.generateMockCandles(selectedSymbol!, 50);
      patternMarkers = MockDataGenerator.generateMockPatterns(candles);
      _updateDisplayedCandles();
      _updateMarketMetrics();
    });
  }

  Future<void> _loadCandles() async {
    if (selectedSymbol == null) return;

    setState(() => isLoading = true);

    // Reset zoom state before loading new data
    _resetZoomView();

    print("📡 Loading candles for: $selectedSymbol | $selectedTimeframe");

    try {
      // Fetch and store real data from Alpha Vantage
      final result = await ApiService.fetchAndStoreCandles(
          selectedSymbol!, selectedTimeframe);

      String dataSource = result['source'];
      print("📊 Data source: $dataSource");

      if (!result['success']) {
        print("⚠️ Failed to fetch from Alpha Vantage");
        setState(() => isLoading = false);
        return;
      }

      // Show snackbar with data source info
      if (mounted) {
        String message = dataSource == 'cache'
            ? '📦 Loaded from cache (no API call)'
            : '🌐 Fetched fresh data from Alpha Vantage';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: Duration(seconds: 2),
            backgroundColor:
                dataSource == 'cache' ? Colors.orange : Colors.green,
          ),
        );
      }

      // Fetch patterns and candles from your database
      final url = Uri.parse(
        "${ApiService.baseUrl}/fetch_patterns.php?symbol=$selectedSymbol&timeframe=$selectedTimeframe",
      );

      final res = await http.get(url);
      print("📡 Patterns response status: ${res.statusCode}");

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        if (data["status"] == "success") {
          final List candlesJson = data["candles"];
          final List patternsJson = data["patterns"];

          print("✅ Got ${candlesJson.length} candles from database");

          List<Candle> tempCandles = [];
          Map<int, List<String>> tempMarkers = {};

          for (var item in candlesJson) {
            tempCandles.add(Candle(
              date: item['date'],
              open: double.parse(item['open'].toString()),
              high: double.parse(item['high'].toString()),
              low: double.parse(item['low'].toString()),
              close: double.parse(item['close'].toString()),
              volume: int.parse(item['volume'].toString()),
            ));
          }

          for (var p in patternsJson) {
            final timestamp = DateTime.parse(p['date']).millisecondsSinceEpoch;
            if (!tempMarkers.containsKey(timestamp)) {
              tempMarkers[timestamp] = [];
            }
            tempMarkers[timestamp]!.add(p['pattern']);
          }

          setState(() {
            candles = tempCandles;
            patternMarkers = tempMarkers;
            _updateDisplayedCandles();
            _updateMarketMetrics();
          });

          print("✅ Loaded ${candles.length} candles");
          setState(() => isLoading = false);
          return;
        }
      }

      print("⚠️ No data found in database");
      await _loadMockCandles();
    } catch (e) {
      print("🔥 Error: $e");
      await _loadMockCandles();
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _updateMarketMetrics() {
    if (candles.isNotEmpty) {
      currentPrice = candles.last.close;
      if (candles.length > 1) {
        priceChange = candles.last.close - candles[candles.length - 2].close;
        priceChangePercent =
            (priceChange / candles[candles.length - 2].close) * 100;
      }
    }
  }

  String getTrendLabel() {
    if (candles.length < 6) return 'Neutral';

    double avg(List<double> values) =>
        values.reduce((a, b) => a + b) / values.length;

    final last3 =
        candles.sublist(candles.length - 3).map((e) => e.close).toList();
    final prev3 = candles
        .sublist(candles.length - 6, candles.length - 3)
        .map((e) => e.close)
        .toList();

    final lastAvg = avg(last3);
    final prevAvg = avg(prev3);

    if (lastAvg > prevAvg * 1.01) return 'Bullish';
    if (lastAvg < prevAvg * 0.99) return 'Bearish';
    return 'Sideways';
  }

  Color getTrendColor() {
    String trend = getTrendLabel();
    if (trend == 'Bullish') return AppTheme.accentGreen;
    if (trend == 'Bearish') return AppTheme.accentRed;
    return AppTheme.accentYellow;
  }

  void _updateDisplayedCandles() {
    print("🔄 Updating displayed candles...");
    print("Zoom start: $_zoomStartIndex, Zoom end: $_zoomEndIndex");
    print("Total candles: ${candles.length}");

    if (_zoomStartIndex != null &&
        _zoomEndIndex != null &&
        _zoomStartIndex! >= 0 &&
        _zoomEndIndex! < candles.length &&
        _zoomStartIndex! <= _zoomEndIndex!) {
      // Ensure the indices are within bounds
      final start = _zoomStartIndex!.clamp(0, candles.length - 1);
      final end = _zoomEndIndex!.clamp(start, candles.length - 1);

      _displayedCandles = candles.sublist(start, end + 1);
      print(
          "✅ Zoomed view: ${_displayedCandles.length} candles (${start} to ${end})");
      _isZoomed = true;
    } else {
      _displayedCandles = List.from(candles); // Create a new list instance
      print("✅ Full view: ${_displayedCandles.length} candles");
      _isZoomed = false;
    }

    // Verify the update
    if (_displayedCandles.isEmpty && candles.isNotEmpty) {
      print(
          "⚠️ Warning: Displayed candles is empty but total candles is ${candles.length}");
      _displayedCandles = List.from(candles);
      _isZoomed = false;
    }
  }

  Future<void> _scrollToDate(DateTime targetDate) async {
    if (candles.isEmpty) {
      print("❌ No candles available");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No chart data available'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    print(
        "🔍 Looking for date: ${DateFormat('yyyy-MM-dd').format(targetDate)}");
    print(
        "📊 Available candle dates: ${candles.map((c) => c.date).take(5).toList()}...");

    // Find the index of the candle with matching date
    int targetIndex = -1;
    final targetDateStr = DateFormat('yyyy-MM-dd').format(targetDate);

    for (int i = 0; i < candles.length; i++) {
      String candleDateStr = candles[i].date;
      DateTime? candleDate;

      // Try different date formats
      try {
        candleDate = DateTime.parse(candleDateStr);
      } catch (e) {
        try {
          List<String> parts = candleDateStr.split('/');
          if (parts.length == 3) {
            candleDate = DateTime(
                int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
          }
        } catch (e2) {
          print("⚠️ Could not parse date: $candleDateStr");
          continue;
        }
      }

      if (candleDate != null) {
        final candleDateStrFormatted =
            DateFormat('yyyy-MM-dd').format(candleDate);
        if (candleDateStrFormatted == targetDateStr) {
          targetIndex = i;
          print("✅ Found match at index $targetIndex");
          break;
        }
      }
    }

    if (targetIndex != -1) {
      // Calculate zoom range
      int startIndex = (targetIndex - 10).clamp(0, candles.length - 1);
      int endIndex = (targetIndex + 10).clamp(0, candles.length - 1);

      if (endIndex - startIndex < 5) {
        startIndex = (targetIndex - 5).clamp(0, candles.length - 1);
        endIndex = (targetIndex + 5).clamp(0, candles.length - 1);
      }

      print("📍 Zooming to range: $startIndex to $endIndex");

      setState(() {
        _zoomStartIndex = startIndex;
        _zoomEndIndex = endIndex;
        _selectedDateForHighlight = targetDate;
        _updateDisplayedCandles();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '📍 Showing ${DateFormat('MMM dd, yyyy').format(targetDate)}'),
          duration: const Duration(seconds: 2),
          backgroundColor: AppTheme.accentGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _selectedDateForHighlight = null;
          });
        }
      });
    } else {
      // Date not found - show error
      _showDateNotFoundError(targetDate);
    }
  }

  void _showDateNotFoundError(DateTime targetDate) {
    // Find the closest date
    int closestIndex = 0;
    int smallestDiff = double.maxFinite.toInt();
    final targetMillis = targetDate.millisecondsSinceEpoch;

    for (int i = 0; i < candles.length; i++) {
      try {
        DateTime candleDate = DateTime.parse(candles[i].date);
        int diff = (candleDate.millisecondsSinceEpoch - targetMillis).abs();
        if (diff < smallestDiff) {
          smallestDiff = diff;
          closestIndex = i;
        }
      } catch (e) {
        continue;
      }
    }

    String closestDateStr = "unknown";
    DateTime? closestDate;
    try {
      closestDate = DateTime.parse(candles[closestIndex].date);
      closestDateStr = DateFormat('MMM dd, yyyy').format(closestDate);
    } catch (e) {}

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('⚠️ Date not found. Closest: $closestDateStr'),
        duration: const Duration(seconds: 3),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Show Closest',
          textColor: Colors.white,
          onPressed: () {
            if (closestDate != null) {
              _scrollToDate(closestDate);
            }
          },
        ),
      ),
    );
  }

  void _debugDateFormats() {
    print("=== Date Format Debug ===");
    print("Candles count: ${candles.length}");
    if (candles.isNotEmpty) {
      print("First candle date: ${candles[0].date}");
      print("Last candle date: ${candles[candles.length - 1].date}");
    }

    print("Pattern marker dates:");
    patternMarkers.keys.take(5).forEach((timestamp) {
      final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
      print(
          "  Pattern date: ${DateFormat('yyyy-MM-dd').format(date)} (timestamp: $timestamp)");
    });
    print("========================");
  }

  // Method to reset zoom and show full chart
  void _resetZoomView() {
    print("🔄 Resetting zoom view...");
    print(
        "Before reset - zoomStart: $_zoomStartIndex, zoomEnd: $_zoomEndIndex");

    setState(() {
      // Clear all zoom-related variables
      _zoomStartIndex = null;
      _zoomEndIndex = null;
      _selectedDateForHighlight = null;
      _isZoomed = false;

      // Reset displayed candles to full list
      _displayedCandles =
          List.from(candles); // Create a new list to ensure refresh
    });

    print(
        "After reset - displayed candles: ${_displayedCandles.length} (total: ${candles.length})");

    // Force a rebuild of the chart
    if (mounted) {
      // Show confirmation message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Reset to full chart view'),
          duration: Duration(seconds: 1),
          backgroundColor: AppTheme.accentGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: homeScreenKey,
      appBar: _buildAppBar(),
      body: isLoading
          ? _buildLoadingShimmer()
          : Column(
              children: [
                // Improved reset button - shows when zoomed
                if (_isZoomed ||
                    (_zoomStartIndex != null && _zoomEndIndex != null) ||
                    (_displayedCandles.length != candles.length &&
                        candles.isNotEmpty))
                  Container(
                    margin: const EdgeInsets.all(8),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _resetZoomView();
                      },
                      icon: const Icon(Icons.zoom_out, size: 16),
                      label: const Text('Reset to Full Chart'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        textStyle: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                Expanded(
                  child: IndexedStack(
                    index: _currentIndex,
                    children: [
                      _buildMainContent(),
                      const PatternsLibraryScreen(),
                      WatchlistScreen(onSymbolSelected: (symbol) {
                        changeSymbol(symbol);
                        changeTab(0);
                      }),
                      const SettingsScreen(),
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: _buildBottomNavigation(),
      floatingActionButton:
          _currentIndex == 0 && patternMarkers.isNotEmpty ? _buildFAB() : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Column(
        children: [
          Text(
            selectedSymbol?.replaceAll('.BSE', '') ?? 'Select Stock',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          if (currentPrice > 0)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '₹${NumberFormat('#,##0.00').format(currentPrice)}',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.normal),
                ),
                const SizedBox(width: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: priceChange >= 0
                        ? AppTheme.accentGreen
                        : AppTheme.accentRed,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${priceChange >= 0 ? "+" : ""}${priceChangePercent.toStringAsFixed(2)}%',
                    style: const TextStyle(
                        fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: () => _showSymbolSearch(),
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () => _refreshData(),
        ),
      ],
    );
  }

  Widget _buildMainContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 80),
            child: Column(
              children: [
                _buildTimeframeSelector(),
                _buildTrendIndicator(),
                // Add pattern indicator right after trend indicator
                if (patternMarkers.isNotEmpty) _buildPatternIndicator(),
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.5,
                  child: _buildChart(),
                ),
                if (patternMarkers.isNotEmpty) _buildPatternsSection(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPatternIndicator() {
    if (patternMarkers.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListView.builder(
        key: _patternIndicatorKey,
        scrollDirection: Axis.horizontal,
        itemCount: patternMarkers.length,
        itemBuilder: (context, index) {
          final timestamp = patternMarkers.keys.toList()[index];
          final patterns = patternMarkers[timestamp]!;
          final date = DateTime.fromMillisecondsSinceEpoch(timestamp);

          // Determine pattern type
          bool isBullish = patterns.any((p) =>
              p.toLowerCase().contains('bull') ||
              p.toLowerCase().contains('up'));
          bool isBearish = patterns.any((p) =>
              p.toLowerCase().contains('bear') ||
              p.toLowerCase().contains('down'));

          Color indicatorColor = isBullish
              ? AppTheme.accentGreen
              : isBearish
                  ? AppTheme.accentRed
                  : AppTheme.accentYellow;

          // Check if this date is selected for highlighting
          bool isSelected = _selectedDateForHighlight != null &&
              date.year == _selectedDateForHighlight!.year &&
              date.month == _selectedDateForHighlight!.month &&
              date.day == _selectedDateForHighlight!.day;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? indicatorColor.withOpacity(0.4)
                  : indicatorColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: indicatorColor,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: indicatorColor.withOpacity(0.5),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: GestureDetector(
              onTap: () {
                _showPatternAtDate(date, patterns);
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: indicatorColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    DateFormat('MMM dd').format(date),
                    style: TextStyle(
                      color: indicatorColor,
                      fontSize: 11,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '(${patterns.length})',
                    style: TextStyle(
                      color: indicatorColor,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showPatternAtDate(DateTime date, List<String> patterns) {
    // Ensure we have a valid date
    final normalizedDate = DateTime(date.year, date.month, date.day);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.textSecondary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '📊 Patterns on ${DateFormat('MMM dd, yyyy').format(normalizedDate)}',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context); // Close bottom sheet
                    // Add a small delay to ensure bottom sheet is closed
                    await Future.delayed(const Duration(milliseconds: 100));
                    await _scrollToDate(normalizedDate);
                  },
                  icon: const Icon(Icons.timeline, size: 18),
                  label: const Text('Go to Chart & Zoom'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...patterns.map((pattern) => ListTile(
                  leading: Icon(
                    pattern.toLowerCase().contains('bull')
                        ? Icons.trending_up
                        : pattern.toLowerCase().contains('bear')
                            ? Icons.trending_down
                            : Icons.remove,
                    color: pattern.toLowerCase().contains('bull')
                        ? AppTheme.accentGreen
                        : pattern.toLowerCase().contains('bear')
                            ? AppTheme.accentRed
                            : AppTheme.accentYellow,
                  ),
                  title: Text(pattern),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () {
                    Navigator.pop(context);
                    _showPatternDetails(pattern);
                  },
                )),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  // GlobalKey for the pattern indicator ListView
  final GlobalKey _patternIndicatorKey = GlobalKey();

  Widget _buildTimeframeSelector() {
    final timeframes = ['1D', '1W', '1M', '5mins'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: timeframes.map((tf) {
          final isSelected = tf == selectedTimeframe;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  selectedTimeframe = tf;
                  _resetZoom();
                });
                _loadCandles();
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color:
                      isSelected ? AppTheme.primaryColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.primaryColor
                        : AppTheme.textSecondary,
                  ),
                ),
                child: Text(
                  tf,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppTheme.textSecondary,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTrendIndicator() {
    String trend = getTrendLabel();
    Color trendColor = getTrendColor();
    IconData trendIcon = trend == 'Bullish'
        ? Icons.trending_up
        : trend == 'Bearish'
            ? Icons.trending_down
            : Icons.trending_flat;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [trendColor.withOpacity(0.2), Colors.transparent],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: trendColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(trendIcon, color: trendColor, size: 16),
          const SizedBox(width: 6),
          Text(
            'Market Trend: $trend',
            style: TextStyle(
                color: trendColor, fontWeight: FontWeight.w600, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildChart() {
    if (_displayedCandles.isEmpty) {
      // If displayed candles is empty but we have candles, reset the view
      if (candles.isNotEmpty) {
        print(
            "⚠️ Displayed candles is empty but total candles is ${candles.length}. Resetting...");
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _resetZoomView();
        });
        return const Center(child: CircularProgressIndicator());
      }
      return const Center(child: Text('No data available'));
    }

    print("📊 Building chart with ${_displayedCandles.length} candles");

    // Prepare chart data with highlight functionality
    final chartData = _displayedCandles.asMap().entries.map((entry) {
      final originalIndex =
          _zoomStartIndex != null ? _zoomStartIndex! + entry.key : entry.key;
      final candle = entry.value;
      final timestamp = DateTime.parse(candle.date).millisecondsSinceEpoch;

      // Check if this candle should be highlighted
      final isHighlighted = _selectedDateForHighlight != null &&
          DateTime.parse(candle.date).year == _selectedDateForHighlight!.year &&
          DateTime.parse(candle.date).month ==
              _selectedDateForHighlight!.month &&
          DateTime.parse(candle.date).day == _selectedDateForHighlight!.day;

      return {
        'timestamp': timestamp,
        'open': candle.open,
        'high': candle.high,
        'low': candle.low,
        'close': candle.close,
        'volume': candle.volume.toDouble(),
        'highlight': isHighlighted,
        'originalIndex': originalIndex,
      };
    }).toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: _selectedDateForHighlight != null
            ? Border.all(color: Colors.yellow, width: 2)
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: InteractiveChart(
          key: ValueKey(
              'chart_${_displayedCandles.length}_${_zoomStartIndex ?? 'full'}'),
          candles: chartData
              .map((data) => CandleData(
                    timestamp: data['timestamp'] as int,
                    open: data['open'] as double,
                    high: data['high'] as double,
                    low: data['low'] as double,
                    close: data['close'] as double,
                    volume: data['volume'] as double,
                  ))
              .toList(),
          overlayInfo: (candleData) {
            final patterns = patternMarkers[candleData.timestamp];
            final isHighlighted = _selectedDateForHighlight != null &&
                DateTime.fromMillisecondsSinceEpoch(candleData.timestamp)
                        .year ==
                    _selectedDateForHighlight!.year &&
                DateTime.fromMillisecondsSinceEpoch(candleData.timestamp)
                        .month ==
                    _selectedDateForHighlight!.month &&
                DateTime.fromMillisecondsSinceEpoch(candleData.timestamp).day ==
                    _selectedDateForHighlight!.day;

            Map<String, String> info = {
              'Date': DateTime.fromMillisecondsSinceEpoch(candleData.timestamp)
                  .toLocal()
                  .toString()
                  .split(' ')[0],
              'Open': '₹${candleData.open?.toStringAsFixed(2)}',
              'High': '₹${candleData.high?.toStringAsFixed(2)}',
              'Low': '₹${candleData.low?.toStringAsFixed(2)}',
              'Close': '₹${candleData.close?.toStringAsFixed(2)}',
            };

            if (patterns != null && patterns.isNotEmpty) {
              info['Patterns'] = patterns.join(', ');
            }

            if (isHighlighted) {
              info['📍'] = 'Selected Date';
            }

            return info;
          },
        ),
      ),
    );
  }

  Widget _buildPatternsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '📊 Detected Patterns',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              TextButton(
                onPressed: () => _showAllPatterns(),
                child: const Text('View All', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: patternMarkers.values.expand((i) => i).take(5).length,
            itemBuilder: (context, index) {
              final patterns = patternMarkers.values.expand((i) => i).toList();
              if (index >= patterns.length) return const SizedBox.shrink();
              final pattern = patterns[index];
              return _buildPatternCard(pattern);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPatternCard(String pattern) {
    bool isBullish = pattern.toLowerCase().contains('bull') ||
        pattern.toLowerCase().contains('up') ||
        pattern.toLowerCase().contains('rise');
    bool isBearish = pattern.toLowerCase().contains('bear') ||
        pattern.toLowerCase().contains('down') ||
        pattern.toLowerCase().contains('fall');

    Color patternColor = isBullish
        ? AppTheme.accentGreen
        : isBearish
            ? AppTheme.accentRed
            : AppTheme.accentYellow;
    IconData patternIcon = isBullish
        ? Icons.trending_up
        : isBearish
            ? Icons.trending_down
            : Icons.remove_circle_outline;

    return AnimationConfiguration.staggeredList(
      position: 0,
      duration: const Duration(milliseconds: 375),
      child: SlideAnimation(
        verticalOffset: 50.0,
        child: FadeInAnimation(
          child: GestureDetector(
            onTap: () => _showPatternDetails(pattern),
            child: Container(
              width: 140,
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: patternColor.withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                    color: patternColor.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(patternIcon, color: patternColor, size: 24),
                  const SizedBox(height: 8),
                  Text(
                    pattern.length > 25
                        ? '${pattern.substring(0, 22)}...'
                        : pattern,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: patternColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isBullish
                          ? 'BUY SIGNAL'
                          : (isBearish ? 'SELL SIGNAL' : 'NEUTRAL'),
                      style: TextStyle(
                        color: patternColor,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            height: 50,
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Container(
            height: 120,
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (index) {
        setState(() {
          _currentIndex = index;
        });
      },
      type: BottomNavigationBarType.fixed,
      backgroundColor: AppTheme.surfaceColor,
      selectedItemColor: AppTheme.primaryColor,
      unselectedItemColor: AppTheme.textSecondary,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.show_chart),
          label: 'Charts',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.book),
          label: 'Patterns',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.star),
          label: 'Watchlist',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.settings),
          label: 'Settings',
        ),
      ],
    );
  }

  Widget? _buildFAB() {
    if (patternMarkers.isEmpty) return null;

    return FloatingActionButton.extended(
      onPressed: () => _showPatternHistory(),
      icon: const Icon(Icons.history, color: Colors.white),
      label:
          const Text('Pattern History', style: TextStyle(color: Colors.white)),
      backgroundColor: AppTheme.primaryColor,
    );
  }

  void _showSymbolSearch() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text('Search Symbols',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Enter symbol name...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (query) {},
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: symbols.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      leading: const Icon(Icons.show_chart),
                      title: Text(symbols[index].replaceAll('.BSE', '')),
                      onTap: () {
                        setState(() {
                          selectedSymbol = symbols[index];
                          _resetZoom();
                          _loadCandles();
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPatternDetails(String pattern) async {
    final info = await ApiService.fetchPatternInfo(pattern);

    if (info != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PatternDetailScreen(patternInfo: info),
        ),
      );
    }
  }

  void _showPatternHistory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.textSecondary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Pattern History',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: patternMarkers.length,
                      itemBuilder: (context, index) {
                        final timestamp = patternMarkers.keys.toList()[index];
                        final patterns = patternMarkers[timestamp]!;
                        final date =
                            DateTime.fromMillisecondsSinceEpoch(timestamp);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ExpansionTile(
                            leading: Icon(
                              Icons.calendar_today,
                              color: AppTheme.primaryColor,
                            ),
                            title: Text(
                              DateFormat('MMM dd, yyyy').format(date),
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            children: patterns.map((pattern) {
                              return ListTile(
                                leading: Icon(
                                  pattern.toLowerCase().contains('bull')
                                      ? Icons.trending_up
                                      : pattern.toLowerCase().contains('bear')
                                          ? Icons.trending_down
                                          : Icons.remove,
                                  color: pattern.toLowerCase().contains('bull')
                                      ? AppTheme.accentGreen
                                      : pattern.toLowerCase().contains('bear')
                                          ? AppTheme.accentRed
                                          : AppTheme.accentYellow,
                                ),
                                title: Text(pattern),
                                trailing: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _scrollToDate(date);
                                  },
                                  icon: const Icon(Icons.timeline, size: 16),
                                  label: const Text('Go to Chart'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    textStyle: const TextStyle(fontSize: 11),
                                  ),
                                ),
                                onTap: () {
                                  Navigator.pop(context);
                                  _showPatternDetails(pattern);
                                },
                              );
                            }).toList(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAllPatterns() {
    _showPatternHistory();
  }

  Future<void> _refreshData() async {
    setState(() => isRefreshing = true);
    await _loadCandles();
    setState(() => isRefreshing = false);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
