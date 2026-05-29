import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';

/// Global Isar instance provider.
/// Initialized in main.dart and overridden via ProviderScope.
final isarProvider = Provider<Isar>((ref) {
  throw UnimplementedError(
    'Isar must be initialized in main.dart before use.',
  );
});
