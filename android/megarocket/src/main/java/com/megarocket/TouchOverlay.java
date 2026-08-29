package com.megarocket;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.view.KeyEvent;
import android.view.MotionEvent;
import android.view.View;

import org.libsdl.app.SDLActivity;

/* On-screen controls for the game activities: a d-pad on the left, three
 * action buttons on the right, ESC and ENTER at the top corners.  Control
 * transitions inject ordinary Android key events into SDL through
 * SDLActivity's native hooks, so the engines see a keyboard and need no
 * changes.  Keys match the engines' shipped defaults: Ctrl = jump,
 * Alt = pogo, Space = fire. */
public class TouchOverlay extends View {

    private static final int NBTN = 5;
    private static final int[] BTN_KEY = {
        KeyEvent.KEYCODE_ESCAPE,     /* ESC   */
        KeyEvent.KEYCODE_ENTER,      /* ENTER */
        KeyEvent.KEYCODE_CTRL_LEFT,  /* JUMP  */
        KeyEvent.KEYCODE_ALT_LEFT,   /* POGO  */
        KeyEvent.KEYCODE_SPACE,      /* FIRE  */
    };
    private static final String[] BTN_LABEL = { "ESC", "ENTER", "JUMP", "POGO", "FIRE" };

    private final float[] bx = new float[NBTN], by = new float[NBTN], br = new float[NBTN];
    private final boolean[] btnHeld = new boolean[NBTN];
    private float dpadCx, dpadCy, dpadR;

    private static final int MAX_POINTERS = 16;
    /* pointer id -> what it is holding: -1 none, -2 the d-pad, else button */
    private final int[] pointerOwns = new int[MAX_POINTERS];

    private boolean leftHeld, rightHeld, upHeld, downHeld;

    private final Paint fill = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint stroke = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint label = new Paint(Paint.ANTI_ALIAS_FLAG);

    public TouchOverlay(Context context) {
        super(context);
        for (int i = 0; i < MAX_POINTERS; i++)
            pointerOwns[i] = -1;
        fill.setColor(0x33ffffff);
        stroke.setStyle(Paint.Style.STROKE);
        stroke.setColor(0x66ffffff);
        label.setColor(0x99ffffff);
        label.setTextAlign(Paint.Align.CENTER);
    }

    @Override
    protected void onSizeChanged(int w, int h, int oldw, int oldh) {
        float u = Math.min(w, h) / 9.0f;

        dpadR = 1.9f * u;
        dpadCx = 0.6f * u + dpadR;
        dpadCy = h - 0.6f * u - dpadR;

        /* JUMP under the thumb, POGO beside it, FIRE above */
        br[2] = 0.95f * u; bx[2] = w - 1.4f * u;           by[2] = h - 1.6f * u;
        br[3] = 0.95f * u; bx[3] = w - 3.6f * u;           by[3] = h - 1.2f * u;
        br[4] = 0.95f * u; bx[4] = w - 2.6f * u;           by[4] = h - 3.4f * u;

        /* menu keys, small, at the top corners */
        br[0] = 0.65f * u; bx[0] = 1.1f * u;               by[0] = 1.1f * u;
        br[1] = 0.65f * u; bx[1] = w - 1.1f * u;           by[1] = 1.1f * u;

        stroke.setStrokeWidth(0.08f * u);
        label.setTextSize(0.42f * u);
    }

    @Override
    protected void onDraw(Canvas c) {
        /* d-pad: ring plus cross arms */
        c.drawCircle(dpadCx, dpadCy, dpadR, fill);
        c.drawCircle(dpadCx, dpadCy, dpadR, stroke);
        float a = dpadR * 0.55f;
        c.drawLine(dpadCx - a, dpadCy, dpadCx + a, dpadCy, stroke);
        c.drawLine(dpadCx, dpadCy - a, dpadCx, dpadCy + a, stroke);

        for (int i = 0; i < NBTN; i++) {
            fill.setColor(btnHeld[i] ? 0x66ffffff : 0x33ffffff);
            c.drawCircle(bx[i], by[i], br[i], fill);
            c.drawCircle(bx[i], by[i], br[i], stroke);
            c.drawText(BTN_LABEL[i], bx[i], by[i] + label.getTextSize() / 3, label);
        }
        fill.setColor(0x33ffffff);
    }

    private void key(int keycode, boolean down) {
        if (down)
            SDLActivity.onNativeKeyDown(keycode);
        else
            SDLActivity.onNativeKeyUp(keycode);
    }

    private void setDpad(boolean l, boolean r, boolean u, boolean d) {
        if (l != leftHeld)  { key(KeyEvent.KEYCODE_DPAD_LEFT, l);  leftHeld = l; }
        if (r != rightHeld) { key(KeyEvent.KEYCODE_DPAD_RIGHT, r); rightHeld = r; }
        if (u != upHeld)    { key(KeyEvent.KEYCODE_DPAD_UP, u);    upHeld = u; }
        if (d != downHeld)  { key(KeyEvent.KEYCODE_DPAD_DOWN, d);  downHeld = d; }
    }

    private void dpadMove(float x, float y) {
        float dx = x - dpadCx, dy = y - dpadCy;
        float dead = dpadR * 0.28f;
        setDpad(dx < -dead, dx > dead, dy < -dead, dy > dead);
    }

    private int classify(float x, float y) {
        float ddx = x - dpadCx, ddy = y - dpadCy;
        if (ddx * ddx + ddy * ddy <= dpadR * dpadR * 2.0f)
            return -2;
        int best = -1;
        float bestD = Float.MAX_VALUE;
        for (int i = 0; i < NBTN; i++) {
            float dx = x - bx[i], dy = y - by[i];
            float d = dx * dx + dy * dy;
            float reach = br[i] * 1.35f;
            if (d <= reach * reach && d < bestD) {
                best = i;
                bestD = d;
            }
        }
        return best;
    }

    private void release(int pid) {
        if (pid < 0 || pid >= MAX_POINTERS)
            return;
        int owns = pointerOwns[pid];
        pointerOwns[pid] = -1;
        if (owns == -2)
            setDpad(false, false, false, false);
        else if (owns >= 0 && btnHeld[owns]) {
            btnHeld[owns] = false;
            key(BTN_KEY[owns], false);
        }
    }

    @Override
    public boolean onTouchEvent(MotionEvent ev) {
        int action = ev.getActionMasked();
        int idx = ev.getActionIndex();
        int pid = ev.getPointerId(idx);

        switch (action) {
        case MotionEvent.ACTION_DOWN:
        case MotionEvent.ACTION_POINTER_DOWN: {
            if (pid >= MAX_POINTERS)
                break;
            int owns = classify(ev.getX(idx), ev.getY(idx));
            pointerOwns[pid] = owns;
            if (owns == -2)
                dpadMove(ev.getX(idx), ev.getY(idx));
            else if (owns >= 0 && !btnHeld[owns]) {
                btnHeld[owns] = true;
                key(BTN_KEY[owns], true);
            }
            break;
        }
        case MotionEvent.ACTION_MOVE:
            for (int i = 0; i < ev.getPointerCount(); i++) {
                int p = ev.getPointerId(i);
                if (p < MAX_POINTERS && pointerOwns[p] == -2)
                    dpadMove(ev.getX(i), ev.getY(i));
            }
            break;
        case MotionEvent.ACTION_UP:
        case MotionEvent.ACTION_POINTER_UP:
            release(pid);
            break;
        case MotionEvent.ACTION_CANCEL:
            for (int i = 0; i < MAX_POINTERS; i++)
                release(i);
            break;
        }
        invalidate();
        return true;
    }
}
