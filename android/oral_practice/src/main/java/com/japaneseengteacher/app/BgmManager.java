package com.japaneseengteacher.app;

import android.content.Context;
import android.content.SharedPreferences;
import android.content.res.AssetFileDescriptor;
import android.content.res.AssetManager;
import android.media.AudioAttributes;
import android.media.MediaPlayer;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.BufferedInputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashSet;
import java.util.List;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/**
 * Centralized BGM (background music) management for the course intro stage.
 *
 * Audio sources, in listing order:
 *   1) External files dir:  <externalFilesDir>/bgm/*.{mp3,m4a,wav,ogg,aac}
 *      - Accessible via the device's file manager at:
 *        /Android/data/<package>/files/bgm/
 *      - Users can add/remove/rename BGM files here without rebuilding the APK.
 *   2) Bundled assets:      assets/bgm/*.{mp3,m4a,wav,ogg,aac}
 *      - Shipped inside the APK, always available.
 *
 * Persisted in SharedPreferences (name = "ai_prefs"):
 *   - bgm_enabled  (boolean, default true)
 *   - bgm_volume   (float 0..1, default 0.16)
 *   - bgm_selected (String identifier like "file:///..." or "asset://bgm/xx.mp3")
 */
public final class BgmManager {

    public enum Source { ASSET, FILE, CLOUD_CACHE }

    public static final class BgmItem {
        public final String displayName;
        public final String identifier;
        public final Source source;

        public BgmItem(String displayName, String identifier, Source source) {
            this.displayName = displayName;
            this.identifier = identifier;
            this.source = source;
        }

        @Override
        public String toString() {
            return displayName;
        }
    }

    public static final String PREFS_NAME = "ai_prefs";
    public static final String PREF_BGM_ENABLED = "bgm_enabled";
    public static final String PREF_BGM_VOLUME = "bgm_volume";
    public static final String PREF_BGM_SELECTED = "bgm_selected";

    private static final String TAG = "BgmManager";
    private static final String ASSET_BGM_DIR = "bgm";
    private static final String EXTERNAL_BGM_DIR = "bgm";
    private static final String CACHE_DIR_NAME = "bgm_cache";
    private static final String[] EXTS = { ".mp3", ".m4a", ".wav", ".ogg", ".aac" };

    private static final ExecutorService IO_POOL = Executors.newSingleThreadExecutor(r -> {
        Thread t = new Thread(r, "bgm-sync");
        t.setDaemon(true);
        return t;
    });

    public interface SyncCallback {
        /** Always invoked on the main thread. */
        void onComplete(int downloaded, int total, @androidx.annotation.Nullable String errorMessage);
    }

    private BgmManager() {}

    public static boolean isEnabled(Context ctx) {
        try {
            return sp(ctx).getBoolean(PREF_BGM_ENABLED, true);
        } catch (Exception e) {
            return true;
        }
    }

    public static void setEnabled(Context ctx, boolean v) {
        try {
            sp(ctx).edit().putBoolean(PREF_BGM_ENABLED, v).apply();
        } catch (Exception ignored) {}
    }

    public static float getVolume(Context ctx) {
        try {
            return sp(ctx).getFloat(PREF_BGM_VOLUME, 0.16f);
        } catch (Exception e) {
            return 0.16f;
        }
    }

    public static void setVolume(Context ctx, float v) {
        if (v < 0f) v = 0f;
        if (v > 1f) v = 1f;
        try {
            sp(ctx).edit().putFloat(PREF_BGM_VOLUME, v).apply();
        } catch (Exception ignored) {}
    }

    public static String getSelectedId(Context ctx) {
        try {
            return sp(ctx).getString(PREF_BGM_SELECTED, "");
        } catch (Exception e) {
            return "";
        }
    }

    public static void setSelectedId(Context ctx, String id) {
        try {
            sp(ctx).edit().putString(PREF_BGM_SELECTED, id == null ? "" : id).apply();
        } catch (Exception ignored) {}
    }

    public static List<BgmItem> listBgms(Context ctx) {
        ArrayList<BgmItem> out = new ArrayList<>();
        HashSet<String> seenNames = new HashSet<>();

        // 0) Cloud cache: <filesDir>/bgm_cache/*.{mp3,...}
        try {
            File cacheDir = cacheDir(ctx);
            if (cacheDir != null && cacheDir.isDirectory()) {
                File[] fs = cacheDir.listFiles();
                if (fs != null) {
                    for (File f : fs) {
                        if (f == null) continue;
                        if (f.isFile() && hasAudioExt(f.getName())) {
                            String id = "cloud://" + f.getName();
                            String name = stripExt(f.getName());
                            out.add(new BgmItem(name, id, Source.CLOUD_CACHE));
                            seenNames.add(f.getName().toLowerCase());
                        }
                    }
                }
            }
        } catch (Exception ignored) {}

        // 1) External files dir.
        try {
            File ext = ctx.getExternalFilesDir(EXTERNAL_BGM_DIR);
            if (ext != null) {
                if (!ext.exists()) {
                    try { ext.mkdirs(); } catch (Exception ignored) {}
                }
                if (ext.isDirectory()) {
                    File[] fs = ext.listFiles();
                    if (fs != null) {
                        for (File f : fs) {
                            if (f == null) continue;
                            if (f.isFile() && hasAudioExt(f.getName())) {
                                String id = "file://" + f.getAbsolutePath();
                                String name = stripExt(f.getName());
                                out.add(new BgmItem(name, id, Source.FILE));
                            }
                        }
                    }
                }
            }
        } catch (Exception ignored) {}

        // 2) Bundled assets.
        try {
            AssetManager am = ctx.getAssets();
            String[] names = am.list(ASSET_BGM_DIR);
            if (names != null) {
                for (String n : names) {
                    if (n == null) continue;
                    if (!hasAudioExt(n)) continue;
                    String id = "asset://" + ASSET_BGM_DIR + "/" + n;
                    String name = stripExt(n);
                    out.add(new BgmItem(name, id, Source.ASSET));
                }
            }
        } catch (IOException ignored) {}

        // Stable alphabetical ordering so Settings list is predictable.
        Collections.sort(out, (a, b) -> a.displayName.compareToIgnoreCase(b.displayName));
        return out;
    }

    /**
     * Start the currently selected BGM. Returns the MediaPlayer (looping) or null
     * if BGM is disabled, no files are available, or playback failed.
     * The caller owns the returned MediaPlayer and must stop/release it.
     */
    public static MediaPlayer start(Context ctx) {
        if (!isEnabled(ctx)) return null;
        List<BgmItem> items = listBgms(ctx);
        if (items.isEmpty()) return null;

        String selected = getSelectedId(ctx);
        BgmItem target = null;
        if (selected != null && !selected.isEmpty()) {
            for (BgmItem it : items) {
                if (selected.equals(it.identifier)) {
                    target = it;
                    break;
                }
            }
        }
        if (target == null) target = items.get(0);

        MediaPlayer mp = null;
        try {
            mp = new MediaPlayer();
            mp.setAudioAttributes(new AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build());
            if (target.source == Source.ASSET) {
                String rel = target.identifier.substring("asset://".length());
                AssetFileDescriptor afd = ctx.getAssets().openFd(rel);
                try {
                    mp.setDataSource(afd.getFileDescriptor(), afd.getStartOffset(), afd.getLength());
                } finally {
                    try { afd.close(); } catch (Exception ignored) {}
                }
            } else if (target.source == Source.CLOUD_CACHE) {
                String fname = target.identifier.substring("cloud://".length());
                File f = new File(cacheDir(ctx), fname);
                mp.setDataSource(f.getAbsolutePath());
            } else {
                String path = target.identifier.substring("file://".length());
                mp.setDataSource(path);
            }
            mp.setLooping(true);
            float v = getVolume(ctx);
            mp.setVolume(v, v);
            mp.prepare();
            mp.start();
            return mp;
        } catch (Exception e) {
            Log.w(TAG, "bgm start failed: " + e.getMessage());
            try { if (mp != null) mp.release(); } catch (Exception ignored) {}
            return null;
        }
    }

    public static void applyVolume(MediaPlayer mp, Context ctx) {
        if (mp == null) return;
        try {
            float v = getVolume(ctx);
            mp.setVolume(v, v);
        } catch (Exception ignored) {}
    }

    public static File externalBgmDir(Context ctx) {
        File ext = ctx.getExternalFilesDir(EXTERNAL_BGM_DIR);
        if (ext != null && !ext.exists()) {
            try { ext.mkdirs(); } catch (Exception ignored) {}
        }
        return ext;
    }

    /** Private cache directory for BGM files downloaded from the backend. */
    public static File cacheDir(Context ctx) {
        File base = ctx.getFilesDir();
        if (base == null) return null;
        File d = new File(base, CACHE_DIR_NAME);
        if (!d.exists()) {
            try { d.mkdirs(); } catch (Exception ignored) {}
        }
        return d;
    }

    /**
     * Sync the BGM library from the backend:
     *   1) GET {baseUrl}/bgm/list
     *   2) For every item missing in the local cache dir, download it.
     *   3) Delete local cache files that are no longer in the remote list.
     * The callback is invoked on the main thread.
     */
    public static void syncFromCloud(Context ctxIn, String baseUrl, @androidx.annotation.Nullable SyncCallback cb) {
        final Context ctx = ctxIn.getApplicationContext();
        final String base = baseUrl == null ? "" : baseUrl.trim();
        final Handler main = new Handler(Looper.getMainLooper());
        if (base.isEmpty()) {
            if (cb != null) main.post(() -> cb.onComplete(0, 0, "empty_base_url"));
            return;
        }
        IO_POOL.execute(() -> {
            int downloaded = 0;
            int total = 0;
            String err = null;
            try {
                String listUrl = base.endsWith("/") ? (base + "bgm/list") : (base + "/bgm/list");
                String json = httpGetString(listUrl);
                JSONObject root = new JSONObject(json);
                JSONArray arr = root.optJSONArray("items");
                if (arr == null) arr = new JSONArray();
                total = arr.length();

                File dir = cacheDir(ctx);
                if (dir == null) throw new IOException("no_cache_dir");

                HashSet<String> keep = new HashSet<>();
                for (int i = 0; i < arr.length(); i++) {
                    JSONObject it = arr.optJSONObject(i);
                    if (it == null) continue;
                    String name = it.optString("name", "");
                    String url = it.optString("url", "");
                    long size = it.optLong("size", -1L);
                    if (name.isEmpty() || url.isEmpty()) continue;
                    if (!hasAudioExt(name)) continue;
                    // Guard against path traversal.
                    if (name.contains("/") || name.contains("\\") || name.contains("..")) continue;
                    keep.add(name);

                    File out = new File(dir, name);
                    boolean already = out.exists() && out.isFile()
                            && (size <= 0 || out.length() == size);
                    if (already) continue;

                    String fullUrl = url.startsWith("http://") || url.startsWith("https://")
                            ? url
                            : (base.endsWith("/") ? base.substring(0, base.length() - 1) : base) + (url.startsWith("/") ? url : ("/" + url));
                    try {
                        downloadToFile(fullUrl, out);
                        downloaded += 1;
                    } catch (Exception de) {
                        Log.w(TAG, "bgm download failed name=" + name + " err=" + de.getMessage());
                        try { out.delete(); } catch (Exception ignored) {}
                    }
                }

                // Prune stale files no longer in the remote list.
                File[] existing = dir.listFiles();
                if (existing != null) {
                    for (File f : existing) {
                        if (f == null || !f.isFile()) continue;
                        if (!hasAudioExt(f.getName())) continue;
                        if (!keep.contains(f.getName())) {
                            try { f.delete(); } catch (Exception ignored) {}
                        }
                    }
                }
            } catch (Exception e) {
                err = e.getMessage();
                Log.w(TAG, "bgm sync failed: " + err);
            }
            final int d = downloaded;
            final int t = total;
            final String e = err;
            if (cb != null) main.post(() -> cb.onComplete(d, t, e));
        });
    }

    private static String httpGetString(String url) throws IOException {
        HttpURLConnection c = (HttpURLConnection) new URL(url).openConnection();
        try {
            c.setConnectTimeout(8000);
            c.setReadTimeout(12000);
            c.setRequestMethod("GET");
            int code = c.getResponseCode();
            if (code < 200 || code >= 300) {
                throw new IOException("http " + code);
            }
            try (InputStream in = new BufferedInputStream(c.getInputStream())) {
                java.io.ByteArrayOutputStream bos = new java.io.ByteArrayOutputStream();
                byte[] buf = new byte[4096];
                int n;
                while ((n = in.read(buf)) > 0) bos.write(buf, 0, n);
                return bos.toString("UTF-8");
            }
        } finally {
            try { c.disconnect(); } catch (Exception ignored) {}
        }
    }

    private static void downloadToFile(String url, File out) throws IOException {
        File tmp = new File(out.getParentFile(), out.getName() + ".part");
        HttpURLConnection c = (HttpURLConnection) new URL(url).openConnection();
        try {
            c.setConnectTimeout(10000);
            c.setReadTimeout(60000);
            c.setRequestMethod("GET");
            int code = c.getResponseCode();
            if (code < 200 || code >= 300) {
                throw new IOException("http " + code);
            }
            try (InputStream in = new BufferedInputStream(c.getInputStream());
                 FileOutputStream fos = new FileOutputStream(tmp)) {
                byte[] buf = new byte[8192];
                int n;
                while ((n = in.read(buf)) > 0) fos.write(buf, 0, n);
                fos.flush();
            }
        } finally {
            try { c.disconnect(); } catch (Exception ignored) {}
        }
        if (out.exists()) {
            try { out.delete(); } catch (Exception ignored) {}
        }
        if (!tmp.renameTo(out)) {
            throw new IOException("rename_failed");
        }
    }

    private static SharedPreferences sp(Context ctx) {
        return ctx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
    }

    private static boolean hasAudioExt(String n) {
        if (n == null) return false;
        String lower = n.toLowerCase();
        for (String e : EXTS) if (lower.endsWith(e)) return true;
        return false;
    }

    private static String stripExt(String n) {
        if (n == null) return "";
        int dot = n.lastIndexOf('.');
        if (dot <= 0) return n;
        return n.substring(0, dot);
    }
}
