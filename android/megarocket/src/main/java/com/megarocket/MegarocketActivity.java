package com.megarocket;

import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;

import android.content.Intent;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Bundle;

import androidx.documentfile.provider.DocumentFile;

import org.libsdl.app.SDLActivity;

public class MegarocketActivity extends SDLActivity {

    private static final int REQ_IMPORT = 0x4b45; /* 'KE' */

    @Override
    protected String[] getLibraries() {
        return new String[] {
            "SDL2",
            "megarocket_launcher"
        };
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        extractBundledData();
        super.onCreate(savedInstanceState);
    }

    /* SDL second-guesses the manifest's orientation from its window flags
     * (a resizable window becomes sensor-any); this is a landscape shell. */
    @Override
    public void setOrientationBis(int w, int h, boolean resizable, String hint) {
        setRequestedOrientation(
            android.content.pm.ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE);
    }

    /* Omnispeak's own public metadata ships in the APK's assets (mirroring
     * the desktop dist's rt/); extract anything missing to files/rt. */
    private void extractBundledData() {
        try {
            File rt = new File(getExternalFilesDir(null), "rt");
            rt.mkdirs();
            String[] names = getAssets().list("rt");
            if (names == null)
                return;
            byte[] buf = new byte[65536];
            for (String name : names) {
                File dst = new File(rt, name);
                if (dst.exists())
                    continue;
                InputStream in = getAssets().open("rt/" + name);
                OutputStream out = new FileOutputStream(dst);
                int n;
                while ((n = in.read(buf)) > 0)
                    out.write(buf, 0, n);
                out.close();
                in.close();
            }
        } catch (Exception e) {
            /* engines will simply report the files missing */
        }
    }

    /* Called from launcher.c (launch()): front the requested game's
     * activity.  Android pauses this activity while the game runs -- the
     * launcher's usual "block while a game is playing" -- and resumes it
     * when the game's process exits. */
    public boolean launchSlot(int slot) {
        Intent intent;
        switch (slot) {
        case 0: intent = new Intent(this, Keen1Activity.class); break;
        case 1: intent = new Intent(this, Keen2Activity.class); break;
        case 2: intent = new Intent(this, Keen3Activity.class); break;
        case 3:
        case 4:
        case 5:
            intent = new Intent(this, OmnispeakActivity.class);
            intent.putExtra("episode", slot + 1);
            break;
        case 6:
            /* Keen Dreams is the separate ReflectionHLE app */
            intent = new Intent();
            intent.setClassName("com.reflectionhle",
                                "com.reflectionhle.ReflectionHLEActivity");
            break;
        default:
            return false;
        }
        try {
            startActivity(intent);
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    public boolean isDreamsInstalled() {
        try {
            getPackageManager().getPackageInfo("com.reflectionhle", 0);
            return true;
        } catch (PackageManager.NameNotFoundException e) {
            return false;
        }
    }

    /* Called from launcher.c when an empty slot is played: let the player
     * pick the folder holding their original game files; the copy runs in
     * the background and the launcher's periodic re-detect lights slots up
     * as their files land. */
    public boolean importGames() {
        try {
            Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT_TREE);
            startActivityForResult(intent, REQ_IMPORT);
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode != REQ_IMPORT || data == null)
            return;
        final Uri tree = data.getData();
        if (tree == null)
            return;
        new Thread(new Runnable() {
            @Override
            public void run() {
                DocumentFile root = DocumentFile.fromTreeUri(MegarocketActivity.this, tree);
                if (root == null)
                    return;
                java.util.ArrayList<Object[]> plan = new java.util.ArrayList<Object[]>();
                collectImports(root, 0, plan);
                /* Copy with retries: right after the grant dialog the first
                 * few opens can race the permission becoming visible. */
                for (int attempt = 0; attempt < 3 && !plan.isEmpty(); attempt++) {
                    java.util.ArrayList<Object[]> failed = new java.util.ArrayList<Object[]>();
                    for (Object[] job : plan) {
                        if (!copyOne((Uri) job[0], (String) job[1], (String) job[2]))
                            failed.add(job);
                    }
                    plan = failed;
                    if (!plan.isEmpty()) {
                        try { Thread.sleep(400); } catch (InterruptedException e) { break; }
                    }
                }
            }
        }, "megarocket-import").start();
    }

    /* Route recognised game files into the collection layout.  Filenames
     * are matched case-insensitively and normalised where an engine expects
     * exact names on Android's case-sensitive filesystem. */
    private void collectImports(DocumentFile dir, int depth, java.util.ArrayList<Object[]> plan) {
        if (depth > 4)
            return;
        DocumentFile[] entries = dir.listFiles();
        if (entries == null)
            return;
        for (DocumentFile f : entries) {
            if (f.isDirectory()) {
                collectImports(f, depth + 1, plan);
                continue;
            }
            String name = f.getName();
            if (name == null)
                continue;
            String lower = name.toLowerCase();
            String destDir = null, destName = null;
            if (lower.endsWith(".ck1")) { destDir = "keen13/gamedata";  destName = name.toUpperCase(); }
            else if (lower.endsWith(".ck2")) { destDir = "keen13/gamedata2"; destName = name.toUpperCase(); }
            else if (lower.endsWith(".ck3")) { destDir = "keen13/gamedata3"; destName = name.toUpperCase(); }
            else if (lower.equals("keen1.exe")) { destDir = "keen13/gamedata";  destName = "KEEN1.EXE"; }
            else if (lower.equals("keen2.exe")) { destDir = "keen13/gamedata2"; destName = "KEEN2.EXE"; }
            else if (lower.equals("keen3.exe")) { destDir = "keen13/gamedata3"; destName = "KEEN3.EXE"; }
            else if (lower.endsWith(".ck4") || lower.endsWith(".ck5")
                     || lower.endsWith(".ck6")) { destDir = "rt"; destName = name; }
            else if (lower.endsWith(".kdr") || lower.equals("kdreams.exe"))
                { destDir = "keendreams/game"; destName = lower; }
            if (destDir != null)
                plan.add(new Object[] { f.getUri(), destDir, destName });
        }
    }

    private boolean copyOne(Uri src, String destDir, String destName) {
        try {
            File outDir = new File(getExternalFilesDir(null), destDir);
            outDir.mkdirs();
            File dst = new File(outDir, destName);
            InputStream in = getContentResolver().openInputStream(src);
            OutputStream out = new FileOutputStream(dst);
            byte[] buf = new byte[65536];
            int n;
            while ((n = in.read(buf)) > 0)
                out.write(buf, 0, n);
            out.close();
            in.close();
            return true;
        } catch (Exception e) {
            return false;
        }
    }
}
