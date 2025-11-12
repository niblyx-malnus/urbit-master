/-  *master
/+  io=sailboxio, sailbox
|%
::  Helper functions for sending Server-Sent Events (SSE)
::
++  notify-chat-message
  |=  [chat-id=@ux timestamp=@ud]
  =/  m  (fiber:io ,~)
  ^-  form:m
  ~&  >  "Sending SSE event for message at {<timestamp>} to chat {<chat-id>}"
  %:  send-sse-event:io
    /master/claude/stream/(crip (hexn:sailbox chat-id))
    `(scot %ud timestamp)
    `%message-update
  ==
::
++  notify-chat-title
  |=  chat-id=@ux
  =/  m  (fiber:io ,~)
  ^-  form:m
  ~&  >  "Sending SSE event for title update to chat {<chat-id>}"
  %:  send-sse-event:io
    /master/claude/stream/(crip (hexn:sailbox chat-id))
    ~
    `%title-update
  ==
::
++  notify-multiple-messages
  |=  [chat-id=@ux timestamps=(list @ud)]
  =/  m  (fiber:io ,~)
  ^-  form:m
  ~&  >  "Sending {<(lent timestamps)>} SSE events for new messages"
  |-
  ?~  timestamps
    (pure:m ~)
  ;<  ~  bind:m  (notify-chat-message chat-id i.timestamps)
  $(timestamps t.timestamps)
--
