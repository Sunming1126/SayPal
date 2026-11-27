package com.japaneseengteacher.app;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.util.AttributeSet;
import android.view.View;

import androidx.annotation.Nullable;

import java.util.Random;

public class VoiceWaveView extends View {

    private static final int BAR_COUNT = 16;
    private static final long FRAME_DELAY_MS = 40;

    private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final float[] bars = new float[BAR_COUNT];
    private final Random random = new Random();

    private boolean running = false;

    private final Runnable tick = new Runnable() {
        @Override
        public void run() {
            if (!running) return;
            for (int i = 0; i < BAR_COUNT; i++) {
                float target = 0.15f + random.nextFloat() * 0.85f;
                bars[i] = bars[i] * 0.55f + target * 0.45f;
            }
            invalidate();
            postDelayed(this, FRAME_DELAY_MS);
        }
    };

    public VoiceWaveView(Context context) {
        super(context);
        init();
    }

    public VoiceWaveView(Context context, @Nullable AttributeSet attrs) {
        super(context, attrs);
        init();
    }

    public VoiceWaveView(Context context, @Nullable AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
        init();
    }

    private void init() {
        paint.setColor(0xFF2DE2E6);
        paint.setStyle(Paint.Style.FILL);
        for (int i = 0; i < BAR_COUNT; i++) {
            bars[i] = 0.2f;
        }
    }

    public void start() {
        if (running) return;
        running = true;
        removeCallbacks(tick);
        post(tick);
    }

    public void stop() {
        running = false;
        removeCallbacks(tick);
        for (int i = 0; i < BAR_COUNT; i++) {
            bars[i] = 0.12f;
        }
        invalidate();
    }

    public boolean isRunning() {
        return running;
    }

    @Override
    protected void onDetachedFromWindow() {
        stop();
        super.onDetachedFromWindow();
    }

    @Override
    protected void onDraw(Canvas canvas) {
        super.onDraw(canvas);

        int w = getWidth();
        int h = getHeight();
        if (w <= 0 || h <= 0) return;

        float gap = dp(3);
        float barWidth = (w - gap * (BAR_COUNT - 1)) / BAR_COUNT;
        float minH = dp(4);

        for (int i = 0; i < BAR_COUNT; i++) {
            float value = bars[i];
            float barH = Math.max(minH, value * h);
            float left = i * (barWidth + gap);
            float top = (h - barH) / 2f;
            float right = left + barWidth;
            float bottom = top + barH;
            float r = barWidth / 2f;
            canvas.drawRoundRect(left, top, right, bottom, r, r, paint);
        }
    }

    private float dp(float dp) {
        return dp * getResources().getDisplayMetrics().density;
    }
}
