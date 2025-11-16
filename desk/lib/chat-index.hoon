/-  *master, claude
|%
::  Calculate approximate character count of a message for token estimation
::
++  message-char-count
  |=  msg=message:claude
  ^-  @ud
  ::  Get JSON string representation and count characters
  =/  content-text=@t  (en:json:html content.msg)
  (met 3 content-text)
::
::  Add a message to all three indexes
::
++  add-message
  |=  $:  chat=chat:claude
          timestamp=@ud
          msg=message:claude
      ==
  ^-  chat:claude
  ::  Calculate character count for this message
  =/  msg-chars=@ud  (message-char-count msg)
  ::  Update message with all metadata fields
  =.  chat-id.msg  id.chat
  =.  index.msg  next-index.chat
  =.  timestamp.msg  timestamp
  =.  cumulative-chars.msg  total-chars.chat
  =.  chars.msg  msg-chars
  ::  Add to time index
  =.  messages-by-time.chat
    (put:((on @ud message:claude) lth) messages-by-time.chat timestamp msg)
  ::  Add to index index
  =.  messages-by-index.chat
    (put:((on @ud message:claude) lth) messages-by-index.chat next-index.chat msg)
  ::  Add to character count index (using cumulative count as key)
  =.  messages-by-chars.chat
    (put:((on @ud message:claude) lth) messages-by-chars.chat total-chars.chat msg)
  ::  Increment counters
  =.  next-index.chat  +(next-index.chat)
  =.  total-chars.chat  (add total-chars.chat msg-chars)
  chat
::
::  Get messages by time range
::
++  get-by-time
  |=  [chat=chat:claude start=(unit @ud) end=(unit @ud)]
  ^-  (list [@ud message:claude])
  (tap:((on @ud message:claude) lth) (lot:((on @ud message:claude) lth) messages-by-time.chat start end))
::
::  Get messages by index range
::
++  get-by-index
  |=  [chat=chat:claude start=(unit @ud) end=(unit @ud)]
  ^-  (list [@ud message:claude])
  (tap:((on @ud message:claude) lth) (lot:((on @ud message:claude) lth) messages-by-index.chat start end))
::
::  Get messages by character range (for token budget)
::
++  get-by-chars
  |=  [chat=chat:claude start=(unit @ud) end=(unit @ud)]
  ^-  (list [@ud message:claude])
  (tap:((on @ud message:claude) lth) (lot:((on @ud message:claude) lth) messages-by-chars.chat start end))
::
::  Get last N characters worth of messages
::
++  get-last-chars
  |=  [chat=chat:claude char-limit=@ud]
  ^-  (list [@ud message:claude])
  ::  Calculate starting point
  =/  start-char=@ud
    ?:  (lth total-chars.chat char-limit)  0
    (sub total-chars.chat char-limit)
  (get-by-chars chat `start-char ~)
--
