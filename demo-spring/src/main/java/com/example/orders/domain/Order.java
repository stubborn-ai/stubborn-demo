package com.example.orders.domain;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

public class Order {

    private final UUID id;
    private final Customer customer;
    private final BigDecimal total;
    private final Instant createdAt;
    private OrderStatus status;

    public Order(UUID id, Customer customer, BigDecimal total, Instant createdAt, OrderStatus status) {
        this.id = id;
        this.customer = customer;
        this.total = total;
        this.createdAt = createdAt;
        this.status = status;
    }

    public static Order pending(Customer customer, BigDecimal total) {
        return new Order(UUID.randomUUID(), customer, total, Instant.now(), OrderStatus.PENDING);
    }

    public UUID getId() {
        return id;
    }

    public Customer getCustomer() {
        return customer;
    }

    public BigDecimal getTotal() {
        return total;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public OrderStatus getStatus() {
        return status;
    }

    public void markPaid() {
        if (status != OrderStatus.PENDING) {
            throw new IllegalStateException("only pending orders can be paid");
        }
        this.status = OrderStatus.PAID;
    }

    public void cancel() {
        if (status == OrderStatus.SHIPPED) {
            throw new IllegalStateException("shipped orders cannot be cancelled");
        }
        this.status = OrderStatus.CANCELLED;
    }
}
