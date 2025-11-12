/-  *master
/+  io=sailboxio, telegram
|%
::  Initial telegram credentials
::
++  initial-creds
  ^-  telegram-creds
  :*  bot-token='your-bot-token'
      chat-id='your-chat-id'
  ==
::
::  POST /master/telegram - Send telegram message
::
++  handle-send-message
  |=  [message=@t =telegram-creds]
  =/  m  (fiber:io ,~)
  ^-  form:m
  ;<  ~  bind:m
    %:  send-message:telegram
      bot-token.telegram-creds
      chat-id.telegram-creds
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
  =.  telegram-creds.state  [bot-token chat-id]
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
  ::  Send telegram
  ;<  ~  bind:m
    %:  send-message:telegram
      bot-token.telegram-creds.state
      chat-id.telegram-creds.state
      message.telegram-alarm
    ==
  ::  Remove alarm from state after sending
  ;<  state=state-0  bind:m  (get-state-as:io state-0)
  =.  telegram-alarms.state  (~(del by telegram-alarms.state) alarm-id)
  ;<  ~  bind:m  (replace:io !>(state))
  (pure:m ~)
--
