/-  *master
/+  io=sailboxio, pytz, json-utils, tarball
|%
::  Build initial alarm JSON structure
++  build-alarm-json
  |=  [wake-time=@da message=@t created=@da]
  ^-  json
  %-  pairs:enjs:format
  :~  ['wake-time' s+(scot %da wake-time)]
      ['message' s+message]
      ['created' s+(scot %da created)]
      ['timer-set' b+%.n]
  ==
::
::  Parse ISO-8601 duration format (e.g. PT5M, PT2H30M, P1DT2H)
++  parse-duration
  |=  dur-str=@t
  ^-  (unit @dr)
  =/  parsed=(unit [d=@ud time=[h=@ud m=@ud s=@ud]])
    (rush dur-str parse-duration-rule)
  ?~  parsed  ~
  `(compile-duration u.parsed)
::
++  parse-duration-rule
  ;~  pfix
    (just 'P')
    ;~  plug
      ;~  pose
        ;~(sfix dem (just 'D'))
        (easy 0)
      ==
      ;~  pose
        ;~  pfix
          (just 'T')
          ;~  plug
            ;~  pose
              ;~(sfix dem (just 'H'))
              (easy 0)
            ==
            ;~  pose
              ;~(sfix dem (just 'M'))
              (easy 0)
            ==
            ;~  pose
              ;~(sfix dem (just 'S'))
              (easy 0)
            ==
          ==
        ==
        (easy [0 0 0])
      ==
    ==
  ==
::
++  compile-duration
  |=  [d=@ud h=@ud m=@ud s=@ud]
  ^-  @dr
  :(add (mul d ~d1) (mul h ~h1) (mul m ~m1) (mul s ~s1))
::
++  parse-schedule-time
  |=  [time-str=@t tz-name=@t]
  ^-  (unit @da)
  ::  Parse ISO datetime using pytz's existing parser
  =/  tz-time=(unit @da)  (rush time-str parse-datetime:pytz)
  ?~  tz-time  ~
  ::  Convert from timezone to UTC
  =/  utc-time
    %-  mule
    |.
    (universalize:~(. zn:pytz tz-name) u.tz-time)
  ?.  ?=(%& -.utc-time)  ~
  `p.utc-time
::
++  send-message
  |=  [bot-token=@t chat-id=@t message=@t]
  =/  m  (fiber:io ,~)
  ^-  form:m
  =/  url=tape
    %+  weld  "https://api.telegram.org/bot"
    %+  weld  (trip bot-token)
    "/sendMessage"
  =/  body=@t
    %+  rap  3
    :~  'chat_id='
        chat-id
        '&text='
        message
    ==
  =/  body-octs=octs  (as-octs:mimes:html body)
  =/  =request:http
    :*  %'POST'
        (crip url)
        ~[['content-type' 'application/x-www-form-urlencoded']]
        `body-octs
    ==
  ;<  ~  bind:m  (send-request:io request)
  ;<  =client-response:iris  bind:m  take-client-response:io
  (pure:m ~)
::
::  Initialize alarm state - creates process file if it doesn't exist
++  init-alarm-state
  |=  [wake-time=@da message=@t]
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
  =/  jon=json  (build-alarm-json wake-time message now)
  (put-cage:io /processes/alarms filename [%json !>(jon)])
::
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
::  Run the alarm fiber - waits until wake time, sends, cleans up
++  run-alarm
  |=  [wake-time=@da message=@t]
  =/  m  (fiber:io ,~)
  ^-  form:m
  ;<  ~  bind:m  (init-alarm-state wake-time message)
  ;<  ~  bind:m  (wait-for-alarm wake-time)
  ;<  ball=ball:tarball  bind:m  get-state:io
  =/  creds=json
    (~(got-cage-as ba:tarball ball) /config/creds 'telegram.json' json)
  =/  bot-token=@t  (~(dog jo:json-utils creds) /bot-token so:dejs:format)
  =/  chat-id=@t  (~(dog jo:json-utils creds) /chat-id so:dejs:format)
  ;<  ~  bind:m  (send-message bot-token chat-id message)
  ;<  ~  bind:m  (cleanup-alarm-state wake-time)
  (pure:m ~)
::
::  Check if timer has been set for this alarm
++  timer-already-set
  |=  wake-time=@da
  =/  m  (fiber:io ,?)
  ^-  form:m
  ;<  ball=ball:tarball  bind:m  get-state:io
  =/  filename=@ta  (crip "{(scow %da wake-time)}.json")
  =/  jon=json
    (~(got-cage-as ba:tarball ball) /processes/alarms filename json)
  (pure:m (~(dog jo:json-utils jon) /timer-set bo:dejs:format))
::
::  Mark timer as set and send behn timer
++  set-timer
  |=  wake-time=@da
  =/  m  (fiber:io ,~)
  ^-  form:m
  ;<  ball=ball:tarball  bind:m  get-state:io
  =/  filename=@ta  (crip "{(scow %da wake-time)}.json")
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
  |=  wake-time=@da
  =/  m  (fiber:io ,~)
  ^-  form:m
  ;<  already-set=?  bind:m  (timer-already-set wake-time)
  ;<  ~  bind:m
    ?:  already-set
      (pure:m ~)
    (set-timer wake-time)
  take-alarm-wake
--
