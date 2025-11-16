/-  *master, claude
/+  io=sailboxio, tools, chat-index, pytz, sailbox, time, iso-8601
|%
::  Maximum characters for context window (as proxy for tokens)
::
++  max-context-chars  100.000
::
::  Count characters in a message's JSON representation
::
++  count-message-chars
  |=  msg=message:claude
  ^-  @ud
  ::  Convert message to JSON to get accurate character count
  =/  msg-json=json
    %-  pairs:enjs:format
    :~  ['role' s+role.msg]
        ['content' content.msg]
    ==
  =/  json-text=@t  (en:json:html msg-json)
  (met 3 json-text)
::
::  Apply sliding window to message list based on character limit
::  Returns most recent messages that fit within max-context-chars
::
++  apply-sliding-window
  |=  history=(list message:claude)
  ^-  (list message:claude)
  ::  Work backwards from most recent message
  =/  reversed=(list message:claude)  (flop history)
  =/  accumulated=@ud  0
  =/  result=(list message:claude)  ~
  |-
  ?~  reversed
    ::  Return in chronological order
    result
  =/  msg-chars=@ud  (count-message-chars i.reversed)
  =/  new-total=@ud  (add accumulated msg-chars)
  ::  If adding this message would exceed limit, stop
  ?:  (gth new-total max-context-chars)
    result
  ::  Add message to result (prepending to maintain order)
  $(reversed t.reversed, accumulated new-total, result [i.reversed result])
::
::  Build chat range string from message list
::  Groups consecutive messages by chat-id and formats as [chat-id:idx-idx:char-char][chat-id:idx-idx:char-char]
::
++  build-chat-ranges
  |=  messages=(list message:claude)
  ^-  tape
  ?~  messages  ""
  ::  Group consecutive messages by chat-id
  =/  result=tape  ""
  =/  current-chat=@ux  chat-id.i.messages
  =/  start-idx=@ud  index.i.messages
  =/  last-idx=@ud  index.i.messages
  =/  start-char=@ud  cumulative-chars.i.messages
  =/  last-msg=message:claude  i.messages
  =/  remaining=(list message:claude)  t.messages
  |-
  ?~  remaining
    ::  Finish last group - end char is cumulative + chars of last message
    =/  end-char=@ud  (add cumulative-chars.last-msg chars.last-msg)
    (weld result "[{(scow %ux current-chat)}:{(a-co:co start-idx)}-{(a-co:co last-idx)}:{(a-co:co start-char)}-{(a-co:co end-char)}]")
  =/  msg=message:claude  i.remaining
  ?:  =(chat-id.msg current-chat)
    ::  Same chat, extend range
    $(remaining t.remaining, last-idx index.msg, last-msg msg)
  ::  Different chat, close current range and start new one
  =/  end-char=@ud  (add cumulative-chars.last-msg chars.last-msg)
  =/  new-result=tape  (weld result "[{(scow %ux current-chat)}:{(a-co:co start-idx)}-{(a-co:co last-idx)}:{(a-co:co start-char)}-{(a-co:co end-char)}]")
  $(result new-result, current-chat chat-id.msg, start-idx index.msg, last-idx index.msg, start-char cumulative-chars.msg, last-msg msg, remaining t.remaining)
::
::  Build full conversation history by walking up parent chain
::  Returns messages in chronological order
::
++  build-ancestor-context
  |=  [chat=chat:claude chats=(map @ux chat:claude)]
  ^-  (list message:claude)
  ::  Recursively collect messages from ancestors
  =/  ancestor-messages=(list message:claude)
    ?~  parent.chat  ~
    ::  Get parent chat
    =/  parent-chat=(unit chat:claude)  (~(get by chats) chat-id.u.parent.chat)
    ?~  parent-chat  ~
    ::  Get parent's messages up to branch point
    =/  parent-msgs-by-index=((mop @ud message:claude) lth)  messages-by-index.u.parent-chat
    =/  parent-msgs-list=(list [@ud message:claude])
      (tap:((on @ud message:claude) lth) (lot:((on @ud message:claude) lth) parent-msgs-by-index ~ `(add branch-point.u.parent.chat 1)))
    ::  Recursively get parent's ancestors
    =/  grandparent-msgs=(list message:claude)
      (build-ancestor-context u.parent-chat chats)
    ::  Combine: grandparents + parent messages up to branch
    (weld grandparent-msgs (turn parent-msgs-list tail))
  ::  Get current chat's own messages
  =/  own-messages=(list message:claude)
    (turn (tap:((on @ud message:claude) lth) messages-by-time.chat) tail)
  ::  Combine: ancestors + own messages
  (weld ancestor-messages own-messages)
::
::  Get paginated messages from a chat
::
++  get-messages-page
  |=  [messages=((mop @ud message:claude) lth) before=(unit @ud) limit=@ud]
  ^-  (list [@ud message:claude])
  ::  Get messages before timestamp (or all if no timestamp)
  =/  messages-to-return=((mop @ud message:claude) lth)
    ?~  before
      messages
    (lot:((on @ud message:claude) lth) messages ~ `u.before)
  ::  Take last N messages (most recent before the timestamp)
  =/  message-list=(list [@ud message:claude])
    (scag limit (flop (tap:((on @ud message:claude) lth) messages-to-return)))
  ::  Return in chronological order (oldest first)
  (flop message-list)
::
::  Claude tool definitions - converts lib/tools format to Claude API format
::
++  param-type-to-json
  |=  type=parameter-type:tools
  ^-  @t
  ?-  type
    %string   'string'
    %number   'number'
    %boolean  'boolean'
    %array    'array'
    %object   'object'
  ==
::
++  tool-def-to-claude
  |=  tool=tool-def:tools
  ^-  json
  ::  Convert parameters map to properties
  =/  properties=(map @t json)
    %-  ~(run by parameters.tool)
    |=  param=parameter-def:tools
    %-  pairs:enjs:format
    :~  ['type' s+(param-type-to-json type.param)]
        ['description' s+description.param]
    ==
  ::  Convert required list to JSON array
  =/  required-array=(list json)
    (turn required.tool |=(f=@t s+f))
  ::  Build Claude API tool definition
  %-  pairs:enjs:format
  :~  ['name' s+name.tool]
      ['description' s+description.tool]
      :-  'input_schema'
      %-  pairs:enjs:format
      :~  ['type' s+'object']
          ['properties' [%o properties]]
          ['required' [%a required-array]]
      ==
  ==
::
++  claude-tools
  ^-  (list json)
  (turn all-tools:tools tool-def-to-claude)
::  Call Claude Messages API with conversation history
::
++  send-message
  |=  [api-key=@t ai-model=@t chat=chat:claude chats=(map @ux chat:claude) user-timezone=@t]
  =/  m  (fiber:io ,[response=@t updated-chat=chat:claude])
  ^-  form:m
  ::  Build full history including ancestors
  =/  full-history=(list message:claude)
    (build-ancestor-context chat chats)
  ::  Apply sliding window to limit context size
  =/  history=(list message:claude)
    (apply-sliding-window full-history)
  ~&  >  "send-message: {<(lent full-history)>} total messages, using {<(lent history)>} after sliding window"
  ::  Convert message history to JSON format
  =/  messages-json=(list json)
    %+  turn  history
    |=  msg=message:claude
    ^-  json
    %-  pairs:enjs:format
    :~  ['role' s+role.msg]
        ['content' content.msg]
    ==
  ::  Get current time in user's timezone
  ;<  =bowl:gall  bind:m  get-bowl:io
  =/  tz-time=(unit dext:pytz)
    (utc-to-tz:~(. zn:pytz user-timezone) now.bowl)
  =/  current-time=@t
    ?~  tz-time
      'Unknown'
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
    =/  minute-str=tape
      ?:  (lth minute 10)
        (weld "0" (numb:sailbox minute))
      (numb:sailbox minute)
    (crip "{weekday} {year}-{month}-{day} {(numb:sailbox hour-12)}:{minute-str}{?:(is-pm "pm" "am")} {(trip user-timezone)}")
  ::  Build the request body with system prompt and tools
  ::  IMPORTANT: This system prompt is sent with EVERY request, not just at conversation start
  ::  All information here is LIVE and REAL-TIME
  =/  ship-name=@t  (scot %p our.bowl)
  ::  Calculate context stats
  =/  total-messages=@ud  (lent full-history)
  =/  context-messages=@ud  (lent history)
  =/  context-chars=@ud
    %-  roll  :_  add
    %+  turn  history
    |=(msg=message:claude (count-message-chars msg))
  =/  context-truncated=?  !=(total-messages context-messages)
  =/  chat-id-text=@t  (scot %ux id.chat)
  ::  Build chat range string showing which messages from which chats
  =/  chat-ranges=tape
    ?~  history  "no messages"
    (build-chat-ranges history)
  ::  Build readable UTC timestamp range (timestamps are already UTC)
  =/  time-range=tape
    ?~  history  ""
    =/  first-time=@ud  timestamp.i.history
    =/  last-time=@ud  timestamp:(rear history)
    ::  Convert Unix ms to @da and format with ISO 8601
    =/  first-da=@da  (from-unix-ms:chrono:userlib first-time)
    =/  last-da=@da  (from-unix-ms:chrono:userlib last-time)
    "{(en:datetime-local:iso-8601 first-da)} to {(en:datetime-local:iso-8601 last-da)} UTC"
  =/  system-prompt=@t
    %+  rap  3
    :~  'REAL-TIME SYSTEM INFORMATION (updated with every message): '
        'You are '
        ai-model
        ', a helpful AI assistant integrated with Urbit ship '
        ship-name
        '. '
        'Urbit is a peer-to-peer operating system and network. This integration runs as a native Hoon application on the user\'s personal server (their "ship"), which calls your API. '
        'Through this integration, you have access to tools that can interact with their Urbit system and other Urbit applications and ships on the network. '
        'The user is interacting with you through a web interface served by their ship. '
        'Current time: '
        current-time
        ' (LIVE - this is the actual current time right now). '
        'Chat ID: '
        chat-id-text
        '. '
        'Context: '
        (crip (a-co:co context-messages))
        '/'
        (crip (a-co:co total-messages))
        ' messages, '
        (crip (a-co:co context-chars))
        '/'
        (crip (a-co:co max-context-chars))
        ' chars'
        ?:(context-truncated ' [TRUNCATED]' '')
        '. '
        'Messages in context (format [chat-id:msg-index-range:char-range] (ISO-8601-start to ISO-8601-end UTC)): '
        (crip chat-ranges)
        ?~(history '' (crip " ({time-range})"))
        '. '
        'INSTRUCTIONS: '
        'Use the rename_chat tool ONCE after the first message to give this conversation a descriptive 3-5 word title, and then only use it again at the user\'s explicit request thereafter.'
    ==
  =/  body=@t
    %-  en:json:html
    %-  pairs:enjs:format
    :~  ['model' s+ai-model]
        ['max_tokens' n+~.1024]
        ['system' s+system-prompt]
        ['messages' a+messages-json]
        ['tools' a+claude-tools]
    ==
  ~&  >  'Request body being sent to Claude:'
  ~&  >  body
  =/  body-octs=octs  (as-octs:mimes:html body)
  ::  Build request with auth header
  =/  =request:http
    :*  %'POST'
        'https://api.anthropic.com/v1/messages'
        :~  ['x-api-key' api-key]
            ['anthropic-version' '2023-06-01']
            ['content-type' 'application/json']
        ==
        `body-octs
    ==
  ::  🧪 Hypothesis: Claude API returns JSON with content array
  ;<  ~  bind:m  (send-request:io request)
  ;<  =client-response:iris  bind:m  take-client-response:io
  ;<  body=cord  bind:m  (extract-body:io client-response)
  ::  Parse JSON response
  =/  jon=(unit json)  (de:json:html body)
  ?~  jon
    (pure:m [(crip "Error: Could not parse Claude response: {(trip body)}") chat])
  ::  Debug: log the response
  ~&  >  'Claude API Response:'
  ~&  >  (en:json:html u.jon)
  ::  Check if response is an error
  =/  error-check
    %-  mule
    |.
    %.  u.jon
    %-  ot:dejs:format
    :~  ['type' so:dejs:format]
    ==
  ?:  ?&  ?=(%& -.error-check)
          =(p.error-check 'error')
      ==
    ::  Extract error message
    =/  error-msg
      %-  mule
      |.
      %.  u.jon
      %-  ot:dejs:format
      :~  :-  'error'
          %-  ot:dejs:format
          :~  ['message' so:dejs:format]
              ['type' so:dejs:format]
          ==
      ==
    =/  err-text=@t
      ?:  ?=(%| -.error-msg)
        'Claude API error (could not parse details)'
      =/  [msg=@t typ=@t]  p.error-msg
      (crip "Claude API {(trip typ)}: {(trip msg)}")
    ::  Add error message as an assistant message so user sees it
    ;<  =bowl:gall  bind:m  get-bowl:io
    =/  error-timestamp=@ud
      =/  all-timestamps=(list @ud)  (turn (tap:((on @ud message:claude) lth) messages-by-time.chat) head)
      ?~  all-timestamps  (unm:chrono:userlib now.bowl)
      (add (snag 0 (flop all-timestamps)) 1)
    =/  error-content=json
      :-  %a
      :~  %-  pairs:enjs:format
          :~  ['type' s+'text']
              ['text' s+err-text]
          ==
      ==
    =/  error-msg=message:claude  ['assistant' error-content %error id.chat 0 0 0 0]
    =/  chat-with-error=chat:claude
      (add-message:chat-index chat error-timestamp error-msg)
    (pure:m [err-text chat-with-error])
  ::  Check stop_reason to see if Claude wants to use a tool
  =/  stop-reason
    %-  mule
    |.
    %.  u.jon
    %-  ot:dejs:format
    :~  ['stop_reason' so:dejs:format]
    ==
  ?:  ?=(%| -.stop-reason)
    ~&  >  'Failed to parse stop_reason'
    ~&  >  p.stop-reason
    =/  json-dump=@t  (en:json:html u.jon)
    (pure:m [(crip "Error parsing stop_reason. Full JSON: {(trip json-dump)}") chat])
  ::  If it's tool_use, extract and execute the tool, then continue conversation
  ?:  =(p.stop-reason 'tool_use')
    ::  Extract the full content array (with tool_use blocks)
    =/  content-array
      %-  mule
      |.
      %.  u.jon
      %-  ot:dejs:format
      :~  ['content' same]
      ==
    ?:  ?=(%| -.content-array)
      =/  json-dump=@t  (en:json:html u.jon)
      (pure:m [(crip "Error: Could not parse content array. Full JSON: {(trip json-dump)}") chat])
    ::  Add assistant's tool_use message using helper
    ;<  =bowl:gall  bind:m  get-bowl:io
    ::  Find the highest timestamp in existing messages and add 1
    =/  last-timestamp=@ud
      =/  all-timestamps=(list @ud)  (turn (tap:((on @ud message:claude) lth) messages-by-time.chat) head)
      ?~  all-timestamps  (unm:chrono:userlib now.bowl)
      (add (snag 0 (flop all-timestamps)) 1)
    =/  assistant-timestamp=@ud  last-timestamp
    =/  assistant-msg=message:claude  ['assistant' p.content-array %normal id.chat 0 0 0 0]
    =/  chat-with-tool=chat:claude
      (add-message:chat-index chat assistant-timestamp assistant-msg)
    ::  Parse content array to separate text and tool_use blocks
    =/  content-blocks
      %-  mule
      |.
      %.  p.content-array
      %-  ar:dejs:format
      |=  block=json
      ^-  [type=@t data=json]
      =/  block-type
        %.  block
        %-  ot:dejs:format
        :~  ['type' so:dejs:format]
        ==
      [block-type block]
    ?:  ?=(%| -.content-blocks)
      =/  json-dump=@t  (en:json:html u.jon)
      (pure:m [(crip "Error: Could not parse content blocks. Full JSON: {(trip json-dump)}") chat])
    ::  Filter out just the tool_use blocks
    =/  tool-calls=(list [@t @t json])
      %+  murn  p.content-blocks
      |=  [type=@t block=json]
      ^-  (unit [@t @t json])
      ?.  =(type 'tool_use')  ~
      =/  parsed
        %-  mule
        |.
        %.  block
        %-  ot:dejs:format
        :~  ['id' so:dejs:format]
            ['name' so:dejs:format]
            ['input' same]
        ==
      ?:  ?=(%| -.parsed)  ~
      `p.parsed
    ?~  tool-calls
      =/  json-dump=@t  (en:json:html u.jon)
      (pure:m [(crip "Error: No tool calls found in tool_use response. Full JSON: {(trip json-dump)}") chat])
    ::  Execute ALL tool calls sequentially and collect results
    =|  tool-results=(list json)
    =/  remaining-tools=(list [@t @t json])  tool-calls
    =/  current-chat=chat:claude  chat-with-tool
    |-  ^-  form:m
    ?~  remaining-tools
      ::  All tools executed, build tool_result message
      ::  Get highest timestamp from current messages and add 1
      =/  last-timestamp=@ud
        =/  all-timestamps=(list @ud)  (turn (tap:((on @ud message:claude) lth) messages-by-time.current-chat) head)
        ?~  all-timestamps  *@ud
        (snag 0 (flop all-timestamps))
      =/  tool-result-timestamp=@ud  (add last-timestamp 1)
      =/  tool-result-content=json  [%a (flop tool-results)]
      =/  user-msg=message:claude  ['user' tool-result-content %normal id.current-chat 0 0 0 0]
      =/  chat-with-result=chat:claude
        (add-message:chat-index current-chat tool-result-timestamp user-msg)
      ::  Recursively call Claude again with all tool results
      (send-message api-key ai-model chat-with-result chats user-timezone)
    =/  [tool-id=@t tool-name=@t tool-input=json]  i.remaining-tools
    ::  Call tool directly from lib/tools with chat context
    ~&  >  "Calling tool '{<tool-name>}' for chat-id: {<id.current-chat>}"
    ::  Extract arguments from tool-input JSON and add chat_id
    =/  arguments=(map @t json)
      ?.  ?=([%o *] tool-input)  ~
      (~(put by p.tool-input) '_chat_id' s+(scot %ux id.current-chat))
    ::  Execute tool directly
    ;<  result=tool-result:tools  bind:m  (execute-tool:tools tool-name arguments)
    ::  Extract text from result
    =/  result-text=@t
      ?-  -.result
        %text   text.result
        %error  (crip "Error: {(trip message.result)}")
      ==
    ::  Build this tool_result block
    =/  tool-result=json
      %-  pairs:enjs:format
      :~  ['type' s+'tool_result']
          ['tool_use_id' s+tool-id]
          ['content' s+result-text]
      ==
    ::  Add to results and continue with next tool
    $(remaining-tools t.remaining-tools, tool-results [tool-result tool-results], current-chat current-chat)
  ::  Otherwise, extract text response as normal
  =/  content-array
    %-  mule
    |.
    %.  u.jon
    %-  ot:dejs:format
    :~  ['content' same]
    ==
  ?:  ?=(%| -.content-array)
    =/  json-dump=@t  (en:json:html u.jon)
    (pure:m [(crip "Error: Could not parse content array. Full JSON: {(trip json-dump)}") chat])
  ::  Extract just the text from content blocks
  =/  parsed
    %-  mule
    |.
    %.  p.content-array
    %-  ar:dejs:format
    %-  ot:dejs:format
    :~  ['text' so:dejs:format]
    ==
  ?:  ?=(%| -.parsed)
    =/  json-dump=@t  (en:json:html u.jon)
    (pure:m [(crip "Error: Could not parse text content. Full JSON: {(trip json-dump)}") chat])
  =/  texts=(list @t)  p.parsed
  ?~  texts
    =/  json-dump=@t  (en:json:html u.jon)
    (pure:m [(crip "Error: Empty content array. Full JSON: {(trip json-dump)}") chat])
  ::  Add assistant's text response using helper
  ::  Get highest timestamp from existing messages and add 1
  =/  last-timestamp=@ud
    =/  all-timestamps=(list @ud)  (turn (tap:((on @ud message:claude) lth) messages-by-time.chat) head)
    ?~  all-timestamps  *@ud
    (snag 0 (flop all-timestamps))
  =/  assistant-timestamp=@ud  (add last-timestamp 1)
  =/  assistant-msg=message:claude  ['assistant' p.content-array %normal id.chat 0 0 0 0]
  =/  updated-chat=chat:claude
    (add-message:chat-index chat assistant-timestamp assistant-msg)
  (pure:m [i.texts updated-chat])
--
