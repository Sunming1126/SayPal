package com.japaneseengteacher.app;

import android.app.AlertDialog;
import android.content.SharedPreferences;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.view.LayoutInflater;
import android.view.View;
import android.widget.BaseAdapter;
import android.widget.ListView;
import android.widget.TextView;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.appcompat.app.AppCompatActivity;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.IOException;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.Locale;
import java.util.concurrent.TimeUnit;

import okhttp3.Call;
import okhttp3.Callback;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.Response;

import com.google.android.material.button.MaterialButton;

public class HistoryActivity extends AppCompatActivity {

    private static final String PREFS_NAME = "ai_prefs";
    private static final String PREF_USERNAME = "username";

    private static final String PREF_HISTORY_ITEMS = "history_items_v1";
    private static final String PREF_HISTORY_BY_JOB = "history_by_job_v1";
    private static final String PREF_HISTORY_LEGACY_OWNER = "history_legacy_owner_v1";
    private static final int HISTORY_LOCAL_MAX = 200;

    private final OkHttpClient httpClient = new OkHttpClient.Builder()
            .connectTimeout(15, TimeUnit.SECONDS)
            .readTimeout(30, TimeUnit.SECONDS)
            .build();

    private final Handler mainHandler = new Handler(Looper.getMainLooper());

    private TextView tvTitle;
    private ListView listView;
    private MaterialButton btnSync;
    private MaterialButton btnBack;

    private HistoryRowAdapter adapter;
    private final ArrayList<JSONObject> displayItems = new ArrayList<>();
    private final ArrayList<String> jobIds = new ArrayList<>();

    private TextView tvHeaderTopic;
    private boolean showTopicColumn = true;

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_history);

        tvTitle = findViewById(R.id.tv_title);
        listView = findViewById(R.id.list_history);
        btnSync = findViewById(R.id.btn_sync_history);
        btnBack = findViewById(R.id.btn_back);
        tvHeaderTopic = findViewById(R.id.tv_header_topic);

        if (tvTitle != null) {
            tvTitle.setText("历史记录");
        }

        adapter = new HistoryRowAdapter();
        if (listView != null) {
            listView.setAdapter(adapter);
            listView.setOnItemClickListener((parent, view, position, id) -> {
                if (position < 0 || position >= jobIds.size()) return;
                String jid = jobIds.get(position);
                openHistoryItem(jid);
            });
        }

        if (btnSync != null) {
            btnSync.setOnClickListener(v -> syncFromCloud());
        }
        if (btnBack != null) {
            btnBack.setOnClickListener(v -> finish());
        }

        refreshFromLocal();
    }

    private SharedPreferences sp() {
        return getSharedPreferences(PREFS_NAME, MODE_PRIVATE);
    }

    private String currentUsername() {
        try {
            String u = sp().getString(PREF_USERNAME, null);
            if (u == null) return "";
            u = u.trim();
            return u;
        } catch (Exception e) {
            return "";
        }
    }

    private String itemsKey() {
        String u = currentUsername();
        if (u == null || u.trim().isEmpty()) return PREF_HISTORY_ITEMS;
        return PREF_HISTORY_ITEMS + ":" + u.trim();
    }

    private String byJobKey() {
        String u = currentUsername();
        if (u == null || u.trim().isEmpty()) return PREF_HISTORY_BY_JOB;
        return PREF_HISTORY_BY_JOB + ":" + u.trim();
    }

    private String getUserIdForCloud() {
        try {
            String u = sp().getString(PREF_USERNAME, null);
            if (u == null) return null;
            u = u.trim();
            return u.isEmpty() ? null : u;
        } catch (Exception e) {
            return null;
        }
    }

    private JSONArray loadLocalItems() {
        try {
            String s = sp().getString(itemsKey(), null);
            if (s != null && !s.trim().isEmpty()) {
                return new JSONArray(s);
            }

            String owner = sp().getString(PREF_HISTORY_LEGACY_OWNER, null);
            String cur = currentUsername();
            if (owner != null && cur != null && !cur.trim().isEmpty() && !owner.trim().equalsIgnoreCase(cur.trim())) {
                return new JSONArray();
            }

            String legacy = sp().getString(PREF_HISTORY_ITEMS, null);
            if (legacy == null || legacy.trim().isEmpty()) return new JSONArray();
            JSONArray legacyArr = new JSONArray(legacy);

            JSONArray filtered = new JSONArray();
            boolean hadAnyUserField = false;
            for (int i = 0; i < legacyArr.length(); i++) {
                JSONObject it = legacyArr.optJSONObject(i);
                if (it == null) continue;
                String uid = it.optString("user_id", "");
                if (uid != null && !uid.trim().isEmpty()) {
                    hadAnyUserField = true;
                    if (cur != null && !cur.trim().isEmpty() && !cur.trim().equalsIgnoreCase(uid.trim())) {
                        continue;
                    }
                }
                filtered.put(it);
            }

            JSONArray out = hadAnyUserField ? filtered : legacyArr;
            if (cur != null && !cur.trim().isEmpty()) {
                sp().edit().putString(itemsKey(), out.toString()).putString(PREF_HISTORY_LEGACY_OWNER, cur.trim()).apply();
            }
            return out;
        } catch (Exception e) {
            return new JSONArray();
        }
    }

    private JSONObject loadLocalByJob() {
        try {
            String s = sp().getString(byJobKey(), null);
            if (s != null && !s.trim().isEmpty()) {
                return new JSONObject(s);
            }

            String owner = sp().getString(PREF_HISTORY_LEGACY_OWNER, null);
            String cur = currentUsername();
            if (owner != null && cur != null && !cur.trim().isEmpty() && !owner.trim().equalsIgnoreCase(cur.trim())) {
                return new JSONObject();
            }

            String legacy = sp().getString(PREF_HISTORY_BY_JOB, null);
            if (legacy == null || legacy.trim().isEmpty()) return new JSONObject();
            JSONObject legacyObj = new JSONObject(legacy);

            JSONObject filtered = new JSONObject();
            JSONArray items = loadLocalItems();
            for (int i = 0; i < items.length(); i++) {
                JSONObject it = items.optJSONObject(i);
                if (it == null) continue;
                String jid = it.optString("job_id", "");
                if (jid == null || jid.trim().isEmpty()) continue;
                Object v = legacyObj.opt(jid);
                if (v != null) {
                    filtered.put(jid, v);
                }
            }

            if (cur != null && !cur.trim().isEmpty()) {
                sp().edit().putString(byJobKey(), filtered.toString()).putString(PREF_HISTORY_LEGACY_OWNER, cur.trim()).apply();
            }
            return filtered;
        } catch (Exception e) {
            return new JSONObject();
        }
    }

    private void saveLocal(JSONArray items, JSONObject byJob) {
        sp().edit()
                .putString(itemsKey(), items.toString())
                .putString(byJobKey(), byJob.toString())
                .apply();
    }

    private static String shortDate(String iso) {
        if (iso == null) return "";
        String s = iso.trim();
        if (s.length() >= 10) {
            return s.substring(0, 10);
        }
        return s;
    }

    private static boolean isNullish(String v) {
        if (v == null) return true;
        String t = v.trim();
        if (t.isEmpty()) return true;
        return "null".equalsIgnoreCase(t);
    }

    private static String safeOptString(JSONObject obj, String key) {
        if (obj == null) return "";
        String v = obj.optString(key, "");
        return isNullish(v) ? "" : v;
    }

    private static String normalizeIdPart(String s) {
        if (isNullish(s)) return "";
        String t = s.trim();
        try {
            String digits = t.replaceAll("[^0-9]", "");
            if (!digits.isEmpty()) {
                int v = Integer.parseInt(digits);
                return String.valueOf(v);
            }
        } catch (Exception ignored) {
        }
        return t;
    }

    private static String inferTopicLabel(JSONObject summary) {
        if (summary == null) return "";
        String mode = summary.optString("mode", "");
        if (isNullish(mode)) mode = "";

        String chapterId = safeOptString(summary, "chapter_id");
        String unitId = safeOptString(summary, "unit_id");
        String topicId = safeOptString(summary, "topic_id");

        boolean hasAny = false;
        if (!isNullish(chapterId)) hasAny = true;
        if (!isNullish(unitId)) hasAny = true;
        if (!isNullish(topicId)) hasAny = true;

        if (!hasAny) {
            if ("mainline".equalsIgnoreCase(mode) || isNullish(mode)) {
                return "主线训练";
            }
            return "";
        }

        String c = normalizeIdPart(chapterId);
        String u = normalizeIdPart(unitId);
        String t = normalizeIdPart(topicId);

        if (!c.isEmpty() && !u.isEmpty() && !t.isEmpty()) return c + "-" + u + "-" + t;
        if (!u.isEmpty() && !t.isEmpty()) return u + "-" + t;
        if (!u.isEmpty()) return u;
        if (!t.isEmpty()) return t;

        return "";
    }

    private static double avgScore(JSONObject analysis) {
        if (analysis == null) return -1;
        JSONObject scores = analysis.optJSONObject("scores");
        if (scores == null) return -1;
        return scores.optDouble("overall_score", -1);
    }

    private void refreshFromLocal() {
        JSONArray items = loadLocalItems();

        displayItems.clear();
        jobIds.clear();

        ArrayList<JSONObject> list = new ArrayList<>();
        String curUser = currentUsername();
        for (int i = 0; i < items.length(); i++) {
            JSONObject it = items.optJSONObject(i);
            if (it == null) continue;
            String uid = it.optString("user_id", "");
            if (uid != null && !uid.trim().isEmpty() && curUser != null && !curUser.trim().isEmpty()) {
                if (!curUser.trim().equalsIgnoreCase(uid.trim())) {
                    continue;
                }
            }
            list.add(it);
        }
        list.sort((a, b) -> String.valueOf(b.optString("created_at", "")).compareTo(String.valueOf(a.optString("created_at", ""))));

        boolean anyTopicInfo = false;
        for (JSONObject it : list) {
            String mode = it.optString("mode", "");
            String unitId = safeOptString(it, "unit_id");
            String topicId = safeOptString(it, "topic_id");
            String chapterId = safeOptString(it, "chapter_id");
            if (!isNullish(mode) || !isNullish(unitId) || !isNullish(topicId) || !isNullish(chapterId)) {
                anyTopicInfo = true;
                break;
            }
        }
        showTopicColumn = anyTopicInfo;

        for (JSONObject it : list) {
            displayItems.add(it);
            jobIds.add(it.optString("job_id", ""));
        }

        runOnUiThread(() -> {
            if (tvHeaderTopic != null) {
                tvHeaderTopic.setVisibility(showTopicColumn ? View.VISIBLE : View.GONE);
            }
            if (adapter != null) adapter.notifyDataSetChanged();
        });
    }

    private class HistoryRowAdapter extends BaseAdapter {
        @Override
        public int getCount() {
            return displayItems.size();
        }

        @Override
        public Object getItem(int position) {
            if (position < 0 || position >= displayItems.size()) return null;
            return displayItems.get(position);
        }

        @Override
        public long getItemId(int position) {
            return position;
        }

        @Override
        public View getView(int position, View convertView, android.view.ViewGroup parent) {
            View v = convertView;
            if (v == null) {
                v = LayoutInflater.from(HistoryActivity.this).inflate(R.layout.item_history_row, parent, false);
            }

            TextView tvDate = v.findViewById(R.id.tv_col_date);
            TextView tvTopic = v.findViewById(R.id.tv_col_topic);
            TextView tvAvg = v.findViewById(R.id.tv_col_avg);

            JSONObject it = null;
            if (position >= 0 && position < displayItems.size()) {
                it = displayItems.get(position);
            }

            String createdAt = it != null ? it.optString("created_at", "") : "";
            String dateText = shortDate(createdAt);
            if (tvDate != null) tvDate.setText(dateText);

            String topicText = inferTopicLabel(it);
            if (tvTopic != null) {
                tvTopic.setVisibility(showTopicColumn ? View.VISIBLE : View.GONE);
                if (showTopicColumn) {
                    if (topicText == null || topicText.trim().isEmpty()) topicText = "-";
                    tvTopic.setText(topicText);
                }
            }

            double avg = it != null ? it.optDouble("avg_score", -1) : -1;
            String avgText = (avg >= 0 ? String.format(Locale.US, "%.1f", avg) : "-");
            if (tvAvg != null) tvAvg.setText(avgText);

            return v;
        }
    }

    private void openHistoryItem(String jobId) {
        if (jobId == null || jobId.trim().isEmpty()) return;
        try {
            JSONObject byJob = loadLocalByJob();
            JSONObject cached = byJob.optJSONObject(jobId);
            if (cached != null) {
                JSONObject analysis = cached.optJSONObject("analysis");
                if (analysis != null) {
                    showCompactAnalysisDialog(analysis);
                    return;
                }
            }
        } catch (Exception ignored) {
        }

        pollJobUntilReady(jobId, 0);
    }

    private void pollJobUntilReady(String jobId, int attempt) {
        final int maxAttempts = 120;
        final long intervalMs = 1000;
        if (attempt > maxAttempts) {
            runOnUiThread(() -> Toast.makeText(HistoryActivity.this, "查询超时：未拿到结果", Toast.LENGTH_LONG).show());
            return;
        }

        String url = AIConfigHelper.AGENT_API_BASE_URL + "/analysis_jobs/" + jobId + "?include_result=1";
        Request req = new Request.Builder().url(url).get().build();
        httpClient.newCall(req).enqueue(new Callback() {
            @Override
            public void onFailure(@NonNull Call call, @NonNull IOException e) {
                mainHandler.postDelayed(() -> pollJobUntilReady(jobId, attempt + 1), intervalMs);
            }

            @Override
            public void onResponse(@NonNull Call call, @NonNull Response response) throws IOException {
                String resStr = response.body() != null ? response.body().string() : "";
                if (!response.isSuccessful()) {
                    mainHandler.postDelayed(() -> pollJobUntilReady(jobId, attempt + 1), intervalMs);
                    return;
                }

                try {
                    JSONObject obj = new JSONObject(resStr);
                    String status = obj.optString("status", "");
                    if ("succeeded".equalsIgnoreCase(status)) {
                        JSONObject result = obj.optJSONObject("result");
                        JSONObject analysis = result != null ? result.optJSONObject("analysis") : null;
                        if (analysis == null) {
                            runOnUiThread(() -> Toast.makeText(HistoryActivity.this, "分析为空", Toast.LENGTH_LONG).show());
                            return;
                        }

                        try {
                            persistCloudItemToLocal(obj);
                            refreshFromLocal();
                        } catch (Exception ignored) {
                        }

                        showCompactAnalysisDialog(analysis);
                        return;
                    }
                    if ("failed".equalsIgnoreCase(status)) {
                        String err = obj.optString("error", "analysis_failed");
                        runOnUiThread(() -> Toast.makeText(HistoryActivity.this, "分析失败：" + err, Toast.LENGTH_LONG).show());
                        return;
                    }

                    mainHandler.postDelayed(() -> pollJobUntilReady(jobId, attempt + 1), intervalMs);
                } catch (Exception e) {
                    mainHandler.postDelayed(() -> pollJobUntilReady(jobId, attempt + 1), intervalMs);
                }
            }
        });
    }

    private void persistCloudItemToLocal(JSONObject jobObj) {
        if (jobObj == null) return;
        String jobId = jobObj.optString("job_id", "");
        if (jobId == null || jobId.trim().isEmpty()) return;

        JSONObject result = jobObj.optJSONObject("result");
        JSONObject analysis = result != null ? result.optJSONObject("analysis") : null;

        try {
            JSONObject summary = new JSONObject();
            summary.put("user_id", currentUsername());
            summary.put("job_id", jobId);
            summary.put("created_at", jobObj.optString("created_at", jobObj.optString("started_at", "")));
            summary.put("status", jobObj.optString("status", ""));
            summary.put("task_id", jobObj.optString("task_id", ""));
            summary.put("chapter_id", safeOptString(jobObj, "chapter_id"));
            summary.put("topic_id", safeOptString(jobObj, "topic_id"));
            summary.put("unit_id", safeOptString(jobObj, "unit_id"));
            summary.put("difficulty", jobObj.optInt("difficulty", -1));
            summary.put("mode", jobObj.optString("mode", ""));
            summary.put("avg_score", avgScore(analysis));

            JSONArray items = loadLocalItems();
            JSONObject byJob = loadLocalByJob();

            boolean found = false;
            for (int i = 0; i < items.length(); i++) {
                JSONObject it = items.optJSONObject(i);
                if (it == null) continue;
                if (jobId.equals(it.optString("job_id", ""))) {
                    items.put(i, summary);
                    found = true;
                    break;
                }
            }
            if (!found) {
                JSONArray newItems = new JSONArray();
                newItems.put(summary);
                for (int i = 0; i < items.length(); i++) {
                    newItems.put(items.opt(i));
                    if (newItems.length() >= HISTORY_LOCAL_MAX) break;
                }
                items = newItems;
            }

            if (result != null) {
                byJob.put(jobId, result);
            }

            saveLocal(items, byJob);
        } catch (Exception ignored) {
        }
    }

    private void syncFromCloud() {
        String userId = getUserIdForCloud();
        if (userId == null || userId.trim().isEmpty()) {
            Toast.makeText(this, "未找到 user_id，无法同步云端", Toast.LENGTH_SHORT).show();
            return;
        }
        Toast.makeText(this, "正在同步云端...", Toast.LENGTH_SHORT).show();

        String url = AIConfigHelper.AGENT_API_BASE_URL + "/users/" + userId + "/tasks?limit=100&offset=0&include_result=1";
        Request req = new Request.Builder().url(url).get().build();
        httpClient.newCall(req).enqueue(new Callback() {
            @Override
            public void onFailure(@NonNull Call call, @NonNull IOException e) {
                mainHandler.post(() -> Toast.makeText(HistoryActivity.this, "同步失败：网络异常", Toast.LENGTH_LONG).show());
            }

            @Override
            public void onResponse(@NonNull Call call, @NonNull Response response) throws IOException {
                String resStr = response.body() != null ? response.body().string() : "";
                if (!response.isSuccessful()) {
                    mainHandler.post(() -> Toast.makeText(HistoryActivity.this, "同步失败：http=" + response.code(), Toast.LENGTH_LONG).show());
                    return;
                }

                try {
                    JSONObject obj = new JSONObject(resStr);
                    JSONArray items = obj.optJSONArray("items");
                    if (items == null) items = new JSONArray();

                    JSONArray localItems = loadLocalItems();
                    JSONObject localByJob = loadLocalByJob();

                    LinkedHashMap<String, JSONObject> mergedSummary = new LinkedHashMap<>();
                    for (int i = 0; i < localItems.length(); i++) {
                        JSONObject it = localItems.optJSONObject(i);
                        if (it == null) continue;
                        String jid = it.optString("job_id", "");
                        if (jid != null && !jid.isEmpty()) mergedSummary.put(jid, it);
                    }

                    for (int i = 0; i < items.length(); i++) {
                        JSONObject it = items.optJSONObject(i);
                        if (it == null) continue;
                        String jid = it.optString("job_id", "");
                        if (jid == null || jid.isEmpty()) continue;

                        JSONObject result = it.optJSONObject("result");
                        JSONObject analysis = result != null ? result.optJSONObject("analysis") : null;

                        JSONObject summary = new JSONObject();
                        summary.put("user_id", currentUsername());
                        summary.put("job_id", jid);
                        summary.put("created_at", it.optString("created_at", ""));
                        summary.put("status", it.optString("status", ""));
                        summary.put("task_id", it.optString("task_id", ""));
                        summary.put("chapter_id", safeOptString(it, "chapter_id"));
                        summary.put("topic_id", safeOptString(it, "topic_id"));
                        summary.put("unit_id", safeOptString(it, "unit_id"));
                        summary.put("difficulty", it.optInt("difficulty", -1));
                        summary.put("mode", it.optString("mode", ""));
                        summary.put("avg_score", avgScore(analysis));

                        mergedSummary.put(jid, summary);
                        if (result != null) {
                            localByJob.put(jid, result);
                        }
                    }

                    ArrayList<JSONObject> mergedList = new ArrayList<>(mergedSummary.values());
                    mergedList.sort((a, b) -> String.valueOf(b.optString("created_at", "")).compareTo(String.valueOf(a.optString("created_at", ""))));

                    JSONArray out = new JSONArray();
                    for (int i = 0; i < mergedList.size() && i < HISTORY_LOCAL_MAX; i++) {
                        out.put(mergedList.get(i));
                    }

                    saveLocal(out, localByJob);
                    mainHandler.post(() -> {
                        refreshFromLocal();
                        Toast.makeText(HistoryActivity.this, "同步完成", Toast.LENGTH_SHORT).show();
                    });
                } catch (Exception e) {
                    mainHandler.post(() -> Toast.makeText(HistoryActivity.this, "同步解析失败", Toast.LENGTH_LONG).show());
                }
            }
        });
    }

    private void showCompactAnalysisDialog(JSONObject compact) {
        runOnUiThread(() -> {
            try {
                JSONObject scores = compact.optJSONObject("scores");
                JSONObject dim = scores != null ? scores.optJSONObject("dimension_scores") : null;
                JSONObject feedback = compact.optJSONObject("feedback");
                JSONArray evidence = feedback != null ? feedback.optJSONArray("evidence") : null;

                StringBuilder sb = new StringBuilder();
                if (scores != null) {
                    sb.append("总分: ").append(scores.optInt("overall_score", -1)).append("\n");
                    sb.append("难度等级: ").append(scores.optInt("difficulty_level", -1)).append("\n\n");
                }
                if (dim != null) {
                    sb.append("语法: ").append(dim.optInt("grammar_score", -1)).append("\n");
                    sb.append("词汇: ").append(dim.optInt("vocabulary_score", -1)).append("\n");
                    sb.append("流利度: ").append(dim.optInt("fluency_score", -1)).append("\n");
                    sb.append("理解: ").append(dim.optInt("comprehension_score", -1)).append("\n");
                    sb.append("任务完成: ").append(dim.optInt("task_completion_score", -1)).append("\n\n");
                }

                if (evidence != null && evidence.length() > 0) {
                    sb.append("证据(原句):\n");
                    for (int i = 0; i < Math.min(5, evidence.length()); i++) {
                        JSONObject it = evidence.optJSONObject(i);
                        if (it == null) continue;
                        sb.append("- [").append(it.optString("dimension", "")).append("] ");
                        sb.append(it.optString("quote", "")).append("\n");
                    }
                }

                if (sb.toString().trim().isEmpty()) {
                    sb.append("无可展示的分析字段");
                }

                new AlertDialog.Builder(HistoryActivity.this)
                        .setTitle("分析")
                        .setMessage(sb.toString())
                        .setPositiveButton("OK", null)
                        .show();
            } catch (Exception e) {
                Toast.makeText(HistoryActivity.this, "展示失败", Toast.LENGTH_SHORT).show();
            }
        });
    }
}
