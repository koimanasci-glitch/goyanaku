// Penyimpanan kunci-nilai: database SQLite yang sama dengan aplikasi HTML (GoyanaStore.kt).

import 'package:flutter/services.dart';

abstract class KvStore {
  Future<String?> get(String key);
  Future<bool> set(String key, String value);
  Future<void> remove(String key);
}

/// Di HP: lewat kanal native ke GoyanaStore (SQLite, dibagi dengan WebView selama masa transisi).
class DeviceKvStore implements KvStore {
  const DeviceKvStore([this._channel = const MethodChannel('id.goyana/device')]);
  final MethodChannel _channel;
  @override
  Future<String?> get(String key) => _channel.invokeMethod<String>('Store.get', {'key': key});
  @override
  Future<bool> set(String key, String value) async => await _channel.invokeMethod<bool>('Store.set', {'key': key, 'value': value}) ?? false;
  @override
  Future<void> remove(String key) => _channel.invokeMethod<void>('Store.remove', {'key': key});
}

/// Untuk tes dan pratinjau.
class MemoryKvStore implements KvStore {
  MemoryKvStore([Map<String, String>? initial]) : data = {...?initial};
  final Map<String, String> data;
  @override
  Future<String?> get(String key) async => data[key];
  @override
  Future<bool> set(String key, String value) async {
    data[key] = value;
    return true;
  }

  @override
  Future<void> remove(String key) async => data.remove(key);
}

/// Nama kunci yang dipakai aplikasi HTML (jangan diganti: data lama di HP memakai nama ini).
abstract final class Keys {
  static const business = 'goyana-business177';
  static const services = 'goyana-services158';
  static const outlets = 'goyana-outlets180';
  static const activeOutlet = 'goyana-active-outlet180';
  static const perfumes = 'goyana-perfumes178';
  static const trial = 'goyana-trial190';
  static const qrisText = 'goyana-qris-text';
  static const qrisImage = 'goyana-qris-image';
  static const qrisOptions = 'goyana-qris-options185';
}
