package com.meridian.payments.auth;

/**
 * UserProfile — non-sensitive user profile data returned to clients.
 */
public class UserProfile {

    private String userId;
    private String displayName;
    private String email;
    private String department;

    public String getUserId() { return userId; }
    public void setUserId(String userId) { this.userId = userId; }

    public String getDisplayName() { return displayName; }
    public void setDisplayName(String displayName) { this.displayName = displayName; }

    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }

    public String getDepartment() { return department; }
    public void setDepartment(String department) { this.department = department; }
}
