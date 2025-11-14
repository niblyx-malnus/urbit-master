/-  *master
/+  io=sailboxio, sailbox, server, ui-claude, claude, chat-index,
    sse=sse-helpers, *html-utils, tarball
|%
::  POST /master/claude/{id} - Send message to Claude chat
::
++  handle-message
  |=  [chat-id=@ux message=@t api-key=@t ai-model=@t user-timezone=@t]
  =/  m  (fiber:io ,~)
  ^-  form:m
  ;<  state=state-0  bind:m  (get-state-as:io state-0)
  =/  chat=(unit claude-chat)  (~(get by claude-chats.state) chat-id)
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
  =/  user-msg=claude-message  ['user' user-content %normal chat-id 0 0 0 0]
  ;<  =bowl:gall  bind:m  get-bowl:io
  =/  user-timestamp=@ud  (unm:chrono:userlib now.bowl)
  ::  Add user message using triple-index helper
  =.  u.chat  (add-message:chat-index u.chat user-timestamp user-msg)
  =.  claude-chats.state  (~(put by claude-chats.state) chat-id u.chat)
  =.  active-chat.state  `chat-id
  ;<  ~  bind:m  (replace:io !>(state))
  ::  Send SSE event for user message
  ;<  ~  bind:m  (notify-chat-message:sse chat-id user-timestamp)
  ::  Call Claude and get response
  ;<  state=state-0  bind:m  (get-state-as:io state-0)
  =/  chat=(unit claude-chat)  (~(get by claude-chats.state) chat-id)
  ?~  chat
    (give-simple-payload:io [[200 ~] ~])
  =/  messages-before=((mop @ud claude-message) lth)  messages-by-time.u.chat
  ;<  [response=@t updated-chat=claude-chat]  bind:m
    (send-message:claude api-key ai-model u.chat claude-chats.state user-timezone)
  ::  Get fresh state after Claude call (tools may have modified it)
  ;<  state=state-0  bind:m  (get-state-as:io state-0)
  =/  chat-after=(unit claude-chat)  (~(get by claude-chats.state) chat-id)
  ?~  chat-after
    (give-simple-payload:io [[200 ~] ~])
  ~&  >  "Chat name after tools: '{<name.u.chat-after>}'"
  ::  Update chat with new messages (preserving name from updated-chat, which may have been changed by tools)
  =.  updated-chat  updated-chat(name name.u.chat-after)
  =.  claude-chats.state  (~(put by claude-chats.state) chat-id updated-chat)
  ;<  ~  bind:m  (replace:io !>(state))
  ::  Get all message timestamps from updated chat (already in order)
  =/  all-timestamps=(list @ud)  (turn (tap:((on @ud claude-message) lth) messages-by-time.updated-chat) head)
  =/  before-timestamps=(list @ud)  (turn (tap:((on @ud claude-message) lth) messages-before) head)
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
  =/  chat=(unit claude-chat)  (~(get by claude-chats.state) chat-id)
  ?~  chat
    (give-simple-payload:io [[404 ~] `(as-octs:mimes:html '404 Chat Not Found')])
  ::  Update the chat name
  =.  name.u.chat  new-name
  =.  claude-chats.state  (~(put by claude-chats.state) chat-id u.chat)
  ;<  ~  bind:m  (replace:io !>(state))
  (give-simple-payload:io [[200 ~[['content-type' 'text/plain']]] `(as-octs:mimes:html 'OK')])
::
::  POST /master/claude/{id}/delete - Delete a chat
::
++  handle-delete
  |=  chat-id=@ux
  =/  m  (fiber:io ,~)
  ^-  form:m
  ;<  state=state-0  bind:m  (get-state-as:io state-0)
  ::  Delete the chat
  =.  claude-chats.state  (~(del by claude-chats.state) chat-id)
  ::  Clear active chat if it was the deleted one
  =?  active-chat.state  =(`chat-id active-chat.state)  ~
  ;<  ~  bind:m  (replace:io !>(state))
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
  =/  parent-chat=(unit claude-chat)  (~(get by claude-chats.state) parent-chat-id)
  ?~  parent-chat
    (give-simple-payload:io [[404 ~] `(as-octs:mimes:html '404 Parent Chat Not Found')])
  ::  Verify branch point is a valid message index in parent
  =/  branch-msg=(unit claude-message)
    (get:((on @ud claude-message) lth) messages-by-index.u.parent-chat branch-point)
  ?~  branch-msg
    (give-simple-payload:io [[400 ~] `(as-octs:mimes:html '400 Invalid branch point')])
  ::  Generate unique child chat ID
  =/  child-chat-id=@ux  |-
    =/  candidate=@ux  `@ux`(sham eny.bowl)
    ?:  (~(has by claude-chats.state) candidate)
      $(eny.bowl +(eny.bowl))
    candidate
  ::  Build new child chat (empty, will reference parent for history)
  =/  child-chat=claude-chat
    :*  child-chat-id
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
  =.  claude-chats.state  (~(put by claude-chats.state) parent-chat-id u.parent-chat)
  =.  claude-chats.state  (~(put by claude-chats.state) child-chat-id child-chat)
  =.  active-chat.state  `child-chat-id
  ;<  ~  bind:m  (replace:io !>(state))
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
  ?^  active-chat.state
    (give-simple-payload:io [[303 ~[['location' (crip "/master/claude/{(hexn:sailbox u.active-chat.state)}")]]] ~])
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
  =/  chat-id=@ux  |-
    =/  candidate=@ux  `@ux`(sham eny.bowl)
    ?:  (~(has by claude-chats.state) candidate)
      $(eny.bowl +(eny.bowl))
    candidate
  =/  new-chat=claude-chat
    :*  chat-id
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
  =.  claude-chats.state  (~(put by claude-chats.state) chat-id new-chat)
  =.  active-chat.state  `chat-id
  ;<  ~  bind:m  (replace:io !>(state))
  (give-simple-payload:io [[303 ~[['location' (crip "/master/claude/{(hexn:sailbox chat-id)}")]]] ~])
::
::  GET /master/claude/{id} - Render chat page
::
++  handle-get-chat
  |=  [chat-id=@ux user-timezone=@t creds=(unit claude-creds)]
  =/  m  (fiber:io ,~)
  ^-  form:m
  ;<  state=state-0  bind:m  (get-state-as:io state-0)
  =/  chat=(unit claude-chat)  (~(get by claude-chats.state) chat-id)
  ?~  chat
    (give-simple-payload:io [[404 ~] `(as-octs:mimes:html '404 Chat Not Found')])
  ::  Use default creds if not configured (for UI display only)
  =/  display-creds=claude-creds
    ?~  creds
      [api-key='' ai-model='claude-sonnet-4-20250514']
    u.creds
  (give-simple-payload:io (mime-response:sailbox [/text/html (manx-to-octs:server (chat-page:ui-claude u.chat claude-chats.state user-timezone display-creds))]))
::
::  GET /master/claude/{id}/messages - Get paginated messages
::
++  handle-get-messages
  |=  [chat-id=@ux args=(list [key=@t value=@t]) user-timezone=@t]
  =/  m  (fiber:io ,~)
  ^-  form:m
  ;<  state=state-0  bind:m  (get-state-as:io state-0)
  =/  chat=(unit claude-chat)  (~(get by claude-chats.state) chat-id)
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
  =/  message-list=(list [@ud claude-message])
    (get-messages-page:claude messages-by-time.u.chat before-timestamp limit)
  ::  Render as HTML using render-message from ui-master
  =/  rendered-messages=(list manx)
    %-  zing
    %+  turn  message-list
    |=  [timestamp=@ud msg=claude-message]
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
  ;<  =bowl:gall  bind:m  get-bowl:io
  ::  Get existing creds from ball
  =/  existing=(unit claude-creds)
    (~(get-cage-as ba:tarball ball.state) /config/creds 'claude.json' claude-creds)
  ::  Use existing values if not provided
  =/  api-key=@t
    ?~  existing
      (need (get-key:kv 'api-key' args))
    (fall (get-key:kv 'api-key' args) api-key.u.existing)
  =/  ai-model=@t
    ?~  existing
      (fall (get-key:kv 'model' args) 'claude-sonnet-4-20250514')
    (fall (get-key:kv 'model' args) ai-model.u.existing)
  =/  creds=claude-creds  [api-key ai-model]
  =.  ball.state
    (~(put ba:tarball ball.state) /config/creds 'claude.json' (make-cage:tarball [%json !>(creds)] now.bowl))
  ;<  ~  bind:m  (replace:io !>(state))
  (pure:m ~)
--
