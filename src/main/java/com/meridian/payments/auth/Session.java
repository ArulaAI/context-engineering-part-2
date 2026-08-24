package com.meridian.payments.auth;

/**
 * Session — minimal session abstraction for the auth layer.
 * (Stands in for the servlet session so the lab has no external web dependency.)
 */
public interface Session {

    String getId();

    void setAttribute(String name, Object value);

    Object getAttribute(String name);

    void removeAttribute(String name);

    void setMaxInactiveInterval(int seconds);

    void invalidate();
}
