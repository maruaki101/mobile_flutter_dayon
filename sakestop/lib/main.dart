import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';

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
  int _selectedTabIndex = 0;

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
      body: _selectedTabIndex == 0
          ? _buildCounterTab()
          : _buildCalendarTab(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedTabIndex,
        onTap: (index) {
          setState(() {
            _selectedTabIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle),
            label: 'カウント',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: '履歴',
          ),
        ],
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

  Widget _buildCalendarTab() {
    return CalendarHistoryScreen(prefs: _prefs, formatDate: _formatDate);
  }
}

class CalendarHistoryScreen extends StatefulWidget {
  final SharedPreferences prefs;
  final Function(DateTime) formatDate;

  const CalendarHistoryScreen({
    super.key,
    required this.prefs,
    required this.formatDate,
  });

  @override
  State<CalendarHistoryScreen> createState() => _CalendarHistoryScreenState();
}

class _CalendarHistoryScreenState extends State<CalendarHistoryScreen> {
  late DateTime _selectedDay;
  late DateTime _focusedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _focusedDay = DateTime.now();
  }

  int _getCountForDate(DateTime date) {
    final dateStr = widget.formatDate(date);
    return widget.prefs.getInt(dateStr) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    int selectedCount = _getCountForDate(_selectedDay);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TableCalendar(
              firstDay: DateTime.utc(2024, 1, 1),
              lastDay: DateTime.utc(2026, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
              ),
              calendarStyle: CalendarStyle(
                selectedDecoration: BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(height: 30),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Text(
                      '${_selectedDay.year}年${_selectedDay.month}月${_selectedDay.day}日',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '$selectedCount',
                      style: Theme.of(context).textTheme.displayLarge,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      '杯',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
