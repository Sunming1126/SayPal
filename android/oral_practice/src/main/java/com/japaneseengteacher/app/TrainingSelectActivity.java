package com.japaneseengteacher.app;

import android.content.Intent;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.text.SpannableString;
import android.text.Spanned;
import android.text.style.ForegroundColorSpan;
import android.text.style.RelativeSizeSpan;
import android.text.style.StyleSpan;
import android.widget.ArrayAdapter;
import android.widget.ListView;
import android.widget.TextView;
import android.widget.Toast;
import android.view.LayoutInflater;
import android.view.View;
import android.graphics.Typeface;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.appcompat.app.AppCompatActivity;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.IOException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.concurrent.TimeUnit;

import okhttp3.Call;
import okhttp3.Callback;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.Response;

import com.google.android.material.button.MaterialButton;
import com.google.android.material.button.MaterialButtonToggleGroup;
import com.google.android.material.dialog.MaterialAlertDialogBuilder;

public class TrainingSelectActivity extends AppCompatActivity {

    private enum Stage { CHAPTER, TOPIC }

    private final OkHttpClient httpClient = new OkHttpClient.Builder()
            .connectTimeout(15, TimeUnit.SECONDS)
            .readTimeout(30, TimeUnit.SECONDS)
            .build();

    private final Handler mainHandler = new Handler(Looper.getMainLooper());

    private TextView tvBreadcrumb;
    private TextView tvHint;
    private ListView listView;
    private MaterialButton btnBack;
    private MaterialButtonToggleGroup tgDifficulty;
    private MaterialButton btnDiffAll;
    private MaterialButton btnDiff1;
    private MaterialButton btnDiff2;
    private MaterialButton btnDiff3;

    private Stage stage = Stage.CHAPTER;

    private boolean skipChapterFlow = false;

    private String selectedChapterId = null;
    private String selectedChapterName = null;

    private Integer selectedDifficultyFilter = null;

    private static final int DEFAULT_TOPIC_LIMIT = 200;

    private final List<HashMap<String, Object>> currentItems = new ArrayList<>();

    private ArrayAdapter<String> listAdapter;
    private final List<String> listLabels = new ArrayList<>();

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_training_select);

        try {
            Intent it = getIntent();
            if (it != null) {
                skipChapterFlow = it.getBooleanExtra("skip_chapter", false);
            }
        } catch (Exception ignored) {
        }

        tvBreadcrumb = findViewById(R.id.tv_breadcrumb);
        tvHint = findViewById(R.id.tv_hint);
        listView = findViewById(R.id.list_items);
        btnBack = findViewById(R.id.btn_back);

        tgDifficulty = findViewById(R.id.tg_difficulty);
        btnDiffAll = findViewById(R.id.btn_diff_all);
        btnDiff1 = findViewById(R.id.btn_diff_1);
        btnDiff2 = findViewById(R.id.btn_diff_2);
        btnDiff3 = findViewById(R.id.btn_diff_3);

        if (tgDifficulty != null) {
            tgDifficulty.addOnButtonCheckedListener((group, checkedId, isChecked) -> {
                if (!isChecked) return;
                Integer diff = null;
                if (checkedId == R.id.btn_diff_1) diff = 1;
                else if (checkedId == R.id.btn_diff_2) diff = 2;
                else if (checkedId == R.id.btn_diff_3) diff = 3;
                selectedDifficultyFilter = diff;
                if (stage == Stage.TOPIC) {
                    loadTopicsByChapter(selectedChapterId, selectedDifficultyFilter, DEFAULT_TOPIC_LIMIT);
                }
            });
        }

        if (btnBack != null) {
            btnBack.setOnClickListener(v -> {
                if (stage == Stage.CHAPTER) {
                    finish();
                } else {
                    goBackOneLevel();
                }
            });
        }

        if (listView != null) {
            listView.setOnItemClickListener((parent, view, position, id) -> onItemSelected(position));
        }

        refreshBreadcrumb();
        loadChapters();
    }

    private void refreshBreadcrumb() {
        String text;
        if (stage == Stage.CHAPTER) {
            text = skipChapterFlow ? "课程" : "章节";
        } else {
            text = "Topic";
        }
        if (tvBreadcrumb != null) tvBreadcrumb.setText(text);
        if (tvHint != null) {
            if (stage == Stage.CHAPTER) tvHint.setText(skipChapterFlow ? "加载中..." : "请选择章节：");
            else tvHint.setText("请选择 Topic：");
        }
        if (tgDifficulty != null) {
            tgDifficulty.setVisibility(stage == Stage.TOPIC ? android.view.View.VISIBLE : android.view.View.GONE);
            if (stage == Stage.TOPIC) {
                if (btnDiffAll != null) btnDiffAll.setChecked(true);
                selectedDifficultyFilter = null;
            }
        }
        if (btnBack != null) {
            btnBack.setEnabled(true);
        }
    }

    private void setListStrings(List<String> labels) {
        if (listView == null) return;
        listLabels.clear();
        if (labels != null) listLabels.addAll(labels);
        if (listAdapter == null) {
            listAdapter = new ArrayAdapter<String>(
                    this,
                    R.layout.item_select_row,
                    R.id.tv_row,
                    listLabels
            ) {
                @NonNull
                @Override
                public View getView(int position, @Nullable View convertView, @NonNull android.view.ViewGroup parent) {
                    View v = super.getView(position, convertView, parent);
                    try {
                        TextView tv = v.findViewById(R.id.tv_row);
                        if (tv != null && stage == Stage.TOPIC && position >= 0 && position < currentItems.size()) {
                            HashMap<String, Object> map = currentItems.get(position);
                            int d = 1;
                            try {
                                Object diff = map.get("difficulty");
                                if (diff != null) d = Integer.parseInt(String.valueOf(diff));
                            } catch (Exception ignored) {
                            }
                            String name = "";
                            try {
                                Object n = map.get("name");
                                if (n != null) name = String.valueOf(n);
                            } catch (Exception ignored) {
                            }
                            if (name == null) name = "";
                            String prefix = "难度 " + d;
                            String full = prefix + "  " + name;
                            SpannableString ss = new SpannableString(full);

                            int muted = 0xFF8E8E93;
                            ss.setSpan(new ForegroundColorSpan(muted), 0, prefix.length(), Spanned.SPAN_EXCLUSIVE_EXCLUSIVE);
                            ss.setSpan(new RelativeSizeSpan(0.90f), 0, prefix.length(), Spanned.SPAN_EXCLUSIVE_EXCLUSIVE);
                            ss.setSpan(new StyleSpan(Typeface.BOLD), prefix.length() + 2, full.length(), Spanned.SPAN_EXCLUSIVE_EXCLUSIVE);
                            tv.setText(ss);
                        }
                    } catch (Exception ignored) {
                    }

                    try {
                        TextView more = v.findViewById(R.id.tv_more);
                        if (more != null) {
                            more.setVisibility(stage == Stage.TOPIC ? View.VISIBLE : View.GONE);
                            // Click the entire row to select (starts MainActivity)
                            v.setOnClickListener(vv -> onItemSelected(position));

                            more.setOnClickListener(vv -> {
                                try {
                                    if (stage != Stage.TOPIC) return;
                                    if (position < 0 || position >= currentItems.size()) return;
                                    HashMap<String, Object> item = currentItems.get(position);

                                    String topicId = String.valueOf(item.get("topic_id"));
                                    String unitId = String.valueOf(item.get("unit_id"));

                                    String topicName = null;
                                    try {
                                        Object n = item.get("name");
                                        if (n != null) {
                                            String s = String.valueOf(n).trim();
                                            if (!s.isEmpty()) topicName = s;
                                        }
                                    } catch (Exception ignored2) {
                                    }

                                    String videoUrl = null;
                                    String videoStreams = null;
                                    try {
                                        Object vvurl = item.get("video_url");
                                        if (vvurl != null) {
                                            String s = String.valueOf(vvurl).trim();
                                            if (!s.isEmpty()) videoUrl = s;
                                        }
                                    } catch (Exception ignored2) {
                                    }
                                    try {
                                        Object vs = item.get("video_streams");
                                        if (vs != null) {
                                            String s = String.valueOf(vs).trim();
                                            if (!s.isEmpty() && !"{}".equals(s) && !"[]".equals(s)) videoStreams = s;
                                        }
                                    } catch (Exception ignored2) {
                                    }

                                    int d = 1;
                                    try {
                                        Object diff = item.get("difficulty");
                                        if (diff != null) d = Integer.parseInt(String.valueOf(diff));
                                    } catch (Exception ignored2) {
                                    }

                                    // Directly open CourseDetailActivity when clicking the 'three dots'
                                    Intent it = new Intent(TrainingSelectActivity.this, CourseDetailActivity.class);
                                    it.putExtra("chapter_id", selectedChapterId);
                                    it.putExtra("unit_id", unitId);
                                    it.putExtra("topic_id", topicId);
                                    it.putExtra("difficulty", d);
                                    if (topicName != null && !topicName.trim().isEmpty()) {
                                        it.putExtra("topic_name", topicName);
                                    }
                                    if (videoUrl != null && !videoUrl.trim().isEmpty()) {
                                        it.putExtra("topic_video_url", videoUrl);
                                    }
                                    if (videoStreams != null && !videoStreams.trim().isEmpty()) {
                                        it.putExtra("topic_video_streams", videoStreams);
                                    }
                                    startActivity(it);
                                } catch (Exception ignored2) {
                                }
                            });
                        }
                    } catch (Exception ignored) {
                    }
                    try {
                        TextView badge = v.findViewById(R.id.tv_badge);
                        boolean show = false;
                        if (stage == Stage.CHAPTER) {
                            if (position >= 0 && position < currentItems.size()) {
                                Object hv = currentItems.get(position).get("has_video");
                                if (hv instanceof Boolean) show = (Boolean) hv;
                                else if (hv != null) show = "1".equals(String.valueOf(hv)) || "true".equalsIgnoreCase(String.valueOf(hv));
                            }
                        } else {
                            if (position >= 0 && position < currentItems.size()) {
                                Object vu = currentItems.get(position).get("video_url");
                                if (vu != null && !String.valueOf(vu).trim().isEmpty()) show = true;
                            }
                        }
                        if (badge != null) {
                            badge.setVisibility(show ? View.VISIBLE : View.GONE);
                        }
                    } catch (Exception ignored) {
                    }
                    return v;
                }
            };
            listView.setAdapter(listAdapter);
        } else {
            listAdapter.notifyDataSetChanged();
        }
    }

    private void updateChapterLabelAt(int index) {
        try {
            if (index < 0 || index >= currentItems.size()) return;
            if (index >= listLabels.size()) return;
            HashMap<String, Object> map = currentItems.get(index);
            String name = String.valueOf(map.get("name"));
            int unitCount = 0;
            try {
                Object uc = map.get("unit_count");
                if (uc != null) unitCount = Integer.parseInt(String.valueOf(uc));
            } catch (Exception ignored) {
            }
            boolean hasVideo = false;
            try {
                Object hv = map.get("has_video");
                if (hv instanceof Boolean) hasVideo = (Boolean) hv;
                else if (hv != null) hasVideo = "1".equals(String.valueOf(hv)) || "true".equalsIgnoreCase(String.valueOf(hv));
            } catch (Exception ignored) {
            }
            listLabels.set(index, name + " (" + unitCount + ")");
            if (listAdapter != null) listAdapter.notifyDataSetChanged();
        } catch (Exception ignored) {
        }
    }

    private void probeChapterHasVideo(String chapterId, int index) {
        if (chapterId == null || chapterId.trim().isEmpty()) return;
        String url = AIConfigHelper.AGENT_API_BASE_URL + "/training/chapters/" + chapterId + "/topics?limit=" + DEFAULT_TOPIC_LIMIT;
        Request req = new Request.Builder().url(url).get().build();
        httpClient.newCall(req).enqueue(new Callback() {
            @Override
            public void onFailure(@NonNull Call call, @NonNull IOException e) {
            }

            @Override
            public void onResponse(@NonNull Call call, @NonNull Response response) throws IOException {
                String resStr = response.body() != null ? response.body().string() : "";
                if (!response.isSuccessful()) {
                    return;
                }
                boolean hasVideo = false;
                try {
                    JSONObject obj = new JSONObject(resStr);
                    JSONArray topics = obj.optJSONArray("items");
                    if (topics != null) {
                        for (int i = 0; i < topics.length(); i++) {
                            JSONObject t = topics.optJSONObject(i);
                            if (t == null) continue;
                            JSONObject v = t.optJSONObject("video");
                            if (v != null) {
                                String vu = v.optString("url", "");
                                if (vu != null && !vu.trim().isEmpty()) {
                                    hasVideo = true;
                                    break;
                                }
                            }
                        }
                    }
                } catch (Exception ignored) {
                }

                final boolean hvFinal = hasVideo;
                mainHandler.post(() -> {
                    try {
                        if (index >= 0 && index < currentItems.size()) {
                            currentItems.get(index).put("has_video", hvFinal);
                            updateChapterLabelAt(index);
                        }
                    } catch (Exception ignored) {
                    }
                });
            }
        });
    }

    private void goBackOneLevel() {
        if (stage == Stage.TOPIC) {
            if (skipChapterFlow) {
                finish();
                return;
            }
            stage = Stage.CHAPTER;
            selectedChapterId = null;
            selectedChapterName = null;
            refreshBreadcrumb();
            loadChapters();
        }
    }

    private void onItemSelected(int position) {
        if (position < 0 || position >= currentItems.size()) return;
        HashMap<String, Object> item = currentItems.get(position);
        if (stage == Stage.CHAPTER) {
            if (skipChapterFlow) {
                return;
            }
            selectedChapterId = String.valueOf(item.get("chapter_id"));
            selectedChapterName = String.valueOf(item.get("name"));
            stage = Stage.TOPIC;
            refreshBreadcrumb();
            loadTopicsByChapter(selectedChapterId, selectedDifficultyFilter, DEFAULT_TOPIC_LIMIT);
            return;
        }
        if (stage == Stage.TOPIC) {
            String topicId = String.valueOf(item.get("topic_id"));
            String unitId = String.valueOf(item.get("unit_id"));
            String videoUrl = null;
            String videoStreams = null;
            try {
                Object v = item.get("video_url");
                if (v != null) {
                    String s = String.valueOf(v).trim();
                    if (!s.isEmpty()) videoUrl = s;
                }
            } catch (Exception ignored) {
            }
            try {
                Object vs = item.get("video_streams");
                if (vs != null) {
                    String s = String.valueOf(vs).trim();
                    if (!s.isEmpty() && !"{}".equals(s) && !"[]".equals(s)) videoStreams = s;
                }
            } catch (Exception ignored) {
            }
            Object diff = item.get("difficulty");
            int d = 1;
            try {
                if (diff != null) d = Integer.parseInt(String.valueOf(diff));
            } catch (Exception ignored) {
            }
            Intent it = new Intent(TrainingSelectActivity.this, MainActivity.class);
            it.putExtra("mode", "chapter");
            it.putExtra("chapter_id", selectedChapterId);
            it.putExtra("unit_id", unitId);
            it.putExtra("topic_id", topicId);
            it.putExtra("difficulty", d);
            if (videoUrl != null && !videoUrl.trim().isEmpty()) {
                it.putExtra("topic_video_url", videoUrl);
            }
            if (videoStreams != null && !videoStreams.trim().isEmpty()) {
                it.putExtra("topic_video_streams", videoStreams);
            }
            startActivity(it);
        }
    }

    private void loadChapters() {
        stage = Stage.CHAPTER;
        refreshBreadcrumb();
        String url = AIConfigHelper.AGENT_API_BASE_URL + "/training/chapters";
        Request req = new Request.Builder().url(url).get().build();
        httpClient.newCall(req).enqueue(new Callback() {
            @Override
            public void onFailure(@NonNull Call call, @NonNull IOException e) {
                mainHandler.post(() -> Toast.makeText(TrainingSelectActivity.this, "获取章节失败：网络异常", Toast.LENGTH_SHORT).show());
            }

            @Override
            public void onResponse(@NonNull Call call, @NonNull Response response) throws IOException {
                String resStr = response.body() != null ? response.body().string() : "";
                if (!response.isSuccessful()) {
                    mainHandler.post(() -> Toast.makeText(TrainingSelectActivity.this, "获取章节失败：" + response.code(), Toast.LENGTH_SHORT).show());
                    return;
                }
                try {
                    JSONObject obj = new JSONObject(resStr);
                    JSONArray items = obj.optJSONArray("items");
                    currentItems.clear();
                    List<String> labels = new ArrayList<>();
                    if (items != null) {
                        for (int i = 0; i < items.length(); i++) {
                            JSONObject it = items.optJSONObject(i);
                            if (it == null) continue;
                            HashMap<String, Object> map = new HashMap<>();
                            map.put("chapter_id", it.optString("chapter_id"));
                            map.put("name", it.optString("name"));
                            map.put("unit_count", it.optInt("unit_count", 0));
                            map.put("has_video", false);
                            currentItems.add(map);
                            String label = it.optString("name") + " (" + it.optInt("unit_count", 0) + ")";
                            labels.add(label);
                        }
                    }
                    mainHandler.post(() -> {
                        if (skipChapterFlow) {
                            if (!currentItems.isEmpty()) {
                                HashMap<String, Object> first = currentItems.get(0);
                                selectedChapterId = String.valueOf(first.get("chapter_id"));
                                selectedChapterName = String.valueOf(first.get("name"));
                                loadTopicsByChapter(selectedChapterId, selectedDifficultyFilter, DEFAULT_TOPIC_LIMIT);
                            } else {
                                Toast.makeText(TrainingSelectActivity.this, "没有可用课程", Toast.LENGTH_SHORT).show();
                                setListStrings(new ArrayList<>());
                            }
                        } else {
                            setListStrings(labels);

                            // Probe each chapter for whether any topic has video.
                            for (int i = 0; i < currentItems.size(); i++) {
                                Object cid = currentItems.get(i).get("chapter_id");
                                if (cid != null) {
                                    probeChapterHasVideo(String.valueOf(cid), i);
                                }
                            }
                        }
                    });
                } catch (Exception e) {
                    mainHandler.post(() -> Toast.makeText(TrainingSelectActivity.this, "解析章节失败", Toast.LENGTH_SHORT).show());
                }
            }
        });
    }

    private void loadTopicsByChapter(String chapterId, Integer difficulty, Integer limit) {
        if (chapterId == null || chapterId.trim().isEmpty()) return;
        stage = Stage.TOPIC;
        refreshBreadcrumb();
        String url = AIConfigHelper.AGENT_API_BASE_URL + "/training/chapters/" + chapterId + "/topics";
        StringBuilder sb = new StringBuilder(url);
        boolean hasQ = false;
        if (difficulty != null) {
            sb.append(hasQ ? "&" : "?");
            hasQ = true;
            sb.append("difficulty=").append(difficulty);
        }
        if (limit != null) {
            sb.append(hasQ ? "&" : "?");
            hasQ = true;
            sb.append("limit=").append(limit);
        }
        Request req = new Request.Builder().url(sb.toString()).get().build();
        httpClient.newCall(req).enqueue(new Callback() {
            @Override
            public void onFailure(@NonNull Call call, @NonNull IOException e) {
                mainHandler.post(() -> Toast.makeText(TrainingSelectActivity.this, "获取 Topic 失败：网络异常", Toast.LENGTH_SHORT).show());
            }

            @Override
            public void onResponse(@NonNull Call call, @NonNull Response response) throws IOException {
                String resStr = response.body() != null ? response.body().string() : "";
                if (!response.isSuccessful()) {
                    mainHandler.post(() -> Toast.makeText(TrainingSelectActivity.this, "获取 Topic 失败：" + response.code(), Toast.LENGTH_SHORT).show());
                    return;
                }
                try {
                    JSONObject obj = new JSONObject(resStr);
                    JSONArray topics = obj.optJSONArray("items");
                    currentItems.clear();
                    List<String> labels = new ArrayList<>();
                    if (topics != null) {
                        for (int i = 0; i < topics.length(); i++) {
                            JSONObject t = topics.optJSONObject(i);
                            if (t == null) continue;
                            String tid = t.optString("topic_id");
                            String name = t.optString("name");
                            String uid = t.optString("unit_id");
                            int diff = t.optInt("difficulty", 1);
                            String videoUrl = "";
                            String videoStreams = "";
                            try {
                                JSONObject v = t.optJSONObject("video");
                                if (v != null) {
                                    videoUrl = v.optString("url", "");
                                    JSONArray streamsArr = v.optJSONArray("streams");
                                    if (streamsArr != null && streamsArr.length() > 0) {
                                        videoStreams = streamsArr.toString();
                                    }
                                }
                            } catch (Exception ignored) {
                            }
                            HashMap<String, Object> map = new HashMap<>();
                            map.put("topic_id", tid);
                            map.put("name", name);
                            map.put("unit_id", uid);
                            map.put("difficulty", diff);
                            map.put("video_url", videoUrl);
                            map.put("video_streams", videoStreams);
                            currentItems.add(map);
                            String base = (name == null || name.isEmpty()) ? tid : name;
                            labels.add(base);
                        }
                    }
                    mainHandler.post(() -> setListStrings(labels));
                } catch (Exception e) {
                    mainHandler.post(() -> Toast.makeText(TrainingSelectActivity.this, "解析 Topic 失败", Toast.LENGTH_SHORT).show());
                }
            }
        });
    }
}
