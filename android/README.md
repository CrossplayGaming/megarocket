# Megarocket Android

Gradle project for the Android builds. One module per engine; the launcher
shell module comes later (see `docs/ANDROID_PLAN.md`).

## Per-machine setup (not committed)

Each engine module's `jni/` needs links to the source trees, and the SDL Java
glue copied in. On Windows (junctions; from the repo root):

```
# megarocket (the launcher + all engines in one APK — the main deliverable)
New-Item -ItemType Junction android\megarocket\jni\SDL        -Target deps\SDL2-2.32.10-src
New-Item -ItemType Junction android\megarocket\jni\omnispeak  -Target omnispeak
New-Item -ItemType Junction android\megarocket\jni\keen13port -Target keen13\port
New-Item -ItemType Junction android\megarocket\jni\launcher   -Target launcher
New-Item -ItemType Junction android\megarocket\jni\SDL3       -Target deps\SDL3-3.2.30
New-Item -ItemType Junction android\megarocket\jni\refkeen    -Target refkeen
Copy-Item -Recurse deps\SDL2-2.32.10-src\android-project\app\src\main\java\org android\megarocket\src\main\java\org
# SDL3's glue must be package-renamed once per fresh SDL3 tree, so it can
# coexist with SDL2's glue in one APK:
powershell -File android\patch-sdl3-java-package.ps1
Copy-Item -Recurse deps\SDL3-3.2.30\android-project\app\src\main\java\org\libsdl3 android\megarocket\src\main\java\org\libsdl3

# engine-only test modules use the same pattern:
#   omnispeak: jni\SDL, jni\omnispeak
#   keen13:    jni\SDL, jni\keen13port
Set-Content android\local.properties "sdk.dir=<path-to-Android-Sdk>"
```

Build (JAVA_HOME must point at a JDK, e.g. Android Studio's `jbr`):

```
cd android && ./gradlew assembleDebug
```

## Data files

Engines default their data path to the app-specific external storage
directory (`/sdcard/Android/data/<applicationId>/files`), which needs no
runtime permission and is adb-pushable:

```
adb push rt/*.CK4 /sdcard/Android/data/com.megarocket.omnispeak/files/
```
