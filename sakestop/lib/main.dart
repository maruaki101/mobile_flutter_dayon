import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:uuid/uuid.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
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

class CartItem {
  final Drink drink;
  int quantity;

  CartItem({
    required this.drink,
    this.quantity = 1,
  });

  double get totalPureAlcohol => drink.calculatePureAlcohol() * quantity;
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
  String? _sessionId;
  String? _memberId;
  String? _nickname;
  double _totalPureAlcohol = 0.0;
  List<OrderRecord> _orderHistory = [];
  List<CartItem> _cartItems = [];
  bool _showCart = false;
  DateTime? _lastPaceNotificationAt;
  final Duration _paceCooldown = const Duration(minutes: 20);

  Future<void> _startSession(String tableId, String nickname) async {
    final memberId = const Uuid().v4();
    final sessionId = const Uuid().v4();

    try {
      // Firebaseにメンバー登録
      await FirebaseDatabase.instance
          .ref('tables/$tableId/sessions/$sessionId/members/$memberId')
          .set({
        'nickname': nickname.isEmpty ? null : nickname,
        'created_at': ServerValue.timestamp,
      });

      setState(() {
        _tableId = tableId;
        _sessionId = sessionId;
        _memberId = memberId;
        _nickname = nickname.isEmpty ? 'ゲスト' : nickname;
        _totalPureAlcohol = 0.0;
        _orderHistory = [];
        _cartItems = [];
        _showCart = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e')),
        );
      }
    }
  }

  Future<void> _addDrink(Drink drink, {bool showSnackBar = true}) async {
    final pureAlcohol = drink.calculatePureAlcohol();
    final now = DateTime.now();
    final orderId = const Uuid().v4();

    try {
      // Firebaseに注文を保存
      await FirebaseDatabase.instance
          .ref('tables/$_tableId/sessions/$_sessionId/members/$_memberId/orders/$orderId')
          .set({
        'drink_name': drink.name,
        'pure_alcohol': pureAlcohol,
        'timestamp': now.millisecondsSinceEpoch,
      });

      setState(() {
        _totalPureAlcohol += pureAlcohol;
        _orderHistory.add(OrderRecord(
          drinkName: drink.name,
          pureAlcohol: pureAlcohol,
          timestamp: now,
        ));
      });

      if (showSnackBar) {
        final isPaceAlert = _checkPaceNotification();
        final alcoholIn20Minutes = _calculateAlcoholInLast20Minutes();
        final message = isPaceAlert
            ? '${drink.name} を注文しました。過去20分のペースが速くなっています（${alcoholIn20Minutes.toStringAsFixed(1)}g）'
            : '${drink.name} を注文しました';

        if (mounted) {
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
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e')),
        );
      }
    }
  }

  Future<void> _resetSession() async {
    if (_tableId != null && _sessionId != null) {
      try {
        await FirebaseDatabase.instance
            .ref('tables/$_tableId/sessions/$_sessionId')
            .update({'closed_at': ServerValue.timestamp});
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('エラー: $e')),
          );
        }
      }
    }

    setState(() {
      _tableId = null;
      _sessionId = null;
      _memberId = null;
      _nickname = null;
      _totalPureAlcohol = 0.0;
      _orderHistory = [];
      _cartItems = [];
      _showCart = false;
    });
  }

  double _calculateAlcoholInLast20Minutes() {
    final twentyMinutesAgo = DateTime.now().subtract(const Duration(minutes: 20));
    double alcoholIn20Minutes = 0.0;
    for (final order in _orderHistory) {
      if (order.timestamp.isAfter(twentyMinutesAgo)) {
        alcoholIn20Minutes += order.pureAlcohol;
      }
    }
    return alcoholIn20Minutes;
  }

  void _addToCart(Drink drink) {
    setState(() {
      for (final item in _cartItems) {
        if (item.drink.name == drink.name) {
          item.quantity++;
          return;
        }
      }
      _cartItems.add(CartItem(drink: drink));
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${drink.name} をカートに追加しました'),
      duration: const Duration(seconds: 2),
    ));
  }

  void _updateCartQuantity(CartItem item, int delta) {
    setState(() {
      item.quantity += delta;
      if (item.quantity <= 0) {
        _cartItems.remove(item);
      }
    });
  }

  void _removeFromCart(CartItem item) {
    setState(() {
      _cartItems.remove(item);
    });
  }

  Future<void> _confirmOrder() async {
    if (_cartItems.isEmpty) return;

    final orderItems = List<CartItem>.from(_cartItems);
    for (final item in orderItems) {
      for (int i = 0; i < item.quantity; i++) {
        await _addDrink(item.drink, showSnackBar: false);
      }
    }

    final isPaceAlert = _checkPaceNotification();
    final alcoholIn20Minutes = _calculateAlcoholInLast20Minutes();
    final message = isPaceAlert
        ? '注文が確定しました。過去20分のペースが速くなっています（${alcoholIn20Minutes.toStringAsFixed(1)}g）'
        : '注文が確定しました';

    if (mounted) {
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

    setState(() {
      _cartItems = [];
      _showCart = false;
    });
  }

  // 20分以内に60g以上摂取した場合に通知（bool値を返す）
  bool _checkPaceNotification() {
    final now = DateTime.now();
    final twentyMinutesAgo = now.subtract(const Duration(minutes: 20));

    // 過去20分以内の注文を集計
    double alcoholIn20Minutes = 0.0;
    for (final order in _orderHistory) {
      if (order.timestamp.isAfter(twentyMinutesAgo)) {
        alcoholIn20Minutes += order.pureAlcohol;
      }
    }

    // 20分以内に60g以上摂取した場合かつクールダウンが経過していれば通知
    if (alcoholIn20Minutes >= 60.0) {
      if (_lastPaceNotificationAt == null ||
          now.difference(_lastPaceNotificationAt!) >= _paceCooldown) {
        _lastPaceNotificationAt = now;
        return true; // ペース通知あり
      }
    }
    return false; // ペース通知なし
  }

  @override
  Widget build(BuildContext context) {
    if (_tableId == null) {
      return QRScanScreen(onScanned: _startSession);
    } else if (_showCart) {
      return CartScreen(
        cartItems: _cartItems,
        onConfirmOrder: _confirmOrder,
        onBack: () => setState(() => _showCart = false),
        onQuantityChanged: _updateCartQuantity,
        onRemove: _removeFromCart,
      );
    } else {
      return MenuScreen(
        tableId: _tableId!,
        nickname: _nickname ?? 'ゲスト',
        totalPureAlcohol: _totalPureAlcohol,
        onAddToCart: _addToCart,
        onCartTapped: () => setState(() => _showCart = true),
        cartItemCount: _cartItems.fold(0, (sum, item) => sum + item.quantity),
        onCheckout: _showCheckoutDialog,
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

// ========== QRスキャン・ニックネーム入力画面 ==========

class QRScanScreen extends StatefulWidget {
  final Function(String, String) onScanned;

  const QRScanScreen({super.key, required this.onScanned});

  @override
  State<QRScanScreen> createState() => _QRScanScreenState();
}

class _QRScanScreenState extends State<QRScanScreen> {
  final TextEditingController _tableIdController = TextEditingController();
  final TextEditingController _nicknameController = TextEditingController();
  String? _scannedTableId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_scannedTableId == null ? 'QRスキャン' : 'ニックネーム入力'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: _scannedTableId == null
              ? _buildQRScanScreen(context)
              : _buildNicknameScreen(context),
        ),
      ),
    );
  }

  Widget _buildQRScanScreen(BuildContext context) {
    return Column(
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
              setState(() {
                _scannedTableId = _tableIdController.text;
              });
            }
          },
          icon: const Icon(Icons.arrow_forward),
          label: const Text('次へ'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildNicknameScreen(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.person,
          size: 100,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 32),
        const Text(
          'ニックネームを入力してください',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          '（未入力の場合は「ゲスト」となります）',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _nicknameController,
          decoration: InputDecoration(
            hintText: 'ニックネーム',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            prefixIcon: const Icon(Icons.edit),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _scannedTableId = null;
                  _nicknameController.clear();
                });
              },
              icon: const Icon(Icons.arrow_back),
              label: const Text('戻る'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              onPressed: () {
                widget.onScanned(_scannedTableId!, _nicknameController.text);
              },
              icon: const Icon(Icons.arrow_forward),
              label: const Text('開始'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  void dispose() {
    _tableIdController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }
}

// ========== メニュー画面 ==========

class MenuScreen extends StatelessWidget {
  final String tableId;
  final String nickname;
  final double totalPureAlcohol;
  final void Function(Drink) onAddToCart;
  final VoidCallback onCartTapped;
  final int cartItemCount;
  final VoidCallback onCheckout;
  final List<OrderRecord> orderHistory;

  const MenuScreen({
    super.key,
    required this.tableId,
    required this.nickname,
    required this.totalPureAlcohol,
    required this.onAddToCart,
    required this.onCartTapped,
    required this.cartItemCount,
    required this.onCheckout,
    required this.orderHistory,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$nickname さん @テーブル: $tableId'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart),
                onPressed: onCartTapped,
              ),
              if (cartItemCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$cartItemCount',
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                ),
            ],
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
                final nonAlcoholicDrinks = drinkMenu
                    .where((d) => d.alcoholPercentage == 0 && d.volume > 0)
                    .toList();
                final foodItems = drinkMenu.where((d) => d.volume == 0).toList();

                // 全アイテムリスト（セクションヘッダー含む）を作成
                List<Widget> items = [];

                // アルコールセクション
                if (alcoholicDrinks.isNotEmpty) {
                  items.add(
                    Padding(
                      padding: const EdgeInsets.only(
                        top: 16.0,
                        bottom: 8.0,
                        left: 16.0,
                        right: 16.0,
                      ),
                      child: Text(
                        '🍺 アルコール',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  );
                  for (final drink in alcoholicDrinks) {
                    items.add(
                      Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                        child: ListTile(
                          title: Text(drink.name),
                          subtitle: Text(
                            '${drink.volume}ml / ${drink.alcoholPercentage}%度',
                          ),
                          trailing: ElevatedButton(
                            onPressed: () => onAddToCart(drink),
                            child: const Text('追加'),
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
                      padding: const EdgeInsets.only(
                        top: 16.0,
                        bottom: 8.0,
                        left: 16.0,
                        right: 16.0,
                      ),
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
                            onPressed: () => onAddToCart(drink),
                            child: const Text('追加'),
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
                      padding: const EdgeInsets.only(
                        top: 16.0,
                        bottom: 8.0,
                        left: 16.0,
                        right: 16.0,
                      ),
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
                            onPressed: () => onAddToCart(drink),
                            child: const Text('追加'),
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

class CartScreen extends StatelessWidget {
  final List<CartItem> cartItems;
  final Future<void> Function() onConfirmOrder;
  final VoidCallback onBack;
  final void Function(CartItem, int) onQuantityChanged;
  final void Function(CartItem) onRemove;

  const CartScreen({
    super.key,
    required this.cartItems,
    required this.onConfirmOrder,
    required this.onBack,
    required this.onQuantityChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final totalPureAlcohol = cartItems.fold<double>(
      0,
      (sum, item) => sum + item.totalPureAlcohol,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('カート確認'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: onBack,
        ),
      ),
      body: cartItems.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('カートに商品がありません'),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: onBack,
                    child: const Text('メニューに戻る'),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: cartItems.length,
                    itemBuilder: (context, index) {
                      final item = cartItems[index];
                      final pureAlcohol = item.totalPureAlcohol;
                      final subtitle = pureAlcohol > 0
                          ? '${item.drink.volume.toStringAsFixed(0)}ml / '
                              '${item.drink.alcoholPercentage.toStringAsFixed(0)}%度 / '
                              '純アルコール ${pureAlcohol.toStringAsFixed(1)}g'
                          : item.drink.volume > 0
                              ? 'ノンアルコール'
                              : 'フード';

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.drink.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(subtitle),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () => onRemove(item),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline),
                                    onPressed: () =>
                                        onQuantityChanged(item, -1),
                                  ),
                                  SizedBox(
                                    width: 40,
                                    child: Text(
                                      '${item.quantity}',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline),
                                    onPressed: () => onQuantityChanged(item, 1),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    border: Border(top: BorderSide(color: Colors.grey.shade300)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'カート合計: 純アルコール ${totalPureAlcohol.toStringAsFixed(1)}g',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: onConfirmOrder,
                        icon: const Icon(Icons.check),
                        label: const Text('注文確定'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: onBack,
                        icon: const Icon(Icons.restaurant_menu),
                        label: const Text('メニューに戻る'),
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
