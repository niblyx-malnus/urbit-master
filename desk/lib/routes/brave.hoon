/-  *master
/+  io=sailboxio, *html-utils, tarball
|%
::  POST /master/update-brave-creds - Update Brave Search credentials
::
++  handle-update-creds
  |=  args=(list [key=@t value=@t])
  =/  m  (fiber:io ,~)
  ^-  form:m
  ;<  state=state-0  bind:m  (get-state-as:io state-0)
  ;<  =bowl:gall  bind:m  get-bowl:io
  ::  Get existing creds from ball
  =/  existing=(unit brave-search-creds)
    (~(get-cage-as ba:tarball ball.state) /config/creds 'brave-search.json' brave-search-creds)
  ::  Use existing value if not provided
  =/  api-key=@t
    ?~  existing
      (need (get-key:kv 'api-key' args))
    (fall (get-key:kv 'api-key' args) api-key.u.existing)
  =/  creds=brave-search-creds  [api-key]
  =.  ball.state
    (~(put ba:tarball ball.state) /config/creds 'brave-search.json' (make-cage:tarball [%json !>(creds)] now.bowl))
  ;<  ~  bind:m  (replace:io !>(state))
  (pure:m ~)
--
