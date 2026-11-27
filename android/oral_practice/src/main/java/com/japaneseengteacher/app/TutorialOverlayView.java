package com.japaneseengteacher.app;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.PorterDuff;
import android.graphics.PorterDuffXfermode;
import android.graphics.Rect;
import android.graphics.RectF;
import android.text.TextUtils;
import android.util.AttributeSet;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.google.android.material.button.MaterialButton;
import com.google.android.material.card.MaterialCardView;

public class TutorialOverlayView extends FrameLayout {

    public interface Callback {
        void onAction();
    }

    private final Paint dimPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint clearPaint = new Paint(Paint.ANTI_ALIAS_FLAG);

    private RectF targetRect = null;
    private float targetRadiusPx = 0f;
    private View targetView = null;

    private MaterialCardView bubbleCard;
    private TextView titleView;
    private TextView bodyView;
    private MaterialButton nextButton;
    private MaterialButton skipButton;

    private Callback onNext;
    private Callback onSkip;

    public TutorialOverlayView(@NonNull Context context) {
        super(context);
        init();
    }

    public TutorialOverlayView(@NonNull Context context, @Nullable AttributeSet attrs) {
        super(context, attrs);
        init();
    }

    public TutorialOverlayView(@NonNull Context context, @Nullable AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
        init();
    }

    private void init() {
        setLayoutParams(new ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
        setClickable(true);
        setFocusable(true);

        dimPaint.setColor(0xB3000000);
        dimPaint.setStyle(Paint.Style.FILL);

        clearPaint.setXfermode(new PorterDuffXfermode(PorterDuff.Mode.CLEAR));
        clearPaint.setStyle(Paint.Style.FILL);

        setLayerType(View.LAYER_TYPE_SOFTWARE, null);

        bubbleCard = new MaterialCardView(getContext());
        bubbleCard.setCardElevation(dp(2));
        bubbleCard.setRadius(dp(16));
        bubbleCard.setCardBackgroundColor(0xFFFFFFFF);

        LinearLayout bubbleRoot = new LinearLayout(getContext());
        bubbleRoot.setOrientation(LinearLayout.VERTICAL);
        int pad = (int) dp(14);
        bubbleRoot.setPadding(pad, pad, pad, pad);

        titleView = new TextView(getContext());
        titleView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 16);
        titleView.setTextColor(0xFF111827);
        titleView.setTypeface(titleView.getTypeface(), android.graphics.Typeface.BOLD);
        bubbleRoot.addView(titleView, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));

        bodyView = new TextView(getContext());
        bodyView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 14);
        bodyView.setTextColor(0xFF374151);
        LinearLayout.LayoutParams bodyLp = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        bodyLp.topMargin = (int) dp(6);
        bubbleRoot.addView(bodyView, bodyLp);

        LinearLayout buttonRow = new LinearLayout(getContext());
        buttonRow.setOrientation(LinearLayout.HORIZONTAL);
        buttonRow.setGravity(Gravity.END);
        LinearLayout.LayoutParams rowLp = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        rowLp.topMargin = (int) dp(10);

        skipButton = new MaterialButton(getContext(), null, com.google.android.material.R.attr.materialButtonOutlinedStyle);
        skipButton.setText("チュートリアルをスキップ");
        skipButton.setLayerType(LAYER_TYPE_NONE, null);
        LinearLayout.LayoutParams skipLp = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        buttonRow.addView(skipButton, skipLp);

        nextButton = new MaterialButton(getContext());
        nextButton.setText("次へ");
        nextButton.setLayerType(LAYER_TYPE_NONE, null);
        LinearLayout.LayoutParams nextLp = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        nextLp.leftMargin = (int) dp(8);
        buttonRow.addView(nextButton, nextLp);

        bubbleRoot.addView(buttonRow, rowLp);

        bubbleCard.addView(bubbleRoot, new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));

        FrameLayout.LayoutParams cardLp = new FrameLayout.LayoutParams((int) dp(280), ViewGroup.LayoutParams.WRAP_CONTENT);
        cardLp.gravity = Gravity.TOP | Gravity.START;
        addView(bubbleCard, cardLp);

        skipButton.setOnClickListener(v -> {
            if (onSkip != null) onSkip.onAction();
        });
        nextButton.setOnClickListener(v -> {
            if (onNext != null) onNext.onAction();
        });

        setOnClickListener(v -> {
        });
    }

    public void setStep(@NonNull View target, @Nullable String title, @Nullable String body, @Nullable Callback onNext, @Nullable Callback onSkip) {
        this.targetView = target;
        this.onNext = onNext;
        this.onSkip = onSkip;

        titleView.setText(TextUtils.isEmpty(title) ? "" : title);
        bodyView.setText(TextUtils.isEmpty(body) ? "" : body);

        Rect r = new Rect();
        boolean ok = target.getGlobalVisibleRect(r);
        if (!ok) {
            targetRect = null;
        } else {
            int[] loc = new int[2];
            getLocationOnScreen(loc);
            float left = r.left - loc[0];
            float top = r.top - loc[1];
            float right = r.right - loc[0];
            float bottom = r.bottom - loc[1];
            targetRect = new RectF(left, top, right, bottom);
        }

        targetRadiusPx = Math.max(dp(12), (targetRect != null ? Math.min(targetRect.width(), targetRect.height()) / 2f : dp(16)));

        post(this::positionBubble);
        invalidate();
    }

    @Override
    public boolean onTouchEvent(android.view.MotionEvent event) {
        try {
            if (event != null && event.getAction() == android.view.MotionEvent.ACTION_UP) {
                if (targetRect != null && targetView != null) {
                    float x = event.getX();
                    float y = event.getY();
                    if (targetRect.contains(x, y)) {
                        targetView.performClick();
                        return true;
                    }
                }
            }
        } catch (Exception ignored) {
        }
        return true;
    }

    private void positionBubble() {
        if (targetRect == null) return;

        int w = getWidth();
        int h = getHeight();
        if (w <= 0 || h <= 0) return;

        int cardW = bubbleCard.getLayoutParams().width;
        if (cardW <= 0) cardW = (int) dp(280);

        float margin = dp(12);
        float xCenter = (targetRect.left + targetRect.right) / 2f;
        float desiredLeft = xCenter - cardW / 2f;
        float left = clamp(desiredLeft, margin, w - margin - cardW);

        bubbleCard.measure(MeasureSpec.makeMeasureSpec(cardW, MeasureSpec.EXACTLY), MeasureSpec.makeMeasureSpec(0, MeasureSpec.UNSPECIFIED));
        int cardH = bubbleCard.getMeasuredHeight();

        float spaceAbove = targetRect.top;
        float spaceBelow = h - targetRect.bottom;
        boolean placeBelow = spaceBelow >= cardH + margin || spaceBelow >= spaceAbove;

        float top;
        if (placeBelow) {
            top = targetRect.bottom + margin;
            top = Math.min(top, h - margin - cardH);
        } else {
            top = targetRect.top - margin - cardH;
            top = Math.max(top, margin);
        }

        FrameLayout.LayoutParams lp = (FrameLayout.LayoutParams) bubbleCard.getLayoutParams();
        lp.leftMargin = (int) left;
        lp.topMargin = (int) top;
        bubbleCard.setLayoutParams(lp);
    }

    @Override
    protected void dispatchDraw(Canvas canvas) {
        int save = canvas.saveLayer(0, 0, getWidth(), getHeight(), null);

        canvas.drawRect(0, 0, getWidth(), getHeight(), dimPaint);
        if (targetRect != null) {
            Path p = new Path();
            p.addRoundRect(targetRect, targetRadiusPx, targetRadiusPx, Path.Direction.CW);
            canvas.drawPath(p, clearPaint);
        }

        canvas.restoreToCount(save);
        super.dispatchDraw(canvas);
    }

    public void setNextText(@NonNull String text) {
        nextButton.setText(text);
    }

    public void setSkipVisible(boolean visible) {
        skipButton.setVisibility(visible ? View.VISIBLE : View.GONE);
    }

    private float dp(float v) {
        return TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, v, getResources().getDisplayMetrics());
    }

    private float clamp(float v, float min, float max) {
        return Math.max(min, Math.min(max, v));
    }
}
