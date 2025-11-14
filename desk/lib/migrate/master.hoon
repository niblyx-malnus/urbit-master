/+  tarball
|%
::  Get ball version from /version file (returns 0 if not found)
::
++  get-ball-version
  |=  =ball:tarball
  ^-  @ud
  =/  maybe-content=(unit content:tarball)  (~(get ba:tarball ball) / 'version')
  ?~  maybe-content  0
  ?.  ?=([%cage *] u.maybe-content)  0
  =/  =cage  cage.u.maybe-content
  ?.  =(%txt p.cage)  0
  (rash !<(@t q.cage) dem)
::  Set ball version in /version file
::
++  set-ball-version
  |=  [=ball:tarball version=@ud]
  ^-  ball:tarball
  (~(put ba:tarball ball) / 'version' [%cage ~ [%txt !>((crip (a-co:co version)))]])
::  Migrate ball to latest version
::
++  migrate-ball
  |=  =ball:tarball
  ^-  ball:tarball
  ::  Add version file if it doesn't exist
  =/  has-version=?  (~(has ba:tarball ball) / 'version')
  =?  ball  !has-version
    (set-ball-version ball 0)
  =/  current-version=@ud  (get-ball-version ball)
  =/  latest-version=@ud  0  ::  Update this as we add migrations
  ?:  =(current-version latest-version)
    ball
  ::  Apply migrations in sequence
  =/  migrated=ball:tarball  ball
  ::  Example migration from 0 to 1:
  ::  =?  migrated  =(current-version 0)
  ::    (migrate-0-to-1 migrated)
  (set-ball-version migrated latest-version)
--
