# Runtime Expression Reference

This file summarizes every runtime expression prefix and usage pattern allowed in Arazzo 1.0.1. Use it whenever you need to wire data between workflow inputs, steps, or HTTP messages.

## Core Principles
- Expressions always start with `$` and can be used as standalone strings or embedded via `{"$expression"}` syntax.
- Dot notation navigates objects; JSON Pointer fragments (`#/path`) extract values inside request/response bodies.
- Arrays: use `[index]` for zero-based access when the result is a list (e.g., `$response.body#/items/0/id`).
- When concatenating text, wrap expressions in `{}` inside quoted strings: `"Order {$steps.create.outputs.orderId}"`.
- Boolean/number/string literals support basic operators (`==`, `!=`, `<`, `>`, `&&`, `||`, `!`, parentheses).

## Available Prefixes

| Prefix | Description | Example |
| --- | --- | --- |
| `$inputs.<name>` | Workflow input schema values | `$inputs.customer.id` |
| `$outputs.<name>` | Workflow outputs defined at the workflow level | `$outputs.workflow_order_id` |
| `$steps.<stepId>.outputs.<name>` | Data exposed by a previous step | `$steps.login.outputs.token` |
| `$workflows.<workflowId>.inputs.<name>` | Inputs received by another workflow (when referencing it) | `$workflows.authWorkflow.inputs.username` |
| `$workflows.<workflowId>.outputs.<name>` | Outputs produced by another workflow | `$workflows.authWorkflow.outputs.token` |
| `$sourceDescriptions.<name>.<identifier>` | Explicit reference to operations/workflows from a sourceDescription. Use when multiple non-Arazzo sources exist. | `$sourceDescriptions.petApi.findPetsByStatus` |
| `$url` | Request URL for the current step | Used in logging criteria |
| `$method` | HTTP method used by the operation | `$method == 'POST'` |
| `$statusCode` | Response status code | `$statusCode == 200` |
| `$request.header.<Header-Name>` | Request header (case-insensitive) | `$request.header.Authorization` |
| `$request.query.<name>` | Request query parameter | `$request.query.page` |
| `$request.path.<name>` | Request path parameter | `$request.path.petId` |
| `$request.body` | Entire request body | `$request.body#/customer/email` |
| `$response.header.<Header-Name>` | Response header | `$response.header.Location` |
| `$response.body` | Entire response body (JSON/XML) | `$response.body#/data/id` |
| `$components.parameters.<name>` | Reusable parameter definitions | `$components.parameters.tenantHeader` |
| `$components.successActions.<name>` | Reusable success actions | `$components.successActions.finish` |
| `$components.failureActions.<name>` | Reusable failure actions | `$components.failureActions.retry429` |

## JSON Pointer Cheatsheet
- Always prefix with `#/` when referencing JSON members.
- Escape `/` as `~1` and `~` as `~0`.
- Example: `#/items/0/id` → `response.body.items[0].id`.
- Example with special chars: `#/labels/foo~1bar` references `labels["foo/bar"]`.

## Embedding Expressions Inside Strings
```yaml
payload:
  note: "Order {$steps.create.outputs.orderId} confirmed"
```
- Use double quotes to allow interpolation.
- For JSON bodies, wrap with braces or use `payload` + `replacements` to avoid quoting issues.

## Condition Grammar (Simple Type)
```
condition = expression (operator expression)*
operator = == | != | < | <= | > | >= | && | ||
```
Example:
```yaml
- condition: $statusCode == 200 && $response.body#/errors == null
```

## Regex Conditions
```yaml
- context: $response.body#/orderId
  type: regex
  condition: '^[A-Z]{3}-[0-9]{6}$'
```
- `context` defines what to run the regex against.
- Pattern syntax = ECMAScript regular expressions.

## JSONPath Conditions
```yaml
- context: $response.body
  type: jsonpath
  condition: $[?(@.inStock >= 5)]
```
- Supports RFC 9535 (draft-goessner) JSONPath.
- Use `@` for current node, `$` for root (the `context`).
- JSONPath returns truthy/falsy; any match satisfies the criterion.

### JSONPath Filter Examples
```yaml
# Check if field exists and is not null
- context: $response.body
  type: jsonpath
  condition: $[?(@.user != null)]

# Compare with step output
- context: $response.body
  type: jsonpath
  condition: $[?(@.article.slug == $steps.createArticle.outputs.slug)]

# Check array length
- context: $response.body
  type: jsonpath
  condition: $[?(@.comments.length > 0)]

# Boolean comparison
- context: $response.body
  type: jsonpath
  condition: $[?(@.article.favorited == true)]
```

> Note: Always wrap filter expressions in `$[?(...)]` - do NOT use bare expressions like `@.user != null`

## XPath Conditions
```yaml
- context: $response.body
  type: xpath
  condition: "boolean(/Envelope/Body/Result[text()='OK'])"
```
- Use XPath 1.0/2.0/3.0; default is XPath 3.0.
- Set explicit version via criterion-expression-type object:
```yaml
- context: $response.body
  type:
    type: xpath
    version: xpath-20
  condition: "count(//item[@status='ok']) > 0"
```

## Referencing Components & Parameters
```yaml
parameters:
  - reference: $components.parameters.authHeader
    value: "Bearer {$workflows.auth.outputs.token}"
```
- `reference` pulls the full object; optional `value` overrides a specific field (for parameters only).

## Cross-Workflow Chaining
1. Expose outputs in Workflow A:
   ```yaml
   outputs:
     sessionToken: $steps.login.outputs.token
   ```
2. Reference them in Workflow B:
   ```yaml
   parameters:
     - name: Authorization
       in: header
       value: "Bearer {$workflows.runLogin.outputs.sessionToken}"
   ```

## Edge Cases & Tips
- Expressions cannot call arbitrary functions; keep logic declarative.
- For complex payload manipulation, use `requestBody.replacements` rather than nested expressions.
- When referencing another workflow via `workflowId`, you can still pass parameters by name, even if the workflow doesn’t include those `in` values (since they’re not HTTP params).
- Always ensure referenced step/workflow IDs exist—validators will flag missing references.
