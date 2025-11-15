/-  *master
/+  *ui-layout, sailbox, fi=feather-icons, ui-claude
|%
++  telegram-card
  ^-  manx
  ;div(style "padding: 1.5rem; background: var(--b1); border-radius: 8px; border: 1px solid var(--b2); box-sizing: border-box; max-width: 100%; overflow: hidden;")
    ;h2(style "margin-bottom: 1rem; font-size: clamp(1.25rem, 4vw, 1.5rem); word-wrap: break-word;"): Telegram Notifications
    ;p(style "margin-bottom: 1rem; opacity: 0.8; font-size: clamp(0.9rem, 2.5vw, 1rem); word-wrap: break-word;"): Send yourself a quick notification
    ;form(method "post", action "/master/telegram")
      ;input
        =type         "text"
        =name         "message"
        =placeholder  "Enter message..."
        =required     ""
        =style        "width: 100%; padding: 0.875rem; margin-bottom: 1rem; border: 1px solid var(--b2); border-radius: 6px; background: var(--b0); color: var(--f0); font-size: 1rem; min-height: 44px; box-sizing: border-box;";
      ;button
        =type   "submit"
        =style  "width: 100%; padding: 0.875rem; background: var(--f-3); color: var(--b0); border: none; border-radius: 6px; cursor: pointer; font-weight: bold; font-size: 1rem; min-height: 44px; box-sizing: border-box;"
        Send Notification
      ==
    ==
  ==
::
++  simple-sse-test
  ^-  manx
  =/  content=manx
    ;div(style "max-width: 600px; margin: 0 auto; padding: 2rem;")
      ;h1(style "margin-bottom: 2rem;"): Simple SSE Test
      ;div(hx-ext "sse", sse-connect "/master/test-sse", sse-swap "/test/counter", style "padding: 2rem; background: var(--b1); border: 1px solid var(--b2); border-radius: 8px; font-size: 2rem; text-align: center; margin-bottom: 1rem;")
        ; Waiting...
      ==
      ;form(hx-post "/master/test-sse")
        ;input(type "hidden", name "action", value "start");
        ;button.p3.b-3.f-3.br2.hover.pointer(type "submit", style "outline: none;"): Start Counter
      ==
    ==
  (htmx-page "SSE Test" %.y ~ content)
::
++  handle-simple-sse
  |=  $:  =bowl:gall
          state=vase
          args=(list [key=@t value=@t])
          id=(unit @t)
          event=(unit @t)
      ==
  ^-  wain
  =/  s  !<(state-0 state)
  ~&  >  "handle-simple-sse called with event {<event>}"
  ?+    event  !!
      [~ %'/test/counter']
    ::  Read counter from ball
    =/  counter=@ud  (~(got-cage-as ba:tarball ball.s) /state 'counter.ud' @ud)
    ~&  >  "Returning counter value: {<counter>}"
    %-  manx-to-wain:sailbox
    ;div: Count: {(scow %ud counter)}
  ==
::
++  home-page
  ^-  manx
  =/  mobile-styles=@t
    '''
    html, body {
      overflow-x: hidden;
      max-width: 100vw;
      margin: 0;
      padding: 0;
    }
    '''
  =/  content=manx
    ;div(style "max-width: min(1200px, 100vw); width: 100%; box-sizing: border-box; margin: 0 auto; padding: 1rem;")
      ;div(style "text-align: center; margin-bottom: 1.5rem;")
        ;h1(style "font-size: clamp(1.75rem, 5vw, 3rem); margin-bottom: 0.5rem; word-wrap: break-word;"): Master
        ;p(style "font-size: clamp(0.9rem, 3vw, 1.2rem); opacity: 0.8; word-wrap: break-word;"): Your Personal Everything App
      ==
      ;div(style "display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 280px), 1fr)); gap: 1rem; margin-bottom: 1.5rem; width: 100%;")
        ;+  claude-card:ui-claude
        ;+  telegram-card
      ==
      ;div(style "text-align: center; opacity: 0.6; font-size: 0.85rem;")
        ;p: Built on Urbit
      ==
    ==
  (htmx-page "Master - Home" %.y `mobile-styles content)
--
