package com.artonad.backend.auth;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record SignupRequest(
        @NotBlank String name,
        String phone,
        @NotBlank @Email String email,
        @NotBlank String username,
        @NotBlank @Size(min = 8) String password
) {}