package com.japaneseengteacher.app;

import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;

import androidx.annotation.NonNull;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;
import androidx.viewpager2.widget.ViewPager2;

import java.util.List;

public class PracticePagerAdapter extends RecyclerView.Adapter<PracticePagerAdapter.PageViewHolder> {

    private final List<String> enSentences;
    private final List<String> cnTranslations;

    public PracticePagerAdapter(List<String> enSentences, List<String> cnTranslations) {
        this.enSentences = enSentences;
        this.cnTranslations = cnTranslations;
    }

    @NonNull
    @Override
    public PageViewHolder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
        View view;
        if (viewType == 0) {
            view = LayoutInflater.from(parent.getContext())
                    .inflate(R.layout.page_english_practice_cn, parent, false);
        } else {
            view = LayoutInflater.from(parent.getContext())
                    .inflate(R.layout.page_english_practice_bilingual, parent, false);
        }
        return new PageViewHolder(view, viewType);
    }

    @Override
    public void onBindViewHolder(@NonNull PageViewHolder holder, int position) {
        holder.bind(enSentences, cnTranslations);
    }

    @Override
    public int getItemCount() {
        return 2;
    }

    @Override
    public int getItemViewType(int position) {
        return position;
    }

    static class PageViewHolder extends RecyclerView.ViewHolder {
        private final int pageType;

        PageViewHolder(@NonNull View itemView, int pageType) {
            super(itemView);
            this.pageType = pageType;
        }

        void bind(List<String> enSentences, List<String> cnTranslations) {
            RecyclerView rv = pageType == 0
                    ? itemView.findViewById(R.id.rv_cn_sentences)
                    : itemView.findViewById(R.id.rv_bilingual_sentences);

            // Page 0 (CN only): show CN translation as main text
            // Page 1 (Bilingual): show both CN and EN in parallel
            PracticeSentenceAdapter adapter = new PracticeSentenceAdapter(
                    cnTranslations,
                    pageType == 0 ? null : enSentences,
                    pageType
            );

            rv.setLayoutManager(new LinearLayoutManager(itemView.getContext()));
            rv.setAdapter(adapter);
        }
    }
}
