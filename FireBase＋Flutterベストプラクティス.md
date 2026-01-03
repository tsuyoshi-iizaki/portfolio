
# Riverpod × Firestore アーキテクチャ設計ガイド

Flutter (Dart) アプリにおいて、Cloud Firestore と Riverpod を組み合わせた状態管理アーキテクチャのベストプラクティスを解説します。

---

## 📁 ディレクトリ構成

```
lib/
├── main.dart
├── models/
│   └── user.dart
├── services/
│   └── firestore_service.dart
├── repositories/
│   └── user_repository.dart
├── providers/
│   └── user_provider.dart
├── screens/
│   └── user_profile_screen.dart
└── widgets/
    └── user_info_card.dart
```

---

## ① モデル定義

`models/user.dart`

```dart
class User {
  final String id;
  final String name;
  final int age;

  User({required this.id, required this.name, required this.age});

  factory User.fromJson(String id, Map<String, dynamic> json) {
    return User(
      id: id,
      name: json['name'],
      age: json['age'],
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'age': age,
      };
}
```

---

## ② Firestore サービス層

`services/firestore_service.dart`

```dart
class FirestoreService {
  final _db = FirebaseFirestore.instance;

  Stream<User> streamUser(String userId) {
    return _db.collection('users').doc(userId).snapshots().map((doc) {
      return User.fromJson(doc.id, doc.data()!);
    });
  }

  Future<void> updateUser(User user) async {
    await _db.collection('users').doc(user.id).update(user.toJson());
  }
}
```

---

## ③ Repository 層

`repositories/user_repository.dart`

```dart
class UserRepository {
  final FirestoreService _service;

  UserRepository(this._service);

  Stream<User> getUserStream(String userId) => _service.streamUser(userId);
  Future<void> updateUser(User user) => _service.updateUser(user);
}
```

---

## ④ Provider 定義（Riverpod）

`providers/user_provider.dart`

```dart
final firestoreServiceProvider = Provider((ref) => FirestoreService());

final userRepositoryProvider = Provider((ref) {
  final service = ref.watch(firestoreServiceProvider);
  return UserRepository(service);
});

final userStreamProvider =
    StreamProvider.family<User, String>((ref, userId) {
  final repo = ref.watch(userRepositoryProvider);
  return repo.getUserStream(userId);
});
```

---

## ⑤ UI 実装例

`screens/user_profile_screen.dart`

```dart
class UserProfileScreen extends ConsumerWidget {
  final String userId;

  const UserProfileScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userStreamProvider(userId));

    return Scaffold(
      appBar: AppBar(title: Text('User Profile')),
      body: userAsync.when(
        data: (user) => Column(
          children: [
            Text('Name: ${user.name}'),
            Text('Age: ${user.age}'),
          ],
        ),
        loading: () => Center(child: CircularProgressIndicator()),
        error: (e, _) => Text('Error: $e'),
      ),
    );
  }
}
```

---

## ✅ この構成のメリット

- データ取得を責任分離して再利用可能に
- UI層がシンプルに保てる
- テストしやすくモック可能
- Firestoreのリアルタイム性とRiverpodのキャッシュ性を両立

---

## 🔜 拡張例

- `StateNotifierProvider` によるフォーム操作
- `AsyncNotifier` を使った非同期状態制御
- REST API やローカルDBへの差し替えも容易

---

## 📝 まとめ

このアーキテクチャを用いることで、Flutterアプリにおける Firestore のデータ管理が堅牢・再利用可能・テスト可能になります。
