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
    final result = (volume * alcoholPercentage * 0.8) / 100;
    print('DEBUG: calculatePureAlcohol: ($volume * $alcoholPercentage * 0.8) / 100 = $result');
    return result;
  }
}

// 飲料マスターデータ（ハードコード）
final List<Drink> drinkMenu = [
  // アルコール
  Drink(name: '生ビール', volume: 500, alcoholPercentage: 5),    // 純アルコール20.0g
  Drink(name: '缶ビール', volume: 350, alcoholPercentage: 5),    // 純アルコール14.0g
  Drink(name: '日本酒', volume: 180, alcoholPercentage: 15),     // 純アルコール21.6g
  Drink(name: 'ハイボール', volume: 350, alcoholPercentage: 7),  // 純アルコール19.6g
  Drink(name: '赤ワイン', volume: 125, alcoholPercentage: 12),   // 純アルコール12.0g
  Drink(name: 'チューハイ', volume: 350, alcoholPercentage: 5),  // 純アルコール14.0g
  // ノンアルコール
  Drink(name: 'ウーロン茶', volume: 200, alcoholPercentage: 0),
  Drink(name: 'コーラ', volume: 200, alcoholPercentage: 0),
  Drink(name: 'オレンジジュース', volume: 200, alcoholPercentage: 0),
  // フード
  Drink(name: '枝豆', volume: 0, alcoholPercentage: 0),
  Drink(name: 'から揚げ', volume: 0, alcoholPercentage: 0),
  Drink(name: '刺身盛り合わせ', volume: 0, alcoholPercentage: 0),
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
  final Duration _paceCooldown = const Duration(minutes: 20);

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
    
    print('DEBUG: _addDrink called: name=${drink.name}, volume=${drink.volume}ml, alcohol%=${drink.alcoholPercentage}%, pureAlcohol=$pureAlcohol g');
    
    setState(() {
      _totalPureAlcohol += pureAlcohol;
      _orderHistory.add(OrderRecord(
        drinkName: drink.name,
        pureAlcohol: pureAlcohol,
        timestamp: now,
      ));
    });

    // ペース通知をチェック
    final isPaceAlert = _checkPaceNotification();

    // 過去20分の合計を取得（ペース通知時のメッセージ用）
    final twentyMinutesAgo = now.subtract(const Duration(minutes: 20));
    double alcoholIn20Minutes = 0.0;
    for (final order in _orderHistory) {
      if (order.timestamp.isAfter(twentyMinutesAgo)) {
        alcoholIn20Minutes += order.pureAlcohol;
      }
    }

    final message = isPaceAlert
        ? '${drink.name} を注文しました。過去20分のペースが速くなっています（${alcoholIn20Minutes.toStringAsFixed(1)}g）'
        : '${drink.name} を注文しました';

    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 4),
      action: SnackBarAction(
        label: '閉じる',
        onPressed: () => messenger.hideCurrentSnackBar(),
      ),
    ));
  }

  void _resetSession() {
    setState(() {
      _tableId = null;
      _totalPureAlcohol = 0.0;
      _orderHistory = [];
    });
  }

  // 20分以内に60g以上摂取した場合に通知（bool値を返す）
  bool _checkPaceNotification() {
    final now = DateTime.now();
    final twentyMinutesAgo = now.subtract(const Duration(minutes: 20));

    print('DEBUG: now=$now, twentyMinutesAgo=$twentyMinutesAgo');
    print('DEBUG: orderHistory length=${_orderHistory.length}');

    // 過去20分以内の注文を集計
    double alcoholIn20Minutes = 0.0;
    for (final order in _orderHistory) {
      final isAfter = order.timestamp.isAfter(twentyMinutesAgo);
      print('DEBUG: order timestamp=${order.timestamp}, isAfter=$isAfter, pureAlcohol=${order.pureAlcohol}');
      if (isAfter) {
        alcoholIn20Minutes += order.pureAlcohol;
      }
    }

    print('DEBUG: alcoholIn20Minutes=$alcoholIn20Minutes (threshold=60.0)');
    print('DEBUG: lastPaceNotificationAt=$_lastPaceNotificationAt');

    // 20分以内に60g以上摂取した場合かつクールダウンが経過していれば通知
    if (alcoholIn20Minutes >= 60.0) {
      print('DEBUG: Condition met: alcoholIn20Minutes >= 60.0');
      if (_lastPaceNotificationAt == null || now.difference(_lastPaceNotificationAt!) >= _paceCooldown) {
        print('DEBUG: Cooldown check passed, returning true');
        _lastPaceNotificationAt = now;
        return true; // ペース通知あり
      } else {
        print('DEBUG: Cooldown not elapsed yet');
      }
    } else {
      print('DEBUG: Condition not met: alcoholIn20Minutes < 60.0');
    }
    return false; // ペース通知なし
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
                // 過去20分合計を表示
                Builder(builder: (context) {
                  final twentyAgo = DateTime.now().subtract(const Duration(minutes: 20));
                  double in20 = 0.0;
                  for (final o in orderHistory) {
                    if (o.timestamp.isAfter(twentyAgo)) in20 += o.pureAlcohol;
                  }
                  return Text(
                    '過去20分: ${in20.toStringAsFixed(1)}g',
                    style: const TextStyle(fontSize: 14, color: Colors.black54),
                  );
                }),
              ],
            ),
          ),
          // メニューリスト（セクション分け）
          Expanded(
            child: Builder(
              builder: (context) {
                // セクション別にアイテムを分類
                final alcoholicDrinks = drinkMenu.where((d) => d.alcoholPercentage > 0).toList();
                final nonAlcoholicDrinks = drinkMenu.where((d) => d.alcoholPercentage == 0 && d.volume > 0).toList();
                final foodItems = drinkMenu.where((d) => d.volume == 0).toList();

                // 全アイテムリスト（セクションヘッダー含む）を作成
                List<Widget> items = [];

                // アルコールセクション
                if (alcoholicDrinks.isNotEmpty) {
                  items.add(
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0, left: 16.0, right: 16.0),
                      child: Text(
                        '🍺 アルコール',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  );
                  for (final drink in alcoholicDrinks) {
                    final pureAlcohol = drink.calculatePureAlcohol();
                    items.add(
                      Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                        child: ListTile(
                          title: Text(drink.name),
                          subtitle: Text(
                            '${drink.volume}ml / ${drink.alcoholPercentage}%度',
                          ),
                          trailing: ElevatedButton(
                            onPressed: () => onDrinkSelected(drink),
                            child: const Text('注文'),
                          ),
                        ),
                      ),
                    );
                  }
                }

                // ノンアルコールセクション
                if (nonAlcoholicDrinks.isNotEmpty) {
                  items.add(
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0, left: 16.0, right: 16.0),
                      child: Text(
                        '🥤 ノンアルコール',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  );
                  for (final drink in nonAlcoholicDrinks) {
                    items.add(
                      Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                        child: ListTile(
                          title: Text(drink.name),
                          subtitle: const Text('ノンアルコール'),
                          trailing: ElevatedButton(
                            onPressed: () => onDrinkSelected(drink),
                            child: const Text('注文'),
                          ),
                        ),
                      ),
                    );
                  }
                }

                // フードセクション
                if (foodItems.isNotEmpty) {
                  items.add(
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0, left: 16.0, right: 16.0),
                      child: Text(
                        '🍽️ フード',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  );
                  for (final drink in foodItems) {
                    items.add(
                      Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                        child: ListTile(
                          title: Text(drink.name),
                          subtitle: const Text('フード'),
                          trailing: ElevatedButton(
                            onPressed: () => onDrinkSelected(drink),
                            child: const Text('注文'),
                          ),
                        ),
                      ),
                    );
                  }
                }

                return ListView(
                  children: items,
                );
              },
            ),
          ),
          // 会計・終了ボタン
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
