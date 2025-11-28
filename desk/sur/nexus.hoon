/+  sailbox, tarball
:: exploring the possibility of a directory-specific orchestrator agent
::
|%
+$  card     card:agent:gall       :: to be replaced with local version
++  process  process:fiber:sailbox :: to be replaced with local version
++  nexus
  $_  ^|
  |%
  :: all pokes result in file/directory creation/deletion
  ::
  ++  on-poke
    |~  [bowl:gall cage]
    *[path (unit ball:tarball)]
  :: all files have an associated running process
  :: all running processes should be able to recover proper
  ::   operation based on state alone, even when restarted.
  ::   this is not guaranteed and is a responsibility of the programmer.
  ::
  ++  on-file
    |~  [path mark]
    *process
  :: can send effects when the state of a file/process changes
  ::
  ++  on-diff
    |~  [path cage]
    (list card)
  :: can send effects when a process has completed
  ::
  ++  on-done
    |~  [path cage ack=(unit tang)]
    (list card)
  --
--
