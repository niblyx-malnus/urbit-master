/-  *master
/+  io=sailboxio, sailbox, server, ui-master, html-utils, tarball
/=  claude-routes  /lib/routes/claude
/=  s3-routes  /lib/routes/s3
/=  telegram-routes  /lib/routes/telegram
/=  brave-routes  /lib/routes/brave
/=  mcp-routes  /lib/routes/mcp
=,  html-utils
|%
::  Helper to get claude creds from ball
::
++  get-claude-creds
  |=  =ball:tarball
  ^-  claude-creds
  (~(get-cage-as ba:tarball ball) / 'claude-creds.json' claude-creds)
::  GET request router
::
++  handle-get-request
  |=  $:  req=inbound-request:eyre
          =bowl:gall
          state=state-0
      ==
  =/  m  (fiber:io ,~)
  ^-  form:m
  =/  user-timezone=@t  (~(get-cage-as ba:tarball ball.state) / 'user-timezone.txt' @t)
  =/  lin=request-line:server  (parse-request-line:server url.request.req)
  =/  site=(list @t)  site.lin
  =/  args=(list [key=@t value=@t])  args.lin
  ::  Check authentication
  ?.  =(our src):bowl
    (give-simple-payload:io (login-redirect:sailbox [ext site]:lin args))
  ::  Route all GET requests
  ?+    site  ~|(%unrecognized-get !!)
      [%master ~]
    =/  =simple-payload:http
      (mime-response:sailbox [/text/html (manx-to-octs:server home-page:ui-master)])
    (give-simple-payload:io simple-payload)
  ::
      [%master %test-sse ~]
    =/  =simple-payload:http
      (mime-response:sailbox [/text/html (manx-to-octs:server simple-sse-test:ui-master)])
    (give-simple-payload:io simple-payload)
  ::
      [%master %claude ~]
    (handle-get-root:claude-routes ~)
  ::
      [%master %claude %new ~]
    (handle-get-new:claude-routes ~)
  ::
      [%master %claude @ ~]
    =/  chat-id=@ux  (rash i.t.t.site hex)
    =/  creds=claude-creds  (get-claude-creds ball.state)
    (handle-get-chat:claude-routes chat-id user-timezone creds)
  ::
      [%master %claude @ %messages ~]
    =/  chat-id=@ux  (rash i.t.t.site hex)
    (handle-get-messages:claude-routes chat-id args user-timezone)
  ==
::
::  JSON POST request router
::
++  handle-json-request
  |=  $:  req=inbound-request:eyre
          site=(list @t)
      ==
  =/  m  (fiber:io ,~)
  ^-  form:m
  ::  Route JSON requests based on path
  ?+    site  !!
      [%master %mcp ~]
    (handle-request:mcp-routes req)
  ==
::
::  Form-encoded POST request router
::
++  handle-form-request
  |=  $:  req=inbound-request:eyre
          site=(list @t)
          state=state-0
      ==
  =/  m  (fiber:io ,~)
  ^-  form:m
  =/  user-timezone=@t  (~(get-cage-as ba:tarball ball.state) / 'user-timezone.txt' @t)
  =/  args=key-value-list:kv  (parse-body:kv body.request.req)
  ?+    site  !!
      [%master %test-sse ~]
    =.  io  io(hold &) :: claim the mutex
    ;<  state=state-0  bind:m  (get-state-as:io state-0)
    =.  state  state(counter 0)
    ;<  ~  bind:m  (replace:io !>(state))
    ;<  ~  bind:m  (send-sse-event:io /master/test-sse ~ `'/test/counter')
    |-
    ;<  state=state-0  bind:m  (get-state-as:io state-0)
    ?:  (gte counter.state 5)
      (give-simple-payload:io [[200 ~] ~])
    ;<  ~  bind:m  (replace:io !>(state(counter +(counter.state))))
    ;<  ~  bind:m  (send-sse-event:io /master/test-sse ~ `'/test/counter')
    ;<  ~  bind:m  (sleep:io ~s1)
    $
  ::
      [%master %telegram ~]
    =/  message=@t  (need (get-key:kv 'message' args))
    (handle-send-message:telegram-routes message)
  ::
      [%master %set-timezone ~]
    =/  timezone=@t  (need (get-key:kv 'timezone' args))
    ;<  state=state-0  bind:m  (get-state-as:io state-0)
    =.  ball.state  (~(put ba:tarball ball.state) / 'user-timezone.txt' [%cage ~ [%txt !>(timezone)]])
    ;<  ~  bind:m  (replace:io !>(state))
    (give-simple-payload:io [[200 ~] ~])
  ::
      [%master %s3-upload ~]
    =/  text=@t  (fall (get-key:kv 'text' args) 'Hello world!')
    =/  filename=@t  (fall (get-key:kv 'filename' args) 'test.txt')
    (handle-upload:s3-routes text filename)
  ::
      [%master %s3-get ~]
    =/  filename=@t  (fall (get-key:kv 'filename' args) 'test.txt')
    (handle-get:s3-routes filename)
  ::
      [%master %s3-delete ~]
    =/  filename=@t  (fall (get-key:kv 'filename' args) 'test.txt')
    (handle-delete:s3-routes filename)
  ::
      [%master %s3-list ~]
    =/  prefix=@t  (fall (get-key:kv 'prefix' args) '')
    (handle-list:s3-routes prefix)
  ::
      [%master %s3-get-directory ~]
    =/  prefix=@t  (fall (get-key:kv 'prefix' args) '')
    (handle-get-directory:s3-routes prefix)
  ::
      [%master %update-creds ~]
    =/  bot-token=@t  (need (get-key:kv 'bot-token' args))
    =/  chat-id=@t  (need (get-key:kv 'chat-id' args))
    (handle-update-creds:telegram-routes bot-token chat-id)
  ::
      [%master %update-s3-creds ~]
    =/  access-key=@t  (need (get-key:kv 'access-key' args))
    =/  secret-key=@t  (need (get-key:kv 'secret-key' args))
    =/  region=@t  (need (get-key:kv 'region' args))
    =/  bucket=@t  (need (get-key:kv 'bucket' args))
    =/  endpoint=@t  (need (get-key:kv 'endpoint' args))
    (handle-update-creds:s3-routes access-key secret-key region bucket endpoint)
  ::
      [%master %update-claude-creds ~]
    (handle-update-creds:claude-routes args)
  ::
      [%master %update-brave-creds ~]
    (handle-update-creds:brave-routes args)
  ::
      [%master %claude @ %rename ~]
    =/  chat-id=@ux  (rash i.t.t.site hex)
    =/  new-name=@t  (need (get-key:kv 'name' args))
    (handle-rename:claude-routes chat-id new-name)
  ::
      [%master %claude @ %delete ~]
    =/  chat-id=@ux  (rash i.t.t.site hex)
    (handle-delete:claude-routes chat-id)
  ::
      [%master %claude @ ~]
    =/  chat-id=@ux  (rash i.t.t.site hex)
    =/  message=@t  (need (get-key:kv 'message' args))
    ;<  state=state-0  bind:m  (get-state-as:io state-0)
    =/  creds=claude-creds  (get-claude-creds ball.state)
    %:  handle-message:claude-routes
      chat-id
      message
      api-key.creds
      ai-model.creds
      user-timezone
    ==
  ::
      [%master %claude @ %branch ~]
    =/  parent-chat-id=@ux  (rash i.t.t.site hex)
    =/  branch-point=@ud  (rash (need (get-key:kv 'branch-point' args)) dem)
    (handle-branch:claude-routes parent-chat-id branch-point)
  ==
--
