# Konektizen Android editions

The normal Konektizen app keeps SOS enabled and uses the standard entry point:

```sh
flutter build apk --release --flavor standard --target lib/main.dart
```

The Laoag edition keeps the same Konektizen features but removes access to SOS
calls. Emergency hotline numbers remain available:

```sh
flutter build apk --release --flavor laoag --target lib/main_laoag.dart
```

The two entry points share the same feature code. SOS is not deleted from the
project; `main_laoag.dart` selects the Laoag edition before the app starts.

The Laoag flavor uses the separate Android package ID
`com.konektizen.konektizen.laoag` and the launcher name `Konektizen Laoag`, so
it can be installed beside the standard Konektizen app without replacing it.
