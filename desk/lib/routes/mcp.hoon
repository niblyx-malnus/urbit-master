/-  *master
/+  io=sailboxio, sailbox, mcp
|%
::  POST /master/mcp - Handle MCP JSON-RPC requests
::
++  handle-request
  |=  req=inbound-request:eyre
  =/  m  (fiber:io ,~)
  ^-  form:m
  ::  Parse JSON body
  =/  parsed=(unit json)  (de:json:html q:(need body.request.req))
  ?~  parsed
    (give-simple-payload:io [[400 ~] `(as-octs:mimes:html '400 Bad Request - Invalid JSON')])
  ::  Delegate to MCP protocol adapter
  ;<  response=(unit json)  bind:m  (handle-request:mcp u.parsed)
  ::  Handle notification responses (no response needed per MCP spec)
  ?~  response
    (give-simple-payload:io [[202 ~] ~])
  ::  Return JSON response
  (give-simple-payload:io [[200 ~[['content-type' 'application/json']]] `(as-octs:mimes:html (en:json:html u.response))])
--
