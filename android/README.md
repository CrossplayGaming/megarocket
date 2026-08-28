# Megarocket Android

Gradle project for the Android builds. One module per engine; the launcher
shell module comes later (see `docs/ANDROID_PLAN.md`).

## Per-machine setup (not committed)

Each engine module's `jni/` needs links to the source trees, and the SDL Java
glue copied in. On Windows (junctions; from the repo root):

```
New-Item -ItemType Junction android\omnispeak\jni\SDL       -Target deps\SDL2-2.32.10-src
New-Item -ItemType Junction android\omnispeak\jni\omnispeak -Target omnispeak
Copy-Item -Recurse deps\SDL2-2.32.10-src\android-project\app\src\main\java\org android\omnispeak\src\main\java\org
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
