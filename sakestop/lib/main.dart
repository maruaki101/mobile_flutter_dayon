import 'package:flutter/material.dart';

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

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _drinkCount = 0;
  // 危ない指標としての平均杯数（後々機能拡張のため変数で管理）
  final double _averageDrinks = 8.0;

  void _incrementDrinks() {
    setState(() {
      _drinkCount++;
    });
  }

  void _resetCounter() {
    setState(() {
      _drinkCount = 0;
    });
  }

  double _getRiskPercentage() {
    return (_drinkCount / _averageDrinks) * 100;
  }

  @override
  Widget build(BuildContext context) {
    double riskPercentage = _getRiskPercentage();
    Color riskColor = Colors.green;
    
    if (riskPercentage >= 100) {
      riskColor = Colors.red;
    } else if (riskPercentage >= 75) {
      riskColor = Colors.orange;
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
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
            Text(
              '平均閾値: ${_averageDrinks.toStringAsFixed(0)}杯',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 10),
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
                  const SizedBox(height: 8),
                  Text(
                    '平均の${riskPercentage.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 16,
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
      ),
    );
  }
}
