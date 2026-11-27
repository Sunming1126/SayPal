package com.japaneseengteacher.app;

import android.app.AlertDialog;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.view.View;
import android.widget.ProgressBar;
import android.widget.TextView;
import android.widget.Toast;

import androidx.annotation.Nullable;
import androidx.appcompat.app.AppCompatActivity;

import androidx.media3.common.MediaItem;
import androidx.media3.common.PlaybackException;
import androidx.media3.common.Player;
import androidx.media3.exoplayer.ExoPlayer;
import androidx.media3.ui.PlayerView;

import com.google.android.material.appbar.MaterialToolbar;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.List;

public class VideoPlayerActivity extends AppCompatActivity {

    private static final long PREPARE_TIMEOUT_MS = 12000L;

    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private ExoPlayer player;
    private PlayerView playerView;
    private ProgressBar loading;
    private TextView errorText;
    private TextView btnQuality;
    private boolean playbackReady = false;

    /** Parsed stream list from video_streams JSON. */
    private static class StreamItem {
        final String definition;
        final String label;
        final String format;
        final String url;
        StreamItem(String definition, String label, String format, String url) {
            this.definition = definition;
            this.label = label;
            this.format = format;
            this.url = url;
        }
    }

    private final List<StreamItem> streams = new ArrayList<>();
    private int currentStreamIndex = -1;  // index into streams, -1 = original url
    private String defaultUrl = "";

    private final Runnable prepareTimeoutRunnable = () -> {
        if (playbackReady || isFinishing()) {
            return;
        }
        showErrorAndFinish("视频加载超时，请稍后重试");
    };

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_video_player);

        String url = null;
        String streamsJson = null;
        try {
            Intent it = getIntent();
            if (it != null) {
                url = it.getStringExtra("video_url");
                streamsJson = it.getStringExtra("video_streams");
            }
        } catch (Exception ignored) {
        }
        if (url == null) url = "";
        url = url.trim();
        defaultUrl = url;

        playerView = findViewById(R.id.player_view);
        MaterialToolbar toolbar = findViewById(R.id.toolbar);
        loading = findViewById(R.id.loading);
        errorText = findViewById(R.id.error_text);
        btnQuality = findViewById(R.id.btn_quality);

        if (toolbar != null) {
            toolbar.setTitle("视频预览");
            toolbar.setNavigationIcon(androidx.appcompat.R.drawable.abc_ic_ab_back_material);
            toolbar.setNavigationOnClickListener(v -> {
                setResult(RESULT_OK);
                finish();
            });
        }

        if (playerView == null) {
            Toast.makeText(this, "播放器初始化失败", Toast.LENGTH_SHORT).show();
            setResult(RESULT_CANCELED);
            finish();
            return;
        }

        // Parse streams JSON
        parseStreams(streamsJson);

        // Setup quality button
        setupQualityButton();

        if (url.isEmpty() && streams.isEmpty()) {
            if (errorText != null) {
                errorText.setText("video_url 为空");
                errorText.setVisibility(View.VISIBLE);
            }
            setResult(RESULT_CANCELED);
            finish();
            return;
        }

        // Start playback with default or best available URL
        String playUrl = url.isEmpty() ? (streams.isEmpty() ? "" : streams.get(0).url) : url;
        if (playUrl.isEmpty()) {
            if (errorText != null) {
                errorText.setText("无可播放的视频地址");
                errorText.setVisibility(View.VISIBLE);
            }
            setResult(RESULT_CANCELED);
            finish();
            return;
        }
        startPlayback(playUrl);
    }

    private void parseStreams(String streamsJson) {
        streams.clear();
        if (streamsJson == null || streamsJson.trim().isEmpty()) return;
        try {
            JSONArray arr = new JSONArray(streamsJson);
            for (int i = 0; i < arr.length(); i++) {
                JSONObject obj = arr.optJSONObject(i);
                if (obj == null) continue;
                String definition = obj.optString("definition", "");
                String label = obj.optString("label", definition);
                String format = obj.optString("format", "");
                String sUrl = obj.optString("url", "");
                if (sUrl.isEmpty()) continue;
                streams.add(new StreamItem(definition, label, format, sUrl));
            }
        } catch (Exception ignored) {
        }
    }

    private void setupQualityButton() {
        if (btnQuality == null) return;
        if (streams.size() <= 1) {
            // No quality choice needed
            btnQuality.setVisibility(View.GONE);
            return;
        }
        btnQuality.setVisibility(View.VISIBLE);
        // Find which stream matches the default URL
        currentStreamIndex = -1;
        for (int i = 0; i < streams.size(); i++) {
            if (streams.get(i).url.equals(defaultUrl)) {
                currentStreamIndex = i;
                break;
            }
        }
        updateQualityLabel();
        btnQuality.setOnClickListener(v -> showQualityDialog());
    }

    private void updateQualityLabel() {
        if (btnQuality == null) return;
        if (streams.size() > 1) {
            btnQuality.setText("清晰度");
        } else if (currentStreamIndex >= 0 && currentStreamIndex < streams.size()) {
            btnQuality.setText(streams.get(currentStreamIndex).label);
        } else {
            btnQuality.setText("默认");
        }
    }

    private void showQualityDialog() {
        if (streams.isEmpty()) return;
        String[] labels = new String[streams.size()];
        for (int i = 0; i < streams.size(); i++) {
            labels[i] = streams.get(i).label;
        }
        int checked = currentStreamIndex >= 0 ? currentStreamIndex : 0;
        new AlertDialog.Builder(this)
                .setTitle("选择清晰度")
                .setSingleChoiceItems(labels, checked, (dialog, which) -> {
                    dialog.dismiss();
                    if (which != currentStreamIndex) {
                        switchStream(which);
                    }
                })
                .setNegativeButton("取消", null)
                .show();
    }

    private void switchStream(int newIndex) {
        if (newIndex < 0 || newIndex >= streams.size()) return;
        StreamItem target = streams.get(newIndex);
        if (target.url.equals(getCurrentUrl())) {
            currentStreamIndex = newIndex;
            updateQualityLabel();
            return;
        }
        // Save current position for seamless switch
        long positionMs = 0;
        if (player != null) {
            positionMs = player.getCurrentPosition();
        }
        currentStreamIndex = newIndex;
        updateQualityLabel();
        startPlayback(target.url, positionMs);
    }

    private String getCurrentUrl() {
        if (player == null) return "";
        MediaItem item = player.getCurrentMediaItem();
        if (item == null || item.requestMetadata == null || item.requestMetadata.mediaUri == null) return "";
        return item.requestMetadata.mediaUri.toString();
    }

    private void startPlayback(String url) {
        startPlayback(url, 0);
    }

    private void startPlayback(String url, long positionMs) {
        try {
            if (loading != null) loading.setVisibility(View.VISIBLE);
            if (errorText != null) errorText.setVisibility(View.GONE);

            if (player == null) {
                player = new ExoPlayer.Builder(this).build();
                playerView.setPlayer(player);
                playerView.setControllerAutoShow(false);
                playerView.setControllerShowTimeoutMs(3000);
                // Hide controls initially; user taps screen to show them
                playerView.hideController();

                player.addListener(new Player.Listener() {
                    @Override
                    public void onPlaybackStateChanged(int playbackState) {
                        if (playbackState == Player.STATE_READY) {
                            playbackReady = true;
                            mainHandler.removeCallbacks(prepareTimeoutRunnable);
                            if (loading != null) loading.setVisibility(View.GONE);
                            return;
                        }
                        if (playbackState == Player.STATE_BUFFERING) {
                            if (loading != null) loading.setVisibility(View.VISIBLE);
                            return;
                        }
                        if (playbackState == Player.STATE_ENDED) {
                            setResult(RESULT_OK);
                            finish();
                        }
                    }

                    @Override
                    public void onPlayerError(PlaybackException error) {
                        showErrorAndFinish("视频播放失败");
                    }

                    @Override
                    public void onIsLoadingChanged(boolean isLoading) {
                        if (!playbackReady && loading != null) {
                            loading.setVisibility(isLoading ? View.VISIBLE : View.GONE);
                        }
                    }
                });
            }

            MediaItem mediaItem = new MediaItem.Builder()
                    .setUri(Uri.parse(url))
                    .build();
            player.setMediaItem(mediaItem);
            if (positionMs > 0) {
                player.setMediaItem(mediaItem, positionMs);
            } else {
                player.setMediaItem(mediaItem);
            }
            player.setRepeatMode(Player.REPEAT_MODE_OFF);
            player.setPlayWhenReady(true);
            player.prepare();

            playbackReady = false;
            mainHandler.removeCallbacks(prepareTimeoutRunnable);
            mainHandler.postDelayed(prepareTimeoutRunnable, PREPARE_TIMEOUT_MS);
        } catch (Exception e) {
            android.util.Log.e("VideoPlayer", "startPlayback exception", e);
            showErrorAndFinish("视频播放异常: " + e.getMessage());
        }
    }

    @Override
    protected void onStop() {
        android.util.Log.d("VideoPlayer", "onStop called");
        super.onStop();
        if (player != null) {
            player.pause();
        }
    }

    @Override
    protected void onDestroy() {
        android.util.Log.d("VideoPlayer", "onDestroy called");
        mainHandler.removeCallbacks(prepareTimeoutRunnable);
        releasePlayer();
        super.onDestroy();
    }

    private void showErrorAndFinish(String message) {
        android.util.Log.d("VideoPlayer", "showErrorAndFinish: " + message);
        playbackReady = false;
        mainHandler.removeCallbacks(prepareTimeoutRunnable);
        try {
            if (loading != null) loading.setVisibility(View.GONE);
        } catch (Exception ignored) {
        }
        if (errorText != null) {
            errorText.setText(message);
            errorText.setVisibility(View.VISIBLE);
        } else {
            Toast.makeText(this, message, Toast.LENGTH_SHORT).show();
        }
        setResult(RESULT_CANCELED);
        releasePlayer();
        finish();
    }

    private void releasePlayer() {
        if (player == null) {
            return;
        }
        android.util.Log.d("VideoPlayer", "releasePlayer called");
        try {
            player.release();
        } catch (Exception ignored) {
        }
        player = null;
    }
}
