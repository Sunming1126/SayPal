package com.japaneseengteacher.app;

import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Bundle;
import android.util.Patterns;
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

public class RegisterActivity extends AppCompatActivity {

    private static final String PREFS_NAME = "ai_prefs";
    private static final String PREF_AUTH_TOKEN = "auth_token";
    private static final String PREF_USERNAME = "username";

    private final OkHttpClient httpClient = new OkHttpClient.Builder()
            .connectTimeout(15, TimeUnit.SECONDS)
            .readTimeout(30, TimeUnit.SECONDS)
            .build();

    private TextInputEditText etUsername;
    private TextInputEditText etPassword;
    private TextInputEditText etEmail;
    private TextInputEditText etPhone;
    private TextInputEditText etInviteCode;
    private MaterialButton btnRegister;
    private MaterialButton btnBack;
    private TextView tvStatus;

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_register);

        etUsername = findViewById(R.id.et_username);
        etPassword = findViewById(R.id.et_password);
        etEmail = findViewById(R.id.et_email);
        etPhone = findViewById(R.id.et_phone);
        etInviteCode = findViewById(R.id.et_invite_code);
        btnRegister = findViewById(R.id.btn_register);
        btnBack = findViewById(R.id.btn_back);
        tvStatus = findViewById(R.id.tv_status);

        if (btnBack != null) {
            btnBack.setOnClickListener(v -> finish());
        }
        if (btnRegister != null) {
            btnRegister.setOnClickListener(v -> doRegister());
        }
    }

    private void doRegister() {
        String username = etUsername != null ? String.valueOf(etUsername.getText()).trim() : "";
        String password = etPassword != null ? String.valueOf(etPassword.getText()).trim() : "";
        String email = etEmail != null ? String.valueOf(etEmail.getText()).trim() : "";
        String phone = etPhone != null ? String.valueOf(etPhone.getText()).trim() : "";
        String inviteCode = etInviteCode != null ? String.valueOf(etInviteCode.getText()).trim() : "";

        if (username.isEmpty() || password.isEmpty() || email.isEmpty() || phone.isEmpty() || inviteCode.isEmpty()) {
            Toast.makeText(this, "请填写完整信息", Toast.LENGTH_SHORT).show();
            return;
        }

        if (!Patterns.EMAIL_ADDRESS.matcher(email).matches()) {
            Toast.makeText(this, "邮箱格式不正确", Toast.LENGTH_SHORT).show();
            return;
        }

        String phoneDigits = phone.replaceAll("\\D+", "");
        if (phoneDigits.startsWith("86") && phoneDigits.length() >= 13) {
            phoneDigits = phoneDigits.substring(2);
        }
        if (!phoneDigits.matches("^1\\d{10}$")) {
            Toast.makeText(this, "手机号格式不正确", Toast.LENGTH_SHORT).show();
            return;
        }

        if (tvStatus != null) tvStatus.setText("正在注册...");

        try {
            JSONObject payload = new JSONObject();
            payload.put("username", username);
            payload.put("password", password);
            payload.put("email", email);
            payload.put("phone", phoneDigits);
            payload.put("invite_code", inviteCode);

            RequestBody body = RequestBody.create(payload.toString(), MediaType.parse("application/json; charset=utf-8"));
            Request req = new Request.Builder()
                    .url(AIConfigHelper.AGENT_API_BASE_URL + "/auth/register")
                    .post(body)
                    .build();

            httpClient.newCall(req).enqueue(new Callback() {
                @Override
                public void onFailure(Call call, IOException e) {
                    runOnUiThread(() -> {
                        if (tvStatus != null) tvStatus.setText("注册失败：网络异常");
                    });
                }

                @Override
                public void onResponse(Call call, Response response) throws IOException {
                    String resStr = response.body() != null ? response.body().string() : "";
                    if (!response.isSuccessful()) {
                        runOnUiThread(() -> {
                            if (tvStatus != null) tvStatus.setText("注册失败：http=" + response.code());
                        });
                        return;
                    }

                    try {
                        JSONObject obj = new JSONObject(resStr);
                        String token = obj.optString("token", "");
                        JSONObject user = obj.optJSONObject("user");
                        String uname = user != null ? user.optString("username", username) : username;

                        if (token == null || token.trim().isEmpty()) {
                            runOnUiThread(() -> {
                                if (tvStatus != null) tvStatus.setText("注册失败：token为空");
                            });
                            return;
                        }

                        SharedPreferences sp = getSharedPreferences(PREFS_NAME, MODE_PRIVATE);
                        sp.edit()
                                .putString(PREF_AUTH_TOKEN, token)
                                .putString(PREF_USERNAME, uname)
                                .apply();

                        runOnUiThread(() -> {
                            Intent it = new Intent(RegisterActivity.this, HomeActivity.class);
                            it.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TASK);
                            startActivity(it);
                            finish();
                        });

                    } catch (Exception e) {
                        runOnUiThread(() -> {
                            if (tvStatus != null) tvStatus.setText("注册失败：解析异常");
                        });
                    }
                }
            });

        } catch (Exception e) {
            if (tvStatus != null) tvStatus.setText("注册失败：构造请求异常");
        }
    }
}
