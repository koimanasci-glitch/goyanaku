import '../core/store.dart';
import 'device_store.dart';

/// Uses the existing native storage; does not introduce another account store.
class WaKvStorage implements WaStorage {
  const WaKvStorage(this.kv);
  final KvStore kv;
  @override
  Future<String?> read(String key) => kv.get(key);
  @override
  Future<bool> write(String key, String value) => kv.set(key, value);
}
