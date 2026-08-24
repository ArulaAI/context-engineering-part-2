package com.meridian.payments.auth;

import java.util.Map;

/**
 * SessionStore — server-side session state lookup.
 */
public interface SessionStore {

    Map<String, Object> get(String sessionId);

    boolean isValid(String sessionId);

    void remove(String sessionId);
}
