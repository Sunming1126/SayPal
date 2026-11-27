package com.japaneseengteacher.app;

public class ChatMessage {

    public enum Side {
        LEFT,
        RIGHT
    }

    public final Side side;
    public final CharSequence text;

    public ChatMessage(Side side, CharSequence text) {
        this.side = side;
        this.text = text;
    }
}
