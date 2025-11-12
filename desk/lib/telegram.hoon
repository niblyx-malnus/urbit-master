/-  *master
/+  io=sailboxio, pytz
|%
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
++  restart-alarms
  |=  alarms=(map @da telegram-alarm)
  =/  m  (fiber:io ,~)
  ^-  form:m
  ;<  =bowl:gall  bind:m  get-bowl:io
  =/  alarms-list=(list [id=@da alarm=telegram-alarm])
    ~(tap by alarms)
  =|  idx=@ud
  |-  ^-  form:m
  ?~  alarms-list  (pure:m ~)
  =/  [alarm-id=@da =telegram-alarm]  i.alarms-list
  ::  Only restart if wake-time is in the future
  ?:  (lth wake-time.telegram-alarm now.bowl)
    ::  Alarm already passed, skip it
    $(alarms-list t.alarms-list, idx +(idx))
  ::  Fire-and-forget spawn alarm fiber
  ;<  ~  bind:m
    %:  fiber-throw:io
      (crip "alarm-{(scow %ud idx)}")
      spawn-alarm+!>([alarm-id telegram-alarm])
    ==
  $(alarms-list t.alarms-list, idx +(idx))
--
