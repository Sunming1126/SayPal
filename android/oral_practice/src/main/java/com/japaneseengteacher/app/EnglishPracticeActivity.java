package com.japaneseengteacher.app;

import android.Manifest;
import android.content.pm.PackageManager;
import android.media.MediaPlayer;
import android.media.MediaRecorder;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.view.View;
import android.widget.ProgressBar;
import android.widget.SeekBar;
import android.widget.TextView;
import android.widget.Toast;

import androidx.activity.result.ActivityResultLauncher;
import androidx.activity.result.contract.ActivityResultContracts;
import androidx.annotation.NonNull;
import androidx.appcompat.app.AppCompatActivity;
import androidx.core.content.ContextCompat;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;
import androidx.viewpager2.widget.ViewPager2;

import com.google.android.material.appbar.MaterialToolbar;
import com.google.android.material.floatingactionbutton.FloatingActionButton;
import com.google.android.material.button.MaterialButton;
import com.google.android.material.tabs.TabLayout;
import com.google.android.material.tabs.TabLayoutMediator;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.File;
import java.io.IOException;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;
import java.util.Locale;
import java.util.concurrent.TimeUnit;

import okhttp3.Call;
import okhttp3.Callback;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.Response;

public class EnglishPracticeActivity extends AppCompatActivity {

    public static final String EXTRA_UNIT_ID = "unit_id";
    public static final String EXTRA_TOPIC_ID = "topic_id";

    private final OkHttpClient httpClient = new OkHttpClient.Builder()
            .connectTimeout(15, TimeUnit.SECONDS)
            .readTimeout(30, TimeUnit.SECONDS)
            .build();
    private final Handler mainHandler = new Handler(Looper.getMainLooper());

    private String unitId;
    private String topicId;
    private JSONObject topicJson;

    // Sentences data
    private final List<String> enSentences = new ArrayList<>();
    private final List<String> cnTranslations = new ArrayList<>();

    // BGM
    private MediaPlayer bgmPlayer;
    private float bgmNormalVolume = 0f;

    // ViewPager2 + TabLayout
    private ViewPager2 viewPager;
    private TabLayout tabLayout;

    // Recording
    private MediaRecorder mediaRecorder;
    private MediaPlayer mediaPlayer;
    private String currentRecordingPath;
    private boolean isRecording = false;
    private boolean isPlaying = false;
    private final Handler handler = new Handler(Looper.getMainLooper());
    private int recordingProgress = 0;
    private Runnable progressRunnable;

    // Views
    private FloatingActionButton fabRecord;
    private MaterialButton btnRerecord;
    private MaterialButton btnPlay;
    private TextView tvRecordingStatus;
    private ProgressBar progressRecording;
    private SeekBar sbBgmVolume;
    private TextView tvBgmVolume;
    private View loadingOverlay;

    // Permission launcher
    private final ActivityResultLauncher<String> micPermissionLauncher =
            registerForActivityResult(new ActivityResultContracts.RequestPermission(), granted -> {
                if (granted) {
                    startRecording();
                } else {
                    Toast.makeText(this, R.string.recording_permission_denied, Toast.LENGTH_SHORT).show();
                }
            });

    // Tab titles
    private static final String[] TAB_TITLES = {"中文提示", "中英对照"};

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_english_practice);

        unitId = getIntent().getStringExtra(EXTRA_UNIT_ID);
        topicId = getIntent().getStringExtra(EXTRA_TOPIC_ID);

        if (unitId == null || unitId.trim().isEmpty()
                || topicId == null || topicId.trim().isEmpty()) {
            Toast.makeText(this, "缺少课程信息", Toast.LENGTH_SHORT).show();
            finish();
            return;
        }

        setupToolbar();
        setupRecordingPanel();
        setupBgmVolumeBar();
        setupViewPager();
        startBgmIfAvailable();
        fetchTopicData();
    }

    private void fetchTopicData() {
        showLoading(true);
        String url = AIConfigHelper.AGENT_API_BASE_URL + "/training/topics/" + unitId + "/" + topicId;
        Request req = new Request.Builder().url(url).get().build();
        httpClient.newCall(req).enqueue(new Callback() {
            @Override
            public void onFailure(@NonNull Call call, @NonNull IOException e) {
                mainHandler.post(() -> {
                    showLoading(false);
                    Toast.makeText(EnglishPracticeActivity.this, "加载课程数据失败", Toast.LENGTH_LONG).show();
                });
            }

            @Override
            public void onResponse(@NonNull Call call, @NonNull Response response) throws IOException {
                String resStr = response.body() != null ? response.body().string() : "";
                if (!response.isSuccessful()) {
                    mainHandler.post(() -> {
                        showLoading(false);
                        Toast.makeText(EnglishPracticeActivity.this, "加载失败：http" + response.code(), Toast.LENGTH_LONG).show();
                    });
                    return;
                }
                try {
                    JSONObject wrapper = new JSONObject(resStr);
                    topicJson = wrapper.optJSONObject("topic");
                    if (topicJson == null) {
                        mainHandler.post(() -> {
                            showLoading(false);
                            Toast.makeText(EnglishPracticeActivity.this, "找不到课程内容", Toast.LENGTH_LONG).show();
                        });
                        return;
                    }
                    mainHandler.post(() -> {
                        showLoading(false);
                        loadSentenceData();
                        refreshViewPager();
                    });
                } catch (Exception e) {
                    mainHandler.post(() -> {
                        showLoading(false);
                        Toast.makeText(EnglishPracticeActivity.this, "解析课程数据失败", Toast.LENGTH_LONG).show();
                    });
                }
            }
        });
    }

    private void loadSentenceData() {
        enSentences.clear();
        cnTranslations.clear();

        // Load required_sentences (EN sentences)
        JSONArray reqSent = topicJson.optJSONArray("required_sentences");
        if (reqSent != null) {
            for (int i = 0; i < reqSent.length(); i++) {
                String s = reqSent.optString(i, "").trim();
                if (!s.isEmpty()) {
                    enSentences.add(s);
                }
            }
        }

        // Load translation_drill from lesson_flow for CN translations
        JSONObject lessonFlow = topicJson.optJSONObject("lesson_flow");
        if (lessonFlow != null) {
            JSONArray translationDrill = lessonFlow.optJSONArray("translation_drill");
            if (translationDrill != null) {
                for (int i = 0; i < translationDrill.length(); i++) {
                    JSONObject item = translationDrill.optJSONObject(i);
                    if (item != null) {
                        String cn = item.optString("cn", "").trim();
                        cnTranslations.add(cn);
                    }
                }
            }
        }

        // Fill placeholder for missing translations
        while (cnTranslations.size() < enSentences.size()) {
            cnTranslations.add("");
        }

        if (enSentences.isEmpty()) {
            Toast.makeText(this, R.string.no_sentences, Toast.LENGTH_LONG).show();
        }
    }

    private void refreshViewPager() {
        if (viewPager != null && tabLayout != null) {
            PracticePagerAdapter adapter = new PracticePagerAdapter(enSentences, cnTranslations);
            viewPager.setAdapter(adapter);
            new TabLayoutMediator(tabLayout, viewPager, (tab, position) -> {
                tab.setText(TAB_TITLES[position]);
            }).attach();
        }
    }

    private void showLoading(boolean show) {
        if (loadingOverlay != null) {
            loadingOverlay.setVisibility(show ? View.VISIBLE : View.GONE);
        }
    }

    private void setupToolbar() {
        MaterialToolbar toolbar = findViewById(R.id.toolbar);
        toolbar.setNavigationOnClickListener(v -> finish());
    }

    private void setupViewPager() {
        viewPager = findViewById(R.id.view_pager);
        tabLayout = findViewById(R.id.tab_layout);
        loadingOverlay = findViewById(R.id.loading_overlay);
    }

    private void setupRecordingPanel() {
        fabRecord = findViewById(R.id.fab_record);
        btnRerecord = findViewById(R.id.btn_rerecord);
        btnPlay = findViewById(R.id.btn_play);
        tvRecordingStatus = findViewById(R.id.tv_recording_status);
        progressRecording = findViewById(R.id.progress_recording);

        fabRecord.setOnClickListener(v -> {
            if (isRecording) {
                stopRecording();
            } else {
                checkPermissionAndRecord();
            }
        });

        btnRerecord.setOnClickListener(v -> {
            if (isPlaying) stopPlaying();
            if (currentRecordingPath != null) {
                new File(currentRecordingPath).delete();
                currentRecordingPath = null;
            }
            hideRecordingControls();
            checkPermissionAndRecord();
        });

        btnPlay.setOnClickListener(v -> {
            if (isPlaying) {
                stopPlaying();
            } else {
                playRecording();
            }
        });
    }

    private void setupBgmVolumeBar() {
        sbBgmVolume = findViewById(R.id.sb_bgm_volume);
        tvBgmVolume = findViewById(R.id.tv_bgm_volume);

        // Initialize from BgmManager stored volume
        float vol = BgmManager.getVolume(this);
        int volPercent = Math.round(vol * 100f);
        bgmNormalVolume = vol;
        sbBgmVolume.setProgress(volPercent);
        tvBgmVolume.setText(volPercent + "%");

        sbBgmVolume.setOnSeekBarChangeListener(new android.widget.SeekBar.OnSeekBarChangeListener() {
            @Override
            public void onProgressChanged(SeekBar seekBar, int progress, boolean fromUser) {
                if (!fromUser) return;
                float newVol = progress / 100f;
                bgmNormalVolume = newVol;
                BgmManager.setVolume(EnglishPracticeActivity.this, newVol);
                applyBgmVolume(newVol);
                tvBgmVolume.setText(progress + "%");
            }

            @Override
            public void onStartTrackingTouch(SeekBar seekBar) {}

            @Override
            public void onStopTrackingTouch(SeekBar seekBar) {}
        });
    }

    private void checkPermissionAndRecord() {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO)
                == PackageManager.PERMISSION_GRANTED) {
            startRecording();
        } else {
            micPermissionLauncher.launch(Manifest.permission.RECORD_AUDIO);
        }
    }

    private void startRecording() {
        File dir = new File(getExternalFilesDir(null), "practice_recordings");
        if (!dir.exists()) dir.mkdirs();

        String timestamp = new SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(new Date());
        String safeTopicId = topicId != null ? topicId.replaceAll("[^a-zA-Z0-9]", "_") : "topic";
        currentRecordingPath = new File(dir, "practice_" + safeTopicId + "_" + timestamp + ".m4a").getAbsolutePath();

        mediaRecorder = new MediaRecorder();
        mediaRecorder.setAudioSource(MediaRecorder.AudioSource.MIC);
        mediaRecorder.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4);
        mediaRecorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC);
        mediaRecorder.setAudioEncodingBitRate(128000);
        mediaRecorder.setAudioSamplingRate(44100);
        mediaRecorder.setOutputFile(currentRecordingPath);

        try {
            mediaRecorder.prepare();
            mediaRecorder.start();
            isRecording = true;
            onRecordingOrPlaybackStarted();

            fabRecord.setImageResource(R.drawable.ic_mic);
            tvRecordingStatus.setText(R.string.recording_in_progress);
            progressRecording.setVisibility(View.VISIBLE);
            progressRecording.setProgress(0);
            recordingProgress = 0;

            progressRunnable = new Runnable() {
                @Override
                public void run() {
                    if (!isRecording) return;
                    recordingProgress++;
                    progressRecording.setProgress(recordingProgress * 100 / 60);
                    if (recordingProgress < 60) {
                        handler.postDelayed(this, 1000);
                    } else {
                        stopRecording();
                    }
                }
            };
            handler.postDelayed(progressRunnable, 1000);

        } catch (IOException e) {
            Toast.makeText(this, R.string.recording_failed, Toast.LENGTH_SHORT).show();
            if (mediaRecorder != null) {
                mediaRecorder.release();
                mediaRecorder = null;
            }
        }
    }

    private void stopRecording() {
        if (mediaRecorder == null) return;
        try {
            mediaRecorder.stop();
        } catch (Exception ignored) {}
        mediaRecorder.release();
        mediaRecorder = null;

        isRecording = false;
        if (progressRunnable != null) handler.removeCallbacks(progressRunnable);
        onRecordingOrPlaybackStopped();

        tvRecordingStatus.setText(R.string.recording_saved);
        showRecordingControls();
        Toast.makeText(this, R.string.recording_saved, Toast.LENGTH_SHORT).show();
    }

    private void playRecording() {
        if (currentRecordingPath == null || !new File(currentRecordingPath).exists()) {
            Toast.makeText(this, "录音文件不存在", Toast.LENGTH_SHORT).show();
            return;
        }

        mediaPlayer = new MediaPlayer();
        try {
            mediaPlayer.setDataSource(currentRecordingPath);
            mediaPlayer.prepare();
            mediaPlayer.start();
            isPlaying = true;
            onRecordingOrPlaybackStarted();
            btnPlay.setText(R.string.stop);

            mediaPlayer.setOnCompletionListener(mp -> {
                isPlaying = false;
                mainHandler.post(() -> {
                    btnPlay.setText(R.string.play);
                    tvRecordingStatus.setText(R.string.recording_saved);
                    onRecordingOrPlaybackStopped();
                });
            });
        } catch (IOException e) {
            Toast.makeText(this, "播放失败", Toast.LENGTH_SHORT).show();
        }
    }

    private void stopPlaying() {
        if (mediaPlayer != null) {
            try {
                mediaPlayer.stop();
                mediaPlayer.release();
            } catch (Exception ignored) {}
            mediaPlayer = null;
        }
        isPlaying = false;
        btnPlay.setText(R.string.play);
        tvRecordingStatus.setText(R.string.recording_saved);
        onRecordingOrPlaybackStopped();
    }

    private void showRecordingControls() {
        btnRerecord.setVisibility(View.VISIBLE);
        btnPlay.setVisibility(View.VISIBLE);
        progressRecording.setVisibility(View.GONE);
    }

    private void hideRecordingControls() {
        btnRerecord.setVisibility(View.GONE);
        btnPlay.setVisibility(View.GONE);
    }

    private void stopRecordingIfActive() {
        if (isRecording) stopRecording();
        if (isPlaying) stopPlaying();
    }

    // ==============================================================
    // BGM management — mirrors the pattern used in MainActivity
    // ==============================================================

    private void startBgmIfAvailable() {
        stopBgm();
        try {
            bgmPlayer = BgmManager.start(this);
            bgmNormalVolume = BgmManager.getVolume(this);
            BgmManager.applyVolume(bgmPlayer, this);
        } catch (Exception e) {
            if (bgmPlayer != null) {
                try {
                    bgmPlayer.release();
                } catch (Exception ignored) {}
                bgmPlayer = null;
            }
        }
    }

    private void stopBgm() {
        try {
            if (bgmPlayer != null) bgmPlayer.stop();
        } catch (Exception ignored) {}
        try {
            if (bgmPlayer != null) bgmPlayer.release();
        } catch (Exception ignored) {}
        bgmPlayer = null;
    }

    private void applyBgmVolume(float volume) {
        if (bgmPlayer == null) return;
        try {
            bgmPlayer.setVolume(volume, volume);
        } catch (Exception ignored) {}
    }

    private void lowerBgmForRecording() {
        // While recording or playing back, lower BGM to 50% so user can hear themselves
        applyBgmVolume(bgmNormalVolume * 0.5f);
    }

    private void restoreBgmVolume() {
        applyBgmVolume(bgmNormalVolume);
    }

    private void onRecordingOrPlaybackStarted() {
        if (bgmPlayer != null && bgmPlayer.isPlaying()) {
            lowerBgmForRecording();
        }
    }

    private void onRecordingOrPlaybackStopped() {
        if (bgmPlayer != null) {
            restoreBgmVolume();
            if (!bgmPlayer.isPlaying()) {
                try {
                    bgmPlayer.start();
                } catch (Exception ignored) {}
            }
        }
    }

    @Override
    protected void onPause() {
        super.onPause();
        stopRecordingIfActive();
        if (bgmPlayer != null) {
            try { bgmPlayer.pause(); } catch (Exception ignored) {}
        }
    }

    @Override
    protected void onResume() {
        super.onResume();
        BgmManager.applyVolume(bgmPlayer, this);
        if (bgmPlayer != null) {
            try {
                if (!bgmPlayer.isPlaying()) bgmPlayer.start();
            } catch (Exception ignored) {}
        }
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        stopRecordingIfActive();
        stopBgm();
        handler.removeCallbacksAndMessages(null);
    }
}
