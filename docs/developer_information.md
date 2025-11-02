# Log Levels Reference:

0-299: Fine/Debug
300-399: Config
400-499: Info
500-699: Warning
700-899: Severe/Error
900+: Shout/Critical

# To generate the model files use the command

```
flutter pub run build_runner build --delete-conflicting-outputs
```

# Faster build

```bash
flutter build apk --debug --target-platform android-arm64
```
