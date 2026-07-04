# Case: visit-to-customer-context

## Goal

Validate that a service-boundary contract can connect API gateway/customer code to the customers service provider graph.

The baseline workspace indexes each service independently. Without the contract evidence, ordinary Java references stay within service/module boundaries and the HTTP boundary remains a graph leaf.

After writing `petclinic-contracts` into schema v4 contract tables, Stubborn should traverse:

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

With declared contract evidence written, context should include:

- `CustomersServiceClient`
- `OwnerResource`
- `ApiGatewayController`

The verifier also checks that the no-contract baseline does not already cross into `OwnerResource`; that protects the demo from accidentally relying on unsupported HTTP inference. In bridged mode it also checks structured `contract_edges` and the `stubborn-dsl` `contracts:` block.
