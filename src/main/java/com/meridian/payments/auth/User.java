package com.meridian.payments.auth;

import java.util.List;

/**
 * User — authentication principal.
 * NOTE: password is stored here for the lab's threat-mitigation exercise;
 * the secure reference replaces this with a hashed credential.
 */
public class User {

    private String id;
    private String username;
    private String email;
    private String password;          // plaintext in starter — this is the threat to fix
    private List<String> roles;

    public String getId() { return id; }
    public void setId(String id) { this.id = id; }

    public String getUsername() { return username; }
    public void setUsername(String username) { this.username = username; }

    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }

    public String getPassword() { return password; }
    public void setPassword(String password) { this.password = password; }

    public List<String> getRoles() { return roles; }
    public void setRoles(List<String> roles) { this.roles = roles; }
}
