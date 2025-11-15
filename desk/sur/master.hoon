/+  tarball
|%
+$  claude-message
  $:  role=@t
      content=json  ::  Can be string or array of content blocks
      type=?(%normal %error)  ::  Message type for UI styling
      chat-id=@ux  ::  Which chat this message belongs to
      index=@ud  ::  Sequential index in this chat
      timestamp=@ud  ::  When message was created
      cumulative-chars=@ud  ::  Cumulative character count at beginning of this message
      chars=@ud  ::  Character count of this message
  ==
::
:: Conversation Branching Strategy:
::
:: Each chat can be branched from any message, creating a tree of conversations.
:: When a chat is branched:
::   1. New chat is created with parent link (chat-id + message index of branch point)
::   2. Parent chat adds child's ID to its children map (doubly-linked)
::   3. Child conversation inherits context from all ancestors up to branch points
::
:: Context Building for API Calls:
::   - Walk up parent chain: current -> parent -> grandparent -> ...
::   - For each ancestor, include messages from start up to branch point
::   - Concatenate: ancestor[0..branch1] + parent[0..branch2] + current[all]
::   - Apply character cap (~50k chars / ~12k tokens) to fit in context window
::   - If over cap: trim oldest ancestor messages first, always keep current chat
::   - Use messages-by-chars mop to efficiently find trim points
::
:: UI Elements:
::   - Each message has "Branch from here" button
::   - Sidebar shows conversation tree with parent/child relationships
::   - Branch icon/indicator shows which message was branched from
::   - Children map shows: message-index -> chat-id (which message spawned which child)
::
:: MCP Integration:
::   - Tools can traverse conversation tree
::   - Query sibling branches, alternative approaches
::   - Access full conversation history across tree
::
+$  claude-chat
  $:  id=@ux
      name=@t
      parent=(unit [chat-id=@ux branch-point=@ud])  :: (unit [parent-chat-id branch-message-index])
      children=(map @ud @ux)                         :: map from message-index to child-chat-id
      messages-by-time=((mop @ud claude-message) lth)     :: keyed by Unix ms timestamp
      messages-by-index=((mop @ud claude-message) lth)    :: keyed by sequential index
      messages-by-chars=((mop @ud claude-message) lth)    :: keyed by cumulative character count
      next-index=@ud                                       :: next message index to assign
      total-chars=@ud                                      :: total character count so far
      created=@da
  ==
::
+$  telegram-alarm
  $:  id=@da
      message=@t
      wake-time=@da
  ==
::
+$  state-0
  $:  %0
      bindings=(set binding:eyre)
      =ball:tarball
      active-chat=(unit @ux)
      claude-chats=(map @ux claude-chat)
      telegram-alarms=(map @da telegram-alarm)
  ==
--
