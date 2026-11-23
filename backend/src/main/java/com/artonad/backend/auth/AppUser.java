
package com.artonad.backend.auth;

import jakarta.persistence.*;

@Entity
@Table(name = "app_user")
public class AppUser {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "user_id")
    private Long userId;

    private String name;
    private String phone;
    private String email;
    private String username;

    @Column(name = "password_hash")
    private String passwordHash;

    private String role;

    public AppUser() {
    }

    public AppUser(String name, String phone, String email,
                   String username, String passwordHash, String role) {
        this.name = name;
        this.phone = phone;
        this.email = email;
        this.username = username;
        this.passwordHash = passwordHash;
        this.role = role;
    }

    public Long getUserId() {
        return userId;
    }

    public String getName() {
        return name;
    }

    public String getUsername() {
        return username;
    }

    public String getPasswordHash() {
        return passwordHash;
    }

    public String getRole() {
        return role;
    }
}
