import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
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

ThemeData _buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF9A3412),
    surface: const Color(0xFFFFFBF7),
    brightness: Brightness.light,
  );
  final base = ThemeData(colorScheme: scheme, useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    textTheme: base.textTheme.copyWith(
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      labelLarge: base.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sake Stop',
      theme: _buildAppTheme(),
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 72,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 24),
                const Text(
                  'アプリを起動できませんでした',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
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
      theme: _buildAppTheme(),
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
  DateTime? _nextRecommendedDrinkAt;
  Timer? _nextRecommendedDrinkTimer;

  double get _cartTotalAlcohol =>
      _cartItems.fold(0.0, (sum, item) => sum + item.totalPureAlcohol);

  String? get _nextRecommendedDrinkTimerText {
    final nextAt = _nextRecommendedDrinkAt;
    if (nextAt == null) return null;

    final remaining = nextAt.difference(DateTime.now());
    final totalSeconds = remaining.isNegative
        ? 0
        : (remaining.inMilliseconds / 1000).ceil();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Duration _calculateOrderInterval(Drink drink) {
    final pureAlcohol = drink.calculatePureAlcohol();
    if (pureAlcohol <= 0) return Duration.zero;

    final seconds =
        (alcoholPaceWindow.inSeconds * pureAlcohol / alcoholPaceThresholdGrams)
            .round();
    return Duration(seconds: seconds);
  }

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
        _nextRecommendedDrinkAt = null;
      });
      _listenToOrderHistory(tableId, sessionId, memberId);
      return true;
    } catch (e) {
      if (mounted) {
        _showSnackBar('エラー: $e');
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
          _showSnackBar('記録の終了に失敗しました。もう一度お試しください。($e)');
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
      _nextRecommendedDrinkAt = null;
    });
    _stopNextRecommendedDrinkTimer();
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
            _showSnackBar('注文履歴の取得に失敗しました: $error');
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

  void _showSnackBar(
    String message, {
    Duration duration = const Duration(seconds: 3),
    bool showCloseAction = false,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
        action: showCloseAction
            ? SnackBarAction(
                label: '閉じる',
                onPressed: () => messenger.hideCurrentSnackBar(),
              )
            : null,
      ),
    );
  }

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
          if (drink.alcoholPercentage > 0) {
            _nextRecommendedDrinkAt = DateTime.now().add(
              _calculateOrderInterval(drink),
            );
          }
          return;
        }
      }
      _cartItems.add(CartItem(drink: drink));
      if (drink.alcoholPercentage > 0) {
        _nextRecommendedDrinkAt = DateTime.now().add(
          _calculateOrderInterval(drink),
        );
      }
    });

    if (drink.alcoholPercentage > 0) {
      _startNextRecommendedDrinkTimer();
    }

    _showSnackBar(
      '${drink.name} をカートに追加しました',
      duration: const Duration(milliseconds: 1200),
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

  void _startNextRecommendedDrinkTimer() {
    _nextRecommendedDrinkTimer?.cancel();
    _nextRecommendedDrinkTimer = Timer.periodic(const Duration(seconds: 1), (
      timer,
    ) {
      final nextRecommendedDrinkAt = _nextRecommendedDrinkAt;
      if (!mounted || nextRecommendedDrinkAt == null) {
        timer.cancel();
        return;
      }

      if (!DateTime.now().isBefore(nextRecommendedDrinkAt)) {
        timer.cancel();
      }
      setState(() {});
    });
  }

  void _stopNextRecommendedDrinkTimer() {
    _nextRecommendedDrinkTimer?.cancel();
    _nextRecommendedDrinkTimer = null;
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
      _showSnackBar('注文の送信に失敗しました。もう一度お試しください。($error)');
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
        ? '注文を受け付けました。飲酒ペースが少し速めです（過去30分 ${alcoholIn30Minutes.toStringAsFixed(1)}g）'
        : '注文を受け付けました';
    _showSnackBar(
      message,
      duration: const Duration(seconds: 4),
      showCloseAction: true,
    );
  }

  // 30分以内の注文がビール500ml相当3杯前後を超えた場合に通知（bool値を返す）
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
      return TableEntryScreen(onSubmitted: _startSession);
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
        cartQuantities: {
          for (final item in _cartItems) item.drink.name: item.quantity,
        },
        nextRecommendedDrinkTimerText: _nextRecommendedDrinkTimerText,
        onCheckout: _showCheckoutDialog,
        orderHistory: _orderHistory,
        onOrderHistoryTapped: () => setState(() => _showOrderHistory = true),
      );
    }
  }

  @override
  void dispose() {
    unawaited(_ordersSubscription?.cancel());
    _stopNextRecommendedDrinkTimer();
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
            title: const Text('利用を終了'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('テーブル: $_tableId'),
                const SizedBox(height: 8),
                Text('記録数: ${_orderHistory.length}'),
                const SizedBox(height: 16),
                if (_cartItems.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '未確定の${_cartItems.fold<int>(0, (sum, item) => sum + item.quantity)}点は破棄されます',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                const Text('利用を終了しますか？'),
                const SizedBox(height: 12),
                const Text('お会計はスタッフへお声がけください'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isClosing ? null : () => Navigator.pop(context),
                child: const Text('利用を続ける'),
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
                label: Text(
                  isClosing
                      ? '終了処理中...'
                      : _cartItems.isNotEmpty
                      ? '未確定分を破棄して終了'
                      : '利用を終了',
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ========== テーブルID・ニックネーム入力画面 ==========

class TableEntryScreen extends StatefulWidget {
  final Future<bool> Function(String, String) onSubmitted;

  const TableEntryScreen({super.key, required this.onSubmitted});

  @override
  State<TableEntryScreen> createState() => _TableEntryScreenState();
}

class _TableEntryScreenState extends State<TableEntryScreen> {
  final TextEditingController _tableIdController = TextEditingController();
  final TextEditingController _nicknameController = TextEditingController();
  String? _selectedTableId;
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
      _selectedTableId = tableId;
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

    final succeeded = await widget.onSubmitted(_selectedTableId!, nickname);
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
        title: Text(_selectedTableId == null ? 'テーブルを選択' : 'ニックネーム入力'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight > 48
                    ? constraints.maxHeight - 48
                    : 0,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: _selectedTableId == null
                      ? _buildTableIdScreen(context)
                      : _buildNicknameScreen(context),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTableIdScreen(BuildContext context) {
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
          'テーブルに表示されたID（例：T01）を入力',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          '見当たらない場合はスタッフへお声がけください',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
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
        FilledButton.icon(
          onPressed: _continueToNickname,
          icon: const Icon(Icons.arrow_forward),
          label: const Text('このテーブルで進む'),
        ),
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
          style: TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 16),
        Chip(
          avatar: const Icon(Icons.table_restaurant, size: 18),
          label: Text('テーブル $_selectedTableId'),
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _nicknameController,
          enabled: !_isStarting,
          onChanged: (_) => setState(() {}),
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
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              onPressed: _isStarting ? null : _start,
              icon: _isStarting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.arrow_forward),
              label: Text(
                _isStarting
                    ? '開始中...'
                    : _nicknameController.text.trim().isEmpty
                    ? 'ゲストで始める'
                    : 'この名前で始める',
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _isStarting
                  ? null
                  : () {
                      setState(() {
                        _selectedTableId = null;
                        _nicknameError = null;
                        _nicknameController.clear();
                      });
                    },
              icon: const Icon(Icons.arrow_back),
              label: const Text('テーブルを変更'),
              style: OutlinedButton.styleFrom(
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
  final Map<String, int> cartQuantities;
  final String? nextRecommendedDrinkTimerText;
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
    required this.cartQuantities,
    required this.nextRecommendedDrinkTimerText,
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
        title: const Text('ご注文'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long),
            onPressed: onOrderHistoryTapped,
            tooltip: '注文履歴を見る',
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart),
                onPressed: onCartTapped,
                tooltip: 'カートを見る',
              ),
              if (cartItemCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.error,
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
      bottomNavigationBar: null, /*
      DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
        child: SafeArea(
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 840),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (cartItemCount > 0) ...[
                      FilledButton.icon(
                        onPressed: onCartTapped,
                        icon: const Icon(Icons.shopping_cart),
                        label: Text('カートを見る（$cartItemCount点）'),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '純アルコール合計 ${cartTotalAlcohol.toStringAsFixed(1)}g',
                        textAlign: TextAlign.center,
                      ),
                    ],
                    TextButton(
                      onPressed: onCheckout,
                      child: const Text('利用を終了'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      */
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 840),
          child: ListView(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: Text('商品を選んでカートに追加してください'),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        '$tableId / $nickname',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: Theme.of(context).textTheme.labelSmall
                            ?.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.72,
                              ),
                              fontWeight: FontWeight.w400,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
          Card(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '純アルコール合計 ${totalPureAlcohol.toStringAsFixed(1)}g',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '過去30分 ${alcoholIn30Minutes.toStringAsFixed(1)}g・注文内容からの計算目安',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  if (nextRecommendedDrinkTimerText != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      nextRecommendedDrinkTimerText!,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (alcoholIn30Minutes >= alcoholPaceThresholdGrams)
            Card(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              color: Theme.of(context).colorScheme.tertiaryContainer,
              child: ListTile(
                leading: Icon(
                  Icons.warning_amber_rounded,
                  color: Theme.of(context).colorScheme.onTertiaryContainer,
                ),
                title: Text(
                  '飲酒ペースが少し速めです',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onTertiaryContainer,
                  ),
                ),
                subtitle: Text(
                  '水や食事を取り、ペースを落としましょう。健康判断ではなく目安です',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onTertiaryContainer,
                  ),
                ),
              ),
            ),
              // メニューリスト（セクション分け）
              Builder(
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

                Widget sectionHeader(IconData icon, String title) => Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Icon(icon),
                      const SizedBox(width: 8),
                      Text(title, style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                );

                Widget itemAction(Drink drink) {
                  final quantity = cartQuantities[drink.name] ?? 0;
                  return SizedBox(
                    width: 112,
                    child: FilledButton.tonalIcon(
                      onPressed: () => onAddToCart(drink),
                      icon: const Icon(Icons.add),
                      label: Text(
                        quantity > 0 ? '$quantity点' : '追加',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  );
                }

                // アルコールセクション
                if (alcoholicDrinks.isNotEmpty) {
                  items.add(sectionHeader(Icons.local_bar, 'アルコール'));
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
                            '${drink.volume.toStringAsFixed(0)} ml・${drink.alcoholPercentage.toStringAsFixed(0)}%・純アルコール${drink.calculatePureAlcohol().toStringAsFixed(1)}g',
                          ),
                          trailing: itemAction(drink),
                        ),
                      ),
                    );
                  }
                }

                // ノンアルコールセクション
                if (nonAlcoholicDrinks.isNotEmpty) {
                  items.add(
                    sectionHeader(Icons.local_drink, 'ノンアルコール'),
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
                          subtitle: Text(
                            '${drink.volume.toStringAsFixed(0)} ml・ノンアルコール',
                          ),
                          trailing: itemAction(drink),
                        ),
                      ),
                    );
                  }
                }

                // フードセクション
                if (foodItems.isNotEmpty) {
                  items.add(sectionHeader(Icons.restaurant, 'フード'));
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
                          trailing: itemAction(drink),
                        ),
                      ),
                    );
                  }
                }

                items.add(
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (cartItemCount > 0) ...[
                          FilledButton.icon(
                            onPressed: onCartTapped,
                            icon: const Icon(Icons.shopping_cart),
                            label: Text('カートを見る（$cartItemCount点）'),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '純アルコール合計 ${cartTotalAlcohol.toStringAsFixed(1)}g',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                        ],
                        TextButton(
                          onPressed: onCheckout,
                          child: const Text('利用を終了'),
                        ),
                      ],
                    ),
                  ),
                );

                return Column(children: items);
                },
              ),
            ],
          ),
        ),
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
        title: const Text('注文履歴'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: onBack,
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 840),
          child: Column(
            children: [
          Card(
            margin: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Column(
              children: [
                Text(
                  '注文数: ${orderHistory.length}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  '\u7d14\u30a2\u30eb\u30b3\u30fc\u30eb\u5408\u8a08 ${totalPureAlcohol.toStringAsFixed(1)}g',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: latestFirst.isEmpty
                ? const Center(
                    child: Text(
                      'まだ注文履歴がありません',
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
        ),
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
    final totalItems = cartItems.fold<int>(
      0,
      (sum, item) => sum + item.quantity,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('注文内容の確認'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: isSubmittingOrder ? null : onBack,
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 840),
          child: cartItems.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 80,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'カートは空です',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
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
                                    tooltip: 'カートから削除',
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
                                    tooltip: '数量を減らす',
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
                                    tooltip: '数量を増やす',
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
                    color: Theme.of(context).colorScheme.surface,
                    border: Border(
                      top: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '合計 $totalItems点・純アルコール ${totalPureAlcohol.toStringAsFixed(1)}g',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'この内容で注文します',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      FilledButton.icon(
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
                          isSubmittingOrder ? '注文送信中...' : '注文を確定',
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
        ),
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
