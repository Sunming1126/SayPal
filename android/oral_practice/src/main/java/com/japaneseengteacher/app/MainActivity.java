package com.japaneseengteacher.app;

import android.Manifest;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.media.AudioFormat;
import android.media.AudioRecord;
import android.media.MediaRecorder;
import android.media.AudioDeviceInfo;
import android.media.AudioManager;
import android.media.MediaPlayer;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.text.TextUtils;
import android.text.Spannable;
import android.text.SpannableStringBuilder;
import android.text.style.ForegroundColorSpan;
import android.text.Layout;
import android.text.Selection;
import android.util.Log;
import android.util.Base64;
import android.util.TypedValue;
import android.widget.TextView;
import android.widget.Toast;
import android.view.animation.DecelerateInterpolator;

import com.github.mikephil.charting.charts.LineChart;
import com.github.mikephil.charting.components.AxisBase;
import com.github.mikephil.charting.components.XAxis;
import com.github.mikephil.charting.components.YAxis;
import com.github.mikephil.charting.data.Entry;
import com.github.mikephil.charting.data.LineData;
import com.github.mikephil.charting.data.LineDataSet;
import com.github.mikephil.charting.formatter.ValueFormatter;
import androidx.appcompat.app.AlertDialog;
import android.content.ClipData;
import android.content.ClipboardManager;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Typeface;
import android.graphics.Color;
import android.graphics.drawable.BitmapDrawable;
import android.graphics.drawable.Drawable;
import android.graphics.drawable.GradientDrawable;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.view.ActionMode;
import android.view.Menu;
import android.view.MenuItem;
import android.view.SubMenu;
import android.view.MotionEvent;
import android.view.GestureDetector;
import android.widget.FrameLayout;
import android.widget.CheckBox;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.HorizontalScrollView;
import android.widget.ProgressBar;
import android.widget.RadioGroup;
import android.widget.TableLayout;
import android.widget.TableRow;
import android.view.ViewTreeObserver;
import android.view.ContextThemeWrapper;
import java.lang.reflect.Field;
import java.lang.reflect.Method;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;
import com.google.android.material.card.MaterialCardView;
import com.google.android.material.button.MaterialButton;
import com.google.android.material.dialog.MaterialAlertDialogBuilder;
import com.google.android.material.radiobutton.MaterialRadioButton;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.appcompat.app.AppCompatActivity;
import androidx.appcompat.widget.PopupMenu;
import androidx.appcompat.widget.Toolbar;
import androidx.appcompat.widget.AppCompatButton;
import androidx.core.app.ActivityCompat;
import androidx.core.view.ViewCompat;

import android.content.SharedPreferences;

import com.ss.bytertc.engine.RTCEngine;
import com.ss.bytertc.engine.RTCRoom;
import com.ss.bytertc.engine.RTCRoomConfig;
import com.ss.bytertc.engine.UserInfo;
import com.ss.bytertc.engine.data.EngineConfig;
import com.ss.bytertc.engine.data.StreamInfo;
import com.ss.bytertc.engine.data.SubscribeState;
import com.ss.bytertc.engine.data.SubscribeStateChangeReason;
import com.ss.bytertc.engine.data.PublishState;
import com.ss.bytertc.engine.data.PublishStateChangeReason;
import com.ss.bytertc.engine.data.LocalAudioStreamState;
import com.ss.bytertc.engine.data.LocalAudioStreamError;
import com.ss.bytertc.engine.data.RemoteAudioState;
import com.ss.bytertc.engine.data.RemoteAudioStateChangeReason;
import com.ss.bytertc.engine.handler.IRTCEngineEventHandler;
import com.ss.bytertc.engine.handler.IRTCRoomEventHandler;
import com.ss.bytertc.engine.type.ChannelProfile;
import com.ss.bytertc.engine.type.RoomState;
import com.ss.bytertc.engine.type.RoomStateChangeReason;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.util.ArrayDeque;
import java.util.Arrays;
import java.util.HashMap;
import java.util.Locale;
import java.util.ArrayList;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.TimeUnit;

import java.util.regex.Matcher;
import java.util.regex.Pattern;

import com.github.mikephil.charting.charts.RadarChart;
import com.github.mikephil.charting.components.AxisBase;
import com.github.mikephil.charting.components.XAxis;
import com.github.mikephil.charting.data.RadarData;
import com.github.mikephil.charting.data.RadarDataSet;
import com.github.mikephil.charting.data.RadarEntry;
import com.github.mikephil.charting.formatter.ValueFormatter;

import okhttp3.Call;
import okhttp3.Callback;
import okhttp3.MediaType;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.RequestBody;
import okhttp3.Response;

import java.net.SocketTimeoutException;

public class MainActivity extends AppCompatActivity {

    private static final String TAG = "RTC_AI_DEMO";
    private RTCEngine rtcEngine;
    private RTCRoom rtcRoom;

    private boolean isJoiningOrJoined = false;
    private boolean hasSummonedAi = false;
    private volatile boolean isInRoom = false;
    private String currentTaskId = AIConfigHelper.TASK_ID;

    private static final String PREFS_NAME = "ai_prefs";
    private static final String PREF_USERNAME = "username";
    private static final String PREF_CLIENT_ID = "client_id";
    private static final String PREF_CHAT_DIFFICULTY = "chat_difficulty";
    private static final String PREF_CHAT_DIFFICULTY_MANUAL = "chat_difficulty_manual";
    private static final String PREF_SHOW_ANALYSIS_DIALOG = "show_analysis_dialog";

    private static final String PREF_SHOW_ONBOARDING_CHAT = "show_onboarding_chat";
    private static final String PREF_ONBOARDING_CHAT_SHOWN = "onboarding_chat_shown";
    private static final String PREF_ONBOARDING_TUTORIAL_SHOWN = "onboarding_tutorial_shown";

    private static final String PREF_CHAT_MODULES_MODE = "chat_modules_mode"; // default/teach_test/roleplay (legacy: custom)
    private static final String PREF_CHAT_MODULES = "chat_modules"; // csv: repeat,chat,exam
    private static final String PREF_CHAT_CN_LEVEL = "chat_cn_level"; // high/mid/low

    private static final String PREF_LAST_VOICECHAT_START_URL = "last_voicechat_start_url";
    private static final String PREF_LAST_VOICECHAT_START_PAYLOAD = "last_voicechat_start_payload";
    private static final String PREF_LAST_VOICECHAT_START_RESPONSE = "last_voicechat_start_response";

    private static final String PREF_STATS_DAY_SECONDS_PREFIX = "stats_day_seconds_"; // yyyyMMdd -> long seconds
    private static final String PREF_STATS_DAY_SESSIONS_PREFIX = "stats_day_sessions_"; // yyyyMMdd -> int
    private static final String PREF_STATS_DAY_DEFINE_PREFIX = "stats_day_define_"; // yyyyMMdd -> int
    private static final String PREF_STATS_ALL_SECONDS = "stats_all_seconds"; // long seconds

    private static final String PREF_TUTORIAL_DONE = "tutorial_done";
    private static final String PREF_TUTORIAL_STEP = "tutorial_step";

    private String currentUserId = null;
    private String currentRoomId = null;
    private String currentUserRtcToken = null;
    private String currentAppId = null;
    private String currentSessionId = null;
    private String currentBotUserId = null;
    private String currentClientId = null;

    private String selectedMode = "mainline";
    private String selectedChapterId = null;
    private String selectedUnitId = null;
    private String selectedTopicId = null;
    private String selectedTopicVideoUrl = null;
    private String selectedTopicVideoStreams = null;
    private int selectedDifficulty = 1;

    // null means "default" (let backend map modules from difficulty)
    private ArrayList<String> selectedModules = null;
    private String selectedCnLevel = "mid";

    private static final int REQ_PRECHAT_VIDEO = 9101;

    private boolean autoFlowEnabled = false;
    private boolean autoFlowTriggered = false;
    private boolean autoSummonAfterJoin = false;
    private boolean autoFlowWaitingPermission = false;
    private boolean selectedCoursePending;
    private boolean pendingCourseVideoConversation = false;
    private int selectedLessonStartStage = 1;

    private boolean analyzePending = false;
    private boolean stopAnalyzePending = false;

    private boolean wasInCallForStats = false;
    private long studySessionStartMs = 0L;

    private MaterialCardView callToggleCard;
    private ImageView callToggleIcon;
    private MaterialButton playVideoButton;
    private MaterialButton openSettingsButton;

    private TutorialOverlayView tutorialOverlay;
    private boolean tutorialForceShow = false;

    private LinearLayout courseIntroOverlay;
    private TextView courseStageTextView;
    private TextView courseIntroEnglishTextView;
    private TextView courseIntroChineseTextView;
    private TextView courseIntroProgressTextView;
    private MaterialButton courseIntroReplayButton;
    private MaterialButton courseIntroSkipButton;
    private TextView subtitlesTextView;

    private RecyclerView chatRecyclerView;
    private LinearLayoutManager chatLayoutManager;
    private ChatAdapter chatAdapter;
    private VoiceWaveView voiceWaveView;

    private boolean courseIntroPendingStart = false;
    private boolean courseIntroPlaying = false;
    private String courseIntroRequestId = null;
    private MediaPlayer courseIntroPlayer;
    private MediaPlayer courseBgmPlayer;
    private Runnable courseIntroTimeoutRunnable = null;
    private Runnable courseIntroFinishRunnable = null;
    private boolean structuredCourseLoading = false;
    private boolean structuredCourseLoaded = false;
    private boolean lessonCourseEnabled = false;
    private String structuredCourseKey = null;
    private final ArrayList<CourseLine> courseIntroLines = new ArrayList<>();
    private final ArrayList<CourseLine> courseTranslateLines = new ArrayList<>();
    private final ArrayList<CourseQa> courseQaPairs = new ArrayList<>();
    private int courseIntroPlayIndex = 0;

    private final ArrayList<String> freeChatSentences = new ArrayList<>();
    private boolean freeChatModeActive = false;

    private enum ModeType { NONE, CHINESE_QA, ENGLISH_QA, FREE_QA }
    private ModeType currentMode = ModeType.NONE;

    private final ArrayList<ChatMessage> chatMessages = new ArrayList<>();

    private final HashMap<String, Integer> lastSequenceBySpeakerRound = new HashMap<>();
    private final HashMap<String, Integer> lastFinalSequenceBySpeakerRound = new HashMap<>();
    private final HashMap<String, String> lastFinalTextBySpeakerRound = new HashMap<>();
    private final HashMap<String, String> lastLiveTextBySpeaker = new HashMap<>();
    private String liveUserLine = "";
    private String liveAiLine = "";
    // When a welcome_message is appended directly from /voicechat/start response,
    // RTC subtitle callback will later deliver the same text as the bot's first line.
    // We remember the normalized welcome text and skip the first matching bot subtitle
    // to avoid duplicate display.
    private String pendingWelcomeDedupText = null;
    private String lastHistoryKey = null;
    private int lastHistoryStart = 0;

    private int currentUtteranceId = 0;
    private int lastFinalizedUtteranceId = -1;

    private final OkHttpClient httpClient = new OkHttpClient.Builder()
            .connectTimeout(30, TimeUnit.SECONDS)
            .readTimeout(300, TimeUnit.SECONDS)
            .callTimeout(0, TimeUnit.SECONDS)
            .build();

    private final Handler mainHandler = new Handler(Looper.getMainLooper());

    private static final String PREF_HISTORY_ITEMS = "history_items_v1";
    private static final String PREF_HISTORY_BY_JOB = "history_by_job_v1";
    private static final String PREF_HISTORY_LEGACY_OWNER = "history_legacy_owner_v1";
    private static final int HISTORY_LOCAL_MAX = 200;

    private static final int AUDIO_SAMPLE_RATE = 16000;
    private static final int AUDIO_CHANNELS = 1;
    private static final int AUDIO_CHUNK_MS = 200;
    private static final int CLIENT_VAD_THRESHOLD = 1500;
    private static final int CLIENT_VAD_PRE_MS = 200;
    private static final int CLIENT_VAD_POST_MS = 400;
    private AudioRecord audioRecord;
    private Thread audioThread;
    private volatile boolean audioRecording = false;
    private volatile boolean audioSessionActive = false;
    private volatile boolean audioFinalizeInFlight = false;
    private volatile boolean audioFinalized = false;
    private long audioRecordStartMs = 0;
    private int audioChunkSeq = 0;
    private final AtomicInteger audioUploadInFlight = new AtomicInteger(0);
    private volatile boolean audioHasUploadedAnyChunk = false;

    private int calcAvgAbsPcm16(byte[] buf, int len) {
        int samples = len / 2;
        if (samples <= 0) return 0;
        long sum = 0;
        int i = 0;
        while (i + 1 < len) {
            int lo = buf[i] & 0xFF;
            int hi = buf[i + 1];
            short s = (short) (lo | (hi << 8));
            sum += Math.abs((int) s);
            i += 2;
        }

        return (int) (sum / Math.max(1, samples));
    }

    private String _todayKey() {
        try {
            java.text.SimpleDateFormat sdf = new java.text.SimpleDateFormat("yyyyMMdd", java.util.Locale.US);
            return sdf.format(new java.util.Date());
        } catch (Exception e) {
            return "";
        }
    }

    private void _addStudySeconds(long seconds) {
        if (seconds <= 0) return;
        String k = _todayKey();
        if (k == null || k.trim().isEmpty()) return;
        try {
            SharedPreferences sp = getSharedPreferences(PREFS_NAME, MODE_PRIVATE);
            long prev = sp.getLong(PREF_STATS_DAY_SECONDS_PREFIX + k, 0L);
            long next = prev + seconds;
            long allPrev = sp.getLong(PREF_STATS_ALL_SECONDS, 0L);
            sp.edit()
                    .putLong(PREF_STATS_DAY_SECONDS_PREFIX + k, next)
                    .putLong(PREF_STATS_ALL_SECONDS, allPrev + seconds)
                    .apply();
        } catch (Exception ignored) {
        }
    }

    private void _incTodayCounter(String prefix) {
        String k = _todayKey();
        if (k == null || k.trim().isEmpty()) return;
        try {
            SharedPreferences sp = getSharedPreferences(PREFS_NAME, MODE_PRIVATE);
            int prev = sp.getInt(prefix + k, 0);
            sp.edit().putInt(prefix + k, prev + 1).apply();
        } catch (Exception ignored) {
        }
    }

    private static String _formatMmSs(long totalSeconds) {
        if (totalSeconds < 0) totalSeconds = 0;
        long mm = totalSeconds / 60;
        long ss = totalSeconds % 60;
        String m = (mm < 10 ? ("0" + mm) : String.valueOf(mm));
        String s = (ss < 10 ? ("0" + ss) : String.valueOf(ss));
        return m + ":" + s;
    }

    private String _statsDayLabel(String dayKey) {
        String k = String.valueOf(dayKey == null ? "" : dayKey).trim();
        if (k.length() == 8) {
            try {
                return k.substring(4, 6) + "/" + k.substring(6, 8);
            } catch (Exception ignored) {
            }
        }
        return k;
    }

    private ArrayList<String[]> _buildStatsHistoryRows(SharedPreferences sp, int maxRows) {
        ArrayList<String[]> rows = new ArrayList<>();
        if (sp == null) return rows;
        java.util.Map<String, ?> all = sp.getAll();
        if (all == null || all.isEmpty()) return rows;

        java.util.TreeSet<String> dayKeys = new java.util.TreeSet<>();
        for (String fullKey : all.keySet()) {
            if (fullKey == null) continue;
            String day = null;
            if (fullKey.startsWith(PREF_STATS_DAY_SECONDS_PREFIX)) {
                day = fullKey.substring(PREF_STATS_DAY_SECONDS_PREFIX.length());
            } else if (fullKey.startsWith(PREF_STATS_DAY_SESSIONS_PREFIX)) {
                day = fullKey.substring(PREF_STATS_DAY_SESSIONS_PREFIX.length());
            } else if (fullKey.startsWith(PREF_STATS_DAY_DEFINE_PREFIX)) {
                day = fullKey.substring(PREF_STATS_DAY_DEFINE_PREFIX.length());
            }
            if (day != null && day.matches("\\d{8}")) {
                dayKeys.add(day);
            }
        }

        if (dayKeys.isEmpty()) return rows;
        ArrayList<String> descDays = new ArrayList<>(dayKeys);
        java.util.Collections.sort(descDays, java.util.Collections.reverseOrder());
        int n = Math.min(maxRows, descDays.size());
        for (int i = 0; i < n; i++) {
            String day = descDays.get(i);
            long sec = sp.getLong(PREF_STATS_DAY_SECONDS_PREFIX + day, 0L);
            int sessions = sp.getInt(PREF_STATS_DAY_SESSIONS_PREFIX + day, 0);
            int defines = sp.getInt(PREF_STATS_DAY_DEFINE_PREFIX + day, 0);
            rows.add(new String[]{
                    _statsDayLabel(day),
                    _formatMmSs(sec),
                    String.format(Locale.US, "%.1f", sec / 60.0f),
                    String.valueOf(sessions),
                    String.valueOf(defines)
            });
        }
        return rows;
    }

    private MaterialCardView _buildStatsTableCard(String title, String[] headers, ArrayList<String[]> rows, int pad) {
        MaterialCardView card = new MaterialCardView(this);
        card.setRadius(getResources().getDisplayMetrics().density * 12);
        card.setCardBackgroundColor(Color.parseColor("#FFFFFF"));
        card.setStrokeColor(Color.parseColor("#E5E7EB"));
        card.setStrokeWidth((int) (getResources().getDisplayMetrics().density * 1));
        card.setCardElevation(getResources().getDisplayMetrics().density * 1.5f);

        LinearLayout box = new LinearLayout(this);
        box.setOrientation(LinearLayout.VERTICAL);
        box.setPadding(pad, pad, pad, pad);

        TextView titleView = new TextView(this);
        titleView.setText(title);
        titleView.setTextColor(Color.parseColor("#111827"));
        titleView.setTextSize(15f);
        titleView.setTypeface(Typeface.DEFAULT_BOLD);
        box.addView(titleView);

        TableLayout table = new TableLayout(this);
        LinearLayout.LayoutParams tableLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
        );
        tableLp.topMargin = (int) (getResources().getDisplayMetrics().density * 8);
        table.setLayoutParams(tableLp);
        table.setStretchAllColumns(true);

        TableRow headerRow = new TableRow(this);
        headerRow.setBackgroundColor(Color.parseColor("#F8FAFC"));
        for (String h : headers) {
            TextView tv = new TextView(this);
            tv.setText(String.valueOf(h));
            tv.setTextColor(Color.parseColor("#334155"));
            tv.setTextSize(12f);
            tv.setTypeface(Typeface.DEFAULT_BOLD);
            tv.setPadding(
                    (int) (getResources().getDisplayMetrics().density * 8),
                    (int) (getResources().getDisplayMetrics().density * 6),
                    (int) (getResources().getDisplayMetrics().density * 8),
                    (int) (getResources().getDisplayMetrics().density * 6)
            );
            headerRow.addView(tv);
        }
        table.addView(headerRow);

        if (rows == null || rows.isEmpty()) {
            TableRow emptyRow = new TableRow(this);
            TextView tv = new TextView(this);
            tv.setText("履歴はまだありません");
            tv.setTextColor(Color.parseColor("#64748B"));
            tv.setTextSize(12f);
            tv.setPadding(
                    (int) (getResources().getDisplayMetrics().density * 8),
                    (int) (getResources().getDisplayMetrics().density * 8),
                    (int) (getResources().getDisplayMetrics().density * 8),
                    (int) (getResources().getDisplayMetrics().density * 8)
            );
            emptyRow.addView(tv);
            table.addView(emptyRow);
        } else {
            for (int i = 0; i < rows.size(); i++) {
                String[] r = rows.get(i);
                TableRow bodyRow = new TableRow(this);
                if ((i % 2) == 1) {
                    bodyRow.setBackgroundColor(Color.parseColor("#FCFDFF"));
                }
                for (String v : r) {
                    TextView tv = new TextView(this);
                    tv.setText(String.valueOf(v));
                    tv.setTextColor(Color.parseColor("#0F172A"));
                    tv.setTextSize(12f);
                    tv.setPadding(
                            (int) (getResources().getDisplayMetrics().density * 8),
                            (int) (getResources().getDisplayMetrics().density * 6),
                            (int) (getResources().getDisplayMetrics().density * 8),
                            (int) (getResources().getDisplayMetrics().density * 6)
                    );
                    bodyRow.addView(tv);
                }
                table.addView(bodyRow);
            }
        }

        box.addView(table);
        card.addView(box);
        return card;
    }

    private void _statsOnCallStarted() {
        studySessionStartMs = System.currentTimeMillis();
        _incTodayCounter(PREF_STATS_DAY_SESSIONS_PREFIX);
    }

    private void _statsOnCallEnded() {
        if (studySessionStartMs <= 0L) return;
        long now = System.currentTimeMillis();
        long deltaMs = Math.max(0L, now - studySessionStartMs);
        long secs = deltaMs / 1000L;
        studySessionStartMs = 0L;
        _addStudySeconds(secs);
    }

    private void _showStatsDialog() {
        try {
            SharedPreferences sp = getSharedPreferences(PREFS_NAME, MODE_PRIVATE);
            String k = _todayKey();
            long secToday = sp.getLong(PREF_STATS_DAY_SECONDS_PREFIX + k, 0L);
            int sessionsToday = sp.getInt(PREF_STATS_DAY_SESSIONS_PREFIX + k, 0);
            int defineToday = sp.getInt(PREF_STATS_DAY_DEFINE_PREFIX + k, 0);

            // Root UI
            int pad = (int) (getResources().getDisplayMetrics().density * 16);
            LinearLayout root = new LinearLayout(this);
            root.setOrientation(LinearLayout.VERTICAL);
            root.setPadding(pad, pad, pad, pad);
            root.setAlpha(0f);
            root.setTranslationY(getResources().getDisplayMetrics().density * 14);

            // Summary row
            LinearLayout row = new LinearLayout(this);
            row.setOrientation(LinearLayout.HORIZONTAL);
            row.setPadding(0, 0, 0, (int) (getResources().getDisplayMetrics().density * 12));

            LinearLayout.LayoutParams cellLp = new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f);
            cellLp.setMarginEnd((int) (getResources().getDisplayMetrics().density * 8));
            LinearLayout.LayoutParams cellLpLast = new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f);

            MaterialCardView c1 = new MaterialCardView(this);
            c1.setLayoutParams(cellLp);
            c1.setRadius(getResources().getDisplayMetrics().density * 12);
            c1.setCardBackgroundColor(Color.parseColor("#F0F9FF"));
            c1.setStrokeColor(Color.parseColor("#E5E7EB"));
            c1.setStrokeWidth((int) (getResources().getDisplayMetrics().density * 1));
            c1.setCardElevation(getResources().getDisplayMetrics().density * 1.5f);

            MaterialCardView c2 = new MaterialCardView(this);
            c2.setLayoutParams(cellLp);
            c2.setRadius(getResources().getDisplayMetrics().density * 12);
            c2.setCardBackgroundColor(Color.parseColor("#F0FDF4"));
            c2.setStrokeColor(Color.parseColor("#E5E7EB"));
            c2.setStrokeWidth((int) (getResources().getDisplayMetrics().density * 1));
            c2.setCardElevation(getResources().getDisplayMetrics().density * 1.5f);

            MaterialCardView c3 = new MaterialCardView(this);
            c3.setLayoutParams(cellLpLast);
            c3.setRadius(getResources().getDisplayMetrics().density * 12);
            c3.setCardBackgroundColor(Color.parseColor("#FFF7ED"));
            c3.setStrokeColor(Color.parseColor("#E5E7EB"));
            c3.setStrokeWidth((int) (getResources().getDisplayMetrics().density * 1));
            c3.setCardElevation(getResources().getDisplayMetrics().density * 1.5f);

            LinearLayout box1 = new LinearLayout(this);
            box1.setOrientation(LinearLayout.VERTICAL);
            box1.setPadding(pad, pad, pad, pad);
            TextView tv1a = new TextView(this);
            tv1a.setTextColor(Color.parseColor("#334155"));
            tv1a.setTextSize(12f);
            tv1a.setText("今日の学習時間");
            TextView tv1b = new TextView(this);
            tv1b.setTextColor(Color.parseColor("#0F172A"));
            tv1b.setTextSize(20f);
            tv1b.setTypeface(Typeface.DEFAULT_BOLD);
            tv1b.setText(_formatMmSs(secToday));
            box1.addView(tv1a);
            box1.addView(tv1b);
            c1.addView(box1);

            LinearLayout box2 = new LinearLayout(this);
            box2.setOrientation(LinearLayout.VERTICAL);
            box2.setPadding(pad, pad, pad, pad);
            TextView tv2a = new TextView(this);
            tv2a.setTextColor(Color.parseColor("#334155"));
            tv2a.setTextSize(12f);
            tv2a.setText("今日の会話");
            TextView tv2b = new TextView(this);
            tv2b.setTextColor(Color.parseColor("#0F172A"));
            tv2b.setTextSize(20f);
            tv2b.setTypeface(Typeface.DEFAULT_BOLD);
            tv2b.setText(String.valueOf(sessionsToday));
            box2.addView(tv2a);
            box2.addView(tv2b);
            c2.addView(box2);

            LinearLayout box3 = new LinearLayout(this);
            box3.setOrientation(LinearLayout.VERTICAL);
            box3.setPadding(pad, pad, pad, pad);
            TextView tv3a = new TextView(this);
            tv3a.setTextColor(Color.parseColor("#334155"));
            tv3a.setTextSize(12f);
            tv3a.setText("今日の単語検索");
            TextView tv3b = new TextView(this);
            tv3b.setTextColor(Color.parseColor("#0F172A"));
            tv3b.setTextSize(20f);
            tv3b.setTypeface(Typeface.DEFAULT_BOLD);
            tv3b.setText(String.valueOf(defineToday));
            box3.addView(tv3a);
            box3.addView(tv3b);
            c3.addView(box3);

            row.addView(c1);
            row.addView(c2);
            row.addView(c3);
            root.addView(row);

            ArrayList<String[]> allRows = _buildStatsHistoryRows(sp, 60);
            ArrayList<String[]> durationRows = new ArrayList<>();
            ArrayList<String[]> sessionRows = new ArrayList<>();
            ArrayList<String[]> defineRows = new ArrayList<>();
            for (String[] r : allRows) {
                if (r == null || r.length < 5) continue;
                durationRows.add(new String[]{r[0], r[1], r[2]});
                sessionRows.add(new String[]{r[0], r[3]});
                defineRows.add(new String[]{r[0], r[4]});
            }

            TextView tableHint = new TextView(this);
            tableHint.setText("履歴統計（スワイプで切り替え）");
            tableHint.setTextColor(Color.parseColor("#334155"));
            tableHint.setTextSize(13f);
            LinearLayout.LayoutParams hintLp = new LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
            );
            hintLp.topMargin = (int) (getResources().getDisplayMetrics().density * 12);
            tableHint.setLayoutParams(hintLp);
            root.addView(tableHint);

            LinearLayout pagerRow = new LinearLayout(this);
            pagerRow.setOrientation(LinearLayout.HORIZONTAL);
            pagerRow.setGravity(android.view.Gravity.CENTER_VERTICAL);
            LinearLayout.LayoutParams pagerLp = new LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
            );
            pagerLp.topMargin = (int) (getResources().getDisplayMetrics().density * 4);
            pagerRow.setLayoutParams(pagerLp);

            MaterialButton btnPrevPage = new MaterialButton(this, null, com.google.android.material.R.attr.materialButtonOutlinedStyle);
            btnPrevPage.setText("<");
            btnPrevPage.setInsetTop(0);
            btnPrevPage.setInsetBottom(0);
            btnPrevPage.setMinHeight((int) (getResources().getDisplayMetrics().density * 34));
            btnPrevPage.setMinimumHeight((int) (getResources().getDisplayMetrics().density * 34));

            TextView pageIndicator = new TextView(this);
            pageIndicator.setText("1/5");
            pageIndicator.setTextColor(Color.parseColor("#64748B"));
            pageIndicator.setTextSize(12f);
            pageIndicator.setGravity(android.view.Gravity.CENTER);
            LinearLayout.LayoutParams pageTextLp = new LinearLayout.LayoutParams(
                    0,
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                    1f
            );
            pageIndicator.setLayoutParams(pageTextLp);

            MaterialButton btnNextPage = new MaterialButton(this, null, com.google.android.material.R.attr.materialButtonOutlinedStyle);
            btnNextPage.setText(">");
            btnNextPage.setInsetTop(0);
            btnNextPage.setInsetBottom(0);
            btnNextPage.setMinHeight((int) (getResources().getDisplayMetrics().density * 34));
            btnNextPage.setMinimumHeight((int) (getResources().getDisplayMetrics().density * 34));

            pagerRow.addView(btnPrevPage);
            pagerRow.addView(pageIndicator);
            pagerRow.addView(btnNextPage);
            root.addView(pagerRow);

            HorizontalScrollView tablesScroll = new HorizontalScrollView(this);
            tablesScroll.setHorizontalScrollBarEnabled(false);
            tablesScroll.setFillViewport(true);
            LinearLayout.LayoutParams scrollLp = new LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
            );
            scrollLp.topMargin = (int) (getResources().getDisplayMetrics().density * 8);
            tablesScroll.setLayoutParams(scrollLp);

            LinearLayout tablesRow = new LinearLayout(this);
            tablesRow.setOrientation(LinearLayout.HORIZONTAL);
            int cardGap = (int) (getResources().getDisplayMetrics().density * 12);
            int cardMinWidth = (int) (getResources().getDisplayMetrics().widthPixels * 0.86f);
            int pageStep = cardMinWidth + cardGap;

            MaterialCardView chartCard = new MaterialCardView(this);
            chartCard.setRadius(getResources().getDisplayMetrics().density * 12);
            chartCard.setCardBackgroundColor(Color.parseColor("#FFFFFF"));
            chartCard.setStrokeColor(Color.parseColor("#E5E7EB"));
            chartCard.setStrokeWidth((int) (getResources().getDisplayMetrics().density * 1));
            chartCard.setCardElevation(getResources().getDisplayMetrics().density * 1.5f);
            LinearLayout.LayoutParams lpChart = new LinearLayout.LayoutParams(cardMinWidth, LinearLayout.LayoutParams.WRAP_CONTENT);
            lpChart.setMarginEnd(cardGap);
            chartCard.setLayoutParams(lpChart);

            LinearLayout chartBox = new LinearLayout(this);
            chartBox.setOrientation(LinearLayout.VERTICAL);
            chartBox.setPadding(pad, pad, pad, pad);
            TextView chartTitle = new TextView(this);
            chartTitle.setTextColor(Color.parseColor("#111827"));
            chartTitle.setTextSize(15f);
            chartTitle.setTypeface(Typeface.DEFAULT_BOLD);
            chartTitle.setText("過去7日間のトレンド（分＋会話）");
            chartBox.addView(chartTitle);

            LineChart chart = new LineChart(this);
            LinearLayout.LayoutParams chartLp = new LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    (int) (getResources().getDisplayMetrics().density * 230)
            );
            chartLp.topMargin = (int) (getResources().getDisplayMetrics().density * 8);
            chart.setLayoutParams(chartLp);

            java.util.ArrayList<Entry> entries = new java.util.ArrayList<>();
            java.util.ArrayList<Entry> entriesSessions = new java.util.ArrayList<>();
            java.util.ArrayList<String> labels = new java.util.ArrayList<>();
            java.util.Calendar cal = java.util.Calendar.getInstance();
            cal.setTime(new java.util.Date());
            cal.add(java.util.Calendar.DAY_OF_YEAR, -6);
            java.text.SimpleDateFormat keyFmt = new java.text.SimpleDateFormat("yyyyMMdd", java.util.Locale.US);
            java.text.SimpleDateFormat labFmt = new java.text.SimpleDateFormat("MM/dd", java.util.Locale.US);
            for (int i = 0; i < 7; i++) {
                String key = keyFmt.format(cal.getTime());
                String lab = labFmt.format(cal.getTime());
                long sec = sp.getLong(PREF_STATS_DAY_SECONDS_PREFIX + key, 0L);
                float minutes = sec / 60.0f;
                int sessions = sp.getInt(PREF_STATS_DAY_SESSIONS_PREFIX + key, 0);
                entries.add(new Entry(i, minutes));
                entriesSessions.add(new Entry(i, (float) sessions));
                labels.add(lab);
                cal.add(java.util.Calendar.DAY_OF_YEAR, 1);
            }

            LineDataSet set = new LineDataSet(entries, "minutes");
            set.setColor(Color.parseColor("#0EA5E9"));
            set.setLineWidth(2.2f);
            set.setCircleColor(Color.parseColor("#0EA5E9"));
            set.setCircleRadius(3.8f);
            set.setDrawCircleHole(false);
            set.setValueTextSize(10f);
            set.setValueTextColor(Color.parseColor("#111827"));
            set.setMode(LineDataSet.Mode.CUBIC_BEZIER);
            set.setDrawFilled(true);
            set.setFillColor(Color.parseColor("#0EA5E9"));
            set.setFillAlpha(35);
            set.setValueFormatter(new ValueFormatter() {
                @Override
                public String getPointLabel(Entry entry) {
                    if (entry == null) return "";
                    if (entry.getY() <= 0.01f) return "";
                    return String.format(java.util.Locale.US, "%.0f", entry.getY());
                }
            });

            LineDataSet setSessions = new LineDataSet(entriesSessions, "sessions");
            setSessions.setColor(Color.parseColor("#F97316"));
            setSessions.setLineWidth(2.0f);
            setSessions.setCircleColor(Color.parseColor("#F97316"));
            setSessions.setCircleRadius(3.8f);
            setSessions.setDrawCircleHole(false);
            setSessions.setValueTextSize(10f);
            setSessions.setValueTextColor(Color.parseColor("#111827"));
            setSessions.setMode(LineDataSet.Mode.CUBIC_BEZIER);
            setSessions.setDrawFilled(false);
            setSessions.setAxisDependency(YAxis.AxisDependency.RIGHT);
            setSessions.setValueFormatter(new ValueFormatter() {
                @Override
                public String getPointLabel(Entry entry) {
                    if (entry == null) return "";
                    if (entry.getY() <= 0.01f) return "";
                    return String.format(java.util.Locale.US, "%.0f", entry.getY());
                }
            });

            LineData data = new LineData(set, setSessions);
            chart.setData(data);
            chart.getDescription().setEnabled(false);
            chart.getLegend().setEnabled(false);
            chart.setTouchEnabled(false);
            chart.setDragEnabled(false);
            chart.setScaleEnabled(false);
            chart.setPinchZoom(false);

            XAxis xAxis = chart.getXAxis();
            xAxis.setPosition(XAxis.XAxisPosition.BOTTOM);
            xAxis.setGranularity(1f);
            xAxis.setDrawGridLines(false);
            xAxis.setTextColor(Color.parseColor("#64748B"));
            xAxis.setTextSize(11f);
            xAxis.setValueFormatter(new ValueFormatter() {
                @Override
                public String getAxisLabel(float value, AxisBase axis) {
                    int idx = (int) value;
                    if (idx < 0 || idx >= labels.size()) return "";
                    return labels.get(idx);
                }
            });

            YAxis left = chart.getAxisLeft();
            left.setTextColor(Color.parseColor("#64748B"));
            left.setTextSize(11f);
            left.setAxisMinimum(0f);
            left.setDrawGridLines(true);
            left.setGridColor(Color.parseColor("#E5E7EB"));
            left.setValueFormatter(new ValueFormatter() {
                @Override
                public String getAxisLabel(float value, AxisBase axis) {
                    if (value <= 0.01f) return "0";
                    return String.format(java.util.Locale.US, "%.0f", value);
                }
            });

            YAxis right = chart.getAxisRight();
            right.setEnabled(true);
            right.setTextColor(Color.parseColor("#64748B"));
            right.setTextSize(11f);
            right.setAxisMinimum(0f);
            right.setDrawGridLines(false);
            right.setValueFormatter(new ValueFormatter() {
                @Override
                public String getAxisLabel(float value, AxisBase axis) {
                    if (value <= 0.01f) return "0";
                    return String.format(java.util.Locale.US, "%.0f", value);
                }
            });
            chart.invalidate();

            chartBox.addView(chart);
            chartCard.addView(chartBox);

            MaterialCardView allCard = _buildStatsTableCard(
                    "総合履歴（学習時間＋会話＋単語検索）",
                    new String[]{"日付", "時間", "分", "会話", "単語検索"},
                    allRows,
                    pad
            );
            LinearLayout.LayoutParams lpAll = new LinearLayout.LayoutParams(cardMinWidth, LinearLayout.LayoutParams.WRAP_CONTENT);
            lpAll.setMarginEnd(cardGap);
            allCard.setLayoutParams(lpAll);

            MaterialCardView durationCard = _buildStatsTableCard(
                    "時間历史",
                    new String[]{"日付", "時間", "分"},
                    durationRows,
                    pad
            );
            LinearLayout.LayoutParams lpDuration = new LinearLayout.LayoutParams(cardMinWidth, LinearLayout.LayoutParams.WRAP_CONTENT);
            lpDuration.setMarginEnd(cardGap);
            durationCard.setLayoutParams(lpDuration);

            MaterialCardView sessionCard = _buildStatsTableCard(
                    "会話历史",
                    new String[]{"日付", "会話次数"},
                    sessionRows,
                    pad
            );
            LinearLayout.LayoutParams lpSession = new LinearLayout.LayoutParams(cardMinWidth, LinearLayout.LayoutParams.WRAP_CONTENT);
            lpSession.setMarginEnd(cardGap);
            sessionCard.setLayoutParams(lpSession);

            MaterialCardView defineCard = _buildStatsTableCard(
                    "単語検索历史",
                    new String[]{"日付", "単語検索次数"},
                    defineRows,
                    pad
            );
            LinearLayout.LayoutParams lpDefine = new LinearLayout.LayoutParams(cardMinWidth, LinearLayout.LayoutParams.WRAP_CONTENT);
            defineCard.setLayoutParams(lpDefine);

            tablesRow.addView(chartCard);
            tablesRow.addView(allCard);
            tablesRow.addView(durationCard);
            tablesRow.addView(sessionCard);
            tablesRow.addView(defineCard);
            tablesScroll.addView(tablesRow);
            root.addView(tablesScroll);

            final int totalPages = 5;
            final Runnable updatePagerUi = () -> {
                int page = Math.round((float) tablesScroll.getScrollX() / (float) Math.max(1, pageStep));
                if (page < 0) page = 0;
                if (page > totalPages - 1) page = totalPages - 1;
                pageIndicator.setText((page + 1) + "/" + totalPages);
                btnPrevPage.setEnabled(page > 0);
                btnNextPage.setEnabled(page < (totalPages - 1));
            };

            btnPrevPage.setOnClickListener(v -> {
                int page = Math.round((float) tablesScroll.getScrollX() / (float) Math.max(1, pageStep));
                page = Math.max(0, page - 1);
                tablesScroll.smoothScrollTo(page * pageStep, 0);
                tablesScroll.post(updatePagerUi);
            });
            btnNextPage.setOnClickListener(v -> {
                int page = Math.round((float) tablesScroll.getScrollX() / (float) Math.max(1, pageStep));
                page = Math.min(totalPages - 1, page + 1);
                tablesScroll.smoothScrollTo(page * pageStep, 0);
                tablesScroll.post(updatePagerUi);
            });

            tablesScroll.setOnTouchListener((v, event) -> {
                int action = event.getActionMasked();
                if (action == MotionEvent.ACTION_UP || action == MotionEvent.ACTION_CANCEL) {
                    tablesScroll.post(() -> {
                        int page = Math.round((float) tablesScroll.getScrollX() / (float) Math.max(1, pageStep));
                        if (page < 0) page = 0;
                        if (page > totalPages - 1) page = totalPages - 1;
                        tablesScroll.smoothScrollTo(page * pageStep, 0);
                        tablesScroll.post(updatePagerUi);
                    });
                }
                return false;
            });
            tablesScroll.getViewTreeObserver().addOnScrollChangedListener(() -> {
                updatePagerUi.run();
            });
            tablesScroll.post(updatePagerUi);

            AlertDialog dlg = new MaterialAlertDialogBuilder(this)
                    .setTitle("学習統計")
                    .setView(root)
                    .setPositiveButton("了解しました", (d, w) -> d.dismiss())
                    .create();
            dlg.show();

            root.post(() -> {
                try {
                    root.animate()
                            .alpha(1f)
                            .translationY(0f)
                            .setDuration(280)
                            .setInterpolator(new DecelerateInterpolator())
                            .start();

                    View[] cards = new View[]{c1, c2, c3, allCard, durationCard, sessionCard, defineCard};
                    for (int i = 0; i < cards.length; i++) {
                        View v = cards[i];
                        if (v == null) continue;
                        v.setAlpha(0f);
                        v.setScaleX(0.96f);
                        v.setScaleY(0.96f);
                        v.animate()
                                .alpha(1f)
                                .scaleX(1f)
                                .scaleY(1f)
                                .setStartDelay(60L * i)
                                .setDuration(260)
                                .setInterpolator(new DecelerateInterpolator())
                                .start();
                    }
                } catch (Exception ignored) {
                }
            });
        } catch (Exception ignored) {
        }
    }

    private void updatePlayVideoButtonUi() {
        if (playVideoButton == null) return;
        try {
            boolean enabled = hasSelectedTopicVideo();
            playVideoButton.setEnabled(enabled);
            playVideoButton.setAlpha(enabled ? 1.0f : 0.4f);
        } catch (Exception ignored) {
        }
    }

    private boolean hasSelectedTopicVideo() {
        String vu = (selectedTopicVideoUrl != null) ? selectedTopicVideoUrl.trim() : "";
        return !vu.isEmpty();
    }

    private void openSelectedTopicVideo(boolean continueAfterVideo) {
        try {
            String vu = (selectedTopicVideoUrl != null) ? selectedTopicVideoUrl.trim() : "";
            if (vu.isEmpty()) {
                pendingCourseVideoConversation = false;
                courseIntroPendingStart = false;
                if (continueAfterVideo) {
                    startAiConversationFlow();
                } else {
                    Toast.makeText(MainActivity.this, "このトピックには動画がありません", Toast.LENGTH_SHORT).show();
                }
                return;
            }
            if (!_tutorialDone() && _tutorialStep() == 2) {
                _setTutorialStep(3);
            }
            pendingCourseVideoConversation = continueAfterVideo;
            courseIntroPendingStart = continueAfterVideo;
            Intent it = new Intent(MainActivity.this, VideoPlayerActivity.class);
            it.putExtra("video_url", vu);
            if (selectedTopicVideoStreams != null && !selectedTopicVideoStreams.trim().isEmpty()) {
                it.putExtra("video_streams", selectedTopicVideoStreams);
            }
            if (continueAfterVideo) {
                startActivityForResult(it, REQ_PRECHAT_VIDEO);
            } else {
                startActivity(it);
            }
            mainHandler.post(this::_showTutorialStepIfNeeded);
        } catch (Exception e) {
            pendingCourseVideoConversation = false;
            courseIntroPendingStart = false;
            if (continueAfterVideo) {
                startAiConversationFlow();
            } else {
                Toast.makeText(MainActivity.this, "動画を開けませんでした", Toast.LENGTH_SHORT).show();
            }
        }
    }

    private void startSelectedCourseFromStage(int stage) {
        try {
            if (stopAnalyzePending || isJoiningOrJoined || isInRoom) {
                Toast.makeText(this, "まず会話を終了してからフローを切り替えてください", Toast.LENGTH_SHORT).show();
                return;
            }
            selectedLessonStartStage = Math.max(1, Math.min(3, stage));
            boolean hasTopic = selectedUnitId != null && !selectedUnitId.trim().isEmpty()
                    && selectedTopicId != null && !selectedTopicId.trim().isEmpty();
            if (!hasTopic) {
                Toast.makeText(this, "まずコースを選択してください", Toast.LENGTH_SHORT).show();
                return;
            }
            loadStructuredCourseFlow(this::maybeStartStructuredCourseOrConversation);
        } catch (Exception ignored) {
        }
    }

    private void showModeSelectionDialog() {
        if (stopAnalyzePending || isJoiningOrJoined || isInRoom) {
            Toast.makeText(this, "まず現在のの会話を終了してください", Toast.LENGTH_SHORT).show();
            return;
        }
        boolean hasTopic = selectedUnitId != null && !selectedUnitId.trim().isEmpty()
                && selectedTopicId != null && !selectedTopicId.trim().isEmpty();
        if (!hasTopic) {
            Toast.makeText(this, "まずコースを選択してください", Toast.LENGTH_SHORT).show();
            return;
        }

        new AlertDialog.Builder(this)
                .setTitle("モードを選択")
                .setItems(new String[]{"中国語質問", "英語質問", "自由質問"}, (dialog, which) -> {
                    if (which == 0) {
                        startMode(ModeType.CHINESE_QA);
                    } else if (which == 1) {
                        startMode(ModeType.ENGLISH_QA);
                    } else {
                        startMode(ModeType.FREE_QA);
                    }
                })
                .setNegativeButton("キャンセル", null)
                .show();
    }

    private void startMode(ModeType mode) {
        currentMode = mode;
        if (mode == ModeType.CHINESE_QA) {
            // Mode 1: same as old "中文提问" — go to stage 2 (skip video).
            selectedLessonStartStage = 2;
            loadStructuredCourseFlow(this::maybeStartStructuredCourseOrConversation);
        } else {
            // Mode 2 (ENGLISH_QA) & 3 (FREE_QA): free-chat style path.
            // Android shows the sentence list; the backend uses the mode flag
            // to build the appropriate system prompt.
            freeChatModeActive = true;
            loadStructuredCourseFlow(this::loadFreeChatAndStart);
        }
    }

    private void loadFreeChatAndStart() {
        if (!freeChatModeActive) return;
        String uid = selectedUnitId != null ? selectedUnitId.trim() : "";
        String tid = selectedTopicId != null ? selectedTopicId.trim() : "";
        if (uid.isEmpty() || tid.isEmpty()) {
            Toast.makeText(this, "まずコースを選択してください", Toast.LENGTH_SHORT).show();
            freeChatModeActive = false;
            return;
        }
        freeChatSentences.clear();

        // Load sentences from unit JSON.
        String unitUrl = AIConfigHelper.AGENT_API_BASE_URL + "/training/units/" + uid;
        Request unitReq = new Request.Builder().url(unitUrl).get().build();
        httpClient.newCall(unitReq).enqueue(new Callback() {
            @Override
            public void onFailure(@NonNull Call call, @NonNull IOException e) {
                runOnUiThread(() -> {
                    if (!freeChatModeActive) return;
                    Toast.makeText(MainActivity.this, "コース内容の読み込みに失敗しました", Toast.LENGTH_SHORT).show();
                    freeChatModeActive = false;
                });
            }

            @Override
            public void onResponse(@NonNull Call call, @NonNull Response response) throws IOException {
                if (response.isSuccessful()) {
                    try {
                        String resStr = response.body() != null ? response.body().string() : "";
                        JSONObject unit = new JSONObject(resStr);
                        JSONObject topic = findTopicInUnitJson(unit, tid);
                        if (topic != null) {
                            JSONArray reqSent = topic.optJSONArray("required_sentences");
                            if (reqSent != null) {
                                for (int i = 0; i < reqSent.length(); i++) {
                                    String s = reqSent.optString(i, "").trim();
                                    if (!s.isEmpty()) {
                                        freeChatSentences.add(s);
                                    }
                                }
                            }
                        }
                    } catch (Exception ignored) {}
                }
                runOnUiThread(() -> {
                    if (!freeChatModeActive) return;
                    joinRoomAndShowIntro();
                });
            }
        });
    }

    private void joinRoomAndShowIntro() {
        String stageText;
        int stageColor;
        switch (currentMode) {
            case CHINESE_QA:
                stageText = "中国語質問";
                stageColor = Color.parseColor("#7C3AED");
                break;
            case ENGLISH_QA:
                stageText = "英語質問";
                stageColor = Color.parseColor("#2563EB");
                break;
            case FREE_QA:
            default:
                stageText = "自由質問";
                stageColor = Color.parseColor("#059669");
                break;
        }
        if (courseStageTextView != null) {
            courseStageTextView.setText(stageText);
            courseStageTextView.setBackgroundColor(stageColor);
        }
        autoSummonAfterJoin = true;
        joinRoom();
        updateCallToggleUi();
    }

    private void showFreeChatOverlayAndStartConversation() {
        if (!freeChatModeActive) return;
        if (courseStageTextView != null) {
            courseStageTextView.setText("自由会話");
            courseStageTextView.setBackgroundColor(Color.parseColor("#059669"));
        }
        autoSummonAfterJoin = true;
        joinRoom();
        updateCallToggleUi();
    }

    @Override
    protected void onStop() {
        super.onStop();
        try {
            if (courseIntroPlaying) {
                stopCourseIntroPlayback(false);
            }
        } catch (Exception ignored) {
        }
        try {
            // If user backgrounds the app during a call, close the current segment for stats.
            if (wasInCallForStats) {
                wasInCallForStats = false;
                _statsOnCallEnded();
            }
        } catch (Exception ignored) {
        }
    }

    @Override
    protected void onDestroy() {
        try {
            stopCourseIntroPlayback(false);
        } catch (Exception ignored) {
        }
        super.onDestroy();
    }

    private ArrayList<String> defaultModulesForDifficulty(int d) {
        ArrayList<String> mods = new ArrayList<>();
        mods.add("repeat_fast");
        mods.add("exam_mix");
        if (d >= 3) {
            // Difficulty 3 default: add dialog in "original extension" style.
            mods.add("roleplay_extend_guided");
        }
        return mods;
    }

    private SharedPreferences _sp() {
        return getSharedPreferences(PREFS_NAME, MODE_PRIVATE);
    }

    private boolean _tutorialDone() {
        try {
            return _sp().getBoolean(PREF_TUTORIAL_DONE, false);
        } catch (Exception e) {
            return false;
        }
    }

    private int _tutorialStep() {
        try {
            int s = _sp().getInt(PREF_TUTORIAL_STEP, 1);
            if (s < 1) s = 1;
            if (s > 6) s = 6;
            return s;
        } catch (Exception e) {
            return 1;
        }
    }

    private void _setTutorialStep(int step) {
        try {
            _sp().edit().putInt(PREF_TUTORIAL_STEP, step).apply();
        } catch (Exception ignored) {
        }
    }

    private void _finishTutorial() {
        try {
            _sp().edit().putBoolean(PREF_TUTORIAL_DONE, true).apply();
        } catch (Exception ignored) {
        }
        _hideTutorialOverlay();
    }

    private void _ensureTutorialOverlay() {
        if (tutorialOverlay != null) return;
        try {
            ViewGroup root = (ViewGroup) getWindow().getDecorView();
            tutorialOverlay = new TutorialOverlayView(this);
            tutorialOverlay.setVisibility(View.GONE);
            root.addView(tutorialOverlay);
        } catch (Exception ignored) {
        }
    }

    private void _hideTutorialOverlay() {
        try {
            if (tutorialOverlay != null) {
                tutorialOverlay.setVisibility(View.GONE);
            }
            tutorialForceShow = false;
        } catch (Exception ignored) {
        }
    }

    private void _showTutorialStepIfNeeded() {
        if (!tutorialForceShow && _tutorialDone()) {
            _hideTutorialOverlay();
            return;
        }

        _ensureTutorialOverlay();
        if (tutorialOverlay == null) return;

        int step = _tutorialStep();
        if (step == 1) {
            View v = findViewById(R.id.btn_quick_course);
            if (v == null) return;
            tutorialOverlay.setSkipVisible(true);
            tutorialOverlay.setNextText("次へ");
            tutorialOverlay.setStep(
                    v,
                    "まずコースを選択",
                    "ここをタップしてレッスンを選択してください。",
                    () -> {
                        _setTutorialStep(2);
                        mainHandler.post(this::_showTutorialStepIfNeeded);
                    },
                    this::_finishTutorial
            );
            tutorialOverlay.setVisibility(View.VISIBLE);
            return;
        }
        if (step == 2) {
            View v = findViewById(R.id.btn_play_video);
            if (v == null) return;
            tutorialOverlay.setSkipVisible(true);
            tutorialOverlay.setNextText("次へ");
            tutorialOverlay.setStep(
                    v,
                    "デモ動画を見る",
                    "まずデモを見ると、よりスムーズに進められます。",
                    () -> {
                        _setTutorialStep(3);
                        mainHandler.post(this::_showTutorialStepIfNeeded);
                    },
                    this::_finishTutorial
            );
            tutorialOverlay.setVisibility(View.VISIBLE);
            return;
        }
        if (step == 3) {
            View v = findViewById(R.id.btn_quick_difficulty);
            if (v == null) return;
            tutorialOverlay.setSkipVisible(true);
            tutorialOverlay.setNextText("次へ");
            tutorialOverlay.setStep(
                    v,
                    "練習モードを選択（1/2）",
                    "点这里切换到“シャドウイング+試験”模式。",
                    () -> {
                        _setTutorialStep(4);
                        mainHandler.post(this::_showTutorialStepIfNeeded);
                    },
                    this::_finishTutorial
            );
            tutorialOverlay.setVisibility(View.VISIBLE);
            return;
        }
        if (step == 4) {
            View v = findViewById(R.id.btn_quick_plus);
            if (v == null) return;
            tutorialOverlay.setSkipVisible(true);
            tutorialOverlay.setNextText("次へ");
            tutorialOverlay.setStep(
                    v,
                    "練習モードを選択（2/2）",
                    "点这里进入自由会話模式.",
                    () -> {
                        _setTutorialStep(5);
                        mainHandler.post(this::_showTutorialStepIfNeeded);
                    },
                    this::_finishTutorial
            );
            tutorialOverlay.setVisibility(View.VISIBLE);
            return;
        }
        if (step == 5) {
            View v = findViewById(R.id.btn_call_toggle);
            if (v == null) return;
            tutorialOverlay.setSkipVisible(true);
            tutorialOverlay.setNextText("次へ");
            tutorialOverlay.setStep(
                    v,
                    "会話を始める",
                    "点这里会話を始める练习。",
                    () -> {
                        _setTutorialStep(6);
                        mainHandler.post(this::_showTutorialStepIfNeeded);
                    },
                    this::_finishTutorial
            );
            tutorialOverlay.setVisibility(View.VISIBLE);
            return;
        }
        if (step == 6) {
            View v = findViewById(R.id.btn_call_toggle);
            if (v == null) return;
            tutorialOverlay.setSkipVisible(false);
            tutorialOverlay.setNextText("チュートリアルを完了");
            tutorialOverlay.setStep(
                    v,
                    "会話を終了",
                    "終了時にここをタップすると、今回のまとめが生成されます。",
                    this::_finishTutorial,
                    this::_finishTutorial
            );
            tutorialOverlay.setVisibility(View.VISIBLE);
        }
    }

    private String _currentUsername() {
        try {
            String u = _sp().getString(PREF_USERNAME, null);
            if (u == null) return "";
            return u.trim();
        } catch (Exception e) {
            return "";
        }
    }

    private String _historyItemsKey() {
        String u = _currentUsername();
        if (u == null || u.trim().isEmpty()) return PREF_HISTORY_ITEMS;
        return PREF_HISTORY_ITEMS + ":" + u.trim();
    }

    private String _historyByJobKey() {
        String u = _currentUsername();
        if (u == null || u.trim().isEmpty()) return PREF_HISTORY_BY_JOB;
        return PREF_HISTORY_BY_JOB + ":" + u.trim();
    }

    private JSONArray _loadLocalHistoryItems() {
        try {
            String s = _sp().getString(_historyItemsKey(), null);
            if (s != null && !s.trim().isEmpty()) {
                return new JSONArray(s);
            }

            String owner = _sp().getString(PREF_HISTORY_LEGACY_OWNER, null);
            String cur = _currentUsername();
            if (owner != null && cur != null && !cur.trim().isEmpty() && !owner.trim().equalsIgnoreCase(cur.trim())) {
                return new JSONArray();
            }

            String legacy = _sp().getString(PREF_HISTORY_ITEMS, null);
            if (legacy == null || legacy.trim().isEmpty()) return new JSONArray();
            JSONArray legacyArr = new JSONArray(legacy);

            if (cur != null && !cur.trim().isEmpty()) {
                _sp().edit().putString(_historyItemsKey(), legacyArr.toString()).putString(PREF_HISTORY_LEGACY_OWNER, cur.trim()).apply();
            }
            return legacyArr;
        } catch (Exception e) {
            return new JSONArray();
        }
    }

    private JSONObject _loadLocalHistoryByJob() {
        try {
            String s = _sp().getString(_historyByJobKey(), null);
            if (s != null && !s.trim().isEmpty()) {
                return new JSONObject(s);
            }

            String owner = _sp().getString(PREF_HISTORY_LEGACY_OWNER, null);
            String cur = _currentUsername();
            if (owner != null && cur != null && !cur.trim().isEmpty() && !owner.trim().equalsIgnoreCase(cur.trim())) {
                return new JSONObject();
            }

            String legacy = _sp().getString(PREF_HISTORY_BY_JOB, null);
            if (legacy == null || legacy.trim().isEmpty()) return new JSONObject();
            JSONObject legacyObj = new JSONObject(legacy);
            if (cur != null && !cur.trim().isEmpty()) {
                _sp().edit().putString(_historyByJobKey(), legacyObj.toString()).putString(PREF_HISTORY_LEGACY_OWNER, cur.trim()).apply();
            }
            return legacyObj;
        } catch (Exception e) {
            return new JSONObject();
        }
    }

    private void _saveLocalHistory(JSONArray items, JSONObject byJob) {
        _sp().edit()
                .putString(_historyItemsKey(), items.toString())
                .putString(_historyByJobKey(), byJob.toString())
                .apply();
    }

    private static String _shortTime(String iso) {
        if (iso == null) return "";
        String s = iso.trim();
        if (s.length() >= 19) {
            return s.substring(0, 19).replace('T', ' ');
        }
        return s;
    }

    private static boolean _isNullish(String v) {
        if (v == null) return true;
        String t = v.trim();
        if (t.isEmpty()) return true;
        return "null".equalsIgnoreCase(t);
    }

    private static String _safeOptString(JSONObject obj, String key) {
        if (obj == null) return "";
        String v = obj.optString(key, "");
        return _isNullish(v) ? "" : v;
    }

    private static double _avgScoreFromAnalysis(JSONObject analysis) {
        if (analysis == null) return -1;
        JSONObject scores = analysis.optJSONObject("scores");
        if (scores == null) return -1;
        return scores.optDouble("overall_score", -1);
    }

    private static String _fmtScoreField(JSONObject obj, String key) {
        try {
            if (obj == null) return "N/A";
            if (!obj.has(key) || obj.isNull(key)) return "N/A";
            Object v = obj.opt(key);
            if (v == null || v == JSONObject.NULL) return "N/A";
            if (v instanceof Number) {
                double d = ((Number) v).doubleValue();
                if (Math.abs(d - Math.rint(d)) < 1e-9) {
                    return String.valueOf((int) Math.rint(d));
                }
                return String.format(Locale.ROOT, "%.2f", d);
            }
            String s = String.valueOf(v).trim();
            if (s.isEmpty() || "null".equalsIgnoreCase(s)) return "N/A";
            return s;
        } catch (Exception ignored) {
            return "N/A";
        }
    }

    private void saveHistoryRecordLocal(JSONObject jobObj) {
        if (jobObj == null) return;
        String jobId = jobObj.optString("job_id", "");
        if (jobId == null || jobId.trim().isEmpty()) return;

        try {
            JSONObject result = jobObj.optJSONObject("result");
            JSONObject analysis = result != null ? result.optJSONObject("analysis") : null;

            JSONObject summary = new JSONObject();
            summary.put("user_id", _currentUsername());
            summary.put("job_id", jobId);
            summary.put("created_at", jobObj.optString("created_at", jobObj.optString("started_at", "")));
            summary.put("status", jobObj.optString("status", ""));
            summary.put("task_id", jobObj.optString("task_id", ""));
            summary.put("chapter_id", _safeOptString(jobObj, "chapter_id"));
            summary.put("topic_id", _safeOptString(jobObj, "topic_id"));
            summary.put("unit_id", _safeOptString(jobObj, "unit_id"));
            summary.put("difficulty", jobObj.optInt("difficulty", -1));
            summary.put("mode", jobObj.optString("mode", ""));
            double avg = _avgScoreFromAnalysis(analysis);
            summary.put("avg_score", avg);

            JSONArray items = _loadLocalHistoryItems();
            JSONObject byJob = _loadLocalHistoryByJob();

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

            _saveLocalHistory(items, byJob);
        } catch (Exception e) {
            Log.e(TAG, "saveHistoryRecordLocal failed: " + e.getMessage());
        }
    }


    private void postUtteranceToBackend(String speakerUserId, String text, int roundId, int sequence, boolean definite, boolean paragraph, boolean runLlm, Integer utteranceId) {
        try {
            if (currentSessionId == null || currentSessionId.trim().isEmpty()) {
                return;
            }
            JSONObject payload = new JSONObject();
            payload.put("room_id", currentRoomId);
            payload.put("user_id", currentUserId);
            payload.put("client_id", currentClientId);
            payload.put("session_id", currentSessionId);
            payload.put("speaker_user_id", speakerUserId);
            payload.put("text", text);
            payload.put("round_id", roundId);
            payload.put("sequence", sequence);
            payload.put("definite", definite);
            payload.put("paragraph", paragraph);
            payload.put("run_llm", runLlm);
            if (utteranceId != null) {
                payload.put("utterance_id", utteranceId.intValue());
            }

            String url = AIConfigHelper.AGENT_API_BASE_URL + "/sessions/utterance";
            RequestBody body = RequestBody.create(payload.toString(), MediaType.parse("application/json; charset=utf-8"));
            Request req = new Request.Builder().url(url).post(body).build();
            httpClient.newCall(req).enqueue(new Callback() {
                @Override
                public void onFailure(@NonNull Call call, @NonNull IOException e) {
                    Log.e(TAG, "utterance post failed: " + e.getMessage());
                }

                @Override
                public void onResponse(@NonNull Call call, @NonNull Response response) throws IOException {
                    String resStr = response.body() != null ? response.body().string() : "";
                    Log.d(TAG, "utterance post resp=" + response.code() + " body=" + resStr);

                    if (response.isSuccessful()
                            && currentUserId != null
                            && currentUserId.equals(speakerUserId)
                            && definite
                            && paragraph
                            && utteranceId != null) {
                        pollPronunciationAndShow(roundId, sequence, utteranceId.intValue(), text);
                    }
                }
            });
        } catch (Exception e) {
            Log.e(TAG, "utterance post build failed: " + e.getMessage());
        }
    }

    private void pollPronunciationAndShow(int roundId, int sequence, int utteranceId, String refText) {
        final int maxTries = 20;
        final long intervalMs = 600;
        Handler h = new Handler(Looper.getMainLooper());

        Runnable[] taskRef = new Runnable[1];
        taskRef[0] = new Runnable() {
            int tries = 0;

            @Override
            public void run() {
                tries++;
                fetchPronunciationOnce(roundId, sequence, utteranceId, refText, new PronunciationCallback() {
                    @Override
                    public void onResult(JSONObject pronunciation) {
                        appendPronunciationToConversation(refText, pronunciation);
                    }

                    @Override
                    public void onNotReady() {
                        if (tries >= maxTries) {
                            return;
                        }
                        h.postDelayed(taskRef[0], intervalMs);
                    }

                    @Override
                    public void onError(String msg) {
                        Log.e(TAG, "poll pronunciation error: " + msg);
                    }
                });
            }
        };

        h.postDelayed(taskRef[0], intervalMs);
    }

    private interface PronunciationCallback {
        void onResult(JSONObject pronunciation);

        void onNotReady();

        void onError(String msg);
    }

    private void fetchPronunciationOnce(int roundId, int sequence, int utteranceId, String refText, PronunciationCallback cb) {
        try {
            String sessionId = currentSessionId;
            if (sessionId == null || sessionId.trim().isEmpty()) {
                cb.onNotReady();
                return;
            }
            String url = AIConfigHelper.AGENT_API_BASE_URL + "/sessions/" + sessionId + "/utterances";
            Request req = new Request.Builder().url(url).get().build();
            httpClient.newCall(req).enqueue(new Callback() {
                @Override
                public void onFailure(@NonNull Call call, @NonNull IOException e) {
                    cb.onError(e.getMessage());
                }

                @Override
                public void onResponse(@NonNull Call call, @NonNull Response response) throws IOException {
                    String resStr = response.body() != null ? response.body().string() : "";
                    if (!response.isSuccessful()) {
                        cb.onError("http=" + response.code() + " body=" + resStr);
                        return;
                    }

                    try {
                        JSONObject root = new JSONObject(resStr);
                        JSONArray items = root.optJSONArray("items");
                        if (items == null) {
                            cb.onNotReady();
                            return;
                        }
                        for (int i = 0; i < items.length(); i++) {
                            JSONObject it = items.optJSONObject(i);
                            if (it == null) continue;
                            if (currentUserId == null || !currentUserId.equals(it.optString("speaker_user_id", ""))) continue;
                            if (it.optInt("round_id", -1) != roundId) continue;
                            if (it.optInt("sequence", -1) != sequence) continue;
                            if (it.optInt("utterance_id", -1) != utteranceId) continue;
                            JSONObject pronunciation = it.optJSONObject("pronunciation");
                            if (pronunciation != null) {
                                cb.onResult(pronunciation);
                                return;
                            }
                            cb.onNotReady();
                            return;
                        }
                        cb.onNotReady();
                    } catch (Exception e) {
                        cb.onError("parse_failed: " + e.getMessage());
                    }
                }
            });
        } catch (Exception e) {
            cb.onError(e.getMessage());
        }
    }

    private void showPronunciationDialog(String refText, JSONObject pronunciation) {
        runOnUiThread(() -> {
            try {
                JSONObject score = pronunciation.optJSONObject("评分");
                String sentence = (refText != null ? refText : "").trim();
                SpannableStringBuilder colored = new SpannableStringBuilder(sentence);
                // Default sentence color: green
                colored.setSpan(
                        new ForegroundColorSpan(_colorForAccuracy(100)),
                        0,
                        Math.max(0, colored.length()),
                        Spannable.SPAN_EXCLUSIVE_EXCLUSIVE
                );

                JSONArray badWords = pronunciation.optJSONArray("问题词");
                if (badWords != null && badWords.length() > 0 && sentence.length() > 0) {
                    for (int i = 0; i < badWords.length(); i++) {
                        JSONObject w = badWords.optJSONObject(i);
                        if (w == null) continue;
                        String word = w.optString("词", "");
                        if (word == null) continue;
                        word = word.trim();
                        if (word.isEmpty()) continue;

                        double acc = w.optDouble("発音精度", 0);
                        int color = _colorForAccuracy(acc);

                        Pattern p;
                        try {
                            p = Pattern.compile("\\b" + Pattern.quote(word) + "\\b", Pattern.CASE_INSENSITIVE);
                        } catch (Exception ignored) {
                            continue;
                        }
                        Matcher m = p.matcher(sentence);
                        while (m.find()) {
                            int s = m.start();
                            int e = m.end();
                            if (s >= 0 && e > s && e <= colored.length()) {
                                colored.setSpan(
                                        new ForegroundColorSpan(color),
                                        s,
                                        e,
                                        Spannable.SPAN_EXCLUSIVE_EXCLUSIVE
                                );
                            }
                        }
                    }
                }

                View view = LayoutInflater.from(MainActivity.this).inflate(R.layout.dialog_pronunciation_feedback, null, false);
                TextView tvScores = view.findViewById(R.id.tv_scores);
                TextView tvSentence = view.findViewById(R.id.tv_sentence);
                RadarChart chart = view.findViewById(R.id.radar_chart);

                double acc = score != null ? score.optDouble("発音精度", 0) : 0;
                double flu = score != null ? score.optDouble("流暢度", 0) : 0;
                double comp = score != null ? score.optDouble("完整度", 0) : 0;

                if (tvScores != null) {
                    tvScores.setText(
                            "発音精度: " + String.format(Locale.US, "%.1f", acc)
                                    + "    流暢度: " + String.format(Locale.US, "%.1f", flu)
                                    + "    完整度: " + String.format(Locale.US, "%.1f", comp)
                    );
                }
                if (tvSentence != null) {
                    tvSentence.setText(colored);
                }
                if (chart != null) {
                    bindRadarChart(chart, (float) acc, (float) flu, (float) comp);
                }

                new AlertDialog.Builder(MainActivity.this)
                        .setTitle("この文の発音フィードバック")
                        .setView(view)
                        .setPositiveButton("了解しました", (d, which) -> d.dismiss())
                        .show();
            } catch (Exception e) {
                Log.e(TAG, "showPronunciationDialog failed: " + e.getMessage());
            }
        });
    }

    private void appendPronunciationToConversation(String refText, JSONObject pronunciation) {
        runOnUiThread(() -> {
            try {
                String sentence = (refText != null ? refText : "").trim();
                if (sentence.isEmpty()) {
                    return;
                }

                SpannableStringBuilder colored = new SpannableStringBuilder(sentence);
                colored.setSpan(
                        new ForegroundColorSpan(_colorForAccuracyForConversation(100)),
                        0,
                        Math.max(0, colored.length()),
                        Spannable.SPAN_EXCLUSIVE_EXCLUSIVE
                );

                JSONArray badWords = pronunciation.optJSONArray("问题词");
                if (badWords != null && badWords.length() > 0) {
                    for (int i = 0; i < badWords.length(); i++) {
                        JSONObject w = badWords.optJSONObject(i);
                        if (w == null) continue;
                        String word = w.optString("词", "");
                        if (word == null) continue;
                        word = word.trim();
                        if (word.isEmpty()) continue;

                        double acc = w.optDouble("発音精度", 0);
                        int color = _colorForAccuracyForConversation(acc);

                        Pattern p;
                        try {
                            p = Pattern.compile("\\b" + Pattern.quote(word) + "\\b", Pattern.CASE_INSENSITIVE);
                        } catch (Exception ignored) {
                            continue;
                        }
                        Matcher m = p.matcher(sentence);
                        while (m.find()) {
                            int s = m.start();
                            int e = m.end();
                            if (s >= 0 && e > s && e <= colored.length()) {
                                colored.setSpan(
                                        new ForegroundColorSpan(color),
                                        s,
                                        e,
                                        Spannable.SPAN_EXCLUSIVE_EXCLUSIVE
                                );
                            }
                        }
                    }
                }

                SpannableStringBuilder line = new SpannableStringBuilder();
                line.append("发音测评: ");
                line.append(colored);
                appendChatMessage(ChatMessage.Side.LEFT, line);
            } catch (Exception e) {
                Log.e(TAG, "appendPronunciationToConversation failed: " + e.getMessage());
            }
        });
    }

    private void bindRadarChart(RadarChart chart, float accuracy, float fluency, float completeness) {
        chart.getDescription().setEnabled(false);
        chart.getLegend().setEnabled(false);
        chart.setRotationEnabled(false);
        chart.setTouchEnabled(false);
        chart.setWebLineWidth(1f);
        chart.setWebColor(Color.parseColor("#CBD5E1"));
        chart.setWebLineWidthInner(1f);
        chart.setWebColorInner(Color.parseColor("#CBD5E1"));
        chart.setWebAlpha(120);

        XAxis xAxis = chart.getXAxis();
        xAxis.setTextColor(Color.parseColor("#111827"));
        xAxis.setTextSize(12f);
        xAxis.setYOffset(0f);
        xAxis.setXOffset(0f);
        xAxis.setValueFormatter(new ValueFormatter() {
            @Override
            public String getAxisLabel(float value, AxisBase axis) {
                int i = ((int) value) % 3;
                if (i == 0) return "発音精度";
                if (i == 1) return "流暢度";
                return "完整度";
            }
        });

        chart.getYAxis().setAxisMinimum(0f);
        chart.getYAxis().setAxisMaximum(100f);
        chart.getYAxis().setDrawLabels(false);

        RadarDataSet set = new RadarDataSet(
                Arrays.asList(
                        new RadarEntry(accuracy),
                        new RadarEntry(fluency),
                        new RadarEntry(completeness)
                ),
                "scores"
        );
        set.setColor(Color.parseColor("#0EA5E9"));
        set.setFillColor(Color.parseColor("#0EA5E9"));
        set.setFillAlpha(80);
        set.setDrawFilled(true);
        set.setLineWidth(2f);
        set.setDrawHighlightCircleEnabled(true);
        set.setDrawHighlightIndicators(false);
        set.setValueTextColor(Color.parseColor("#111827"));
        set.setValueTextSize(12f);

        RadarData data = new RadarData(set);
        data.setDrawValues(true);
        data.setValueFormatter(new ValueFormatter() {
            @Override
            public String getRadarLabel(RadarEntry radarEntry) {
                return String.format(Locale.US, "%.1f", radarEntry.getValue());
            }
        });
        chart.setData(data);
        chart.invalidate();
    }

    private int _colorForAccuracy(double acc) {
        if (acc < 60.0) {
            return Color.parseColor("#C62828"); // red (dark)
        }
        if (acc < 80.0) {
            return Color.parseColor("#F9A825"); // amber/yellow (dark)
        }
        return Color.parseColor("#2E7D32"); // green (dark)
    }

    private void summonAiViaBackend() {
        if (!isInRoom) {
            Toast.makeText(this, "まずルームに参加し、入室成功をお待ちください", Toast.LENGTH_SHORT).show();
            return;
        }
        if (currentSessionId == null || currentSessionId.trim().isEmpty()) {
            Toast.makeText(this, "会話尚未准备好，请稍候", Toast.LENGTH_SHORT).show();
            return;
        }
        if (hasSummonedAi) {
            Toast.makeText(this, "AIはもう呼び出されています", Toast.LENGTH_SHORT).show();
            return;
        }

        try {
            JSONObject payload = new JSONObject();
            payload.put("room_id", currentRoomId);
            payload.put("user_id", currentUserId);
            payload.put("client_id", currentClientId);
            payload.put("session_id", currentSessionId);
            payload.put("task_id", currentTaskId);
            payload.put("difficulty", selectedDifficulty);
            payload.put("debug", true);
            payload.put("include_welcome_message", true);
            if (selectedCnLevel != null && !selectedCnLevel.trim().isEmpty()) {
                payload.put("cn_level", selectedCnLevel);
            }
            boolean useLessonCourse = lessonCourseEnabled
                    && selectedUnitId != null && !selectedUnitId.trim().isEmpty()
                    && selectedTopicId != null && !selectedTopicId.trim().isEmpty();
            boolean isFreeChat = freeChatModeActive;
            if (isFreeChat) {
                useLessonCourse = false;
            }
            if (useLessonCourse) {
                payload.put("lesson_start_stage", Math.max(1, selectedLessonStartStage));
            } else {
                ArrayList<String> modsToSend = null;
                if (isFreeChat) {
                    modsToSend = new ArrayList<>();
                    // Map currentMode to backend module name.
                    switch (currentMode) {
                        case CHINESE_QA:
                            modsToSend.add("chinese_qa");
                            break;
                        case ENGLISH_QA:
                            modsToSend.add("english_qa");
                            break;
                        case FREE_QA:
                            modsToSend.add("free_qa");
                            break;
                        default:
                            modsToSend.add("free_qa");
                            break;
                    }
                } else if (selectedModules != null && !selectedModules.isEmpty()) {
                    modsToSend = selectedModules;
                } else {
                    // Default mode: do not change prefs or UI mode.
                    // But still send an explicit default v2 module combo derived from difficulty.
                    modsToSend = defaultModulesForDifficulty(selectedDifficulty);
                }
                if (modsToSend != null && !modsToSend.isEmpty()) {
                    JSONArray mods = new JSONArray();
                    for (String m : modsToSend) {
                        if (m == null) continue;
                        String s = m.trim().toLowerCase(Locale.US);
                        if (s.isEmpty()) continue;
                        mods.put(s);
                    }
                    if (mods.length() > 0) {
                        payload.put("modules", mods);
                    }
                }
            }
            payload.put("mode", useLessonCourse ? "lesson_course" : "situation");
            payload.put("voice_pipeline", "three_stage");
            if (selectedChapterId != null && !selectedChapterId.trim().isEmpty()) {
                payload.put("chapter_id", selectedChapterId);
            }
            if (selectedUnitId != null && !selectedUnitId.trim().isEmpty()) {
                payload.put("unit_id", selectedUnitId);
            }
            if (selectedTopicId != null && !selectedTopicId.trim().isEmpty()) {
                payload.put("topic_id", selectedTopicId);
            }

            String url = AIConfigHelper.AGENT_API_BASE_URL + "/voicechat/start";

            try {
                SharedPreferences sp = getSharedPreferences(PREFS_NAME, MODE_PRIVATE);
                sp.edit()
                        .putString(PREF_LAST_VOICECHAT_START_URL, url)
                        .putString(PREF_LAST_VOICECHAT_START_PAYLOAD, payload.toString())
                        .apply();
            } catch (Exception ignored) {
            }

            Log.i("VOICECHAT_START", "url=" + url);
            Log.i("VOICECHAT_START", "payload=" + payload);

            RequestBody body = RequestBody.create(payload.toString(), MediaType.parse("application/json; charset=utf-8"));
            Request req = new Request.Builder().url(url).post(body).build();
            httpClient.newCall(req).enqueue(new Callback() {
                @Override
                public void onFailure(@NonNull Call call, @NonNull IOException e) {
                    Log.e(TAG, "summon via backend failed: " + e.getMessage());
                    runOnUiThread(() -> {
                        Toast.makeText(MainActivity.this, "召喚失敗：ネットワークエラー", Toast.LENGTH_SHORT).show();
                        updateCallToggleUi();
                    });
                }

                @Override
                public void onResponse(@NonNull Call call, @NonNull Response response) throws IOException {
                    String resStr = response.body() != null ? response.body().string() : "";
                    Log.d(TAG, "summon via backend resp=" + response.code() + " body=" + resStr);
                    Log.i("VOICECHAT_START", "resp_code=" + response.code());
                    Log.i("VOICECHAT_START", "resp_body=" + resStr);
                    try {
                        SharedPreferences sp = getSharedPreferences(PREFS_NAME, MODE_PRIVATE);
                        sp.edit().putString(PREF_LAST_VOICECHAT_START_RESPONSE, resStr).apply();
                    } catch (Exception ignored) {
                    }
                    runOnUiThread(() -> {
                        if (response.isSuccessful()) {
                            Toast.makeText(MainActivity.this, "AIを呼び出しました", Toast.LENGTH_SHORT).show();
                            hasSummonedAi = true;
                            // Sentence list is only shown for FREE_QA mode.
                            // ENGLISH_QA should not show sentence list (it's a quiz mode).
                            if (freeChatModeActive && currentMode == ModeType.FREE_QA && !freeChatSentences.isEmpty()) {
                                StringBuilder sb = new StringBuilder();
                                sb.append("【この課の文】\n");
                                for (int i = 0; i < freeChatSentences.size(); i++) {
                                    sb.append(i + 1).append(". ").append(freeChatSentences.get(i));
                                    if (i < freeChatSentences.size() - 1) sb.append("\n");
                                }
                                appendChatMessage(ChatMessage.Side.LEFT, sb.toString());
                            }
                            if (!_tutorialDone() && _tutorialStep() == 4) {
                                _setTutorialStep(5);
                                mainHandler.post(MainActivity.this::_showTutorialStepIfNeeded);
                            }
                            try {
                                JSONObject obj = new JSONObject(resStr);
                                String bid = obj.optString("bot_user_id", "");
                                if (bid != null && !bid.trim().isEmpty()) {
                                    currentBotUserId = bid;
                                }
                                String wm = obj.optString("welcome_message", "");
                                if (wm != null) wm = wm.trim();
                                if (wm != null && !wm.isEmpty()) {
                                    final String finalWm = wm;
                                    pendingWelcomeDedupText = normalizeForSubtitleDedup(finalWm);
                                    try {
                                        String last = null;
                                        if (!chatMessages.isEmpty()) {
                                            ChatMessage m = chatMessages.get(chatMessages.size() - 1);
                                            if (m != null && m.side == ChatMessage.Side.LEFT && m.text != null) {
                                                last = String.valueOf(m.text).trim();
                                            }
                                        }
                                        if (last == null || !last.equals(finalWm)) {
                                            for (String line : finalWm.split("\\r?\\n")) {
                                                if (line == null) continue;
                                                String s = line.trim();
                                                if (s.isEmpty()) continue;
                                                appendChatMessage(ChatMessage.Side.LEFT, s);
                                            }
                                        }
                                    } catch (Exception ignored) {
                                    }

                                    try {
                                        if (subtitlesTextView != null) {
                                            subtitlesTextView.setText(finalWm);
                                        }
                                    } catch (Exception ignored) {
                                    }
                                }
                            } catch (Exception ignored) {
                            }
                            startPcmRecordingIfNeeded();
                            updateCallToggleUi();
                        } else {
                            hasSummonedAi = false;
                            Toast.makeText(MainActivity.this, "召喚に失敗しました。ログをご確認ください", Toast.LENGTH_SHORT).show();
                            updateCallToggleUi();
                        }
                    });
                }
            });
        } catch (Exception e) {
            Log.e(TAG, "summon payload build failed: " + e.getMessage());
        }
    }

    private void analyzeViaBackend() {
        if ((!isJoiningOrJoined) && (!isInRoom)) {
            Toast.makeText(this, "まずルームに参加してください", Toast.LENGTH_SHORT).show();
            return;
        }
        if (analyzePending) {
            return;
        }
        if (currentSessionId == null || currentSessionId.trim().isEmpty()) {
            analyzePending = true;
            Toast.makeText(this, "会話尚未准备好，正在初始化...", Toast.LENGTH_SHORT).show();
            startBackendSession(() -> {
                analyzePending = false;
                analyzeViaBackend();
            });
            return;
        }

        analyzePending = true;

        try {
            JSONObject payload = new JSONObject();
            payload.put("session_id", currentSessionId);
            payload.put("analysis_mode", "full");

            String url = AIConfigHelper.AGENT_API_BASE_URL + "/sessions/analyze/compact";
            RequestBody body = RequestBody.create(payload.toString(), MediaType.parse("application/json; charset=utf-8"));
            Request req = new Request.Builder().url(url).post(body).build();
            httpClient.newCall(req).enqueue(new Callback() {
                @Override
                public void onFailure(@NonNull Call call, @NonNull IOException e) {
                    Log.e(TAG, "analyze failed: " + e.getMessage());
                    analyzePending = false;
                    runOnUiThread(() -> Toast.makeText(MainActivity.this, "分析失敗：ネットワークエラー", Toast.LENGTH_SHORT).show());
                }

                @Override
                public void onResponse(@NonNull Call call, @NonNull Response response) throws IOException {
                    String resStr = response.body() != null ? response.body().string() : "";
                    Log.d(TAG, "analyze resp=" + response.code() + " body=" + resStr);
                    if (!response.isSuccessful()) {
                        analyzePending = false;
                        runOnUiThread(() -> Toast.makeText(MainActivity.this, "分析に失敗しました。ログをご確認ください", Toast.LENGTH_SHORT).show());
                        return;
                    }

                    try {
                        JSONObject obj = new JSONObject(resStr);
                        analyzePending = false;
                        showCompactAnalysisDialog(obj);
                    } catch (Exception e) {
                        analyzePending = false;
                        Log.e(TAG, "parse analyze json failed: " + e.getMessage());
                    }
                }
            });
        } catch (Exception e) {
            analyzePending = false;
            Log.e(TAG, "analyze payload build failed: " + e.getMessage());
        }
    }

    private void stopAndAnalyzeViaBackend() {
        stopAndAnalyzeViaBackend(false);
    }

    private void stopAndAnalyzeViaBackend(boolean ignoreRoomCheck) {
        Log.e(TAG, "STOP_FLOW_V2_USED");
        if (!ignoreRoomCheck) {
            if ((!isJoiningOrJoined) && (!isInRoom)) {
                Toast.makeText(this, "まずルームに参加してください", Toast.LENGTH_SHORT).show();
                return;
            }
        }
        if (stopAnalyzePending) {
            return;
        }
        if (currentSessionId == null || currentSessionId.trim().isEmpty()) {
            stopAnalyzePending = true;
            Toast.makeText(this, "会話尚未准备好，正在初始化...", Toast.LENGTH_SHORT).show();
            updateCallToggleUi();
            startBackendSession(() -> {
                stopAnalyzePending = false;
                stopAndAnalyzeViaBackend(ignoreRoomCheck);
            });
            return;
        }

        stopAnalyzePending = true;
        updateCallToggleUi();

        stopPcmRecordingAndFinalizeAsync();

        try {
            final String sessionId = currentSessionId;

            JSONObject payload = new JSONObject();
            payload.put("room_id", currentRoomId);
            payload.put("user_id", currentUserId);
            payload.put("client_id", currentClientId);
            payload.put("session_id", sessionId);
            payload.put("task_id", currentTaskId);
            payload.put("mode", selectedMode);
            payload.put("difficulty", selectedDifficulty);
            payload.put("analysis_mode", "full");
            boolean isMainline = "mainline".equalsIgnoreCase(selectedMode);
            if (!isMainline) {
                if (selectedUnitId != null && !selectedUnitId.trim().isEmpty()) {
                    payload.put("unit_id", selectedUnitId);
                }
                if (selectedTopicId != null && !selectedTopicId.trim().isEmpty()) {
                    payload.put("topic_id", selectedTopicId);
                }
            }

            String url = AIConfigHelper.AGENT_API_BASE_URL + "/voicechat/end_task";
            RequestBody body = RequestBody.create(payload.toString(), MediaType.parse("application/json; charset=utf-8"));
            Request req = new Request.Builder().url(url).post(body).build();
            httpClient.newCall(req).enqueue(new Callback() {
                @Override
                public void onFailure(@NonNull Call call, @NonNull IOException e) {
                    Log.e(TAG, "end_task failed", e);
                    stopAnalyzePending = false;
                    String detail = (e.getMessage() != null ? e.getMessage() : "");
                    String kind;
                    if (e instanceof SocketTimeoutException) {
                        String lc = detail.toLowerCase(Locale.ROOT);
                        if (lc.contains("connect")) {
                            kind = "接続タイムアウト";
                        } else if (lc.contains("read")) {
                            kind = "読み取りタイムアウト";
                        } else {
                            kind = "リクエストタイムアウト";
                        }
                    } else {
                        kind = "ネットワークエラー";
                    }
                    String msg = "タスク終了失敗：" + kind + "（" + e.getClass().getSimpleName() + (detail.isEmpty() ? "" : (":" + detail)) + "）";
                    runOnUiThread(() -> {
                        Toast.makeText(MainActivity.this, msg, Toast.LENGTH_LONG).show();
                        updateCallToggleUi();
                    });
                }

                @Override
                public void onResponse(@NonNull Call call, @NonNull Response response) throws IOException {
                    String resStr = response.body() != null ? response.body().string() : "";
                    Log.d(TAG, "end_task resp=" + response.code() + " body=" + resStr);
                    if (!response.isSuccessful()) {
                        stopAnalyzePending = false;
                        String brief = resStr;
                        if (brief != null && brief.length() > 200) brief = brief.substring(0, 200);
                        String msg = "タスク終了失敗：http=" + response.code() + (brief != null && !brief.isEmpty() ? (" " + brief) : "");
                        runOnUiThread(() -> {
                            Toast.makeText(MainActivity.this, msg, Toast.LENGTH_LONG).show();
                            updateCallToggleUi();
                        });
                        return;
                    }

                    stopAnalyzePending = false;
                    runOnUiThread(() -> {
                        Toast.makeText(MainActivity.this, "タスクは終了しました", Toast.LENGTH_SHORT).show();
                        updateCallToggleUi();
                    });
                }
            });
        } catch (Exception e) {
            stopAnalyzePending = false;
            Log.e(TAG, "stop+analyze payload build failed: " + e.getMessage());
            updateCallToggleUi();
        }
    }

    private void pollAnalysisJobUntilReady(String jobId, int attempt) {
        final int maxAttempts = 180;
        final long intervalMs = 1000;
        if (attempt > maxAttempts) {
            runOnUiThread(() -> Toast.makeText(MainActivity.this, "分析タイムアウト：結果を取得できませんでした", Toast.LENGTH_SHORT).show());
            return;
        }

        String url = AIConfigHelper.AGENT_API_BASE_URL + "/analysis_jobs/" + jobId + "?include_result=1";
        Request req = new Request.Builder().url(url).get().build();
        httpClient.newCall(req).enqueue(new Callback() {
            @Override
            public void onFailure(@NonNull Call call, @NonNull IOException e) {
                Log.e(TAG, "poll analysis job failed", e);
                mainHandler.postDelayed(() -> pollAnalysisJobUntilReady(jobId, attempt + 1), intervalMs);
            }

            @Override
            public void onResponse(@NonNull Call call, @NonNull Response response) throws IOException {
                String resStr = response.body() != null ? response.body().string() : "";
                if (!response.isSuccessful()) {
                    Log.e(TAG, "poll analysis job http=" + response.code() + " body=" + resStr);
                    mainHandler.postDelayed(() -> pollAnalysisJobUntilReady(jobId, attempt + 1), intervalMs);
                    return;
                }

                try {
                    JSONObject obj = new JSONObject(resStr);
                    String status = obj.optString("status", "");
                    if ("succeeded".equalsIgnoreCase(status)) {
                        JSONObject result = obj.optJSONObject("result");
                        JSONObject analysis = result != null ? result.optJSONObject("analysis") : null;
                        if (analysis == null) {
                            runOnUiThread(() -> Toast.makeText(MainActivity.this, "分析は完了しましたが、result.analysisが空です", Toast.LENGTH_SHORT).show());
                            return;
                        }

                        try {
                            saveHistoryRecordLocal(obj);
                        } catch (Exception ignored) {
                        }

                        boolean showDialog = true;
                        try {
                            SharedPreferences sp = getSharedPreferences(PREFS_NAME, MODE_PRIVATE);
                            showDialog = sp.getBoolean(PREF_SHOW_ANALYSIS_DIALOG, false);
                        } catch (Exception ignored) {
                            showDialog = false;
                        }

                        if (showDialog) {
                            showCompactAnalysisDialog(analysis);
                        } else {
                            runOnUiThread(() -> Toast.makeText(MainActivity.this, "分析完了、歴史記録に同期しました", Toast.LENGTH_SHORT).show());
                        }
                        return;
                    }
                    if ("failed".equalsIgnoreCase(status)) {
                        String err = obj.optString("error", "");
                        if (err == null || err.trim().isEmpty()) {
                            JSONObject result = obj.optJSONObject("result");
                            err = result != null ? result.optString("error", "analysis_failed") : "analysis_failed";
                        }
                        String msg = "分析失敗：" + err;
                        runOnUiThread(() -> Toast.makeText(MainActivity.this, msg, Toast.LENGTH_SHORT).show());
                        return;
                    }

                    mainHandler.postDelayed(() -> pollAnalysisJobUntilReady(jobId, attempt + 1), intervalMs);
                } catch (Exception e) {
                    Log.e(TAG, "parse poll analysis job json failed: " + e.getMessage());
                    mainHandler.postDelayed(() -> pollAnalysisJobUntilReady(jobId, attempt + 1), intervalMs);
                }
            }
        });
    }

    private void showHistoryTasksDialog() {
        if (currentUserId == null || currentUserId.trim().isEmpty()) {
            Toast.makeText(this, "ユーザーはまだ準備ができていません", Toast.LENGTH_SHORT).show();
            return;
        }

        String url = AIConfigHelper.AGENT_API_BASE_URL + "/users/" + currentUserId + "/tasks?limit=30&offset=0&include_result=0";
        Request req = new Request.Builder().url(url).get().build();
        httpClient.newCall(req).enqueue(new Callback() {
            @Override
            public void onFailure(@NonNull Call call, @NonNull IOException e) {
                Log.e(TAG, "history tasks failed", e);
                runOnUiThread(() -> Toast.makeText(MainActivity.this, "履歴の取得に失敗：ネットワークエラー", Toast.LENGTH_LONG).show());
            }

            @Override
            public void onResponse(@NonNull Call call, @NonNull Response response) throws IOException {
                String resStr = response.body() != null ? response.body().string() : "";
                if (!response.isSuccessful()) {
                    Log.e(TAG, "history tasks http=" + response.code() + " body=" + resStr);
                    runOnUiThread(() -> Toast.makeText(MainActivity.this, "履歴の取得に失敗：http=" + response.code(), Toast.LENGTH_LONG).show());
                    return;
                }

                try {
                    JSONObject obj = new JSONObject(resStr);
                    JSONArray items = obj.optJSONArray("items");
                    if (items == null || items.length() == 0) {
                        runOnUiThread(() -> Toast.makeText(MainActivity.this, "履歴はまだありません", Toast.LENGTH_SHORT).show());
                        return;
                    }

                    int n = items.length();
                    String[] labels = new String[n];
                    String[] jobIds = new String[n];

                    for (int i = 0; i < n; i++) {
                        JSONObject it = items.optJSONObject(i);
                        if (it == null) {
                            labels[i] = "(invalid)";
                            jobIds[i] = "";
                            continue;
                        }

                        String createdAt = it.optString("created_at", "");
                        String status = it.optString("status", "");
                        String topicId = it.optString("topic_id", "");
                        String unitId = it.optString("unit_id", "");
                        int diff = it.optInt("difficulty", -1);
                        String mode = it.optString("mode", "");
                        String taskId = it.optString("task_id", "");
                        String jobId = it.optString("job_id", "");

                        String dateShort = createdAt;
                        if (dateShort != null && dateShort.length() >= 19) {
                            dateShort = dateShort.substring(0, 19).replace('T', ' ');
                        }

                        StringBuilder sb = new StringBuilder();
                        sb.append(dateShort);
                        if (status != null && !status.isEmpty()) sb.append(" [").append(status).append("]");
                        if (topicId != null && !topicId.isEmpty()) sb.append(" topic=").append(topicId);
                        if (unitId != null && !unitId.isEmpty()) sb.append(" unit=").append(unitId);
                        if (diff >= 0) sb.append(" diff=").append(diff);
                        if (mode != null && !mode.isEmpty()) sb.append(" mode=").append(mode);
                        if (taskId != null && !taskId.isEmpty()) sb.append("\n").append(taskId);

                        labels[i] = sb.toString();
                        jobIds[i] = jobId;
                    }

                    runOnUiThread(() -> new AlertDialog.Builder(MainActivity.this)
                            .setTitle("訓練履歴（タップして詳細を見る）")
                            .setItems(labels, (d, which) -> {
                                String jid = jobIds[which];
                                if (jid == null || jid.trim().isEmpty()) {
                                    Toast.makeText(MainActivity.this, "job_idが空です", Toast.LENGTH_SHORT).show();
                                    return;
                                }
                                pollAnalysisJobUntilReady(jid, 0);
                            })
                            .setNegativeButton("閉じる", null)
                            .show());
                } catch (Exception e) {
                    Log.e(TAG, "parse history tasks json failed: " + e.getMessage());
                    runOnUiThread(() -> Toast.makeText(MainActivity.this, "履歴の解析に失敗しました", Toast.LENGTH_LONG).show());
                }
            }
        });
    }

    private void analyzeSessionCompactAfterStop(String sessionId) {
        try {
            JSONObject payload = new JSONObject();
            payload.put("session_id", sessionId);

            String url = AIConfigHelper.AGENT_API_BASE_URL + "/sessions/analyze/compact";
            RequestBody body = RequestBody.create(payload.toString(), MediaType.parse("application/json; charset=utf-8"));
            Request req = new Request.Builder().url(url).post(body).build();
            httpClient.newCall(req).enqueue(new Callback() {
                @Override
                public void onFailure(@NonNull Call call, @NonNull IOException e) {
                    Log.e(TAG, "stop->analyze failed: " + e.getMessage());
                    runOnUiThread(() -> Toast.makeText(MainActivity.this, "分析失敗：ネットワークエラー", Toast.LENGTH_SHORT).show());
                }

                @Override
                public void onResponse(@NonNull Call call, @NonNull Response response) throws IOException {
                    String resStr = response.body() != null ? response.body().string() : "";
                    Log.d(TAG, "stop->analyze resp=" + response.code() + " body=" + resStr);
                    if (!response.isSuccessful()) {
                        runOnUiThread(() -> Toast.makeText(MainActivity.this, "分析失敗：http=" + response.code(), Toast.LENGTH_SHORT).show());
                        return;
                    }
                    try {
                        JSONObject obj = new JSONObject(resStr);
                        showCompactAnalysisDialog(obj);
                    } catch (Exception e) {
                        Log.e(TAG, "parse stop->analyze json failed: " + e.getMessage());
                        runOnUiThread(() -> Toast.makeText(MainActivity.this, "分析の解析に失敗しました", Toast.LENGTH_LONG).show());
                    }
                }
            });
        } catch (Exception e) {
            Log.e(TAG, "stop->analyze build failed: " + e.getMessage());
        }
    }

    private void pollReportUntilReady(String sessionId, int attempt) {
        if (attempt > 60) {
            runOnUiThread(() -> Toast.makeText(MainActivity.this, "分析タイムアウト：レポートを取得できませんでした", Toast.LENGTH_SHORT).show());
            return;
        }

        String url = AIConfigHelper.AGENT_API_BASE_URL + "/sessions/" + sessionId + "/report/last";
        Request req = new Request.Builder().url(url).get().build();
        httpClient.newCall(req).enqueue(new Callback() {
            @Override
            public void onFailure(@NonNull Call call, @NonNull IOException e) {
                Log.e(TAG, "poll report failed", e);
                try {
                    Thread.sleep(1000);
                } catch (InterruptedException ignored) {
                }
                pollReportUntilReady(sessionId, attempt + 1);
            }

            @Override
            public void onResponse(@NonNull Call call, @NonNull Response response) throws IOException {
                String resStr = response.body() != null ? response.body().string() : "";
                if (response.code() == 404) {
                    try {
                        Thread.sleep(1000);
                    } catch (InterruptedException ignored) {
                    }
                    pollReportUntilReady(sessionId, attempt + 1);
                    return;
                }
                if (!response.isSuccessful()) {
                    Log.e(TAG, "poll report http=" + response.code() + " body=" + resStr);
                    runOnUiThread(() -> Toast.makeText(MainActivity.this, "レポートの取得に失敗：http=" + response.code(), Toast.LENGTH_LONG).show());
                    return;
                }
                try {
                    JSONObject report = new JSONObject(resStr);
                    showReportDialog(report);
                } catch (Exception e) {
                    Log.e(TAG, "parse report json failed: " + e.getMessage());
                    runOnUiThread(() -> Toast.makeText(MainActivity.this, "レポートの解析に失敗しました", Toast.LENGTH_LONG).show());
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
                    sb.append("総合点: ").append(_fmtScoreField(scores, "overall_score")).append("\n");
                    sb.append("難易度: ").append(_fmtScoreField(scores, "difficulty_level")).append("\n\n");
                }
                if (dim != null) {
                    sb.append("文法: ").append(_fmtScoreField(dim, "grammar_score")).append("\n");
                    sb.append("語彙: ").append(_fmtScoreField(dim, "vocabulary_score")).append("\n");
                    sb.append("流暢度: ").append(_fmtScoreField(dim, "fluency_score")).append("\n");
                    sb.append("理解: ").append(_fmtScoreField(dim, "comprehension_score")).append("\n");
                    sb.append("タスク完了: ").append(_fmtScoreField(dim, "task_completion_score")).append("\n\n");
                }

                if (evidence != null && evidence.length() > 0) {
                    sb.append("証拠(原文):\n");
                    for (int i = 0; i < Math.min(5, evidence.length()); i++) {
                        JSONObject it = evidence.optJSONObject(i);
                        if (it == null) continue;
                        sb.append("- [").append(it.optString("dimension", "")).append("] ");
                        sb.append(it.optString("quote", "")).append("\n");
                    }
                }

                new AlertDialog.Builder(MainActivity.this)
                        .setTitle("分析")
                        .setMessage(sb.toString())
                        .setPositiveButton("OK", null)
                        .show();
            } catch (Exception e) {
                Log.e(TAG, "show dialog failed: " + e.getMessage());
            }
        });
    }

    private void showReportDialog(JSONObject report) {
        runOnUiThread(() -> {
            try {
                JSONObject analysis = report != null ? report.optJSONObject("文法と表現の分析") : null;
                JSONObject pron = report != null ? report.optJSONObject("Tencent スピークィング評価") : null;

                StringBuilder sb = new StringBuilder();

                if (report != null) {
                    String sid = report.optString("会話ID", "");
                    if (sid != null && !sid.isEmpty()) {
                        sb.append("会話ID: ").append(sid).append("\n\n");
                    }
                }

                if (analysis != null) {
                    JSONObject sc = analysis.optJSONObject("评分");
                    if (sc != null) {
                        sb.append("文法と表現の分析\n");
                        sb.append("総合点: ").append(sc.optInt("总分", -1)).append("\n");
                        sb.append("難易度: ").append(sc.optInt("難易度等级", -1)).append("\n");
                        JSONObject dims = sc.optJSONObject("维度得分");
                        if (dims != null) {
                            sb.append("文法: ").append(dims.optInt("语法", -1)).append("\n");
                            sb.append("語彙: ").append(dims.optInt("词汇", -1)).append("\n");
                            sb.append("流暢度: ").append(dims.optInt("流暢度", -1)).append("\n");
                            sb.append("理解: ").append(dims.optInt("理解", -1)).append("\n");
                        }
                        sb.append("\n");
                    }

                    JSONObject fb = analysis.optJSONObject("反馈");
                    if (fb != null) {
                        JSONArray strengths = fb.optJSONArray("优点");
                        JSONArray weaknesses = fb.optJSONArray("待改进");
                        JSONArray evidence = fb.optJSONArray("证据");

                        if (strengths != null && strengths.length() > 0) {
                            sb.append("优点:\n");
                            for (int i = 0; i < Math.min(3, strengths.length()); i++) {
                                sb.append("- ").append(strengths.optString(i, "")).append("\n");
                            }
                            sb.append("\n");
                        }
                        if (weaknesses != null && weaknesses.length() > 0) {
                            sb.append("待改进:\n");
                            for (int i = 0; i < Math.min(3, weaknesses.length()); i++) {
                                sb.append("- ").append(weaknesses.optString(i, "")).append("\n");
                            }
                            sb.append("\n");
                        }
                        if (evidence != null && evidence.length() > 0) {
                            sb.append("証拠(原文):\n");
                            for (int i = 0; i < Math.min(5, evidence.length()); i++) {
                                JSONObject it = evidence.optJSONObject(i);
                                if (it == null) continue;
                                sb.append("- [").append(it.optString("维度", "")).append("] ");
                                sb.append(it.optString("原句", "")).append("\n");
                            }
                            sb.append("\n");
                        }
                    }
                }

                if (pron != null) {
                    if (!sb.toString().isEmpty()) {
                        sb.append("\n");
                    }
                    sb.append("Tencent スピークィング評価\n");
                    sb.append("状態: ").append(pron.optString("状态", "")).append("\n");
                    JSONObject sc = pron.optJSONObject("评分");
                    if (sc != null) {
                        sb.append("推奨得点: ").append(sc.optDouble("建议得分", -1)).append("\n");
                        sb.append("発音精度: ").append(sc.optDouble("発音精度", -1)).append("\n");
                        sb.append("流暢度: ").append(sc.optDouble("流暢度", -1)).append("\n");
                        sb.append("完整度: ").append(sc.optDouble("完整度", -1)).append("\n");
                    }

                    JSONArray bad = pron.optJSONArray("问题词");
                    if (bad != null && bad.length() > 0) {
                        sb.append("\n問題語(Top):\n");
                        for (int i = 0; i < Math.min(12, bad.length()); i++) {
                            JSONObject it = bad.optJSONObject(i);
                            if (it == null) continue;
                            sb.append("- ").append(it.optString("词", ""));
                            double acc = it.optDouble("発音精度", -1);
                            if (acc >= 0) sb.append(" (").append(String.format(java.util.Locale.US, "%.1f", acc)).append(")");
                            sb.append("\n");
                        }
                    }

                    JSONArray perUt = pron.optJSONArray("文ごとのフィードバック");
                    if (perUt != null && perUt.length() > 0) {
                        sb.append("\n逐句問題語(Top):\n");
                        for (int i = 0; i < Math.min(6, perUt.length()); i++) {
                            JSONObject ut = perUt.optJSONObject(i);
                            if (ut == null) continue;
                            String text = ut.optString("文本", "");
                            if (text == null) text = "";
                            if (text.length() > 80) text = text.substring(0, 80) + "...";
                            sb.append("- ").append(text).append("\n");
                            JSONArray bw = ut.optJSONArray("问题词");
                            if (bw != null && bw.length() > 0) {
                                for (int j = 0; j < Math.min(6, bw.length()); j++) {
                                    JSONObject w = bw.optJSONObject(j);
                                    if (w == null) continue;
                                    sb.append("    ").append(w.optString("词", ""));
                                    double acc = w.optDouble("発音精度", -1);
                                    if (acc >= 0) sb.append(" (").append(String.format(java.util.Locale.US, "%.1f", acc)).append(")");
                                    sb.append("\n");
                                }
                            }
                        }
                    }
                }

                if (sb.toString().trim().isEmpty()) {
                    sb.append("表示できるレポートフィールド(report)がありません");
                }

                new AlertDialog.Builder(MainActivity.this)
                        .setTitle("今回の練習レポート")
                        .setMessage(sb.toString())
                        .setPositiveButton("OK", null)
                        .show();
            } catch (Exception e) {
                Log.e(TAG, "show report dialog failed: " + e.getMessage());
            }
        });
    }

    private void startPcmRecordingIfNeeded() {
        if (!isInRoom || !hasSummonedAi) {
            return;
        }
        if (audioRecording) return;

        if (audioSessionActive && audioFinalized) {
            return;
        }

        if (ActivityCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            runOnUiThread(() -> Toast.makeText(MainActivity.this, "マイクの権限が許可されていません。録音とアップロードができません", Toast.LENGTH_SHORT).show());
            return;
        }

        try {
            int channelConfig = AudioFormat.CHANNEL_IN_MONO;
            int audioFormat = AudioFormat.ENCODING_PCM_16BIT;
            int minBuf = AudioRecord.getMinBufferSize(AUDIO_SAMPLE_RATE, channelConfig, audioFormat);
            int chunkSamples = (AUDIO_SAMPLE_RATE * AUDIO_CHUNK_MS) / 1000;
            int chunkBytes = chunkSamples * 2;
            int bufferBytes = Math.max(minBuf, chunkBytes * 2);

            try {
                audioRecord = new AudioRecord(
                        MediaRecorder.AudioSource.VOICE_COMMUNICATION,
                        AUDIO_SAMPLE_RATE,
                        channelConfig,
                        audioFormat,
                        bufferBytes
                );
            } catch (SecurityException se) {
                Log.e(TAG, "AudioRecord permission denied: " + se.getMessage());
                runOnUiThread(() -> Toast.makeText(MainActivity.this, "録音失敗：マイクの権限が拒否されました", Toast.LENGTH_SHORT).show());
                audioRecord = null;
                return;
            }

            if (audioRecord.getState() != AudioRecord.STATE_INITIALIZED) {
                audioRecord.release();
                audioRecord = null;
                runOnUiThread(() -> Toast.makeText(MainActivity.this, "録音の初期化に失敗しました（マイクが使用中の可能性があります）", Toast.LENGTH_SHORT).show());
                return;
            }

            audioRecordStartMs = SystemClock.elapsedRealtime();
            audioChunkSeq = 0;
            audioRecording = true;
            audioSessionActive = true;
            audioFinalized = false;
            audioHasUploadedAnyChunk = false;
            audioUploadInFlight.set(0);
            currentUtteranceId = 0;
            lastFinalizedUtteranceId = -1;
            try {
                audioRecord.startRecording();
            } catch (SecurityException se) {
                Log.e(TAG, "startRecording permission denied: " + se.getMessage());
                runOnUiThread(() -> Toast.makeText(MainActivity.this, "録音開始失敗：権限が拒否されました", Toast.LENGTH_SHORT).show());
                stopPcmRecordingInternal();
                return;
            }

            audioThread = new Thread(() -> {
                byte[] buf = new byte[chunkBytes];
                final int preChunks = Math.max(0, CLIENT_VAD_PRE_MS / Math.max(1, AUDIO_CHUNK_MS));
                final long postMs = CLIENT_VAD_POST_MS;
                ArrayDeque<byte[]> preBuf = new ArrayDeque<>();
                boolean inSpeech = false;
                long lastVoiceTsMs = 0;
                int inSpeechUtteranceId = -1;
                while (audioRecording && audioRecord != null) {
                    int n = audioRecord.read(buf, 0, buf.length);
                    if (n <= 0) {
                        continue;
                    }
                    long tsMs = SystemClock.elapsedRealtime() - audioRecordStartMs;

                    int avgAbs = calcAvgAbsPcm16(buf, n);
                    boolean isVoice = avgAbs >= CLIENT_VAD_THRESHOLD;
                    byte[] chunkCopy = Arrays.copyOf(buf, n);

                    if (!inSpeech) {
                        preBuf.addLast(chunkCopy);
                        while (preBuf.size() > preChunks + 1) {
                            preBuf.pollFirst();
                        }
                        if (isVoice) {
                            inSpeech = true;
                            inSpeechUtteranceId = ++currentUtteranceId;
                            audioChunkSeq = 0;
                            lastVoiceTsMs = tsMs;
                            while (!preBuf.isEmpty()) {
                                byte[] c = preBuf.pollFirst();
                                uploadAudioChunk(c, c.length, tsMs, inSpeechUtteranceId);
                            }
                        }
                        continue;
                    }

                    if (isVoice) {
                        lastVoiceTsMs = tsMs;
                        uploadAudioChunk(chunkCopy, chunkCopy.length, tsMs, inSpeechUtteranceId);
                        continue;
                    }

                    if (tsMs - lastVoiceTsMs <= postMs) {
                        uploadAudioChunk(chunkCopy, chunkCopy.length, tsMs, inSpeechUtteranceId);
                        continue;
                    }

                    inSpeech = false;
                    if (inSpeechUtteranceId > 0) {
                        lastFinalizedUtteranceId = inSpeechUtteranceId;
                        finalizeAudioOnServer(inSpeechUtteranceId);
                    }
                    inSpeechUtteranceId = -1;
                    preBuf.clear();
                    preBuf.addLast(chunkCopy);
                }
            }, "pcm-uploader");
            audioThread.start();

            runOnUiThread(() -> Toast.makeText(MainActivity.this, "録音とアップロードを開始しました(16k mono)", Toast.LENGTH_SHORT).show());
        } catch (Exception e) {
            Log.e(TAG, "startPcmRecordingIfNeeded failed: " + e.getMessage());
        }
    }

    private void stopPcmRecordingAndFinalizeAsync() {
        if (!audioSessionActive) {
            return;
        }
        if (audioFinalizeInFlight || audioFinalized) {
            return;
        }
        audioFinalizeInFlight = true;
        new Thread(() -> {
            stopPcmRecordingInternal();
            long startWait = SystemClock.elapsedRealtime();
            while (audioUploadInFlight.get() > 0 && (SystemClock.elapsedRealtime() - startWait) < 3000) {
                try {
                    Thread.sleep(60);
                } catch (InterruptedException ignored) {
                }
            }
            if (!audioHasUploadedAnyChunk) {
                audioFinalized = true;
                audioFinalizeInFlight = false;
                audioSessionActive = false;
                return;
            }
            finalizeAudioOnServer(null);
        }, "pcm-finalize").start();
    }

    private void stopPcmRecordingInternal() {
        audioRecording = false;

        try {
            if (audioThread != null) {
                audioThread.join(800);
            }
        } catch (InterruptedException ignored) {
        }

        try {
            if (audioRecord != null) {
                try {
                    audioRecord.stop();
                } catch (Exception ignored) {
                }
                try {
                    audioRecord.release();
                } catch (Exception ignored) {
                }
            }
        } finally {
            audioRecord = null;
            audioThread = null;
        }
    }

    private void uploadAudioChunk(byte[] data, int len, long tsMs, int utteranceId) {
        try {
            if (!isInRoom || !hasSummonedAi) {
                return;
            }
            if (audioUploadInFlight.get() >= 3) {
                return;
            }
            audioUploadInFlight.incrementAndGet();
            String sessionId = currentSessionId;
            if (sessionId == null || sessionId.trim().isEmpty()) {
                audioUploadInFlight.decrementAndGet();
                return;
            }
            String b64 = Base64.encodeToString(java.util.Arrays.copyOf(data, len), Base64.NO_WRAP);

            JSONObject payload = new JSONObject();
            payload.put("session_id", sessionId);
            payload.put("client_id", currentClientId);
            payload.put("sample_rate", AUDIO_SAMPLE_RATE);
            payload.put("channels", AUDIO_CHANNELS);
            payload.put("chunk_seq", audioChunkSeq++);
            payload.put("chunk_ts_ms", tsMs);
            payload.put("pcm16_base64", b64);
            payload.put("utterance_id", utteranceId);

            String url = AIConfigHelper.AGENT_API_BASE_URL + "/sessions/audio/chunk";
            RequestBody body = RequestBody.create(payload.toString(), MediaType.parse("application/json; charset=utf-8"));
            Request req = new Request.Builder().url(url).post(body).build();
            httpClient.newCall(req).enqueue(new Callback() {
                @Override
                public void onFailure(@NonNull Call call, @NonNull IOException e) {
                    Log.e(TAG, "uploadAudioChunk failed: " + e.getMessage());
                    audioUploadInFlight.decrementAndGet();
                }

                @Override
                public void onResponse(@NonNull Call call, @NonNull Response response) throws IOException {
                    try {
                        if (!response.isSuccessful()) {
                            String resStr = response.body() != null ? response.body().string() : "";
                            Log.e(TAG, "uploadAudioChunk resp=" + response.code() + " body=" + resStr);
                        } else {
                            // Important: still close the response body to avoid connection leaks.
                            audioHasUploadedAnyChunk = true;
                        }
                    } finally {
                        try {
                            response.close();
                        } catch (Exception ignored) {
                        }
                        audioUploadInFlight.decrementAndGet();
                    }
                }
            });
        } catch (Exception e) {
            Log.e(TAG, "uploadAudioChunk build failed: " + e.getMessage());
            audioUploadInFlight.decrementAndGet();
        }
    }

    private void finalizeAudioOnServer(Integer utteranceId) {
        try {
            if (!isInRoom || !hasSummonedAi) {
                audioFinalizeInFlight = false;
                return;
            }
            String sessionId = currentSessionId;
            if (sessionId == null || sessionId.trim().isEmpty()) {
                audioFinalizeInFlight = false;
                return;
            }
            JSONObject payload = new JSONObject();
            payload.put("session_id", sessionId);
            payload.put("client_id", currentClientId);
            payload.put("sample_rate", AUDIO_SAMPLE_RATE);
            payload.put("channels", AUDIO_CHANNELS);
            payload.put("trim_silence", false);
            if (utteranceId != null) {
                payload.put("utterance_id", utteranceId.intValue());
            }

            String url = AIConfigHelper.AGENT_API_BASE_URL + "/sessions/audio/finalize";
            RequestBody body = RequestBody.create(payload.toString(), MediaType.parse("application/json; charset=utf-8"));
            Request req = new Request.Builder().url(url).post(body).build();
            httpClient.newCall(req).enqueue(new Callback() {
                @Override
                public void onFailure(@NonNull Call call, @NonNull IOException e) {
                    Log.e(TAG, "finalizeAudio failed: " + e.getMessage());
                    audioFinalizeInFlight = false;
                }

                @Override
                public void onResponse(@NonNull Call call, @NonNull Response response) throws IOException {
                    String resStr = response.body() != null ? response.body().string() : "";
                    Log.d(TAG, "finalizeAudio resp=" + response.code() + " body=" + resStr);
                    audioFinalized = response.isSuccessful();
                    audioFinalizeInFlight = false;
                }
            });
        } catch (Exception e) {
            Log.e(TAG, "finalizeAudio build failed: " + e.getMessage());
            audioFinalizeInFlight = false;
        }
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        try {
            Toolbar tb = findViewById(R.id.top_app_bar);
            if (tb != null) {
                setSupportActionBar(tb);
            }
        } catch (Exception ignored) {
        }

        // Load difficulty from prefs when idle.
        refreshDifficultyFromPrefsIfIdle();

        // Apply course difficulty (from chapter/topic selection) unless user manually overrode.
        try {
            Intent it = getIntent();
            if (it != null) {
                String m = it.getStringExtra("mode");
                if (m != null && !m.trim().isEmpty()) selectedMode = m;
                String cid = it.getStringExtra("chapter_id");
                if (cid != null && !cid.trim().isEmpty()) selectedChapterId = cid;
                String uid = it.getStringExtra("unit_id");
                if (uid != null && !uid.trim().isEmpty()) selectedUnitId = uid;
                String tid = it.getStringExtra("topic_id");
                if (tid != null && !tid.trim().isEmpty()) {
                    selectedTopicId = tid;
                    selectedCoursePending = true;
                    // Default to "teach_test" mode when a new topic is selected
                    try {
                        SharedPreferences sp = getSharedPreferences(PREFS_NAME, MODE_PRIVATE);
                        sp.edit()
                                .putString(PREF_CHAT_MODULES_MODE, "teach_test")
                                .putString(PREF_CHAT_MODULES, "repeat_sentence,exam_sentence")
                                .apply();
                        // Also update runtime state
                        selectedModules = new ArrayList<>();
                        selectedModules.add("repeat_sentence");
                        selectedModules.add("exam_sentence");
                    } catch (Exception ignored) {}
                }
                String vurl = it.getStringExtra("topic_video_url");
                if (vurl != null && !vurl.trim().isEmpty()) selectedTopicVideoUrl = vurl;
                String vstreams = it.getStringExtra("topic_video_streams");
                if (vstreams != null && !vstreams.trim().isEmpty()) selectedTopicVideoStreams = vstreams;

                int courseDifficulty = it.getIntExtra("difficulty", -1);
                if (courseDifficulty >= 1 && courseDifficulty <= 3) {
                    applyCourseDifficultyIfNotManualOverride(courseDifficulty);
                }
            }
        } catch (Exception ignored) {
        }

        requestPermission();

        chatRecyclerView = findViewById(R.id.rv_chat);
        courseIntroOverlay = findViewById(R.id.course_intro_overlay);
        courseStageTextView = findViewById(R.id.tv_course_stage);
        courseIntroEnglishTextView = findViewById(R.id.tv_course_intro_en);
        courseIntroChineseTextView = findViewById(R.id.tv_course_intro_cn);
        courseIntroProgressTextView = findViewById(R.id.tv_course_intro_progress);
        courseIntroReplayButton = findViewById(R.id.btn_course_intro_replay);
        if (courseIntroReplayButton != null) {
            courseIntroReplayButton.setOnClickListener(v -> onCourseIntroReplayClicked());
        }
        courseIntroSkipButton = findViewById(R.id.btn_course_intro_skip);
        if (courseIntroSkipButton != null) {
            courseIntroSkipButton.setOnClickListener(v -> onCourseIntroSkipClicked());
        }
        voiceWaveView = null;

        // Best-effort: prefetch BGM from cloud so it's ready before the user starts a course.
        try {
            BgmManager.syncFromCloud(this, AIConfigHelper.AGENT_API_BASE_URL, null);
        } catch (Exception ignored) {
        }

        setupChatRecyclerView();
        loadStructuredCourseFlow(null);
        maybeShowOnboardingChatMessage();

        // New single-call toggle button (CardView).
        callToggleCard = findViewById(R.id.btn_call_toggle);
        callToggleIcon = findViewById(R.id.iv_call_mic);
        if (callToggleCard != null) {
            callToggleCard.setOnClickListener(v -> onCallToggleClicked());
        }

        MaterialButton btnQuickDifficulty = findViewById(R.id.btn_quick_difficulty);
        if (btnQuickDifficulty != null) {
            btnQuickDifficulty.setOnClickListener(v -> {
                try {
                    showModeSelectionDialog();
                } catch (Exception ignored) {
                }
            });
        }

        MaterialButton btnQuickCourse = findViewById(R.id.btn_quick_course);
        if (btnQuickCourse != null) {
            btnQuickCourse.setOnClickListener(v -> {
                if (!_tutorialDone() && _tutorialStep() == 1) {
                    _setTutorialStep(2);
                }
                openCourseList();
                mainHandler.post(this::_showTutorialStepIfNeeded);
            });
        }

        playVideoButton = findViewById(R.id.btn_play_video);
        if (playVideoButton != null) {
            playVideoButton.setOnClickListener(v -> {
                try {
                    openSelectedTopicVideo(false);
                } catch (Exception e) {
                    Toast.makeText(MainActivity.this, "動画を開けませんでした", Toast.LENGTH_SHORT).show();
                }
            });
        }

        // btn_quick_plus: open English Practice Activity
        MaterialButton btnQuickPlus = findViewById(R.id.btn_quick_plus);
        if (btnQuickPlus != null) {
            btnQuickPlus.setOnClickListener(v -> {
                if (stopAnalyzePending || isJoiningOrJoined || isInRoom) {
                    Toast.makeText(MainActivity.this, "まず現在のの会話を終了してください", Toast.LENGTH_SHORT).show();
                    return;
                }
                if (selectedUnitId == null || selectedUnitId.trim().isEmpty()
                        || selectedTopicId == null || selectedTopicId.trim().isEmpty()) {
                    Toast.makeText(MainActivity.this, "まずコースを選択してください", Toast.LENGTH_SHORT).show();
                    return;
                }
                Intent it = new Intent(MainActivity.this, EnglishPracticeActivity.class);
                it.putExtra(EnglishPracticeActivity.EXTRA_UNIT_ID, selectedUnitId);
                it.putExtra(EnglishPracticeActivity.EXTRA_TOPIC_ID, selectedTopicId);
                startActivity(it);
            });
        }

        ensureClientId();
        updateCallToggleUi();
        updatePlayVideoButtonUi();

        mainHandler.post(() -> {
            if (selectedCoursePending) {
                startSelectedCourseWhenReady();
                return;
            }
            if (!_tutorialDone() && _tutorialStep() == 2) {
                boolean hasCourse = selectedTopicId != null && !selectedTopicId.trim().isEmpty();
                if (!hasCourse) {
                    _setTutorialStep(1);
                }
            }
            _showTutorialStepIfNeeded();
        });
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode == REQ_PRECHAT_VIDEO) {
            boolean continueAfterVideo = pendingCourseVideoConversation;
            pendingCourseVideoConversation = false;
            courseIntroPendingStart = false;
            if (continueAfterVideo) {
                mainHandler.post(this::startAiConversationFlow);
            }
        }
    }

    private void setupChatRecyclerView() {
        if (chatRecyclerView == null) return;
        chatLayoutManager = new LinearLayoutManager(this);
        chatLayoutManager.setStackFromEnd(true);
        chatRecyclerView.setLayoutManager(chatLayoutManager);
        chatAdapter = new ChatAdapter();
        try {
            chatAdapter.setOnDefineWordListener(word -> {
                try {
                    if (word == null || word.trim().isEmpty()) return;
                    requestDefine(word.trim(), "word");
                } catch (Exception ignored) {
                }
            });
        } catch (Exception ignored) {
        }
        chatRecyclerView.setAdapter(chatAdapter);
        chatAdapter.setItems(chatMessages);
    }

    private void maybeShowOnboardingChatMessage() {
        try {
            SharedPreferences sp = getSharedPreferences(PREFS_NAME, MODE_PRIVATE);
            boolean enabled = sp.getBoolean(PREF_SHOW_ONBOARDING_CHAT, true);
            boolean shown = sp.getBoolean(PREF_ONBOARDING_CHAT_SHOWN, false);
            if (!enabled || shown) return;

            String msg = "新規ユーザーガイド：\n"
                    + "1.『コース』をタップして練習内容を選択\n"
                    + "2. 動画がある場合、『動画』をタップしてデモを見る\n"
                    + "3. 点『シャドウイング+試験』或『原文扩展』切换流程\n"
                    + "4. 右上隅の『更多』には履歴/設定などの機能があります\n"
                    + "（之後は右上隅のチュートリアルで繰り返し確認できます）";

            // Add a small delay to ensure RecyclerView is ready
            mainHandler.postDelayed(() -> {
                try {
                    appendChatMessage(ChatMessage.Side.LEFT, msg);
                    sp.edit().putBoolean(PREF_ONBOARDING_CHAT_SHOWN, true).apply();
                } catch (Exception ignored) {}
            }, 500);
        } catch (Exception ignored) {
        }
    }

    private void clearConversationUiAndState() {
        try {
            chatMessages.clear();
            if (chatAdapter != null) {
                chatAdapter.clear();
            }
        } catch (Exception ignored) {
        }

        try {
            lastSequenceBySpeakerRound.clear();
            lastFinalSequenceBySpeakerRound.clear();
            lastFinalTextBySpeakerRound.clear();
            lastLiveTextBySpeaker.clear();
        } catch (Exception ignored) {
        }
        liveUserLine = "";
        liveAiLine = "";
        pendingWelcomeDedupText = null;
        lastHistoryKey = null;
        lastHistoryStart = 0;
        freeChatModeActive = false;
        freeChatSentences.clear();
    }


    private static String normalizeForSubtitleDedup(String s) {
        if (s == null) return "";
        // Remove all whitespace, zero-width spaces, and common punctuation so different
        // subtitle segmentations of the same welcome line match.
        String t = s;
        t = t.replace("\u200b", "");
        t = t.replaceAll("\\s+", "");
        t = t.replaceAll("[\\p{Punct}，。！？：；、「」『』“”‘’（）《》【】·…—\\-]", "");
        return t;
    }

    private static final class CourseLine {
        final String en;
        final String cn;

        CourseLine(String en, String cn) {
            this.en = en != null ? en.trim() : "";
            this.cn = cn != null ? cn.trim() : "";
        }
    }

    private static final class CourseQa {
        final String q;
        final String a;

        CourseQa(String q, String a) {
            this.q = q != null ? q.trim() : "";
            this.a = a != null ? a.trim() : "";
        }
    }

    private String currentStructuredCourseKey() {
        String uid = selectedUnitId != null ? selectedUnitId.trim() : "";
        String tid = selectedTopicId != null ? selectedTopicId.trim() : "";
        return uid + "|" + tid;
    }

    private void clearStructuredCourseFlow() {
        structuredCourseLoading = false;
        structuredCourseLoaded = false;
        lessonCourseEnabled = false;
        structuredCourseKey = null;
        courseIntroLines.clear();
        courseTranslateLines.clear();
        courseQaPairs.clear();
        showCourseIntroOverlay(false);
    }

    private void showCourseIntroOverlay(boolean show) {
        if (courseIntroOverlay == null) return;
        courseIntroOverlay.setVisibility(show ? View.VISIBLE : View.GONE);
    }

    private void restoreCourseIntroSkipButton() {
        if (courseIntroSkipButton != null) {
            courseIntroSkipButton.setText("スキップ");
            courseIntroSkipButton.setOnClickListener(v -> onCourseIntroSkipClicked());
        }
        if (courseIntroChineseTextView != null) {
            courseIntroChineseTextView.setVisibility(View.VISIBLE);
        }
        if (courseIntroProgressTextView != null) {
            courseIntroProgressTextView.setVisibility(View.VISIBLE);
        }
        if (courseIntroReplayButton != null) {
            courseIntroReplayButton.setVisibility(View.VISIBLE);
        }
        if (courseStageTextView != null) {
            courseStageTextView.setText("コースリスニング入力");
            courseStageTextView.setBackgroundColor(Color.parseColor("#DBEAFE"));
        }
    }

    private void bindCourseIntroLine(int index) {
        if (courseIntroEnglishTextView == null || courseIntroChineseTextView == null || courseIntroProgressTextView == null) {
            return;
        }
        if (index < 0 || index >= courseIntroLines.size()) return;
        CourseLine line = courseIntroLines.get(index);
        if (courseStageTextView != null) {
            courseStageTextView.setText("コースリスニング入力");
        }
        courseIntroEnglishTextView.setText(line.en);
        courseIntroChineseTextView.setText(line.cn);
        courseIntroProgressTextView.setText((index + 1) + " / " + courseIntroLines.size());
        // Show "もう一度聞く" only on the last line so the user can re-listen before we
        // transition to the AI conversation stage.
        if (courseIntroReplayButton != null) {
            boolean isLast = index == courseIntroLines.size() - 1;
            courseIntroReplayButton.setVisibility(isLast ? View.VISIBLE : View.GONE);
        }
    }

    private void refreshCourseIntroReplayButtonLabel() {
        if (courseIntroReplayButton == null) {
            return;
        }
        courseIntroReplayButton.setText("もう一度聞く");
        boolean show = false;
        if (!courseIntroLines.isEmpty()) {
            int lastIndex = courseIntroLines.size() - 1;
            int currentIndex = courseIntroPlayIndex;
            if (currentIndex < 0) {
                currentIndex = 0;
            }
            show = currentIndex >= lastIndex;
            if (!courseIntroPlaying && !courseIntroPendingStart) {
                show = true;
            }
        }
        courseIntroReplayButton.setVisibility(show ? View.VISIBLE : View.GONE);
    }

    private void releaseCourseBgmPlayer() {
        try {
            if (courseBgmPlayer != null) {
                courseBgmPlayer.stop();
            }
        } catch (Exception ignored) {
        }
        try {
            if (courseBgmPlayer != null) {
                courseBgmPlayer.release();
            }
        } catch (Exception ignored) {
        }
        courseBgmPlayer = null;
    }

    private void startCourseBgmIfAvailable() {
        releaseCourseBgmPlayer();
        try {
            // Use the centralized BgmManager: reads user prefs (enabled / volume / selected)
            // and picks a track from externalFilesDir("bgm") or assets/bgm/.
            courseBgmPlayer = BgmManager.start(this);
            BgmManager.applyVolume(courseBgmPlayer, this);
        } catch (Exception ignored) {
            releaseCourseBgmPlayer();
        }
    }

    private void stopCourseIntroPlayback(boolean byUser) {
        courseIntroPendingStart = false;
        courseIntroPlaying = false;
        courseIntroRequestId = null;
        courseIntroPlayIndex = 0;
        cancelCourseIntroFinishDelay();
        releaseCourseIntroPlayer();
        releaseCourseBgmPlayer();
        showCourseIntroOverlay(false);
        if (byUser) {
            Toast.makeText(this, "コース再生を停止しました", Toast.LENGTH_SHORT).show();
        }
    }

    private void releaseCourseIntroPlayer() {
        if (courseIntroTimeoutRunnable != null) {
            try {
                mainHandler.removeCallbacks(courseIntroTimeoutRunnable);
            } catch (Exception ignored) {
            }
        }
        courseIntroTimeoutRunnable = null;
        try {
            if (courseIntroPlayer != null) {
                courseIntroPlayer.stop();
            }
        } catch (Exception ignored) {
        }
        try {
            if (courseIntroPlayer != null) {
                courseIntroPlayer.release();
            }
        } catch (Exception ignored) {
        }
        courseIntroPlayer = null;
    }

    private String buildCourseIntroTtsUrl(String text) {
        String uid = (selectedUnitId != null ? selectedUnitId.trim() : "") + "_" + (selectedTopicId != null ? selectedTopicId.trim() : "") + "_" + courseIntroPlayIndex;
        return AIConfigHelper.AGENT_API_BASE_URL
                + "/tts/course_intro.wav?uid=" + Uri.encode(uid)
                + "&text=" + Uri.encode(text != null ? text.trim() : "");
    }

    private void cancelCourseIntroFinishDelay() {
        if (courseIntroFinishRunnable != null) {
            try {
                mainHandler.removeCallbacks(courseIntroFinishRunnable);
            } catch (Exception ignored) {
            }
        }
        courseIntroFinishRunnable = null;
    }

    private void playNextCourseIntroLine() {
        if (!courseIntroPlaying) return;
        if (courseIntroPlayIndex < 0 || courseIntroPlayIndex >= courseIntroLines.size()) {
            // After the last line finishes, hold the overlay for 3 seconds so the
            // user has a chance to tap "もう一度聞く" before we transition to part 2.
            cancelCourseIntroFinishDelay();
            courseIntroFinishRunnable = () -> {
                courseIntroFinishRunnable = null;
                if (!courseIntroPlaying) return;
                finishCourseIntroPlaybackAndStartConversation();
            };
            mainHandler.postDelayed(courseIntroFinishRunnable, 3000);
            return;
        }
        CourseLine line = courseIntroLines.get(courseIntroPlayIndex);
        if (line == null || line.en == null || line.en.trim().isEmpty()) {
            courseIntroPlayIndex += 1;
            mainHandler.post(this::playNextCourseIntroLine);
            return;
        }
        showCourseIntroOverlay(true);
        bindCourseIntroLine(courseIntroPlayIndex);
        String reqId = "lesson_intro_" + courseIntroPlayIndex + "_" + System.currentTimeMillis();
        courseIntroRequestId = reqId;
        releaseCourseIntroPlayer();
        courseIntroTimeoutRunnable = () -> {
            if (!courseIntroPlaying) return;
            if (courseIntroRequestId == null || !courseIntroRequestId.equals(reqId)) return;
            releaseCourseIntroPlayer();
            Toast.makeText(MainActivity.this, "课程音频获取超时，已直接进入会話", Toast.LENGTH_SHORT).show();
            finishCourseIntroPlaybackAndStartConversation();
        };
        mainHandler.postDelayed(courseIntroTimeoutRunnable, 7000);
        try {
            MediaPlayer mp = new MediaPlayer();
            courseIntroPlayer = mp;
            mp.setAudioStreamType(AudioManager.STREAM_MUSIC);
            mp.setOnPreparedListener(player -> {
                if (!courseIntroPlaying) {
                    try {
                        player.release();
                    } catch (Exception ignored) {
                    }
                    return;
                }
                if (courseIntroTimeoutRunnable != null) {
                    try {
                        mainHandler.removeCallbacks(courseIntroTimeoutRunnable);
                    } catch (Exception ignored) {
                    }
                    courseIntroTimeoutRunnable = null;
                }
                try {
                    player.start();
                } catch (Exception ignored) {
                    courseIntroPlayIndex += 1;
                    mainHandler.postDelayed(this::playNextCourseIntroLine, 280);
                }
            });
            mp.setOnCompletionListener(player -> {
                mainHandler.post(() -> {
                    if (!courseIntroPlaying) return;
                    if (courseIntroRequestId == null || !courseIntroRequestId.equals(reqId)) return;
                    releaseCourseIntroPlayer();
                    courseIntroPlayIndex += 1;
                    mainHandler.postDelayed(MainActivity.this::playNextCourseIntroLine, 280);
                });
            });
            mp.setOnErrorListener((player, what, extra) -> {
                mainHandler.post(() -> {
                    releaseCourseIntroPlayer();
                    if (!courseIntroPlaying) return;
                    if (courseIntroRequestId == null || !courseIntroRequestId.equals(reqId)) return;
                    courseIntroPlayIndex += 1;
                    mainHandler.postDelayed(MainActivity.this::playNextCourseIntroLine, 400);
                });
                return true;
            });
            mp.setDataSource(buildCourseIntroTtsUrl(line.en));
            mp.prepareAsync();
        } catch (Exception ignored) {
            releaseCourseIntroPlayer();
            courseIntroPlayIndex += 1;
            mainHandler.postDelayed(this::playNextCourseIntroLine, 400);
        }
    }

    private void finishCourseIntroPlaybackAndStartConversation() {
        courseIntroPlaying = false;
        courseIntroPendingStart = false;
        courseIntroRequestId = null;
        cancelCourseIntroFinishDelay();
        releaseCourseIntroPlayer();
        releaseCourseBgmPlayer();
        showCourseIntroOverlay(false);
        startAiConversationFlow();
    }

    private static JSONObject findTopicInUnitJson(JSONObject unit, String topicId) {
        try {
            if (unit == null) return null;
            JSONArray topics = unit.optJSONArray("topics");
            if (topics == null) return null;
            String tid = topicId != null ? topicId.trim() : "";
            for (int i = 0; i < topics.length(); i++) {
                JSONObject topic = topics.optJSONObject(i);
                if (topic == null) continue;
                if (tid.equals(topic.optString("topic_id", "").trim())) {
                    return topic;
                }
            }
        } catch (Exception ignored) {
        }
        return null;
    }

    private void parseStructuredCourseTopic(JSONObject topic) {
        courseIntroLines.clear();
        courseTranslateLines.clear();
        courseQaPairs.clear();
        lessonCourseEnabled = false;
        if (topic == null) return;
        try {
            JSONObject lessonFlow = topic.optJSONObject("lesson_flow");
            if (lessonFlow == null) return;

            JSONArray intro = lessonFlow.optJSONArray("intro_lines");
            if (intro != null) {
                for (int i = 0; i < intro.length(); i++) {
                    JSONObject item = intro.optJSONObject(i);
                    if (item == null) continue;
                    String en = item.optString("en", "").trim();
                    String cn = item.optString("cn", "").trim();
                    if (!en.isEmpty()) {
                        courseIntroLines.add(new CourseLine(en, cn));
                    }
                }
            }

            JSONArray drill = lessonFlow.optJSONArray("translation_drill");
            if (drill != null) {
                for (int i = 0; i < drill.length(); i++) {
                    JSONObject item = drill.optJSONObject(i);
                    if (item == null) continue;
                    String cn = item.optString("cn", "").trim();
                    String en = item.optString("en", "").trim();
                    if (!cn.isEmpty() && !en.isEmpty()) {
                        courseTranslateLines.add(new CourseLine(en, cn));
                    }
                }
            }

            JSONArray qa = lessonFlow.optJSONArray("qa_pairs");
            if (qa != null) {
                for (int i = 0; i < qa.length(); i++) {
                    JSONObject item = qa.optJSONObject(i);
                    if (item == null) continue;
                    String q = item.optString("q", "").trim();
                    String a = item.optString("a", "").trim();
                    if (!q.isEmpty() && !a.isEmpty()) {
                        courseQaPairs.add(new CourseQa(q, a));
                    }
                }
            }

            lessonCourseEnabled = !courseIntroLines.isEmpty() && (!courseTranslateLines.isEmpty() || !courseQaPairs.isEmpty());
        } catch (Exception ignored) {
            lessonCourseEnabled = false;
        }
    }

    private void loadStructuredCourseFlow(@Nullable Runnable onLoaded) {
        String uid = selectedUnitId != null ? selectedUnitId.trim() : "";
        String tid = selectedTopicId != null ? selectedTopicId.trim() : "";
        if (uid.isEmpty() || tid.isEmpty()) {
            clearStructuredCourseFlow();
            if (onLoaded != null) {
                runOnUiThread(onLoaded);
            }
            return;
        }

        String key = currentStructuredCourseKey();
        if (structuredCourseLoaded && key.equals(structuredCourseKey)) {
            if (onLoaded != null) {
                runOnUiThread(onLoaded);
            }
            return;
        }

        if (structuredCourseLoading) {
            if (onLoaded != null) {
                mainHandler.postDelayed(() -> loadStructuredCourseFlow(onLoaded), 180);
            }
            return;
        }

        structuredCourseLoading = true;
        String url = AIConfigHelper.AGENT_API_BASE_URL + "/training/units/" + uid;
        Request req = new Request.Builder().url(url).get().build();
        httpClient.newCall(req).enqueue(new Callback() {
            @Override
            public void onFailure(@NonNull Call call, @NonNull IOException e) {
                structuredCourseLoading = false;
                structuredCourseLoaded = false;
                lessonCourseEnabled = false;
                structuredCourseKey = null;
                if (onLoaded != null) {
                    mainHandler.post(onLoaded);
                }
            }

            @Override
            public void onResponse(@NonNull Call call, @NonNull Response response) throws IOException {
                String resStr = response.body() != null ? response.body().string() : "";
                structuredCourseLoading = false;
                structuredCourseLoaded = response.isSuccessful();
                structuredCourseKey = response.isSuccessful() ? key : null;
                lessonCourseEnabled = false;
                courseIntroLines.clear();
                courseTranslateLines.clear();
                courseQaPairs.clear();
                if (response.isSuccessful()) {
                    try {
                        JSONObject unit = new JSONObject(resStr);
                        JSONObject topic = findTopicInUnitJson(unit, tid);
                        parseStructuredCourseTopic(topic);
                    } catch (Exception ignored) {
                        lessonCourseEnabled = false;
                    }
                }
                if (onLoaded != null) {
                    mainHandler.post(onLoaded);
                }
            }
        });
    }

    private void startCourseIntroPlayback() {
        if (courseIntroLines.isEmpty()) {
            startAiConversationFlow();
            return;
        }
        if (courseIntroPlaying) {
            return;
        }
        courseIntroPlaying = true;
        courseIntroPendingStart = false;
        courseIntroPlayIndex = 0;
        courseIntroRequestId = null;
        startCourseBgmIfAvailable();
        showCourseIntroOverlay(true);
        bindCourseIntroLine(0);
        updateCallToggleUi();
        playNextCourseIntroLine();
    }

    private void onCourseIntroReplayClicked() {
        if (courseIntroLines.isEmpty()) {
            Toast.makeText(this, "現在のコースには再生可能なコンテンツがありません", Toast.LENGTH_SHORT).show();
            return;
        }
        // Reset playback state and start from the first line.
        cancelCourseIntroFinishDelay();
        courseIntroRequestId = null;
        releaseCourseIntroPlayer();
        courseIntroPlaying = true;
        courseIntroPendingStart = false;
        courseIntroPlayIndex = 0;
        startCourseBgmIfAvailable();
        showCourseIntroOverlay(true);
        bindCourseIntroLine(0);
        updateCallToggleUi();
        playNextCourseIntroLine();
    }

    private void onCourseIntroSkipClicked() {
        // Skip remaining intro playback / delay and jump straight into the conversation.
        cancelCourseIntroFinishDelay();
        releaseCourseIntroPlayer();
        if (!courseIntroPlaying && !courseIntroPendingStart) return;
        finishCourseIntroPlaybackAndStartConversation();
    }

    private void maybeStartStructuredCourseOrConversation() {
        if (selectedLessonStartStage < 2 && hasSelectedTopicVideo()) {
            openSelectedTopicVideo(true);
            return;
        }
        if (lessonCourseEnabled) {
            if (selectedLessonStartStage >= 3) {
                startAiConversationFlow();
                return;
            }
            if (selectedLessonStartStage >= 2) {
                startAiConversationFlow();
                return;
            }
            if (!courseIntroLines.isEmpty()) {
                startCourseIntroPlayback();
                return;
            }
            return;
        }
        startAiConversationFlow();
    }

    private void startAiConversationFlow() {
        autoSummonAfterJoin = true;
        if (isInRoom) {
            ensureSessionThenSummonIfNeeded();
            updateCallToggleUi();
            return;
        }
        clearConversationUiAndState();
        joinRoom();
        updateCallToggleUi();
    }

    private void appendChatMessage(ChatMessage.Side side, CharSequence text) {
        if (text == null) return;
        CharSequence t = text;
        try {
            String s = String.valueOf(t).trim();
            if (s.isEmpty()) return;
        } catch (Exception ignored) {
        }

        runOnUiThread(() -> {
            try {
                ChatMessage m = new ChatMessage(side, t);
                chatMessages.add(m);
                if (chatAdapter != null) {
                    chatAdapter.add(m);
                }
                scrollChatToBottom();
            } catch (Exception ignored2) {
            }
        });
    }

    private void scrollChatToBottom() {
        if (chatRecyclerView == null) return;
        int n = chatMessages.size();
        if (n <= 0) return;
        chatRecyclerView.post(() -> {
            try {
                chatRecyclerView.scrollToPosition(Math.max(0, n - 1));
            } catch (Exception ignored) {
            }
        });
    }

    @Override
    protected void onResume() {
        super.onResume();
        refreshDifficultyFromPrefsIfIdle();
        updateCallToggleUi();
        updatePlayVideoButtonUi();
        BgmManager.applyVolume(courseBgmPlayer, this);

        mainHandler.post(() -> {
            if (isFinishing() || isDestroyed()) return;
            refreshCourseIntroReplayButtonLabel();
            if (!_tutorialDone()) {
                int step = _tutorialStep();
                if (step == 1) {
                    boolean hasCourse = selectedTopicId != null && !selectedTopicId.trim().isEmpty();
                    if (hasCourse) _setTutorialStep(2);
                }
                _showTutorialStepIfNeeded();
            }
        });
    }

    private void refreshDifficultyFromPrefsIfIdle() {
        if (stopAnalyzePending || isJoiningOrJoined || isInRoom) {
            return;
        }
        try {
            SharedPreferences sp = getSharedPreferences(PREFS_NAME, MODE_PRIVATE);
            int d = sp.getInt(PREF_CHAT_DIFFICULTY, 1);
            if (d < 1) d = 1;
            if (d > 3) d = 3;
            selectedDifficulty = d;

            String cn = sp.getString(PREF_CHAT_CN_LEVEL, "mid");
            if (cn == null || cn.trim().isEmpty()) cn = "mid";
            cn = cn.trim().toLowerCase(Locale.US);
            if (!cn.equals("high") && !cn.equals("mid") && !cn.equals("low")) {
                cn = "mid";
            }
            selectedCnLevel = cn;

            String mode = sp.getString(PREF_CHAT_MODULES_MODE, "default");
            if (mode == null || mode.trim().isEmpty()) mode = "default";
            mode = mode.trim().toLowerCase(Locale.US);
            // backward compatible: old "custom" -> new "teach_test"
            if (mode.equals("custom")) mode = "teach_test";

            if (mode.equals("teach_test") || mode.equals("roleplay")) {
                String csv = sp.getString(PREF_CHAT_MODULES, "");
                ArrayList<String> mods = new ArrayList<>();
                if (csv != null && !csv.trim().isEmpty()) {
                    String[] parts = csv.split(",");
                    for (String p : parts) {
                        String s = (p != null) ? p.trim().toLowerCase(Locale.US) : "";
                        if (s.isEmpty()) continue;
                        if (!mods.contains(s)) mods.add(s);
                    }
                }
                selectedModules = mods.isEmpty() ? null : mods;
            } else {
                selectedModules = null;
            }
        } catch (Exception ignored) {
        }
    }

    private boolean isManualDifficultyOverrideEnabled() {
        try {
            SharedPreferences sp = getSharedPreferences(PREFS_NAME, MODE_PRIVATE);
            return sp.getBoolean(PREF_CHAT_DIFFICULTY_MANUAL, false);
        } catch (Exception e) {
            return false;
        }
    }

    private void setManualDifficultyOverrideEnabled(boolean v) {
        try {
            SharedPreferences sp = getSharedPreferences(PREFS_NAME, MODE_PRIVATE);
            sp.edit().putBoolean(PREF_CHAT_DIFFICULTY_MANUAL, v).apply();
        } catch (Exception ignored) {
        }
    }

    private void applyCourseDifficultyIfNotManualOverride(int courseDifficulty) {
        try {
            int d = courseDifficulty;
            if (d < 1) d = 1;
            if (d > 3) d = 3;
            SharedPreferences sp = getSharedPreferences(PREFS_NAME, MODE_PRIVATE);
            String modulesMode = sp.getString(PREF_CHAT_MODULES_MODE, "default");
            if (modulesMode == null || modulesMode.trim().isEmpty()) modulesMode = "default";
            modulesMode = modulesMode.trim().toLowerCase(Locale.US);

            // backward compatible: old "custom" -> new "teach_test"
            if (modulesMode.equals("custom")) modulesMode = "teach_test";

            // If user is not using default flow, respect user's manual settings and do not auto-override.
            if (!modulesMode.equals("default")) {
                return;
            }

            // Default (by difficulty): always follow the course difficulty.
            // This should override previous manual difficulty selection.
            selectedDifficulty = d;
            sp.edit()
                    .putInt(PREF_CHAT_DIFFICULTY, d)
                    .putBoolean(PREF_CHAT_DIFFICULTY_MANUAL, false)
                    .apply();
        } catch (Exception ignored) {
        }
    }

    @Override
    public boolean onCreateOptionsMenu(Menu menu) {
        getMenuInflater().inflate(R.menu.main_activity_menu, menu);

        try {
            MenuItem helpItem = menu.findItem(R.id.action_help);
            if (helpItem != null && helpItem.getIcon() != null) {
                helpItem.getIcon().setTint(getResources().getColor(R.color.kids_hint));
            }
            MenuItem moreItem = menu.findItem(R.id.action_more);
            if (moreItem != null && moreItem.getIcon() != null) {
                moreItem.getIcon().setTint(getResources().getColor(R.color.kids_hint));
            }
        } catch (Exception ignored2) {
        }

        return true;
    }

    @Override
    public boolean onOptionsItemSelected(@NonNull MenuItem item) {
        if (item.getItemId() == R.id.action_help) {
            try {
                tutorialForceShow = true;
                _sp().edit().putBoolean(PREF_TUTORIAL_DONE, false).apply();
                _setTutorialStep(1);
                _showTutorialStepIfNeeded();
            } catch (Exception ignored) {
            }
            return true;
        }
        if (item.getItemId() == R.id.action_more) {
            try {
                View anchor = null;
                try {
                    Toolbar tb = findViewById(R.id.top_app_bar);
                    if (tb != null) {
                        anchor = tb.findViewById(R.id.action_more);
                    }
                } catch (Exception ignored2) {
                }
                _showPlusPopupMenu(anchor);
            } catch (Exception ignored) {
            }
            return true;
        }
        if (item.getItemId() == R.id.action_history) {
            try {
                Intent it = new Intent(MainActivity.this, HistoryActivity.class);
                startActivity(it);
            } catch (Exception ignored) {
            }
            return true;
        }
        if (item.getItemId() == R.id.action_settings) {
            if (stopAnalyzePending || isJoiningOrJoined || isInRoom) {
                Toast.makeText(this, "请先会話を終了后再修改设置", Toast.LENGTH_SHORT).show();
                return true;
            }
            try {
                Intent it = new Intent(MainActivity.this, SettingsActivity.class);
                startActivity(it);
            } catch (Exception ignored) {
            }
            return true;
        }
        if (item.getItemId() == R.id.action_profile) {
            try {
                Intent it = new Intent(MainActivity.this, ProfileActivity.class);
                startActivity(it);
            } catch (Exception ignored) {
            }
            return true;
        }
        if (item.getItemId() == R.id.action_stats) {
            try {
                _showStatsDialog();
            } catch (Exception ignored) {
            }
            return true;
        }
        return super.onOptionsItemSelected(item);
    }

    private void _showPlusPopupMenu(@Nullable View preferredAnchor) {
        View anchor = preferredAnchor;
        if (anchor == null) {
            try {
                Toolbar tb = findViewById(R.id.top_app_bar);
                if (tb != null) {
                    anchor = tb.findViewById(R.id.action_more);
                    if (anchor == null) anchor = tb;
                }
            } catch (Exception ignored) {
            }
        }
        if (anchor == null) return;

        PopupMenu popup = new PopupMenu(new ContextThemeWrapper(this, R.style.ThemeOverlay_MyApplication_Kids_ToolbarPopup), anchor);
        popup.getMenuInflater().inflate(R.menu.plus_popup_menu, popup.getMenu());
        popup.setOnMenuItemClickListener(it -> {
            try {
                return MainActivity.this.onOptionsItemSelected(it);
            } catch (Exception ignored2) {
                return false;
            }
        });

        try {
            // Force show icons + force background (some OEMs ignore theme backgrounds).
            Field f = PopupMenu.class.getDeclaredField("mPopup");
            f.setAccessible(true);
            Object helper = f.get(popup);
            if (helper != null) {
                try {
                    Method setForceShowIcon = helper.getClass().getDeclaredMethod("setForceShowIcon", boolean.class);
                    setForceShowIcon.setAccessible(true);
                    setForceShowIcon.invoke(helper, true);
                } catch (Exception ignored3) {
                }
                try {
                    Method getPopup = helper.getClass().getDeclaredMethod("getPopup");
                    getPopup.setAccessible(true);
                    Object listPopupWindow = getPopup.invoke(helper);
                    if (listPopupWindow != null) {
                        Method setBackgroundDrawable = listPopupWindow.getClass().getMethod("setBackgroundDrawable", android.graphics.drawable.Drawable.class);
                        setBackgroundDrawable.invoke(listPopupWindow, getResources().getDrawable(R.drawable.bg_popup_menu_ios));
                    }
                } catch (Exception ignored4) {
                }
            }
        } catch (Exception ignored) {
        }

        popup.show();
    }

    private void openCourseList() {
        if (stopAnalyzePending || isJoiningOrJoined || isInRoom) {
            Toast.makeText(this, "请先会話を終了后再选择课程", Toast.LENGTH_SHORT).show();
            return;
        }
        try {
            Intent it = new Intent(MainActivity.this, TrainingSelectActivity.class);
            it.putExtra("skip_chapter", true);
            startActivity(it);
        } catch (Exception ignored) {
        }
    }

    private void showQuickDifficultyDialog() {
        if (stopAnalyzePending || isJoiningOrJoined || isInRoom) {
            Toast.makeText(this, "请先会話を終了后再修改難易度", Toast.LENGTH_SHORT).show();
            return;
        }

        int initDifficulty = selectedDifficulty;
        String initCn = (selectedCnLevel != null) ? selectedCnLevel : "mid";
        ArrayList<String> initMods = selectedModules;

        final String[] diffLabels = new String[]{"初級", "中級", "上級"};

        try {
            LinearLayout root = new LinearLayout(this);
            root.setOrientation(LinearLayout.VERTICAL);
            int pad = (int) (getResources().getDisplayMetrics().density * 16);
            root.setPadding(pad, pad, pad, pad);

            // Difficulty
            TextView tvDiff = new TextView(this);
            tvDiff.setText("難易度");
            root.addView(tvDiff);

            com.google.android.material.button.MaterialButtonToggleGroup tgDiff = new com.google.android.material.button.MaterialButtonToggleGroup(this);
            tgDiff.setSingleSelection(true);
            tgDiff.setSelectionRequired(true);
            LinearLayout.LayoutParams tgDiffLp = new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
            tgDiff.setLayoutParams(tgDiffLp);

            com.google.android.material.button.MaterialButton btnD1 = new com.google.android.material.button.MaterialButton(this, null, com.google.android.material.R.attr.materialButtonOutlinedStyle);
            btnD1.setText(diffLabels[0]);
            btnD1.setCheckable(true);
            com.google.android.material.button.MaterialButton btnD2 = new com.google.android.material.button.MaterialButton(this, null, com.google.android.material.R.attr.materialButtonOutlinedStyle);
            btnD2.setText(diffLabels[1]);
            btnD2.setCheckable(true);
            com.google.android.material.button.MaterialButton btnD3 = new com.google.android.material.button.MaterialButton(this, null, com.google.android.material.R.attr.materialButtonOutlinedStyle);
            btnD3.setText(diffLabels[2]);
            btnD3.setCheckable(true);

            LinearLayout.LayoutParams diffBtnLp = new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f);
            btnD1.setLayoutParams(diffBtnLp);
            btnD2.setLayoutParams(diffBtnLp);
            btnD3.setLayoutParams(diffBtnLp);

            tgDiff.addView(btnD1);
            tgDiff.addView(btnD2);
            tgDiff.addView(btnD3);

            if (initDifficulty == 2) tgDiff.check(btnD2.getId());
            else if (initDifficulty == 3) tgDiff.check(btnD3.getId());
            else tgDiff.check(btnD1.getId());

            root.addView(tgDiff);

            // Modules mode
            TextView tvMods = new TextView(this);
            tvMods.setText("モジュール拼接");
            root.addView(tvMods);

            RadioGroup rgModsMode = new RadioGroup(this);
            rgModsMode.setOrientation(RadioGroup.HORIZONTAL);
            MaterialRadioButton rbDefault = new MaterialRadioButton(this);
            rbDefault.setText("默认（按難易度）");
            MaterialRadioButton rbCustom = new MaterialRadioButton(this);
            rbCustom.setText("カスタム");

            RadioGroup.LayoutParams modsModeLp = new RadioGroup.LayoutParams(0, RadioGroup.LayoutParams.WRAP_CONTENT, 1f);
            rbDefault.setLayoutParams(modsModeLp);
            rbCustom.setLayoutParams(modsModeLp);
            rgModsMode.addView(rbDefault);
            rgModsMode.addView(rbCustom);
            boolean isCustom = initMods != null && !initMods.isEmpty();
            if (isCustom) rbCustom.setChecked(true);
            else rbDefault.setChecked(true);
            root.addView(rgModsMode);

            LinearLayout modsBox = new LinearLayout(this);
            modsBox.setOrientation(LinearLayout.VERTICAL);
            modsBox.setPadding(0, (int) (getResources().getDisplayMetrics().density * 4), 0, 0);
            CheckBox cbRepeat = new CheckBox(this);
            cbRepeat.setText("シャドウイング");
            CheckBox cbChat = new CheckBox(this);
            cbChat.setText("会話");
            CheckBox cbScript = new CheckBox(this);
            cbScript.setText("原文ロールプレイ");
            CheckBox cbExam = new CheckBox(this);
            cbExam.setText("試験");
            modsBox.addView(cbRepeat);
            modsBox.addView(cbChat);
            modsBox.addView(cbScript);
            modsBox.addView(cbExam);
            if (initMods != null) {
                cbRepeat.setChecked(initMods.contains("repeat"));
                cbChat.setChecked(initMods.contains("chat"));
                cbScript.setChecked(initMods.contains("script"));
                cbExam.setChecked(initMods.contains("exam"));
            } else {
                cbRepeat.setChecked(true);
                cbChat.setChecked(false);
                cbScript.setChecked(false);
                cbExam.setChecked(false);
            }
            root.addView(modsBox);

            // CN level
            TextView tvCn = new TextView(this);
            tvCn.setText("日本語含有量");
            root.addView(tvCn);

            RadioGroup rgCn = new RadioGroup(this);
            rgCn.setOrientation(RadioGroup.HORIZONTAL);
            MaterialRadioButton rbCnHigh = new MaterialRadioButton(this);
            rbCnHigh.setText("多");
            MaterialRadioButton rbCnMid = new MaterialRadioButton(this);
            rbCnMid.setText("中");
            MaterialRadioButton rbCnLow = new MaterialRadioButton(this);
            rbCnLow.setText("少");

            RadioGroup.LayoutParams cnLp = new RadioGroup.LayoutParams(0, RadioGroup.LayoutParams.WRAP_CONTENT, 1f);
            rbCnHigh.setLayoutParams(cnLp);
            rbCnMid.setLayoutParams(cnLp);
            rbCnLow.setLayoutParams(cnLp);
            rgCn.addView(rbCnHigh);
            rgCn.addView(rbCnMid);
            rgCn.addView(rbCnLow);
            String cn0 = (initCn != null) ? initCn.trim().toLowerCase(Locale.US) : "mid";
            if (cn0.equals("high")) rbCnHigh.setChecked(true);
            else if (cn0.equals("low")) rbCnLow.setChecked(true);
            else rbCnMid.setChecked(true);
            root.addView(rgCn);

            final boolean[] applyDefaultToModules = new boolean[]{!isCustom};
            Runnable refreshModulesBox = () -> {
                boolean custom = rbCustom.isChecked();
                if (custom) {
                    cbRepeat.setEnabled(true);
                    cbChat.setEnabled(true);
                    cbScript.setEnabled(true);
                    cbExam.setEnabled(true);
                    modsBox.setAlpha(1.0f);
                    applyDefaultToModules[0] = false;
                    return;
                }

                // Default mode: follow difficulty mapping and disallow editing.
                int d = 1;
                int checkedId = tgDiff.getCheckedButtonId();
                if (checkedId == btnD2.getId()) d = 2;
                else if (checkedId == btnD3.getId()) d = 3;

                boolean defRepeat = (d <= 2);
                boolean defChat = (d >= 2);
                boolean defScript = false;
                boolean defExam = (d >= 3);
                cbRepeat.setChecked(defRepeat);
                cbChat.setChecked(defChat);
                cbScript.setChecked(defScript);
                cbExam.setChecked(defExam);

                cbRepeat.setEnabled(false);
                cbChat.setEnabled(false);
                cbScript.setEnabled(false);
                cbExam.setEnabled(false);
                modsBox.setAlpha(0.6f);
                applyDefaultToModules[0] = true;
            };

            rgModsMode.setOnCheckedChangeListener((g, id) -> refreshModulesBox.run());
            tgDiff.addOnButtonCheckedListener((group, checkedId, isChecked) -> {
                if (!isChecked) return;
                refreshModulesBox.run();
            });
            refreshModulesBox.run();

            ScrollView sv = new ScrollView(this);
            sv.addView(root);

            new MaterialAlertDialogBuilder(this)
                    .setTitle("難易度 / 模块 / 中文")
                    .setView(sv)
                    .setPositiveButton("確定", (dialog, which) -> {
                        int d = 1;
                        int checkedId = tgDiff.getCheckedButtonId();
                        if (checkedId == btnD2.getId()) d = 2;
                        if (checkedId == btnD3.getId()) d = 3;
                        selectedDifficulty = d;

                        String cn = "mid";
                        if (rbCnHigh.isChecked()) cn = "high";
                        if (rbCnLow.isChecked()) cn = "low";
                        selectedCnLevel = cn;

                        boolean custom = rbCustom.isChecked();
                        if (custom) {
                            ArrayList<String> mods = new ArrayList<>();
                            if (cbRepeat.isChecked()) mods.add("repeat");
                            if (cbChat.isChecked()) mods.add("chat");
                            if (cbScript.isChecked()) mods.add("script");
                            if (cbExam.isChecked()) mods.add("exam");
                            selectedModules = mods.isEmpty() ? null : mods;
                        } else {
                            selectedModules = null;
                        }

                        try {
                            SharedPreferences sp = getSharedPreferences(PREFS_NAME, MODE_PRIVATE);
                            String mode = custom ? "custom" : "default";
                            String csv = "";
                            if (custom && selectedModules != null) {
                                csv = TextUtils.join(",", selectedModules);
                            }
                            sp.edit()
                                    .putInt(PREF_CHAT_DIFFICULTY, d)
                                    .putBoolean(PREF_CHAT_DIFFICULTY_MANUAL, true)
                                    .putString(PREF_CHAT_CN_LEVEL, selectedCnLevel)
                                    .putString(PREF_CHAT_MODULES_MODE, mode)
                                    .putString(PREF_CHAT_MODULES, csv)
                                    .apply();
                        } catch (Exception ignored2) {
                        }

                        String tip = "已保存：" + diffLabels[Math.max(0, Math.min(2, selectedDifficulty - 1))];
                        Toast.makeText(MainActivity.this, tip, Toast.LENGTH_SHORT).show();
                        dialog.dismiss();
                    })
                    .setNegativeButton("キャンセル", (d, w) -> {
                    })
                    .show();
        } catch (Exception ignored) {
        }
    }

    private void onCallToggleClicked() {
        if (stopAnalyzePending) {
            return;
        }

        if (freeChatModeActive) {
            freeChatModeActive = false;
            freeChatSentences.clear();
            currentMode = ModeType.NONE;
            pendingWelcomeDedupText = null;
            stopPcmRecordingInternal();
            // End the current voice chat task BEFORE clearing session state.
            // Must come before rtcRoom.destroy() / null assignments below.
            if (currentSessionId != null && !currentSessionId.trim().isEmpty()) {
                stopAndAnalyzeViaBackend(true);
            }
            if (rtcRoom != null) { rtcRoom.leaveRoom(); rtcRoom.destroy(); rtcRoom = null; }
            isJoiningOrJoined = false;
            isInRoom = false;
            autoSummonAfterJoin = false;
            hasSummonedAi = false;
            currentSessionId = null;
            currentBotUserId = null;
            stopAnalyzePending = false;
            updateCallToggleUi();
            return;
        }

        if (courseIntroPlaying) {
            stopCourseIntroPlayback(true);
            updateCallToggleUi();
            return;
        }

        if (isInRoom && hasSummonedAi) {
            // End: immediately leave room and switch UI, then do stop+analyze in background.
            if (!_tutorialDone() && _tutorialStep() == 5) {
                _finishTutorial();
            }
            stopAndAnalyzeViaBackend(true);
            leaveRoom();
            hasSummonedAi = false;
            updateCallToggleUi();
            return;
        }

        boolean hasTopic = selectedUnitId != null && !selectedUnitId.trim().isEmpty()
                && selectedTopicId != null && !selectedTopicId.trim().isEmpty();
        if (hasTopic) {
            selectedLessonStartStage = 1;
            loadStructuredCourseFlow(this::maybeStartStructuredCourseOrConversation);
            return;
        }

        selectedLessonStartStage = 1;
        startAiConversationFlow();
    }

    private void startSelectedCourseWhenReady() {
        if (!selectedCoursePending || isFinishing() || isDestroyed()) return;
        if (ActivityCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO)
                != PackageManager.PERMISSION_GRANTED) return;
        selectedCoursePending = false;
        onCallToggleClicked();
    }

    private void updateCallToggleUi() {
        final boolean inCall = (isInRoom && hasSummonedAi) || courseIntroPlaying || freeChatModeActive;

        try {
            if (inCall && !wasInCallForStats) {
                wasInCallForStats = true;
                _statsOnCallStarted();
            } else if ((!inCall) && wasInCallForStats) {
                wasInCallForStats = false;
                _statsOnCallEnded();
            }
        } catch (Exception ignored) {
        }

        if (callToggleIcon != null) {
            try {
                callToggleIcon.setImageResource(inCall ? R.drawable.ic_phone_hangup_outline : R.drawable.ic_phone_outline);
            } catch (Exception ignored) {
            }
        }

        try {
            int color;
            if (inCall) {
                color = getResources().getColor(R.color.kids_danger);
            } else {
                color = getResources().getColor(R.color.kids_call_button);
            }
            if (callToggleCard != null) {
                callToggleCard.setCardBackgroundColor(color);
            }
        } catch (Exception ignored) {
        }

        if (callToggleCard != null) {
            callToggleCard.setEnabled(!stopAnalyzePending);
        }

        try {
            if (getSupportActionBar() != null) {
                getSupportActionBar().setTitle("");
            }
        } catch (Exception ignored) {
        }
    }

    private void maybeStartAutoFlow() {
        if (!autoFlowEnabled) return;
        if (autoFlowTriggered) return;

        boolean isMainline = selectedMode != null && "mainline".equalsIgnoreCase(selectedMode);
        boolean isChapter = selectedMode != null && "chapter".equalsIgnoreCase(selectedMode);
        if (!isMainline && !isChapter) return;

        if (ActivityCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            autoFlowWaitingPermission = true;
            requestPermission();
            return;
        }

        autoFlowTriggered = true;
        autoFlowWaitingPermission = false;

        if (isInRoom) {
            autoSummonAfterJoin = true;
            ensureSessionThenSummonIfNeeded();
            return;
        }

        autoSummonAfterJoin = true;
        joinRoom();
    }

    private void ensureSessionThenSummonIfNeeded() {
        if (!autoSummonAfterJoin) return;
        if (!isInRoom) return;
        if (hasSummonedAi) return;
        if (currentSessionId != null && !currentSessionId.trim().isEmpty()) {
            runOnUiThread(this::summonAiViaBackend);
            return;
        }
        startBackendSession(() -> {
            if (hasSummonedAi) return;
            runOnUiThread(this::summonAiViaBackend);
        });
    }

    private void setupSubtitleLookup() {
        if (subtitlesTextView == null) return;

        try {
            subtitlesTextView.setTextIsSelectable(true);
        } catch (Exception ignored) {
        }

        try {
            subtitlesTextView.setCustomSelectionActionModeCallback(new ActionMode.Callback() {
                private static final int MENU_ID_DEFINE = 1001;

                @Override
                public boolean onCreateActionMode(ActionMode mode, Menu menu) {
                    try {
                        menu.add(0, MENU_ID_DEFINE, 0, "释义/翻译");
                    } catch (Exception ignored) {
                     }
                    return true;
                }

                @Override
                public boolean onPrepareActionMode(ActionMode mode, Menu menu) {
                    return true;
                }

                @Override
                public boolean onActionItemClicked(ActionMode mode, MenuItem item) {
                    if (item == null) return false;
                    if (item.getItemId() != MENU_ID_DEFINE) return false;

                    CharSequence cs = subtitlesTextView.getText();
                    if (!(cs instanceof Spannable)) return false;
                    Spannable sp = (Spannable) cs;
                    int s = Selection.getSelectionStart(sp);
                    int e = Selection.getSelectionEnd(sp);
                    if (s < 0 || e < 0 || s == e) return false;
                    int start = Math.min(s, e);
                    int end = Math.max(s, e);
                    if (start < 0 || end > sp.length()) return false;

                    String selected = String.valueOf(sp.subSequence(start, end)).trim();
                    if (selected.isEmpty()) return false;

                    String full = String.valueOf(sp);
                    if (!_isAiLineByOffset(full, start)) {
                        Toast.makeText(MainActivity.this, "只支持查询 AI 的句子/单词", Toast.LENGTH_SHORT).show();
                        mode.finish();
                        return true;
                    }

                    if (selectedDifficulty >= 2) {
                        Toast.makeText(MainActivity.this, "中上級難易度不做单词シャドウイング，专注句子/文章练习", Toast.LENGTH_SHORT).show();
                        mode.finish();
                        return true;
                    }

                    String selectedTrim = selected.trim();
                    if (!_looksLikeSingleEnglishWord(selectedTrim)) {
                        Toast.makeText(MainActivity.this, "请只选择一个英文单词", Toast.LENGTH_SHORT).show();
                        mode.finish();
                        return true;
                    }
                    requestDefine(selectedTrim, "word");
                    mode.finish();
                    return true;
                }

                @Override
                public void onDestroyActionMode(ActionMode mode) {
                }
            });
        } catch (Exception ignored) {
        }

        GestureDetector detector = new GestureDetector(
                this,
                new GestureDetector.SimpleOnGestureListener() {
                    @Override
                    public boolean onSingleTapConfirmed(MotionEvent e) {
                        try {
                            java.util.ArrayList<String> candidates = _candidateWordsAtTouchEvent(subtitlesTextView, e);
                            if (candidates.isEmpty()) {
                                runOnUiThread(() -> Toast.makeText(MainActivity.this, "没选中英文单词，请点英文单词本身", Toast.LENGTH_SHORT).show());
                                return true;
                            }
                            if (candidates.size() == 1) {
                                String w = candidates.get(0);
                                runOnUiThread(() -> Toast.makeText(MainActivity.this, "查询：" + w, Toast.LENGTH_SHORT).show());
                                requestDefine(candidates.get(0), "word");
                                return true;
                            }
                            new AlertDialog.Builder(MainActivity.this)
                                    .setTitle("选择要查询的单词")
                                    .setItems(candidates.toArray(new String[0]), (dialog, which) -> {
                                        try {
                                            if (which >= 0 && which < candidates.size()) {
                                                String w = candidates.get(which);
                                                runOnUiThread(() -> Toast.makeText(MainActivity.this, "查询：" + w, Toast.LENGTH_SHORT).show());
                                                requestDefine(candidates.get(which), "word");
                                            }
                                        } catch (Exception ignored) {
                                        }
                                    })
                                    .setNegativeButton("キャンセル", null)
                                    .show();
                            return true;
                        } catch (Exception ignored) {
                            return false;
                        }
                    }
                }
        );

        subtitlesTextView.setOnTouchListener((v, event) -> {
            try {
                boolean handled = detector.onTouchEvent(event);
                if (handled) return true;
            } catch (Exception ignored) {
            }
            return false;
        });
    }

    private static String _guessDefineKind(String selected) {
        String t = selected == null ? "" : selected.trim();
        if (t.isEmpty()) return "word";
        if (t.contains("\n")) return "sentence";
        int spaces = 0;
        for (int i = 0; i < t.length(); i++) {
            if (Character.isWhitespace(t.charAt(i))) spaces++;
        }
        if (spaces >= 1) return "sentence";
        if (t.length() > 18) return "sentence";
        return "word";
    }

    private static boolean _looksLikeSingleEnglishWord(String s) {
        if (s == null) return false;
        String t = s.trim();
        if (t.isEmpty()) return false;
        if (t.length() > 32) return false;
        for (int i = 0; i < t.length(); i++) {
            char c = t.charAt(i);
            boolean ok = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '\'' || c == '-';
            if (!ok) return false;
        }
        boolean hasLetter = false;
        for (int i = 0; i < t.length(); i++) {
            char c = t.charAt(i);
            if ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')) {
                hasLetter = true;
                break;
            }
        }
        return hasLetter;
    }

    private static boolean _isAsciiWordChar(char c) {
        return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '\'' || c == '-';
    }

    private static boolean _isAiLineByOffset(String full, int offset) {
        if (full == null) return false;
        int n = full.length();
        if (offset < 0 || offset > n) return false;
        int lineStart = full.lastIndexOf('\n', Math.max(0, offset - 1));
        lineStart = lineStart >= 0 ? (lineStart + 1) : 0;
        int lineEnd = full.indexOf('\n', offset);
        if (lineEnd < 0) lineEnd = n;
        String line = full.substring(lineStart, Math.min(lineEnd, n));
        String s = line != null ? line.trim() : "";
        if (s.isEmpty()) return false;

        // Robust speaker detection: allow dynamic bot names.
        // Rule: treat any non-user line as AI line.
        // Supports both ':' and '：' and also lines without any prefix.
        int iColon = s.indexOf(':');
        int iColonCn = s.indexOf('：');
        int i = -1;
        if (iColon >= 0 && iColonCn >= 0) i = Math.min(iColon, iColonCn);
        else if (iColon >= 0) i = iColon;
        else if (iColonCn >= 0) i = iColonCn;

        if (i >= 0 && i <= 6) {
            String who = s.substring(0, i).trim();
            if ("我".equals(who) || "Me".equalsIgnoreCase(who) || "User".equalsIgnoreCase(who)) {
                return false;
            }
            return true;
        }

        // No prefix: if it's not explicitly a user line, allow define.
        if (s.startsWith("我:") || s.startsWith("我：")) return false;
        return true;
    }

    private String _wordAtPosition(TextView tv, float rawX, float rawY) {
        if (tv == null) return null;
        CharSequence cs = tv.getText();
        if (cs == null) return null;
        String full = String.valueOf(cs);
        Layout layout = tv.getLayout();
        if (layout == null) return null;

        float x = rawX - tv.getTotalPaddingLeft() + tv.getScrollX();
        float y = rawY - tv.getTotalPaddingTop() + tv.getScrollY();
        if (x < 0) x = 0;
        if (y < 0) y = 0;

        int line = layout.getLineForVertical((int) y);
        int off = layout.getOffsetForHorizontal(line, x);
        if (off < 0 || off >= full.length()) return null;
        if (!_isAiLineByOffset(full, off)) return null;

        char ch = full.charAt(off);
        if (!_isAsciiWordChar(ch)) {
            if (off > 0 && _isAsciiWordChar(full.charAt(off - 1))) {
                off = off - 1;
            } else if (off + 1 < full.length() && _isAsciiWordChar(full.charAt(off + 1))) {
                off = off + 1;
            } else {
                return null;
            }
        }

        int s = off;
        int e2 = off + 1;
        while (s - 1 >= 0 && _isAsciiWordChar(full.charAt(s - 1))) s--;
        while (e2 < full.length() && _isAsciiWordChar(full.charAt(e2))) e2++;
        String w = full.substring(s, e2).trim();
        if (w.isEmpty()) return null;
        if (w.length() > 32) return null;
        return w;
    }

    private java.util.ArrayList<String> _candidateWordsAtTouchEvent(TextView tv, MotionEvent e) {
        java.util.ArrayList<String> out = new java.util.ArrayList<>();
        if (tv == null || e == null) return out;
        float x = e.getX();
        float y = e.getY();
        float density = tv.getResources().getDisplayMetrics().density;
        float dx = 14f * density;

        String w1 = _wordAtPosition(tv, x, y);
        String w2 = _wordAtPosition(tv, x - dx, y);
        String w3 = _wordAtPosition(tv, x + dx, y);

        if (w1 != null && !w1.trim().isEmpty()) out.add(w1.trim());
        if (w2 != null && !w2.trim().isEmpty() && !out.contains(w2.trim())) out.add(w2.trim());
        if (w3 != null && !w3.trim().isEmpty() && !out.contains(w3.trim())) out.add(w3.trim());
        return out;
    }

    private void requestDefine(String text, String kind) {
        try {
            if (text == null || text.trim().isEmpty()) return;
            String t = text.trim();
            String k = (kind != null ? kind.trim() : "word");

            try {
                _incTodayCounter(PREF_STATS_DAY_DEFINE_PREFIX);
            } catch (Exception ignored) {
            }

            try {
                Log.d(TAG, "requestDefine: text=" + t + " kind=" + k);
            } catch (Exception ignored) {
            }

            try {
                String dbgUrl = AIConfigHelper.AGENT_API_BASE_URL + "/define";
                runOnUiThread(() -> Toast.makeText(MainActivity.this, "发送単語検索请求：" + t, Toast.LENGTH_SHORT).show());
                try {
                    Log.d(TAG, "requestDefine url=" + dbgUrl);
                } catch (Exception ignored) {
                }
            } catch (Exception ignored) {
            }

            JSONObject payload = new JSONObject();
            payload.put("text", t);
            payload.put("kind", k);

            String url = AIConfigHelper.AGENT_API_BASE_URL + "/define";
            RequestBody body = RequestBody.create(payload.toString(), MediaType.parse("application/json; charset=utf-8"));
            Request req = new Request.Builder().url(url).post(body).build();
            httpClient.newCall(req).enqueue(new Callback() {
                @Override
                public void onFailure(@NonNull Call call, @NonNull IOException e) {
                    try {
                        Log.e(TAG, "define request failed: " + e.getMessage());
                    } catch (Exception ignored) {
                    }
                    runOnUiThread(() -> Toast.makeText(MainActivity.this, "查询失败：网络异常", Toast.LENGTH_SHORT).show());
                }

                @Override
                public void onResponse(@NonNull Call call, @NonNull Response response) throws IOException {
                    String resStr = response.body() != null ? response.body().string() : "";
                    try {
                        Log.d(TAG, "define resp=" + response.code() + " body=" + resStr);
                    } catch (Exception ignored) {
                    }
                    if (!response.isSuccessful()) {
                        runOnUiThread(() -> Toast.makeText(MainActivity.this, "查询失败：http=" + response.code(), Toast.LENGTH_SHORT).show());
                        return;
                    }
                    try {
                        JSONObject obj = new JSONObject(resStr);
                        if (!obj.optBoolean("ok", false)) {
                            runOnUiThread(() -> Toast.makeText(MainActivity.this, "查询失败", Toast.LENGTH_SHORT).show());
                            return;
                        }
                        runOnUiThread(() -> showDefineDialog(obj));
                    } catch (Exception e) {
                        runOnUiThread(() -> Toast.makeText(MainActivity.this, "查询解析失败", Toast.LENGTH_SHORT).show());
                    }
                }
            });
        } catch (Exception ignored) {
        }
    }

    private void showDefineDialog(JSONObject obj) {
        try {
            String kind = obj.optString("kind", "");
            String input = obj.optString("input", "");
            String meaningCn = obj.optString("meaning_cn", "");
            String translationCn = obj.optString("translation_cn", "");
            String simpleEnglish = obj.optString("simple_english", "");
            String exampleEn = obj.optString("example_en", "");
            String exampleCn = obj.optString("example_cn", "");

            String title = (input == null || input.trim().isEmpty()) ? "释义" : input;
            String mainText;
            if ("word".equalsIgnoreCase(kind)) {
                mainText = meaningCn != null ? meaningCn.trim() : "";
            } else {
                mainText = translationCn != null ? translationCn.trim() : "";
            }
            if (mainText == null) mainText = "";

            float density = getResources().getDisplayMetrics().density;
            int outerPad = (int) (14f * density);
            int cardPad = (int) (16f * density);
            int dividerH = Math.max(1, (int) (1f * density));
            int radius = (int) (14f * density);
            int strokeW = Math.max(1, (int) (1f * density));

            FrameLayout outer = new FrameLayout(this);
            outer.setPadding(outerPad, outerPad, outerPad, outerPad);

            LinearLayout card = new LinearLayout(this);
            card.setOrientation(LinearLayout.VERTICAL);
            card.setPadding(cardPad, cardPad, cardPad, cardPad);

            GradientDrawable bg = new GradientDrawable();
            bg.setColor(Color.WHITE);
            bg.setCornerRadius(radius);
            bg.setStroke(strokeW, 0xFFDDDDDD);
            card.setBackground(bg);
            try {
                ViewCompat.setElevation(card, 10f * density);
            } catch (Exception ignored) {
            }

            FrameLayout.LayoutParams lp = new FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.MATCH_PARENT,
                    FrameLayout.LayoutParams.WRAP_CONTENT
            );
            outer.addView(card, lp);

            TextView tvWord = new TextView(this);
            tvWord.setText(title);
            tvWord.setTextColor(0xFF111827);
            tvWord.setTypeface(Typeface.DEFAULT_BOLD);
            tvWord.setTextSize(TypedValue.COMPLEX_UNIT_SP, 20);
            tvWord.setPadding(0, 0, 0, (int) (10f * density));
            card.addView(tvWord);

            View divider = new View(this);
            divider.setBackgroundColor(0xFFEEF2F7);
            LinearLayout.LayoutParams dlp = new LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    dividerH
            );
            dlp.bottomMargin = (int) (12f * density);
            card.addView(divider, dlp);

            ScrollView sv = new ScrollView(this);
            TextView tvMeaning = new TextView(this);
            tvMeaning.setText(mainText.isEmpty() ? "（未找到释义）" : mainText);
            tvMeaning.setTextColor(0xFF374151);
            tvMeaning.setTextSize(TypedValue.COMPLEX_UNIT_SP, 16);
            tvMeaning.setLineSpacing(0f, 1.2f);
            sv.addView(tvMeaning);
            card.addView(sv);

            String copyText = (title + "\n" + tvMeaning.getText()).trim();
            new AlertDialog.Builder(this)
                    .setView(outer)
                    .setPositiveButton("閉じる", null)
                    .setNeutralButton("复制", (d, w) -> {
                        try {
                            ClipboardManager cm = (ClipboardManager) getSystemService(CLIPBOARD_SERVICE);
                            if (cm != null) {
                                cm.setPrimaryClip(ClipData.newPlainText("define", copyText));
                                Toast.makeText(MainActivity.this, "已复制", Toast.LENGTH_SHORT).show();
                            }
                        } catch (Exception ignored) {
                        }
                    })
                    .show();
        } catch (Exception e) {
            Toast.makeText(this, "展示失败", Toast.LENGTH_SHORT).show();
        }
    }

    private void ensureClientId() {
        SharedPreferences sp = getSharedPreferences(PREFS_NAME, MODE_PRIVATE);
        String cid = sp.getString(PREF_CLIENT_ID, null);
        if (cid == null || cid.trim().isEmpty()) {
            cid = java.util.UUID.randomUUID().toString();
            sp.edit().putString(PREF_CLIENT_ID, cid).apply();
        }
        currentClientId = cid;
    }

    private void ensureBootstrapThen(Runnable onOk) {
        if (currentUserId != null && currentRoomId != null && currentUserRtcToken != null && currentAppId != null) {
            onOk.run();
            return;
        }

        SharedPreferences sp = getSharedPreferences(PREFS_NAME, MODE_PRIVATE);
        String u = sp.getString(PREF_USERNAME, null);
        if (u == null || u.trim().isEmpty()) {
            runOnUiThread(() -> {
                Toast.makeText(MainActivity.this, "请先登录", Toast.LENGTH_SHORT).show();
                Intent it = new Intent(MainActivity.this, LoginActivity.class);
                startActivity(it);
                finish();
            });
            return;
        }

        String username = u.trim();
        bootstrapFromBackend(username, onOk);
    }

    private void bootstrapFromBackend(String userId, Runnable onOk) {
        try {
            String url = AIConfigHelper.AGENT_API_BASE_URL + "/users/" + userId + "/bootstrap?client_id=" + currentClientId;
            Request req = new Request.Builder().url(url).get().build();
            httpClient.newCall(req).enqueue(new Callback() {
                @Override
                public void onFailure(@NonNull Call call, @NonNull IOException e) {
                    Log.e(TAG, "bootstrap failed: " + e.getMessage());
                    runOnUiThread(() -> Toast.makeText(MainActivity.this, "bootstrap 失败：网络异常", Toast.LENGTH_LONG).show());
                }

                @Override
                public void onResponse(@NonNull Call call, @NonNull Response response) throws IOException {
                    String resStr = response.body() != null ? response.body().string() : "";
                    Log.d(TAG, "bootstrap HTTP " + response.code());
                    if (!response.isSuccessful()) {
                        runOnUiThread(() -> Toast.makeText(MainActivity.this, "bootstrap 失败：http=" + response.code(), Toast.LENGTH_LONG).show());
                        return;
                    }
                    try {
                        JSONObject obj = new JSONObject(resStr);
                        currentUserId = obj.optString("user_id", userId);
                        currentRoomId = obj.optString("room_id", null);
                        currentUserRtcToken = obj.optString("user_rtc_token", null);
                        currentAppId = obj.optString("app_id", null);
                        if (currentUserId == null || currentRoomId == null || currentUserRtcToken == null || currentAppId == null) {
                            runOnUiThread(() -> Toast.makeText(MainActivity.this, "bootstrap 数据不完整", Toast.LENGTH_LONG).show());
                            return;
                        }
                        runOnUiThread(() -> {
                            Toast.makeText(MainActivity.this, "已加载用户配置：" + currentUserId, Toast.LENGTH_SHORT).show();
                            onOk.run();
                        });
                    } catch (Exception e) {
                        Log.e(TAG, "parse bootstrap json failed: " + e.getMessage());
                        runOnUiThread(() -> Toast.makeText(MainActivity.this, "bootstrap 解析失败", Toast.LENGTH_LONG).show());
                    }
                }
            });
        } catch (Exception e) {
            Log.e(TAG, "bootstrap build failed: " + e.getMessage());
            Toast.makeText(this, "bootstrap 构造失败", Toast.LENGTH_LONG).show();
        }
    }

    private void ensureRtcEngineReady() {
        if (rtcEngine != null) {
            return;
        }
        EngineConfig engineConfig = new EngineConfig();
        engineConfig.context = this;
        engineConfig.appID = currentAppId;
        rtcEngine = RTCEngine.createRTCEngine(engineConfig, engineEventHandler);
        if (rtcEngine != null) {
            Log.d(TAG, "RTC 引擎初始化成功");
        }
    }

    private void joinRoom() {
        ensureBootstrapThen(() -> {
            ensureRtcEngineReady();
            joinRoomInternal();
        });
    }

    private void joinRoomInternal() {
        if (rtcEngine == null) return;

        if (ActivityCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            Toast.makeText(this, "请先授权麦克风权限", Toast.LENGTH_SHORT).show();
            requestPermission();
            return;
        }

        if (isJoiningOrJoined) {
            Log.d(TAG, "joinRoom 被忽略：正在进房或已在房间内");
            return;
        }
        isJoiningOrJoined = true;
        isInRoom = false;

        boolean rejoiningExisting = hasSummonedAi
                && currentSessionId != null
                && !currentSessionId.trim().isEmpty()
                && currentBotUserId != null
                && !currentBotUserId.trim().isEmpty();

        if (!rejoiningExisting) {
            hasSummonedAi = false;
            currentTaskId = AIConfigHelper.TASK_ID + "_" + System.currentTimeMillis();
        }

        runOnUiThread(() -> Toast.makeText(MainActivity.this, "正在加入房间...", Toast.LENGTH_SHORT).show());

        audioSessionActive = false;
        audioFinalizeInFlight = false;
        audioFinalized = false;
        audioChunkSeq = 0;

        // 【关键点 1】在进房前，确保麦克风已经开启采集
        // 有时 onCreate 里的调用会被系统权限延迟干扰，建议在 join 时再次显式开启
        rtcEngine.startAudioCapture();
        rtcEngine.muteAudioCapture(false);
        rtcEngine.setCaptureVolume(100);
        rtcEngine.setPlaybackVolume(100);
        rtcEngine.enableAudioEncoding(true);
        rtcEngine.enableAudioDecoding(true);

        // 注意：如果强制设置为扬声器，会导致插入耳机后仍从外放出声。
        // 这里仅在“没有耳机/蓝牙设备”时才默认走扬声器；否则交给系统/SDK 自动路由。
        try {
            AudioManager am = (AudioManager) getSystemService(AUDIO_SERVICE);
            if (am != null) {
                am.setMode(AudioManager.MODE_IN_COMMUNICATION);
                boolean hasHeadset = _hasExternalAudioOutput(am);
                rtcEngine.setDefaultAudioRoute(
                        hasHeadset
                                ? com.ss.bytertc.engine.data.AudioRoute.AUDIO_ROUTE_DEFAULT
                                : com.ss.bytertc.engine.data.AudioRoute.AUDIO_ROUTE_SPEAKERPHONE
                );
            } else {
                rtcEngine.setDefaultAudioRoute(com.ss.bytertc.engine.data.AudioRoute.AUDIO_ROUTE_DEFAULT);
            }
        } catch (Exception ignored) {
            try {
                rtcEngine.setDefaultAudioRoute(com.ss.bytertc.engine.data.AudioRoute.AUDIO_ROUTE_DEFAULT);
            } catch (Exception ignored2) {
            }
        }

        rtcRoom = rtcEngine.createRTCRoom(currentRoomId);
        rtcRoom.setRTCRoomEventHandler(rtcRoomEventHandler);

        UserInfo userInfo = new UserInfo(currentUserId, "");

        // 【关键点 2】 roomConfig 的参数定义了“你想做什么”
        // 第 2 个参数 true: 自动发布我的声音（如果不为 true，AI 就听不见你）
        // 第 3 个参数 true: 自动订阅别人的声音
        RTCRoomConfig roomConfig = new RTCRoomConfig(ChannelProfile.CHANNEL_PROFILE_CHAT_ROOM, true, true, true, false);

        // 【关键点 3】 joinRoom 的第 3 个参数必须为 true (isAutoPublish)
        // 这个 boolean 代表“我进房后立刻把我的声音发出去”
        int res = rtcRoom.joinRoom(currentUserRtcToken, userInfo, true, roomConfig);
        Log.d(TAG, "调用 joinRoom, 返回码: " + res);
    }

    private static boolean _hasExternalAudioOutput(AudioManager am) {
        if (am == null) return false;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                AudioDeviceInfo[] devices = am.getDevices(AudioManager.GET_DEVICES_OUTPUTS);
                if (devices == null) return false;
                for (AudioDeviceInfo d : devices) {
                    if (d == null) continue;
                    int t = d.getType();
                    if (t == AudioDeviceInfo.TYPE_WIRED_HEADSET
                            || t == AudioDeviceInfo.TYPE_WIRED_HEADPHONES
                            || t == AudioDeviceInfo.TYPE_BLUETOOTH_A2DP
                            || t == AudioDeviceInfo.TYPE_BLUETOOTH_SCO
                            || t == AudioDeviceInfo.TYPE_USB_HEADSET
                            || t == AudioDeviceInfo.TYPE_USB_DEVICE) {
                        return true;
                    }
                }
            } catch (Exception ignored) {
            }
            return false;
        }

        try {
            // Deprecated but works on old devices.
            return am.isWiredHeadsetOn() || am.isBluetoothA2dpOn() || am.isBluetoothScoOn();
        } catch (Exception ignored) {
            return false;
        }
    }

    private void startBackendSession() {
        startBackendSession(null);
    }

    private void startBackendSession(@Nullable Runnable onReady) {
        try {
            if (currentUserId == null || currentUserId.trim().isEmpty()) {
                return;
            }
            JSONObject payload = new JSONObject();
            payload.put("user_id", currentUserId);
            payload.put("client_id", currentClientId);

            String url = AIConfigHelper.AGENT_API_BASE_URL + "/sessions/start";
            RequestBody body = RequestBody.create(payload.toString(), MediaType.parse("application/json; charset=utf-8"));
            Request req = new Request.Builder().url(url).post(body).build();
            httpClient.newCall(req).enqueue(new Callback() {
                @Override
                public void onFailure(@NonNull Call call, @NonNull IOException e) {
                    Log.e(TAG, "sessions/start failed: " + e.getMessage());
                }

                @Override
                public void onResponse(@NonNull Call call, @NonNull Response response) throws IOException {
                    String resStr = response.body() != null ? response.body().string() : "";
                    Log.d(TAG, "sessions/start resp=" + response.code() + " body=" + resStr);
                    if (!response.isSuccessful()) {
                        return;
                    }
                    try {
                        JSONObject obj = new JSONObject(resStr);
                        String sid = obj.optString("session_id", "");
                        String bid = obj.optString("bot_user_id", "");
                        if (sid != null && !sid.trim().isEmpty()) {
                            currentSessionId = sid;
                        }
                        if (bid != null && !bid.trim().isEmpty()) {
                            currentBotUserId = bid;
                        }
                        if (onReady != null && currentSessionId != null && !currentSessionId.trim().isEmpty()) {
                            runOnUiThread(onReady);
                        }
                    } catch (Exception ignored) {
                    }
                }
            });
        } catch (Exception e) {
            Log.e(TAG, "sessions/start build failed: " + e.getMessage());
        }
    }


    private final IRTCRoomEventHandler rtcRoomEventHandler = new IRTCRoomEventHandler() {
        @Override
        public void onRoomStateChanged(String roomId, String uid, int state, String extraInfo) {
            Log.d(TAG, "房间状态改变回调触发: state=" + state + ", uid=" + uid + ", extraInfo=" + extraInfo);

            // state == 0 通常表示 JOIN_SUCCESS
            if (state == 0) {
                isJoiningOrJoined = true;
                isInRoom = true;
                if (hasSummonedAi) {
                    Log.d(TAG, "AIはもう呼び出されています：进房成功后恢复会話/录音");
                    startPcmRecordingIfNeeded();
                    runOnUiThread(() -> updateCallToggleUi());
                    return;
                }
                hasSummonedAi = false;
                if (autoSummonAfterJoin) {
                    startBackendSession(() -> ensureSessionThenSummonIfNeeded());
                } else {
                    startBackendSession();
                }
                runOnUiThread(() -> updateCallToggleUi());
            } else {
                // 进房失败/断开等，允许用户重新尝试 join
                isJoiningOrJoined = false;
                isInRoom = false;
                hasSummonedAi = false;
                audioSessionActive = false;
                audioFinalizeInFlight = false;
                audioFinalized = true;
                stopPcmRecordingInternal();
                final String errTip = "进房失败: state=" + state + (extraInfo != null && !extraInfo.isEmpty() ? (" extra=" + extraInfo) : "");
                runOnUiThread(() -> {
                    Toast.makeText(MainActivity.this, errTip, Toast.LENGTH_LONG).show();
                    updateCallToggleUi();
                });
            }
        }

        @Override
        public void onUserJoined(UserInfo userInfo) {
            Log.d(TAG, "发现新用户进场: " + userInfo.getUid());
            if (currentBotUserId != null && userInfo.getUid().equals(currentBotUserId)) {
                runOnUiThread(() -> Toast.makeText(MainActivity.this, "小宁已就位！", Toast.LENGTH_LONG).show());
            }
        }

        @Override
        public void onUserPublishStreamAudio(String streamId, StreamInfo streamInfo, boolean isPublish) {
            Log.d(TAG, "onUserPublishStreamAudio: streamId=" + streamId + ", uid=" + (streamInfo != null ? streamInfo.userId : "") + ", isPublish=" + isPublish);
        }

        @Override
        public void onAudioPublishStateChanged(String streamId, StreamInfo streamInfo, PublishState state, PublishStateChangeReason reason) {
            Log.d(TAG, "onAudioPublishStateChanged: state=" + state + ", reason=" + reason + ", streamId=" + streamId);
        }

        @Override
        public void onAudioSubscribeStateChanged(String streamId, StreamInfo streamInfo, SubscribeState state, SubscribeStateChangeReason reason) {
            Log.d(TAG, "onAudioSubscribeStateChanged: state=" + state + ", reason=" + reason + ", streamId=" + streamId);
        }

        @Override
        public void onRoomBinaryMessageReceived(String uid, ByteBuffer message) {
            if (message == null) return;

            ByteBuffer slice = message.slice();
            byte[] bytes = new byte[slice.remaining()];
            slice.get(bytes);

            String json = unpackSubtitle(bytes);
            if (json == null) return;
            handleSubtitleJson(json, uid);
        }

        @Override
        public void onRoomBinaryMessageReceived(long messageId, String uid, ByteBuffer message) {
            onRoomBinaryMessageReceived(uid, message);
        }
    };

    private String unpackSubtitle(byte[] message) {
        final int headerSize = 8;
        if (message.length < headerSize) return null;
        int magic = ((message[0] & 0xFF) << 24)
                | ((message[1] & 0xFF) << 16)
                | ((message[2] & 0xFF) << 8)
                | (message[3] & 0xFF);
        if (magic != 0x73756276) {
            return null;
        }
        int length = ((message[4] & 0xFF) << 24)
                | ((message[5] & 0xFF) << 16)
                | ((message[6] & 0xFF) << 8)
                | (message[7] & 0xFF);

        if (message.length - headerSize != length) {
            return null;
        }
        if (length <= 0) return "";
        return new String(message, headerSize, length, StandardCharsets.UTF_8);
    }

    private void handleSubtitleJson(String msg, String fallbackUid) {
        try {
            JSONObject root = new JSONObject(msg);
            if (!"subtitle".equals(root.optString("type"))) return;
            JSONArray data = root.optJSONArray("data");
            if (data == null || data.length() == 0) return;

            for (int i = 0; i < data.length(); i++) {
                JSONObject item = data.optJSONObject(i);
                if (item == null) continue;

                String text = item.optString("text", "");
                String speakerUserId = item.optString("userId", "");
                int roundId = item.optInt("roundId", -1);
                int sequence = item.optInt("sequence", -1);
                boolean definite = item.optBoolean("definite", false);
                boolean paragraph = item.optBoolean("paragraph", false);

                if (text == null || text.trim().isEmpty()) {
                    continue;
                }

                if (speakerUserId == null || speakerUserId.trim().isEmpty()) {
                    speakerUserId = fallbackUid;
                }
                if (speakerUserId == null || speakerUserId.trim().isEmpty()) {
                    continue;
                }

                boolean isUser = currentUserId != null && currentUserId.equals(speakerUserId);
                boolean shouldCommit = isUser ? (paragraph && definite) : definite;
                if (!shouldCommit) {
                    continue;
                }

                String key = (roundId >= 0) ? (speakerUserId + ":" + roundId) : speakerUserId;
                int lastSeq = lastSequenceBySpeakerRound.getOrDefault(key, -1);
                if (sequence >= 0 && lastSeq >= 0) {
                    if (sequence < lastSeq) {
                        // sequence 在新一轮会話里通常会从 1 重新开始（有时 roundId 缺失），这里视为新轮次，重置状态
                        lastSequenceBySpeakerRound.remove(key);
                        lastFinalSequenceBySpeakerRound.remove(key);
                        lastFinalTextBySpeakerRound.remove(key);
                        lastSeq = -1;
                    } else if (sequence == lastSeq) {
                        // 同一个 sequence 的重复回调：允许文本变长/变化时覆盖更新，否则丢弃
                        String lastLive = lastLiveTextBySpeaker.get(speakerUserId);
                        if (lastLive != null && lastLive.equals(text)) {
                            continue;
                        }
                    }
                }
                lastSequenceBySpeakerRound.put(key, sequence);

                int lastFinalSeq = lastFinalSequenceBySpeakerRound.getOrDefault(key, -1);
                if (lastFinalSeq >= 0 && sequence >= 0 && sequence <= lastFinalSeq && !paragraph) {
                    continue;
                }

                String speaker;
                if (currentUserId != null && currentUserId.equals(speakerUserId)) {
                    speaker = "我";
                } else if (currentBotUserId != null && currentBotUserId.equals(speakerUserId)) {
                    speaker = "小宁";
                } else {
                    speaker = speakerUserId;
                }

                if (shouldCommit) {
                    if (sequence >= 0 && lastFinalSeq >= 0 && sequence <= lastFinalSeq) {
                        continue;
                    }
                    String lastFinalText = lastFinalTextBySpeakerRound.get(key);
                    if (sequence < 0 && lastFinalText != null && lastFinalText.equals(text)) {
                        continue;
                    }

                    // Dedup the bot's welcome message: it was already appended directly
                    // from the /voicechat/start response, so skip the first RTC subtitle
                    // that matches it.
                    if (!isUser && pendingWelcomeDedupText != null) {
                        String norm = normalizeForSubtitleDedup(text);
                        if (!norm.isEmpty()
                                && (norm.equals(pendingWelcomeDedupText)
                                        || pendingWelcomeDedupText.contains(norm)
                                        || norm.contains(pendingWelcomeDedupText))) {
                            pendingWelcomeDedupText = null;
                            lastFinalSequenceBySpeakerRound.put(key, sequence);
                            lastFinalTextBySpeakerRound.put(key, text);
                            lastLiveTextBySpeaker.remove(speakerUserId);
                            liveAiLine = "";
                            continue;
                        }
                    }

                    if (!freeChatModeActive) {
                        Integer uttId = null;
                        if (currentUserId != null && currentUserId.equals(speakerUserId)) {
                            if (lastFinalizedUtteranceId > 0) {
                                uttId = lastFinalizedUtteranceId;
                                lastFinalizedUtteranceId = -1;
                            } else if (currentUtteranceId > 0) {
                                uttId = currentUtteranceId;
                            }
                        }
                        if (currentUserId != null && currentUserId.equals(speakerUserId) && paragraph && definite) {
                            postUtteranceToBackend(speakerUserId, text, roundId, sequence, definite, paragraph, false, uttId);
                        }

                        appendChatMessage(isUser ? ChatMessage.Side.RIGHT : ChatMessage.Side.LEFT, text);
                        lastFinalSequenceBySpeakerRound.put(key, sequence);
                        lastFinalTextBySpeakerRound.put(key, text);
                        lastLiveTextBySpeaker.remove(speakerUserId);
                        if (currentUserId != null && currentUserId.equals(speakerUserId)) {
                            liveUserLine = "";
                        } else {
                            liveAiLine = "";
                        }
                        continue;
                    }

                    appendChatMessage(isUser ? ChatMessage.Side.RIGHT : ChatMessage.Side.LEFT, text);
                    lastFinalSequenceBySpeakerRound.put(key, sequence);
                    lastFinalTextBySpeakerRound.put(key, text);
                    lastLiveTextBySpeaker.remove(speakerUserId);
                    if (currentUserId != null && currentUserId.equals(speakerUserId)) {
                        liveUserLine = "";
                    } else {
                        liveAiLine = "";
                    }
                    continue;
                }
            }
        } catch (Exception e) {
            Log.e(TAG, "字幕解析失败: " + e.getMessage());
        }
    }

    private static boolean _isScrollViewAtBottom(ScrollView sv) {
        if (sv == null) return true;
        try {
            if (sv.getChildCount() <= 0) return true;
            View child = sv.getChildAt(0);
            int diff = child.getBottom() - (sv.getHeight() + sv.getScrollY());
            return diff <= 32;
        } catch (Exception ignored) {
            return true;
        }
    }

    private int _colorForAccuracyForConversation(double acc) {
        if (acc < 60.0) {
            return Color.parseColor("#EF4444");
        }
        if (acc < 80.0) {
            return Color.parseColor("#F59E0B");
        }
        return Color.parseColor("#22C55E");
    }

    private void leaveRoom() {
        stopPcmRecordingInternal();
        audioSessionActive = false;
        audioFinalizeInFlight = false;
        audioFinalized = true;
        if (rtcRoom != null) { rtcRoom.leaveRoom(); rtcRoom.destroy(); rtcRoom = null; }

        isJoiningOrJoined = false;
        isInRoom = false;
        // Leaving the RTC room should be treated as a temporary disconnect.
        // Keep session/bot state so re-joining won't force a new AI summon.
        autoSummonAfterJoin = false;
        voiceWaveView = null;
    }

    private void requestPermission() {
        String[] ps = {Manifest.permission.RECORD_AUDIO};
        ActivityCompat.requestPermissions(this, ps, 22);
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, @NonNull String[] permissions, @NonNull int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode == 22) {
            boolean granted = grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED;
            if (granted) startSelectedCourseWhenReady();
            if (granted && autoFlowWaitingPermission) {
                autoFlowWaitingPermission = false;
                maybeStartAutoFlow();
            }
        }
    }

    IRTCEngineEventHandler engineEventHandler = new IRTCEngineEventHandler() {
        @Override
        public void onError(int err) {
            Log.e(TAG, "RTC onError: " + err);
        }

        @Override
        public void onWarning(int warn) {
            Log.w(TAG, "RTC onWarning: " + warn);
        }

        @Override
        public void onLocalAudioStateChanged(com.ss.bytertc.engine.IAudioSource audioSource, LocalAudioStreamState state, LocalAudioStreamError error) {
            Log.d(TAG, "onLocalAudioStateChanged: state=" + state + ", error=" + error);
        }

        @Override
        public void onRemoteAudioStateChanged(String streamId, StreamInfo streamInfo, RemoteAudioState state, RemoteAudioStateChangeReason reason) {
            String uid = streamInfo != null ? streamInfo.userId : "";
            Log.d(TAG, "onRemoteAudioStateChanged: uid=" + uid + ", state=" + state + ", reason=" + reason + ", streamId=" + streamId);
        }

        @Override
        public void onFirstRemoteAudioFrame(String streamId, StreamInfo streamInfo) {
            String uid = streamInfo != null ? streamInfo.userId : "";
            Log.d(TAG, "onFirstRemoteAudioFrame: uid=" + uid + ", streamId=" + streamId);
        }

        @Override
        public void onAudioRouteChanged(com.ss.bytertc.engine.data.AudioRoute route) {
            Log.d(TAG, "onAudioRouteChanged: " + route);
        }
    };
}
