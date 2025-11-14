/-  *master
/+  io=sailboxio, telegram, tarball
|%
::  POST /master/telegram - Send telegram message
::
++  handle-send-message
  |=  message=@t
  =/  m  (fiber:io ,~)
  ^-  form:m
  ;<  state=state-0  bind:m  (get-state-as:io state-0)
  =/  creds=(unit telegram-creds)
    (~(get-cage-as ba:tarball ball.state) /config/creds 'telegram.json' telegram-creds)
  ?~  creds
    (fiber-fail:io leaf+"Telegram credentials not configured" ~)
  ;<  ~  bind:m
    %:  send-message:telegram
      bot-token.u.creds
      chat-id.u.creds
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
  ;<  =bowl:gall  bind:m  get-bowl:io
  =/  creds=telegram-creds  [bot-token chat-id]
  =.  ball.state
    (~(put ba:tarball ball.state) /config/creds 'telegram.json' (make-cage:tarball [%json !>(creds)] now.bowl))
  ;<  ~  bind:m  (replace:io !>(state))
  (pure:m ~)
::
::  Handle spawned telegram alarm
::
++  handle-spawn-alarm
  |=  [alarm-id=@da =telegram-alarm]
  =/  m  (fiber:io ,~)
  ^-  form:m
  ~&  >  "spawn-alarm handler called"
  ~&  >  "alarm-id: {<alarm-id>}, wake-time: {<wake-time.telegram-alarm>}"
  ::  Wait until wake time
  ~&  >  "waiting until wake time..."
  ;<  ~  bind:m  (wait:io wake-time.telegram-alarm)
  ~&  >  "wake time reached, sending telegram..."
  ::  Get current state to access telegram creds
  ;<  state=state-0  bind:m  (get-state-as:io state-0)
  =/  creds=(unit telegram-creds)
    (~(get-cage-as ba:tarball ball.state) /config/creds 'telegram.json' telegram-creds)
  ?~  creds
    (fiber-fail:io leaf+"Telegram credentials not configured" ~)
  ::  Send telegram
  ;<  ~  bind:m
    %:  send-message:telegram
      bot-token.u.creds
      chat-id.u.creds
      message.telegram-alarm
    ==
  ::  Remove alarm from state after sending
  ;<  state=state-0  bind:m  (get-state-as:io state-0)
  =.  telegram-alarms.state  (~(del by telegram-alarms.state) alarm-id)
  ;<  ~  bind:m  (replace:io !>(state))
  (pure:m ~)
--
