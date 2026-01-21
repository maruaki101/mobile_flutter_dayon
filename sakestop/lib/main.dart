import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'calendar_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sake Stop',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
      ),
      home: const MyHomePage(title: 'sakestop'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _drinkCount = 0;
  final double _averageDrinks = 8.0;
  late SharedPreferences _prefs;

  @override
  void initState() {
    super.initState();
    _initializePreferences();
  }

  Future<void> _initializePreferences() async {
    _prefs = await SharedPreferences.getInstance();
    _loadTodayCount();
  }

  void _loadTodayCount() {
    final today = _formatDate(DateTime.now());
    setState(() {
      _drinkCount = _prefs.getInt(today) ?? 0;
    });
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _saveDrinkCount() async {
    final today = _formatDate(DateTime.now());
    await _prefs.setInt(today, _drinkCount);
  }

  void _incrementDrinks() {
    setState(() {
      _drinkCount++;
    });
    _saveDrinkCount();
  }

  void _resetCounter() {
    setState(() {
      _drinkCount = 0;
    });
    _saveDrinkCount();
  }

  double _getRiskPercentage() {
    return (_drinkCount / _averageDrinks) * 100;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: _buildCounterTab(),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(8.0),
        child: ElevatedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CalendarHistoryScreen(
                  prefs: _prefs,
                  formatDate: _formatDate,
                ),
              ),
            );
          },
          icon: const Icon(Icons.calendar_today),
          label: const Text('履歴'),
        ),
      ),
    );
  }

  Widget _buildCounterTab() {
    double riskPercentage = _getRiskPercentage();
    Color riskColor = Colors.green;

    if (riskPercentage >= 100) {
      riskColor = Colors.red;
    } else if (riskPercentage >= 75) {
      riskColor = Colors.orange;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Text(
            '飲んだ杯数:',
            style: TextStyle(fontSize: 18),
          ),
          Text(
            '$_drinkCount',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 20),
          LinearProgressIndicator(
            value: (riskPercentage / 100).clamp(0.0, 1.0),
            minHeight: 10,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(riskColor),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _incrementDrinks,
            style: ButtonStyle(
              elevation: WidgetStateProperty.all(0.0),
              backgroundColor: WidgetStateProperty.all(riskColor.withValues(alpha: 0.1)),
              side: WidgetStateProperty.all(BorderSide(color: riskColor)),
              padding: WidgetStateProperty.all(const EdgeInsets.all(16)),
              shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              overlayColor: WidgetStateProperty.all(Colors.transparent),
            ),
            child: Column(
              children: [
                Text(
                  'カウントを増やす',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: riskColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _resetCounter,
                child: const Text('リセット'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
