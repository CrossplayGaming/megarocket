package com.megarocket;

import java.io.File;

import android.os.Bundle;
import android.system.Os;

import org.libsdl.app.SDLActivity;

public class Keen1Activity extends SDLActivity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        try {
            Os.setenv("K13_CWD",
                new File(getExternalFilesDir(null), "keen13/gamedata").getAbsolutePath(),
                true);
        } catch (Exception e) {
            /* fall back to the engine's default (files-dir root) */
        }
        super.onCreate(savedInstanceState);
    }

    @Override
    protected String[] getLibraries() {
        return new String[] { "SDL2", "keen13" };
    }
}
