import QtQuick
import "../../native/OmaDeck/Touch" as NativeTouch

// Loaded privately by the trusted lock plugin. Only this boolean enters native
// state; the lock service, PAM objects and QML context are never exported.
NativeTouch.HostInputGuard {
  blocked: true
  // Loader may defer QObject deletion after destroying its QML context.
  // Revoke permission at context teardown, before that deferred deletion.
  Component.onDestruction: blocked = true
}
