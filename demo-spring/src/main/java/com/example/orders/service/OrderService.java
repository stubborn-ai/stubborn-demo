package com.example.orders.service;

import com.example.orders.domain.Customer;
import com.example.orders.domain.Order;
import com.example.orders.dto.CreateOrderRequest;
import com.example.orders.dto.OrderResponse;
import com.example.orders.exception.OrderNotFoundException;
import com.example.orders.repository.OrderRepository;
import java.util.List;
import java.util.UUID;
import org.springframework.stereotype.Service;

@Service
public class OrderService {

    private final OrderRepository orderRepository;
    private final PaymentGateway paymentGateway;

    public OrderService(OrderRepository orderRepository, PaymentGateway paymentGateway) {
        this.orderRepository = orderRepository;
        this.paymentGateway = paymentGateway;
    }

    public OrderResponse createOrder(CreateOrderRequest request) {
        Customer customer = new Customer(UUID.randomUUID(), request.customerEmail(), request.customerName());
        Order order = Order.pending(customer, request.total());
        orderRepository.save(order);
        return toResponse(order);
    }

    public OrderResponse getOrder(UUID id) {
        Order order = orderRepository.findById(id).orElseThrow(() -> new OrderNotFoundException(id));
        return toResponse(order);
    }

    public List<OrderResponse> listOrders() {
        return orderRepository.findAll().stream().map(this::toResponse).toList();
    }

    public OrderResponse payOrder(UUID id) {
        Order order = orderRepository.findById(id).orElseThrow(() -> new OrderNotFoundException(id));
        boolean paid = paymentGateway.charge(order.getCustomer(), order.getTotal());
        if (!paid) {
            throw new IllegalStateException("payment failed for order " + id);
        }
        order.markPaid();
        orderRepository.save(order);
        return toResponse(order);
    }

    public OrderResponse cancelOrder(UUID id) {
        Order order = orderRepository.findById(id).orElseThrow(() -> new OrderNotFoundException(id));
        order.cancel();
        orderRepository.save(order);
        return toResponse(order);
    }

    private OrderResponse toResponse(Order order) {
        return new OrderResponse(
                order.getId(),
                order.getCustomer().email(),
                order.getTotal(),
                order.getStatus(),
                order.getCreatedAt());
    }
}
