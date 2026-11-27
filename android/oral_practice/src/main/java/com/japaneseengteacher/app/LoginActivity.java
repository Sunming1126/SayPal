package com.japaneseengteacher.app;

import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Bundle;
import android.widget.TextView;
import android.widget.Toast;

import androidx.annotation.Nullable;
import androidx.appcompat.app.AppCompatActivity;

import com.google.android.material.button.MaterialButton;
import com.google.android.material.textfield.TextInputEditText;

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

public class LoginActivity extends AppCompatActivity {

    private static final String PREFS_NAME = "ai_prefs";
    private static final String PREF_AUTH_TOKEN = "auth_token";
    private static final String PREF_USERNAME = "username";

    private final OkHttpClient httpClient = new OkHttpClient.Builder()
            .connectTimeout(15, TimeUnit.SECONDS)
            .readTimeout(30, TimeUnit.SECONDS)
            .build();

    private TextInputEditText etUsername;
    private TextInputEditText etPassword;
    private MaterialButton btnLogin;
    private MaterialButton btnGoRegister;
    private TextView tvStatus;

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_login);

        etUsername = findViewById(R.id.et_username);
        etPassword = findViewById(R.id.et_password);
        btnLogin = findViewById(R.id.btn_login);
        btnGoRegister = findViewById(R.id.btn_go_register);
        tvStatus = findViewById(R.id.tv_status);

        SharedPreferences sp = getSharedPreferences(PREFS_NAME, MODE_PRIVATE);
        String lastUsername = sp.getString(PREF_USERNAME, "");
        if (etUsername != null && lastUsername != null && !lastUsername.trim().isEmpty()) {
            etUsername.setText(lastUsername);
        }

        if (btnLogin != null) {
            btnLogin.setOnClickListener(v -> doLogin());
        }

        if (btnGoRegister != null) {
            btnGoRegister.setOnClickListener(v -> {
                Intent it = new Intent(LoginActivity.this, RegisterActivity.class);
                startActivity(it);
            });
        }

        String token = sp.getString(PREF_AUTH_TOKEN, null);
        if (token != null && !token.trim().isEmpty()) {
            if (tvStatus != null) tvStatus.setText("正在验证登录状态...");
            verifyTokenAndEnter(token);
        }
    }

    private void verifyTokenAndEnter(String token) {
        Request req = new Request.Builder()
                .url(AIConfigHelper.AGENT_API_BASE_URL + "/auth/me")
                .get()
                .addHeader("Authorization", "Bearer " + token)
                .build();

        httpClient.newCall(req).enqueue(new Callback() {
            @Override
            public void onFailure(Call call, IOException e) {
                runOnUiThread(() -> {
                    getSharedPreferences(PREFS_NAME, MODE_PRIVATE).edit().remove(PREF_AUTH_TOKEN).apply();
                    if (tvStatus != null) tvStatus.setText("验证失败，请重新登录");
                });
            }

            @Override
            public void onResponse(Call call, Response response) throws IOException {
                String resStr = response.body() != null ? response.body().string() : "";
                if (!response.isSuccessful()) {
                    runOnUiThread(() -> {
                        getSharedPreferences(PREFS_NAME, MODE_PRIVATE).edit().remove(PREF_AUTH_TOKEN).apply();
                        if (tvStatus != null) tvStatus.setText("登录已失效，请重新登录");
                    });
                    return;
                }

                try {
                    JSONObject obj = new JSONObject(resStr);
                    JSONObject user = obj.optJSONObject("user");
                    String username = user != null ? user.optString("username", "") : "";
                    JSONObject sub = obj.optJSONObject("subscription");
                    int remainingDays = sub != null ? sub.optInt("remaining_days", 0) : 0;
                    boolean canUse = obj.optBoolean("can_use", remainingDays > 0);
                    if (username != null && !username.trim().isEmpty()) {
                        getSharedPreferences(PREFS_NAME, MODE_PRIVATE).edit().putString(PREF_USERNAME, username).apply();
                    }
                    final boolean finalCanUse = canUse;
                    runOnUiThread(() -> enterAfterAuth(finalCanUse));
                    return;
                } catch (Exception ignored) {
                }
                runOnUiThread(() -> enterAfterAuth(true));
            }
        });
    }

    private void doLogin() {
        String username = etUsername != null ? String.valueOf(etUsername.getText()).trim() : "";
        String password = etPassword != null ? String.valueOf(etPassword.getText()).trim() : "";

        if (username.isEmpty() || password.isEmpty()) {
            Toast.makeText(this, "请输入用户名和密码", Toast.LENGTH_SHORT).show();
            return;
        }

        if (tvStatus != null) tvStatus.setText("正在登录...");

        try {
            JSONObject payload = new JSONObject();
            payload.put("username", username);
            payload.put("password", password);

            RequestBody body = RequestBody.create(payload.toString(), MediaType.parse("application/json; charset=utf-8"));
            Request req = new Request.Builder()
                    .url(AIConfigHelper.AGENT_API_BASE_URL + "/auth/login")
                    .post(body)
                    .build();

            httpClient.newCall(req).enqueue(new Callback() {
                @Override
                public void onFailure(Call call, IOException e) {
                    runOnUiThread(() -> {
                        if (tvStatus != null) tvStatus.setText("登录失败：网络异常");
                    });
                }

                @Override
                public void onResponse(Call call, Response response) throws IOException {
                    String resStr = response.body() != null ? response.body().string() : "";
                    if (!response.isSuccessful()) {
                        runOnUiThread(() -> {
                            if (tvStatus != null) tvStatus.setText("登录失败：http=" + response.code());
                        });
                        return;
                    }

                    try {
                        JSONObject obj = new JSONObject(resStr);
                        String token = obj.optString("token", "");
                        JSONObject user = obj.optJSONObject("user");
                        JSONObject sub = obj.optJSONObject("subscription");
                        int remainingDays = sub != null ? sub.optInt("remaining_days", 0) : 0;
                        boolean canUse = obj.optBoolean("can_use", remainingDays > 0);
                        String uname = user != null ? user.optString("username", username) : username;

                        if (token == null || token.trim().isEmpty()) {
                            runOnUiThread(() -> {
                                if (tvStatus != null) tvStatus.setText("登录失败：token为空");
                            });
                            return;
                        }

                        SharedPreferences sp = getSharedPreferences(PREFS_NAME, MODE_PRIVATE);
                        sp.edit()
                                .putString(PREF_AUTH_TOKEN, token)
                                .putString(PREF_USERNAME, uname)
                                .apply();

                        final boolean finalCanUse = canUse;
                        runOnUiThread(() -> enterAfterAuth(finalCanUse));
                    } catch (Exception e) {
                        runOnUiThread(() -> {
                            if (tvStatus != null) tvStatus.setText("登录失败：解析异常");
                        });
                    }
                }
            });

        } catch (Exception e) {
            if (tvStatus != null) tvStatus.setText("登录失败：构造请求异常");
        }
    }

    private void enterHome() {
        Intent it = new Intent(LoginActivity.this, TrainingSelectActivity.class);
        startActivity(it);
        finish();
    }

    private void enterProfileForRedeem() {
        Intent it = new Intent(LoginActivity.this, ProfileActivity.class);
        startActivity(it);
        finish();
    }

    private void enterAfterAuth(boolean canUse) {
        if (canUse) {
            enterHome();
        } else {
            if (tvStatus != null) {
                tvStatus.setText("当前无可用时长，请先兑换时长卡");
            }
            enterProfileForRedeem();
        }
    }
}
