package com.meridian.payments.auth;

import java.util.List;

/**
 * AuthResponse — result of an authentication attempt.
 */
public class AuthResponse {

    private final boolean success;
    private final String code;
    private final String sessionId;
    private final List<String> roles;

    private AuthResponse(boolean success, String code, String sessionId, List<String> roles) {
        this.success = success;
        this.code = code;
        this.sessionId = sessionId;
        this.roles = roles;
    }

    public static AuthResponse success(String sessionId, List<String> roles) {
        return new AuthResponse(true, "SUCCESS", sessionId, roles);
    }

    public static AuthResponse failure(String code) {
        return new AuthResponse(false, code, null, null);
    }

    public boolean isSuccess() { return success; }
    public String getCode() { return code; }
    public String getSessionId() { return sessionId; }
    public List<String> getRoles() { return roles; }
}
