/-  claude
/+  io=sailboxio, telegram, pytz, random, time, sailbox, server, tarball, json-utils, alarms, open-loops, iso-8601
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
      :*  'create_alarm'
          'Schedule any MCP tool to execute at a specific time or duration from now, with optional repeating'
          %-  ~(gas by *(map @t parameter-def))
          :~  :-  'tool_name'
              ^-  parameter-def
              [%string 'Name of the MCP tool to execute (e.g. send_telegram, web_search)']
              :-  'tool_arguments'
              ^-  parameter-def
              [%object 'JSON object containing arguments for the tool']
              :-  'time'
              ^-  parameter-def
              [%string 'Time in ISO format: YYYY-MM-DDTHH:MM:SS (optional if duration provided)']
              :-  'timezone'
              ^-  parameter-def
              [%string 'Timezone name (e.g. America/New_York) (optional if duration provided)']
              :-  'duration'
              ^-  parameter-def
              [%string 'ISO-8601 duration from now (e.g. PT5M for 5 minutes, PT2H for 2 hours, P1DT2H for 1 day 2 hours) (optional if time provided)']
              :-  'repeat_count'
              ^-  parameter-def
              [%number 'Number of times to repeat the tool execution (optional, defaults to 1)']
              :-  'interval'
              ^-  parameter-def
              [%string 'ISO-8601 duration between repeats (e.g. PT5M for 5 minutes) (required if repeat_count > 1)']
          ==
          ~['tool_name' 'tool_arguments']
          tool-create-alarm
      ==
      :*  'rename_chat'
          'Rename a chat conversation'
          %-  ~(gas by *(map @t parameter-def))
          :~  :-  'title'
              ^-  parameter-def
              [%string 'New title for the chat (3-5 words)']
              :-  'chat_id'
              ^-  parameter-def
              [%string 'Chat ID in hex format (e.g. 0x1234.5678)']
          ==
          ~['title' 'chat_id']
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
      :*  'commit'
          'Commit a mounted desk and return version info with logs'
          %-  ~(gas by *(map @t parameter-def))
          :~  :-  'mount_point'
              ^-  parameter-def
              [%string 'Mount point name (e.g. "base")']
              :-  'timeout_seconds'
              ^-  parameter-def
              [%number 'Timeout in seconds to wait for logs (default: 30)']
          ==
          ~['mount_point']
          tool-commit
      ==
      :*  'desk_version'
          'Get the current version of a mounted desk'
          %-  ~(gas by *(map @t parameter-def))
          :~  :-  'mount_point'
              ^-  parameter-def
              [%string 'Mount point name (e.g. "base")']
          ==
          ~['mount_point']
          tool-desk-version
      ==
      :*  'list_loop_contexts'
          'List all available open-loops contexts (e.g. urbit, learning, personal)'
          ~
          ~
          tool-list-loop-contexts
      ==
      :*  'open_loop'
          'Create loops (pass array of specs, even for single loop)'
          %-  ~(gas by *(map @t parameter-def))
          :~  :-  'context'
              ^-  parameter-def
              [%string 'Context name']
              :-  'specs'
              ^-  parameter-def
              [%array 'Array of loop specs with text, labels (array), and best_by (optional ISO date string)']
          ==
          ~['context' 'specs']
          tool-batch-open
      ==
      :*  'close_loop'
          'Close loops (pass array of IDs, even for single loop)'
          %-  ~(gas by *(map @t parameter-def))
          :~  :-  'context'
              ^-  parameter-def
              [%string 'Context name']
              :-  'ids'
              ^-  parameter-def
              [%array 'Array of loop IDs to close']
          ==
          ~['context' 'ids']
          tool-batch-close
      ==
      :*  'reopen_loop'
          'Reopen closed loops (pass array of IDs, even for single loop)'
          %-  ~(gas by *(map @t parameter-def))
          :~  :-  'context'
              ^-  parameter-def
              [%string 'Context name']
              :-  'ids'
              ^-  parameter-def
              [%array 'Array of loop IDs to reopen']
          ==
          ~['context' 'ids']
          tool-batch-reopen
      ==
      :*  'delete_loop'
          'Delete closed loops (pass array of IDs, even for single loop)'
          %-  ~(gas by *(map @t parameter-def))
          :~  :-  'context'
              ^-  parameter-def
              [%string 'Context name']
              :-  'ids'
              ^-  parameter-def
              [%array 'Array of loop IDs to delete']
          ==
          ~['context' 'ids']
          tool-batch-delete
      ==
      :*  'update_labels'
          'Replace all labels on multiple loops (pass arrays of IDs and new labels)'
          %-  ~(gas by *(map @t parameter-def))
          :~  :-  'context'
              ^-  parameter-def
              [%string 'Context name']
              :-  'ids'
              ^-  parameter-def
              [%array 'Array of loop IDs']
              :-  'labels'
              ^-  parameter-def
              [%array 'Array of labels to set (replaces all existing labels)']
          ==
          ~['context' 'ids' 'labels']
          tool-batch-update-labels
      ==
      :*  'add_labels'
          'Add labels to multiple loops (pass arrays of IDs and labels)'
          %-  ~(gas by *(map @t parameter-def))
          :~  :-  'context'
              ^-  parameter-def
              [%string 'Context name']
              :-  'ids'
              ^-  parameter-def
              [%array 'Array of loop IDs']
              :-  'labels'
              ^-  parameter-def
              [%array 'Array of labels to add to each loop']
          ==
          ~['context' 'ids' 'labels']
          tool-batch-add-labels
      ==
      :*  'remove_labels'
          'Remove labels from multiple loops (pass arrays of IDs and labels)'
          %-  ~(gas by *(map @t parameter-def))
          :~  :-  'context'
              ^-  parameter-def
              [%string 'Context name']
              :-  'ids'
              ^-  parameter-def
              [%array 'Array of loop IDs']
              :-  'labels'
              ^-  parameter-def
              [%array 'Array of labels to remove from each loop']
          ==
          ~['context' 'ids' 'labels']
          tool-batch-remove-labels
      ==
      :*  'list_loops'
          'List loops with optional filters (state, labels, search text, search labels)'
          %-  ~(gas by *(map @t parameter-def))
          :~  :-  'context'
              ^-  parameter-def
              [%string 'Context name']
              :-  'state'
              ^-  parameter-def
              [%string 'Filter by state: "open", "closed", or "all" (default: "open")']
              :-  'labels'
              ^-  parameter-def
              [%array 'Filter by exact labels (returns loops with ANY of these labels)']
              :-  'search_text'
              ^-  parameter-def
              [%string 'Regex pattern to search loop text']
              :-  'search_labels'
              ^-  parameter-def
              [%string 'Regex pattern to search loop labels']
          ==
          ~['context']
          tool-list-loops
      ==
      :*  'update_loop'
          'Update loop text, labels, or best-by date'
          %-  ~(gas by *(map @t parameter-def))
          :~  :-  'context'
              ^-  parameter-def
              [%string 'Context name']
              :-  'id'
              ^-  parameter-def
              [%number 'Loop ID']
              :-  'text'
              ^-  parameter-def
              [%string 'New text (optional)']
              :-  'labels'
              ^-  parameter-def
              [%array 'New labels array (optional, replaces all labels)']
              :-  'best_by'
              ^-  parameter-def
              [%string 'New best-by date in ISO format YYYY-MM-DD (optional, use empty string to clear)']
          ==
          ~['context' 'id']
          tool-update-loop
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
  ;<  ball=ball:tarball  bind:m  get-state:io
  =/  timezone=@t
    =/  tz-result  (mule |.((~(get-cage-as ba:tarball ball) /config 'timezone.txt' wain)))
    ?:  ?=(%| -.tz-result)  'UTC'
    =/  tz-wain=(unit wain)  p.tz-result
    ?~  tz-wain  'UTC'
    ?~  u.tz-wain  'UTC'
    i.u.tz-wain
  (pure:m [%text timezone])
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
  ;<  ball=ball:tarball  bind:m  get-state:io
  =/  jon=(unit json)
    (~(get-cage-as ba:tarball ball) /config/creds 'telegram.json' json)
  ?~  jon
    (pure:m [%error 'Telegram credentials not configured'])
  =/  bot-token=@t  (~(dog jo:json-utils u.jon) /bot-token so:dejs:format)
  =/  chat-id=@t  (~(dog jo:json-utils u.jon) /chat-id so:dejs:format)
  ;<  ~  bind:m
    (send-message:telegram bot-token chat-id message)
  (pure:m [%text 'Telegram message sent'])
::
++  tool-create-alarm
  ^-  tool-handler
  |=  arguments=(map @t json)
  =/  m  (fiber:io ,tool-result)
  ^-  form:m
  ::  Parse required tool_name and tool_arguments
  =/  parsed
    %.  [%o arguments]
    %-  ot:dejs:format
    :~  ['tool_name' so:dejs:format]
        ['tool_arguments' same]
    ==
  =/  tool-name=@t  -.parsed
  =/  tool-arguments=json  +.parsed
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
  ::  Get optional repeat parameters (default to 1 and ~s0)
  =/  repeat-count=@ud
    =/  count-json=(unit json)  (~(get by arguments) 'repeat_count')
    ?~  count-json  1
    ?.  ?=([%n *] u.count-json)  1
    (fall (rush p.u.count-json dem) 1)
  =/  interval-str=(unit @t)
    =/  interval-json=(unit json)  (~(get by arguments) 'interval')
    ?~  interval-json  ~
    ?.  ?=([%s *] u.interval-json)  ~
    `p.u.interval-json
  ::  Parse interval if provided, default to ~s0
  =/  interval=@dr
    ?~  interval-str  ~s0
    (fall (parse-duration:telegram u.interval-str) ~s0)
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
  ::  Validate repeat parameters
  ?:  ?&  (gth repeat-count 1)
          =(interval ~s0)
      ==
    (pure:m [%error 'interval required when repeat_count is greater than 1'])
  ::  Create recurrence rule and start alarm
  =/  rule=recurrence-rule:alarms  [u.wake-time repeat-count interval %.y]
  ::  Initialize alarm state (creates process file)
  ;<  ~  bind:m  (init-alarm-state:alarms u.wake-time tool-name tool-arguments repeat-count interval %.y)
  ::  Fire-and-forget the alarm fiber (sailbox manages lifecycle)
  ;<  ~  bind:m
    %:  fiber-throw:io
      (crip "alarm-{(scow %da u.wake-time)}")
      set-alarm+!>([u.wake-time tool-name tool-arguments repeat-count interval])
    ==
  (pure:m [%text (crip "Alarm created for tool: {(trip tool-name)}")])
::
++  tool-rename-chat
  ^-  tool-handler
  |=  arguments=(map @t json)
  =/  m  (fiber:io ,tool-result)
  ^-  form:m
  =/  parsed
    %.  [%o arguments]
    %-  ot:dejs:format
    :~  ['title' so:dejs:format]
        ['chat_id' so:dejs:format]
    ==
  =/  title=@t  -.parsed
  =/  chat-id-str=@t  +.parsed
  ::  Parse chat-id from hex string
  =/  chat-id=(unit @ux)  (slaw %ux chat-id-str)
  ?~  chat-id
    (pure:m [%error 'Invalid chat_id format. Expected hex format like 0x1234.5678'])
  ::  Update chat name in ball
  ;<  ball=ball:tarball  bind:m  get-state:io
  =/  chat=(unit chat:claude)
    (~(get-cage-as ba:tarball ball) /claude/chats (crip "{(hexn:sailbox u.chat-id)}.claude-chat") chat:claude)
  ?~  chat
    (pure:m [%error 'Chat not found'])
  ::  Update the chat's name
  =/  updated-chat=chat:claude  u.chat(name title)
  ;<  ~  bind:m
    (put-cage:io /claude/chats (crip "{(hexn:sailbox u.chat-id)}.claude-chat") [%claude-chat !>(updated-chat)])
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
  ;<  ball=ball:tarball  bind:m  get-state:io
  =/  jon=(unit json)
    (~(get-cage-as ba:tarball ball) /config/creds 'brave-search.json' json)
  ?~  jon
    (pure:m [%error 'Brave Search credentials not configured'])
  =/  api-key=@t  (~(dog jo:json-utils u.jon) /api-key so:dejs:format)
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
::
++  parse-commit-args
  |=  arguments=(map @t json)
  ^-  [mount-point=@tas timeout=@dr]
  =/  mount-point=@tas
    %.  [%o arguments]
    %-  ot:dejs:format
    :~  ['mount_point' so:dejs:format]
    ==
  =/  timeout-seconds=@ud
    ?~  timeout-json=(~(get by arguments) 'timeout_seconds')
      30
    ?.  ?=([%n *] u.timeout-json)
      30
    (rash p.u.timeout-json dem)
  [mount-point (mul timeout-seconds ~s1)]
::
++  subscribe-dill-logs
  =/  m  (fiber:io ,~)
  ^-  form:m
  (send-raw-card:io %pass /dill-logs %arvo %d %logs `~)
::
++  unsubscribe-dill-logs
  =/  m  (fiber:io ,~)
  ^-  form:m
  (send-raw-card:io %pass /dill-logs %arvo %d %logs ~)
::
++  set-timeout
  |=  [=bowl:gall duration=@dr]
  =/  m  (fiber:io ,~)
  ^-  form:m
  (send-raw-card:io %pass /commit-timeout %arvo %b %wait (add now.bowl duration))
::
++  format-told-to-text
  |=  log=told:dill
  ^-  tape
  ?-  -.log
      %crud
    =/  err-lines=wall  (zing (turn (flop q.log) (cury wash [0 80])))
    =/  lines-text=tape
      %-  zing
      %+  turn  err-lines
      |=(line=tape "{line}\0a")
    "ERROR [{<p.log>}]:\0a{lines-text}"
      %talk
    =/  talk-lines=wall  (zing (turn p.log (cury wash [0 80])))
    %-  zing
    %+  turn  talk-lines
    |=(line=tape "{line}\0a")
      %text
    "{p.log}\0a"
  ==
::
++  build-commit-json
  |=  =cass:clay
  ^-  json
  %-  pairs:enjs:format
  :~  ['sent' b+%.n]
      :-  'initial-version'
      %-  pairs:enjs:format
      :~  ['ud' (numb:enjs:format ud.cass)]
          ['da' s+(scot %da da.cass)]
      ==
      ['logs' a+~]
  ==
::
++  parse-initial-version
  |=  jon=json
  ^-  cass:clay
  =/  iv-json=json  (~(got jo:json-utils jon) /initial-version)
  :*  (~(dog jo:json-utils iv-json) /ud ni:dejs:format)
      (slav %da (~(dog jo:json-utils iv-json) /da so:dejs:format))
  ==
::
++  append-log-to-commit
  |=  [jon=json log-text=@t]
  ^-  json
  =/  logs=(list json)  (~(dog jo:json-utils jon) /logs (ar:dejs:format same:dejs:format))
  (~(put jo:json-utils jon) /logs a+[s+log-text logs])
::
++  cleanup-commit-state
  |=  pid=@ta
  =/  m  (fiber:io ,~)
  ^-  form:m
  ;<  ball=ball:tarball  bind:m  get-state:io
  ::  Delete from ball
  =/  ba  ~(. ba:tarball ball)
  =/  new-ball=ball:tarball  (del:ba /processes/commits (crip "{(trip pid)}.json"))
  (replace:io new-ball)
::
++  init-commit-state
  |=  [mount-point=@tas pid=@ta]
  =/  m  (fiber:io ,~)
  ^-  form:m
  ;<  ball=ball:tarball  bind:m  get-state:io
  ::  Check if already exists in ball
  =/  ba  ~(. ba:tarball ball)
  =/  existing=(unit content:tarball)  (get:ba /processes/commits (crip "{(trip pid)}.json"))
  ?^  existing
    (pure:m ~)
  ;<  =cass:clay  bind:m  (scry:io cass:clay %cw mount-point ~)
  =/  jon=json  (build-commit-json cass)
  (put-cage:io /processes/commits (crip "{(trip pid)}.json") [%json !>(jon)])
::
++  commit-desk
  |=  mount-point=@tas
  =/  m  (fiber:io ,~)
  ^-  form:m
  ;<  pid=@ta  bind:m  get-pid:io
  ;<  ball=ball:tarball  bind:m  get-state:io
  =/  jon=json
    (~(got-cage-as ba:tarball ball) /processes/commits (crip "{(trip pid)}.json") json)
  =/  sent=?  (~(dog jo:json-utils jon) /sent bo:dejs:format)
  ?:  sent
    (pure:m ~)
  =/  updated-jon=json  (~(put jo:json-utils jon) /sent b+%.y)
  ;<  ~  bind:m  (put-cage:io /processes/commits (crip "{(trip pid)}.json") [%json !>(updated-jon)])
  ;<  our=@p  bind:m  get-our:io
  (poke:io [our %hood] kiln-commit+!>([mount-point %.n]))
::
++  collect-logs-until-timeout
  |=  pid=@ta
  =/  m  (fiber:io ,~)
  ^-  form:m
  ::  Use raw fiber form (|= input) to pattern match on incoming events
  ::  and directly emit timer cards for debouncing
  |=  input:fiber:sailbox
  =/  ball-0=ball:tarball  state
  ::  Read JSON from ball
  =/  jon=json
    (~(got-cage-as ba:tarball ball-0) /processes/commits (crip "{(trip pid)}.json") json)
  =/  logs=(list json)  (~(dog jo:json-utils jon) /logs (ar:dejs:format same:dejs:format))
  ?+  in  [~ state %skip |]
      ~  [~ state %wait |]
      ::  Main timeout expired - we're done
      [~ %arvo [%commit-timeout ~] %behn %wake *]
    [~ state %done ~]
      ::  Quiet timer fired - check if it's still current
      ::  Debouncing: each log spawns a 1s timer tagged with log count
      ::  If timer's count matches current count, no new logs arrived (quiet)
      ::  Otherwise it's stale - another log arrived and spawned a newer timer
      [~ %arvo [%commit-quiet @ ~] %behn %wake *]
    =/  timer-counter=@ud  (slav %ud i.t.wire.u.in)
    ?.  =(timer-counter (lent logs))
      ::  Stale timer (more logs arrived), ignore it
      [~ state %skip |]
    ::  Current timer (no new logs for 1s), we're done
    [~ state %done ~]
      ::  Got a dill log - store it and spawn new quiet timer
      [~ %arvo [%dill-logs ~] %dill %logs *]
    ::  Render the told to text immediately
    =/  log-text=tape  (format-told-to-text told.sign.u.in)
    =/  updated-jon=json  (append-log-to-commit jon (crip log-text))
    ::  Write back to ball using empty dais-map (same-mark update)
    =/  ba  (~(das ba:tarball ball-0) ~)
    =/  meta=metadata:tarball
      %-  ~(gas by *(map @t @t))
      :~  ['mtime' (da-oct:tarball now.bowl)]
      ==
    =/  new-ball=ball:tarball  (put:ba /processes/commits (crip "{(trip pid)}.json") [meta %& [%json !>(updated-jon)]])
    =.  ball-0  new-ball
    ::  Get updated log count
    =/  new-logs=(list json)  (~(dog jo:json-utils updated-jon) /logs (ar:dejs:format same:dejs:format))
    ::  Spawn quiet timer tagged with new log count
    =/  card  [%pass /commit-quiet/(scot %ud (lent new-logs)) %arvo %b %wait (add now.bowl ~s1)]
    [~[card] ball-0 %cont (collect-logs-until-timeout pid)]
  ==
::
++  format-commit-result
  |=  [initial=cass:clay final=cass:clay logs=(list @t)]
  ^-  tape
  %+  weld  "Initial version: {<ud.initial>}\0a"
  %+  weld  "Final version: {<ud.final>}\0a"
  %+  weld  "Logs ({<(lent logs)>}):\0a"
  (roll logs |=([log=@t acc=tape] (weld acc (trip log))))
::
++  tool-commit
  ^-  tool-handler
  |=  arguments=(map @t json)
  =/  m  (fiber:io ,tool-result)
  ^-  form:m
  ;<  pid=@ta  bind:m  get-pid:io
  =/  [mount-point=@tas timeout=@dr]  (parse-commit-args arguments)
  ;<  ~  bind:m  (init-commit-state mount-point pid)
  ;<  =bowl:gall  bind:m  get-bowl:io
  ;<  ~  bind:m  subscribe-dill-logs
  ;<  ~  bind:m  (set-timeout bowl timeout)
  ;<  ~  bind:m  (commit-desk mount-point)
  ;<  ~  bind:m  (collect-logs-until-timeout pid)
  ;<  ~  bind:m  unsubscribe-dill-logs
  ::  Read final result from JSON
  ;<  ball=ball:tarball  bind:m  get-state:io
  =/  jon=json
    (~(got-cage-as ba:tarball ball) /processes/commits (crip "{(trip pid)}.json") json)
  =/  initial-version=cass:clay  (parse-initial-version jon)
  =/  log-texts=(list @t)  (~(dug jo:json-utils jon) /logs (ar:dejs:format so:dejs:format) ~)
  ;<  final-version=cass:clay  bind:m  (scry:io cass:clay %cw mount-point ~)
  ;<  ~  bind:m  (cleanup-commit-state pid)
  (pure:m %text (crip (format-commit-result initial-version final-version (flop log-texts))))
::
++  tool-desk-version
  ^-  tool-handler
  |=  arguments=(map @t json)
  =/  m  (fiber:io ,tool-result)
  ^-  form:m
  =/  mount-point=@tas
    %.  [%o arguments]
    %-  ot:dejs:format
    :~  ['mount_point' so:dejs:format]
    ==
  ;<  version=cass:clay  bind:m  (scry:io cass:clay %cw mount-point ~)
  (pure:m [%text (crip "Desk version: {<ud.version>}")])
::
++  tool-list-loop-contexts
  ^-  tool-handler
  |=  arguments=(map @t json)
  =/  m  (fiber:io ,tool-result)
  ^-  form:m
  ;<  ball=ball:tarball  bind:m  get-state:io
  =/  contexts=(list @t)  (find-all-contexts ball /tools/open-loops ~)
  (pure:m [%text (crip (format-contexts contexts))])
::
++  find-all-contexts
  |=  [ball=ball:tarball base-path=path prefix=tape]
  ^-  (list @t)
  ::  List files in current directory
  =/  files=(list @ta)
    (~(lis ba:tarball ball) base-path)
  =/  file-contexts=(list @t)
    %+  murn  files
    |=  filename=@ta
    ::  Check if ends with '.open-loops'
    =/  name=tape  (trip filename)
    =/  ext=tape  ".open-loops"
    ?.  =(ext (slag (sub (lent name) (lent ext)) name))
      ~
    ::  Extract context name (filename without extension)
    =/  context-name=tape  (scag (sub (lent name) (lent ext)) name)
    ::  Prepend prefix if any
    `(crip ?~(prefix context-name "{prefix}/{context-name}"))
  ::  List subdirectories
  =/  dirs=(list @ta)
    (~(lss ba:tarball ball) base-path)
  ::  Recursively process each subdirectory
  =/  dir-contexts=(list @t)
    %-  zing
    %+  turn  dirs
    |=  dirname=@ta
    =/  new-prefix=tape
      ?~(prefix (trip dirname) "{prefix}/{(trip dirname)}")
    (find-all-contexts ball (weld base-path /[dirname]) new-prefix)
  ::  Combine file and directory results
  (weld file-contexts dir-contexts)
++  format-context-items
  |=  contexts=(list @t)
  ^-  tape
  ?~  contexts  ""
  =/  rest=tape  $(contexts t.contexts)
  "- {(trip i.contexts)}\0a{rest}"
::
++  format-contexts
  |=  contexts=(list @t)
  ^-  tape
  ?~  contexts  "No loop contexts found"
  =/  count=@ud  (lent contexts)
  =/  header=tape  "Loop contexts ({(a-co:co count)}):\0a"
  =/  items=tape  (format-context-items contexts)
  "{header}{items}"
::
++  parse-iso-date
  |=  text=@t
  ^-  @da
  ::  Parse YYYY-MM-DD to @da using iso-8601 library
  =/  [[a=? y=@ud] m=@ud d=@ud]  (de:date-input:iso-8601 text)
  (year [a y] m d 0 0 0 ~)
::
++  context-to-path
  |=  context=@ta
  ^-  [pax=path filename=@ta]
  ::  Parse context as path (prepend '/' for stap)
  =/  context-path=path
    (rash (crip (weld "/" (trip context))) stap)
  ::  Split into parent directory and filename
  ?~  context-path
    [/tools/open-loops context]  ::  empty, shouldn't happen
  ?~  t.context-path
    [/tools/open-loops i.context-path]  ::  just a filename, no directory
  ::  Multiple parts: all but last are directories
  =/  dirs=(list @ta)  (snip `(list @ta)`context-path)
  =/  filename=@ta  (rear context-path)
  [(weld /tools/open-loops dirs) filename]
::
++  tool-list-loops
  ^-  tool-handler
  |=  arguments=(map @t json)
  =/  m  (fiber:io ,tool-result)
  ^-  form:m
  =/  context=@tas
    %.  [%o arguments]
    %-  ot:dejs:format
    :~  ['context' so:dejs:format]
    ==
  =/  state-filter=@t
    =/  state-json=(unit json)  (~(get by arguments) 'state')
    ?~  state-json  'open'
    (so:dejs:format u.state-json)
  =/  [pax=path filename=@ta]  (context-to-path context)
  =/  full-filename=@ta  (crip "{(trip filename)}.open-loops")
  ;<  ball=ball:tarball  bind:m  get-state:io
  =/  =loops:open-loops
    (~(got-cage-as ba:tarball ball) pax full-filename loops:open-loops)
  =/  loop-list=(list [@ud loop:open-loops])
    ?+  state-filter  ~(list-open lo:open-loops loops)
      %open    ~(list-open lo:open-loops loops)
      %closed  ~(list-closed lo:open-loops loops)
      %all     (weld ~(list-open lo:open-loops loops) ~(list-closed lo:open-loops loops))
    ==
  ::  Apply label filter (exact match)
  =/  filtered-list=(list [@ud loop:open-loops])
    =/  labels-json=(unit json)  (~(get by arguments) 'labels')
    ?~  labels-json  loop-list
    =/  labels=(list @t)  ((ar so):dejs:format u.labels-json)
    |-  ^-  (list [@ud loop:open-loops])
    ?~  labels  loop-list
    =/  with-label=(list [@ud loop:open-loops])
      (~(filter-by-label lo:open-loops loops) loop-list i.labels)
    $(labels t.labels, loop-list with-label)
  ::  Apply text search (regex)
  =.  filtered-list
    =/  search-text-json=(unit json)  (~(get by arguments) 'search_text')
    ?~  search-text-json  filtered-list
    =/  pattern=@t  (so:dejs:format u.search-text-json)
    (~(search-text lo:open-loops loops) filtered-list pattern)
  ::  Apply label search (regex)
  =.  filtered-list
    =/  search-labels-json=(unit json)  (~(get by arguments) 'search_labels')
    ?~  search-labels-json  filtered-list
    =/  pattern=@t  (so:dejs:format u.search-labels-json)
    (~(search-labels lo:open-loops loops) filtered-list pattern)
  (pure:m [%text (crip (format-loop-list filtered-list state-filter))])
::
++  format-loop-items
  |=  loop-list=(list [@ud loop:open-loops])
  ^-  tape
  ?~  loop-list  ""
  =/  [id=@ud =loop:open-loops]  i.loop-list
  =/  labels-str=tape
    =/  label-list=(list @t)  ~(tap in labels.loop)
    |-  ^-  tape
    ?~  label-list  ""
    =/  rest=tape  $(label-list t.label-list)
    "{(trip i.label-list)} {rest}"
  =/  item=tape
    ?~  labels-str
      "#{(a-co:co id)}: {(trip text.loop)}\0a"
    "#{(a-co:co id)}: {(trip text.loop)} [{labels-str}]\0a"
  =/  rest=tape  $(loop-list t.loop-list)
  "{item}{rest}"
::
++  format-loop-list
  |=  [loop-list=(list [@ud loop:open-loops]) state=@t]
  ^-  tape
  ?~  loop-list
    "{(trip state)} loops: (none)"
  =/  count=@ud  (lent loop-list)
  =/  header=tape  "{(trip state)} loops ({(a-co:co count)}):\0a"
  =/  items=tape  (format-loop-items loop-list)
  "{header}{items}"
::
++  tool-update-loop
  ^-  tool-handler
  |=  arguments=(map @t json)
  =/  m  (fiber:io ,tool-result)
  ^-  form:m
  =/  context=@tas
    %.  [%o arguments]
    %-  ot:dejs:format
    :~  ['context' so:dejs:format]
    ==
  =/  id=@ud
    %.  [%o arguments]
    %-  ot:dejs:format
    :~  ['id' ni:dejs:format]
    ==
  =/  [pax=path filename=@ta]  (context-to-path context)
  =/  full-filename=@ta  (crip "{(trip filename)}.open-loops")
  ;<  ball=ball:tarball  bind:m  get-state:io
  =/  =loops:open-loops
    (~(got-cage-as ba:tarball ball) pax full-filename loops:open-loops)
  ;<  =bowl:gall  bind:m  get-bowl:io
  =/  updated-loops=loops:open-loops  loops
  ::  Update text if provided
  =/  new-text-json=(unit json)  (~(get by arguments) 'text')
  =?  updated-loops  ?=(^ new-text-json)
    =/  new-text=@t  (so:dejs:format u.new-text-json)
    (~(update-text lo:open-loops updated-loops) id new-text now.bowl)
  ::  Update labels if provided
  =/  new-labels=(unit json)  (~(get by arguments) 'labels')
  =?  updated-loops  ?=(^ new-labels)
    =/  labels-set=(set @t)
      %-  ~(gas in *(set @t))
      ((ar so):dejs:format u.new-labels)
    (~(update-labels lo:open-loops updated-loops) id labels-set now.bowl)
  ::  Update best-by if provided
  =/  new-best-by=(unit json)  (~(get by arguments) 'best_by')
  =?  updated-loops  ?=(^ new-best-by)
    =/  bb-text=@t  (so:dejs:format u.new-best-by)
    =/  bb-date=(unit @da)
      ?:  =(bb-text '')  ~
      `(parse-iso-date bb-text)
    (~(update-best-by lo:open-loops updated-loops) id bb-date now.bowl)
  ::  Save
  ;<  ~  bind:m
    (put-cage:io pax full-filename [%open-loops !>(updated-loops)])
  (pure:m [%text (crip "Updated loop #{(a-co:co id)} in {(trip context)}")])
::
++  tool-batch-open
  ^-  tool-handler
  |=  arguments=(map @t json)
  =/  m  (fiber:io ,tool-result)
  ^-  form:m
  =/  context=@tas
    %.  [%o arguments]
    %-  ot:dejs:format
    :~  ['context' so:dejs:format]
    ==
  =/  specs-json=json  (~(got by arguments) 'specs')
  =/  spec-parser
    |=  j=json
    ^-  [text=@t labels=(set @t) best-by=(unit @da)]
    =/  obj=(map @t json)  ((om:dejs:format same) j)
    =/  text=@t  (so:dejs:format (~(got by obj) 'text'))
    =/  labels=(set @t)
      %-  ~(gas in *(set @t))
      ((ar so):dejs:format (~(got by obj) 'labels'))
    =/  best-by=(unit @da)
      =/  bb-json=(unit json)  (~(get by obj) 'best_by')
      ?~  bb-json  ~
      ?~  u.bb-json  ~
      =/  bb-text=@t  (so:dejs:format u.bb-json)
      ?:  =(bb-text '')  ~
      `(parse-iso-date bb-text)
    [text labels best-by]
  =/  specs=(list [text=@t labels=(set @t) best-by=(unit @da)])
    ((ar:dejs:format spec-parser) specs-json)
  =/  [pax=path filename=@ta]  (context-to-path context)
  =/  full-filename=@ta  (crip "{(trip filename)}.open-loops")
  ;<  ball=ball:tarball  bind:m  get-state:io
  =/  =loops:open-loops
    =/  existing=(unit loops:open-loops)
      (~(get-cage-as ba:tarball ball) pax full-filename loops:open-loops)
    ?^  existing  u.existing
    [0 ~ ~]
  ;<  =bowl:gall  bind:m  get-bowl:io
  =/  updated-loops=loops:open-loops
    (~(batch-open lo:open-loops loops) specs now.bowl)
  ;<  ~  bind:m
    (put-cage:io pax full-filename [%open-loops !>(updated-loops)])
  (pure:m [%text (crip "Opened {(a-co:co (lent specs))} loops in {(trip context)}")])
::
++  tool-batch-close
  ^-  tool-handler
  |=  arguments=(map @t json)
  =/  m  (fiber:io ,tool-result)
  ^-  form:m
  =/  context=@tas
    %.  [%o arguments]
    %-  ot:dejs:format
    :~  ['context' so:dejs:format]
    ==
  =/  ids=(list @ud)
    ((ar ni):dejs:format (~(got by arguments) 'ids'))
  =/  [pax=path filename=@ta]  (context-to-path context)
  =/  full-filename=@ta  (crip "{(trip filename)}.open-loops")
  ;<  ball=ball:tarball  bind:m  get-state:io
  =/  =loops:open-loops
    (~(got-cage-as ba:tarball ball) pax full-filename loops:open-loops)
  ;<  =bowl:gall  bind:m  get-bowl:io
  =/  updated-loops=loops:open-loops
    (~(batch-close lo:open-loops loops) ids now.bowl)
  ;<  ~  bind:m
    (put-cage:io pax full-filename [%open-loops !>(updated-loops)])
  (pure:m [%text (crip "Closed {(a-co:co (lent ids))} loops in {(trip context)}")])
::
++  tool-batch-reopen
  ^-  tool-handler
  |=  arguments=(map @t json)
  =/  m  (fiber:io ,tool-result)
  ^-  form:m
  =/  context=@tas
    %.  [%o arguments]
    %-  ot:dejs:format
    :~  ['context' so:dejs:format]
    ==
  =/  ids=(list @ud)
    ((ar ni):dejs:format (~(got by arguments) 'ids'))
  =/  [pax=path filename=@ta]  (context-to-path context)
  =/  full-filename=@ta  (crip "{(trip filename)}.open-loops")
  ;<  ball=ball:tarball  bind:m  get-state:io
  =/  =loops:open-loops
    (~(got-cage-as ba:tarball ball) pax full-filename loops:open-loops)
  ;<  =bowl:gall  bind:m  get-bowl:io
  =/  updated-loops=loops:open-loops
    (~(batch-reopen lo:open-loops loops) ids now.bowl)
  ;<  ~  bind:m
    (put-cage:io pax full-filename [%open-loops !>(updated-loops)])
  (pure:m [%text (crip "Reopened {(a-co:co (lent ids))} loops in {(trip context)}")])
::
++  tool-batch-delete
  ^-  tool-handler
  |=  arguments=(map @t json)
  =/  m  (fiber:io ,tool-result)
  ^-  form:m
  =/  context=@tas
    %.  [%o arguments]
    %-  ot:dejs:format
    :~  ['context' so:dejs:format]
    ==
  =/  ids=(list @ud)
    ((ar ni):dejs:format (~(got by arguments) 'ids'))
  =/  [pax=path filename=@ta]  (context-to-path context)
  =/  full-filename=@ta  (crip "{(trip filename)}.open-loops")
  ;<  ball=ball:tarball  bind:m  get-state:io
  =/  =loops:open-loops
    (~(got-cage-as ba:tarball ball) pax full-filename loops:open-loops)
  =/  updated-loops=loops:open-loops
    (~(batch-delete lo:open-loops loops) ids)
  ;<  ~  bind:m
    (put-cage:io pax full-filename [%open-loops !>(updated-loops)])
  (pure:m [%text (crip "Deleted {(a-co:co (lent ids))} loops from {(trip context)}")])
::
++  tool-batch-update-labels
  ^-  tool-handler
  |=  arguments=(map @t json)
  =/  m  (fiber:io ,tool-result)
  ^-  form:m
  =/  context=@tas
    %.  [%o arguments]
    %-  ot:dejs:format
    :~  ['context' so:dejs:format]
    ==
  =/  ids=(list @ud)
    ((ar ni):dejs:format (~(got by arguments) 'ids'))
  =/  labels=(set @t)
    %-  ~(gas in *(set @t))
    ((ar so):dejs:format (~(got by arguments) 'labels'))
  =/  [pax=path filename=@ta]  (context-to-path context)
  =/  full-filename=@ta  (crip "{(trip filename)}.open-loops")
  ;<  ball=ball:tarball  bind:m  get-state:io
  =/  =loops:open-loops
    (~(got-cage-as ba:tarball ball) pax full-filename loops:open-loops)
  ;<  =bowl:gall  bind:m  get-bowl:io
  =/  updated-loops=loops:open-loops
    (~(batch-update-labels lo:open-loops loops) ids labels now.bowl)
  ;<  ~  bind:m
    (put-cage:io pax full-filename [%open-loops !>(updated-loops)])
  (pure:m [%text (crip "Updated labels on {(a-co:co (lent ids))} loops in {(trip context)}")])
::
++  tool-batch-add-labels
  ^-  tool-handler
  |=  arguments=(map @t json)
  =/  m  (fiber:io ,tool-result)
  ^-  form:m
  =/  context=@tas
    %.  [%o arguments]
    %-  ot:dejs:format
    :~  ['context' so:dejs:format]
    ==
  =/  ids=(list @ud)
    ((ar ni):dejs:format (~(got by arguments) 'ids'))
  =/  labels=(set @t)
    %-  ~(gas in *(set @t))
    ((ar so):dejs:format (~(got by arguments) 'labels'))
  =/  [pax=path filename=@ta]  (context-to-path context)
  =/  full-filename=@ta  (crip "{(trip filename)}.open-loops")
  ;<  ball=ball:tarball  bind:m  get-state:io
  =/  =loops:open-loops
    (~(got-cage-as ba:tarball ball) pax full-filename loops:open-loops)
  ;<  =bowl:gall  bind:m  get-bowl:io
  =/  updated-loops=loops:open-loops
    (~(batch-add-labels lo:open-loops loops) ids labels now.bowl)
  ;<  ~  bind:m
    (put-cage:io pax full-filename [%open-loops !>(updated-loops)])
  (pure:m [%text (crip "Added {(a-co:co ~(wyt in labels))} labels to {(a-co:co (lent ids))} loops in {(trip context)}")])
::
++  tool-batch-remove-labels
  ^-  tool-handler
  |=  arguments=(map @t json)
  =/  m  (fiber:io ,tool-result)
  ^-  form:m
  =/  context=@tas
    %.  [%o arguments]
    %-  ot:dejs:format
    :~  ['context' so:dejs:format]
    ==
  =/  ids=(list @ud)
    ((ar ni):dejs:format (~(got by arguments) 'ids'))
  =/  labels=(set @t)
    %-  ~(gas in *(set @t))
    ((ar so):dejs:format (~(got by arguments) 'labels'))
  =/  [pax=path filename=@ta]  (context-to-path context)
  =/  full-filename=@ta  (crip "{(trip filename)}.open-loops")
  ;<  ball=ball:tarball  bind:m  get-state:io
  =/  =loops:open-loops
    (~(got-cage-as ba:tarball ball) pax full-filename loops:open-loops)
  ;<  =bowl:gall  bind:m  get-bowl:io
  =/  updated-loops=loops:open-loops
    (~(batch-remove-labels lo:open-loops loops) ids labels now.bowl)
  ;<  ~  bind:m
    (put-cage:io pax full-filename [%open-loops !>(updated-loops)])
  (pure:m [%text (crip "Removed {(a-co:co ~(wyt in labels))} labels from {(a-co:co (lent ids))} loops in {(trip context)}")])
--
