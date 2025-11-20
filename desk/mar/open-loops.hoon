/+  open-loops
|_  =loops:open-loops
++  grab
  |%
  ++  noun  loops:open-loops
  ++  json  dejs-loops:open-loops
  ++  mime
    |=  [=mite p=octs]
    ^-  loops:open-loops
    (json (need (de:json:html q.p)))
  --
++  grow
  |%
  ++  noun  loops
  ++  json  (enjs-loops:open-loops loops)
  ++  mime
    [/application/json (as-octs:mimes:html (en:json:html json))]
  --
++  grad  %noun
--
