/+  server, multipart, sailbox, html-utils, tarball
=|  hold=_| :: switch to interleave vs sequentialize processes
|%
++  fiber  fiber:fiber:sailbox
++  input  input:fiber:sailbox
::
++  send-raw-cards
  |=  cards=(list card:sailbox)
  =/  m  (fiber ,~)
  ^-  form:m
  |=  input
  [cards state %done ~]
::
++  send-raw-card
  |=  =card:sailbox
  =/  m  (fiber ,~)
  ^-  form:m
  (send-raw-cards card ~)
::
++  fiber-fail
  |=  err=tang
  |=  input
  [~ state %fail err]
::
++  get-state
  =/  m  (fiber ,ball:tarball)
  ^-  form:m
  |=  input
  [~ state %done state]
::
++  replace
  |=  new=ball:tarball
  =/  m  (fiber ,~)
  ^-  form:m
  |=  input
  ^-  output:m
  [~ new %done ~]
::
++  get-bowl
  =/  m  (fiber ,bowl:gall)
  ^-  form:m
  |=  input
  [~ state %done bowl]
::
++  get-beak
  =/  m  (fiber ,beak)
  ^-  form:m
  |=  input
  [~ state %done byk.bowl]
::
++  get-desk
  =/  m  (fiber ,desk)
  ^-  form:m
  |=  input
  [~ state %done q.byk.bowl]
::
++  get-case
  =/  m  (fiber ,case)
  ^-  form:m
  |=  input
  [~ state %done r.byk.bowl]
::
++  get-time
  =/  m  (fiber ,@da)
  ^-  form:m
  |=  input
  [~ state %done now.bowl]
::
++  get-our
  =/  m  (fiber ,ship)
  ^-  form:m
  |=  input
  [~ state %done our.bowl]
::
++  get-agent
  =/  m  (fiber ,dude:gall)
  ^-  form:m
  |=  input
  [~ state %done dap.bowl]
::
++  get-entropy
  =/  m  (fiber ,@uvJ)
  ^-  form:m
  |=  input
  [~ state %done eny.bowl]
::
++  get-guest
  =/  m  (fiber ,ship)
  ^-  form:m
  |=  input
  [~ state %done src.bowl]
::
++  get-provenance
  =/  m  (fiber ,path)
  ^-  form:m
  |=  input
  [~ state %done sap.bowl]
::
++  get-pid
  =/  m  (fiber ,@ta)
  ^-  form:m
  |=  input
  [~ state %done pid]
::
++  get-poke
  =/  m  (fiber ,cage)
  ^-  form:m
  |=  input
  [~ state %done cage.poke]
::
++  get-poke-guest
  =/  m  (fiber ,ship)
  ^-  form:m
  |=  input
  [~ state %done src.poke]
::
++  get-poke-provenance
  =/  m  (fiber ,path)
  ^-  form:m
  |=  input
  [~ state %done sap.poke]
::
++  get-poke-fresh
  =/  m  (fiber ,?)
  ^-  form:m
  |=  input
  [~ state %done fresh.poke]
::
++  soften
  |*  a=mold
  =/  m  (fiber ,a)
  =/  m-e  (fiber ,(each a tang))
  |=  =form:m
  ^-  form:m-e
  |=  tin=input
  =/  res  (form tin)
  %=    res
      next
    ?+  -.next.res  next.res
      %cont  [%cont ^$(form self.next.res)]
      %fail  [%done %| err.next.res]
      %done  [%done %& value.next.res]
    ==
  ==
::
++  unit-soften
  |*  a=mold
  =/  m  (fiber ,a)
  =/  m-u  (fiber ,(unit a))
  |=  =form:m
  ^-  form:m-u
  |=  tin=input
  =/  res  (form tin)
  %=    res
      next
    ?+  -.next.res  next.res
      %cont  [%cont ^$(form self.next.res)]
      %fail  [%done ~]
      %done  [%done ~ value.next.res]
    ==
  ==
::
++  take-bump
  =/  m  (fiber ,cage)
  ^-  form:m
  |=  input
  :+  ~  state
  ?+  in  [%skip hold]
     ~             [%wait hold]
    [~ %bump @ *]  [%done cage.u.in]
  ==
::
++  take-poke-ack
  |=  =wire
  =/  m  (fiber ,~)
  ^-  form:m
  |=  input
  :+  ~  state
  ?+  in  [%skip hold]
      ~  [%wait hold]
      [~ %agent * %poke-ack *]
    ?.  =(wire wire.u.in)
      [%skip hold]
    ?~  p.sign.u.in
      [%done ~]
    [%fail %poke-fail u.p.sign.u.in]
  ==
::
++  take-watch-ack
  |=  =wire
  =/  m  (fiber ,~)
  ^-  form:m
  |=  input
  :+  ~  state
  ?+  in  [%skip hold]
      ~  [%wait hold]
      [~ %agent * %watch-ack *]
    ?.  =(watch+wire wire.u.in)
      [%skip hold]
    ?~  p.sign.u.in
      [%done ~]
    [%fail %watch-ack-fail u.p.sign.u.in]
  ==
::  Wait for a subscription update on a wire
::
++  take-fact
  |=  =wire
  =/  m  (fiber ,cage)
  ^-  form:m
  |=  input
  :+  ~  state
  ?+  in  [%skip hold]
      ~  [%wait hold]
      [~ %agent * %fact *]
    ?.  =(watch+wire wire.u.in)
      [%skip hold]
    [%done cage.sign.u.in]
  ==
::  Wait for a subscription close
::
++  take-kick
  |=  =wire
  =/  m  (fiber ,~)
  ^-  form:m
  |=  input
  :+  ~  state
  ?+  in  [%skip hold]
      ~  [%wait hold]
      [~ %agent * %kick *]
    ?.  =(watch+wire wire.u.in)
      [%skip hold]
    [%done ~]
  ==
::
++  watch
  |=  [=wire =dock =path]
  =/  m  (fiber ,~)
  ^-  form:m
  =/  =card:agent:gall  [%pass watch+wire %agent dock %watch path]
  ;<  ~  bind:m  (send-raw-card card)
  (take-watch-ack wire)
::
++  watch-one
  |=  [=wire =dock =path]
  =/  m  (fiber ,cage)
  ^-  form:m
  ;<  ~  bind:m  (watch wire dock path)
  ;<  =cage  bind:m  (take-fact wire)
  ;<  ~  bind:m  (take-kick wire)
  (pure:m cage)
::
++  watch-our
  |=  [=wire =term =path]
  =/  m  (fiber ,~)
  ^-  form:m
  ;<  our=@p  bind:m  get-our
  (watch wire [our term] path)
::
++  scry
  |*  [=mold =path]
  =/  m  (fiber ,mold)
  ^-  form:m
  ?>  ?=(^ path)
  ?>  ?=(^ t.path)
  ;<  =bowl:gall  bind:m  get-bowl
  %-  pure:m
  .^(mold i.path (scot %p our.bowl) i.t.path (scot %da now.bowl) t.t.path)
::
++  get-all-bindings
  =/  m  (fiber ,(list [binding:eyre duct action:eyre]))
  ^-  form:m
  (scry ,(list [binding:eyre duct action:eyre]) %e /bindings)
::
++  get-our-bindings
  =/  m  (fiber ,(list binding:eyre))
  ^-  form:m
  ;<  bindings=(list [binding:eyre duct action:eyre])  bind:m  get-all-bindings
  ;<  =bowl:gall  bind:m  get-bowl
  %-  pure:m
  %+  murn  bindings
  |=  [=binding:eyre =duct =action:eyre]
  ^-  (unit binding:eyre)
  ?.  ?=(%app -.action)
    ~
  ?.  =(app.action dap.bowl)
    ~
  `binding
::
++  take-eyre-bound
  |=  =wire
  =/  m  (fiber ,~)
  ^-  form:m
  |=  input
  :+  ~  state
  ?+  in  [%skip hold]
      ~  [%wait hold]
      [~ %arvo * %eyre %bound *]
    ?.  =(wire wire.u.in)
      [%skip hold]
    ?:  accepted.sign.u.in
      [%done ~]
    [%fail leaf+"eyre bind failed on wire {(spud wire)} with binding {<binding.sign.u.in>}" ~]
  ==
::
++  eyre-connect
  |=  [=binding:eyre app=term]
  =/  m  (fiber ,~)
  ^-  form:m
  =/  =card:agent:gall
    [%pass /eyre/connect %arvo %e %connect binding app]
  ;<  ~  bind:m  (send-raw-card card)
  (take-eyre-bound /eyre/connect)
::
++  eyre-disconnect
  |=  =binding:eyre
  =/  m  (fiber ,~)
  ^-  form:m
  %-  send-raw-card
  :: NOTE: wire must be same as connecting for identical duct
  [%pass /eyre/connect %arvo %e %disconnect binding]
::
++  add-bindings
  |=  bindings=(list binding:eyre)
  =/  m  (fiber ,~)
  ^-  form:m
  ;<  =bowl:gall  bind:m  get-bowl
  |-  ^-  form:m
  ?~  bindings
    (pure:m ~)
  ;<  ~  bind:m  (eyre-connect i.bindings dap.bowl)
  $(bindings t.bindings)
::
++  set-bindings
  |=  desired=(list binding:eyre)
  =/  m  (fiber ,~)
  ^-  form:m
  ::  connect to all desired bindings (overwrites any from other ducts)
  ;<  ~  bind:m  (add-bindings desired)
  ;<  current=(list binding:eyre)  bind:m  get-our-bindings
  ::  disconnect from bindings not in desired list
  =/  to-disconnect=(list binding:eyre)
    %+  skip  current
    |=  =binding:eyre
    (~(has in (~(gas in *(set binding:eyre)) desired)) binding)
  ;<  ~  bind:m  (add-bindings to-disconnect)
  |-  ^-  form:m
  ?~  to-disconnect
    (pure:m ~)
  ;<  ~  bind:m  (eyre-disconnect i.to-disconnect)
  $(to-disconnect t.to-disconnect)
::
++  clear-bindings
  |=  bindings=(list binding:eyre)
  =/  m  (fiber ,~)
  ^-  form:m
  ;<  =bowl:gall  bind:m  get-bowl
  ::  connect first to overwrite any bindings from other ducts
  ;<  ~  bind:m  (add-bindings bindings)
  ::  now disconnect
  |-  ^-  form:m
  ?~  bindings
    (pure:m ~)
  ;<  ~  bind:m  (eyre-disconnect i.bindings)
  $(bindings t.bindings)
::
++  clear-all-bindings
  =/  m  (fiber ,~)
  ^-  form:m
  ;<  current=(list binding:eyre)  bind:m  get-our-bindings
  (clear-bindings current)
::
++  leave
  |=  [=wire =dock]
  =/  m  (fiber ,~)
  ^-  form:m
  =/  =card:agent:gall  [%pass watch+wire %agent dock %leave ~]
  (send-raw-card card)
::
++  leave-our
  |=  [=wire =term]
  =/  m  (fiber ,~)
  ^-  form:m
  ;<  our=@p  bind:m  get-our
  (leave wire [our term])
::
++  poke
  |=  [=dock =cage]
  =/  m  (fiber ,~)
  ^-  form:m
  =/  =card:agent:gall  [%pass /poke %agent dock %poke cage]
  ;<  ~  bind:m  (send-raw-card card)
  (take-poke-ack /poke)
::
++  fiber-bump
  |=  [pid=@ta bump=cage]
  =/  m  (fiber ,~)
  ^-  form:m
  ;<  =bowl:gall  bind:m  get-bowl
  (poke [our dap]:bowl fiber-bump+!>([pid bump]))
::
++  fiber-kill
  |=  pid=@ta
  =/  m  (fiber ,~)
  ^-  form:m
  ;<  =bowl:gall  bind:m  get-bowl
  (poke [our dap]:bowl fiber-kill+!>(pid))
::
++  fiber-poke
  |=  [sfx=@ta foke=cage]
  =/  m  (fiber ,~)
  ^-  form:m
  ;<  pid=@ta  bind:m  get-pid
  =/  nid=@ta  (rap 3 pid '_' sfx ~)
  ;<  =bowl:gall  bind:m  get-bowl
  =/  =dock  [our dap]:bowl
  ;<  ~  bind:m  (watch /fiber-result dock /fiber-result/[nid])
  ;<  ~  bind:m  (poke dock fiber-poke+!>([nid foke]))
  ;<  res=cage  bind:m  (take-fact /fiber-result)
  ;<  ~  bind:m  (take-kick /fiber-result)
  ?>  ?=(%fiber-ack p.res)
  =+  !<(err=(unit tang) q.res)
  ?~  err
    (pure:m ~)
  (fiber-fail u.err)
::
++  fiber-throw
  |=  [sfx=@ta foke=cage]
  =/  m  (fiber ,~)
  ^-  form:m
  ;<  pid=@ta  bind:m  get-pid
  =/  nid=@ta  (rap 3 pid '_' sfx ~)
  ;<  =bowl:gall  bind:m  get-bowl
  =/  =dock  [our dap]:bowl
  (poke dock fiber-poke+!>([nid foke]))
::
++  give-simple-payload
  |=  payload=simple-payload:http
  =/  m  (fiber ,~)
  ^-  form:m
  (send-raw-card %simple-payload payload)
::
++  send-sse-event
  |=  [site=(list @t) =sse-key:sailbox]
  =/  m  (fiber ,~)
  ^-  form:m
  (send-raw-card %sse site ~ sse-key)
::
++  send-sse-events
  |=  [site=(list @t) keys=(list sse-key:sailbox)]
  =/  m  (fiber ,~)
  ^-  form:m
  %-  send-raw-cards
  %+  turn  keys
  |=  =sse-key:sailbox
  [%sse site ~ sse-key]
::
++  send-wait
  |=  until=@da
  =/  m  (fiber ,~)
  ^-  form:m
  %-  send-raw-card
  [%pass /wait/(scot %da until) %arvo %b %wait until]
::
++  wait
  |=  until=@da
  =/  m  (fiber ,~)
  ^-  form:m
  ;<  ~  bind:m  (send-wait until)
  (take-wake `until)
::
++  mass
  =/  m  (fiber ,(list quac:dill))
  ^-  form:m
  =/  =card:agent:gall  [%pass /mass %arvo %d %mass ~]
  ;<  ~  bind:m  (send-raw-card card)
  ;<  quz=(list quac:dill)  bind:m  take-meme
  (pure:m quz)
::
++  take-meme
  =/  m  (fiber ,(list quac:dill))
  ^-  form:m
  |=  input
  :+  ~  state
  ?+  in  [%skip hold]
    ~  [%wait hold]
      [~ %arvo [%mass ~] %dill %meme *]
    [%done p.sign.u.in]
  ==
::
++  take-wake
  |=  until=(unit @da)
  =/  m  (fiber ,~)
  ^-  form:m
  |=  input
  :+  ~  state
  ?+  in  [%skip hold]
    ~  [%wait hold]
      [~ %arvo [%wait @ ~] %behn %wake *]
    ?.  |(?=(~ until) =(`u.until (slaw %da i.t.wire.u.in)))
      [%skip hold]
    ?~  error.sign.u.in
      [%done ~]
    [%fail leaf+"timer-error" u.error.sign.u.in]
  ==
::
++  sleep
  |=  for=@dr
  =/  m  (fiber ,~)
  ^-  form:m
  ;<  now=@da  bind:m  get-time
  (wait (add now for))
::
++  backoff
  |=  [try=@ud limit=@dr]
  =/  m  (fiber ,~)
  ^-  form:m
  ;<  eny=@uvJ  bind:m  get-entropy
  %-  sleep
  %+  min  limit
  ?:  =(0 try)  ~s0
  %+  add
    (mul ~s1 (bex (dec try)))
  (mul ~s0..0001 (~(rad og eny) 1.000))
::
++  retry
  |*  result=mold
  |=  [crash-after=(unit @ud) computation=_*form:(fiber result)]
  =/  m  (fiber ,result)
  =|  try=@ud
  |-
  ^-  form:m
  ?:  =(crash-after `try)
    (fiber-fail %retry-too-many ~)
  ;<  ~                  bind:m  (backoff try ~m1)
  ;<  res=(unit result)  bind:m  ((unit-soften ,result) computation)
  ?~  res
    $(try +(try))
  (pure:m u.res)
::
++  send-request
  |=  =request:http
  =/  m  (fiber ,~)
  ^-  form:m
  (send-raw-card %pass /request %arvo %i %request request *outbound-config:iris)
::
++  send-cancel-request
  =/  m  (fiber ,~)
  ^-  form:m
  (send-raw-card %pass /request %arvo %i %cancel-request ~)
::
++  take-client-response
  =/  m  (fiber ,client-response:iris)
  ^-  form:m
  |=  input
  :+  ~  state
  ?+  in  [%skip hold]
      ~  [%wait hold]
    ::
      [~ %arvo [%request ~] %iris %http-response %cancel *]
    ::NOTE  iris does not (yet?) retry after cancel, so it means failure
    :+  %fail
      leaf+"http-request-cancelled"
    ['http request was cancelled by the runtime']~
    ::
      [~ %arvo [%request ~] %iris %http-response %finished *]
    [%done client-response.sign.u.in]
  ==
::
++  extract-body
  |=  =client-response:iris
  =/  m  (fiber ,cord)
  ^-  form:m
  ?>  ?=(%finished -.client-response)
  %-  pure:m
  ?~  full-file.client-response  ''
  q.data.u.full-file.client-response
::
++  fetch-cord
  |=  url=tape
  =/  m  (fiber ,cord)
  ^-  form:m
  =/  =request:http  [%'GET' (crip url) ~ ~]
  ;<  ~                      bind:m  (send-request request)
  ;<  =client-response:iris  bind:m  take-client-response
  (extract-body client-response)
::
++  fetch-json
  |=  url=tape
  =/  m  (fiber ,json)
  ^-  form:m
  ;<  =cord  bind:m  (fetch-cord url)
  =/  json=(unit json)  (de:json:html cord)
  ?~  json
    (fiber-fail leaf+"json-parse-error" ~)
  (pure:m u.json)
::    ----
::
::  Output
::
++  flog
  |=  =flog:dill
  =/  m  (fiber ,~)
  ^-  form:m
  (send-raw-card %pass / %arvo %d %flog flog)
::
++  flog-text
  |=  =tape
  =/  m  (fiber ,~)
  ^-  form:m
  (flog %text tape)
::
++  flog-tang
  |=  =tang
  =/  m  (fiber ,~)
  ^-  form:m
  =/  =wall
    (zing (turn (flop tang) (cury wash [0 80])))
  |-  ^-  form:m
  ?~  wall
    (pure:m ~)
  ;<  ~  bind:m  (flog-text i.wall)
  $(wall t.wall)
::
++  trace
  |=  =tang
  =/  m  (fiber ,~)
  ^-  form:m
  (pure:m ((slog tang) ~))
::  Take Clay read result
::
++  take-writ
  |=  =wire
  =/  m  (fiber ,riot:clay)
  ^-  form:m
  |=  input
  :+  ~  state
  ?+  in  [%skip hold]
      ~  [%wait hold]
      [~ %arvo * ?(%behn %clay) %writ *]
    ?.  =(wire wire.u.in)
      [%skip hold]
    [%done +>.sign.u.in]
  ==
::  Read from Clay
::
++  warp
  |=  [=ship =riff:clay]
  =/  m  (fiber ,riot:clay)
  ;<  ~  bind:m  (send-raw-card %pass /warp %arvo %c %warp ship riff)
  (take-writ /warp)
::
++  build-file
  |=  [[=ship =desk =case] =spur]
  =*  arg  +<
  =/  m  (fiber ,(unit vase))
  ^-  form:m
  ;<  =riot:clay  bind:m
    (warp ship desk ~ %sing %a case spur)
  ?~  riot
    (pure:m ~)
  ?>  =(%vase p.r.u.riot)
  (pure:m (some !<(vase q.r.u.riot)))
::
++  build-file-hard
  |=  [[=ship =desk =case] =spur]
  =*  arg  +<
  =/  m  (fiber ,vase)
  ^-  form:m
  ;<    =riot:clay
      bind:m
    (warp ship desk ~ %sing %a case spur)
  ?>  ?=(^ riot)
  ?>  ?=(%vase p.r.u.riot)
  (pure:m !<(vase q.r.u.riot))
::  +build-mark: build a mark definition to a $dais
::
++  build-mark
  |=  [[=ship =desk =case] mak=mark]
  =*  arg  +<
  =/  m  (fiber ,dais:clay)
  ^-  form:m
  ;<  =riot:clay  bind:m
    (warp ship desk ~ %sing %b case /[mak])
  ?~  riot
    (fiber-fail leaf+<['build-mark' arg]> ~)
  ?>  =(%dais p.r.u.riot)
  (pure:m !<(dais:clay q.r.u.riot))
::
++  build-mark-soft
  |=  [[=ship =desk =case] mak=mark]
  =/  m  (fiber ,(unit dais:clay))
  ^-  form:m
  ;<  =riot:clay  bind:m
    (warp ship desk ~ %sing %b case /[mak])
  ?~  riot
    (pure:m ~)
  ?>  =(%dais p.r.u.riot)
  (pure:m `!<(dais:clay q.r.u.riot))
::  +try-build-dais: build a mark dais, trying our desk first then %base
::
++  try-build-dais
  |=  mak=mark
  =/  m  (fiber ,(unit dais:clay))
  ^-  form:m
  ;<  our=@p  bind:m  get-our
  ;<  =desk  bind:m  get-desk
  ;<  now=@da  bind:m  get-time
  ;<  dais=(unit dais:clay)  bind:m
    (build-mark-soft [our desk [%da now]] mak)
  ?^  dais
    (pure:m dais)
  (build-mark-soft [our %base [%da now]] mak)
::  +build-tube: build a mark conversion gate ($tube)
::
++  build-tube
  |=  [[=ship =desk =case] =mars:clay]
  =*  arg  +<
  =/  m  (fiber ,tube:clay)
  ^-  form:m
  ;<  =riot:clay  bind:m
    (warp ship desk ~ %sing %c case /[a.mars]/[b.mars])
  ?~  riot
    (fiber-fail leaf+<['build-tube' arg]> ~)
  ?>  =(%tube p.r.u.riot)
  (pure:m !<(tube:clay q.r.u.riot))
::
++  build-tube-soft
  |=  [[=ship =desk =case] =mars:clay]
  =/  m  (fiber ,(unit tube:clay))
  ^-  form:m
  ;<  =riot:clay  bind:m
    (warp ship desk ~ %sing %c case /[a.mars]/[b.mars])
  ?~  riot
    (pure:m ~)
  ?>  =(%tube p.r.u.riot)
  (pure:m `!<(tube:clay q.r.u.riot))
::
::  +build-nave: build a mark definition to a $nave
::
++  build-nave
  |=  [[=ship =desk =case] mak=mark]
  =*  arg  +<
  =/  m  (fiber ,vase)
  ^-  form:m
  ;<  =riot:clay  bind:m
    (warp ship desk ~ %sing %e case /[mak])
  ?~  riot
    (fiber-fail leaf+<['build-nave' arg]> ~)
  ?>  =(%nave p.r.u.riot)
  (pure:m q.r.u.riot)
::  +build-cast: build a mark conversion gate (static)
::
++  build-cast
  |=  [[=ship =desk =case] =mars:clay]
  =*  arg  +<
  =/  m  (fiber ,vase)
  ^-  form:m
  ;<  =riot:clay  bind:m
    (warp ship desk ~ %sing %f case /[a.mars]/[b.mars])
  ?~  riot
    (fiber-fail leaf+<['build-cast' arg]> ~)
  ?>  =(%cast p.r.u.riot)
  (pure:m q.r.u.riot)
::
++  read-file
  |=  [[=ship =desk =case] =spur]
  =*  arg  +<
  =/  m  (fiber ,cage)
  ;<  =riot:clay  bind:m  (warp ship desk ~ %sing %x case spur)
  ?~  riot
    (fiber-fail leaf+<['read-file' arg]> ~)
  (pure:m r.u.riot)
::
++  check-for-file
  |=  [[=ship =desk =case] =spur]
  =/  m  (fiber ,?)
  ;<  =riot:clay  bind:m  (warp ship desk ~ %sing %u case spur)
  ?>  ?=(^ riot)
  (pure:m !<(? q.r.u.riot))
::
++  list-tree
  |=  [[=ship =desk =case] =spur]
  =*  arg  +<
  =/  m  (fiber ,(list path))
  ;<  =riot:clay  bind:m  (warp ship desk ~ %sing %t case spur)
  ?~  riot
    (fiber-fail leaf+<['list-tree' arg]> ~)
  (pure:m !<((list path) q.r.u.riot))
::
++  list-desk
  |=  [[=ship =desk =case] =spur]
  =*  arg  +<
  =/  m  (fiber ,arch)
  ;<  =riot:clay  bind:m  (warp ship desk ~ %sing %y case spur)
  ?~  riot
    (fiber-fail leaf+<['list-desk' arg]> ~)
  (pure:m !<(arch q.r.u.riot))
::  +get-dais-map: build a dais map for a single mark
::
++  get-dais-map
  |=  =mark
  =/  m  (fiber ,(map ^mark dais:clay))
  ^-  form:m
  ;<  our=@p  bind:m  get-our
  ;<  =desk  bind:m  get-desk
  ;<  now=@da  bind:m  get-time
  ;<  dais=(unit dais:clay)  bind:m
    (build-mark-soft [our desk [%da now]] mark)
  =/  dais-map=(map ^mark dais:clay)
    ?~  dais  ~
    (~(gas by *(map ^mark dais:clay)) ~[[mark u.dais]])
  (pure:m dais-map)
::  +put-cage: put a cage into ball with validation and timestamp
::
++  put-cage
  |=  [pax=path name=@ta c=cage]
  =/  m  (fiber ,~)
  ^-  form:m
  ;<  b=ball:tarball  bind:m  get-state
  ::  Inline dais-map building
  ;<  our=@p  bind:m  get-our
  ;<  =desk  bind:m  get-desk
  ;<  now=@da  bind:m  get-time
  ;<  dais=(unit dais:clay)  bind:m
    (build-mark-soft [our desk [%da now]] p.c)
  =/  dais-map=(map mark dais:clay)
    ?~  dais  ~
    (~(gas by *(map mark dais:clay)) ~[[p.c u.dais]])
  =/  ba  (~(das ba:tarball b) dais-map)
  ::  Build metadata with mtime
  =/  meta=metadata:tarball
    %-  ~(gas by *(map @t @t))
    :~  ['mtime' (da-oct:tarball now)]
    ==
  =/  content=content:tarball  [meta %& c]
  (replace (put:ba pax name content))
::  +mkd: make a directory in ball with timestamp
::
++  mkd
  |=  pax=path
  =/  m  (fiber ,~)
  ^-  form:m
  ;<  b=ball:tarball  bind:m  get-state
  ;<  now=@da  bind:m  get-time
  ::  Build metadata with mtime
  =/  meta=metadata:tarball
    %-  ~(gas by *(map @t @t))
    :~  ['mtime' (da-oct:tarball now)]
    ==
  (replace (~(mkd ba:tarball b) pax meta))
::  +put-file: put a file into ball with timestamp
::
++  put-file
  |=  [pax=path name=@ta =mime]
  =/  m  (fiber ,~)
  ^-  form:m
  ;<  b=ball:tarball  bind:m  get-state
  ;<  now=@da  bind:m  get-time
  ::  Build metadata with mtime and size
  =/  meta=metadata:tarball
    %-  ~(gas by *(map @t @t))
    :~  ['mtime' (da-oct:tarball now)]
        ['size' (scot %ud p.q.mime)]
    ==
  =/  content=content:tarball  [meta %& [%mime !>(mime)]]
  (replace (~(put ba:tarball b) pax name content))
::  +put-symlink: put a symlink into ball with timestamp
::
++  put-symlink
  |=  [pax=path name=@ta =road:tarball]
  =/  m  (fiber ,~)
  ^-  form:m
  ;<  b=ball:tarball  bind:m  get-state
  ;<  now=@da  bind:m  get-time
  ::  Build metadata with mtime
  =/  meta=metadata:tarball
    %-  ~(gas by *(map @t @t))
    :~  ['mtime' (da-oct:tarball now)]
    ==
  =/  content=content:tarball  [meta %| road]
  (replace (~(put ba:tarball b) pax name content))
::  +diff-file: compute diff between two versions of a file
::
++  diff-file
  |=  [b=ball:tarball pax=path name=@ta mak=mark old=vase new=vase]
  =/  m  (fiber ,vase)
  ^-  form:m
  ;<  dais=(unit dais:clay)  bind:m  (try-build-dais mak)
  ?~  dais
    (fiber-fail leaf+"mark {<mak>} not found" ~)
  (pure:m (~(diff u.dais old) new))
::  +patch-file: apply a diff to a file in the ball
::
++  patch-file
  |=  [pax=path name=@ta diff=vase]
  =/  m  (fiber ,~)
  ^-  form:m
  ;<  b=ball:tarball  bind:m  get-state
  ::  Get current file to determine its mark
  =/  ba  (~(das ba:tarball b) ~)
  =/  current=(unit content:tarball)  (get:ba pax name)
  ?~  current
    (fiber-fail leaf+"file not found: {<pax>}/{<name>}" ~)
  ?.  ?=(%.y -.data.u.current)
    (fiber-fail leaf+"file is not a cage: {<pax>}/{<name>}" ~)
  ::  Build dais for the mark (try our desk, then %base)
  ;<  dais=(unit dais:clay)  bind:m  (try-build-dais p.p.data.u.current)
  ?~  dais
    (fiber-fail leaf+"mark {<p.p.data.u.current>} not found" ~)
  ::  Apply patch using tarball
  (replace (patch-cage:ba pax name diff u.dais))
--
