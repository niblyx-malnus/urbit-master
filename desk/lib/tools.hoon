/-  *master
/+  io=sailboxio, telegram, pytz, random, time, sailbox, server
|%
::  Protocol-agnostic tool interface
::  This library provides a unified tool definition and execution layer
::  that can be consumed by different protocol adapters (MCP, Claude API, etc.)
::
::  Tool metadata and execution types
::
+$  tool-result
  $%  [%text text=@t]
      [%error message=@t]
  ==
::
+$  tool-handler  $-((map @t json) _*form:(fiber:io ,tool-result))
::
+$  parameter-type
  $?  %string
      %number
      %boolean
      %array
      %object
  ==
::
+$  parameter-def
  $:  type=parameter-type
      description=@t
  ==
::
+$  tool-def
  $:  name=@t
      description=@t
      parameters=(map @t parameter-def)
      required=(list @t)
      handler=tool-handler
  ==
::
::  Tool Registry - Single source of truth for all available tools
::
++  all-tools
  ^-  (list tool-def)
  :~  :*  'get_timezone'
          'Get the user configured timezone'
          ~
          ~
          tool-get-timezone
      ==
      :*  'get_ship'
          'Get the current ship name'
          ~
          ~
          tool-get-ship
      ==
      :*  'get_current_time'
          'Get the current time in a specified timezone'
          %-  ~(gas by *(map @t parameter-def))
          :~  :-  'timezone'
              ^-  parameter-def
              [%string 'Timezone name (e.g. America/New_York)']
          ==
          ~['timezone']
          tool-get-current-time
      ==
      :*  'get_random'
          'Generate random values: integers, floats, booleans, choices, UUIDs, bytes, or raw entropy'
          %-  ~(gas by *(map @t parameter-def))
          :~  :-  'type'
              ^-  parameter-def
              [%string 'Type: integer, float, boolean, choice, uuid, bytes, entropy']
              :-  'min'
              ^-  parameter-def
              [%number 'Minimum value for integer/float (optional)']
              :-  'max'
              ^-  parameter-def
              [%number 'Maximum value for integer/float (optional)']
              :-  'choices'
              ^-  parameter-def
              [%array 'Array of strings to choose from (for choice type)']
              :-  'count'
              ^-  parameter-def
              [%number 'Number of values to generate (default 1)']
              :-  'format'
              ^-  parameter-def
              [%string 'Output format: hex, base64 (for bytes type, optional)']
          ==
          ~['type']
          tool-get-random
      ==
      :*  'send_telegram'
          'Send a telegram notification'
          %-  ~(gas by *(map @t parameter-def))
          :~  :-  'message'
              ^-  parameter-def
              [%string 'Message to send']
          ==
          ~['message']
          tool-send-telegram
      ==
      :*  'schedule_telegram'
          'Schedule a telegram notification for a specific time or duration from now'
          %-  ~(gas by *(map @t parameter-def))
          :~  :-  'message'
              ^-  parameter-def
              [%string 'Message to send']
              :-  'time'
              ^-  parameter-def
              [%string 'Time in ISO format: YYYY-MM-DDTHH:MM:SS (optional if duration provided)']
              :-  'timezone'
              ^-  parameter-def
              [%string 'Timezone name (e.g. America/New_York) (optional if duration provided)']
              :-  'duration'
              ^-  parameter-def
              [%string 'ISO-8601 duration from now (e.g. PT5M for 5 minutes, PT2H for 2 hours, P1DT2H for 1 day 2 hours) (optional if time provided)']
          ==
          ~['message']
          tool-schedule-telegram
      ==
      :*  'rename_chat'
          'Rename the current chat conversation'
          %-  ~(gas by *(map @t parameter-def))
          :~  :-  'title'
              ^-  parameter-def
              [%string 'New title for the chat (3-5 words)']
          ==
          ~['title']
          tool-rename-chat
      ==
      :*  'web_search'
          'Search the web using Brave Search API and return relevant results with titles, URLs, and descriptions'
          %-  ~(gas by *(map @t parameter-def))
          :~  :-  'query'
              ^-  parameter-def
              [%string 'The search query']
              :-  'count'
              ^-  parameter-def
              [%number 'Number of results to return (default 5, max 20)']
          ==
          ~['query']
          tool-web-search
      ==
  ==
::
::  Tool execution interface
::
++  execute-tool
  |=  [name=@t arguments=(map @t json)]
  =/  m  (fiber:io ,tool-result)
  ^-  form:m
  ::  Find tool by name
  =/  tool=(unit tool-def)
    =/  tools-list=(list tool-def)  all-tools
    |-
    ?~  tools-list  ~
    ?:  =(name.i.tools-list name)
      `i.tools-list
    $(tools-list t.tools-list)
  ?~  tool
    (pure:m [%error (crip "Unknown tool: {(trip name)}")])
  ::  Execute the tool's handler
  (handler.u.tool arguments)
::
::  Tool implementations
::
++  tool-get-timezone
  ^-  tool-handler
  |=  arguments=(map @t json)
  =/  m  (fiber:io ,tool-result)
  ^-  form:m
  ;<  state=state-0  bind:m  (get-state-as:io state-0)
  (pure:m [%text user-timezone.state])
::
++  tool-get-ship
  ^-  tool-handler
  |=  arguments=(map @t json)
  =/  m  (fiber:io ,tool-result)
  ^-  form:m
  ;<  =bowl:gall  bind:m  get-bowl:io
  (pure:m [%text (scot %p our.bowl)])
::
++  tool-get-current-time
  ^-  tool-handler
  |=  arguments=(map @t json)
  =/  m  (fiber:io ,tool-result)
  ^-  form:m
  =/  tz-name=@t
    %.  [%o arguments]
    %-  ot:dejs:format
    :~  ['timezone' so:dejs:format]
    ==
  ;<  =bowl:gall  bind:m  get-bowl:io
  ::  Convert UTC now to timezone time
  =/  tz-time=(unit dext:pytz)
    (utc-to-tz:~(. zn:pytz tz-name) now.bowl)
  ?~  tz-time
    (pure:m [%error 'Invalid timezone'])
  ::  Format as human-readable datetime
  =/  tz-struct=date  (yore d.u.tz-time)
  =/  year=tape  (a-co:co y.tz-struct)
  =/  month=tape  (a-co:co m.tz-struct)
  =/  day=tape  (a-co:co d.t.tz-struct)
  =/  dow=@ud  (get-weekday:time d.u.tz-time)
  =/  weekday=tape
    ?+  dow  "???"
      %0  "Mon"
      %1  "Tue"
      %2  "Wed"
      %3  "Thu"
      %4  "Fri"
      %5  "Sat"
      %6  "Sun"
    ==
  =/  hour-24=@ud  h.t.tz-struct
  =/  minute=@ud   m.t.tz-struct
  =/  is-pm=?      (gte hour-24 12)
  =/  hour-12=@ud  ?:  =(hour-24 0)  12
                   ?:  (lte hour-24 12)  hour-24
                   (sub hour-24 12)
  =/  hour-str=tape  (numb:sailbox hour-12)
  =/  minute-str=tape
    ?:  (lth minute 10)
      (weld "0" (numb:sailbox minute))
    (numb:sailbox minute)
  =/  formatted=tape
    "{weekday} {year}-{month}-{day} {hour-str}:{minute-str}{?:(is-pm "pm" "am")} {(trip tz-name)}"
  (pure:m [%text (crip formatted)])
::
++  tool-get-random
  ^-  tool-handler
  |=  arguments=(map @t json)
  =/  m  (fiber:io ,tool-result)
  ^-  form:m
  ::  Parse required type parameter
  =/  type-str=@t
    %.  [%o arguments]
    %-  ot:dejs:format
    :~  ['type' so:dejs:format]
    ==
  ::  Convert type string to random-type
  =/  rand-type=random-type:random
    ?:  =(type-str 'integer')     %integer
    ?:  =(type-str 'float')       %float
    ?:  =(type-str 'boolean')     %boolean
    ?:  =(type-str 'choice')      %choice
    ?:  =(type-str 'uuid')        %uuid
    ?:  =(type-str 'bytes')       %bytes
    ?:  =(type-str 'entropy')     %entropy
    %integer  ::  default
  ::  Parse optional parameters
  =/  min-val=(unit @ud)
    =/  min-json=(unit json)  (~(get by arguments) 'min')
    ?~  min-json  ~
    ?.  ?=([%n *] u.min-json)  ~
    `(need (slaw %ud p.u.min-json))
  =/  max-val=(unit @ud)
    =/  max-json=(unit json)  (~(get by arguments) 'max')
    ?~  max-json  ~
    ?.  ?=([%n *] u.max-json)  ~
    `(need (slaw %ud p.u.max-json))
  =/  choices=(unit (list @t))
    =/  choices-json=(unit json)  (~(get by arguments) 'choices')
    ?~  choices-json  ~
    ?.  ?=([%a *] u.choices-json)  ~
    `(turn p.u.choices-json |=(j=json ?:(?=([%s *] j) p.j '')))
  =/  count=(unit @ud)
    =/  count-json=(unit json)  (~(get by arguments) 'count')
    ?~  count-json  ~
    ?.  ?=([%n *] u.count-json)  ~
    `(need (slaw %ud p.u.count-json))
  =/  format=(unit @t)
    =/  format-json=(unit json)  (~(get by arguments) 'format')
    ?~  format-json  ~
    ?.  ?=([%s *] u.format-json)  ~
    `p.u.format-json
  ::  Build request
  =/  request=random-request:random
    :*  rand-type
        min-val
        max-val
        choices
        count
        format
    ==
  ::  Generate random values
  ;<  result=random-result:random  bind:m  (generate:random request)
  ::  Use library's format-result function
  (pure:m [%text (format-result:random result)])
::
++  tool-send-telegram
  ^-  tool-handler
  |=  arguments=(map @t json)
  =/  m  (fiber:io ,tool-result)
  ^-  form:m
  =/  message=@t
    %.  [%o arguments]
    %-  ot:dejs:format
    :~  ['message' so:dejs:format]
    ==
  ;<  state=state-0  bind:m  (get-state-as:io state-0)
  ;<  ~  bind:m
    (send-message:telegram bot-token.telegram-creds.state chat-id.telegram-creds.state message)
  (pure:m [%text 'Telegram message sent'])
::
++  tool-schedule-telegram
  ^-  tool-handler
  |=  arguments=(map @t json)
  =/  m  (fiber:io ,tool-result)
  ^-  form:m
  ::  Parse required message
  =/  message=@t
    %.  [%o arguments]
    %-  ot:dejs:format
    :~  ['message' so:dejs:format]
    ==
  ::  Get optional time and duration
  =/  time-str=(unit @t)
    =/  time-json=(unit json)  (~(get by arguments) 'time')
    ?~  time-json  ~
    ?.  ?=([%s *] u.time-json)  ~
    `p.u.time-json
  =/  tz-name=(unit @t)
    =/  tz-json=(unit json)  (~(get by arguments) 'timezone')
    ?~  tz-json  ~
    ?.  ?=([%s *] u.tz-json)  ~
    `p.u.tz-json
  =/  duration-str=(unit @t)
    =/  dur-json=(unit json)  (~(get by arguments) 'duration')
    ?~  dur-json  ~
    ?.  ?=([%s *] u.dur-json)  ~
    `p.u.dur-json
  ::  Determine wake time
  ;<  =bowl:gall  bind:m  get-bowl:io
  =/  wake-time=(unit @da)
    ?^  duration-str
      ::  Parse duration and add to current time
      =/  dur=(unit @dr)  (parse-duration:telegram u.duration-str)
      ?~  dur
        ~
      `(add now.bowl u.dur)
    ?^  time-str
      ::  Parse absolute time with timezone
      ?.  ?=([~ *] tz-name)
        ~
      (parse-schedule-time:telegram u.time-str u.tz-name)
    ::  No valid time specification
    ~
  ?~  wake-time
    (pure:m [%error 'Invalid time specification. Provide either duration or time+timezone'])
  ;<  state=state-0  bind:m  (get-state-as:io state-0)
  ::  Create alarm
  =/  alarm-id=@da  u.wake-time
  =/  alarm=telegram-alarm
    :*  id=alarm-id
        message=message
        wake-time=u.wake-time
    ==
  ::  Update state with new alarm
  =.  telegram-alarms.state  (~(put by telegram-alarms.state) alarm-id alarm)
  ;<  ~  bind:m  (replace:io !>(state))
  ::  Schedule the alarm fiber
  ;<  ~  bind:m
    %:  fiber-throw:io
      (crip "alarm-{(scow %da alarm-id)}")
      spawn-alarm+!>([alarm-id alarm])
    ==
  (pure:m [%text 'Telegram message scheduled'])
::
++  tool-rename-chat
  ^-  tool-handler
  |=  arguments=(map @t json)
  =/  m  (fiber:io ,tool-result)
  ^-  form:m
  =/  title=@t
    %.  [%o arguments]
    %-  ot:dejs:format
    :~  ['title' so:dejs:format]
    ==
  ::  Extract chat-id from _chat_id argument
  =/  chat-id=(unit @ux)
    =/  chat-id-json=(unit json)  (~(get by arguments) '_chat_id')
    ?~  chat-id-json  ~
    ?.  ?=([%s *] u.chat-id-json)  ~
    (slaw %ux p.u.chat-id-json)
  ?~  chat-id
    (pure:m [%error 'No chat context provided'])
  ::  Update chat name in state
  ;<  state=state-0  bind:m  (get-state-as:io state-0)
  =/  chat=(unit claude-chat)  (~(get by claude-chats.state) u.chat-id)
  ?~  chat
    (pure:m [%error 'Chat not found'])
  ::  Update the chat's name
  =/  updated-chat=claude-chat  u.chat(name title)
  =.  claude-chats.state  (~(put by claude-chats.state) u.chat-id updated-chat)
  ;<  ~  bind:m  (replace:io !>(state))
  ::  Send SSE event
  ;<  ~  bind:m
    (send-sse-event:io /master/claude/stream/(crip (hexn:sailbox u.chat-id)) ~ `%title-update)
  (pure:m [%text 'Chat renamed'])
::
++  tool-web-search
  ^-  tool-handler
  |=  arguments=(map @t json)
  =/  m  (fiber:io ,tool-result)
  ^-  form:m
  ::  Parse query
  =/  query=@t
    %.  [%o arguments]
    %-  ot:dejs:format
    :~  ['query' so:dejs:format]
    ==
  ::  Parse optional count (default 5, max 20)
  =/  count=@ud
    =/  count-json=(unit json)  (~(get by arguments) 'count')
    ?~  count-json  5
    ?.  ?=([%n *] u.count-json)  5
    =/  parsed=(unit @ud)  (slaw %ud p.u.count-json)
    ?~  parsed  5
    ?:  (gth u.parsed 20)  20
    u.parsed
  ::  Get Brave Search API key from state
  ;<  state=state-0  bind:m  (get-state-as:io state-0)
  =/  api-key=@t  api-key.brave-search-creds.state
  ::  Build request URL
  =/  url=tape
    %+  weld  "https://api.search.brave.com/res/v1/web/search?q="
    %+  weld  (trip query)
    "&count={(a-co:co count)}"
  =/  =request:http
    :*  %'GET'
        (crip url)
        :~  ['X-Subscription-Token' api-key]
            ['Accept' 'application/json']
        ==
        ~
    ==
  ::  Send request
  ;<  ~  bind:m  (send-request:io request)
  ;<  =client-response:iris  bind:m  take-client-response:io
  ;<  body=cord  bind:m  (extract-body:io client-response)
  ::  Parse JSON response
  =/  jon=(unit json)  (de:json:html body)
  ?~  jon
    (pure:m [%error 'Failed to parse search results'])
  ::  Extract results
  =/  results
    %-  mule
    |.
    %.  u.jon
    %-  ot:dejs:format
    :~  :-  'web'
        %-  ot:dejs:format
        :~  :-  'results'
            %-  ar:dejs:format
            %-  ot:dejs:format
            :~  ['title' so:dejs:format]
                ['url' so:dejs:format]
                ['description' so:dejs:format]
            ==
        ==
    ==
  ?:  ?=(%| -.results)
    (pure:m [%error 'Failed to parse search results'])
  ::  Format results as text
  =/  results-list=(list [title=@t url=@t description=@t])  p.results
  =/  formatted=tape
    %-  zing
    %+  turn  results-list
    |=  [title=@t url=@t desc=@t]
    ;:  weld
      (trip title)
      "\0a"
      (trip url)
      "\0a"
      (trip desc)
      "\0a\0a"
    ==
  (pure:m [%text (crip formatted)])
--
