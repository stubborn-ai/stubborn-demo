# Case: visit-to-customer-context

## Goal

Validate that a service-boundary contract can connect API gateway/customer code to the customers service provider graph.

The baseline workspace indexes each service independently. Without the contract bridge, ordinary Java references stay within service/module boundaries and the HTTP boundary remains a graph leaf.

After indexing `petclinic-contracts`, Stubborn should traverse:

```text
ApiGatewayController / CustomersServiceClient
  -> GET http://customers-service/owners/{ownerId}
  -> OwnerResource
```

## Command

```bash
docker compose run --rm petclinic-ms-e2e
```

Or after a host run:

```bash
stubborn context spring-petclinic-microservices/metadata/petclinic-workspace.db \
  --workspace petclinic-ms \
  --target "<CustomersServiceClient stable_id>" \
  --out spring-petclinic-microservices/stub-output/visit-to-customer.stub.java
```

## Expected Neighbors

With the contract bridge indexed, context should include:

- `CustomersServiceClient`
- `OwnerResource`
- `ApiGatewayController`

The verifier also checks that the no-bridge baseline does not already cross into `OwnerResource`; that protects the demo from accidentally relying on unsupported HTTP inference.
