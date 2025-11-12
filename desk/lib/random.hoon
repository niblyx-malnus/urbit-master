/-  *master
/+  io=sailboxio
|%
::  Random value types
::
+$  random-type
  $?  %integer
      %float
      %boolean
      %choice
      %uuid
      %bytes
      %entropy
  ==
::
+$  random-request
  $:  type=random-type
      min=(unit @ud)           ::  for integer/float
      max=(unit @ud)           ::  for integer/float
      choices=(unit (list @t)) ::  for choice
      count=(unit @ud)         ::  how many values (default 1)
      format=(unit @t)         ::  output format: 'hex', 'base64', etc
  ==
::
+$  random-result
  $%  [%single value=@t]
      [%multiple values=(list @t)]
  ==
::
::  Generate random value
::
++  generate
  |=  req=random-request
  =/  m  (fiber:io ,random-result)
  ^-  form:m
  ;<  eny=@uvJ  bind:m  get-entropy:io
  =/  rng  ~(. og eny)
  =/  num-values=@ud  (fall count.req 1)
  ?:  =(num-values 1)
    ;<  val=@t  bind:m  (generate-single req rng)
    (pure:m [%single val])
  ::  Generate multiple values
  =|  results=(list @t)
  =|  i=@ud
  |-  ^-  form:m
  ?:  (gte i num-values)
    (pure:m [%multiple (flop results)])
  ;<  val=@t  bind:m  (generate-single req rng)
  ::  Get new entropy for next iteration
  ;<  eny=@uvJ  bind:m  get-entropy:io
  =.  rng  ~(. og eny)
  $(i +(i), results [val results])
::
::  Generate a single random value
::
++  generate-single
  |=  [req=random-request rng=_og]
  =/  m  (fiber:io ,@t)
  ^-  form:m
  ?-  type.req
      %entropy
    ;<  eny=@uvJ  bind:m  get-entropy:io
    (pure:m (scot %uv eny))
  ::
      %boolean
    =/  [val=@ new-rng=_og]  (rads:rng 2)
    (pure:m ?:(=(val 0) 'false' 'true'))
  ::
      %integer
    =/  min=@ud  (fall min.req 0)
    =/  max=@ud  (fall max.req 100)
    =/  range=@ud  ?:((lte max min) 1 (sub +(max) min))
    =/  [val=@ new-rng=_og]  (rads:rng range)
    =/  result=@ud  (add min val)
    (pure:m (crip (scow %ud result)))
  ::
      %float
    ::  Generate float as integer then divide
    =/  min=@ud  (fall min.req 0)
    =/  max=@ud  (fall max.req 100)
    =/  range=@ud  ?:((lte max min) 1 (sub +(max) min))
    =/  [val=@ new-rng=_og]  (rads:rng (mul range 1.000))
    =/  float-val=@rd  (sun:rd (add (mul min 1.000) val))
    =/  divided=@rd  (div:rd float-val (sun:rd 1.000))
    (pure:m (crip (scow %rd divided)))
  ::
      %choice
    ?~  choices.req
      (pure:m 'error: no choices provided')
    =/  choice-list=(list @t)  u.choices.req
    =/  num-choices=@ud  (lent choice-list)
    ?:  =(num-choices 0)
      (pure:m 'error: empty choices')
    =/  [idx=@ new-rng=_og]  (rads:rng num-choices)
    (pure:m (snag idx choice-list))
  ::
      %uuid
    ::  Generate UUIDv4
    ;<  eny=@uvJ  bind:m  get-entropy:io
    =/  uuid-hex=tape  (scow %ux eny)
    ::  Format as UUID: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
    =/  formatted=tape
      =/  raw=tape  (scag 32 (weld uuid-hex (reap 32 '0')))
      ;:  weld
        (scag 8 raw)
        "-"
        (scag 4 (slag 8 raw))
        "-4"
        (scag 3 (slag 13 raw))
        "-"
        (scag 4 (slag 16 raw))
        "-"
        (slag 20 raw)
      ==
    (pure:m (crip formatted))
  ::
      %bytes
    ;<  eny=@uvJ  bind:m  get-entropy:io
    ?~  format.req
      (pure:m (scot %ux eny))
    ?:  =(u.format.req 'hex')
      (pure:m (scot %ux eny))
    ?:  =(u.format.req 'base64')
      ::  Simple base64-like encoding (simplified)
      (pure:m (scot %uw eny))
    (pure:m (scot %ux eny))
  ==
::
::  Helper to format result as text
::
++  format-result
  |=  res=random-result
  ^-  @t
  ?-  -.res
    %single  value.res
    %multiple  (crip (join ", " (turn values.res trip)))
  ==
::
::  Join tape list with separator
::
++  join
  |=  [sep=tape lst=(list tape)]
  ^-  tape
  ?~  lst  ~
  ?~  t.lst  i.lst
  (weld i.lst (weld sep $(lst t.lst)))
--
