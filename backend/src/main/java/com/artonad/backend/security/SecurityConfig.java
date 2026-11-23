
package com.artonad.backend.security;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.http.MediaType;
import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.security.web.access.AccessDeniedHandler;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;
import jakarta.servlet.DispatcherType;
import java.util.List;
@Configuration
public class SecurityConfig {

    @Bean
    public SecurityFilterChain securityFilterChain(
            HttpSecurity http,
            JwtAuthenticationFilter jwtFilter) throws Exception {

        http
            .cors(cors -> cors.configurationSource(corsConfigurationSource()))
            .csrf(csrf -> csrf.disable())
            .sessionManagement(session ->
                session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .authorizeHttpRequests(auth -> auth
                .dispatcherTypeMatchers(DispatcherType.ERROR).permitAll()
                .requestMatchers(
                    HttpMethod.POST,
                     "/api/v1/auth/login",
                    "/api/v1/auth/signup"
                    ).permitAll()
                .requestMatchers("/actuator/health").permitAll()

                .requestMatchers(HttpMethod.POST, "/api/v1/incidents")
                    .hasRole("TOURIST")

                .requestMatchers(HttpMethod.GET, "/api/v1/incidents")
                    .hasRole("ADMIN")

                .requestMatchers(HttpMethod.GET, "/api/v1/incidents/*")
                    .hasAnyRole("ADMIN", "TOURIST")

                .requestMatchers(HttpMethod.GET, "/api/v1/responders")
                    .hasRole("ADMIN")

                .requestMatchers(HttpMethod.GET, "/api/v1/zones")
                    .hasRole("ADMIN")

                .anyRequest().authenticated()
            )
            .exceptionHandling(ex -> ex
            .authenticationEntryPoint(authenticationEntryPoint())
            .accessDeniedHandler(accessDeniedHandler())
            )
            .addFilterBefore(
                 jwtFilter,
                UsernamePasswordAuthenticationFilter.class
            );

        return http.build();
    }

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }
    @Bean
public AuthenticationEntryPoint authenticationEntryPoint() {
    return (request, response, exception) -> {
        response.setStatus(401);
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        response.getWriter().write(
            "{\"error\":\"UNAUTHORIZED\",\"message\":\"Authentication is required\"}"
        );
    };
}

@Bean
public AccessDeniedHandler accessDeniedHandler() {
    return (request, response, exception) -> {
        response.setStatus(403);
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        response.getWriter().write(
            "{\"error\":\"FORBIDDEN\",\"message\":\"Access denied\"}"
        );
    };
}
@Bean
public CorsConfigurationSource corsConfigurationSource() {

    CorsConfiguration config = new CorsConfiguration();

    config.setAllowedOrigins(List.of(
        "http://localhost:5173",
        "http://127.0.0.1:5173"
    ));

    config.setAllowedMethods(List.of(
        "GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"
    ));

    config.setAllowedHeaders(List.of(
        "Authorization",
        "Content-Type"
    ));

    config.setAllowCredentials(false);

    UrlBasedCorsConfigurationSource source =
        new UrlBasedCorsConfigurationSource();

    source.registerCorsConfiguration("/api/**", config);

    return source;
}
}
