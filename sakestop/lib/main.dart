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
        useMaterial3: true,
      ),
      home: const SakeStopApp(),
    );
  }
}

// ========== モデル定義 ==========

class Drink {
  final String name;
  final double volume; // ml
  final double alcoholPercentage; // %

  Drink({
    required this.name,
    required this.volume,
    required this.alcoholPercentage,
  });

  // 純アルコール量を計算 (g)
  double calculatePureAlcohol() {
    return (volume * alcoholPercentage * 0.8) / 100;
  }
}

// 飲料マスターデータ（ハードコード）
final List<Drink> drinkMenu = [
  Drink(name: 'ビール', volume: 500, alcoholPercentage: 5),
  Drink(name: 'ハイボール', volume: 180, alcoholPercentage: 7),
  Drink(name: '日本酒', volume: 180, alcoholPercentage: 15),
  Drink(name: '焼酎ロック', volume: 60, alcoholPercentage: 25),
  Drink(name: 'ワイン', volume: 150, alcoholPercentage: 12),
  Drink(name: 'サワー', volume: 200, alcoholPercentage: 8),
];

// ========== メインアプリ ==========

class SakeStopApp extends StatefulWidget {
  const SakeStopApp({super.key});

  @override
  State<SakeStopApp> createState() => _SakeStopAppState();
}

class _SakeStopAppState extends State<SakeStopApp> {
  String? _tableId;
  double _totalPureAlcohol = 0.0;
  List<OrderRecord> _orderHistory = [];
  DateTime? _lastPaceNotificationAt;
  final Duration _paceCooldown = const Duration(minutes: 30);

  void _startSession(String tableId) {
    setState(() {
      _tableId = tableId;
      _totalPureAlcohol = 0.0;
      _orderHistory = [];
    });
  }

  void _addDrink(Drink drink) {
    final pureAlcohol = drink.calculatePureAlcohol();
    final now = DateTime.now();
    
    setState(() {
      _totalPureAlcohol += pureAlcohol;
      _orderHistory.add(OrderRecord(
        drinkName: drink.name,
        pureAlcohol: pureAlcohol,
        timestamp: now,
      ));
    });

    // 摂取ペース通知をチェック
    _checkPaceNotification();
  }

  void _resetSession() {
    setState(() {
      _tableId = null;
      _totalPureAlcohol = 0.0;
      _orderHistory = [];
    });
  }

  // 30分以内に20g以上摂取した場合に通知
  void _checkPaceNotification() {
    final now = DateTime.now();
    final thirtyMinutesAgo = now.subtract(const Duration(minutes: 30));

    // 過去30分以内の注文を集計
    double alcoholIn30Minutes = 0.0;
    for (final order in _orderHistory) {
      if (order.timestamp.isAfter(thirtyMinutesAgo)) {
        alcoholIn30Minutes += order.pureAlcohol;
      }
    }

    // 30分以内に20g以上摂取した場合かつクールダウンが経過していれば通知
    if (alcoholIn30Minutes >= 20.0) {
      if (_lastPaceNotificationAt == null || now.difference(_lastPaceNotificationAt!) >= _paceCooldown) {
        _lastPaceNotificationAt = now;
        _showPaceNotification(alcoholIn30Minutes);
      }
    }
  }

  void _showPaceNotification(double alcoholIn30Min) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(
      content: Text('過去30分に${alcoholIn30Min.toStringAsFixed(1)}gを摂取しました。摂取ペースに注意してください。'),
      duration: const Duration(seconds: 6),
      action: SnackBarAction(label: '閉じる', onPressed: () => messenger.hideCurrentSnackBar()),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_tableId == null) {
      return QRScanScreen(onScanned: _startSession);
    } else {
      return MenuScreen(
        tableId: _tableId!,
        totalPureAlcohol: _totalPureAlcohol,
        onDrinkSelected: _addDrink,
        onCheckout: () {
          _showCheckoutDialog();
        },
        orderHistory: _orderHistory,
      );
    }
  }

  void _showCheckoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('会計・終了'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('テーブル: $_tableId'),
            const SizedBox(height: 8),
            Text('純アルコール量: ${_totalPureAlcohol.toStringAsFixed(1)}g'),
            const SizedBox(height: 8),
            Text('注文数: ${_orderHistory.length}'),
            const SizedBox(height: 16),
            const Text('セッションを終了しますか？'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('続ける'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resetSession();
            },
            child: const Text('終了'),
          ),
        ],
      ),
    );
  }
}

// ========== QRスキャン画面 ==========

class QRScanScreen extends StatefulWidget {
  final Function(String) onScanned;

  const QRScanScreen({super.key, required this.onScanned});

  @override
  State<QRScanScreen> createState() => _QRScanScreenState();
}

class _QRScanScreenState extends State<QRScanScreen> {
  final TextEditingController _tableIdController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QRスキャン'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.qr_code_2,
                size: 100,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 32),
              const Text(
                'テーブルIDをスキャンしてください',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),
              // 最小構成のためテキスト入力で代替
              TextField(
                controller: _tableIdController,
                decoration: InputDecoration(
                  hintText: 'テーブルID（例：T01）',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.table_restaurant),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  if (_tableIdController.text.isNotEmpty) {
                    widget.onScanned(_tableIdController.text);
                  }
                },
                icon: const Icon(Icons.arrow_forward),
                label: const Text('開始'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tableIdController.dispose();
    super.dispose();
  }
}

// ========== メニュー画面 ==========

class MenuScreen extends StatelessWidget {
  final String tableId;
  final double totalPureAlcohol;
  final Function(Drink) onDrinkSelected;
  final VoidCallback onCheckout;
  final List<OrderRecord> orderHistory;

  const MenuScreen({
    super.key,
    required this.tableId,
    required this.totalPureAlcohol,
    required this.onDrinkSelected,
    required this.onCheckout,
    required this.orderHistory,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('テーブル: $tableId'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: Text(
                '${totalPureAlcohol.toStringAsFixed(1)}g',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // アルコール摂取量表示（数値のみ）
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue[50],
            child: Column(
              children: [
                const Text(
                  '純アルコール摂取量',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 12),
                Text(
                  '${totalPureAlcohol.toStringAsFixed(1)}g',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 32,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 8),
                // 過去30分合計を表示
                Builder(builder: (context) {
                  final thirtyAgo = DateTime.now().subtract(const Duration(minutes: 30));
                  double in30 = 0.0;
                  for (final o in orderHistory) {
                    if (o.timestamp.isAfter(thirtyAgo)) in30 += o.pureAlcohol;
                  }
                  return Text(
                    '過去30分: ${in30.toStringAsFixed(1)}g',
                    style: const TextStyle(fontSize: 14, color: Colors.black54),
                  );
                }),
              ],
            ),
          ),
          // メニューリスト
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: drinkMenu.length,
              itemBuilder: (context, index) {
                final drink = drinkMenu[index];
                final pureAlcohol = drink.calculatePureAlcohol();
                return Card(
                  child: ListTile(
                    title: Text(drink.name),
                    subtitle: Text(
                      '${drink.volume}ml / ${drink.alcoholPercentage}%度 → ${pureAlcohol.toStringAsFixed(1)}g',
                    ),
                    trailing: ElevatedButton(
                      onPressed: () => onDrinkSelected(drink),
                      child: const Text('注文'),
                    ),
                  ),
                );
              },
            ),
          ),
          // 注文履歴とボタン
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (orderHistory.isNotEmpty)
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      itemCount: orderHistory.length,
                      itemBuilder: (context, index) {
                        final order = orderHistory[index];
                        return Text(
                          '${order.drinkName} (+${order.pureAlcohol.toStringAsFixed(1)}g)',
                          style: const TextStyle(fontSize: 12),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: onCheckout,
                  icon: const Icon(Icons.receipt),
                  label: const Text('会計・終了'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ========== 注文記録 ==========

class OrderRecord {
  final String drinkName;
  final double pureAlcohol;
  final DateTime timestamp;

  OrderRecord({
    required this.drinkName,
    required this.pureAlcohol,
    required this.timestamp,
  });
}
