package com.example.orders.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import java.math.BigDecimal;

public record CreateOrderRequest(
        @NotBlank @Email String customerEmail,
        @NotBlank String customerName,
        @NotNull @Positive BigDecimal total
) {}
