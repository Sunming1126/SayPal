package com.japaneseengteacher.app;

import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;

import java.util.List;

public class PracticeSentenceAdapter extends RecyclerView.Adapter<PracticeSentenceAdapter.SentenceViewHolder> {

    private final List<String> cnList;
    private final List<String> enList;
    private final int pageType;

    public PracticeSentenceAdapter(List<String> cnList, List<String> enList, int pageType) {
        this.cnList = cnList;
        this.enList = enList;
        this.pageType = pageType;
    }

    @NonNull
    @Override
    public SentenceViewHolder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
        int layout = pageType == 0
                ? R.layout.item_practice_cn
                : R.layout.item_practice_bilingual;
        View view = LayoutInflater.from(parent.getContext()).inflate(layout, parent, false);
        return new SentenceViewHolder(view, pageType);
    }

    @Override
    public void onBindViewHolder(@NonNull SentenceViewHolder holder, int position) {
        String cn = position < cnList.size() ? cnList.get(position) : "";
        String en = (enList != null && position < enList.size()) ? enList.get(position) : "";
        holder.bind(position + 1, cn, en);
    }

    @Override
    public int getItemCount() {
        return cnList.size();
    }

    static class SentenceViewHolder extends RecyclerView.ViewHolder {
        private final int pageType;

        SentenceViewHolder(@NonNull View itemView, int pageType) {
            super(itemView);
            this.pageType = pageType;
        }

        void bind(int number, String cn, String en) {
            TextView tvNumber = itemView.findViewById(R.id.tv_number);
            TextView tvCn = itemView.findViewById(R.id.tv_cn);
            TextView tvEn = pageType == 1 ? itemView.findViewById(R.id.tv_en) : null;

            if (tvNumber != null) tvNumber.setText(number + ".");
            if (tvCn != null) tvCn.setText(cn);
            if (tvEn != null) tvEn.setText(en);
        }
    }
}
