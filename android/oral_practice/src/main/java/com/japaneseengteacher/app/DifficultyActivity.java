package com.japaneseengteacher.app;

import android.content.SharedPreferences;
import android.graphics.Color;
import android.os.Bundle;
import android.text.TextUtils;
import android.view.View;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.RadioGroup;
import android.widget.TextView;

import androidx.annotation.Nullable;
import androidx.appcompat.app.AppCompatActivity;
import androidx.core.content.ContextCompat;

import com.google.android.material.button.MaterialButton;
import com.google.android.material.button.MaterialButtonToggleGroup;

import java.util.ArrayList;
import java.util.Locale;

public class DifficultyActivity extends AppCompatActivity {

    private static final String PREFS_NAME = "ai_prefs";
    private static final String PREF_CHAT_DIFFICULTY = "chat_difficulty";
    private static final String PREF_CHAT_DIFFICULTY_MANUAL = "chat_difficulty_manual";
    private static final String PREF_CHAT_MODULES_MODE = "chat_modules_mode";
    private static final String PREF_CHAT_MODULES = "chat_modules";
    private static final String PREF_CHAT_CN_LEVEL = "chat_cn_level";

    private MaterialButtonToggleGroup tgDiff;
    private MaterialButton btnD1;
    private MaterialButton btnD2;
    private MaterialButton btnD3;

    private RadioGroup rgModsMode;
    private com.google.android.material.radiobutton.MaterialRadioButton rbDefault;
    private com.google.android.material.radiobutton.MaterialRadioButton rbCustom;
    private com.google.android.material.radiobutton.MaterialRadioButton rbRoleplayFlow;

    private RadioGroup rgRepeatMode;
    private com.google.android.material.radiobutton.MaterialRadioButton rbRepeatNone;
    private com.google.android.material.radiobutton.MaterialRadioButton rbRepeatWord;
    private com.google.android.material.radiobutton.MaterialRadioButton rbRepeatSentence;
    private com.google.android.material.radiobutton.MaterialRadioButton rbRepeatFast;

    private RadioGroup rgRoleplayScriptMode;
    private com.google.android.material.radiobutton.MaterialRadioButton rbRoleplayNone;
    private com.google.android.material.radiobutton.MaterialRadioButton rbRoleplayScriptGuided;
    private com.google.android.material.radiobutton.MaterialRadioButton rbRoleplayScriptStrict;
    private com.google.android.material.radiobutton.MaterialRadioButton rbRoleplayExtendGuided;

    private RadioGroup rgExamMode;
    private com.google.android.material.radiobutton.MaterialRadioButton rbExamNone;
    private com.google.android.material.radiobutton.MaterialRadioButton rbExamWord;
    private com.google.android.material.radiobutton.MaterialRadioButton rbExamSentence;
    private com.google.android.material.radiobutton.MaterialRadioButton rbExamMix;

    private MaterialButtonToggleGroup tgCn;
    private MaterialButton btnCnHigh;
    private MaterialButton btnCnMid;
    private MaterialButton btnCnLow;

    private LinearLayout modsBox;

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_difficulty);

        MaterialButton btnBack = findViewById(R.id.btn_back);
        if (btnBack != null) {
            btnBack.setOnClickListener(v -> finish());
        }

        tgDiff = findViewById(R.id.tg_difficulty);
        btnD1 = findViewById(R.id.btn_diff_1);
        btnD2 = findViewById(R.id.btn_diff_2);
        btnD3 = findViewById(R.id.btn_diff_3);

        rgModsMode = findViewById(R.id.rg_modules_mode);
        rbDefault = findViewById(R.id.rb_modules_default);
        rbCustom = findViewById(R.id.rb_modules_custom);
        rbRoleplayFlow = findViewById(R.id.rb_modules_roleplay);

        rgRepeatMode = findViewById(R.id.rg_repeat_mode);
        rbRepeatNone = findViewById(R.id.rb_repeat_none);
        rbRepeatWord = findViewById(R.id.rb_repeat_word);
        rbRepeatSentence = findViewById(R.id.rb_repeat_sentence);
        rbRepeatFast = findViewById(R.id.rb_repeat_fast);

        rgRoleplayScriptMode = findViewById(R.id.rg_roleplay_script_mode);
        rbRoleplayNone = findViewById(R.id.rb_roleplay_none);
        rbRoleplayScriptGuided = findViewById(R.id.rb_roleplay_script_guided);
        rbRoleplayScriptStrict = findViewById(R.id.rb_roleplay_script_strict);
        rbRoleplayExtendGuided = findViewById(R.id.rb_roleplay_extend_guided);

        rgExamMode = findViewById(R.id.rg_exam_mode);
        rbExamNone = findViewById(R.id.rb_exam_none);
        rbExamWord = findViewById(R.id.rb_exam_word);
        rbExamSentence = findViewById(R.id.rb_exam_sentence);
        rbExamMix = findViewById(R.id.rb_exam_mix);
        modsBox = findViewById(R.id.box_modules);

        tgCn = findViewById(R.id.tg_cn_level);
        btnCnHigh = findViewById(R.id.btn_cn_high);
        btnCnMid = findViewById(R.id.btn_cn_mid);
        btnCnLow = findViewById(R.id.btn_cn_low);

        ImageView ivDiff = findViewById(R.id.iv_icon_diff);
        if (ivDiff != null) ivDiff.setImageResource(R.drawable.ic_difficult);
        ImageView ivMods = findViewById(R.id.iv_icon_modules);
        if (ivMods != null) ivMods.setImageResource(R.drawable.ic_plus);
        ImageView ivCn = findViewById(R.id.iv_icon_cn);
        if (ivCn != null) ivCn.setImageResource(R.drawable.ic_profile);

        applyFromPrefs();

        if (tgCn != null) {
            tgCn.addOnButtonCheckedListener((group, checkedId, isChecked) -> {
                if (!isChecked) return;
                updateCnLevelStyles();
            });
        }

        Runnable refreshModulesBox = () -> {
            String flow = getSelectedModulesFlow();
            if (flow.equals("teach_test")) {
                // teaching + testing (repeat + exam only)
                applyTeachTestModuleSelectionIfEmpty();
                setRepeatModulesEditable(true);
                setExamModulesEditable(true);
                setRoleplayModulesEditable(false);
                if (rbRoleplayNone != null) rbRoleplayNone.setChecked(true);
            } else if (flow.equals("roleplay")) {
                // roleplay flow: roleplay only, no repeat, no exam
                applyRoleplayModuleSelectionIfEmpty();
                setRoleplayModulesEditable(true);
                setRepeatModulesEditable(false);
                setExamModulesEditable(false);
                if (rbRepeatNone != null) rbRepeatNone.setChecked(true);
                if (rbExamNone != null) rbExamNone.setChecked(true);
            } else {
                // fallback to teach_test
                applyTeachTestModuleSelectionIfEmpty();
                setRepeatModulesEditable(true);
                setExamModulesEditable(true);
                setRoleplayModulesEditable(false);
                if (rbRoleplayNone != null) rbRoleplayNone.setChecked(true);
            }
            updateModulesHint(flow);
        };

        if (rgModsMode != null) {
            rgModsMode.setOnCheckedChangeListener((g, id) -> refreshModulesBox.run());
        }

        if (tgDiff != null) {
            tgDiff.addOnButtonCheckedListener((group, checkedId, isChecked) -> {
                if (!isChecked) return;
                refreshModulesBox.run();
            });
        }

        refreshModulesBox.run();

        MaterialButton btnSave = findViewById(R.id.btn_save);
        if (btnSave != null) {
            btnSave.setOnClickListener(v -> {
                saveToPrefs();
                finish();
            });
        }
    }

    private void updateModulesHint(boolean custom) {
        try {
            TextView tvHint = findViewById(R.id.tv_hint);
            if (tvHint == null) return;
            tvHint.setTextColor(Color.parseColor("#666666"));
            updateModulesHint(getSelectedModulesFlow());
        } catch (Exception ignored) {
        }
    }

    private void updateModulesHint(String flow) {
        try {
            TextView tvHint = findViewById(R.id.tv_hint);
            if (tvHint == null) return;
            tvHint.setTextColor(Color.parseColor("#666666"));
            if (flow == null) flow = "default";
            flow = flow.trim().toLowerCase(Locale.US);
            if (flow.equals("roleplay")) {
                tvHint.setText(
                        "原文扮演：单独流程。只启用原文扮演模块（带提示/严格），不与考试同时选择。\n"
                                + "提示：原文扮演（带提示）=roleplay_script_guided。\n"
                );
                return;
            }
            if (flow.equals("teach_test")) {
                tvHint.setText(
                        "教学与测试：智能拼接跟读 + 考试流程（先跟读，后考试）。\n"
                                + "说明：该流程不会启用原文扮演。\n"
                );
                return;
            }
            // default
            tvHint.setText(
                    "默认：快速跟读 + 混合考试。\n"
                            + "（若要修改流程，请切换到“教学与测试”或“原文扮演”）\n"
            );
        } catch (Exception ignored) {
        }
    }

    private void setModulesEditable(boolean editable) {
        setRepeatModulesEditable(editable);
        setRoleplayModulesEditable(editable);
        setExamModulesEditable(editable);
        if (modsBox != null) modsBox.setAlpha(editable ? 1.0f : 0.6f);
    }

    private void setRepeatModulesEditable(boolean editable) {
        if (rgRepeatMode != null) {
            for (int i = 0; i < rgRepeatMode.getChildCount(); i++) {
                View v = rgRepeatMode.getChildAt(i);
                if (v != null) v.setEnabled(editable);
            }
        }
    }

    private void setRoleplayModulesEditable(boolean editable) {
        if (rgRoleplayScriptMode != null) {
            for (int i = 0; i < rgRoleplayScriptMode.getChildCount(); i++) {
                View v = rgRoleplayScriptMode.getChildAt(i);
                if (v != null) v.setEnabled(editable);
            }
        }
    }

    private void setExamModulesEditable(boolean editable) {
        if (rgExamMode != null) {
            for (int i = 0; i < rgExamMode.getChildCount(); i++) {
                View v = rgExamMode.getChildAt(i);
                if (v != null) v.setEnabled(editable);
            }
        }
    }

    private void applyDefaultModuleSelection() {
        try {
            if (rbRepeatFast != null) rbRepeatFast.setChecked(true);
            else if (rbRepeatSentence != null) rbRepeatSentence.setChecked(true);
            if (rbRoleplayNone != null) rbRoleplayNone.setChecked(true);
            if (rbExamMix != null) rbExamMix.setChecked(true);
            else if (rbExamNone != null) rbExamNone.setChecked(true);
        } catch (Exception ignored) {
        }
    }

    private void applyTeachTestModuleSelectionIfEmpty() {
        try {
            // ensure no roleplay in this flow
            if (rbRoleplayNone != null) rbRoleplayNone.setChecked(true);
            boolean hasRepeat = (rbRepeatWord != null && rbRepeatWord.isChecked())
                    || (rbRepeatSentence != null && rbRepeatSentence.isChecked())
                    || (rbRepeatFast != null && rbRepeatFast.isChecked());
            boolean hasExam = (rbExamWord != null && rbExamWord.isChecked())
                    || (rbExamSentence != null && rbExamSentence.isChecked())
                    || (rbExamMix != null && rbExamMix.isChecked());
            if (!hasRepeat) {
                if (rbRepeatFast != null) rbRepeatFast.setChecked(true);
                else if (rbRepeatSentence != null) rbRepeatSentence.setChecked(true);
            }
            if (!hasExam) {
                if (rbExamMix != null) rbExamMix.setChecked(true);
                else if (rbExamNone != null) rbExamNone.setChecked(true);
            }
        } catch (Exception ignored) {
        }
    }

    private void applyRoleplayModuleSelectionIfEmpty() {
        try {
            // roleplay flow uses guided by default
            boolean hasRoleplay = (rbRoleplayScriptGuided != null && rbRoleplayScriptGuided.isChecked())
                    || (rbRoleplayScriptStrict != null && rbRoleplayScriptStrict.isChecked())
                    || (rbRoleplayExtendGuided != null && rbRoleplayExtendGuided.isChecked());
            if (!hasRoleplay) {
                if (rbRoleplayScriptGuided != null) rbRoleplayScriptGuided.setChecked(true);
                else if (rbRoleplayScriptStrict != null) rbRoleplayScriptStrict.setChecked(true);
            }
            if (rbRepeatNone != null) rbRepeatNone.setChecked(true);
            if (rbExamNone != null) rbExamNone.setChecked(true);
        } catch (Exception ignored) {
        }
    }

    private String getSelectedModulesFlow() {
        try {
            if (rbRoleplayFlow != null && rbRoleplayFlow.isChecked()) return "roleplay";
            if (rbCustom != null && rbCustom.isChecked()) return "teach_test";
            return "teach_test";
        } catch (Exception ignored) {
            return "teach_test";
        }
    }

    private int getSelectedDifficulty() {
        try {
            if (tgDiff == null) return 1;
            int checkedId = tgDiff.getCheckedButtonId();
            if (btnD2 != null && checkedId == btnD2.getId()) return 2;
            if (btnD3 != null && checkedId == btnD3.getId()) return 3;
            return 1;
        } catch (Exception ignored) {
            return 1;
        }
    }

    private String getSelectedCnLevel() {
        try {
            if (tgCn == null) return "mid";
            int checkedId = tgCn.getCheckedButtonId();
            if (btnCnHigh != null && checkedId == btnCnHigh.getId()) return "high";
            if (btnCnLow != null && checkedId == btnCnLow.getId()) return "low";
            return "mid";
        } catch (Exception ignored) {
            return "mid";
        }
    }

    private void updateCnLevelStyles() {
        try {
            if (tgCn == null) return;
            int checkedId = tgCn.getCheckedButtonId();

            int colorOnBg = ContextCompat.getColor(this, R.color.kids_on_background);
            int colorSecondary = ContextCompat.getColor(this, R.color.kids_secondary);
            int colorWhite = ContextCompat.getColor(this, android.R.color.white);

            MaterialButton[] btns = new MaterialButton[]{btnCnHigh, btnCnMid, btnCnLow};
            for (MaterialButton b : btns) {
                if (b == null) continue;
                boolean checked = (checkedId != View.NO_ID && checkedId == b.getId());
                if (checked) {
                    b.setBackgroundColor(colorSecondary);
                    b.setTextColor(colorWhite);
                    b.setStrokeWidth(0);
                } else {
                    b.setBackgroundColor(Color.TRANSPARENT);
                    b.setTextColor(colorOnBg);
                    b.setStrokeColorResource(R.color.kids_secondary);
                    b.setStrokeWidth(1);
                }
            }
        } catch (Exception ignored) {
        }
    }

    private void applyFromPrefs() {
        try {
            SharedPreferences sp = getSharedPreferences(PREFS_NAME, MODE_PRIVATE);
            int d = sp.getInt(PREF_CHAT_DIFFICULTY, 1);
            if (d < 1) d = 1;
            if (d > 3) d = 3;

            String cn = sp.getString(PREF_CHAT_CN_LEVEL, "mid");
            if (cn == null || cn.trim().isEmpty()) cn = "mid";
            cn = cn.trim().toLowerCase(Locale.US);

            String mode = sp.getString(PREF_CHAT_MODULES_MODE, "default");
            if (mode == null || mode.trim().isEmpty()) mode = "default";
            mode = mode.trim().toLowerCase(Locale.US);

            // backward compatible: old "custom" -> new "teach_test"
            if (mode.equals("custom")) mode = "teach_test";

            if (tgDiff != null) {
                if (d == 2 && btnD2 != null) tgDiff.check(btnD2.getId());
                else if (d == 3 && btnD3 != null) tgDiff.check(btnD3.getId());
                else if (btnD1 != null) tgDiff.check(btnD1.getId());
            }

            if (tgCn != null) {
                if (cn.equals("high") && btnCnHigh != null) tgCn.check(btnCnHigh.getId());
                else if (cn.equals("low") && btnCnLow != null) tgCn.check(btnCnLow.getId());
                else if (btnCnMid != null) tgCn.check(btnCnMid.getId());
            }

            updateCnLevelStyles();

            boolean isTeachTest = mode.equals("teach_test");
            boolean isRoleplay = mode.equals("roleplay");
            if (rbDefault != null) rbDefault.setChecked(mode.equals("default"));
            if (rbCustom != null) rbCustom.setChecked(isTeachTest);
            if (rbRoleplayFlow != null) rbRoleplayFlow.setChecked(isRoleplay);

            if (isTeachTest || isRoleplay) {
                String csv = sp.getString(PREF_CHAT_MODULES, "");
                ArrayList<String> mods = new ArrayList<>();
                if (csv != null && !csv.trim().isEmpty()) {
                    String[] parts = csv.split(",");
                    for (String p : parts) {
                        if (p == null) continue;
                        String s = p.trim().toLowerCase(Locale.US);
                        if (s.isEmpty()) continue;
                        if (!mods.contains(s)) mods.add(s);
                    }
                }

                // repeat
                if (rgRepeatMode != null) {
                    if ((mods.contains("repeat_word") || mods.contains("repeat_sentence") || mods.contains("repeat_fast")) == false) {
                        if (rbRepeatNone != null) rbRepeatNone.setChecked(true);
                    } else if (mods.contains("repeat_word") && rbRepeatWord != null) {
                        rbRepeatWord.setChecked(true);
                    } else if (mods.contains("repeat_fast") && rbRepeatFast != null) {
                        rbRepeatFast.setChecked(true);
                    } else if (mods.contains("repeat_sentence") && rbRepeatSentence != null) {
                        rbRepeatSentence.setChecked(true);
                    }
                }

                // roleplay
                if (rgRoleplayScriptMode != null) {
                    if ((mods.contains("roleplay_script_guided") || mods.contains("roleplay_script_strict") || mods.contains("roleplay_extend_guided") || mods.contains("roleplay_extend_strict")) == false) {
                        if (rbRoleplayNone != null) rbRoleplayNone.setChecked(true);
                    } else if ((mods.contains("roleplay_extend_guided") || mods.contains("roleplay_extend_strict")) && rbRoleplayExtendGuided != null) {
                        rbRoleplayExtendGuided.setChecked(true);
                    } else if (mods.contains("roleplay_script_guided") && rbRoleplayScriptGuided != null) {
                        rbRoleplayScriptGuided.setChecked(true);
                    } else if (mods.contains("roleplay_script_strict") && rbRoleplayScriptStrict != null) {
                        rbRoleplayScriptStrict.setChecked(true);
                    }
                }

                // exam
                if (rgExamMode != null) {
                    if ((mods.contains("exam_word") || mods.contains("exam_sentence") || mods.contains("exam_mix")) == false) {
                        if (rbExamNone != null) rbExamNone.setChecked(true);
                    } else if (mods.contains("exam_word") && rbExamWord != null) {
                        rbExamWord.setChecked(true);
                    } else if (mods.contains("exam_sentence") && rbExamSentence != null) {
                        rbExamSentence.setChecked(true);
                    } else if (mods.contains("exam_mix") && rbExamMix != null) {
                        rbExamMix.setChecked(true);
                    }
                }

                // enforce mutual exclusivity by flow
                if (isRoleplay) {
                    applyRoleplayModuleSelectionIfEmpty();
                    setRoleplayModulesEditable(true);
                    setRepeatModulesEditable(false);
                    setExamModulesEditable(false);
                } else {
                    // teach_test
                    applyTeachTestModuleSelectionIfEmpty();
                    setRepeatModulesEditable(true);
                    setExamModulesEditable(true);
                    setRoleplayModulesEditable(false);
                    if (rbRoleplayNone != null) rbRoleplayNone.setChecked(true);
                }
            } else {
                applyDefaultModuleSelection();
                setRepeatModulesEditable(false);
                setRoleplayModulesEditable(false);
                setExamModulesEditable(false);
            }
            updateModulesHint(getSelectedModulesFlow());
        } catch (Exception ignored) {
        }
    }

    private void saveToPrefs() {
        try {
            int d = getSelectedDifficulty();
            String cn = getSelectedCnLevel();

            String mode = getSelectedModulesFlow();
            String csv = "";

            if (mode.equals("teach_test")) {
                ArrayList<String> mods = new ArrayList<>();
                // repeat optional
                if (rbRepeatWord != null && rbRepeatWord.isChecked()) mods.add("repeat_word");
                else if (rbRepeatFast != null && rbRepeatFast.isChecked()) mods.add("repeat_fast");
                else if (rbRepeatSentence != null && rbRepeatSentence.isChecked()) mods.add("repeat_sentence");

                // exam optional
                if (rbExamWord != null && rbExamWord.isChecked()) mods.add("exam_word");
                else if (rbExamSentence != null && rbExamSentence.isChecked()) mods.add("exam_sentence");
                else if (rbExamMix != null && rbExamMix.isChecked()) mods.add("exam_mix");
                if (!mods.isEmpty()) {
                    csv = TextUtils.join(",", mods);
                }
            } else if (mode.equals("roleplay")) {
                ArrayList<String> mods = new ArrayList<>();
                if (rbRoleplayExtendGuided != null && rbRoleplayExtendGuided.isChecked()) {
                    mods.add("roleplay_extend_guided");
                } else if (rbRoleplayScriptGuided != null && rbRoleplayScriptGuided.isChecked()) {
                    mods.add("roleplay_script_guided");
                } else if (rbRoleplayScriptStrict != null && rbRoleplayScriptStrict.isChecked()) {
                    mods.add("roleplay_script_strict");
                } else {
                    mods.add("roleplay_script_guided");
                }
                csv = TextUtils.join(",", mods);
            }

            SharedPreferences sp = getSharedPreferences(PREFS_NAME, MODE_PRIVATE);
            sp.edit()
                    .putInt(PREF_CHAT_DIFFICULTY, d)
                    .putBoolean(PREF_CHAT_DIFFICULTY_MANUAL, true)
                    .putString(PREF_CHAT_CN_LEVEL, cn)
                    .putString(PREF_CHAT_MODULES_MODE, mode)
                    .putString(PREF_CHAT_MODULES, csv)
                    .apply();
        } catch (Exception ignored) {
        }
    }
}
