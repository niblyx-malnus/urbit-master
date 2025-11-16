/-  *master, claude
/+  io=sailboxio, sailbox, server, ui-claude, claude-lib=claude, chat-index,
    sse=sse-helpers, *html-utils, tarball, json-utils
|%
::  Helper: Get all chats from ball as a map
::
++  get-all-chats
  |=  =ball:tarball
  ^-  (map @ux chat:claude)
  =/  ba-core  ~(. ba:tarball ball)
  =/  filenames=(list @ta)  (lis:ba-core /claude/chats)
  %-  malt
  %+  murn  filenames
  |=  name=@ta
  ^-  (unit [@ux chat:claude])
  ::  Only process .chat:claude files
  =/  name-tape=tape  (trip name)
  =/  ext-tape=tape  ".claude-chat"
  =/  ext-len=@ud  (lent ext-tape)
  =/  name-len=@ud  (lent name-tape)
  ?.  (gte name-len ext-len)  ~
  ?.  =((flop (scag ext-len (flop name-tape))) ext-tape)  ~
  ::  Parse hex ID from filename (everything before .chat:claude)
  =/  id-tape=tape  (slag 0 (scag (sub name-len ext-len) name-tape))
  =/  parsed-id=(unit @ux)  (rush (crip id-tape) hex)
  ?~  parsed-id  ~
  ::  Get the content
  =/  maybe-content=(unit content:tarball)  (get:ba-core /claude/chats name)
  ?~  maybe-content  ~
  ::  Must be a cage
  ?.  ?=([%& *] data.u.maybe-content)  ~
  =/  =cage  p.data.u.maybe-content
  ::  Must have chat:claude mark
  ?.  =(p.cage %claude-chat)  ~
  ::  Try to extract the chat
  =/  result  (mule |.(!<(chat:claude q.cage)))
  ?.  ?=(%& -.result)  ~
  `[u.parsed-id p.result]
::
::  Helper: Get active chat ID from ball
::
++  get-active-chat
  |=  =ball:tarball
  ^-  (unit @ux)
  =/  txt=(unit wain)
    (~(get-cage-as ba:tarball ball) /claude 'active-chat.txt' wain)
  ?~  txt  ~
  ?~  u.txt  ~
  (rush i.u.txt hex)
::
::  Helper: Get a single chat from ball
::
++  get-chat
  |=  [=ball:tarball chat-id=@ux]
  ^-  (unit chat:claude)
  (~(get-cage-as ba:tarball ball) /claude/chats (crip "{(hexn:sailbox chat-id)}.claude-chat") chat:claude)
::
::  Helper: Put a chat to ball
::
++  put-chat
  |=  [chat-id=@ux =chat:claude]
  =/  m  (fiber:io ,~)
  ^-  form:m
  ;<  state=state-0  bind:m  (get-state-as:io state-0)
  ;<  new-ball=ball:tarball  bind:m
    (put-cage:io ball.state /claude/chats (crip "{(hexn:sailbox chat-id)}.claude-chat") [%claude-chat !>(chat)])
  =.  ball.state  new-ball
  ;<  ~  bind:m  (replace:io !>(state))
  (pure:m ~)
::
::  Helper: Delete a chat from ball
::
++  del-chat
  |=  chat-id=@ux
  =/  m  (fiber:io ,~)
  ^-  form:m
  ;<  state=state-0  bind:m  (get-state-as:io state-0)
  =.  ball.state  (~(del ba:tarball ball.state) /claude/chats (crip "{(hexn:sailbox chat-id)}.claude-chat"))
  ;<  ~  bind:m  (replace:io !>(state))
  (pure:m ~)
::
::  Helper: Set active chat in ball
::
++  set-active-chat
  |=  chat-id=(unit @ux)
  =/  m  (fiber:io ,~)
  ^-  form:m
  ;<  state=state-0  bind:m  (get-state-as:io state-0)
  =/  txt-content=wain
    ?~  chat-id  ~
    ~[(crip (hexn:sailbox u.chat-id))]
  ;<  new-ball=ball:tarball  bind:m
    (put-cage:io ball.state /claude 'active-chat.txt' [%txt !>(txt-content)])
  =.  ball.state  new-ball
  ;<  ~  bind:m  (replace:io !>(state))
  (pure:m ~)
::
::  POST /master/claude/{id} - Send message to Claude chat
::
++  handle-message
  |=  [chat-id=@ux message=@t api-key=@t ai-model=@t user-timezone=@t]
  =/  m  (fiber:io ,~)
  ^-  form:m
  ;<  state=state-0  bind:m  (get-state-as:io state-0)
  =/  chat=(unit chat:claude)  (get-chat ball.state chat-id)
  ?~  chat
    (give-simple-payload:io [[404 ~] `(as-octs:mimes:html '404 Chat Not Found')])
  ::  Build and save user message
  =/  user-content=json
    :-  %a
    :~  %-  pairs:enjs:format
        :~  ['type' s+'text']
            ['text' s+message]
        ==
    ==
  =/  user-msg=message:claude  ['user' user-content %normal chat-id 0 0 0 0]
  ;<  =bowl:gall  bind:m  get-bowl:io
  =/  user-timestamp=@ud  (unm:chrono:userlib now.bowl)
  ::  Add user message using triple-index helper
  =.  u.chat  (add-message:chat-index u.chat user-timestamp user-msg)
  ;<  ~  bind:m  (put-chat chat-id u.chat)
  ;<  ~  bind:m  (set-active-chat `chat-id)
  ::  Send SSE event for user message
  ;<  ~  bind:m  (notify-chat-message:sse chat-id user-timestamp)
  ::  Call Claude and get response
  ;<  state=state-0  bind:m  (get-state-as:io state-0)
  =/  chat=(unit chat:claude)  (get-chat ball.state chat-id)
  ?~  chat
    (give-simple-payload:io [[200 ~] ~])
  =/  messages-before=((mop @ud message:claude) lth)  messages-by-time.u.chat
  =/  all-chats=(map @ux chat:claude)  (get-all-chats ball.state)
  ;<  [response=@t updated-chat=chat:claude]  bind:m
    (send-message:claude-lib api-key ai-model u.chat all-chats user-timezone)
  ::  Get fresh state after Claude call (tools may have modified it)
  ;<  state=state-0  bind:m  (get-state-as:io state-0)
  =/  chat-after=(unit chat:claude)  (get-chat ball.state chat-id)
  ?~  chat-after
    (give-simple-payload:io [[200 ~] ~])
  ~&  >  "Chat name after tools: '{<name.u.chat-after>}'"
  ::  Update chat with new messages (preserving name from updated-chat, which may have been changed by tools)
  =.  updated-chat  updated-chat(name name.u.chat-after)
  ;<  ~  bind:m  (put-chat chat-id updated-chat)
  ::  Get all message timestamps from updated chat (already in order)
  =/  all-timestamps=(list @ud)  (turn (tap:((on @ud message:claude) lth) messages-by-time.updated-chat) head)
  =/  before-timestamps=(list @ud)  (turn (tap:((on @ud message:claude) lth) messages-before) head)
  ::  Find new timestamps by filtering out ones that existed before
  =/  new-timestamps=(list @ud)
    %+  skip  all-timestamps
    |=(t=@ud (~(has in (silt before-timestamps)) t))
  ::  Send SSE events for all new messages
  ;<  ~  bind:m  (notify-multiple-messages:sse chat-id new-timestamps)
  ::  Return empty success response
  (give-simple-payload:io [[200 ~] ~])
::
::  POST /master/claude/{id}/rename - Rename a chat
::
++  handle-rename
  |=  [chat-id=@ux new-name=@t]
  =/  m  (fiber:io ,~)
  ^-  form:m
  ;<  state=state-0  bind:m  (get-state-as:io state-0)
  =/  chat=(unit chat:claude)  (get-chat ball.state chat-id)
  ?~  chat
    (give-simple-payload:io [[404 ~] `(as-octs:mimes:html '404 Chat Not Found')])
  ::  Update the chat name
  =.  name.u.chat  new-name
  ;<  ~  bind:m  (put-chat chat-id u.chat)
  (give-simple-payload:io [[200 ~[['content-type' 'text/plain']]] `(as-octs:mimes:html 'OK')])
::
::  POST /master/claude/{id}/delete - Delete a chat
::
++  handle-delete
  |=  chat-id=@ux
  =/  m  (fiber:io ,~)
  ^-  form:m
  ;<  state=state-0  bind:m  (get-state-as:io state-0)
  ::  Check if this is the active chat before deleting
  =/  active=(unit @ux)  (get-active-chat ball.state)
  =/  was-active=?  =(`chat-id active)
  ::  Delete the chat
  ;<  ~  bind:m  (del-chat chat-id)
  ::  Clear active chat if it was the deleted one
  ?:  was-active
    ;<  ~  bind:m  (set-active-chat ~)
    (give-simple-payload:io [[200 ~[['content-type' 'text/plain']]] `(as-octs:mimes:html 'OK')])
  (give-simple-payload:io [[200 ~[['content-type' 'text/plain']]] `(as-octs:mimes:html 'OK')])
::
::  POST /master/claude/{id}/branch - Branch from a message
::
++  handle-branch
  |=  [parent-chat-id=@ux branch-point=@ud]
  =/  m  (fiber:io ,~)
  ^-  form:m
  ;<  state=state-0  bind:m  (get-state-as:io state-0)
  ;<  =bowl:gall  bind:m  get-bowl:io
  ::  Verify parent chat exists
  =/  parent-chat=(unit chat:claude)  (get-chat ball.state parent-chat-id)
  ?~  parent-chat
    (give-simple-payload:io [[404 ~] `(as-octs:mimes:html '404 Parent Chat Not Found')])
  ::  Verify branch point is a valid message index in parent
  =/  branch-msg=(unit message:claude)
    (get:((on @ud message:claude) lth) messages-by-index.u.parent-chat branch-point)
  ?~  branch-msg
    (give-simple-payload:io [[400 ~] `(as-octs:mimes:html '400 Invalid branch point')])
  ::  Generate unique child chat ID
  =/  all-chats=(map @ux chat:claude)  (get-all-chats ball.state)
  =/  child-chat-id=@ux  |-
    =/  candidate=@ux  `@ux`(sham eny.bowl)
    ?:  (~(has by all-chats) candidate)
      $(eny.bowl +(eny.bowl))
    candidate
  ::  Build new child chat (empty, will reference parent for history)
  =/  child-chat=chat:claude
    :*  %0
        child-chat-id
        (crip "Branch from {(trip name.u.parent-chat)}")
        `[parent-chat-id branch-point]  :: parent link
        ~                               :: children (empty)
        ~                               :: messages-by-time (empty)
        ~                               :: messages-by-index (empty)
        ~                               :: messages-by-chars (empty)
        0                               :: next-index
        0                               :: total-chars
        now.bowl
    ==
  ::  Update parent chat to add this child to its children map
  =.  children.u.parent-chat  (~(put by children.u.parent-chat) branch-point child-chat-id)
  ::  Save both chats
  ;<  ~  bind:m  (put-chat parent-chat-id u.parent-chat)
  ;<  ~  bind:m  (put-chat child-chat-id child-chat)
  ;<  ~  bind:m  (set-active-chat `child-chat-id)
  ::  Return the child chat ID as plain text
  (give-simple-payload:io [[200 ~[['content-type' 'text/plain']]] `(as-octs:mimes:html (crip (hexn:sailbox child-chat-id)))])
::
::  GET /master/claude - Redirect to active chat or new chat
::
++  handle-get-root
  |=  ~
  =/  m  (fiber:io ,~)
  ^-  form:m
  ;<  state=state-0  bind:m  (get-state-as:io state-0)
  =/  active=(unit @ux)  (get-active-chat ball.state)
  ?^  active
    (give-simple-payload:io [[303 ~[['location' (crip "/master/claude/{(hexn:sailbox u.active)}")]]] ~])
  (give-simple-payload:io [[303 ~[['location' '/master/claude/new']]] ~])
::
::  GET /master/claude/new - Create new chat and redirect
::
++  handle-get-new
  |=  ~
  =/  m  (fiber:io ,~)
  ^-  form:m
  ;<  state=state-0  bind:m  (get-state-as:io state-0)
  ;<  =bowl:gall  bind:m  get-bowl:io
  ::  Generate unique chat ID
  =/  all-chats=(map @ux chat:claude)  (get-all-chats ball.state)
  =/  chat-id=@ux  |-
    =/  candidate=@ux  `@ux`(sham eny.bowl)
    ?:  (~(has by all-chats) candidate)
      $(eny.bowl +(eny.bowl))
    candidate
  =/  new-chat=chat:claude
    :*  %0
        chat-id
        'New Chat'
        ~                                      :: parent
        ~                                      :: children
        ~                                      :: messages-by-time
        ~                                      :: messages-by-index
        ~                                      :: messages-by-chars
        0                                      :: next-index
        0                                      :: total-chars
        now.bowl
    ==
  ;<  ~  bind:m  (put-chat chat-id new-chat)
  ;<  ~  bind:m  (set-active-chat `chat-id)
  (give-simple-payload:io [[303 ~[['location' (crip "/master/claude/{(hexn:sailbox chat-id)}")]]] ~])
::
::  GET /master/claude/{id} - Render chat page
::
++  handle-get-chat
  |=  [chat-id=@ux user-timezone=@t creds-jon=(unit json)]
  =/  m  (fiber:io ,~)
  ^-  form:m
  ;<  state=state-0  bind:m  (get-state-as:io state-0)
  =/  chat=(unit chat:claude)  (get-chat ball.state chat-id)
  ?~  chat
    (give-simple-payload:io [[404 ~] `(as-octs:mimes:html '404 Chat Not Found')])
  ::  Extract creds for UI display (use defaults if not configured)
  =/  [api-key=@t ai-model=@t]
    ?~  creds-jon
      ['' 'claude-sonnet-4-20250514']
    :*  (~(dog jo:json-utils u.creds-jon) /api-key so:dejs:format)
        (~(dog jo:json-utils u.creds-jon) /ai-model so:dejs:format)
    ==
  =/  all-chats=(map @ux chat:claude)  (get-all-chats ball.state)
  (give-simple-payload:io (mime-response:sailbox [/text/html (manx-to-octs:server (chat-page:ui-claude u.chat all-chats user-timezone api-key ai-model))]))
::
::  GET /master/claude/{id}/messages - Get paginated messages
::
++  handle-get-messages
  |=  [chat-id=@ux args=(list [key=@t value=@t]) user-timezone=@t]
  =/  m  (fiber:io ,~)
  ^-  form:m
  ;<  state=state-0  bind:m  (get-state-as:io state-0)
  =/  chat=(unit chat:claude)  (get-chat ball.state chat-id)
  ?~  chat
    (give-simple-payload:io [[404 ~] `(as-octs:mimes:html '404 Chat Not Found')])
  ::  Parse query parameters
  =/  before-timestamp=(unit @ud)
    =/  before-str=(unit @t)  (~(get by (malt args)) 'before')
    ?~  before-str  ~
    `(rash u.before-str dem)
  =/  limit=@ud
    =/  limit-str=(unit @t)  (~(get by (malt args)) 'limit')
    ?~  limit-str  3
    (rash u.limit-str dem)
  ::  Get paginated messages using helper
  =/  message-list=(list [@ud message:claude])
    (get-messages-page:claude-lib messages-by-time.u.chat before-timestamp limit)
  ::  Render as HTML using render-message from ui-master
  =/  rendered-messages=(list manx)
    %-  zing
    %+  turn  message-list
    |=  [timestamp=@ud msg=message:claude]
    (render-message:ui-claude timestamp msg user-timezone)
  ::  Return fragments directly without wrapper div
  =/  html-text=@t
    %-  crip
    %-  zing
    %+  turn  rendered-messages
    |=(m=manx (en-xml:html m))
  (give-simple-payload:io [[200 ~] `(as-octs:mimes:html html-text)])
::
::  POST /master/update-claude-creds - Update Claude credentials
::
++  handle-update-creds
  |=  args=(list [key=@t value=@t])
  =/  m  (fiber:io ,~)
  ^-  form:m
  ;<  state=state-0  bind:m  (get-state-as:io state-0)
  ::  Get existing creds from ball
  =/  existing=(unit json)
    (~(get-cage-as ba:tarball ball.state) /config/creds 'claude.json' json)
  ::  Use existing values if not provided
  =/  api-key=@t
    ?~  existing
      (need (get-key:kv 'api-key' args))
    %.  (get-key:kv 'api-key' args)
    (curr fall (dog:~(. jo:json-utils u.existing) /api-key so:dejs:format))
  =/  ai-model=@t
    ?~  existing
      (fall (get-key:kv 'model' args) 'claude-sonnet-4-20250514')
    %.  (get-key:kv 'model' args)
    (curr fall (dog:~(. jo:json-utils u.existing) /ai-model so:dejs:format))
  ::  Build json directly
  =/  jon=json
    %-  pairs:enjs:format
    :~  ['api-key' s+api-key]
        ['ai-model' s+ai-model]
    ==
  ::  Put with validation
  ;<  new-ball=ball:tarball  bind:m  (put-cage:io ball.state /config/creds 'claude.json' [%json !>(jon)])
  =.  ball.state  new-ball
  ;<  ~  bind:m  (replace:io !>(state))
  (pure:m ~)
--
