package com.megarocket;

import android.content.Intent;
import android.content.pm.PackageManager;

import org.libsdl.app.SDLActivity;

public class MegarocketActivity extends SDLActivity {
    @Override
    protected String[] getLibraries() {
        return new String[] {
            "SDL2",
            "megarocket_launcher"
        };
    }

    /* Called from launcher.c's launch() on the SDL thread: front the
     * requested game's activity.  Android pauses this activity while the
     * game runs -- the launcher's usual "block while a game is playing" --
     * and resumes it when the game's process exits. */
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
}
