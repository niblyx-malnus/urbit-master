/+  regex, iso-8601
|%
::  Types
::
+$  loop
  $:  text=@t
      labels=(set @t)
      created=@da
      updated=@da
      best-by=(unit @da)
  ==
::
+$  loops
  $:  next-id=@ud
      open=(map @ud loop)
      closed=(map @ud loop)
  ==
::  Core operations
::
++  lo
  |_  =loops
  ++  open
    |=  [text=@t labels=(set @t) now=@da best-by=(unit @da)]
    ^+  loops
    =/  =loop  [text labels now now best-by]
    :*  +(next-id.loops)
        (~(put by open.loops) next-id.loops loop)
        closed.loops
    ==
  ::
  ++  close
    |=  [id=@ud now=@da]
    ^+  loops
    =/  =loop  (~(got by open.loops) id)
    =.  updated.loop  now
    :*  next-id.loops
        (~(del by open.loops) id)
        (~(put by closed.loops) id loop)
    ==
  ::
  ++  reopen
    |=  [id=@ud now=@da]
    ^+  loops
    =/  =loop  (~(got by closed.loops) id)
    =.  updated.loop  now
    :*  next-id.loops
        (~(put by open.loops) id loop)
        (~(del by closed.loops) id)
    ==
  ::
  ++  update-text
    |=  [id=@ud new-text=@t now=@da]
    ^+  loops
    ?:  in-open=(~(has by open.loops) id)
      =/  existing=loop  (~(got by open.loops) id)
      =/  updated=loop  existing(text new-text, updated now)
      loops(open (~(put by open.loops) id updated))
    =/  existing=loop  (~(got by closed.loops) id)
    =/  updated=loop  existing(text new-text, updated now)
    loops(closed (~(put by closed.loops) id updated))
  ::
  ++  update-labels
    |=  [id=@ud new-labels=(set @t) now=@da]
    ^+  loops
    ?:  in-open=(~(has by open.loops) id)
      =/  existing=loop  (~(got by open.loops) id)
      =/  updated=loop  existing(labels new-labels, updated now)
      loops(open (~(put by open.loops) id updated))
    =/  existing=loop  (~(got by closed.loops) id)
    =/  updated=loop  existing(labels new-labels, updated now)
    loops(closed (~(put by closed.loops) id updated))
  ::
  ++  add-label
    |=  [id=@ud label=@t now=@da]
    ^+  loops
    ?:  in-open=(~(has by open.loops) id)
      =/  existing=loop  (~(got by open.loops) id)
      =/  updated=loop  existing(labels (~(put in labels.existing) label), updated now)
      loops(open (~(put by open.loops) id updated))
    =/  existing=loop  (~(got by closed.loops) id)
    =/  updated=loop  existing(labels (~(put in labels.existing) label), updated now)
    loops(closed (~(put by closed.loops) id updated))
  ::
  ++  remove-label
    |=  [id=@ud label=@t now=@da]
    ^+  loops
    ?:  in-open=(~(has by open.loops) id)
      =/  existing=loop  (~(got by open.loops) id)
      =/  updated=loop  existing(labels (~(del in labels.existing) label), updated now)
      loops(open (~(put by open.loops) id updated))
    =/  existing=loop  (~(got by closed.loops) id)
    =/  updated=loop  existing(labels (~(del in labels.existing) label), updated now)
    loops(closed (~(put by closed.loops) id updated))
  ::
  ++  remove-labels
    |=  [id=@ud labels=(set @t) now=@da]
    ^+  loops
    ?:  in-open=(~(has by open.loops) id)
      =/  existing=loop  (~(got by open.loops) id)
      =/  updated=loop  existing(labels (~(dif in labels.existing) labels), updated now)
      loops(open (~(put by open.loops) id updated))
    =/  existing=loop  (~(got by closed.loops) id)
    =/  updated=loop  existing(labels (~(dif in labels.existing) labels), updated now)
    loops(closed (~(put by closed.loops) id updated))
  ::
  ++  delete-loop
    |=  id=@ud
    ^+  loops
    loops(closed (~(del by closed.loops) id))
  ::
  ++  update-best-by
    |=  [id=@ud new-best-by=(unit @da) now=@da]
    ^+  loops
    =/  in-open=?  (~(has by open.loops) id)
    ?:  in-open
      =/  existing=loop  (~(got by open.loops) id)
      =/  updated=loop  existing(best-by new-best-by, updated now)
      loops(open (~(put by open.loops) id updated))
    =/  existing=loop  (~(got by closed.loops) id)
    =/  updated=loop  existing(best-by new-best-by, updated now)
    loops(closed (~(put by closed.loops) id updated))
  ::  Batch operations
  ::
  ++  batch-open
    |=  [specs=(list [text=@t labels=(set @t) best-by=(unit @da)]) now=@da]
    ^+  loops
    =/  current=^loops  loops
    |-  ^+  loops
    ?~  specs  current
    =/  updated=^loops  (~(open lo current) text.i.specs labels.i.specs now best-by.i.specs)
    $(specs t.specs, current updated)
  ::
  ++  batch-close
    |=  [ids=(list @ud) now=@da]
    ^+  loops
    =/  current=^loops  loops
    |-  ^+  loops
    ?~  ids  current
    =/  updated=^loops  (~(close lo current) i.ids now)
    $(ids t.ids, current updated)
  ::
  ++  batch-reopen
    |=  [ids=(list @ud) now=@da]
    ^+  loops
    =/  current=^loops  loops
    |-  ^+  loops
    ?~  ids  current
    =/  updated=^loops  (~(reopen lo current) i.ids now)
    $(ids t.ids, current updated)
  ::
  ++  batch-delete
    |=  ids=(list @ud)
    ^+  loops
    =/  current=^loops  loops
    |-  ^+  loops
    ?~  ids  current
    =/  updated=^loops  (~(delete-loop lo current) i.ids)
    $(ids t.ids, current updated)
  ::
  ++  batch-update-labels
    |=  [ids=(list @ud) new-labels=(set @t) now=@da]
    ^+  loops
    ?~  ids
      loops
    %=  $
      ids    t.ids
      loops  (update-labels i.ids new-labels now)
    ==
  ::
  ++  batch-add-label
    |=  [ids=(list @ud) label=@t now=@da]
    ^+  loops
    =/  current=^loops  loops
    |-  ^+  loops
    ?~  ids  current
    =/  updated=^loops  (~(add-label lo current) i.ids label now)
    $(ids t.ids, current updated)
  ::
  ++  batch-remove-label
    |=  [ids=(list @ud) label=@t now=@da]
    ^+  loops
    =/  current=^loops  loops
    |-  ^+  loops
    ?~  ids  current
    =/  updated=^loops  (~(remove-label lo current) i.ids label now)
    $(ids t.ids, current updated)
  ::
  ++  batch-add-labels
    |=  [ids=(list @ud) labels=(set @t) now=@da]
    ^+  loops
    =/  current=^loops  loops
    |-  ^+  loops
    ?~  ids  current
    =/  updated=^loops  (add-labels-to-one current i.ids labels now)
    $(ids t.ids, current updated)
  ::
  ++  add-labels-to-one
    |=  [lops=^loops id=@ud labels=(set @t) now=@da]
    ^+  lops
    =/  label-list=(list @t)  ~(tap in labels)
    |-  ^+  lops
    ?~  label-list  lops
    =/  added=^loops  (~(add-label lo lops) id i.label-list now)
    $(label-list t.label-list, lops added)
  ::
  ++  batch-remove-labels
    |=  [ids=(list @ud) labels=(set @t) now=@da]
    ^+  loops
    ?~  ids
      loops
    %=  $
      ids    t.ids
      loops  (remove-labels i.ids labels now)
    ==
  ::  Query helpers
  ::
  ++  get-loop
    |=  id=@ud
    ^-  (unit [? loop])
    ?^  in-open=(~(get by open.loops) id)
      `[%.y u.in-open]
    ?~  in-closed=(~(get by closed.loops) id)
      ~
    `[%.n u.in-closed]
  ::
  ++  list-open
    ^-  (list [@ud loop])
    %+  sort  ~(tap by open.loops)
    |=  [a=[@ud loop] b=[@ud loop]]
    (gth updated.+.a updated.+.b)
  ::
  ++  list-closed
    ^-  (list [@ud loop])
    %+  sort  ~(tap by closed.loops)
    |=  [a=[@ud loop] b=[@ud loop]]
    (gth updated.+.a updated.+.b)
  ::
  ++  filter-by-label
    |=  [loop-list=(list [@ud loop]) label=@t]
    ^-  (list [@ud loop])
    %+  skim  loop-list
    |=([id=@ud =loop] (~(has in labels.loop) label))
  ::
  ++  filter-by-age
    |=  [loop-list=(list [@ud loop]) cutoff=@da]
    ^-  (list [@ud loop])
    %+  skim  loop-list
    |=([id=@ud =loop] (lth created.loop cutoff))
  ::
  ++  filter-stale
    |=  [loop-list=(list [@ud loop]) cutoff=@da]
    ^-  (list [@ud loop])
    %+  skim  loop-list
    |=([id=@ud =loop] (lth updated.loop cutoff))
  ::
  ++  filter-past-best-by
    |=  [loop-list=(list [@ud loop]) now=@da]
    ^-  (list [@ud loop])
    %+  skim  loop-list
    |=  [id=@ud =loop]
    ?~  best-by.loop  %.n
    (gth now u.best-by.loop)
  ::
  ++  sort-by-urgency
    ::  Sort loops by distance to best-by (negative = overdue, positive = time remaining)
    ::  Loops without best-by are excluded
    |=  [loop-list=(list [@ud loop]) now=@da]
    ^-  (list [@ud loop])
    =/  with-best-by=(list [@ud loop])
      %+  skim  loop-list
      |=([id=@ud =loop] ?=(^ best-by.loop))
    %+  sort  with-best-by
    |=  [a=[@ud loop] b=[@ud loop]]
    =/  dist-a=@dr
      ?~  best-by.+.a  *@dr
      (sub u.best-by.+.a now)
    =/  dist-b=@dr
      ?~  best-by.+.b  *@dr
      (sub u.best-by.+.b now)
    (lth dist-a dist-b)
  ::
  ++  cleanup-old-closed
    |=  cutoff=@da
    ^+  loops
    =/  fresh=(map @ud loop)
      %-  ~(gas by *(map @ud loop))
      %+  skim  ~(tap by closed.loops)
      |=([id=@ud =loop] (gth updated.loop cutoff))
    loops(closed fresh)
  ::
  ::  Regex search helpers
  ::
  ++  search-text
    |=  [loop-list=(list [@ud loop]) pattern=@t]
    ^-  (list [@ud loop])
    %+  skim  loop-list
    |=  [id=@ud =loop]
    ?=(^ (rut:regex (trip pattern) (trip text.loop)))
  ::
  ++  search-labels
    |=  [loop-list=(list [@ud loop]) pattern=@t]
    ^-  (list [@ud loop])
    %+  skim  loop-list
    |=  [id=@ud =loop]
    =/  label-list=(list @t)  ~(tap in labels.loop)
    |-  ^-  ?
    ?~  label-list  %.n
    ?:  ?=(^ (rut:regex (trip pattern) (trip i.label-list)))
      %.y
    $(label-list t.label-list)
  ::
  ++  find-by-text
    |=  pattern=@t
    ^-  (list [@ud loop])
    =/  all-loops=(list [@ud loop])
      (weld ~(tap by open.loops) ~(tap by closed.loops))
    (search-text all-loops pattern)
  ::
  ++  search-fuzzy
    |=  [query=@t case-sensitive=?]
    ^-  (list [@ud loop])
    =/  pattern=@t
      ?:  case-sensitive
        query
      (crip "(?i){(trip query)}")
    (find-by-text pattern)
  --
::  JSON conversions
::
++  enjs-loop
  |=  lop=loop
  ^-  json
  :-  %o
  %-  ~(gas by *(map @t json))
  :~  ['text' [%s text.lop]]
      :-  'labels'
      [%a (turn ~(tap in labels.lop) |=(l=@t [%s l]))]
      ['created' [%s (crip (en:datetime-local:iso-8601 created.lop))]]
      ['updated' [%s (crip (en:datetime-local:iso-8601 updated.lop))]]
      :-  'best_by'
      ?~  best-by.lop  ~
      [%s (crip (en:date-input:iso-8601 [[%.y y] m d.t]:(yore u.best-by.lop)))]
  ==
::
++  enjs-loops
  |=  lops=loops
  ^-  json
  :-  %o
  %-  ~(gas by *(map @t json))
  :~  ['next_id' [%n (crip (a-co:co next-id.lops))]]
      :-  'open'
      :-  %o
      %-  ~(gas by *(map @t json))
      %+  turn  ~(tap by open.lops)
      |=([id=@ud lop=loop] [(crip (a-co:co id)) (enjs-loop lop)])
      :-  'closed'
      :-  %o
      %-  ~(gas by *(map @t json))
      %+  turn  ~(tap by closed.lops)
      |=([id=@ud lop=loop] [(crip (a-co:co id)) (enjs-loop lop)])
  ==
::
++  dejs-loop
  =,  dejs:format
  %-  ot
  :~  ['text' so]
      :-  'labels'
      |=  j=json
      ^-  (set @t)
      (~(gas in *(set @t)) ((ar so) j))
      :-  'created'
      |=  j=json
      (de:datetime-local:iso-8601 (so j))
      :-  'updated'
      |=  j=json
      (de:datetime-local:iso-8601 (so j))
      :-  'best_by'
      |=  j=json
      ^-  (unit @da)
      ?~  j  ~
      =/  [[a=? y=@ud] m=@ud d=@ud]  (de:date-input:iso-8601 (so j))
      `(year [a y] m d 0 0 0 ~)
  ==
::
++  dejs-loops
  =,  dejs:format
  %-  ot
  :~  ['next_id' ni]
      :-  'open'
      (op (full (cook |=(a=@ `@ud`a) dem)) dejs-loop)
      :-  'closed'
      (op (full (cook |=(a=@ `@ud`a) dem)) dejs-loop)
  ==
--
