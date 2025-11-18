/-  *master
/+  io=sailboxio, json-utils, tarball
|%
::  Simple recurrence rule for repeating alarms
+$  recurrence-rule
  $:  start-time=@da
      count=@ud
      interval=@dr
      active=?
  ==
::
::  Get the nth occurrence from a recurrence rule
++  get-occurrence
  |=  [rule=recurrence-rule index=@ud]
  ^-  @da
  (add start-time.rule (mul interval.rule index))
::
::  Build initial alarm JSON structure
++  build-alarm-json
  |=  $:  wake-time=@da
          tool-name=@t
          tool-arguments=json
          created=@da
          repeat-count=@ud
          interval=@dr
          active=?
      ==
  ^-  json
  %-  pairs:enjs:format
  :~  ['wake-time' s+(scot %da wake-time)]
      ['tool-name' s+tool-name]
      ['tool-arguments' tool-arguments]
      ['created' s+(scot %da created)]
      ['timer-set' b+%.n]
      ['repeat-count' (numb:enjs:format repeat-count)]
      ['interval' s+(scot %dr interval)]
      ['current-index' (numb:enjs:format 0)]
      ['active' b+active]
  ==
::
::  Initialize alarm state - creates process file if it doesn't exist
++  init-alarm-state
  |=  $:  wake-time=@da
          tool-name=@t
          tool-arguments=json
          repeat-count=@ud
          interval=@dr
          active=?
      ==
  =/  m  (fiber:io ,~)
  ^-  form:m
  ;<  ball=ball:tarball  bind:m  get-state:io
  ::  Check if already exists in ball
  =/  ba  ~(. ba:tarball ball)
  =/  filename=@ta  (crip "{(scow %da wake-time)}.json")
  =/  existing=(unit content:tarball)  (get:ba /processes/alarms filename)
  ?^  existing
    (pure:m ~)
  ::  Create initial alarm JSON
  ;<  now=@da  bind:m  get-time:io
  =/  jon=json  (build-alarm-json wake-time tool-name tool-arguments now repeat-count interval active)
  (put-cage:io /processes/alarms filename [%json !>(jon)])
::
::  Cleanup alarm state - delete process file
++  cleanup-alarm-state
  |=  wake-time=@da
  =/  m  (fiber:io ,~)
  ^-  form:m
  ;<  ball=ball:tarball  bind:m  get-state:io
  =/  ba  ~(. ba:tarball ball)
  =/  filename=@ta  (crip "{(scow %da wake-time)}.json")
  =/  new-ball=ball:tarball  (del:ba /processes/alarms filename)
  (replace:io new-ball)
::
::  Check if timer has been set for this alarm
++  timer-already-set
  |=  process-id=@da
  =/  m  (fiber:io ,?)
  ^-  form:m
  ;<  ball=ball:tarball  bind:m  get-state:io
  =/  filename=@ta  (crip "{(scow %da process-id)}.json")
  =/  jon=json
    (~(got-cage-as ba:tarball ball) /processes/alarms filename json)
  (pure:m (~(dog jo:json-utils jon) /timer-set bo:dejs:format))
::
::  Mark timer as set and send behn timer
++  set-timer
  |=  [process-id=@da wake-time=@da]
  =/  m  (fiber:io ,~)
  ^-  form:m
  ;<  ball=ball:tarball  bind:m  get-state:io
  =/  filename=@ta  (crip "{(scow %da process-id)}.json")
  =/  jon=json
    (~(got-cage-as ba:tarball ball) /processes/alarms filename json)
  ::  Mark timer as set
  =/  updated-jon=json  (~(put jo:json-utils jon) /timer-set b+%.y)
  ;<  ~  bind:m  (put-cage:io /processes/alarms filename [%json !>(updated-jon)])
  ::  Send the timer card
  (send-raw-card:io %pass /alarm-wake %arvo %b %wait wake-time)
::
::  Raw fiber continuation - wait for behn wake
++  take-alarm-wake
  |=  input:fiber:io
  ?+  in  [~ state %skip |]
    ~  [~ state %wait |]
    [~ %arvo [%alarm-wake ~] %behn %wake *]  [~ state %done ~]
  ==
::
::  Wait for alarm wake-time
++  wait-for-alarm
  |=  [process-id=@da wake-time=@da]
  =/  m  (fiber:io ,~)
  ^-  form:m
  ;<  already-set=?  bind:m  (timer-already-set process-id)
  ;<  ~  bind:m
    ?:  already-set
      (pure:m ~)
    (set-timer process-id wake-time)
  take-alarm-wake
::
::  Run the alarm fiber - waits until wake time, executes scheduled tool
++  run-alarm
  |=  [rule=recurrence-rule tool-name=@t tool-arguments=json]
  =/  m  (fiber:io ,~)
  ^-  form:m
  ;<  ~  bind:m  (init-alarm-state start-time.rule tool-name tool-arguments count.rule interval.rule active.rule)
  ::  Read alarm state
  ;<  ball=ball:tarball  bind:m  get-state:io
  ::  Read current index from alarm state (for restart resilience)
  =/  filename=@ta  (crip "{(scow %da start-time.rule)}.json")
  =/  jon=json
    (~(got-cage-as ba:tarball ball) /processes/alarms filename json)
  =/  start-index=@ud
    =/  maybe-index=(unit @ud)
      (bind (~(get jo:json-utils jon) /current-index) ni:dejs:format)
    (fall maybe-index 0)
  ::  Loop through repetitions starting from saved index
  =/  index=@ud  start-index
  |-  ^-  form:m
  ?:  =(index count.rule)
    ::  Done with all repetitions
    ;<  ~  bind:m  (cleanup-alarm-state start-time.rule)
    (pure:m ~)
  ::  Calculate wake time for this occurrence using the recurrence rule
  =/  wake-time=@da  (get-occurrence rule index)
  ;<  ~  bind:m  (wait-for-alarm start-time.rule wake-time)
  ::  Only execute tool if alarm is active
  ;<  ~  bind:m
    ?:  active.rule
      ::  Launch tool execution in a new fiber
      (fiber-poke:io (scot %da wake-time) %execute-scheduled-tool !>([tool-name tool-arguments]))
    (pure:m ~)
  ::  Update current-index and reset timer-set flag for next iteration
  ;<  ball=ball:tarball  bind:m  get-state:io
  =/  filename=@ta  (crip "{(scow %da start-time.rule)}.json")
  =/  jon=json
    (~(got-cage-as ba:tarball ball) /processes/alarms filename json)
  =/  updated-jon=json
    %-  ~(put jo:json-utils jon)
    :-  /current-index
    (numb:enjs:format +(index))
  =/  updated-jon=json
    (~(put jo:json-utils updated-jon) /timer-set b+%.n)
  ;<  ~  bind:m  (put-cage:io /processes/alarms filename [%json !>(updated-jon)])
  ::  Continue to next iteration
  $(index +(index))
--
