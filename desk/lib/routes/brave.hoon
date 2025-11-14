/-  *master
/+  io=sailboxio, *html-utils, tarball
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
  ::  Get existing creds from ball
  =/  existing=brave-search-creds
    %-  fall  :_  initial-creds
    (bind (~(get ba:tarball ball.state) / 'brave-search-creds.json') |=(c=content:tarball ?>(?=([%cage *] c) !<(brave-search-creds q:cage.c))))
  ::  Use existing value if not provided
  =/  api-key=@t  (fall (get-key:kv 'api-key' args) api-key.existing)
  =/  creds=brave-search-creds  [api-key]
  =/  new-ball=ball:tarball
    (~(put ba:tarball ball.state) / 'brave-search-creds.json' [%cage ~ [%json !>(creds)]])
  =.  ball.state  new-ball
  ;<  ~  bind:m  (replace:io !>(state))
  (pure:m ~)
--
