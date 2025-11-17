/+  io=sailboxio, sailbox, ui-ball, tarball, multipart, html-utils
=,  html-utils
|%
::  GET /master/ball and /master/ball/* - View ball browser
::
++  handle-get
  |=  $:  ball=ball:tarball
          =bowl:gall
          ball-path=(list @t)
          ext=(unit @t)
          args=(list [key=@t value=@t])
      ==
  =/  m  (fiber:io ,simple-payload:http)
  ^-  form:m
  ;<  conversions=(map mars:clay tube:clay)  bind:m  (get-mark-conversions:io ball)
  =/  =simple-payload:http
    %-  mime-response:sailbox
    (handle-ball-get:ui-ball ball bowl conversions ball-path [ext args])
  (pure:m simple-payload)
::
::  POST /master/ball and /master/ball/* - Handle file uploads (multipart)
::
++  handle-multipart-upload
  |=  $:  req=inbound-request:eyre
          ball-path=path
      ==
  =/  m  (fiber:io ,~)
  ^-  form:m
  ::  Parse multipart data
  =/  parts=(unit (list [@t part:multipart]))
    (de-request:multipart header-list.request.req body.request.req)
  ?~  parts
    (give-simple-payload:io [[400 ~] `(as-octs:mimes:html 'Invalid multipart data')])
  ;<  ball=ball:tarball  bind:m  get-state:io
  ;<  =bowl:gall  bind:m  get-bowl:io
  ;<  conversions=(map mars:clay tube:clay)  bind:m  (get-mark-conversions:io ball)
  :: TODO: need to add dais based on file extensions + mime, NOT already
  ::       existing in $ball
  ::
  ;<  dais-map=(map mark dais:clay)  bind:m  (get-mark-dais:io ball)
  ::  Update ball with uploaded files
  =/  new-ball=ball:tarball
    (from-parts:tarball ball ball-path u.parts now.bowl conversions dais-map)
  ;<  ~  bind:m  (replace:io new-ball)
  =/  redirect-url=tape
    ?~(ball-path "/master/ball" (weld "/master/ball" (trip (spat ball-path))))
  (give-simple-payload:io [[303 ~[['location' (crip redirect-url)]]] ~])
::
::  POST /master/ball/* - Handle form actions
::
++  handle-form-actions
  |=  $:  ball-path=path
          args=key-value-list:kv
      ==
  =/  m  (fiber:io ,~)
  ^-  form:m
  =/  action=@t  (need (get-key:kv 'action' args))
  =/  redirect-url=tape
    ?~(ball-path "/master/ball" (weld "/master/ball" (trip (spat ball-path))))
  ?+    action  (give-simple-payload:io [[400 ~] `(as-octs:mimes:html 'Unknown action')])
      %'create-folder'
    =/  foldername=@ta  (rash (need (get-key:kv 'foldername' args)) sym)
    =/  dir-path=path  (snoc ball-path foldername)
    ;<  ~  bind:m  (mkd:io dir-path)
    (give-simple-payload:io [[303 ~[['location' (crip redirect-url)]]] ~])
  ::
      %'create-symlink'
    =/  linkname=@ta  (rash (need (get-key:kv 'linkname' args)) sym)
    =/  target=@t  (need (get-key:kv 'target' args))
    =/  road=road:tarball  (need (parse-road:tarball target))
    ;<  ~  bind:m  (put-road:io ball-path linkname road)
    (give-simple-payload:io [[303 ~[['location' (crip redirect-url)]]] ~])
  ::
      %'delete-file'
    =/  filename=@t  (need (get-key:kv 'filename' args))
    ;<  ~  bind:m  (del:io ball-path filename)
    (give-simple-payload:io [[303 ~[['location' (crip redirect-url)]]] ~])
  ::
      %'delete-folder'
    =/  foldername=@t  (need (get-key:kv 'foldername' args))
    =/  folder-path=path  (snoc ball-path foldername)
    ;<  ~  bind:m  (lop:io folder-path)
    (give-simple-payload:io [[303 ~[['location' (crip redirect-url)]]] ~])
  ==
--
