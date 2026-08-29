package com.megarocket;

import java.io.File;

import android.os.Bundle;
import android.system.Os;

import org.libsdl.app.SDLActivity;

public class Keen2Activity extends EngineActivity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        try {
            Os.setenv("K13_CWD",
                new File(getExternalFilesDir(null), "keen13/gamedata2").getAbsolutePath(),
                true);
        } catch (Exception e) {
            /* fall back to the engine's default (files-dir root) */
        }
        super.onCreate(savedInstanceState);
    }

    @Override
    protected String[] getLibraries() {
        return new String[] { "SDL2", "keen13_ep2" };
    }
}
