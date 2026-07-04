# Case: owner-id-impact-radius

## Goal

Validate reverse traversal across a microservice contract boundary.

The pressure-test story is an Owner identity change. A real migration would start near `Owner#id`; this first demo targets the explicit contract endpoint symbol because it is the stable provider endpoint that can be resolved across upstream versions while still exercising the same boundary:

```text
openapi customers-service:v1 GET /owners/{ownerId}
  <-> OwnerResource
  <-> CustomersServiceClient
  <-> ApiGatewayController
```

## Command

```bash
docker compose run --rm petclinic-ms-e2e
```

## Expected Neighbors

With declared contract evidence written, reverse context for the owner provider side should include:

- `openapi customers-service:v1 GET /owners/{ownerId}`
- `OwnerResource`
- `CustomersServiceClient`
- `ApiGatewayController`

This is the microservices version of the ADR-010 reverse traversal guard, now using ADR-012 contract evidence: a provider-side target must be able to find cross-service consumers, not only callees in its own repo.
