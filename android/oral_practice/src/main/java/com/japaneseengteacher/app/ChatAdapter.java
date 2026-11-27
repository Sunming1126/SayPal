package com.japaneseengteacher.app;

import android.text.TextUtils;
import android.text.Layout;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.MotionEvent;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;

import android.view.GestureDetector;

import java.util.ArrayList;
import java.util.List;

public class ChatAdapter extends RecyclerView.Adapter<ChatAdapter.VH> {

    private static final String TAG = "ChatAdapter";

    private static final int VT_LEFT = 1;
    private static final int VT_RIGHT = 2;

    private final ArrayList<ChatMessage> items = new ArrayList<>();

    public interface OnDefineWordListener {
        void onDefineWord(String word);
    }

    private OnDefineWordListener onDefineWordListener;

    public void setOnDefineWordListener(OnDefineWordListener l) {
        this.onDefineWordListener = l;
    }

    public void setItems(List<ChatMessage> list) {
        items.clear();
        if (list != null) {
            items.addAll(list);
        }
        notifyDataSetChanged();
    }

    public void clear() {
        items.clear();
        notifyDataSetChanged();
    }

    public void add(ChatMessage msg) {
        if (msg == null) return;
        int start = items.size();
        items.add(msg);
        notifyItemInserted(start);
    }

    public int getItemCount() {
        return items.size();
    }

    @Override
    public int getItemViewType(int position) {
        ChatMessage m = items.get(position);
        if (m == null || m.side == null) return VT_LEFT;
        return m.side == ChatMessage.Side.RIGHT ? VT_RIGHT : VT_LEFT;
    }

    @NonNull
    @Override
    public VH onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
        int layoutId = (viewType == VT_RIGHT) ? R.layout.item_chat_right : R.layout.item_chat_left;
        View v = LayoutInflater.from(parent.getContext()).inflate(layoutId, parent, false);
        return new VH(v);
    }

    @Override
    public void onBindViewHolder(@NonNull VH holder, int position) {
        ChatMessage m = items.get(position);
        CharSequence cs = m != null ? m.text : "";
        if (cs == null) cs = "";
        if (holder.tv != null) {
            holder.tv.setText(cs);
            holder.isAi = (getItemViewType(position) == VT_LEFT);
        }
    }

    @Override
    public void onViewRecycled(@NonNull VH holder) {
        super.onViewRecycled(holder);
        if (holder.tv != null) {
            holder.tv.setText("");
            holder.tv.setEllipsize(null);
            holder.tv.setMaxLines(Integer.MAX_VALUE);
        }
    }

    static class VH extends RecyclerView.ViewHolder {
        final TextView tv;
        boolean isAi = false;

        VH(@NonNull View itemView) {
            super(itemView);
            tv = itemView.findViewById(R.id.tv_msg);
        }
    }

    private static boolean _isAsciiWordChar(char c) {
        return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '\'' || c == '-';
    }

    private static String _wordAtPosition(TextView tv, float rawX, float rawY) {
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

    private static java.util.ArrayList<String> _candidateWordsAtTouchEvent(TextView tv, MotionEvent e) {
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

    @Override
    public void onAttachedToRecyclerView(@NonNull RecyclerView recyclerView) {
        super.onAttachedToRecyclerView(recyclerView);
        // no-op
    }

    @Override
    public void onViewAttachedToWindow(@NonNull VH holder) {
        super.onViewAttachedToWindow(holder);
        if (holder.tv == null) return;

        holder.tv.setClickable(true);

        GestureDetector detector = new GestureDetector(
                holder.tv.getContext(),
                new GestureDetector.SimpleOnGestureListener() {
                    @Override
                    public boolean onSingleTapConfirmed(MotionEvent e) {
                        try {
                            if (!holder.isAi) return false;
                            java.util.ArrayList<String> candidates = _candidateWordsAtTouchEvent(holder.tv, e);
                            if (candidates.isEmpty()) {
                                Log.d(TAG, "tap: no word recognized");
                                Toast.makeText(holder.tv.getContext(), "未识别到英文单词", Toast.LENGTH_SHORT).show();
                                return true;
                            }
                            String w = candidates.get(0);
                            if (onDefineWordListener != null) {
                                Log.d(TAG, "tap: define word=" + w);
                                onDefineWordListener.onDefineWord(w);
                                Toast.makeText(holder.tv.getContext(), "查词：" + w, Toast.LENGTH_SHORT).show();
                            } else {
                                Log.d(TAG, "tap: listener null, word=" + w);
                                Toast.makeText(holder.tv.getContext(), "查词监听未绑定", Toast.LENGTH_SHORT).show();
                            }
                            return true;
                        } catch (Exception ignored) {
                            return false;
                        }
                    }
                }
        );

        holder.tv.setOnTouchListener((v, event) -> {
            try {
                boolean handled = detector.onTouchEvent(event);
                if (event.getAction() == MotionEvent.ACTION_UP) {
                    v.performClick();
                }
                // Always consume to ensure GestureDetector gets the full sequence.
                return true;
            } catch (Exception ignored) {
                return false;
            }
        });
    }
}
