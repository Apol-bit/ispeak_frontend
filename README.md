# iSpeak

## Running on a physical Android phone

Start the Node backend:

```powershell
cd ..\ispeak_backend
node server.js
```

For a USB-connected phone, forward port 5000 and then run the app:

```powershell
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
& $adb reverse tcp:5000 tcp:5000
flutter run
```

The forwarding must be repeated after disconnecting or restarting the phone.

For Wi-Fi testing, put the phone and computer on the same network, find the
computer's current IPv4 address with `ipconfig`, and run:

```powershell
flutter run --dart-define=API_HOST=172.20.10.7
```

Replace that example address whenever the network changes. The backend should
report that it is listening on `http://0.0.0.0:5000`, and Windows Firewall must
allow Node.js on the private network.

For an Android emulator, use `--dart-define=API_HOST=10.0.2.2`. For a deployed
app, use an HTTPS backend URL via `--dart-define=API_BASE_URL=https://.../api`
instead of a development LAN address.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
