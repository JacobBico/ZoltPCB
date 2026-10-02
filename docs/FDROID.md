# Releasing on F-Droid

F-Droid builds Zolt from source, signs it with its own key and publishes it.
It finds new versions by watching this repository's git tags.

## Each release

1. Raise the version in `pubspec.yaml`: `1.0.0+1`, then `1.0.1+2`, and so on.
   The number after `+` must go up every release and stay below 1000 (see
   the comment there).
2. Add the release's notes to `assets/changelog.md`, and the same notes,
   500 characters at most, to
   `fastlane/metadata/android/en-US/changelogs/<number after +>.txt`.
3. Commit, then tag and push the tag: `git tag v1.0.1 && git push origin v1.0.1`.

F-Droid picks the tag up on its own, usually within a few days.

## The listing

Everything F-Droid shows comes from `fastlane/metadata/android/en-US/`:
`title.txt`, `short_description.txt` (80 characters at most),
`full_description.txt`, `images/icon.png`, and screenshots in
`images/phoneScreenshots/` as `1.png`, `2.png`, and so on.

## Per-CPU APKs

F-Droid builds one APK for each CPU type rather than one APK holding all
three, so each download is about a third of the size. This uses Flutter's
`--split-per-abi`, which numbers each APK CPU x 1000 + versionCode:

| CPU | APK | versionCode for `+1` |
|---|---|---|
| 32-bit ARM | `app-armeabi-v7a-release.apk` | 1001 |
| 64-bit ARM | `app-arm64-v8a-release.apk` | 2001 |
| x86_64 | `app-x86_64-release.apk` | 4001 |

## Checking a build before submitting

```bash
pip install fdroidserver
flutter build apk --release --split-per-abi
fdroid scanner --refresh --exit-code build/app/outputs/flutter-apk/app-*-release.apk
```

An exit code of 0 means nothing was flagged. `fdroid scanner` needs
`ANDROID_HOME` set to the Android SDK.

## The recipe

The first submission is a merge request to
[fdroiddata](https://gitlab.com/fdroid/fdroiddata) adding this file as
`metadata/com.zoltpcb.app.yml`. F-Droid's reviewers often adjust a recipe
during review; after that it lives in fdroiddata, not here.

```yaml
Categories:
  - Science & Education
License: GPL-3.0-or-later
SourceCode: https://github.com/JacobBico/ZoltPCB
IssueTracker: https://github.com/JacobBico/ZoltPCB/issues
Changelog: https://github.com/JacobBico/ZoltPCB/blob/HEAD/assets/changelog.md

AutoName: Zolt

RepoType: git
Repo: https://github.com/JacobBico/ZoltPCB.git

Builds:
  - versionName: 1.0.0
    versionCode: 1001
    commit: v1.0.0
    output: build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk
    srclibs:
      - flutter@3.38.7
    prebuild:
      - export PUB_CACHE=$(pwd)/.pub-cache
      - $$flutter$$/bin/flutter config --no-analytics
      - $$flutter$$/bin/flutter pub get
    scandelete:
      - .pub-cache
    build:
      - export PUB_CACHE=$(pwd)/.pub-cache
      - $$flutter$$/bin/flutter build apk --release --split-per-abi --target-platform=android-arm
    ndk: r28c

  - versionName: 1.0.0
    versionCode: 2001
    commit: v1.0.0
    output: build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
    srclibs:
      - flutter@3.38.7
    prebuild:
      - export PUB_CACHE=$(pwd)/.pub-cache
      - $$flutter$$/bin/flutter config --no-analytics
      - $$flutter$$/bin/flutter pub get
    scandelete:
      - .pub-cache
    build:
      - export PUB_CACHE=$(pwd)/.pub-cache
      - $$flutter$$/bin/flutter build apk --release --split-per-abi --target-platform=android-arm64
    ndk: r28c

  - versionName: 1.0.0
    versionCode: 4001
    commit: v1.0.0
    output: build/app/outputs/flutter-apk/app-x86_64-release.apk
    srclibs:
      - flutter@3.38.7
    prebuild:
      - export PUB_CACHE=$(pwd)/.pub-cache
      - $$flutter$$/bin/flutter config --no-analytics
      - $$flutter$$/bin/flutter pub get
    scandelete:
      - .pub-cache
    build:
      - export PUB_CACHE=$(pwd)/.pub-cache
      - $$flutter$$/bin/flutter build apk --release --split-per-abi --target-platform=android-x64
    ndk: r28c


AutoUpdateMode: Version
UpdateCheckMode: Tags
VercodeOperation:
  - 1000 + %c
  - 2000 + %c
  - 4000 + %c
UpdateCheckData: pubspec.yaml|version:\s.+\+(\d+)|.|version:\s(.+)\+
CurrentVersion: 1.0.0
CurrentVersionCode: 4001
```

`ndk: r28c` is NDK 28.2.13676358, the version Flutter 3.38.7 asks for. Move
`flutter@3.38.7` along with the version in `.github/workflows/ci.yml`
whenever Flutter is upgraded.
