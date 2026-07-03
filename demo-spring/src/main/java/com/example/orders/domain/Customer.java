package com.example.orders.domain;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

public record Customer(UUID id, String email, String displayName) {

    public Customer {
        if (email == null || email.isBlank()) {
            throw new IllegalArgumentException("email is required");
        }
    }
}
