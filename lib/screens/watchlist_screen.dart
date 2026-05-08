import 'package:flutter/material.dart';
import 'package:trading_app/themes/app_theme.dart';

class WatchlistScreen extends StatefulWidget {
  final Function(String) onSymbolSelected;

  const WatchlistScreen({super.key, required this.onSymbolSelected});

  @override
  State<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends State<WatchlistScreen> {
  List<String> watchlist = [
    'RELIANCE.BSE',
    'TCS.BSE',
    'INFY.BSE',
    'HDFCBANK.BSE'
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'My Watchlist',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon:
                    const Icon(Icons.add_circle, color: AppTheme.primaryColor),
                onPressed: () => _addSymbol(context),
              ),
            ],
          ),
        ),
        Expanded(
          child: watchlist.isEmpty
              ? const Center(
                  child: Text('No symbols in watchlist.\nTap + to add symbols'))
              : ListView.builder(
                  itemCount: watchlist.length,
                  itemBuilder: (context, index) {
                    final symbol = watchlist[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      child: ListTile(
                        leading: const Icon(Icons.show_chart,
                            color: AppTheme.primaryColor),
                        title: Text(symbol.replaceAll('.BSE', '')),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red),
                          onPressed: () {
                            setState(() {
                              watchlist.removeAt(index);
                            });
                          },
                        ),
                        onTap: () {
                          widget.onSymbolSelected(symbol);
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _addSymbol(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        String? newSymbol;
        return AlertDialog(
          title: const Text('Add Symbol'),
          content: TextField(
            decoration: const InputDecoration(
              hintText: 'Enter symbol (e.g., TCS.BSE)',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => newSymbol = value,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (newSymbol != null && newSymbol!.isNotEmpty) {
                  setState(() {
                    watchlist.add(newSymbol!.toUpperCase());
                  });
                }
                Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }
}
