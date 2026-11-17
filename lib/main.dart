
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String adminPassword = '1201';

// ==========================================
// データモデル
// ==========================================

class MeetingRoom {
  String id;
  String name;
  int capacity;
  String equipment;

  MeetingRoom({
    required this.id,
    required this.name,
    required this.capacity,
    required this.equipment,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'capacity': capacity,
    'equipment': equipment,
  };

  factory MeetingRoom.fromJson(Map<String, dynamic> json) {
    return MeetingRoom(
      id: json['id'],
      name: json['name'],
      capacity: json['capacity'],
      equipment: json['equipment'],
    );
  }
}

class AppUser {
  String id;
  String name;
  String email;
  String password;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.password,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'password': password,
  };

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      password: json['password'],
    );
  }
}

class Booking {
  String id;
  String userId;
  String roomId;
  String purpose;
  int participants;
  DateTime start;
  DateTime end;

  Booking({
    required this.id,
    required this.userId,
    required this.roomId,
    required this.purpose,
    required this.participants,
    required this.start,
    required this.end,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'roomId': roomId,
    'purpose': purpose,
    'participants': participants,
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
  };

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: json['id'],
      userId: json['userId'],
      roomId: json['roomId'],
      purpose: json['purpose'],
      participants: json['participants'],
      start: DateTime.parse(json['start']),
      end: DateTime.parse(json['end']),
    );
  }
}

// ==========================================
// アプリ本体・データ保存
// ==========================================

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MeetingApp());
}

class MeetingApp extends StatefulWidget {
  const MeetingApp({super.key});

  @override
  State<MeetingApp> createState() => _MeetingAppState();
}

class _MeetingAppState extends State<MeetingApp> {
  List<MeetingRoom> rooms = [];
  List<AppUser> users = [];
  List<Booking> bookings = [];

  AppUser? currentUser;
  bool isAdmin = false;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();

    try {
      final roomData = prefs.getString('rooms');
      final userData = prefs.getString('users');
      final bookingData = prefs.getString('bookings');

      if (roomData != null) {
        rooms = (jsonDecode(roomData) as List)
            .map((e) => MeetingRoom.fromJson(e))
            .toList();
      }

      if (userData != null) {
        users = (jsonDecode(userData) as List)
            .map((e) => AppUser.fromJson(e))
            .toList();
      }

      if (bookingData != null) {
        bookings = (jsonDecode(bookingData) as List)
            .map((e) => Booking.fromJson(e))
            .toList();
      }
    } catch (e) {
      debugPrint('データ読み込みエラー: $e');
    }

    if (rooms.isEmpty) {
      rooms = [
        MeetingRoom(
          id: 'room1',
          name: '第1会議室',
          capacity: 10,
          equipment: 'プロジェクター、ホワイトボード',
        ),
        MeetingRoom(
          id: 'room2',
          name: '第2会議室',
          capacity: 6,
          equipment: 'モニター、ホワイトボード',
        ),
        MeetingRoom(
          id: 'room3',
          name: '第3会議室',
          capacity: 20,
          equipment: 'プロジェクター、マイク',
        ),
      ];
    }

    await saveData();

    if (mounted) {
      setState(() => loading = false);
    }
  }

  Future<void> saveData() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      'rooms',
      jsonEncode(rooms.map((e) => e.toJson()).toList()),
    );

    await prefs.setString(
      'users',
      jsonEncode(users.map((e) => e.toJson()).toList()),
    );

    await prefs.setString(
      'bookings',
      jsonEncode(bookings.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> registerUser(AppUser user) async {
    users.add(user);
    await saveData();
    setState(() {});
  }

  Future<void> deleteAccount(String userId) async {
    users.removeWhere((u) => u.id == userId);
    bookings.removeWhere((b) => b.userId == userId);

    await saveData();

    setState(() {
      currentUser = null;
      isAdmin = false;
    });
  }

  void login(AppUser user) {
    setState(() {
      currentUser = user;
      isAdmin = false;
    });
  }

  void adminLogin() {
    setState(() {
      currentUser = null;
      isAdmin = true;
    });
  }

  void logout() {
    setState(() {
      currentUser = null;
      isAdmin = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '会議室予約システム',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      home: loading
          ? const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            )
          : isAdmin
              ? AdminPage(
                  rooms: rooms,
                  users: users,
                  bookings: bookings,
                  saveData: saveData,
                  logout: logout,
                )
              : currentUser != null
                  ? UserPage(
                      user: currentUser!,
                      rooms: rooms,
                      bookings: bookings,
                      users: users,
                      refresh: () async {
                        await saveData();
                        if (mounted) setState(() {});
                      },
                      deleteAccount: deleteAccount,
                      logout: logout,
                    )
                  : LoginPage(
                      users: users,
                      login: login,
                      registerUser: registerUser,
                      adminLogin: adminLogin,
                    ),
    );
  }
}

// ==========================================
// 利用者ログイン画面
// ==========================================

class LoginPage extends StatefulWidget {
  final List<AppUser> users;
  final Function(AppUser) login;
  final Function(AppUser) registerUser;
  final VoidCallback adminLogin;

  const LoginPage({
    super.key,
    required this.users,
    required this.login,
    required this.registerUser,
    required this.adminLogin,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final idController = TextEditingController();
  final passwordController = TextEditingController();

  void showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  void doLogin() {
    final user = widget.users.where(
      (u) =>
          u.id == idController.text.trim() &&
          u.password == passwordController.text,
    );

    if (user.isEmpty) {
      showMessage('IDまたはパスワードが違います');
      return;
    }

    widget.login(user.first);
  }

  @override
  void dispose() {
    idController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('会議室予約システム'),
        actions: [
  TextButton.icon(
    onPressed: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AdminLoginPage(
            onSuccess: () {
              widget.adminLogin();
              Navigator.pop(context);
            },
          ),
        ),
      );
    },
    icon: const Icon(Icons.admin_panel_settings),
    label: const Text('管理者'),
  ),
],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: SizedBox(
            width: 400,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.meeting_room, size: 65),
                    const SizedBox(height: 16),
                    const Text(
                      '利用者ログイン',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: idController,
                      decoration: const InputDecoration(
                        labelText: '利用者ID',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'パスワード',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: doLogin,
                        child: const Text('ログイン'),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RegisterPage(
                              users: widget.users,
                              registerUser: widget.registerUser,
                            ),
                          ),
                        );
                      },
                      child: const Text('新規アカウント登録'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 利用者登録画面
// ==========================================

class RegisterPage extends StatefulWidget {
  final List<AppUser> users;
  final Function(AppUser) registerUser;

  const RegisterPage({
    super.key,
    required this.users,
    required this.registerUser,
  });

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final id = TextEditingController();
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final password2 = TextEditingController();

  void message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Future<void> register() async {
    if (id.text.trim().isEmpty ||
        name.text.trim().isEmpty ||
        email.text.trim().isEmpty ||
        password.text.isEmpty) {
      message('すべての項目を入力してください');
      return;
    }

    if (widget.users.any((u) => u.id == id.text.trim())) {
      message('このIDはすでに使用されています');
      return;
    }

    if (password.text != password2.text) {
      message('パスワードが一致しません');
      return;
    }

    await widget.registerUser(
      AppUser(
        id: id.text.trim(),
        name: name.text.trim(),
        email: email.text.trim(),
        password: password.text,
      ),
    );

    if (!mounted) return;

    message('登録しました。ログインしてください');
    Navigator.pop(context);
  }

  @override
  void dispose() {
    id.dispose();
    name.dispose();
    email.dispose();
    password.dispose();
    password2.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('新規アカウント登録')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: SizedBox(
            width: 450,
            child: Column(
              children: [
                TextField(
                  controller: id,
                  decoration: const InputDecoration(
                    labelText: '利用者ID',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: name,
                  decoration: const InputDecoration(
                    labelText: '氏名',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: email,
                  decoration: const InputDecoration(
                    labelText: 'メールアドレス',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: password,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'パスワード',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: password2,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'パスワード（確認）',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: register,
                    child: const Text('登録する'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 利用者画面
// ==========================================

class UserPage extends StatefulWidget {
  final AppUser user;
  final List<MeetingRoom> rooms;
  final List<Booking> bookings;
  final List<AppUser> users;
  final Future<void> Function() refresh;
  final Future<void> Function(String) deleteAccount;
  final VoidCallback logout;

  const UserPage({
    super.key,
    required this.user,
    required this.rooms,
    required this.bookings,
    required this.users,
    required this.refresh,
    required this.deleteAccount,
    required this.logout,
  });

  @override
  State<UserPage> createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> {
  String? selectedRoom;
  DateTime selectedDate = DateTime.now();
  TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay endTime = const TimeOfDay(hour: 10, minute: 0);
  int participants = 1;

  final purpose = TextEditingController();

  DateTime get start => DateTime(
    selectedDate.year,
    selectedDate.month,
    selectedDate.day,
    startTime.hour,
    startTime.minute,
  );

  DateTime get end => DateTime(
    selectedDate.year,
    selectedDate.month,
    selectedDate.day,
    endTime.hour,
    endTime.minute,
  );

  String formatDate(DateTime date) {
    return '${date.year}/${date.month}/${date.day}';
  }

  String formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  void message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  @override
  void initState() {
    super.initState();
    if (widget.rooms.isNotEmpty) {
      selectedRoom = widget.rooms.first.id;
    }
  }

  Future<void> selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );

    if (date != null) {
      setState(() => selectedDate = date);
    }
  }

  Future<void> selectTime(bool isStart) async {
    final time = await showTimePicker(
      context: context,
      initialTime: isStart ? startTime : endTime,
    );

    if (time != null) {
      setState(() {
        if (isStart) {
          startTime = time;
        } else {
          endTime = time;
        }
      });
    }
  }

  Future<void> makeBooking() async {
    final room = widget.rooms.where((r) => r.id == selectedRoom);

    if (room.isEmpty) {
      message('会議室を選択してください');
      return;
    }

    if (purpose.text.trim().isEmpty) {
      message('利用目的を入力してください');
      return;
    }

    if (!end.isAfter(start)) {
      message('終了時刻は開始時刻より後にしてください');
      return;
    }

    if (participants < 1 || participants > room.first.capacity) {
      message('会議室の定員を超えています');
      return;
    }

    final overlap = widget.bookings.any((b) =>
        b.roomId == selectedRoom &&
        start.isBefore(b.end) &&
        end.isAfter(b.start));

    if (overlap) {
      message('この時間帯はすでに予約されています');
      return;
    }

    widget.bookings.add(
      Booking(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        userId: widget.user.id,
        roomId: selectedRoom!,
        purpose: purpose.text.trim(),
        participants: participants,
        start: start,
        end: end,
      ),
    );

    await widget.refresh();

    if (!mounted) return;

    purpose.clear();
    message('予約しました');
    setState(() {});
  }

  Future<void> cancelBooking(Booking booking) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('予約キャンセル'),
        content: const Text('この予約をキャンセルしますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('戻る'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('キャンセルする'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    widget.bookings.removeWhere((b) => b.id == booking.id);
    await widget.refresh();

    if (!mounted) return;

    setState(() {});
    message('予約をキャンセルしました');
  }

  Future<void> removeMyAccount() async {
  final passwordController = TextEditingController();

  final passwordResult = await showDialog<bool?>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('アカウント削除'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'アカウントと、このアカウントに紐づく予約を削除します。\n'
            '続行するには現在のパスワードを入力してください。',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: '現在のパスワード',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('戻る'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(
              context,
              passwordController.text == widget.user.password,
            );
          },
          child: const Text('確認'),
        ),
      ],
    ),
  );

  final correctPassword =
      passwordController.text == widget.user.password;

  passwordController.dispose();

  if (passwordResult == null) return;

  if (!correctPassword) {
    if (mounted) {
      message('パスワードが違います');
    }
    return;
  }

  if (!mounted) return;

  // 最終確認
  final finalConfirm = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('最終確認'),
      content: const Text(
        '本当にアカウントを削除しますか？\n'
        'アカウントとすべての予約情報が削除されます。\n'
        'この操作は取り消せません。',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('削除しない'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.red,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('完全に削除する'),
        ),
      ],
    ),
  );

  if (finalConfirm != true) return;

  await widget.deleteAccount(widget.user.id);
}

  @override
  void dispose() {
    purpose.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myBookings = widget.bookings
        .where((b) => b.userId == widget.user.id)
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    return Scaffold(
      appBar: AppBar(
        title: const Text('会議室予約'),
        actions: [
          IconButton(
            tooltip: '全体の予約状況',
            icon: const Icon(Icons.calendar_month),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AllBookingsPage(
                    rooms: widget.rooms,
                    users: widget.users,
                    bookings: widget.bookings,
                  ),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'ログアウト',
            onPressed: widget.logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
  child: ConstrainedBox(
    constraints: const BoxConstraints(
      maxWidth: 760,
    ),
    child: ListView(
      padding: const EdgeInsets.all(20),
      children: [
          Text(
            'こんにちは、${widget.user.name} さん',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text('ID：${widget.user.id}'),
          Text('メール：${widget.user.email}'),

          const Divider(height: 32),

          const Text(
            '新しい予約',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          DropdownButtonFormField<String>(
            value: selectedRoom,
            decoration: const InputDecoration(
              labelText: '会議室',
              border: OutlineInputBorder(),
            ),
            items: widget.rooms.map((room) {
              return DropdownMenuItem(
                value: room.id,
                child: Text('${room.name}（定員${room.capacity}名）'),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                selectedRoom = value;
                if (value != null) {
                  final room =
                      widget.rooms.firstWhere((r) => r.id == value);
                  if (participants > room.capacity) {
                    participants = room.capacity;
                  }
                }
              });
            },
          ),

          if (selectedRoom != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '設備：${widget.rooms.firstWhere((r) => r.id == selectedRoom).equipment}',
              ),
            ),

          const SizedBox(height: 12),

          OutlinedButton.icon(
            onPressed: selectDate,
            icon: const Icon(Icons.calendar_month),
            label: Text('日付：${formatDate(selectedDate)}'),
          ),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => selectTime(true),
                  child: Text('開始：${formatTime(startTime)}'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => selectTime(false),
                  child: Text('終了：${formatTime(endTime)}'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          DropdownButtonFormField<int>(
            value: participants,
            decoration: const InputDecoration(
              labelText: '利用人数',
              border: OutlineInputBorder(),
            ),
            items: List.generate(
              selectedRoom == null
                  ? 1
                  : widget.rooms
                      .firstWhere((r) => r.id == selectedRoom)
                      .capacity,
              (i) => DropdownMenuItem(
                value: i + 1,
                child: Text('${i + 1}名'),
              ),
            ),
            onChanged: (value) {
              if (value != null) {
                setState(() => participants = value);
              }
            },
          ),

          const SizedBox(height: 12),

          TextField(
            controller: purpose,
            decoration: const InputDecoration(
              labelText: '利用目的',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 16),

          FilledButton.icon(
            onPressed: widget.rooms.isEmpty ? null : makeBooking,
            icon: const Icon(Icons.add),
            label: const Text('予約する'),
          ),

          const Divider(height: 40),

          // 個人の予約一覧はこの位置に維持
          const Text(
            '自分の予約一覧',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),

          if (myBookings.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('予約はありません'),
            ),

          ...myBookings.map((booking) {
            final room =
                widget.rooms.where((r) => r.id == booking.roomId);
            final roomName =
                room.isEmpty ? '削除された会議室' : room.first.name;

            return Card(
              child: ListTile(
                title: Text(roomName),
                subtitle: Text(
                  '${formatDate(booking.start)}\n'
                  '${formatTime(TimeOfDay.fromDateTime(booking.start))}'
                  ' ～ '
                  '${formatTime(TimeOfDay.fromDateTime(booking.end))}\n'
                  '人数：${booking.participants}名\n'
                  '目的：${booking.purpose}',
                ),
                isThreeLine: true,
                trailing: IconButton(
                  icon: const Icon(Icons.cancel_outlined),
                  tooltip: '予約キャンセル',
                  onPressed: () => cancelBooking(booking),
                ),
              ),
            );
          }),

          const SizedBox(height: 30),

          FilledButton.tonalIcon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AllBookingsPage(
                    rooms: widget.rooms,
                    users: widget.users,
                    bookings: widget.bookings,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.calendar_month),
            label: const Text('全体の予約状況を見る'),
          ),

          const Divider(height: 40),

          
        ExpansionTile(
  leading: const Icon(Icons.settings),
  title: const Text('アカウント設定'),
  subtitle: const Text('重要な操作があります'),
  children: [
    const Padding(
      padding: EdgeInsets.all(12),
      child: Text(
        '以下の操作を行うと、アカウントと関連する予約情報が削除されます。',
        style: TextStyle(color: Colors.grey),
      ),
    ),
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: OutlinedButton.icon(
        onPressed: removeMyAccount,
        icon: const Icon(Icons.person_remove),
        label: const Text('自分のアカウントを削除する'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red,
        ),
      ),
    ),
  ],
),
        ],
      ),
    ),
  ),
);
  }
}

// ==========================================
// 全体の予約状況画面
// 一覧表・カレンダー切り替え
// ==========================================

class AllBookingsPage extends StatefulWidget {
  final List<MeetingRoom> rooms;
  final List<AppUser> users;
  final List<Booking> bookings;

  const AllBookingsPage({
    super.key,
    required this.rooms,
    required this.users,
    required this.bookings,
  });

  @override
  State<AllBookingsPage> createState() => _AllBookingsPageState();
}

class _AllBookingsPageState extends State<AllBookingsPage> {
  bool calendarMode = false;
  DateTime currentMonth = DateTime(DateTime.now().year, DateTime.now().month);

  String formatDate(DateTime date) {
    return '${date.year}/${date.month}/${date.day}';
  }

  String formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String roomName(String id) {
    final result = widget.rooms.where((r) => r.id == id);
    return result.isEmpty ? '削除された会議室' : result.first.name;
  }

  String userName(String id) {
    final result = widget.users.where((u) => u.id == id);
    return result.isEmpty ? '削除された利用者' : result.first.name;
  }

  @override
  Widget build(BuildContext context) {
    final allBookings = [...widget.bookings]
      ..sort((a, b) => a.start.compareTo(b.start));

    return Scaffold(
      appBar: AppBar(
        title: const Text('全体の予約状況'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  label: Text('一覧表'),
                  icon: Icon(Icons.list),
                ),
                ButtonSegment(
                  value: true,
                  label: Text('カレンダー'),
                  icon: Icon(Icons.calendar_month),
                ),
              ],
              selected: {calendarMode},
              onSelectionChanged: (value) {
                setState(() => calendarMode = value.first);
              },
            ),
          ),

          Expanded(
            child: calendarMode
                ? buildCalendar(allBookings)
                : buildList(allBookings),
          ),
        ],
      ),
    );
  }

  Widget buildList(List<Booking> allBookings) {
    if (allBookings.isEmpty) {
      return const Center(child: Text('現在、予約はありません'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '予約件数：${allBookings.length}件',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),

        ...allBookings.map((booking) {
          return Card(
            child: ListTile(
              leading: const Icon(Icons.event),
              title: Text(roomName(booking.roomId)),
              subtitle: Text(
                '予約者：${userName(booking.userId)}\n'
                '日付：${formatDate(booking.start)}\n'
                '時間：${formatTime(booking.start)} ～ ${formatTime(booking.end)}\n'
                '人数：${booking.participants}名\n'
                '目的：${booking.purpose}',
              ),
              isThreeLine: true,
            ),
          );
        }),
      ],
    );
  }

  Widget buildCalendar(List<Booking> allBookings) {
  final firstDay = DateTime(
    currentMonth.year,
    currentMonth.month,
    1,
  );

  final daysInMonth = DateTime(
    currentMonth.year,
    currentMonth.month + 1,
    0,
  ).day;

  final offset = (firstDay.weekday + 6) % 7;
  final cells = ((offset + daysInMonth + 6) ~/ 7) * 7;

  return Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: 760,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () {
                    setState(() {
                      currentMonth = DateTime(
                        currentMonth.year,
                        currentMonth.month - 1,
                      );
                    });
                  },
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(
                  '${currentMonth.year}年 ${currentMonth.month}月',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      currentMonth = DateTime(
                        currentMonth.year,
                        currentMonth.month + 1,
                      );
                    });
                  },
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),

          // 曜日表示
          Row(
            children: [
              '月', '火', '水', '木', '金', '土', '日'
            ].map((day) {
              return Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 4,
                    ),
                    child: Text(
                      day,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          // 日付表示
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(3),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 0.95,
              ),
              itemCount: cells,
              itemBuilder: (context, index) {
                final day = index - offset + 1;

                if (day < 1 || day > daysInMonth) {
                  return const SizedBox();
                }

                final date = DateTime(
                  currentMonth.year,
                  currentMonth.month,
                  day,
                );

                final dayBookings = allBookings.where((b) =>
                    b.start.year == date.year &&
                    b.start.month == date.month &&
                    b.start.day == date.day).toList();

                return InkWell(
                  onTap: () {
                    showDayBookings(date, dayBookings);
                  },
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: dayBookings.isEmpty
                          ? Colors.grey.withValues(alpha: 0.08)
                          : Colors.blue.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: dayBookings.isEmpty
                            ? Colors.transparent
                            : Colors.blue,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$day',
                          style: const TextStyle(fontSize: 12),
                        ),
                        if (dayBookings.isNotEmpty) ...[
                          const Icon(
                            Icons.event,
                            size: 11,
                            color: Colors.blue,
                          ),
                          Text(
                            '${dayBookings.length}件',
                            style: const TextStyle(fontSize: 9),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const Padding(
            padding: EdgeInsets.all(6),
            child: Text(
              '日付を選択すると、その日の予約を確認できます。',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

  void showDayBookings(DateTime date, List<Booking> dayBookings) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${formatDate(date)} の予約'),
        content: SizedBox(
          width: 450,
          child: dayBookings.isEmpty
              ? const Text('この日の予約はありません')
              : ListView(
                  shrinkWrap: true,
                  children: dayBookings.map((booking) {
                    return ListTile(
                      title: Text(roomName(booking.roomId)),
                      subtitle: Text(
                        '${formatTime(booking.start)} ～ ${formatTime(booking.end)}\n'
                        '予約者：${userName(booking.userId)}\n'
                        '人数：${booking.participants}名',
                      ),
                    );
                  }).toList(),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 管理者ログイン画面
// ==========================================

class AdminLoginPage extends StatefulWidget {
  final VoidCallback onSuccess;

  const AdminLoginPage({
    super.key,
    required this.onSuccess,
  });

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final password = TextEditingController();

  @override
  void dispose() {
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('管理者ログイン')),
      body: Center(
        child: SizedBox(
          width: 350,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.admin_panel_settings, size: 60),
                const SizedBox(height: 20),
                TextField(
                  controller: password,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '管理者パスワード',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => checkPassword(),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: checkPassword,
                  child: const Text('ログイン'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void checkPassword() {
    if (password.text == adminPassword) {
      widget.onSuccess();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('パスワードが違います'),
        ),
      );
    }
  }
}

// ==========================================
// 管理者画面
// ==========================================

class AdminPage extends StatelessWidget {
  final List<MeetingRoom> rooms;
  final List<AppUser> users;
  final List<Booking> bookings;
  final Future<void> Function() saveData;
  final VoidCallback logout;

  const AdminPage({
    super.key,
    required this.rooms,
    required this.users,
    required this.bookings,
    required this.saveData,
    required this.logout,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('管理者画面'),
          actions: [
            IconButton(
              tooltip: 'ログアウト',
              onPressed: logout,
              icon: const Icon(Icons.logout),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.meeting_room), text: '会議室管理'),
              Tab(icon: Icon(Icons.event), text: '予約管理'),
              Tab(icon: Icon(Icons.people), text: '利用者管理'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            RoomManagement(
              rooms: rooms,
              bookings: bookings,
              saveData: saveData,
            ),
            BookingManagement(
              rooms: rooms,
              users: users,
              bookings: bookings,
              saveData: saveData,
            ),
            UserManagement(
              users: users,
              bookings: bookings,
              saveData: saveData,
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 管理者：会議室管理
// ==========================================

class RoomManagement extends StatefulWidget {
  final List<MeetingRoom> rooms;
  final List<Booking> bookings;
  final Future<void> Function() saveData;

  const RoomManagement({
    super.key,
    required this.rooms,
    required this.bookings,
    required this.saveData,
  });

  @override
  State<RoomManagement> createState() => _RoomManagementState();
}

class _RoomManagementState extends State<RoomManagement> {
  Future<void> editRoom([MeetingRoom? room]) async {
    final name = TextEditingController(text: room?.name ?? '');
    final capacity = TextEditingController(
      text: room?.capacity.toString() ?? '10',
    );
    final equipment = TextEditingController(
      text: room?.equipment ?? '',
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(room == null ? '会議室追加' : '会議室編集'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: '会議室名'),
              ),
              TextField(
                controller: capacity,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '定員'),
              ),
              TextField(
                controller: equipment,
                decoration: const InputDecoration(labelText: '設備'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('戻る'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context, true);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (result == true) {
      final count = int.tryParse(capacity.text);

      if (name.text.trim().isEmpty || count == null || count < 1) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('入力内容を確認してください')),
          );
        }
      } else {
        if (room == null) {
          widget.rooms.add(
            MeetingRoom(
              id: DateTime.now().microsecondsSinceEpoch.toString(),
              name: name.text.trim(),
              capacity: count,
              equipment: equipment.text.trim(),
            ),
          );
        } else {
          room.name = name.text.trim();
          room.capacity = count;
          room.equipment = equipment.text.trim();
        }

        await widget.saveData();
        if (mounted) setState(() {});
      }
    }

    name.dispose();
    capacity.dispose();
    equipment.dispose();
  }

  Future<void> deleteRoom(MeetingRoom room) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('会議室削除'),
        content: Text(
          '${room.name} を削除しますか？\n関連する予約も削除されます。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('戻る'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (ok == true) {
      widget.rooms.removeWhere((r) => r.id == room.id);
      widget.bookings.removeWhere((b) => b.roomId == room.id);
      await widget.saveData();

      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FilledButton.icon(
          onPressed: () => editRoom(),
          icon: const Icon(Icons.add),
          label: const Text('会議室を追加'),
        ),
        const SizedBox(height: 12),
        ...widget.rooms.map((room) {
          return Card(
            child: ListTile(
              title: Text(room.name),
              subtitle: Text(
                '定員：${room.capacity}名\n設備：${room.equipment}',
              ),
              isThreeLine: true,
              trailing: Wrap(
                children: [
                  IconButton(
                    onPressed: () => editRoom(room),
                    icon: const Icon(Icons.edit),
                  ),
                  IconButton(
                    onPressed: () => deleteRoom(room),
                    icon: const Icon(Icons.delete, color: Colors.red),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

// ==========================================
// 管理者：予約管理
// ==========================================

class BookingManagement extends StatefulWidget {
  final List<MeetingRoom> rooms;
  final List<AppUser> users;
  final List<Booking> bookings;
  final Future<void> Function() saveData;

  const BookingManagement({
    super.key,
    required this.rooms,
    required this.users,
    required this.bookings,
    required this.saveData,
  });

  @override
  State<BookingManagement> createState() => _BookingManagementState();
}

class _BookingManagementState extends State<BookingManagement> {
  String roomName(String id) {
    final room = widget.rooms.where((r) => r.id == id);
    return room.isEmpty ? '削除された会議室' : room.first.name;
  }

  String userName(String id) {
    final user = widget.users.where((u) => u.id == id);
    return user.isEmpty ? '削除された利用者' : user.first.name;
  }

  String formatDate(DateTime date) {
    return '${date.year}/${date.month}/${date.day}';
  }

  String formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> editBooking(Booking booking) async {
    final purpose = TextEditingController(text: booking.purpose);
    final participants = TextEditingController(
      text: booking.participants.toString(),
    );

    DateTime newStart = booking.start;
    DateTime newEnd = booking.end;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, dialogSetState) => AlertDialog(
          title: const Text('予約情報の編集'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('予約者：${userName(booking.userId)}'),
                Text('会議室：${roomName(booking.roomId)}'),
                const SizedBox(height: 12),
                TextField(
                  controller: purpose,
                  decoration: const InputDecoration(
                    labelText: '利用目的',
                  ),
                ),
                TextField(
                  controller: participants,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '利用人数',
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: newStart,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );

                    if (date != null) {
                      dialogSetState(() {
                        newStart = DateTime(
                          date.year,
                          date.month,
                          date.day,
                          newStart.hour,
                          newStart.minute,
                        );
                        newEnd = DateTime(
                          date.year,
                          date.month,
                          date.day,
                          newEnd.hour,
                          newEnd.minute,
                        );
                      });
                    }
                  },
                  child: Text('利用日：${formatDate(newStart)}'),
                ),
                OutlinedButton(
                  onPressed: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(newStart),
                    );

                    if (time != null) {
                      dialogSetState(() {
                        newStart = DateTime(
                          newStart.year,
                          newStart.month,
                          newStart.day,
                          time.hour,
                          time.minute,
                        );
                      });
                    }
                  },
                  child: Text('開始：${formatTime(newStart)}'),
                ),
                OutlinedButton(
                  onPressed: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(newEnd),
                    );

                    if (time != null) {
                      dialogSetState(() {
                        newEnd = DateTime(
                          newEnd.year,
                          newEnd.month,
                          newEnd.day,
                          time.hour,
                          time.minute,
                        );
                      });
                    }
                  },
                  child: Text('終了：${formatTime(newEnd)}'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('戻る'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );

    final count = int.tryParse(participants.text);

    if (result == true &&
        purpose.text.trim().isNotEmpty &&
        count != null &&
        count > 0 &&
        newEnd.isAfter(newStart)) {
      final room = widget.rooms.where((r) => r.id == booking.roomId);

      final capacity = room.isEmpty ? count : room.first.capacity;

      final overlap = widget.bookings.any((b) =>
          b.id != booking.id &&
          b.roomId == booking.roomId &&
          newStart.isBefore(b.end) &&
          newEnd.isAfter(b.start));

      if (count > capacity || overlap) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('定員または予約時間を確認してください'),
            ),
          );
        }
      } else {
        booking.purpose = purpose.text.trim();
        booking.participants = count;
        booking.start = newStart;
        booking.end = newEnd;

        await widget.saveData();
        if (mounted) setState(() {});
      }
    }

    purpose.dispose();
    participants.dispose();
  }

  Future<void> deleteBooking(Booking booking) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('予約削除'),
        content: const Text('この予約を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('戻る'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (ok == true) {
      widget.bookings.removeWhere((b) => b.id == booking.id);
      await widget.saveData();
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = [...widget.bookings]
      ..sort((a, b) => a.start.compareTo(b.start));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '予約件数：${list.length}件',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...list.map((booking) {
          return Card(
            child: ListTile(
              title: Text(roomName(booking.roomId)),
              subtitle: Text(
                '予約者：${userName(booking.userId)}\n'
                '日付：${formatDate(booking.start)}\n'
                '時間：${formatTime(booking.start)} ～ ${formatTime(booking.end)}\n'
                '人数：${booking.participants}名\n'
                '目的：${booking.purpose}',
              ),
              isThreeLine: true,
              trailing: Wrap(
                children: [
                  IconButton(
                    tooltip: '編集',
                    onPressed: () => editBooking(booking),
                    icon: const Icon(Icons.edit),
                  ),
                  IconButton(
                    tooltip: '削除',
                    onPressed: () => deleteBooking(booking),
                    icon: const Icon(Icons.delete, color: Colors.red),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

// ==========================================
// 管理者：利用者アカウント管理
// ==========================================

class UserManagement extends StatefulWidget {
  final List<AppUser> users;
  final List<Booking> bookings;
  final Future<void> Function() saveData;

  const UserManagement({
    super.key,
    required this.users,
    required this.bookings,
    required this.saveData,
  });

  @override
  State<UserManagement> createState() => _UserManagementState();
}

class _UserManagementState extends State<UserManagement> {
  Future<void> editUser(AppUser user) async {
    final name = TextEditingController(text: user.name);
    final email = TextEditingController(text: user.email);
    final password = TextEditingController(text: user.password);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('利用者情報の編集'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('利用者ID：${user.id}'),
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: '氏名'),
              ),
              TextField(
                controller: email,
                decoration: const InputDecoration(labelText: 'メールアドレス'),
              ),
              TextField(
                controller: password,
                decoration: const InputDecoration(labelText: '新しいパスワード'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('戻る'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (result == true &&
        name.text.trim().isNotEmpty &&
        email.text.trim().isNotEmpty &&
        password.text.isNotEmpty) {
      user.name = name.text.trim();
      user.email = email.text.trim();
      user.password = password.text;

      await widget.saveData();

      if (mounted) setState(() {});
    }

    name.dispose();
    email.dispose();
    password.dispose();
  }

  Future<void> deleteUser(AppUser user) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('利用者削除'),
        content: Text(
          '${user.name} さんのアカウントと予約情報を削除しますか？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('戻る'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (ok == true) {
      widget.users.removeWhere((u) => u.id == user.id);
      widget.bookings.removeWhere((b) => b.userId == user.id);

      await widget.saveData();

      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '登録利用者：${widget.users.length}人',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),

        ...widget.users.map((user) {
          return Card(
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.person),
              ),
              title: Text(user.name),
              subtitle: Text(
                'ID：${user.id}\n'
                'メール：${user.email}',
              ),
              isThreeLine: true,
              trailing: Wrap(
                children: [
                  IconButton(
                    tooltip: '編集',
                    onPressed: () => editUser(user),
                    icon: const Icon(Icons.edit),
                  ),
                  IconButton(
                    tooltip: '削除',
                    onPressed: () => deleteUser(user),
                    icon: const Icon(Icons.delete, color: Colors.red),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
