package com.japaneseengteacher.app;

import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.widget.TextView;

import androidx.annotation.Nullable;
import androidx.appcompat.app.AppCompatActivity;

import com.google.android.material.button.MaterialButton;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.IOException;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.TimeUnit;

import okhttp3.Call;
import okhttp3.Callback;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.Response;

public class HomeActivity extends AppCompatActivity {

    private static final String PREFS_NAME = "ai_prefs";
    private static final String PREF_USERNAME = "username";

    private final OkHttpClient httpClient = new OkHttpClient.Builder()
            .connectTimeout(15, TimeUnit.SECONDS)
            .readTimeout(30, TimeUnit.SECONDS)
            .build();

    private final Handler mainHandler = new Handler(Looper.getMainLooper());

    private TextView tvProgress;

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_home);

        tvProgress = findViewById(R.id.tv_progress);

        MaterialButton btnMainline = findViewById(R.id.btn_mainline);
        if (btnMainline != null) {
            btnMainline.setOnClickListener(v -> {
                Intent it = new Intent(HomeActivity.this, MainActivity.class);
                it.putExtra("mode", "mainline");
                startActivity(it);
            });
        }

        MaterialButton btnChapter = findViewById(R.id.btn_chapter);
        if (btnChapter != null) {
            btnChapter.setOnClickListener(v -> {
                Intent it = new Intent(HomeActivity.this, TrainingSelectActivity.class);
                startActivity(it);
            });
        }

        MaterialButton btnHistory = findViewById(R.id.btn_history);
        if (btnHistory != null) {
            btnHistory.setOnClickListener(v -> {
                Intent it = new Intent(HomeActivity.this, HistoryActivity.class);
                startActivity(it);
            });
        }

        MaterialButton btnProfile = findViewById(R.id.btn_profile);
        if (btnProfile != null) {
            btnProfile.setOnClickListener(v -> {
                Intent it = new Intent(HomeActivity.this, ProfileActivity.class);
                startActivity(it);
            });
        }
    }

    @Override
    protected void onResume() {
        super.onResume();
        refreshMainlineProgress();
    }

    private void refreshMainlineProgress() {
        SharedPreferences sp = getSharedPreferences(PREFS_NAME, MODE_PRIVATE);
        String u = sp.getString(PREF_USERNAME, null);
        String username = u != null ? u.trim() : "";
        if (username.isEmpty()) {
            if (tvProgress != null) tvProgress.setText("");
            return;
        }

        String url = AIConfigHelper.AGENT_API_BASE_URL + "/users/" + username + "/bootstrap";
        Request req = new Request.Builder().url(url).get().build();
        httpClient.newCall(req).enqueue(new Callback() {
            @Override
            public void onFailure(Call call, IOException e) {
                mainHandler.post(() -> {
                    if (tvProgress != null) tvProgress.setText("进度加载失败");
                });
            }

            @Override
            public void onResponse(Call call, Response response) throws IOException {
                String resStr = response.body() != null ? response.body().string() : "";
                if (!response.isSuccessful()) {
                    mainHandler.post(() -> {
                        if (tvProgress != null) tvProgress.setText("进度加载失败");
                    });
                    return;
                }

                try {
                    JSONObject obj = new JSONObject(resStr);
                    JSONObject profile = obj.optJSONObject("profile");
                    if (profile == null) {
                        mainHandler.post(() -> {
                            if (tvProgress != null) tvProgress.setText("当前未开始主线训练");
                        });
                        return;
                    }

                    String unitId = profile.optString("current_unit_id", "").trim();
                    String topicId = profile.optString("current_topic_id", "").trim();
                    if (unitId.isEmpty() || topicId.isEmpty()) {
                        mainHandler.post(() -> {
                            if (tvProgress != null) tvProgress.setText("当前未开始主线训练");
                        });
                        return;
                    }

                    resolveChapterAndUnitIndex(unitId, (chapterLabel, unitLabel) -> {
                        resolveTopicIndex(unitId, topicId, (topicLabel) -> {
                            String line = chapterLabel + " · " + unitLabel + "\n" + topicLabel;
                            mainHandler.post(() -> {
                                if (tvProgress != null) tvProgress.setText(line);
                            });
                        });
                    });
                } catch (Exception e) {
                    mainHandler.post(() -> {
                        if (tvProgress != null) tvProgress.setText("进度加载失败");
                    });
                }
            }
        });
    }

    private interface TwoStringCallback {
        void onResult(String a, String b);
    }

    private interface OneStringCallback {
        void onResult(String a);
    }

    private void resolveChapterAndUnitIndex(String unitId, TwoStringCallback cb) {
        String url = AIConfigHelper.AGENT_API_BASE_URL + "/training/chapters";
        Request req = new Request.Builder().url(url).get().build();
        httpClient.newCall(req).enqueue(new Callback() {
            @Override
            public void onFailure(Call call, IOException e) {
                cb.onResult("Chapter ?", unitId);
            }

            @Override
            public void onResponse(Call call, Response response) throws IOException {
                String resStr = response.body() != null ? response.body().string() : "";
                if (!response.isSuccessful()) {
                    cb.onResult("Chapter ?", unitId);
                    return;
                }
                try {
                    JSONObject obj = new JSONObject(resStr);
                    JSONArray items = obj.optJSONArray("items");
                    List<JSONObject> chapters = new ArrayList<>();
                    if (items != null) {
                        for (int i = 0; i < items.length(); i++) {
                            JSONObject it = items.optJSONObject(i);
                            if (it != null) chapters.add(it);
                        }
                    }
                    resolveUnitInChapters(unitId, chapters, 0, cb);
                } catch (Exception e) {
                    cb.onResult("Chapter ?", unitId);
                }
            }
        });
    }

    private void resolveUnitInChapters(String unitId, List<JSONObject> chapters, int idx, TwoStringCallback cb) {
        if (chapters == null || idx >= chapters.size()) {
            cb.onResult("Chapter ?", unitId);
            return;
        }
        JSONObject ch = chapters.get(idx);
        String chapterId = ch != null ? ch.optString("chapter_id", "").trim() : "";
        String chapterName = ch != null ? ch.optString("name", chapterId).trim() : chapterId;
        if (chapterId.isEmpty()) {
            resolveUnitInChapters(unitId, chapters, idx + 1, cb);
            return;
        }

        String url = AIConfigHelper.AGENT_API_BASE_URL + "/training/chapters/" + chapterId + "/units";
        Request req = new Request.Builder().url(url).get().build();
        httpClient.newCall(req).enqueue(new Callback() {
            @Override
            public void onFailure(Call call, IOException e) {
                resolveUnitInChapters(unitId, chapters, idx + 1, cb);
            }

            @Override
            public void onResponse(Call call, Response response) throws IOException {
                String resStr = response.body() != null ? response.body().string() : "";
                if (!response.isSuccessful()) {
                    resolveUnitInChapters(unitId, chapters, idx + 1, cb);
                    return;
                }
                try {
                    JSONObject obj = new JSONObject(resStr);
                    JSONArray items = obj.optJSONArray("items");
                    if (items != null) {
                        for (int i = 0; i < items.length(); i++) {
                            JSONObject it = items.optJSONObject(i);
                            if (it == null) continue;
                            String uid = it.optString("unit_id", "").trim();
                            if (!uid.equals(unitId)) continue;
                            String unitName = it.optString("name", unitId).trim();
                            String chapterLabel = "第" + (idx + 1) + "章";
                            if (chapterName != null && !chapterName.trim().isEmpty()) {
                                chapterLabel = chapterLabel + "（" + chapterName.trim() + "）";
                            }
                            String unitLabel = "第" + (i + 1) + "单元";
                            if (unitName != null && !unitName.trim().isEmpty()) {
                                unitLabel = unitLabel + "（" + unitName.trim() + "）";
                            }
                            cb.onResult(chapterLabel, unitLabel);
                            return;
                        }
                    }
                } catch (Exception ignored) {
                }
                resolveUnitInChapters(unitId, chapters, idx + 1, cb);
            }
        });
    }

    private void resolveTopicIndex(String unitId, String topicId, OneStringCallback cb) {
        String url = AIConfigHelper.AGENT_API_BASE_URL + "/training/units/" + unitId;
        Request req = new Request.Builder().url(url).get().build();
        httpClient.newCall(req).enqueue(new Callback() {
            @Override
            public void onFailure(Call call, IOException e) {
                cb.onResult(topicId);
            }

            @Override
            public void onResponse(Call call, Response response) throws IOException {
                String resStr = response.body() != null ? response.body().string() : "";
                if (!response.isSuccessful()) {
                    cb.onResult(topicId);
                    return;
                }

                try {
                    JSONObject obj = new JSONObject(resStr);
                    JSONArray topics = obj.optJSONArray("topics");
                    if (topics != null) {
                        for (int i = 0; i < topics.length(); i++) {
                            JSONObject it = topics.optJSONObject(i);
                            if (it == null) continue;
                            String tid = it.optString("topic_id", "").trim();
                            if (!tid.equals(topicId)) continue;
                            String tname = it.optString("name", topicId).trim();
                            cb.onResult("话题" + (i + 1) + "：" + tname);
                            return;
                        }
                    }
                } catch (Exception ignored) {
                }
                cb.onResult(topicId);
            }
        });
    }
}
