import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:uuid/uuid.dart';

import 'alcohol_pace.dart';
import 'firebase_options.dart';
import 'table_id.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    runApp(const MyApp());
  } catch (_) {
    runApp(const StartupErrorApp());
  }
}

class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sake Stop',
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.error_outline, size: 72, color: Colors.red),
                SizedBox(height: 24),
                Text(
                  'アプリを起動できませんでした',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 12),
                Text(
                  'Firebase設定・通信状態を確認し、アプリを再起動してください。',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
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
    return calculatePureAlcoholGrams(
      volume: volume,
      alcoholPercentage: alcoholPercentage,
    );
  }
}

class CartItem {
  final Drink drink;
  int quantity;

  CartItem({required this.drink, this.quantity = 1});

  double get totalPureAlcohol => drink.calculatePureAlcohol() * quantity;
}

// 飲料マスターデータ（ハードコード）
final List<Drink> drinkMenu = [
  // アルコール
  Drink(name: '生ビール', volume: 500, alcoholPercentage: 5), // 純アルコール20.0g
  Drink(name: '缶ビール', volume: 350, alcoholPercentage: 5), // 純アルコール14.0g
  Drink(name: '日本酒', volume: 180, alcoholPercentage: 15), // 純アルコール21.6g
  Drink(name: 'ハイボール', volume: 350, alcoholPercentage: 7), // 純アルコール19.6g
  Drink(name: '赤ワイン', volume: 125, alcoholPercentage: 12), // 純アルコール12.0g
  Drink(name: 'チューハイ', volume: 350, alcoholPercentage: 5), // 純アルコール14.0g
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
  bool _showOrderHistory = false;
  bool _isSubmittingOrder = false;
  StreamSubscription<DatabaseEvent>? _ordersSubscription;
  DateTime? _lastPaceNotificationAt;

  double get _cartTotalAlcohol =>
      _cartItems.fold(0.0, (sum, item) => sum + item.totalPureAlcohol);

  Future<bool> _startSession(String tableId, String nickname) async {
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

      if (!mounted) return false;
      setState(() {
        _tableId = tableId;
        _sessionId = sessionId;
        _memberId = memberId;
        _nickname = nickname.isEmpty ? 'ゲスト' : nickname;
        _totalPureAlcohol = 0.0;
        _orderHistory = [];
        _cartItems = [];
        _showCart = false;
        _showOrderHistory = false;
        _isSubmittingOrder = false;
        _lastPaceNotificationAt = null;
      });
      _listenToOrderHistory(tableId, sessionId, memberId);
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('エラー: $e')));
      }
      return false;
    }
  }

  Future<bool> _resetSession() async {
    if (_tableId != null && _sessionId != null) {
      try {
        await FirebaseDatabase.instance
            .ref('tables/$_tableId/sessions/$_sessionId')
            .update({'closed_at': ServerValue.timestamp});
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('記録の終了に失敗しました。もう一度お試しください。($e)')),
          );
        }
        return false;
      }
    }

    await _ordersSubscription?.cancel();
    _ordersSubscription = null;
    if (!mounted) return false;

    setState(() {
      _tableId = null;
      _sessionId = null;
      _memberId = null;
      _nickname = null;
      _totalPureAlcohol = 0.0;
      _orderHistory = [];
      _cartItems = [];
      _showCart = false;
      _showOrderHistory = false;
      _isSubmittingOrder = false;
      _lastPaceNotificationAt = null;
    });
    return true;
  }

  void _listenToOrderHistory(
    String tableId,
    String sessionId,
    String memberId,
  ) {
    unawaited(_ordersSubscription?.cancel());
    _ordersSubscription = FirebaseDatabase.instance
        .ref('tables/$tableId/sessions/$sessionId/members/$memberId/orders')
        .orderByChild('timestamp')
        .onValue
        .listen(
          (event) {
            final value = event.snapshot.value;
            final records = <OrderRecord>[];

            if (value is Map) {
              for (final entry in value.entries) {
                final rawOrder = entry.value;
                if (rawOrder is! Map) continue;

                final drinkName = rawOrder['drink_name']?.toString();
                final pureAlcohol = _toDouble(rawOrder['pure_alcohol']);
                final timestamp = _toInt(rawOrder['timestamp']);

                if (drinkName == null ||
                    pureAlcohol == null ||
                    timestamp == null) {
                  continue;
                }

                records.add(
                  OrderRecord(
                    id: entry.key.toString(),
                    drinkName: drinkName,
                    pureAlcohol: pureAlcohol,
                    timestamp: DateTime.fromMillisecondsSinceEpoch(timestamp),
                  ),
                );
              }
            }

            records.sort((a, b) => a.timestamp.compareTo(b.timestamp));

            if (!mounted) return;
            setState(() {
              _orderHistory = records;
              _totalPureAlcohol = records.fold<double>(
                0,
                (sum, order) => sum + order.pureAlcohol,
              );
            });
          },
          onError: (Object error) {
            if (!mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('飲食記録の取得に失敗しました: $error')));
          },
        );
  }

  double? _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  int? _toInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  Iterable<AlcoholIntake> get _alcoholIntakes => _orderHistory.map(
    (order) => AlcoholIntake(
      pureAlcohol: order.pureAlcohol,
      timestamp: order.timestamp,
    ),
  );

  double _calculateAlcoholInLast30Minutes() {
    return calculateAlcoholWithin(
      intakes: _alcoholIntakes,
      now: DateTime.now(),
    );
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${drink.name} を記録内容に追加しました'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _updateCartQuantity(CartItem item, int delta) {
    if (_isSubmittingOrder) return;

    setState(() {
      item.quantity += delta;
      if (item.quantity <= 0) {
        _cartItems.remove(item);
      }
    });
  }

  void _removeFromCart(CartItem item) {
    if (_isSubmittingOrder) return;

    setState(() {
      _cartItems.remove(item);
    });
  }

  Future<void> _confirmOrder() async {
    if (_cartItems.isEmpty || _isSubmittingOrder) return;

    setState(() {
      _isSubmittingOrder = true;
    });

    final orderItems = List<CartItem>.from(_cartItems);
    final orders = <OrderRecord>[];
    final updates = <String, Object?>{};
    for (final item in orderItems) {
      for (int i = 0; i < item.quantity; i++) {
        final orderId = const Uuid().v4();
        final timestamp = DateTime.now();
        final pureAlcohol = item.drink.calculatePureAlcohol();
        orders.add(
          OrderRecord(
            id: orderId,
            drinkName: item.drink.name,
            pureAlcohol: pureAlcohol,
            timestamp: timestamp,
          ),
        );
        updates[orderId] = {
          'drink_name': item.drink.name,
          'pure_alcohol': pureAlcohol,
          'timestamp': timestamp.millisecondsSinceEpoch,
        };
      }
    }

    try {
      await FirebaseDatabase.instance
          .ref(
            'tables/$_tableId/sessions/$_sessionId/members/$_memberId/orders',
          )
          .update(updates);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSubmittingOrder = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('飲食記録の送信に失敗しました。もう一度お試しください。($error)')),
      );
      return;
    }

    if (!mounted) return;
    final newOrderIds = orders.map((order) => order.id).toSet();
    setState(() {
      _orderHistory = [
        ..._orderHistory.where((record) => !newOrderIds.contains(record.id)),
        ...orders,
      ]..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      _totalPureAlcohol = _orderHistory.fold<double>(
        0,
        (sum, order) => sum + order.pureAlcohol,
      );
      _cartItems = [];
      _showCart = false;
      _isSubmittingOrder = false;
    });

    final isPaceAlert = _checkPaceNotification();
    final alcoholIn30Minutes = _calculateAlcoholInLast30Minutes();
    final message = isPaceAlert
        ? '飲食内容を記録しました。過去30分の飲酒ペースが速くなっています（${alcoholIn30Minutes.toStringAsFixed(1)}g）'
        : '飲食内容を記録しました';
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: '閉じる',
          onPressed: () => messenger.hideCurrentSnackBar(),
        ),
      ),
    );
  }

  // 30分以内に20g以上摂取した場合に通知（bool値を返す）
  bool _checkPaceNotification() {
    final now = DateTime.now();

    if (shouldNotifyAlcoholPace(
      intakes: _alcoholIntakes,
      now: now,
      lastNotificationAt: _lastPaceNotificationAt,
    )) {
      _lastPaceNotificationAt = now;
      return true; // ペース通知あり
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
        isSubmittingOrder: _isSubmittingOrder,
        onConfirmOrder: _confirmOrder,
        onBack: () => setState(() => _showCart = false),
        onQuantityChanged: _updateCartQuantity,
        onRemove: _removeFromCart,
      );
    } else if (_showOrderHistory) {
      return OrderHistoryScreen(
        orderHistory: _orderHistory,
        onBack: () => setState(() => _showOrderHistory = false),
      );
    } else {
      return MenuScreen(
        tableId: _tableId!,
        nickname: _nickname ?? 'ゲスト',
        totalPureAlcohol: _totalPureAlcohol,
        onAddToCart: _addToCart,
        onCartTapped: () => setState(() => _showCart = true),
        cartItemCount: _cartItems.fold(0, (sum, item) => sum + item.quantity),
        cartTotalAlcohol: _cartTotalAlcohol,
        onCheckout: _showCheckoutDialog,
        orderHistory: _orderHistory,
        onOrderHistoryTapped: () => setState(() => _showOrderHistory = true),
      );
    }
  }

  @override
  void dispose() {
    unawaited(_ordersSubscription?.cancel());
    super.dispose();
  }

  void _showCheckoutDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        var isClosing = false;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('記録を終了'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('テーブル: $_tableId'),
                const SizedBox(height: 8),
                Text('記録数: ${_orderHistory.length}'),
                const SizedBox(height: 16),
                if (_cartItems.isNotEmpty) ...[
                  Text(
                    '未確定の${_cartItems.fold<int>(0, (sum, item) => sum + item.quantity)}点は破棄されます',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                ],
                const Text('記録を終了しますか？'),
                const SizedBox(height: 12),
                const Text('店舗へのお会計はスタッフへお声がけください'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isClosing ? null : () => Navigator.pop(context),
                child: const Text('続ける'),
              ),
              TextButton.icon(
                onPressed: isClosing
                    ? null
                    : () async {
                        setDialogState(() {
                          isClosing = true;
                        });
                        final succeeded = await _resetSession();
                        if (!dialogContext.mounted) return;
                        if (succeeded) {
                          Navigator.pop(dialogContext);
                        } else {
                          setDialogState(() {
                            isClosing = false;
                          });
                        }
                      },
                icon: isClosing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(isClosing ? '終了処理中...' : '記録を終了'),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ========== QRスキャン・ニックネーム入力画面 ==========

class QRScanScreen extends StatefulWidget {
  final Future<bool> Function(String, String) onScanned;

  const QRScanScreen({super.key, required this.onScanned});

  @override
  State<QRScanScreen> createState() => _QRScanScreenState();
}

class _QRScanScreenState extends State<QRScanScreen> {
  final TextEditingController _tableIdController = TextEditingController();
  final TextEditingController _nicknameController = TextEditingController();
  String? _scannedTableId;
  String? _tableIdError;
  String? _nicknameError;
  bool _isStarting = false;

  void _continueToNickname() {
    final error = tableIdValidationError(_tableIdController.text);
    if (error != null) {
      setState(() {
        _tableIdError = error;
      });
      return;
    }

    final tableId = normalizeTableId(_tableIdController.text);
    _tableIdController.text = tableId;
    setState(() {
      _tableIdError = null;
      _scannedTableId = tableId;
    });
  }

  bool get _supportsCameraScan {
    if (kIsWeb) return true;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return true;
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return false;
    }
  }

  Future<void> _openQrScanner() async {
    final tableId = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (context) => const TableQrScannerScreen()),
    );
    if (!mounted || tableId == null) return;

    _tableIdController.text = tableId;
    setState(() {
      _tableIdError = null;
      _scannedTableId = tableId;
    });
  }

  Future<void> _start() async {
    if (_isStarting) return;

    final nickname = _nicknameController.text.trim();
    if (nickname.length > 20) {
      setState(() {
        _nicknameError = 'ニックネームは20文字以内で入力してください';
      });
      return;
    }

    _nicknameController.text = nickname;
    setState(() {
      _nicknameError = null;
      _isStarting = true;
    });

    final succeeded = await widget.onScanned(_scannedTableId!, nickname);
    if (!mounted) return;
    if (!succeeded) {
      setState(() {
        _isStarting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_scannedTableId == null ? 'テーブルを選択' : 'ニックネーム入力'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 48,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: _scannedTableId == null
                      ? _buildQRScanScreen(context)
                      : _buildNicknameScreen(context),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQRScanScreen(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.table_restaurant,
          size: 80,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 20),
        const Text(
          '飲食内容とアルコール量を記録します',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        const Text(
          'テーブルIDを入力してください',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _tableIdController,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _continueToNickname(),
          decoration: InputDecoration(
            labelText: 'テーブルID',
            hintText: 'テーブルID（例：T01）',
            errorText: _tableIdError,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            prefixIcon: const Icon(Icons.table_restaurant),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _continueToNickname,
          icon: const Icon(Icons.arrow_forward),
          label: const Text('次へ'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          ),
        ),
        if (_supportsCameraScan) ...[
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _openQrScanner,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('QRがある場合はカメラで読み取る'),
          ),
        ],
      ],
    );
  }

  Widget _buildNicknameScreen(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
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
        const SizedBox(height: 16),
        Text(
          '選択中のテーブル: $_scannedTableId',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _nicknameController,
          enabled: !_isStarting,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) {
            if (!_isStarting) _start();
          },
          decoration: InputDecoration(
            labelText: '呼び名（任意）',
            errorText: _nicknameError,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            prefixIcon: const Icon(Icons.edit),
          ),
        ),
        const SizedBox(height: 24),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 16,
          runSpacing: 12,
          children: [
            ElevatedButton.icon(
              onPressed: _isStarting
                  ? null
                  : () {
                      setState(() {
                        _scannedTableId = null;
                        _nicknameError = null;
                        _nicknameController.clear();
                      });
                    },
              icon: const Icon(Icons.arrow_back),
              label: const Text('テーブルを変更'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: _isStarting ? null : _start,
              icon: _isStarting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.arrow_forward),
              label: Text(_isStarting ? '開始中...' : '開始'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
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
  final double cartTotalAlcohol;
  final VoidCallback onCheckout;
  final List<OrderRecord> orderHistory;
  final VoidCallback onOrderHistoryTapped;

  const MenuScreen({
    super.key,
    required this.tableId,
    required this.nickname,
    required this.totalPureAlcohol,
    required this.onAddToCart,
    required this.onCartTapped,
    required this.cartItemCount,
    required this.cartTotalAlcohol,
    required this.onCheckout,
    required this.orderHistory,
    required this.onOrderHistoryTapped,
  });

  @override
  Widget build(BuildContext context) {
    final alcoholIn30Minutes = calculateAlcoholWithin(
      intakes: orderHistory.map(
        (order) => AlcoholIntake(
          pureAlcohol: order.pureAlcohol,
          timestamp: order.timestamp,
        ),
      ),
      now: DateTime.now(),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('メニュー'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long),
            onPressed: onOrderHistoryTapped,
            tooltip: '飲食記録を見る',
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart),
                onPressed: onCartTapped,
                tooltip: '記録内容を確認',
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
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton.icon(
                onPressed: cartItemCount > 0 ? onCartTapped : null,
                icon: const Icon(Icons.fact_check_outlined),
                label: Text(
                  '記録内容を確認（$cartItemCount点・純アルコール${cartTotalAlcohol.toStringAsFixed(1)}g）',
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              TextButton(
                onPressed: onCheckout,
                child: const Text('記録を終了'),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                const Icon(Icons.table_restaurant, size: 18),
                const SizedBox(width: 6),
                Text('テーブル $tableId'),
                const SizedBox(width: 20),
                const Icon(Icons.person_outline, size: 18),
                const SizedBox(width: 6),
                Expanded(child: Text('呼び名 $nickname')),
              ],
            ),
          ),
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
                Text(
                  '過去30分: ${alcoholIn30Minutes.toStringAsFixed(1)}g',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          if (alcoholIn30Minutes >= alcoholPaceThresholdGrams)
            Card(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              color: Colors.amber.shade100,
              child: const ListTile(
                leading: Icon(Icons.warning_amber_rounded),
                title: Text('過去30分の飲酒ペースが速くなっています'),
                subtitle: Text('健康判断ではなく目安です'),
              ),
            ),
          // メニューリスト（セクション分け）
          Expanded(
            child: Builder(
              builder: (context) {
                // セクション別にアイテムを分類
                final alcoholicDrinks = drinkMenu
                    .where((d) => d.alcoholPercentage > 0)
                    .toList();
                final nonAlcoholicDrinks = drinkMenu
                    .where((d) => d.alcoholPercentage == 0 && d.volume > 0)
                    .toList();
                final foodItems = drinkMenu
                    .where((d) => d.volume == 0)
                    .toList();

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
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  );
                  for (final drink in alcoholicDrinks) {
                    items.add(
                      Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 4.0,
                        ),
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
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  );
                  for (final drink in nonAlcoholicDrinks) {
                    items.add(
                      Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 4.0,
                        ),
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
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  );
                  for (final drink in foodItems) {
                    items.add(
                      Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 4.0,
                        ),
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

                return ListView(children: items);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class TableQrScannerScreen extends StatefulWidget {
  const TableQrScannerScreen({super.key});

  @override
  State<TableQrScannerScreen> createState() => _TableQrScannerScreenState();
}

class _TableQrScannerScreenState extends State<TableQrScannerScreen> {
  bool _hasAcceptedValue = false;
  String? _lastInvalidValue;
  String? _errorMessage;

  void _onDetect(BarcodeCapture capture) {
    if (_hasAcceptedValue || !mounted) return;

    String? invalidValue;
    for (final barcode in capture.barcodes) {
      if (barcode.format != BarcodeFormat.qrCode) continue;
      final rawValue = barcode.rawValue;
      if (rawValue == null) continue;

      final tableId = normalizedValidTableId(rawValue);
      if (tableId != null) {
        _hasAcceptedValue = true;
        Navigator.of(context).pop(tableId);
        return;
      }
      invalidValue ??= rawValue;
    }

    if (invalidValue == null || invalidValue == _lastInvalidValue || !mounted) {
      return;
    }
    setState(() {
      _lastInvalidValue = invalidValue;
      _errorMessage =
          'このQRコードはテーブルIDとして使用できません。'
          '別のQRコードをかざしてください。';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QRスキャン'),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
          tooltip: 'キャンセル',
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(onDetect: _onDetect),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _errorMessage ?? 'テーブルのQRコードを枠内にかざしてください',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _errorMessage == null
                            ? Colors.white
                            : Colors.orangeAccent,
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('キャンセル'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OrderHistoryScreen extends StatelessWidget {
  final List<OrderRecord> orderHistory;
  final VoidCallback onBack;

  const OrderHistoryScreen({
    super.key,
    required this.orderHistory,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final totalPureAlcohol = orderHistory.fold<double>(
      0,
      (sum, order) => sum + order.pureAlcohol,
    );
    final latestFirst = orderHistory.reversed.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('飲食記録'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: onBack,
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.blue[50],
            child: Column(
              children: [
                Text(
                  '記録数: ${orderHistory.length}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  '\u7d14\u30a2\u30eb\u30b3\u30fc\u30eb\u5408\u8a08 ${totalPureAlcohol.toStringAsFixed(1)}g',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: latestFirst.isEmpty
                ? const Center(
                    child: Text(
                      'まだ飲食記録がありません',
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: latestFirst.length,
                    itemBuilder: (context, index) {
                      final order = latestFirst[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          leading: const Icon(Icons.receipt_long),
                          title: Text(order.drinkName),
                          subtitle: Text(_formatTimestamp(order.timestamp)),
                          trailing: Text(
                            order.pureAlcohol > 0
                                ? '${order.pureAlcohol.toStringAsFixed(1)}g'
                                : '-',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    return '${_twoDigits(timestamp.month)}/${_twoDigits(timestamp.day)} '
        '${_twoDigits(timestamp.hour)}:${_twoDigits(timestamp.minute)}';
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');
}

class CartScreen extends StatelessWidget {
  final List<CartItem> cartItems;
  final bool isSubmittingOrder;
  final Future<void> Function() onConfirmOrder;
  final VoidCallback onBack;
  final void Function(CartItem, int) onQuantityChanged;
  final void Function(CartItem) onRemove;

  const CartScreen({
    super.key,
    required this.cartItems,
    required this.isSubmittingOrder,
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
        title: const Text('記録内容の確認'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: isSubmittingOrder ? null : onBack,
        ),
      ),
      body: cartItems.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.shopping_cart_outlined,
                    size: 80,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text('記録内容がありません'),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: isSubmittingOrder ? null : onBack,
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
                                    onPressed: isSubmittingOrder
                                        ? null
                                        : () => onRemove(item),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.remove_circle_outline,
                                    ),
                                    onPressed: isSubmittingOrder
                                        ? null
                                        : () => onQuantityChanged(item, -1),
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
                                    onPressed: isSubmittingOrder
                                        ? null
                                        : () => onQuantityChanged(item, 1),
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
                    border: Border(
                      top: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '記録内容の合計: 純アルコール ${totalPureAlcohol.toStringAsFixed(1)}g',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'この内容を記録します',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: isSubmittingOrder ? null : onConfirmOrder,
                        icon: isSubmittingOrder
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.check),
                        label: Text(
                          isSubmittingOrder ? '記録中...' : '飲食記録に追加',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: isSubmittingOrder ? null : onBack,
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
  final String id;
  final String drinkName;
  final double pureAlcohol;
  final DateTime timestamp;

  OrderRecord({
    required this.id,
    required this.drinkName,
    required this.pureAlcohol,
    required this.timestamp,
  });
}
