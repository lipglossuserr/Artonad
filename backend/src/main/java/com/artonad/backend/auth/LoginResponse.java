package com.artonad.backend.auth;


public record LoginResponse(
        String token,
        String role,
        Long userId,
        String name
) {}