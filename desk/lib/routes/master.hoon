/-  *master
/+  io=sailboxio, sailbox, server, ui-master, html-utils, tarball, multipart, json-utils
/=  ball-routes  /lib/routes/ball
/=  claude-routes  /lib/routes/claude
/=  s3-routes  /lib/routes/s3
/=  telegram-routes  /lib/routes/telegram
/=  brave-routes  /lib/routes/brave
/=  mcp-routes  /lib/routes/mcp
=,  html-utils
|%
::  Helper to get claude creds from ball as json
::
++  get-claude-creds
  |=  =ball:tarball
  ^-  (unit json)
  (~(get-cage-as ba:tarball ball) /config/creds 'claude.json' json)
::  GET request router
::
++  handle-get-request
  |=  $:  req=inbound-request:eyre
          =bowl:gall
      ==
  =/  m  (fiber:io ,~)
  ^-  form:m
  ;<  ball=ball:tarball  bind:m  get-state:io
  =/  user-timezone=@t
    =/  tz-result  (mule |.((~(get-cage-as ba:tarball ball) /config 'timezone.txt' wain)))
    ?:  ?=(%| -.tz-result)  'UTC'
    =/  tz-wain=(unit wain)  p.tz-result
    ?~  tz-wain  'UTC'
    ?~  u.tz-wain  'UTC'
    i.u.tz-wain
  =/  lin=request-line:server  (parse-request-line:server url.request.req)
  ::  Check authentication
  ?.  =(our src):bowl
    (give-simple-payload:io (login-redirect:sailbox [ext site]:lin args.lin))
  ::  Route all GET requests
  ?+    site.lin  ~|(%unrecognized-get !!)
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
    ~&  >>>  i.t.t.site.lin
    =/  chat-id=@ux  (rash i.t.t.site.lin hex)
    =/  creds-jon=(unit json)  (get-claude-creds ball)
    (handle-get-chat:claude-routes chat-id user-timezone creds-jon)
  ::
      [%master %claude @ %messages ~]
    =/  chat-id=@ux  (rash i.t.t.site.lin hex)
    (handle-get-messages:claude-routes chat-id args.lin user-timezone)
  ::
      [%master %ball *]
    =/  ball-path=(list @t)  t.t.site.lin
    ;<  payload=simple-payload:http  bind:m
      (handle-get:ball-routes ball bowl ball-path [ext args]:lin)
    (give-simple-payload:io payload)
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
::  Multipart POST request router (file uploads)
::
++  handle-multipart-request
  |=  $:  req=inbound-request:eyre
          site=(list @t)
      ==
  =/  m  (fiber:io ,~)
  ^-  form:m
  ?+    site  !!
      [%master %ball *]
    =/  ball-path=path  t.t.site
    (handle-multipart-upload:ball-routes req ball-path)
  ==
::
::  Form-encoded POST request router
::
++  handle-form-request
  |=  $:  req=inbound-request:eyre
          site=(list @t)
      ==
  =/  m  (fiber:io ,~)
  ^-  form:m
  ;<  ball=ball:tarball  bind:m  get-state:io
  =/  user-timezone=@t
    =/  tz-result  (mule |.((~(get-cage-as ba:tarball ball) /config 'timezone.txt' wain)))
    ?:  ?=(%| -.tz-result)  'UTC'
    =/  tz-wain=(unit wain)  p.tz-result
    ?~  tz-wain  'UTC'
    ?~  u.tz-wain  'UTC'
    i.u.tz-wain
  =/  args=key-value-list:kv  (parse-body:kv body.request.req)
  ?+    site  !!
      [%master %test-sse ~]
    =.  io  io(hold &) :: claim the mutex
    ;<  ball=ball:tarball  bind:m  get-state:io
    ::  Initialize counter to 0 in ball
    ;<  ~  bind:m  (put-cage:io /state 'counter.ud' [%ud !>(0)])
    ;<  ~  bind:m  (send-sse-event:io /master/test-sse ~ `'/test/counter')
    |-
    ;<  ball=ball:tarball  bind:m  get-state:io
    ::  Read counter from ball
    =/  counter=@ud  (~(got-cage-as ba:tarball ball) /state 'counter.ud' @ud)
    ?:  (gte counter 5)
      (give-simple-payload:io [[200 ~] ~])
    ::  Increment counter in ball
    ;<  ~  bind:m  (put-cage:io /state 'counter.ud' [%ud !>(+(counter))])
    ;<  ~  bind:m  (send-sse-event:io /master/test-sse ~ `'/test/counter')
    ;<  ~  bind:m  (sleep:io ~s1)
    $
  ::
      [%master %telegram ~]
    =/  message=@t  (need (get-key:kv 'message' args))
    (handle-send-message:telegram-routes message)
  ::
      [%master %test-diff ~]
    ;<  ball=ball:tarball  bind:m  get-state:io
    ::  Create original version
    =/  old-text=wain  ~['line 1' 'line 2' 'line 3']
    ;<  ~  bind:m
      (put-cage:io /state 'test.txt' [%txt !>(old-text)])
    ::  Create new version
    =/  new-text=wain  ~['line 1' 'line 2 MODIFIED' 'line 3' 'line 4 ADDED']
    ::  Compute diff
    ;<  diff=vase  bind:m
      (diff-file:io ball /state 'test.txt' %txt !>(old-text) !>(new-text))
    ::  Apply patch
    ;<  ~  bind:m
      (patch-file:io /state 'test.txt' diff)
    ::  Re-read ball and result after patch
    ;<  ball=ball:tarball  bind:m  get-state:io
    =/  result=wain  (~(got-cage-as ba:tarball ball) /state 'test.txt' wain)
    ::  Return success with result
    =/  response=tape
      """
      Diff/Patch Test Success!

      Original: [{(trip (of-wain:format old-text))}]
      Expected: [{(trip (of-wain:format new-text))}]
      Result:   [{(trip (of-wain:format result))}]
      Match: {?:(=(new-text result) "YES" "NO")}
      """
    (give-simple-payload:io [[200 ~] `(as-octs:mimes:html (crip response))])
  ::
      [%master %set-timezone ~]
    =/  timezone=@t  (need (get-key:kv 'timezone' args))
    ;<  ball=ball:tarball  bind:m  get-state:io
    ;<  ~  bind:m  (put-cage:io /config 'timezone.txt' [%txt !>(~[timezone])])
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
    ;<  ball=ball:tarball  bind:m  get-state:io
    =/  jon=json
      (~(got-cage-as ba:tarball ball) /config/creds 'claude.json' json)
    =/  api-key=@t  (~(dog jo:json-utils jon) /api-key so:dejs:format)
    =/  ai-model=@t  (~(dog jo:json-utils jon) /ai-model so:dejs:format)
    %:  handle-message:claude-routes
      chat-id
      message
      api-key
      ai-model
      user-timezone
    ==
  ::
      [%master %claude @ %branch ~]
    =/  parent-chat-id=@ux  (rash i.t.t.site hex)
    =/  branch-point=@ud  (rash (need (get-key:kv 'branch-point' args)) dem)
    (handle-branch:claude-routes parent-chat-id branch-point)
  ::
      [%master %ball *]
    =/  ball-path=path  t.t.site
    (handle-form-actions:ball-routes ball-path args)
  ==
--
