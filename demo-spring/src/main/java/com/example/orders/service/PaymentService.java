package com.example.orders.service;

import com.example.orders.domain.Customer;
import java.math.BigDecimal;
import org.springframework.stereotype.Service;

@Service
public class PaymentService implements PaymentGateway {

    @Override
    public boolean charge(Customer customer, BigDecimal amount) {
        if (amount.signum() <= 0) {
            return false;
        }
        return customer.email().contains("@");
    }
}
