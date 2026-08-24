package com.meridian.payments.auth;

/**
 * UserRepository — persistence boundary for users and profiles.
 */
public interface UserRepository {

    User findByUsername(String username);

    User findByEmail(String email);

    UserProfile getProfile(String userId);

    void storeResetToken(String userId, String token);
}
