package com.example.orders.service;

import com.example.orders.domain.Customer;
import com.example.orders.domain.Order;
import java.math.BigDecimal;

public interface PaymentGateway {

    boolean charge(Customer customer, BigDecimal amount);
}
