/-  *master
/+  dbug, sailbox, io=sailboxio, server,
    ui-master, ui-claude, ui-ball, telegram,
    sse=sse-helpers, tarball
/=  master-routes  /lib/routes/master
/=  telegram-routes  /lib/routes/telegram
/=  s3-routes  /lib/routes/s3
/=  claude-routes  /lib/routes/claude
/=  brave-routes  /lib/routes/brave
/=  t-  /tests/tarball
/=  m-  /mar/eyre/bindings
/=  m-  /mar/claude/chat
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
    ;<  =bowl:gall  bind:m  get-bowl:io
    ::  Create /config and /config/creds directories
    ;<  new-ball=ball:tarball  bind:m  (mkd:io ball.state /config)
    =.  ball.state  new-ball
    ;<  new-ball=ball:tarball  bind:m  (mkd:io ball.state /config/creds)
    =.  ball.state  new-ball
    ::  Set default timezone to UTC with correct type (wain)
    ;<  new-ball=ball:tarball  bind:m  (put-cage:io ball.state /config 'timezone.txt' [%txt !>(~['UTC'])])
    =.  ball.state  new-ball
    ::  Set default eyre bindings
    =/  default-bindings=(list binding:eyre)  ~[[~ /master]]
    ;<  new-ball=ball:tarball  bind:m  (put-cage:io ball.state /config 'bindings.eyre-bindings' [%eyre-bindings !>(default-bindings)])
    =.  ball.state  new-ball
    ::  Create /state directory and initialize counter
    ;<  new-ball=ball:tarball  bind:m  (mkd:io ball.state /state)
    =.  ball.state  new-ball
    ;<  new-ball=ball:tarball  bind:m  (put-cage:io ball.state /state 'counter.ud' [%ud !>(0)])
    =.  ball.state  new-ball
    ::  Create /processes/commits and /processes/alarms directories
    ;<  new-ball=ball:tarball  bind:m  (mkd:io ball.state /processes)
    =.  ball.state  new-ball
    ;<  new-ball=ball:tarball  bind:m  (mkd:io ball.state /processes/commits)
    =.  ball.state  new-ball
    ;<  new-ball=ball:tarball  bind:m  (mkd:io ball.state /processes/alarms)
    =.  ball.state  new-ball
    ::  Create /claude directory for chats and active chat
    ;<  new-ball=ball:tarball  bind:m  (mkd:io ball.state /claude)
    =.  ball.state  new-ball
    ;<  new-ball=ball:tarball  bind:m  (mkd:io ball.state /claude/chats)
    =.  ball.state  new-ball
    ::  Initialize active-chat as empty (no active chat)
    ;<  new-ball=ball:tarball  bind:m  (put-cage:io ball.state /claude 'active-chat.txt' [%txt !>(~)])
    =.  ball.state  new-ball
    ;<  ~  bind:m  (replace:io !>(state))
    ::  Set bindings (just use the default we created)
    (set-bindings:io default-bindings)
    ::
      %on-load :: sent by sailbox
    ;<  state=state-0  bind:m  (get-state-as:io state-0)
    ::  Read bindings from config and set them (with fallback if not found)
    =/  bindings=(list binding:eyre)
      =/  maybe-bindings=(unit (list binding:eyre))
        (~(get-cage-as ba:tarball ball.state) /config 'bindings.eyre-bindings' ,(list binding:eyre))
      ?~  maybe-bindings
        ~[[~ /master]]  ::  fallback to default
      u.maybe-bindings
    ;<  ~  bind:m  (set-bindings:io bindings)
    ::  Sailbox will auto-restart alarm fibers with fresh=%.n
    (pure:m ~)
    ::
      %set-binding
    =+  !<(new-binding=binding:eyre vase)
    ;<  state=state-0  bind:m  (get-state-as:io state-0)
    ::  Read current bindings from config
    =/  current-bindings=(list binding:eyre)
      (~(got-cage-as ba:tarball ball.state) /config 'bindings.eyre-bindings' ,(list binding:eyre))
    ::  Add new binding if not already present
    =/  updated-bindings=(list binding:eyre)
      ?:  (lien current-bindings |=(b=binding:eyre =(b new-binding)))
        current-bindings
      [new-binding current-bindings]
    ::  Write updated bindings back to config
    ;<  new-ball=ball:tarball  bind:m  (put-cage:io ball.state /config 'bindings.eyre-bindings' [%eyre-bindings !>(updated-bindings)])
    =.  ball.state  new-ball
    ;<  ~  bind:m  (replace:io !>(state))
    (set-bindings:io updated-bindings)
    ::
      %set-alarm
    =+  !<([wake-time=@da message=@t] vase)
    (run-alarm:telegram wake-time message)
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
    ::  Route multipart POSTs (file uploads)
    ?:  ?&  ?=(^ content-type)
            =('multipart/form-data; boundary=' (end 3^30 u.content-type))
        ==
      (handle-multipart-request:master-routes req site state)
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
