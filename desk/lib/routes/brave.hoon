/-  *master
/+  io=sailboxio, *html-utils, tarball, json-utils
|%
::  POST /master/update-brave-creds - Update Brave Search credentials
::
++  handle-update-creds
  |=  args=(list [key=@t value=@t])
  =/  m  (fiber:io ,~)
  ^-  form:m
  ;<  ball=ball:tarball  bind:m  get-state:io
  ::  Get existing creds from ball
  =/  existing=(unit json)
    (~(get-cage-as ba:tarball ball) /config/creds 'brave-search.json' json)
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
  ;<  ~  bind:m  (put-cage:io /config/creds 'brave-search.json' [%json !>(jon)])
  (pure:m ~)
--
