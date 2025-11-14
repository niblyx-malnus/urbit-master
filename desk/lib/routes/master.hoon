/-  *master
/+  io=sailboxio, sailbox, server, ui-master, ui-ball, html-utils, tarball, multipart, json-utils
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
::  Helper to collect all marks used in cages within a ball
::
++  collect-marks
  |=  =ball:tarball
  ^-  (set mark)
  =/  marks=(set mark)  ~
  ::  Collect marks from current node's contents
  =?  marks  ?=(^ fil.ball)
    =/  entries=(list (pair @ta content:tarball))
      ~(tap by contents.u.fil.ball)
    |-  ^-  (set mark)
    ?~  entries  marks
    =*  content  q.i.entries
    ?.  ?=(%cage -.content)
      $(entries t.entries)
    $(entries t.entries, marks (~(put in marks) p.cage.content))
  ::  Recurse into subdirectories
  =/  subdirs=(list (pair @ta ball:tarball))  ~(tap by dir.ball)
  |-  ^-  (set mark)
  ?~  subdirs  marks
  =/  submarks=(set mark)  ^$(ball q.i.subdirs)
  $(subdirs t.subdirs, marks (~(uni in marks) submarks))
::  Helper to build a single tube, trying our desk first then %base
::
++  try-build-tube
  |=  [our=@p =desk =case =mars:clay]
  =/  m  (fiber:io ,(unit tube:clay))
  ^-  form:m
  ;<  tube=(unit tube:clay)  bind:m
    (build-tube-soft:io [our desk case] mars)
  ?^  tube
    (pure:m tube)
  (build-tube-soft:io [our %base case] mars)
::  Helper to build a single dais, trying our desk first then %base
::
++  try-build-dais
  |=  [our=@p =desk =case =mark]
  =/  m  (fiber:io ,(unit dais:clay))
  ^-  form:m
  ;<  dais=(unit dais:clay)  bind:m
    (build-mark-soft:io [our desk case] mark)
  ?^  dais
    (pure:m dais)
  (build-mark-soft:io [our %base case] mark)
::  Helper to build mark dais map for all marks in a ball
::
++  get-mark-dais
  |=  =ball:tarball
  =/  m  (fiber:io ,(map mark dais:clay))
  ^-  form:m
  ;<  our=@p  bind:m  get-our:io
  ;<  =desk  bind:m  get-desk:io
  ;<  now=@da  bind:m  get-time:io
  =/  =case  [%da now]
  =/  marks=(list mark)  ~(tap in (collect-marks ball))
  =/  dais-map=(map mark dais:clay)  ~
  |-  ^-  form:m
  ?~  marks
    (pure:m dais-map)
  ;<  dais-result=(unit dais:clay)  bind:m
    (try-build-dais our desk case i.marks)
  =?  dais-map  ?=(^ dais-result)
    (~(put by dais-map) i.marks u.dais-result)
  $(marks t.marks)
::  Helper to build mark conversions, trying our desk first then %base
::
++  get-mark-conversions
  |=  =ball:tarball
  =/  m  (fiber:io ,(map mars:clay tube:clay))
  ^-  form:m
  ;<  our=@p  bind:m  get-our:io
  ;<  =desk  bind:m  get-desk:io
  ;<  now=@da  bind:m  get-time:io
  =/  =case  [%da now]
  =/  marks=(list mark)  ~(tap in (collect-marks ball))
  =/  conversions=(map mars:clay tube:clay)  ~
  |-  ^-  form:m
  ?~  marks
    (pure:m conversions)
  =/  from=mark  i.marks
  =/  to=mark  %mime
  =/  =mars:clay  [from to]
  ;<  tube-result=(unit tube:clay)  bind:m
    (try-build-tube our desk case mars)
  =?  conversions  ?=(^ tube-result)
    (~(put by conversions) mars u.tube-result)
  $(marks t.marks)
::  GET request router
::
++  handle-get-request
  |=  $:  req=inbound-request:eyre
          =bowl:gall
          state=state-0
      ==
  =/  m  (fiber:io ,~)
  ^-  form:m
  =/  user-timezone=@t
    =/  tz-result  (mule |.((~(get-cage-as ba:tarball ball.state) /config 'timezone.txt' wain)))
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
    =/  chat-id=@ux  (rash i.t.t.site.lin hex)
    =/  creds-jon=(unit json)  (get-claude-creds ball.state)
    (handle-get-chat:claude-routes chat-id user-timezone creds-jon)
  ::
      [%master %claude @ %messages ~]
    =/  chat-id=@ux  (rash i.t.t.site.lin hex)
    (handle-get-messages:claude-routes chat-id args.lin user-timezone)
  ::
      [%master %ball ~]
    ;<  conversions=(map mars:clay tube:clay)  bind:m  (get-mark-conversions ball.state)
    =/  =simple-payload:http
      (mime-response:sailbox (handle-ball-get:ui-ball ball.state bowl conversions ~ [ext args]:lin))
    (give-simple-payload:io simple-payload)
  ::
      [%master %ball *]
    ;<  conversions=(map mars:clay tube:clay)  bind:m  (get-mark-conversions ball.state)
    =/  ball-path=(list @t)  t.t.site.lin
    =/  =simple-payload:http
      %-  mime-response:sailbox
      (handle-ball-get:ui-ball ball.state bowl conversions t.t.site.lin [ext args]:lin)
    (give-simple-payload:io simple-payload)
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
          state=state-0
      ==
  =/  m  (fiber:io ,~)
  ^-  form:m
  ?+    site  !!
      [%master %ball ~]
    ::  Parse multipart data
    =/  parts=(unit (list [@t part:multipart]))
      (de-request:multipart header-list.request.req body.request.req)
    ?~  parts
      (give-simple-payload:io [[400 ~] `(as-octs:mimes:html 'Invalid multipart data')])
    ;<  =bowl:gall  bind:m  get-bowl:io
    ::  Get conversions for file type detection
    =/  conversions=(map mars:clay tube:clay)  ~
    ::  Update ball with uploaded files
    =/  new-ball=ball:tarball
      (from-parts:tarball ball.state ~ u.parts now.bowl conversions)
    =.  ball.state  new-ball
    ;<  state=state-0  bind:m  (get-state-as:io state-0)
    =.  ball.state  new-ball
    ;<  ~  bind:m  (replace:io !>(state))
    (give-simple-payload:io [[303 ~[['location' '/master/ball']]] ~])
  ::
      [%master %ball *]
    ::  Parse multipart data
    =/  parts=(unit (list [@t part:multipart]))
      (de-request:multipart header-list.request.req body.request.req)
    ?~  parts
      (give-simple-payload:io [[400 ~] `(as-octs:mimes:html 'Invalid multipart data')])
    ;<  =bowl:gall  bind:m  get-bowl:io
    =/  ball-path=path  t.t.site
    =/  conversions=(map mars:clay tube:clay)  ~
    ::  Update ball with uploaded files
    =/  new-ball=ball:tarball
      (from-parts:tarball ball.state ball-path u.parts now.bowl conversions)
    =.  ball.state  new-ball
    ;<  state=state-0  bind:m  (get-state-as:io state-0)
    =.  ball.state  new-ball
    ;<  ~  bind:m  (replace:io !>(state))
    =/  redirect-url=tape
      (weld "/master/ball" (trip (spat ball-path)))
    (give-simple-payload:io [[303 ~[['location' (crip redirect-url)]]] ~])
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
  =/  user-timezone=@t
    =/  tz-result  (mule |.((~(get-cage-as ba:tarball ball.state) /config 'timezone.txt' wain)))
    ?:  ?=(%| -.tz-result)  'UTC'
    =/  tz-wain=(unit wain)  p.tz-result
    ?~  tz-wain  'UTC'
    ?~  u.tz-wain  'UTC'
    i.u.tz-wain
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
    ;<  new-ball=ball:tarball  bind:m  (put-cage:io ball.state /config 'timezone.txt' [%txt !>(~[timezone])])
    =.  ball.state  new-ball
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
    =/  creds-jon=(unit json)  (get-claude-creds ball.state)
    ?~  creds-jon
      (fiber-fail:io leaf+"Claude credentials not configured" ~)
    =/  j  ~(. jo:json-utils u.creds-jon)
    =/  api-key=@t  (dog:j /api-key so:dejs:format)
    =/  ai-model=@t  (dog:j /ai-model so:dejs:format)
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
      [%master %ball ~]
    ::  Handle ball actions at root
    =/  action=@t  (need (get-key:kv 'action' args))
    ?+    action  (give-simple-payload:io [[400 ~] `(as-octs:mimes:html 'Unknown action')])
        %'create-folder'
      ;<  state=state-0  bind:m  (get-state-as:io state-0)
      =/  foldername=@ta  (rash (need (get-key:kv 'foldername' args)) sym)
      ;<  new-ball=ball:tarball  bind:m  (mkd:io ball.state /[foldername])
      =.  ball.state  new-ball
      ;<  ~  bind:m  (replace:io !>(state))
      (give-simple-payload:io [[303 ~[['location' '/master/ball']]] ~])
    ==
  ::
      [%master %ball *]
    ::  Handle ball actions in subdirectories
    ;<  state=state-0  bind:m  (get-state-as:io state-0)
    =/  ball-path=path  t.t.site
    =/  action=@t  (need (get-key:kv 'action' args))
    =/  redirect-url=tape  (weld "/master/ball" (trip (spat ball-path)))
    ?+    action  (give-simple-payload:io [[400 ~] `(as-octs:mimes:html 'Unknown action')])
        %'create-folder'
      =/  foldername=@ta  (rash (need (get-key:kv 'foldername' args)) sym)
      =/  dir-path=path  (snoc ball-path foldername)
      ;<  new-ball=ball:tarball  bind:m  (mkd:io ball.state dir-path)
      =.  ball.state  new-ball
      ;<  ~  bind:m  (replace:io !>(state))
      (give-simple-payload:io [[303 ~[['location' (crip redirect-url)]]] ~])
    ::
        %'create-symlink'
      =/  linkname=@ta  (rash (need (get-key:kv 'linkname' args)) sym)
      =/  target=@t  (need (get-key:kv 'target' args))
      =/  road=road:tarball  (need (parse-road:tarball target))
      ;<  new-ball=ball:tarball  bind:m  (put-symlink:io ball.state ball-path linkname road)
      =.  ball.state  new-ball
      ;<  ~  bind:m  (replace:io !>(state))
      (give-simple-payload:io [[303 ~[['location' (crip redirect-url)]]] ~])
    ::
        %'delete-file'
      =/  filename=@ta  (rash (need (get-key:kv 'filename' args)) sym)
      =.  ball.state  (~(del ba:tarball ball.state) ball-path filename)
      ;<  state=state-0  bind:m  (get-state-as:io state-0)
      ;<  ~  bind:m  (replace:io !>(state))
      (give-simple-payload:io [[303 ~[['location' (crip redirect-url)]]] ~])
    ::
        %'delete-folder'
      =/  foldername=@ta  (rash (need (get-key:kv 'foldername' args)) sym)
      ::  Delete the directory using tarball API
      =.  ball.state  (~(del ba:tarball ball.state) ball-path foldername)
      ;<  state=state-0  bind:m  (get-state-as:io state-0)
      ;<  ~  bind:m  (replace:io !>(state))
      (give-simple-payload:io [[303 ~[['location' (crip redirect-url)]]] ~])
    ==
  ==
--
