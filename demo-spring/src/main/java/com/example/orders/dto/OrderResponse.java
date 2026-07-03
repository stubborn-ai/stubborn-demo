package com.example.orders.dto;

import com.example.orders.domain.OrderStatus;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

public record OrderResponse(
        UUID id,
        String customerEmail,
        BigDecimal total,
        OrderStatus status,
        Instant createdAt
) {}
