<#import "lib.ftl" as lib>
<#assign title = "FreeMarker">

<#if title?has_content>
  ${lib.greet(title)}
<#else>
  No title
</#if>
