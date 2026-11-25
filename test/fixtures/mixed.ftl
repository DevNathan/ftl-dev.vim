<#assign title = "Orders">
<#assign customerId = 42>
<section class="orders" data-title="${title}">
  <h1>${title}</h1>
  <#if customerId gt 0>
    <#assign sqlOrders>
SELECT id FROM orders
WHERE customer_id = @고객 AND label = '${title}'
    </#assign>
  </#if>

  <#-- @lang sql -->
  <#assign updateQuery>
UPDATE orders SET note = 'Customer''s copy' WHERE id = @customerId
  </#assign>

  <#assign plainText>SELECT is ordinary text here.</#assign>
  <p>${plainText}</p>
</section>
