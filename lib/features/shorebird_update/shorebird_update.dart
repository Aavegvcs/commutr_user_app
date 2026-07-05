// =============================================================================
// Shorebird OTA Update — Public Barrel (single import entry point)
// =============================================================================
//
// Import this one file to use the entire module:
//
// ```dart
// import 'package:commutr_main/features/shorebird_update/shorebird_update.dart';
//
// final manager = ShorebirdUpdateManager();
// await manager.checkAndDownload();           // check + download in one call
//
// // or use the service directly for fine-grained control:
// final service = ShorebirdUpdateService();
// final result = await service.checkForUpdate();
// if (result.hasUpdate) {
//   final download = await service.downloadUpdate();
//   if (download.needsRestart) { /* prompt restart */ }
// }
// ```
//
// This module is fully self-contained and independent of the existing
// version-check / Play Store / App Store update flow.
// =============================================================================

export 'data/shorebird_update_service.dart';
export 'domain/i_shorebird_update_service.dart';
export 'domain/shorebird_update_models.dart';
export 'shorebird_update_manager.dart';
