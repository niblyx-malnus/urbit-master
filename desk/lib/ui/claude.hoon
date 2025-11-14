/-  *master
/+  *ui-layout, sailbox, fi=feather-icons, claude, pytz, pprint=time-pprint
|%
::  Helper: check if chat is waiting for Claude's response
::
++  is-chat-thinking
  |=  messages=((mop @ud claude-message) lth)
  ^-  ?
  =/  history=(list claude-message)  (turn (tap:((on @ud claude-message) lth) messages) tail)
  ?~  history  %.n  ::  empty chat = not thinking
  =/  last-msg=claude-message  (snag 0 (flop history))
  =(role.last-msg 'user')  ::  if last message is from user, we're waiting
::
++  handle-claude-sse
  |=  $:  =bowl:gall
          state=vase
          chat-id=@ux
          args=(list [key=@t value=@t])
          id=(unit @t)
          event=(unit @t)
      ==
  ^-  wain
  =/  state-data=state-0  !<(state-0 state)
  =/  user-timezone=@t
    (fall (~(get-cage-as ba:tarball ball.state-data) /config 'timezone.txt' @t) 'UTC')
  ~&  >  "handle-claude-sse called for chat {(hexn:sailbox chat-id)} with event {<event>}"
  =/  chat=(unit claude-chat)  (~(get by claude-chats.state-data) chat-id)
  ?~  chat
    %-  manx-to-wain:sailbox
    ;div: Chat not found
  ?+    event  !!
      [~ %message-update]
    ~&  >  "Rendering message-update SSE event with id {<id>}"
    ::  Convert mop to list for rendering
    =/  messages=(list claude-message)
      (turn (tap:((on @ud claude-message) lth) messages-by-time.u.chat) tail)
    ::  Get the specific message by timestamp from mop
    =/  message-to-render=(unit claude-message)
      ?~  messages
        ~&  >  "No messages"
        ~
      ?~  id
        ~&  >  "No id provided, using last message"
        :-  ~
        (snag 0 (flop `(list claude-message)`messages))
      ::  Parse timestamp from SSE id
      =/  msg-timestamp=@ud  (slav %ud u.id)
      ~&  >  "Looking up message at timestamp {<msg-timestamp>}"
      (get:((on @ud claude-message) lth) messages-by-time.u.chat msg-timestamp)
    ?~  message-to-render
      ~&  >  "No message to render"
      %-  manx-to-wain:sailbox
      ;div;
    ::  Get timestamp - either from id or find it in the mop
    =/  timestamp=@ud
      ?^  id
        (slav %ud u.id)
      ::  If no id, find the timestamp of the last message
      =/  all-msgs=(list [@ud claude-message])  (tap:((on @ud claude-message) lth) messages-by-time.u.chat)
      ?~  all-msgs  *@ud
      (head (rear all-msgs))
    =/  is-user=?  =(role.u.message-to-render 'user')
    =/  is-error=?  =(type.u.message-to-render %error)
    ~&  >  "Message role: {<role.u.message-to-render>}"
    =/  blocks=(list [@t @t])  (parse-message-blocks content.u.message-to-render)
    ~&  >  "Parsed {<(lent blocks)>} blocks"
    ::  Render all blocks for this message
    =/  rendered-blocks=(list manx)
      %+  turn  blocks
      |=  [block-type=@t text=@t]
      (render-message-block is-user is-error block-type text timestamp user-timezone)
    ::  Wrap blocks with hx-swap-oob
    =/  wrapper=manx
      ;div(hx-swap-oob "beforeend:#messages")
        ;*  rendered-blocks
      ==
    ::  Also remove the placeholder if it exists (for first message)
    =/  placeholder-remover=manx
      ;div(hx-swap-oob "delete:#chat-placeholder");
    ::  Update thinking indicator based on current chat state
    =/  is-thinking=?  (is-chat-thinking messages-by-time.u.chat)
    =/  thinking-indicator=manx
      ?:  is-thinking
        ;div(id "thinking-indicator", hx-swap-oob "outerHTML:#thinking-indicator", style "position: sticky; bottom: 0; left: 50%; transform: translateX(-50%); width: fit-content; padding: 0.75rem 1.25rem; margin-top: 1rem; background: var(--b2); border: 1px solid var(--b3); border-radius: 20px; font-style: italic; opacity: 0.85; font-size: 0.9rem; box-shadow: 0 2px 8px rgba(0,0,0,0.1); z-index: 10;")
          ; Claude is thinking...
        ==
      ;div(id "thinking-indicator", hx-swap-oob "outerHTML:#thinking-indicator", style "display: none;");
    ::  Combine all out-of-band swaps
    =/  combined=wain
      :(welp (manx-to-wain:sailbox wrapper) (manx-to-wain:sailbox placeholder-remover) (manx-to-wain:sailbox thinking-indicator))
    ~&  >  "SSE response has {<(lent combined)>} lines (is-thinking: {<is-thinking>})"
    combined
      [~ %title-update]
    ~&  >  "Rendering title-update SSE event"
    ::  Return updated chat title with out-of-band swap
    %-  manx-to-wain:sailbox
    ;div(hx-swap-oob "innerHTML:#chat-title")
      ; {(trip name.u.chat)}
    ==
  ==
::
++  claude-card
  ^-  manx
  ;div(style "padding: 1.5rem; background: var(--b1); border-radius: 8px; border: 1px solid var(--b2); box-sizing: border-box; max-width: 100%; overflow: hidden;")
    ;h2(style "margin-bottom: 1rem; font-size: clamp(1.25rem, 4vw, 1.5rem); word-wrap: break-word;"): Claude Chat
    ;p(style "margin-bottom: 1.5rem; opacity: 0.8; font-size: clamp(0.9rem, 2.5vw, 1rem); word-wrap: break-word;"): Chat with Claude AI through your Urbit ship
    ;a(href "/master/claude", style "display: inline-block; width: 100%; text-align: center; padding: 0.875rem; background: var(--f-3); color: var(--b0); border-radius: 6px; text-decoration: none; font-weight: bold; font-size: 1rem; min-height: 44px; box-sizing: border-box;"): Start Chat
  ==
::
++  render-message-block
  |=  [is-user=? is-error=? block-type=@t text=@t timestamp=@ud tz-name=@t]
  ^-  manx
  =/  bg-style=@t
    ::  Check if this is an error message first
    ?:  is-error
      'background: #fee; border: 1px solid #fcc; align-self: flex-start; color: #c33;'
    ::  Check block type - tool blocks get special styling
    ?:  =(block-type 'tool_use')
      'background: var(--b2); align-self: flex-start; font-style: italic; opacity: 0.8; font-size: 0.9rem;'
    ?:  =(block-type 'tool_result')
      'background: var(--b2); align-self: flex-start; font-size: 0.85rem; opacity: 0.7; border-left: 3px solid var(--b3);'
    ::  For text blocks, use role to determine styling
    ?:  is-user
      'background: var(--f-3); color: var(--b0); align-self: flex-end;'
    ::  Assistant text
    'background: var(--b0); align-self: flex-start;'
  ::  Text blocks get markdown rendering, tool blocks stay as plain text
  =/  use-markdown=?  =(block-type 'text')
  =/  timestamp-text=tape  (format-timestamp timestamp tz-name)
  ::  Copy button
  =/  copy-button=manx
    ;button(class "copy-btn", onclick "copyMessage(this);", title "copy", style "display: inline-flex; align-items: center; margin-left: 0.5rem; opacity: 0; transition: opacity 0.2s; background: none; border: 1px solid currentColor; border-radius: 4px; cursor: pointer; padding: 0.125rem 0.25rem; color: currentColor; font-size: 0.7rem; vertical-align: middle;")
      ;+  (make:fi 'copy')
    ==
  ::  Branch button (using git-branch icon)
  =/  branch-button=manx
    ;button(class "branch-btn", onclick "branchFrom('{(a-co:co timestamp)}');", title "branch", style "display: inline-flex; align-items: center; margin-left: 0.5rem; opacity: 0; transition: opacity 0.2s; background: none; border: 1px solid currentColor; border-radius: 4px; cursor: pointer; padding: 0.125rem 0.25rem; color: currentColor; font-size: 0.7rem; vertical-align: middle;")
      ;+  (make:fi 'git-branch')
    ==
  ::  Timestamp footer with copy and branch buttons (single source of truth)
  =/  timestamp-footer=manx
    ;div(style "font-size: 0.75rem; opacity: 0.5; padding-top: 0.25rem; white-space: nowrap; cursor: default; user-select: none;", title "{timestamp-text} ({(trip tz-name)})")
      ; {timestamp-text}
      ;+  copy-button
      ;+  branch-button
    ==
  ?:  use-markdown
    ;div(class "message-group", data-timestamp "{(a-co:co timestamp)}", style "padding: 0.75rem; {(trip bg-style)} border-radius: 6px; max-width: 80%; min-width: 140px;")
      ;div(class "markdown-content", data-message-text "")
        ; {(trip text)}
      ==
      ;+  timestamp-footer
    ==
  ;div(class "message-group", data-timestamp "{(a-co:co timestamp)}", style "padding: 0.75rem; {(trip bg-style)} border-radius: 6px; max-width: 80%; min-width: 140px; white-space: pre-wrap;")
    ;div(data-message-text "")
      ; {(trip text)}
    ==
    ;+  timestamp-footer
  ==
::
++  parse-message-blocks
  |=  content=json
  ^-  (list [@t @t])
  =/  parsed
    %-  mule
    |.
    %.  content
    %-  ar:dejs:format
    |=  block=json
    ^-  [@t @t]
    =/  block-type
      %.  block
      %-  ot:dejs:format
      :~  ['type' so:dejs:format]
      ==
    ?+  block-type  ['unknown' (en:json:html block)]
      %'text'
        =/  txt
          %.  block
          %-  ot:dejs:format
          :~  ['text' so:dejs:format]
          ==
        ['text' txt]
      %'tool_use'
        =/  tool-info
          %.  block
          %-  ot:dejs:format
          :~  ['name' so:dejs:format]
          ==
        ['tool_use' (cat 3 '[using tool: ' (cat 3 tool-info ']'))]
      %'tool_result'
        =/  result
          %.  block
          %-  ot:dejs:format
          :~  ['content' so:dejs:format]
          ==
        ['tool_result' result]
    ==
  ?:  ?=(%| -.parsed)
    ~[['error' (en:json:html content)]]
  p.parsed
::
++  format-timestamp
  |=  [timestamp=@ud tz-name=@t]
  ^-  tape
  =/  utc-da=@da  (from-unix-ms:chrono:userlib timestamp)
  =/  tz-result=(unit [i=@ud d=@da])  (utc-to-tz:~(. zn:pytz tz-name) utc-da)
  ?~  tz-result
    ::  Fallback to UTC if timezone conversion fails
    =/  date-struct=date  (yore utc-da)
    =/  month=tape  (scow %ud m.date-struct)
    =/  day=tape  (scow %ud d.t.date-struct)
    =/  hour=tape  (scow %ud h.t.date-struct)
    =/  minute=tape  (scow %ud m.t.date-struct)
    "{month}/{day} {hour}:{minute} UTC"
  ::  Format timezone-aware datetime
  =/  tz-da=@da  d.u.tz-result
  =/  tz-struct=date  (yore tz-da)
  =/  month=tape  (scow %ud m.tz-struct)
  =/  day=tape  (scow %ud d.t.tz-struct)
  ::  Format time as HH:MM with am/pm
  =/  hour-24=@ud  h.t.tz-struct
  =/  minute=@ud   m.t.tz-struct
  =/  is-pm=?      (gte hour-24 12)
  =/  hour-12=@ud  ?:  =(hour-24 0)  12
                   ?:  (lte hour-24 12)  hour-24
                   (sub hour-24 12)
  =/  minute-str=tape
    ?:  (lth minute 10)  "0{(scow %ud minute)}"
    (scow %ud minute)
  "{month}/{day} {(scow %ud hour-12)}:{minute-str}{?:(is-pm "pm" "am")}"
::
++  render-timestamp
  |=  [timestamp=@ud tz-name=@t]
  ^-  manx
  =/  timestamp-text=@t  (crip (format-timestamp timestamp tz-name))
  ;div(style "font-size: 0.75rem; color: var(--b1); opacity: 0.5; padding: 0.25rem 0.75rem; text-align: right;")
    ; {(trip timestamp-text)}
  ==
::
++  render-message
  |=  [timestamp=@ud msg=claude-message tz-name=@t]
  ^-  (list manx)
  =/  blocks=(list [@t @t])  (parse-message-blocks content.msg)
  =/  is-user=?  =(role.msg 'user')
  =/  is-error=?  =(type.msg %error)
  %+  turn  blocks
  |=  [block-type=@t text=@t]
  (render-message-block is-user is-error block-type text timestamp tz-name)
::
++  chat-page
  |=  [chat=claude-chat chats=(map @ux claude-chat) user-tz=@t =claude-creds]
  ^-  manx
  ::  Get only last 50 messages for initial render
  =/  message-list=(list [@ud claude-message])
    (get-messages-page:claude messages-by-time.chat ~ 50)
  ::  Get earliest timestamp for "load more" functionality
  =/  earliest-timestamp=(unit @ud)
    ?~  message-list  ~
    `(head (head message-list))
  ::  Check if we're showing the first message (no more to load)
  =/  first-timestamp=(unit @ud)
    =/  all-messages=(list [@ud claude-message])  (tap:((on @ud claude-message) lth) messages-by-time.chat)
    ?~  all-messages  ~
    `(head (head all-messages))
  =/  has-more=?
    ?&  ?=(^ earliest-timestamp)
        ?=(^ first-timestamp)
        !=(u.earliest-timestamp u.first-timestamp)
    ==
  =/  mobile-styles=@t
    '''
    html, body {
      overflow-x: hidden;
      max-width: 100vw;
      margin: 0;
      padding: 0;
    }
    .sidebar {
      width: 350px;
      background: var(--b1);
      border-right: 1px solid var(--b2);
      position: fixed;
      height: 100vh;
      overflow-y: auto;
      padding: 1rem;
      box-sizing: border-box;
      transition: transform 0.3s ease;
      z-index: 1000;
    }
    .sidebar.collapsed {
      transform: translateX(-350px);
    }
    .main-content {
      margin-left: 350px;
      transition: margin-left 0.3s ease;
    }
    .main-content.sidebar-collapsed {
      margin-left: 0;
    }
    .sidebar-toggle {
      background: none;
      border: none;
      padding: 0.5rem;
      cursor: pointer;
      color: var(--f0);
      opacity: 0.7;
      display: flex;
      align-items: center;
      margin-bottom: 1rem;
    }
    .sidebar-toggle:hover {
      opacity: 1;
    }
    .sidebar-toggle-fixed {
      position: fixed;
      top: 1rem;
      left: 1rem;
      z-index: 1001;
      background: var(--b1);
      border: 1px solid var(--b2);
      border-radius: 6px;
      padding: 0.5rem;
      cursor: pointer;
      color: var(--f0);
      opacity: 0;
      pointer-events: none;
      transition: opacity 0.3s ease;
      box-shadow: 0 2px 8px rgba(0,0,0,0.2);
    }
    .sidebar-toggle-fixed.visible {
      opacity: 0.7;
      pointer-events: auto;
    }
    .sidebar-toggle-fixed.visible:hover {
      opacity: 1;
    }
    @media (max-width: 768px) {
      .sidebar {
        width: 280px;
        transform: translateX(-280px);
      }
      .sidebar:not(.collapsed) {
        transform: translateX(0);
      }
      .main-content {
        margin-left: 0;
      }
      .sidebar-toggle-fixed.visible {
        opacity: 0.7;
        pointer-events: auto;
      }
      .sidebar-toggle-fixed:not(.visible) {
        opacity: 0;
        pointer-events: none;
      }
      .sidebar-toggle {
        position: absolute;
        top: 1rem;
        right: 1rem;
        margin-bottom: 0;
      }
    }
    /* Markdown styling */
    .markdown-content {
      line-height: 1.6;
    }
    .markdown-content p {
      margin: 0.5rem 0;
    }
    .markdown-content ul, .markdown-content ol {
      margin: 0.5rem 0;
      padding-left: 1.5rem;
    }
    .markdown-content li {
      margin: 0.25rem 0;
    }
    .markdown-content strong {
      font-weight: bold;
    }
    .markdown-content em {
      font-style: italic;
    }
    .markdown-content code {
      background: var(--b2);
      padding: 0.125rem 0.25rem;
      border-radius: 3px;
      font-family: monospace;
      font-size: 0.9em;
    }
    .markdown-content pre {
      background: var(--b2);
      padding: 0.75rem;
      border-radius: 6px;
      overflow-x: auto;
      margin: 0.5rem 0;
    }
    .markdown-content pre code {
      background: none;
      padding: 0;
    }
    .markdown-content h1, .markdown-content h2, .markdown-content h3 {
      margin: 1rem 0 0.5rem 0;
      font-weight: bold;
    }
    .markdown-content h1 { font-size: 1.5em; }
    .markdown-content h2 { font-size: 1.3em; }
    .markdown-content h3 { font-size: 1.1em; }
    '''
  =/  rendered-messages=(list manx)
    ?~  message-list
      :~  ;div
          =id                 "chat-placeholder"
          =style              "padding: 1rem; background: var(--b0); border-radius: 6px; opacity: 0.6; text-align: center;"
          ;p: Start a conversation...
          ==
      ==
    %-  zing
    %+  turn  message-list
    |=  [timestamp=@ud msg=claude-message]
    (render-message timestamp msg user-tz)
  =/  chat-script=tape
    """
    // Check for timezone change and prompt user
    (function() \{
      try \{
        var serverTz = '{(trip user-tz)}';
        var browserTz = Intl.DateTimeFormat().resolvedOptions().timeZone;
        if (browserTz && browserTz !== serverTz) \{
          if (confirm('Server timezone is ' + serverTz + '. Update to browser timezone ' + browserTz + ' and reload?')) \{
            fetch('/master/set-timezone', \{
              method: 'POST',
              headers: \{ 'Content-Type': 'application/x-www-form-urlencoded' },
              body: 'timezone=' + encodeURIComponent(browserTz)
            }).then(function(response) \{
              if (response.ok) \{
                location.reload();
              }
            });
          }
        }
      } catch(e) \{
        console.error('Failed to detect timezone:', e);
      }
    })();

    function editChat(id, name) \{
      var n = prompt('Enter new chat name:', name);
      if (n && n !== name) \{
        fetch('/master/claude/' + id + '/rename', \{
          method: 'POST',
          headers: \{ 'Content-Type': 'application/x-www-form-urlencoded' },
          body: 'name=' + encodeURIComponent(n)
        }).then(r => r.ok ? location.reload() : alert('Failed'));
      }
    }
    function deleteChat(id, name) \{
      if (confirm('Delete "' + name + '"? Cannot be undone.')) \{
        fetch('/master/claude/' + id + '/delete', \{ method: 'POST' })
        .then(r => \{
          if (r.ok) \{
            location.href = location.pathname.includes(id) ? '/master/claude/new' : location.pathname;
            location.reload();
          } else alert('Failed');
        });
      }
    }
    function updateModel(model) \{
      fetch('/master/update-claude-creds', \{
        method: 'POST',
        headers: \{ 'Content-Type': 'application/x-www-form-urlencoded' },
        body: 'model=' + encodeURIComponent(model)
      }).then(r => \{
        if (r.ok) \{
          console.log('Model updated to:', model);
        } else \{
          alert('Failed to update model');
          location.reload();
        }
      });
    }
    // Button-based loading: simple and predictable
    document.addEventListener('DOMContentLoaded', () => \{
      // Set the selected model in the dropdown
      const modelSelect = document.getElementById('model-select');
      if (modelSelect) \{
        const currentModel = modelSelect.getAttribute('data-current-model');
        if (currentModel) \{
          modelSelect.value = currentModel;
        }
      }

      let isLoading = false;
      let earliestTimestamp = {?~(earliest-timestamp "null" (numb:sailbox u.earliest-timestamp))};
      const hasMore = {?:(has-more "true" "false")};
      const messagesDiv = document.getElementById('messages');

      if (messagesDiv && earliestTimestamp !== null && hasMore) \{
        // Create "Load More" button at the top using htmx
        const loadMoreBtn = document.createElement('button');
        loadMoreBtn.id = 'load-more-btn';
        loadMoreBtn.textContent = 'Load More Messages';
        loadMoreBtn.style = 'width: 100%; padding: 0.75rem; margin-bottom: 0.5rem; background: var(--b2); color: var(--f0); border: none; border-radius: 6px; cursor: pointer; font-size: 0.9rem;';
        loadMoreBtn.setAttribute('hx-get', `/master/claude/{(hexn:sailbox id.chat)}/messages?before=$\{earliestTimestamp}&limit=10`);
        loadMoreBtn.setAttribute('hx-swap', 'afterend');
        loadMoreBtn.setAttribute('hx-indicator', '#load-more-btn');
        loadMoreBtn.onclick = () => \{
          if (typeof autoScrollLocked !== 'undefined') \{
            autoScrollLocked = false;
            if (typeof updateLockButton === 'function') updateLockButton();
          }
        };
        messagesDiv.insertBefore(loadMoreBtn, messagesDiv.firstChild);

        // Process the button with htmx
        if (typeof htmx !== 'undefined') \{
          htmx.process(loadMoreBtn);
        }

        // After htmx loads content, render markdown and update button
        document.body.addEventListener('htmx:afterSwap', function(evt) \{
          if (evt.detail.target === loadMoreBtn) \{
            if (typeof renderMarkdown === 'function') renderMarkdown();

            // Update earliest timestamp from newly loaded messages
            const newMessages = Array.from(messagesDiv.querySelectorAll('[data-timestamp]'));
            if (newMessages.length > 0) \{
              earliestTimestamp = parseInt(newMessages[0].dataset.timestamp);
              loadMoreBtn.setAttribute('hx-get', `/master/claude/{(hexn:sailbox id.chat)}/messages?before=$\{earliestTimestamp}&limit=10`);
              htmx.process(loadMoreBtn);
            } else \{
              loadMoreBtn.textContent = 'No more messages';
              loadMoreBtn.disabled = true;
              loadMoreBtn.style.opacity = '0.5';
              loadMoreBtn.removeAttribute('hx-get');
            }
          }
        });
      }
    });

    // Render markdown in all .markdown-content elements
    function renderMarkdown() \{
      document.querySelectorAll('.markdown-content').forEach(el => \{
        if (!el.dataset.rendered) \{
          const markdown = el.textContent;
          el.innerHTML = marked.parse(markdown);
          el.dataset.rendered = 'true';
        }
      });
    }
    // Render on page load and after htmx swaps
    document.addEventListener('DOMContentLoaded', renderMarkdown);
    document.body.addEventListener('htmx:afterSwap', renderMarkdown);
    """
  =/  content=manx
    ;div(style "display: flex; width: 100vw;")
      ;script(src "https://cdn.jsdelivr.net/npm/marked@11.1.1/marked.min.js");
      ;script: {chat-script}
      ;button(class "sidebar-toggle-fixed", onclick "toggleSidebar()")
        ;svg(xmlns "http://www.w3.org/2000/svg", width "20", height "20", viewBox "0 0 24 24", fill "none", stroke "currentColor", stroke-width "2", stroke-linecap "round", stroke-linejoin "round")
          ;line(x1 "3", y1 "12", x2 "21", y2 "12");
          ;line(x1 "3", y1 "6", x2 "21", y2 "6");
          ;line(x1 "3", y1 "18", x2 "21", y2 "18");
        ==
      ==
      ;div(class "sidebar")
        ;button(class "sidebar-toggle", onclick "toggleSidebar()")
          ;svg(xmlns "http://www.w3.org/2000/svg", width "20", height "20", viewBox "0 0 24 24", fill "none", stroke "currentColor", stroke-width "2", stroke-linecap "round", stroke-linejoin "round")
            ;line(x1 "3", y1 "12", x2 "21", y2 "12");
            ;line(x1 "3", y1 "6", x2 "21", y2 "6");
            ;line(x1 "3", y1 "18", x2 "21", y2 "18");
          ==
        ==
        ;div(style "margin-bottom: 1rem;")
          ;a(href "/master", style "display: inline-flex; align-items: center; padding: 0.5rem; text-decoration: none; color: var(--f0); font-size: 0.9rem;")
            ;span(style "margin-right: 0.5rem;"): ←
            ;span: Home
          ==
        ==
        ;div(style "margin-bottom: 1rem; padding: 0.75rem; background: var(--b2); border: 1px solid var(--b3); border-radius: 6px;")
          ;label(style "display: block; font-size: 0.85rem; opacity: 0.8; margin-bottom: 0.5rem;"): AI Model
          ;select(id "model-select", name "model", onchange "updateModel(this.value)", data-current-model (trip ai-model.claude-creds), style "width: 100%; padding: 0.5rem; background: var(--b0); color: var(--f0); border: 1px solid var(--b2); border-radius: 4px; font-size: 0.9rem; cursor: pointer;")
            ;option(value "claude-sonnet-4-5-20250929"): Sonnet 4.5 ($3/$15)
            ;option(value "claude-haiku-4-5"): Haiku 4.5 ($1/$5)
            ;option(value "claude-opus-4-1"): Opus 4.1 ($15/$75)
          ==
          ;div(style "margin-top: 0.5rem; font-size: 0.75rem; opacity: 0.6; line-height: 1.3;")
            ; Pricing: input/output per 1M tokens
          ==
        ==
        ;a(href "/master/claude/new", style "display: block; width: 100%; padding: 0.75rem; margin-bottom: 1rem; background: var(--f-3); color: var(--b0); border-radius: 6px; text-decoration: none; text-align: center; font-weight: bold;")
          ; + New Chat
        ==
        ;div(style "display: flex; flex-direction: column; gap: 0.5rem;")
          ;*  %+  turn  ~(tap by chats)
              |=  [chat-list-id=@ux chat-list-chat=claude-chat]
              ^-  manx
              =/  is-active=?  =(chat-list-id id.chat)
              =/  bg-style=@t
                ?:  is-active  'background: var(--b2);'
                'background: var(--b0);'
              ::  Escape single quotes in chat name for JavaScript
              =/  escaped-name=tape
                %-  zing
                %+  turn  (trip name.chat-list-chat)
                |=  c=@tD
                ?:  =(c '\'')  ~['\\' '\'']
                ~[c]
              ;div(style "display: flex; align-items: center; gap: 0.5rem; padding: 0.75rem; {(trip bg-style)} border-radius: 6px; border: 1px solid var(--b2);")
                ;a(href "/master/claude/{(hexn:sailbox chat-list-id)}", id ?:(is-active "chat-title" ""), title "{(trip name.chat-list-chat)}", style "flex: 1; text-decoration: none; color: var(--f0); overflow: hidden; text-overflow: ellipsis; white-space: nowrap;")
                  ; {(trip name.chat-list-chat)}
                ==
                ;button(onclick "editChat('{(hexn:sailbox chat-list-id)}', '{escaped-name}')", style "background: none; border: none; padding: 0.25rem; cursor: pointer; color: var(--f0); opacity: 0.6; display: flex; align-items: center;", onmouseover "this.style.opacity='1'", onmouseout "this.style.opacity='0.6'")
                  ;svg(xmlns "http://www.w3.org/2000/svg", width "16", height "16", viewBox "0 0 24 24", fill "none", stroke "currentColor", stroke-width "2", stroke-linecap "round", stroke-linejoin "round")
                    ;path(d "M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7");
                    ;path(d "M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z");
                  ==
                ==
                ;button(onclick "deleteChat('{(hexn:sailbox chat-list-id)}', '{escaped-name}')", style "background: none; border: none; padding: 0.25rem; cursor: pointer; color: var(--red); opacity: 0.6; display: flex; align-items: center;", onmouseover "this.style.opacity='1'", onmouseout "this.style.opacity='0.6'")
                  ;svg(xmlns "http://www.w3.org/2000/svg", width "16", height "16", viewBox "0 0 24 24", fill "none", stroke "currentColor", stroke-width "2", stroke-linecap "round", stroke-linejoin "round")
                    ;polyline(points "3 6 5 6 21 6");
                    ;path(d "M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2");
                  ==
                ==
              ==
        ==
      ==
      ;div(class "main-content", style "width: 100%; box-sizing: border-box; padding: 1rem; display: flex; flex-direction: column; height: 100vh;")
        ;div(style "text-align: center; margin-bottom: 2rem; position: relative;")
          ;*  ?~  parent.chat  ~
              =/  parent-chat=(unit claude-chat)  (~(get by chats) chat-id.u.parent.chat)
              ?~  parent-chat  ~
              :~  ;a(href "/master/claude/{(hexn:sailbox chat-id.u.parent.chat)}", title "Go to parent: {(trip name.u.parent-chat)}", style "position: absolute; left: 0; top: 0; display: flex; align-items: center; gap: 0.5rem; padding: 0.5rem; background: var(--b1); border: 1px solid var(--b2); border-radius: 6px; color: var(--f0); text-decoration: none; opacity: 0.7; transition: opacity 0.2s;", onmouseover "this.style.opacity='1'", onmouseout "this.style.opacity='0.7'")
                    ;+  (make:fi 'corner-up-left')
                    ;span(style "font-size: 0.9rem;"): Parent
                  ==
              ==
          ;h1(style "font-size: clamp(1.75rem, 5vw, 2.5rem); margin-bottom: 0.5rem;"): Chat with Claude
          ;p(style "font-size: clamp(0.9rem, 3vw, 1rem); opacity: 0.8;"): Ask me anything
        ==
        ::  Hidden SSE connection
        ;div(hx-ext "sse", sse-connect "/master/claude/stream/{(hexn:sailbox id.chat)}", sse-swap "message-update,title-update", style "display:none;");
        ;div(style "display: flex; gap: 0.5rem; align-items: stretch; flex: 1; min-height: 0;")
          ::  Vertical navigation bar
          ;div
            =style  "display: flex; flex-direction: column; justify-content: space-between; background: var(--b2); border: 1px solid var(--b3); border-radius: 8px; width: 2.5rem; flex-shrink: 0;"
            ;button
              =id       "scroll-up-btn"
              =onclick  "scrollToTop();"
              =style    "background: none; border: none; padding: 0.75rem; cursor: pointer; color: var(--f0); opacity: 0.7; display: flex; align-items: center; justify-content: center;"
              =onmouseover  "this.style.opacity='1'"
              =onmouseout   "this.style.opacity='0.7'"
              ;+  (make:fi 'arrow-up')
            ==
            ;button
              =id       "lock-btn"
              =onclick  "toggleAutoScroll();"
              =style    "background: none; border: none; padding: 0.75rem; cursor: pointer; color: var(--f0); opacity: 0.7; display: flex; align-items: center; justify-content: center;"
              =onmouseover  "this.style.opacity='1'"
              =onmouseout   "this.style.opacity='0.7'"
              ;+  (make:fi 'lock')
            ==
            ;button
              =id       "scroll-down-btn"
              =onclick  "scrollToBottom();"
              =style    "background: none; border: none; padding: 0.75rem; cursor: pointer; color: var(--f0); opacity: 0.7; display: flex; align-items: center; justify-content: center;"
              =onmouseover  "this.style.opacity='1'"
              =onmouseout   "this.style.opacity='0.7'"
              ;+  (make:fi 'arrow-down')
            ==
          ==
          ::  Chat container
          ;div
            =id  "chat-container"
            =style  "position: relative; flex: 1; background: var(--b1); border: 1px solid var(--b2); border-radius: 8px; padding: 1.5rem; margin-bottom: 0; min-height: 0; overflow-y: auto; scroll-behavior: smooth;"
            ;div
              =id  "messages"
              =style  "display: flex; flex-direction: column; gap: 1rem;"
              ;*  rendered-messages
            ==
            ::  Thinking indicator - shown when waiting for Claude's response
            ;div
              =id  "thinking-indicator"
              =style  ?:((is-chat-thinking messages-by-time.chat) "position: sticky; bottom: 0; left: 50%; transform: translateX(-50%); width: fit-content; padding: 0.75rem 1.25rem; margin-top: 1rem; background: var(--b2); border: 1px solid var(--b3); border-radius: 20px; font-style: italic; opacity: 0.85; font-size: 0.9rem; box-shadow: 0 2px 8px rgba(0,0,0,0.1); z-index: 10;" "display: none;")
              ; {?:((is-chat-thinking messages-by-time.chat) "Claude is thinking..." "")}
            ==
          ==
        ==
        ;form
          =id            "chat-form"
          =hx-post       "/master/claude/{(hexn:sailbox id.chat)}"
          =hx-target     "#messages"
          =hx-swap       "none"
          =style         "display: flex; gap: 0.5rem; margin-left: 3rem;"
          ;textarea
            =name         "message"
            =id           "message-input"
            =placeholder  "Type your message... (Shift+Enter for new line)"
            =required     ""
            =rows         "1"
            =style        "flex: 1; padding: 0.875rem; border: 1px solid var(--b2); border-radius: 6px; background: var(--b0); color: var(--f0); font-size: 1rem; min-height: 44px; max-height: 200px; resize: vertical; box-sizing: border-box; font-family: inherit;";
          ;button
            =type   "submit"
            =style  "padding: 0.875rem 1.5rem; background: var(--f-3); color: var(--b0); border: none; border-radius: 6px; cursor: pointer; font-weight: bold; font-size: 1rem; min-height: 44px; box-sizing: border-box;"
            ; Send
          ==
        ==
        ;script
          ; var autoScrollLocked = true;
          ; var sidebarCollapsed = window.innerWidth <= 768;
          ; var lockIcon = '<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="11" width="18" height="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>';
          ; var unlockIcon = '<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="11" width="18" height="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0 1 9.9-1"/></svg>';
          ; function copyMessage(button) {
          ;   var messageGroup = button.closest('.message-group');
          ;   var textElement = messageGroup.querySelector('[data-message-text]');
          ;   if (!textElement) return;
          ;   var text = textElement.innerText || textElement.textContent;
          ;   navigator.clipboard.writeText(text).then(function() {
          ;     var originalTitle = button.title;
          ;     button.title = 'copied!';
          ;     setTimeout(function() { button.title = originalTitle; }, 1000);
          ;   }).catch(function(err) {
          ;     console.error('Failed to copy:', err);
          ;   });
          ; }
          ; function branchFrom(timestamp) {
          ;   var chatId = window.location.pathname.split('/').pop();
          ;   var messages = document.querySelectorAll('#messages .message-group[data-timestamp]');
          ;   var messageIndex = -1;
          ;   for (var i = 0; i < messages.length; i++) {
          ;     if (messages[i].getAttribute('data-timestamp') === timestamp) {
          ;       messageIndex = i;
          ;       break;
          ;     }
          ;   }
          ;   if (messageIndex === -1) {
          ;     alert('Could not find message to branch from');
          ;     return;
          ;   }
          ;   fetch('/master/claude/' + chatId + '/branch', {
          ;     method: 'POST',
          ;     headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
          ;     body: 'branch-point=' + messageIndex
          ;   })
          ;   .then(function(response) { return response.text(); })
          ;   .then(function(newChatId) {
          ;     window.location.href = '/master/claude/' + newChatId;
          ;   })
          ;   .catch(function(err) {
          ;     console.error('Branch failed:', err);
          ;     alert('Failed to create branch');
          ;   });
          ; }
          ;
          ; function updateLockButton() {
          ;   var btn = document.getElementById('lock-btn');
          ;   if (btn) btn.innerHTML = autoScrollLocked ? lockIcon : unlockIcon;
          ; }
          ; function toggleSidebar() {
          ;   sidebarCollapsed = !sidebarCollapsed;
          ;   var sidebar = document.querySelector('.sidebar');
          ;   var mainContent = document.querySelector('.main-content');
          ;   var fixedBtn = document.querySelector('.sidebar-toggle-fixed');
          ;   if (sidebarCollapsed) {
          ;     sidebar.classList.add('collapsed');
          ;     mainContent.classList.add('sidebar-collapsed');
          ;     if (fixedBtn) fixedBtn.classList.add('visible');
          ;   } else {
          ;     sidebar.classList.remove('collapsed');
          ;     mainContent.classList.remove('sidebar-collapsed');
          ;     if (fixedBtn) fixedBtn.classList.remove('visible');
          ;   }
          ; }
          ; function toggleAutoScroll() {
          ;   autoScrollLocked = !autoScrollLocked;
          ;   updateLockButton();
          ; }
          ; function scrollToTop() {
          ;   var c = document.getElementById('chat-container');
          ;   if (c) {
          ;     c.scrollTop = 0;
          ;     autoScrollLocked = false;
          ;     updateLockButton();
          ;   }
          ; }
          ; function scrollToBottom() {
          ;   var c = document.getElementById('chat-container');
          ;   if (c) {
          ;     c.scrollTop = c.scrollHeight;
          ;     autoScrollLocked = true;
          ;     updateLockButton();
          ;   }
          ; }
          ;
          ; (function() {
          ;   var c = document.getElementById('chat-container');
          ;   var m = document.getElementById('messages');
          ;   var f = document.getElementById('chat-form');
          ;   var i = document.getElementById('message-input');
          ;   var t = document.getElementById('thinking-indicator');
          ;   var msgCount = 0;
          ;   var observer = null;
          ;
          ;   function scroll() {
          ;     if (c && autoScrollLocked) c.scrollTop = c.scrollHeight;
          ;   }
          ;
          ;   // Initialize sidebar state on load
          ;   if (sidebarCollapsed) {
          ;     var sidebar = document.querySelector('.sidebar');
          ;     var mainContent = document.querySelector('.main-content');
          ;     var fixedBtn = document.querySelector('.sidebar-toggle-fixed');
          ;     if (sidebar) sidebar.classList.add('collapsed');
          ;     if (mainContent) mainContent.classList.add('sidebar-collapsed');
          ;     if (fixedBtn) fixedBtn.classList.add('visible');
          ;   }
          ;
          ;   setTimeout(scroll, 100);
          ;   updateLockButton();
          ;
          ;   if (m && window.MutationObserver) {
          ;     observer = new MutationObserver(function() {
          ;       scroll();
          ;       msgCount++;
          ;       if (msgCount === 1 && t) {
          ;         t.style.display = 'block';
          ;         scroll();
          ;       } else if (msgCount === 2 && t) {
          ;         t.style.display = 'none';
          ;         msgCount = 0;
          ;       }
          ;     });
          ;     observer.observe(m, {childList: true, subtree: true});
          ;   }
          ;   function attachFormHandlers() {
          ;     var f = document.getElementById('chat-form');
          ;     var i = document.getElementById('message-input');
          ;     if (f && !f.dataset.hasListener) {
          ;       f.dataset.hasListener = 'true';
          ;       f.addEventListener('submit', function() {
          ;         setTimeout(function() { if (i) i.value = ''; }, 100);
          ;         msgCount = 0;
          ;       });
          ;     }
          ;     if (i && !i.dataset.hasListener) {
          ;       i.dataset.hasListener = 'true';
          ;       i.addEventListener('keydown', function(e) {
          ;         if (e.key === 'Enter' && !e.shiftKey) {
          ;           e.preventDefault();
          ;           var form = document.getElementById('chat-form');
          ;           if (form) form.requestSubmit();
          ;         }
          ;       });
          ;     }
          ;   }
          ;   attachFormHandlers();
          ;   document.body.addEventListener('htmx:afterSwap', attachFormHandlers);
          ;   window.chatObserver = observer;
          ; })();
        ==
        ;style
          ; @keyframes pulse {
          ;   0%, 100% { opacity: 0.4; }
          ;   50% { opacity: 1; }
          ; }
          ;
          ; .copy-btn svg,
          ; .branch-btn svg {
          ;   width: 12px;
          ;   height: 12px;
          ; }
          ;
          ; .message-group:hover .copy-btn,
          ; .message-group:hover .branch-btn {
          ;   opacity: 1 !important;
          ; }
          ;
          ; .copy-btn:hover,
          ; .branch-btn:hover {
          ;   background: var(--b2) !important;
          ; }
        ==
      ==
    ==
  (htmx-page "Claude Chat" %.y `mobile-styles content)
--
