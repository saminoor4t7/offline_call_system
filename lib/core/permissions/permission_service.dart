import 'package:permission_handler/permission_handler.dart' as ph;

class PermissionService {
  static ph.PermissionStatus? _lastMicrophoneRequest;

  /// Requests the microphone permission. Returns true when granted.
  static Future<bool> ensureMicrophone() async {
    var status = await ph.Permission.microphone.status;
    if (status == ph.PermissionStatus.granted) return true;
    status = await ph.Permission.microphone.request();
    _lastMicrophoneRequest = status;
    return status == ph.PermissionStatus.granted;
  }

  static Future<ph.PermissionStatus> microphoneStatus() =>
      ph.Permission.microphone.status;

  /// Android status checks report a permanent denial as `denied`; the result
  /// of the last request is needed to distinguish it from a first denial.
  static Future<bool> microphonePermanentlyDenied() async {
    if (_lastMicrophoneRequest == ph.PermissionStatus.permanentlyDenied) {
      return true;
    }
    return (await microphoneStatus()) == ph.PermissionStatus.permanentlyDenied;
  }

  /// Opens this app's system settings when Android no longer shows the
  /// permission prompt after repeated denial.
  static Future<bool> openAppSettings() => ph.openAppSettings();
}
