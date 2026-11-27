package com.japaneseengteacher.app;

import android.content.SharedPreferences;
import android.os.Bundle;
import android.view.View;
import android.widget.AdapterView;
import android.widget.ArrayAdapter;
import android.widget.Spinner;
import android.widget.TextView;
import com.google.android.material.button.MaterialButton;
import com.google.android.material.materialswitch.MaterialSwitch;

import androidx.annotation.Nullable;
import androidx.appcompat.app.AppCompatActivity;

import java.util.ArrayList;
import java.util.List;

public class SettingsActivity extends AppCompatActivity {

    private static final String PREFS_NAME = "ai_prefs";
    private static final String PREF_SHOW_ANALYSIS_DIALOG = "show_analysis_dialog";
    private static final String PREF_SHOW_ONBOARDING_CHAT = "show_onboarding_chat";
    private static final String PREF_ONBOARDING_CHAT_SHOWN = "onboarding_chat_shown";
    private static final String PREF_ONBOARDING_TUTORIAL_SHOWN = "onboarding_tutorial_shown";

    private MaterialSwitch swShowAnalysisDialog;
    private MaterialSwitch swShowOnboardingChat;
    private MaterialButton btnBack;

    private MaterialSwitch swBgmEnabled;
    private TextView tvBgmHint;
    private Spinner spBgmSelected;
    private List<BgmManager.BgmItem> bgmItems = new ArrayList<>();

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_settings);

        swShowAnalysisDialog = findViewById(R.id.sw_show_analysis_dialog);
        swShowOnboardingChat = findViewById(R.id.sw_show_onboarding_chat);
        btnBack = findViewById(R.id.btn_back);

        if (btnBack != null) {
            btnBack.setOnClickListener(v -> finish());
        }

        boolean showDialog = loadShowAnalysisDialog();
        if (swShowAnalysisDialog != null) {
            swShowAnalysisDialog.setChecked(showDialog);
            swShowAnalysisDialog.setOnCheckedChangeListener((buttonView, isChecked) -> saveShowAnalysisDialog(isChecked));
        }

        boolean showOnboarding = loadShowOnboardingChat();
        if (swShowOnboardingChat != null) {
            swShowOnboardingChat.setChecked(showOnboarding);
            swShowOnboardingChat.setOnCheckedChangeListener((buttonView, isChecked) -> saveShowOnboardingChat(isChecked));
        }

        setupBgmSection();
    }

    private void setupBgmSection() {
        swBgmEnabled = findViewById(R.id.sw_bgm_enabled);
        tvBgmHint = findViewById(R.id.tv_bgm_hint);
        spBgmSelected = findViewById(R.id.sp_bgm_selected);

        if (swBgmEnabled != null) {
            swBgmEnabled.setChecked(BgmManager.isEnabled(this));
            swBgmEnabled.setOnCheckedChangeListener((b, v) -> BgmManager.setEnabled(this, v));
        }

        reloadBgmSpinner();

        // Kick off a cloud sync in the background. When it returns, refresh the spinner.
        if (tvBgmHint != null) {
            tvBgmHint.setText("正在从云端同步背景音乐…");
        }
        BgmManager.syncFromCloud(this, AIConfigHelper.AGENT_API_BASE_URL, (downloaded, total, err) -> {
            reloadBgmSpinner();
            if (tvBgmHint == null) return;
            if (err != null) {
                tvBgmHint.setText("云端同步失败：" + err + "（仍可使用已缓存/内置的 BGM）");
            } else if (total == 0) {
                tvBgmHint.setText("云端暂无可用 BGM，可继续使用本地/内置音乐。");
            } else {
                tvBgmHint.setText("云端 BGM 已同步（共 " + total + " 首，本次新下载 " + downloaded + " 首）。");
            }
        });
    }

    private void reloadBgmSpinner() {
        if (spBgmSelected == null) return;
        bgmItems = BgmManager.listBgms(this);
        ArrayList<String> labels = new ArrayList<>();
        if (bgmItems.isEmpty()) {
            labels.add("（未找到 BGM 文件）");
        } else {
            for (BgmManager.BgmItem it : bgmItems) {
                String tag;
                switch (it.source) {
                    case CLOUD_CACHE: tag = "[云端]"; break;
                    case FILE:        tag = "[外置]"; break;
                    default:          tag = "[内置]"; break;
                }
                labels.add(tag + " " + it.displayName);
            }
        }
        ArrayAdapter<String> adapter = new ArrayAdapter<>(
                this, android.R.layout.simple_spinner_item, labels);
        adapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);
        spBgmSelected.setAdapter(adapter);

        String sel = BgmManager.getSelectedId(this);
        int idx = 0;
        if (sel != null && !sel.isEmpty()) {
            for (int i = 0; i < bgmItems.size(); i++) {
                if (sel.equals(bgmItems.get(i).identifier)) {
                    idx = i;
                    break;
                }
            }
        }
        if (!bgmItems.isEmpty()) {
            spBgmSelected.setSelection(idx, false);
        }

        spBgmSelected.setOnItemSelectedListener(new AdapterView.OnItemSelectedListener() {
            @Override
            public void onItemSelected(AdapterView<?> parent, View view, int position, long id) {
                if (bgmItems == null || position < 0 || position >= bgmItems.size()) return;
                BgmManager.setSelectedId(SettingsActivity.this, bgmItems.get(position).identifier);
            }

            @Override
            public void onNothingSelected(AdapterView<?> parent) {}
        });
    }

    private boolean loadShowAnalysisDialog() {
        try {
            SharedPreferences sp = getSharedPreferences(PREFS_NAME, MODE_PRIVATE);
            return sp.getBoolean(PREF_SHOW_ANALYSIS_DIALOG, false);
        } catch (Exception e) {
            return false;
        }
    }

    private void saveShowAnalysisDialog(boolean v) {
        try {
            SharedPreferences sp = getSharedPreferences(PREFS_NAME, MODE_PRIVATE);
            sp.edit().putBoolean(PREF_SHOW_ANALYSIS_DIALOG, v).apply();
        } catch (Exception ignored) {
        }
    }

    private boolean loadShowOnboardingChat() {
        try {
            SharedPreferences sp = getSharedPreferences(PREFS_NAME, MODE_PRIVATE);
            return sp.getBoolean(PREF_SHOW_ONBOARDING_CHAT, true);
        } catch (Exception e) {
            return true;
        }
    }

    private void saveShowOnboardingChat(boolean v) {
        try {
            SharedPreferences sp = getSharedPreferences(PREFS_NAME, MODE_PRIVATE);
            SharedPreferences.Editor ed = sp.edit().putBoolean(PREF_SHOW_ONBOARDING_CHAT, v);
            if (v) {
                ed.putBoolean(PREF_ONBOARDING_CHAT_SHOWN, false);
                ed.putBoolean(PREF_ONBOARDING_TUTORIAL_SHOWN, false);
            }
            ed.apply();
        } catch (Exception ignored) {
        }
    }
}
