/-  *master
/+  io=sailboxio, *html-utils
|%
::  Initial Brave Search credentials
::
++  initial-creds
  ^-  brave-search-creds
  [api-key='your-brave-api-key']
::
::  POST /master/update-brave-creds - Update Brave Search credentials
::
++  handle-update-creds
  |=  args=(list [key=@t value=@t])
  =/  m  (fiber:io ,~)
  ^-  form:m
  ;<  state=state-0  bind:m  (get-state-as:io state-0)
  ::  Use existing api-key if not provided
  =/  api-key=@t  (fall (get-key:kv 'api-key' args) api-key.brave-search-creds.state)
  =.  brave-search-creds.state  [api-key]
  ;<  ~  bind:m  (replace:io !>(state))
  (pure:m ~)
--
