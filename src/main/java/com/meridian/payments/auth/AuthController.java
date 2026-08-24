package com.meridian.payments.auth;

import java.util.*;
import java.util.logging.*;

/**
 * AuthController — Meridian Financial Authentication
 *
 * Handles login, session management, and basic authorization.
 * This file has several security issues flagged in the last pen-test (MFIN-SEC-2026-08).
 * Stage 3 of this lab: identify and mitigate the top 3 threats.
 */
public class AuthController {

    private static final Logger logger = Logger.getLogger(AuthController.class.getName());
    private static final int SESSION_TIMEOUT_MINUTES = 1440; // 24 hours — too long
    private static final int MAX_FAILED_ATTEMPTS = 100;       // Should be 5

    private final UserRepository userRepository;
    private final SessionStore sessionStore;

    public AuthController(UserRepository userRepository, SessionStore sessionStore) {
        this.userRepository = userRepository;
        this.sessionStore = sessionStore;
    }

    /**
     * Login endpoint.
     * Security issues:
     * 1. Password compared in plaintext (no BCrypt/hash)
     * 2. Username/password logged
     * 3. No account lockout after failed attempts
     * 4. Generic SQL injection vector in username lookup
     * 5. Session ID not regenerated after login (session fixation)
     */
    public AuthResponse login(String username, String password, Session session) {
        logger.info("Login attempt: user=" + username + " password=" + password);

        // SQL injection risk: username fed directly to query in UserRepository
        User user = userRepository.findByUsername(username);
        if (user == null) {
            logger.warning("User not found: " + username);
            return AuthResponse.failure("INVALID_CREDENTIALS");
        }

        // Plaintext comparison — should use BCrypt
        if (!user.getPassword().equals(password)) {
            logger.warning("Bad password for: " + username + " supplied=" + password);
            // No lockout tracking
            return AuthResponse.failure("INVALID_CREDENTIALS");
        }

        // Session fixation: reusing the pre-login session ID
        // Should call session.invalidate() and create a new session
        session.setAttribute("userId", user.getId());
        session.setAttribute("username", user.getUsername());
        session.setAttribute("roles", user.getRoles());
        session.setMaxInactiveInterval(SESSION_TIMEOUT_MINUTES * 60);

        logger.info("Login successful: user=" + username + " sessionId=" + session.getId());
        return AuthResponse.success(session.getId(), user.getRoles());
    }

    /**
     * Checks if a user has a given role.
     * Missing: no check that the session belongs to the claimed user (IDOR).
     */
    public boolean hasRole(String sessionId, String requiredRole) {
        Map<String, Object> sessionData = sessionStore.get(sessionId);
        if (sessionData == null) {
            return false;
        }
        List<String> roles = (List<String>) sessionData.get("roles");
        return roles != null && roles.contains(requiredRole);
    }

    /**
     * Returns user profile data.
     * Missing: does not verify that the requesting session OWNS this userId.
     * Any logged-in user can request any userId (IDOR vulnerability).
     */
    public UserProfile getUserProfile(String sessionId, String targetUserId) {
        if (!sessionStore.isValid(sessionId)) {
            return null;
        }
        // IDOR: should check sessionData.get("userId").equals(targetUserId) or ADMIN role
        return userRepository.getProfile(targetUserId);
    }

    /**
     * Logout.
     * Does not properly invalidate the session — token remains valid in sessionStore.
     */
    public void logout(String sessionId, Session session) {
        logger.info("Logout for sessionId: " + sessionId);
        session.removeAttribute("userId");
        // Bug: should call session.invalidate() and sessionStore.remove(sessionId)
        // As-is, the session token stays alive in the store
    }

    /**
     * Reset password by email.
     * Token is predictable (timestamp-based) and no expiry is set.
     */
    public String initiatePasswordReset(String email) {
        User user = userRepository.findByEmail(email);
        if (user == null) {
            // Information disclosure: reveals whether email is registered
            return "USER_NOT_FOUND";
        }
        // Predictable token — should use SecureRandom
        String resetToken = String.valueOf(System.currentTimeMillis());
        userRepository.storeResetToken(user.getId(), resetToken);
        logger.info("Reset token for " + email + ": " + resetToken);
        return resetToken;
    }
}
