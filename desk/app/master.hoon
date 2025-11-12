/-  *master
/+  dbug, sailbox, io=sailboxio, server,
    ui-master, ui-claude, telegram,
    sse=sse-helpers
/=  master-routes  /lib/routes/master
/=  telegram-routes  /lib/routes/telegram
/=  s3-routes  /lib/routes/s3
/=  claude-routes  /lib/routes/claude
/=  brave-routes  /lib/routes/brave
/=  t-  /tests/tarball
=>
  |%
  +$  card  card:sailbox
  --
^-  agent:gall
%-  agent:dbug
%-  agent:sailbox
^-  sailbox:sailbox
|%
++  initial
  ^-  vase
  =|  state=state-0
  =.  bindings.state  (sy ~[[~ /master]])
  =.  telegram-creds.state  initial-creds:telegram-routes
  =.  s3-creds.state  initial-creds:s3-routes
  =.  claude-creds.state  initial-creds:claude-routes
  =.  brave-search-creds.state  initial-creds:brave-routes
  =.  user-timezone.state  'UTC'
  =.  telegram-alarms.state  ~
  !>(state)
::
++  migrate
  |=  old=vase
  ^-  vase
  =+  !<(=state-0 old)
  !>(state-0)
::
++  on-peek
  |=  [=bowl:gall state=vase =path]
  ~|  "unexpected scry into {<dap.bowl>} on path {<path>}"
  :: [~ ~]
  ?+  path  [~ ~]
    [%x %dbug %state ~]  ``noun+state
  ==
::
++  process
  =/  m  (fiber:io ,~)
  ^-  form:m
  ;<  our=@p  bind:m  get-our:io
  ;<  src=@p  bind:m  get-poke-guest:io
  ~&  our+our
  ~&  src+src
  ?.  =(our src)  (fiber-fail:io leaf+"not us" ~)
  ;<  [=mark =vase]  bind:m  get-poke:io
  ?+    mark  !!
      %on-fail :: sent by sailbox
    =+  !<([=term =tang] vase)
    (pure:m ~)
    ::
      %on-init :: sent by sailbox
    ;<  state=state-0  bind:m  (get-state-as:io state-0)
    ;<  ~  bind:m  (set-bindings:io ~(tap in bindings.state))
    ::  Restart all pending telegram alarms
    (restart-alarms:telegram telegram-alarms.state)
    ::
      %on-load :: sent by sailbox
    ;<  state=state-0  bind:m  (get-state-as:io state-0)
    ;<  ~  bind:m  (set-bindings:io ~(tap in bindings.state))
    ::  Restart all pending telegram alarms
    (restart-alarms:telegram telegram-alarms.state)
    ::
      %set-binding
    =+  !<(new-binding=binding:eyre vase)
    ;<  state=state-0  bind:m  (get-state-as:io state-0)
    =.  bindings.state  (~(put in bindings.state) new-binding)
    ;<  ~  bind:m  (replace:io !>(state))
    (set-bindings:io ~(tap in bindings.state))
    ::
      %spawn-alarm
    =+  !<([alarm-id=@da =telegram-alarm] vase)
    (handle-spawn-alarm:telegram-routes alarm-id telegram-alarm)
    ::
      %handle-http-request
    =+  !<(req=inbound-request:eyre vase)
    ;<  state=state-0  bind:m  (get-state-as:io state-0)
    ;<  =bowl:gall  bind:m  get-bowl:io
    =/  lin=request-line:server  (parse-request-line:server url.request.req)
    =/  site=(list @t)  site.lin
    ::  Route based on HTTP method
    ?:  ?=(%'GET' method.request.req)
      (handle-get-request:master-routes req bowl state)
    ::  Parse POST content-type
    =/  content-type=(unit @t)
      (get-header:http 'content-type' header-list.request.req)
    ::  Route JSON POSTs
    ?:  ?=([~ %'application/json'] content-type)
      (handle-json-request:master-routes req site)
    ::  Route form-encoded POSTs
    (handle-form-request:master-routes req site state)
  ==
::
++  first-sse-event
  |=  $:  site=(list @t)
          args=(list [key=@t value=@t])
          last-event-id=(unit @t)
      ==
  ^-  (unit sse-key:sailbox)
  ?+    site  ~
    [%master %test-sse ~]          `[~ `'/test/counter']
    [%master %claude %stream @ ~]  ~
  ==
::
++  make-sse-event
  |=  $:  =bowl:gall
          state=vase
          site=(list @t)
          args=(list [key=@t value=@t])
          id=(unit @t)
          event=(unit @t)
      ==
  ^-  wain
  =+  !<(state-0 state)
  ?+    site  !!
      [%master %test-sse ~]
    (handle-simple-sse:ui-master bowl state args id event)
    ::
      [%master %claude %stream @ ~]
    =/  chat-id=@ux  (rash i.t.t.t.site hex)
    (handle-claude-sse:ui-claude bowl state chat-id args id event)
  ==
--
