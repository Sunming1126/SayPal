package com.japaneseengteacher.app;

import android.content.Intent;
import android.content.SharedPreferences;
import android.content.ClipData;
import android.content.ClipboardManager;
import android.os.Bundle;
import android.widget.TextView;
import android.widget.Toast;
import android.widget.EditText;

import androidx.annotation.Nullable;
import androidx.appcompat.app.AppCompatActivity;

import com.google.android.material.button.MaterialButton;

import org.json.JSONObject;

import java.io.IOException;
import java.util.concurrent.TimeUnit;

import okhttp3.Call;
import okhttp3.Callback;
import okhttp3.MediaType;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.RequestBody;
import okhttp3.Response;

public class ProfileActivity extends AppCompatActivity {

    private static final String PREFS_NAME = "ai_prefs";
    private static final String PREF_AUTH_TOKEN = "auth_token";

    private final OkHttpClient httpClient = new OkHttpClient.Builder()
            .connectTimeout(15, TimeUnit.SECONDS)
            .readTimeout(30, TimeUnit.SECONDS)
            .build();

    private TextView tvUsername;
    private TextView tvInviteCode;
    private TextView tvUserId;
    private TextView tvSubscription;
    private TextView tvMinutes;
    private TextView tvStatus;
    private EditText etCardCode;
    private MaterialButton btnLogout;
    private MaterialButton btnBack;
    private MaterialButton btnCopyInvite;
    private MaterialButton btnRedeemCard;

    private String lastInviteCode = null;

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_profile);

        tvUsername = findViewById(R.id.tv_username);
        tvInviteCode = findViewById(R.id.tv_invite_code);
        tvUserId = findViewById(R.id.tv_user_id);
        tvSubscription = findViewById(R.id.tv_subscription);
        tvMinutes = findViewById(R.id.tv_minutes);
        tvStatus = findViewById(R.id.tv_status);
        etCardCode = findViewById(R.id.et_card_code);
        btnLogout = findViewById(R.id.btn_logout);
        btnBack = findViewById(R.id.btn_back);
        btnCopyInvite = findViewById(R.id.btn_copy_invite);
        btnRedeemCard = findViewById(R.id.btn_redeem_card);

        if (btnBack != null) {
            btnBack.setOnClickListener(v -> finish());
        }
        if (btnLogout != null) {
            btnLogout.setOnClickListener(v -> doLogout());
        }

        if (btnCopyInvite != null) {
            btnCopyInvite.setOnClickListener(v -> copyInviteCode());
        }
        if (btnRedeemCard != null) {
            btnRedeemCard.setOnClickListener(v -> redeemCard());
        }

        fetchMeAndRender();
    }

    private void fetchMeAndRender() {
        SharedPreferences sp = getSharedPreferences(PREFS_NAME, MODE_PRIVATE);
        String token = sp.getString(PREF_AUTH_TOKEN, null);
        if (token == null || token.trim().isEmpty()) {
            if (tvStatus != null) tvStatus.setText("まだログインしていません");
            goLoginClear();
            return;
        }

        if (tvStatus != null) tvStatus.setText("読み込み中...");

        Request req = new Request.Builder()
                .url(AIConfigHelper.AGENT_API_BASE_URL + "/auth/me")
                .get()
                .addHeader("Authorization", "Bearer " + token)
                .build();

        httpClient.newCall(req).enqueue(new Callback() {
            @Override
            public void onFailure(Call call, IOException e) {
                runOnUiThread(() -> {
                    if (tvStatus != null) tvStatus.setText("読み込み失敗：ネットワークエラー");
                });
            }

            @Override
            public void onResponse(Call call, Response response) throws IOException {
                String resStr = response.body() != null ? response.body().string() : "";
                if (!response.isSuccessful()) {
                    runOnUiThread(() -> {
                        if (tvStatus != null) tvStatus.setText("ログインの有効期限が切れました");
                        goLoginClear();
                    });
                    return;
                }

                try {
                    JSONObject obj = new JSONObject(resStr);
                    JSONObject user = obj.optJSONObject("user");
                    String username = user != null ? user.optString("username", "") : "";
                    String userId = user != null ? user.optString("user_id", "") : "";
                    String inviteCode = user != null ? user.optString("invite_code", "") : "";
                    JSONObject sub = obj.optJSONObject("subscription");
                    int remainingDays = sub != null ? sub.optInt("remaining_days", 0) : 0;
                    double remainingMinutes = sub != null ? sub.optDouble("remaining_minutes", 0.0) : 0.0;
                    String expiresAt = sub != null ? sub.optString("expires_at", "") : "";
                    boolean canUse = obj.optBoolean("can_use", remainingDays > 0);

                    lastInviteCode = inviteCode;

                    runOnUiThread(() -> {
                        if (tvUsername != null) tvUsername.setText("ユーザー名：" + (username == null || username.trim().isEmpty() ? "-" : username));
                        if (tvInviteCode != null) tvInviteCode.setText("招待コード：" + (inviteCode == null || inviteCode.trim().isEmpty() ? "-" : inviteCode));
                        if (tvUserId != null) tvUserId.setText("UserId：" + (userId == null || userId.trim().isEmpty() ? "-" : userId));
                        if (tvSubscription != null) {
                            String expText = (expiresAt == null || expiresAt.trim().isEmpty()) ? "-" : expiresAt;
                            tvSubscription.setText("時間状態：" + (canUse ? "利用可能" : "利用不可") + "，残り " + remainingDays + " 日，期限 " + expText);
                        }
                        if (tvMinutes != null) {
                            tvMinutes.setText("通話分：残り " + formatMinutes(remainingMinutes) + " 分");
                        }
                        if (tvStatus != null) tvStatus.setText("");
                    });

                } catch (Exception e) {
                    runOnUiThread(() -> {
                        if (tvStatus != null) tvStatus.setText("解析に失敗しました");
                    });
                }
            }
        });
    }

    private void copyInviteCode() {
        String code = lastInviteCode != null ? lastInviteCode.trim() : "";
        if (code.isEmpty()) {
            Toast.makeText(this, "招待コードが空です", Toast.LENGTH_SHORT).show();
            return;
        }
        try {
            ClipboardManager cm = (ClipboardManager) getSystemService(CLIPBOARD_SERVICE);
            if (cm != null) {
                cm.setPrimaryClip(ClipData.newPlainText("invite_code", code));
            }
            Toast.makeText(this, "招待コードをコピーしました", Toast.LENGTH_SHORT).show();
        } catch (Exception e) {
            Toast.makeText(this, "コピーに失敗しました", Toast.LENGTH_SHORT).show();
        }
    }

    private void redeemCard() {
        SharedPreferences sp = getSharedPreferences(PREFS_NAME, MODE_PRIVATE);
        String token = sp.getString(PREF_AUTH_TOKEN, null);
        if (token == null || token.trim().isEmpty()) {
            if (tvStatus != null) tvStatus.setText("まずログインしてください");
            goLoginClear();
            return;
        }

        String cardCode = etCardCode != null ? String.valueOf(etCardCode.getText()).trim() : "";
        if (cardCode.isEmpty()) {
            Toast.makeText(this, "カード番号を入力してください", Toast.LENGTH_SHORT).show();
            return;
        }

        if (tvStatus != null) tvStatus.setText("交換中...");

        try {
            JSONObject payload = new JSONObject();
            payload.put("card_code", cardCode);

            RequestBody body = RequestBody.create(payload.toString(), MediaType.parse("application/json; charset=utf-8"));
            Request req = new Request.Builder()
                    .url(AIConfigHelper.AGENT_API_BASE_URL + "/auth/redeem_card")
                    .post(body)
                    .addHeader("Authorization", "Bearer " + token)
                    .build();

            httpClient.newCall(req).enqueue(new Callback() {
                @Override
                public void onFailure(Call call, IOException e) {
                    runOnUiThread(() -> {
                        if (tvStatus != null) tvStatus.setText("交換失敗：ネットワークエラー");
                    });
                }

                @Override
                public void onResponse(Call call, Response response) throws IOException {
                    String resStr = response.body() != null ? response.body().string() : "";
                    if (!response.isSuccessful()) {
                        String err = "交換失敗";
                        try {
                            JSONObject obj = new JSONObject(resStr);
                            String code = obj.optString("error", "");
                            if (code != null && !code.trim().isEmpty()) {
                                err = "交換失敗：" + code;
                            }
                        } catch (Exception ignored) {
                        }
                        String finalErr = err;
                        runOnUiThread(() -> {
                            if (tvStatus != null) tvStatus.setText(finalErr);
                        });
                        return;
                    }

                    try {
                        JSONObject resObj = new JSONObject(resStr);
                        StringBuilder sb = new StringBuilder("交換成功");
                        int daysAdded = resObj.optInt("days_added", 0);
                        double minsAdded = resObj.optDouble("minutes_added", 0.0);
                        if (daysAdded > 0) sb.append("，ログイン日数 +").append(daysAdded).append(" 日");
                        if (minsAdded > 0) sb.append("，通話分 +").append(formatMinutes(minsAdded)).append(" 分");
                        final String okMsg = sb.toString();
                        runOnUiThread(() -> {
                            if (etCardCode != null) etCardCode.setText("");
                            if (tvStatus != null) tvStatus.setText(okMsg);
                            fetchMeAndRender();
                        });
                    } catch (Exception ignored) {
                        runOnUiThread(() -> {
                            if (etCardCode != null) etCardCode.setText("");
                            if (tvStatus != null) tvStatus.setText("交換成功");
                            fetchMeAndRender();
                        });
                    }
                }
            });
        } catch (Exception e) {
            if (tvStatus != null) tvStatus.setText("交換失敗：リクエスト構築エラー");
        }
    }

    private void doLogout() {
        SharedPreferences sp = getSharedPreferences(PREFS_NAME, MODE_PRIVATE);
        String token = sp.getString(PREF_AUTH_TOKEN, null);

        sp.edit().remove(PREF_AUTH_TOKEN).apply();

        if (token == null || token.trim().isEmpty()) {
            goLoginClear();
            return;
        }

        Request req = new Request.Builder()
                .url(AIConfigHelper.AGENT_API_BASE_URL + "/auth/logout")
                .post(RequestBody.create(new byte[0], MediaType.parse("application/json; charset=utf-8")))
                .addHeader("Authorization", "Bearer " + token)
                .build();

        httpClient.newCall(req).enqueue(new Callback() {
            @Override
            public void onFailure(Call call, IOException e) {
                runOnUiThread(() -> goLoginClear());
            }

            @Override
            public void onResponse(Call call, Response response) {
                runOnUiThread(() -> goLoginClear());
            }
        });
    }

    private String formatMinutes(double minutes) {
        if (minutes >= 60) {
            int h = (int) (minutes / 60);
            int m = (int) Math.round(minutes % 60);
            return h + "h " + m + "m";
        }
        if (minutes == Math.floor(minutes)) {
            return String.valueOf((int) minutes);
        }
        return String.format("%.1f", minutes);
    }

    private void goLoginClear() {
        SharedPreferences sp = getSharedPreferences(PREFS_NAME, MODE_PRIVATE);
        sp.edit().remove(PREF_AUTH_TOKEN).apply();

        Intent it = new Intent(ProfileActivity.this, LoginActivity.class);
        it.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TASK);
        startActivity(it);
        finish();
    }
}
