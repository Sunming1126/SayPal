package com.japaneseengteacher.app;

import android.content.Intent;
import android.graphics.Color;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.text.TextUtils;
import android.util.Log;
import android.view.View;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.appcompat.app.AppCompatActivity;

import com.google.android.material.appbar.MaterialToolbar;
import com.google.android.material.button.MaterialButton;
import com.google.android.material.card.MaterialCardView;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.IOException;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.Locale;
import java.util.concurrent.TimeUnit;

import okhttp3.Call;
import okhttp3.Callback;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.Response;

public class CourseDetailActivity extends AppCompatActivity {

    private static final String TAG = "CourseDetail";

    private final OkHttpClient httpClient = new OkHttpClient.Builder()
            .connectTimeout(15, TimeUnit.SECONDS)
            .readTimeout(30, TimeUnit.SECONDS)
            .build();

    private final Handler mainHandler = new Handler(Looper.getMainLooper());

    private MaterialToolbar topAppBar;
    private MaterialButton btnStart;
    private MaterialButton btnEnglishPractice;

    private TextView tvMeta;
    private TextView tvArticle;
    private LinearLayout vocabContainer;
    private LinearLayout sentenceContainer;

    private String chapterId;
    private String unitId;
    private String topicId;
    private int difficulty = 1;
    private String videoUrl;
    private String topicName;

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_course_detail);

        topAppBar = findViewById(R.id.top_app_bar);
        btnStart = findViewById(R.id.btn_start);
        btnEnglishPractice = findViewById(R.id.btn_english_practice);

        tvMeta = findViewById(R.id.tv_meta);
        tvArticle = findViewById(R.id.tv_article);
        vocabContainer = findViewById(R.id.container_vocab);
        sentenceContainer = findViewById(R.id.container_sentences);

        readIntent();
        setupTopBar();

        if (btnStart != null) {
            btnStart.setOnClickListener(v -> openMainForLearning());
        }

        loadUnitAndRender();
    }

    private void readIntent() {
        try {
            Intent it = getIntent();
            if (it == null) return;
            chapterId = it.getStringExtra("chapter_id");
            unitId = it.getStringExtra("unit_id");
            topicId = it.getStringExtra("topic_id");
            difficulty = it.getIntExtra("difficulty", 1);
            videoUrl = it.getStringExtra("topic_video_url");
            topicName = it.getStringExtra("topic_name");
        } catch (Exception ignored) {
        }
    }

    private void setupTopBar() {
        try {
            if (topAppBar != null) {
                setSupportActionBar(topAppBar);
                if (getSupportActionBar() != null) {
                    getSupportActionBar().setDisplayHomeAsUpEnabled(true);
                }
                topAppBar.setNavigationOnClickListener(v -> finish());
                String title = (topicName != null && !topicName.trim().isEmpty()) ? topicName.trim() : "课程详情";
                topAppBar.setTitle(title);
            }
        } catch (Exception ignored) {
        }
    }

    private void openMainForLearning() {
        try {
            if (TextUtils.isEmpty(unitId) || TextUtils.isEmpty(topicId)) {
                Toast.makeText(this, "缺少课程信息", Toast.LENGTH_SHORT).show();
                return;
            }
            Intent it = new Intent(CourseDetailActivity.this, MainActivity.class);
            it.putExtra("mode", "chapter");
            if (chapterId != null) it.putExtra("chapter_id", chapterId);
            it.putExtra("unit_id", unitId);
            it.putExtra("topic_id", topicId);
            it.putExtra("difficulty", difficulty);
            if (videoUrl != null && !videoUrl.trim().isEmpty()) {
                it.putExtra("topic_video_url", videoUrl);
            }
            startActivity(it);
            finish();
        } catch (Exception ignored) {
        }
    }

    private void loadUnitAndRender() {
        if (TextUtils.isEmpty(unitId)) {
            Toast.makeText(this, "unit_id 为空", Toast.LENGTH_SHORT).show();
            return;
        }

        String url = AIConfigHelper.AGENT_API_BASE_URL + "/training/units/" + unitId;
        Request req = new Request.Builder().url(url).get().build();
        httpClient.newCall(req).enqueue(new Callback() {
            @Override
            public void onFailure(@NonNull Call call, @NonNull IOException e) {
                mainHandler.post(() -> Toast.makeText(CourseDetailActivity.this, "加载课程失败：网络异常", Toast.LENGTH_SHORT).show());
            }

            @Override
            public void onResponse(@NonNull Call call, @NonNull Response response) throws IOException {
                String resStr = response.body() != null ? response.body().string() : "";
                if (!response.isSuccessful()) {
                    mainHandler.post(() -> Toast.makeText(CourseDetailActivity.this, "加载课程失败：http=" + response.code(), Toast.LENGTH_SHORT).show());
                    return;
                }
                try {
                    JSONObject unit = new JSONObject(resStr);
                    JSONObject topic = findTopic(unit, topicId);
                    if (topic == null) {
                        mainHandler.post(() -> Toast.makeText(CourseDetailActivity.this, "找不到 Topic", Toast.LENGTH_SHORT).show());
                        return;
                    }
                    mainHandler.post(() -> {
                        renderTopic(topic);
                        setupEnglishPracticeButton();
                    });
                } catch (Exception e) {
                    Log.e(TAG, "parse unit failed: " + e.getMessage());
                    mainHandler.post(() -> Toast.makeText(CourseDetailActivity.this, "解析课程失败", Toast.LENGTH_SHORT).show());
                }
            }
        });
    }

    private static JSONObject findTopic(JSONObject unit, String topicId) {
        try {
            if (unit == null) return null;
            JSONArray topics = unit.optJSONArray("topics");
            if (topics == null) return null;
            String tid = topicId != null ? topicId.trim() : "";
            for (int i = 0; i < topics.length(); i++) {
                JSONObject t = topics.optJSONObject(i);
                if (t == null) continue;
                String id = t.optString("topic_id", "");
                if (id != null && id.trim().equals(tid)) {
                    return t;
                }
            }
            return null;
        } catch (Exception e) {
            return null;
        }
    }

    private void renderTopic(JSONObject topic) {
        try {
            if (topic == null) return;

            String name = topic.optString("name", "");
            if (topAppBar != null && name != null && !name.trim().isEmpty()) {
                topAppBar.setTitle(name.trim());
            }

            ArrayList<String> requiredVocab = jsonArrayToStrings(topic.optJSONArray("required_vocab"));
            ArrayList<String> requiredSentences = jsonArrayToStrings(topic.optJSONArray("required_sentences"));
            String article = topic.optString("article", "");

            String today = new SimpleDateFormat("yyyy-MM-dd", Locale.US).format(new Date());
            String meta = "日期: " + today
                    + "\nUnit: " + (unitId != null ? unitId : "")
                    + "\nTopic: " + (topicId != null ? topicId : "")
                    + "\n词汇: " + requiredVocab.size() + " 个"
                    + "\n句子: " + requiredSentences.size() + " 句";
            if (tvMeta != null) tvMeta.setText(meta);

            if (tvArticle != null) {
                String a = article != null ? article.trim() : "";
                if (a.isEmpty()) a = "（暂无原文）";
                tvArticle.setText(a);
            }

            renderList(vocabContainer, requiredVocab, "（暂无词汇）");
            renderList(sentenceContainer, requiredSentences, "（暂无句子）");

        } catch (Exception ignored) {
        }
    }

    private void setupEnglishPracticeButton() {
        if (btnEnglishPractice == null) return;
        btnEnglishPractice.setOnClickListener(v -> {
            if (TextUtils.isEmpty(unitId) || TextUtils.isEmpty(topicId)) {
                Toast.makeText(this, "缺少课程信息", Toast.LENGTH_SHORT).show();
                return;
            }
            Intent it = new Intent(CourseDetailActivity.this, EnglishPracticeActivity.class);
            it.putExtra(EnglishPracticeActivity.EXTRA_UNIT_ID, unitId);
            it.putExtra(EnglishPracticeActivity.EXTRA_TOPIC_ID, topicId);
            startActivity(it);
        });
    }

    private static ArrayList<String> jsonArrayToStrings(JSONArray arr) {
        ArrayList<String> out = new ArrayList<>();
        if (arr == null) return out;
        for (int i = 0; i < arr.length(); i++) {
            String s = arr.optString(i, "");
            if (s == null) continue;
            s = s.trim();
            if (s.isEmpty()) continue;
            out.add(s);
        }
        return out;
    }

    private void renderList(LinearLayout container, ArrayList<String> items, String emptyText) {
        if (container == null) return;
        container.removeAllViews();
        try {
            if (items == null || items.isEmpty()) {
                TextView tv = new TextView(this);
                tv.setTextColor(Color.parseColor("#64748B"));
                tv.setTextSize(14f);
                tv.setText(emptyText);
                container.addView(tv);
                return;
            }

            float d = getResources().getDisplayMetrics().density;
            for (int i = 0; i < items.size(); i++) {
                String s = items.get(i);
                if (s == null) s = "";

                MaterialCardView card = new MaterialCardView(this);
                card.setCardBackgroundColor(Color.parseColor("#FFFFFF"));
                card.setStrokeColor(Color.parseColor("#E5E7EB"));
                card.setStrokeWidth((int) (d * 1));
                card.setRadius(d * 12);
                card.setCardElevation(d * 1.2f);

                LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(
                        LinearLayout.LayoutParams.MATCH_PARENT,
                        LinearLayout.LayoutParams.WRAP_CONTENT
                );
                lp.topMargin = (int) (d * 8);
                card.setLayoutParams(lp);

                TextView tv = new TextView(this);
                tv.setTextColor(Color.parseColor("#0F172A"));
                tv.setTextSize(15f);
                tv.setPadding((int) (d * 14), (int) (d * 12), (int) (d * 14), (int) (d * 12));
                tv.setText((i + 1) + ".  " + s);

                card.addView(tv);
                container.addView(card);
            }
        } catch (Exception ignored) {
        }
    }
}
