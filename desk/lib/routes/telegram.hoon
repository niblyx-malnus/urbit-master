/-  *master
/+  io=sailboxio, telegram, tarball, json-utils
|%
::  POST /master/telegram - Send telegram message
::
++  handle-send-message
  |=  message=@t
  =/  m  (fiber:io ,~)
  ^-  form:m
  ;<  state=state-0  bind:m  (get-state-as:io state-0)
  =/  jon=json
    (~(got-cage-as ba:tarball ball.state) /config/creds 'telegram.json' json)
  =/  bot-token=@t  (~(dog jo:json-utils jon) /bot-token so:dejs:format)
  =/  chat-id=@t  (~(dog jo:json-utils jon) /chat-id so:dejs:format)
  ;<  ~  bind:m
    %:  send-message:telegram
      bot-token
      chat-id
      message
    ==
  (pure:m ~)
::
::  POST /master/update-creds - Update telegram credentials
::
++  handle-update-creds
  |=  [bot-token=@t chat-id=@t]
  =/  m  (fiber:io ,~)
  ^-  form:m
  ;<  state=state-0  bind:m  (get-state-as:io state-0)
  ::  Build json directly
  =/  jon=json
    %-  pairs:enjs:format
    :~  ['bot-token' s+bot-token]
        ['chat-id' s+chat-id]
    ==
  ::  Put with validation (single line!)
  ;<  new-ball=ball:tarball  bind:m  (put-cage:io ball.state /config/creds 'telegram.json' [%json !>(jon)])
  =.  ball.state  new-ball
  ;<  ~  bind:m  (replace:io !>(state))
  (pure:m ~)
--
