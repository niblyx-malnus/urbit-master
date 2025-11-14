/-  *master
/+  io=sailboxio, *html-utils, tarball, json-utils
|%
::  POST /master/update-brave-creds - Update Brave Search credentials
::
++  handle-update-creds
  |=  args=(list [key=@t value=@t])
  =/  m  (fiber:io ,~)
  ^-  form:m
  ;<  state=state-0  bind:m  (get-state-as:io state-0)
  ::  Get existing creds from ball
  =/  existing=(unit json)
    (~(get-cage-as ba:tarball ball.state) /config/creds 'brave-search.json' json)
  ::  Use existing value if not provided
  =/  api-key=@t
    ?~  existing
      (need (get-key:kv 'api-key' args))
    %.  (get-key:kv 'api-key' args)
    (curr fall (dog:~(. jo:json-utils u.existing) /api-key so:dejs:format))
  ::  Build json directly
  =/  jon=json
    %-  pairs:enjs:format
    :~  ['api-key' s+api-key]
    ==
  ::  Put with validation
  ;<  new-ball=ball:tarball  bind:m  (put-cage:io ball.state /config/creds 'brave-search.json' [%json !>(jon)])
  =.  ball.state  new-ball
  ;<  ~  bind:m  (replace:io !>(state))
  (pure:m ~)
--
