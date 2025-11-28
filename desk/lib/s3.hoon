/+  io=sailboxio, tarball
::  S3 (AWS Signature Version 4) library
::  Implements cryptographic signing for AWS S3-compatible storage
::
::  Byte order note: Hoon cords are stored little-endian (LSB first), but
::  cryptographic functions expect big-endian (MSB first). Use (swp 3 ...)
::  to swap byte order before passing cords to HMAC/SHA functions. HMAC
::  output is already big-endian, so only swap it when using as message.
::
|%
::  HMAC-SHA256 with big-endian inputs
::  Expects key and message in big-endian format (use (swp 3 ...) on cords)
::
++  hmac-sha256
  |=  [key=@ msg=@]
  ^-  @
  %+  hmac-sha256l:hmac:crypto
    [(met 3 key) key]
  [(met 3 msg) msg]
::  Derive AWS signing key via nested HMAC operations
::  Implements AWS4-HMAC-SHA256 key derivation
::
++  get-signature-key
  |=  [key=@t date-stamp=@t region=@t service=@t]
  ^-  @
  =/  aws4-key=@  (cat 3 'AWS4' key)
  =/  k-date=@  (hmac-sha256 (swp 3 aws4-key) (swp 3 date-stamp))
  =/  k-region=@  (hmac-sha256 k-date (swp 3 region))
  =/  k-service=@  (hmac-sha256 k-region (swp 3 service))
  (hmac-sha256 k-service (swp 3 'aws4_request'))
::  Convert hash atom to lowercase hexadecimal string
::  Renders 32-byte hash in MSB-first order
::
++  hash-to-hex
  |=  hash=@
  ^-  @t
  =/  hex-chars  "0123456789abcdef"
  =/  result=tape  ""
  =/  byte-count=@ud  32  :: SHA-256 is 32 bytes
  =/  idx=@ud  0
  |-
  ?:  =(idx byte-count)
    (crip result)
  ::  Extract from MSB (byte 31) down to LSB (byte 0)
  =/  byte=@  (cut 3 [(sub (dec byte-count) idx) 1] hash)
  =/  hi=@ud  (div byte 16)
  =/  lo=@ud  (mod byte 16)
  =/  hi-char=@tD  (snag hi hex-chars)
  =/  lo-char=@tD  (snag lo hex-chars)
  $(idx +(idx), result (weld result ~[hi-char lo-char]))
::  SHA256 hash returning lowercase hexadecimal string
::  Swaps cord bytes to big-endian before hashing
::
++  sha256-hash
  |=  data=@
  ^-  @t
  %-  hash-to-hex
  %-  sha-256:sha
  (swp 3 data)
::  Format date as YYYYMMDD
::
++  format-date-stamp
  |=  now=@da
  ^-  @t
  =/  date  (yore now)
  =/  y=tape  (a-co:co y.date)
  =/  m=tape  ?:((lth m.date 10) (weld "0" (a-co:co m.date)) (a-co:co m.date))
  =/  d=tape  ?:((lth d.t.date 10) (weld "0" (a-co:co d.t.date)) (a-co:co d.t.date))
  (crip (weld y (weld m d)))
::  Format date as YYYYMMDDTHHMMSSZ
::
++  format-amz-date
  |=  now=@da
  ^-  @t
  =/  date  (yore now)
  =/  y=tape  (a-co:co y.date)
  =/  mon=tape  ?:((lth m.date 10) (weld "0" (a-co:co m.date)) (a-co:co m.date))
  =/  d=tape  ?:((lth d.t.date 10) (weld "0" (a-co:co d.t.date)) (a-co:co d.t.date))
  =/  h=tape  ?:((lth h.t.date 10) (weld "0" (a-co:co h.t.date)) (a-co:co h.t.date))
  =/  min=tape  ?:((lth m.t.date 10) (weld "0" (a-co:co m.t.date)) (a-co:co m.t.date))
  =/  s=tape  ?:((lth s.t.date 10) (weld "0" (a-co:co s.t.date)) (a-co:co s.t.date))
  (crip (weld y (weld mon (weld d (weld "T" (weld h (weld min (weld s "Z"))))))))
::  Parse S3 LIST XML response to extract object keys
::  Returns list of file keys from <Key> elements
::  Simple string-based extraction for now
::
++  parse-list-response
  |=  xml=@t
  ^-  (list @t)
  =/  xml-text=tape  (trip xml)
  =|  keys=(list @t)
  |-
  ^-  (list @t)
  =/  key-start  (find "<Key>" xml-text)
  ?~  key-start  (flop keys)
  =/  rest=tape  (slag (add u.key-start 5) xml-text)
  =/  key-end  (find "</Key>" rest)
  ?~  key-end  (flop keys)
  =/  key=tape  (scag u.key-end rest)
  %=  $
    xml-text  (slag (add u.key-end 6) rest)
    keys  [(crip key) keys]
  ==
::
::  Extract file keys from S3 LIST HTTP response
::  Takes client-response and parses XML to extract <Key> elements
::
++  extract-list-keys
  |=  =client-response:iris
  ^-  (list @t)
  =/  xml-content=@t
    ?+  client-response  ''
      [%finished * [~ [* [p=@ q=@]]]]
    ;;(@t q.data.u.full-file.client-response)
    ==
  (parse-list-response xml-content)
::
::  Fiber to take S3 LIST response and extract file keys
::  Must be called with io library in scope
::
++  take-s3-list-response
  =/  m  (fiber:io ,(list @t))
  ^-  form:m
  ;<  =client-response:iris  bind:m  take-client-response:io
  (pure:m (extract-list-keys client-response))
::
::  Complete S3 LIST operation as a fiber
::  Takes credentials and prefix, makes request, returns file list
::
++  s3-list
  |=  $:  access-key=@t
          secret-key=@t
          region=@t
          endpoint=@t
          bucket=@t
          prefix=@t
      ==
  =/  m  (fiber:io ,(list @t))
  ^-  form:m
  ;<  now=@da  bind:m  get-time:io
  ::  Build query string for LIST operation
  =/  query-string=@t  (build-list-query prefix)
  ::  Build AWS Signature V4 for LIST request
  =/  [amz-date=@t payload-hash=@t authorization=@t]
    %:  build-signature
      'GET'
      access-key
      secret-key
      region
      endpoint
      bucket
      ''
      query-string
      ~
      now
    ==
  ::  Build request URL and headers
  =/  url=@t  (build-url endpoint bucket '' `query-string)
  =/  headers=(list [@t @t])  (build-headers 'GET' payload-hash amz-date authorization)
  =/  =request:http
    :*  %'GET'
        url
        headers
        ~
    ==
  ;<  ~  bind:m  (send-request:io request)
  ;<  file-keys=(list @t)  bind:m  take-s3-list-response
  (pure:m file-keys)
::
::  Complete S3 GET DIRECTORY operation as a fiber
::  Lists files in directory and fetches each one
::
++  s3-get-directory
  |=  $:  access-key=@t
          secret-key=@t
          region=@t
          endpoint=@t
          bucket=@t
          prefix=@t
      ==
  =/  m  (fiber:io ,~)
  ^-  form:m
  ::  First, list all files in directory
  ;<  file-keys=(list @t)  bind:m
    %:  s3-list
      access-key
      secret-key
      region
      endpoint
      bucket
      prefix
    ==
  ::  Filter out directories (keys ending in /)
  =/  files=(list @t)
    %+  skip  file-keys
    |=(key=@t =((rear (trip key)) '/'))
  ~&  >  "Found {<(lent files)>} files (excluding directories):"
  ~&  >  files
  ::  Fetch each file
  |-
  ?~  files
    (pure:m ~)
  =/  filename=@t  i.files
  ~&  >  "Fetching: {<filename>}"
  ;<  now=@da  bind:m  get-time:io
  ::  Build AWS Signature V4 for GET request
  =/  [amz-date=@t payload-hash=@t authorization=@t]
    %:  build-signature
      'GET'
      access-key
      secret-key
      region
      endpoint
      bucket
      filename
      ''
      ~
      now
    ==
  ::  Build request URL and headers
  =/  url=@t  (build-url endpoint bucket filename ~)
  =/  headers=(list [@t @t])  (build-headers 'GET' payload-hash amz-date authorization)
  =/  =request:http
    :*  %'GET'
        url
        headers
        ~
    ==
  ;<  ~  bind:m  (send-request:io request)
  ;<  =client-response:iris  bind:m  take-client-response:io
  ::  Extract and print file content
  =/  content=@t
    ?+  client-response  ''
      [%finished * [~ [* [p=@ q=@]]]]
    ;;(@t q.data.u.full-file.client-response)
    ==
  ~&  >  "Content of {<filename>}:"
  ~&  >  content
  $(files t.files)
::
::  Helper: Extract Content-Type from HTTP response headers
::
++  extract-content-type
  |=  response-headers=(list [key=@t value=@t])
  ^-  (unit @t)
  |-  ^-  (unit @t)
  ?~  response-headers  ~
  ?:  =(key.i.response-headers 'content-type')
    `value.i.response-headers
  $(response-headers t.response-headers)
::
::  Helper: Extract filename from S3 key (handles both paths and simple names)
::
++  extract-filename
  |=  s3-key=@t
  ^-  @ta
  =/  key-text=tape  (trip s3-key)
  =/  last-slash=(unit @ud)  (find "/" (flop key-text))
  ?~  last-slash
    ::  No slashes, the whole key is the filename
    s3-key
  ::  Has slashes, take everything after the last slash
  (crip (slag (sub (lent key-text) u.last-slash) key-text))
::
::  Helper: Process downloaded S3 content and save to ball with proper typing
::  Handles Content-Type extraction, mime type determination, and cage conversion
::
++  save-downloaded-file
  |=  $:  response-headers=(list [key=@t value=@t])
          content=@t
          s3-key=@t
          target-path=path
      ==
  =/  m  (fiber:io ,~)
  ^-  form:m
  ::  Extract filename from S3 key
  =/  filename=@ta  (extract-filename s3-key)
  ::  Extract Content-Type from S3 response headers
  =/  content-type=(unit @t)  (extract-content-type response-headers)
  ~&  >  ['S3 Content-Type header:' content-type]
  ::  Parse file extension
  =/  ext=(unit @ta)  (parse-extension:tarball filename)
  ~&  >  ['Parsed extension:' ext]
  ::  Determine mime type using tarball helper
  =/  mime-type=path  (determine-mime-type:tarball content-type filename)
  ~&  >  ['Final mime type:' mime-type]
  =/  =mime  [mime-type (as-octs:mimes:html content)]
  ::  Try to convert to typed cage if we have an extension
  ;<  =ball:tarball  bind:m  get-state:io
  ;<  conversions=(map mars:clay tube:clay)  bind:m  (get-mark-conversions:io ball)
  =/  typed-cage=(unit cage)
    ?~  ext  ~
    (mime-to-cage:tarball conversions filename mime)
  ::  Save as typed cage or fallback to mime
  ?^  typed-cage
    ;<  ~  bind:m  (put-cage:io target-path filename u.typed-cage)
    ~&  >  "Downloaded {<s3-key>} to {<target-path>}/{<filename>} as {<p.u.typed-cage>}"
    (pure:m ~)
  ;<  ~  bind:m  (put-cage:io target-path filename [%mime !>(mime)])
  ~&  >  "Downloaded {<s3-key>} to {<target-path>}/{<filename>} as %mime"
  (pure:m ~)
::
::  Download a single file from S3 and save to ball
::
++  s3-download-file-to-ball
  |=  $:  access-key=@t
          secret-key=@t
          region=@t
          endpoint=@t
          bucket=@t
          s3-key=@t
          ball-path=path
      ==
  =/  m  (fiber:io ,~)
  ^-  form:m
  ~&  >  "Downloading {<s3-key>} to ball path {<ball-path>}..."
  ;<  now=@da  bind:m  get-time:io
  ::  Build AWS Signature V4 for GET request
  =/  [amz-date=@t payload-hash=@t authorization=@t]
    %:  build-signature
      'GET'
      access-key
      secret-key
      region
      endpoint
      bucket
      s3-key
      ''
      ~
      now
    ==
  ::  Build request URL and headers
  =/  url=@t  (build-url endpoint bucket s3-key ~)
  =/  headers=(list [@t @t])  (build-headers 'GET' payload-hash amz-date authorization)
  =/  =request:http
    :*  %'GET'
        url
        headers
        ~
    ==
  ;<  ~  bind:m  (send-request:io request)
  ;<  =client-response:iris  bind:m  take-client-response:io
  ::  Extract response headers and content
  ?.  ?=([%finished *] client-response)
    ~&  >>>  "Failed to download file from S3"
    (pure:m ~)
  ?~  full-file.client-response
    ~&  >>>  "Empty response from S3"
    (pure:m ~)
  =/  response-headers=(list [key=@t value=@t])
    headers.response-header.client-response
  =/  content=@t  ;;(@t q.data.u.full-file.client-response)
  ?:  =(content '')
    (pure:m ~)
  ::  Use helper to save file with proper mime type detection
  %:  save-downloaded-file
    response-headers
    content
    s3-key
    ball-path
  ==
::
::  Download directory from S3 and save to ball
::
++  s3-download-directory-to-ball
  |=  $:  access-key=@t
          secret-key=@t
          region=@t
          endpoint=@t
          bucket=@t
          s3-prefix=@t
          ball-path=path
      ==
  =/  m  (fiber:io ,~)
  ^-  form:m
  ~&  >  "Downloading S3 prefix {<s3-prefix>} to ball path {<ball-path>}..."
  ::  First, list all files in directory
  ;<  file-keys=(list @t)  bind:m
    %:  s3-list
      access-key
      secret-key
      region
      endpoint
      bucket
      s3-prefix
    ==
  ::  Filter out directories (keys ending in /)
  =/  files=(list @t)
    %+  skip  file-keys
    |=(key=@t =((rear (trip key)) '/'))
  ~&  >  "Found {<(lent files)>} files to download"
  ::  Download each file
  |-
  ?~  files
    (pure:m ~)
  =/  s3-key=@t  i.files
  ::  Remove prefix from key to get relative path
  =/  key-path=(list @t)  (slag 1 (rash s3-key (more fas sym)))
  =/  prefix-path=(list @t)
    ?:  =(s3-prefix '')  ~
    (slag 1 (rash s3-prefix (more fas sym)))
  =/  relative-path=(list @t)
    ?~  prefix-path  key-path
    (slag (lent prefix-path) key-path)
  ::  If relative path has directories, create them
  =/  target-path=path
    ?~  relative-path  ball-path
    ?~  t.relative-path  ball-path  :: Single file, no subdirs
    (weld ball-path (snip `path`relative-path))
  =/  filename=@ta  (rear relative-path)
  ~&  >  "Downloading: {<s3-key>} as {<filename>}"
  ::  Download file
  ;<  now=@da  bind:m  get-time:io
  =/  [amz-date=@t payload-hash=@t authorization=@t]
    %:  build-signature
      'GET'
      access-key
      secret-key
      region
      endpoint
      bucket
      s3-key
      ''
      ~
      now
    ==
  =/  url=@t  (build-url endpoint bucket s3-key ~)
  =/  headers=(list [@t @t])  (build-headers 'GET' payload-hash amz-date authorization)
  =/  =request:http
    :*  %'GET'
        url
        headers
        ~
    ==
  ;<  ~  bind:m  (send-request:io request)
  ;<  =client-response:iris  bind:m  take-client-response:io
  ::  Extract response headers and content
  ?.  ?=([%finished *] client-response)
    ~&  >>>  "Failed to download {<s3-key>} from S3"
    $(files t.files)
  ?~  full-file.client-response
    ~&  >>>  "Empty response for {<s3-key>}"
    $(files t.files)
  =/  response-headers=(list [key=@t value=@t])
    headers.response-header.client-response
  =/  content=@t  ;;(@t q.data.u.full-file.client-response)
  ?:  =(content '')
    ~&  >  "Skipping empty file: {<s3-key>}"
    $(files t.files)
  ::  Use helper to save file with proper mime type detection
  ;<  ~  bind:m
    %:  save-downloaded-file
      response-headers
      content
      s3-key
      target-path
    ==
  $(files t.files)
::
::  Upload a single file from ball to S3
::
++  s3-upload-file-from-ball
  |=  $:  access-key=@t
          secret-key=@t
          region=@t
          endpoint=@t
          bucket=@t
          ball-path=path
          filename=@ta
          s3-key=@t
      ==
  =/  m  (fiber:io ,~)
  ^-  form:m
  ~&  >  "Uploading {<ball-path>}/{<filename>} to S3 key {<s3-key>}..."
  ;<  =ball:tarball  bind:m  get-state:io
  ;<  =bowl:gall  bind:m  get-bowl:io
  ;<  conversions=(map mars:clay tube:clay)  bind:m  (get-mark-conversions:io ball)
  ::  Get file content
  =/  content-data=(unit content:tarball)  (~(get ba:tarball ball) ball-path filename)
  ?~  content-data
    ~&  >>>  "File not found: {<ball-path>}/{<filename>}"
    (pure:m ~)
  =/  cag=cage  cage.u.content-data
  ?:  =(%road p.cag)
    ~&  >>>  "Cannot upload symlink: {<ball-path>}/{<filename>}"
    (pure:m ~)
  ::  Convert cage to mime
  =/  =mime
    ?:  =(%mime p.cag)
      !<(mime q.cag)
    (~(cage-to-mime gen:tarball [bowl conversions]) cag)
  =/  text=@t  ;;(@t q.q.mime)
  ::  Upload to S3
  ;<  now=@da  bind:m  get-time:io
  =/  [amz-date=@t payload-hash=@t authorization=@t]
    %:  build-signature
      'PUT'
      access-key
      secret-key
      region
      endpoint
      bucket
      s3-key
      ''
      `text
      now
    ==
  =/  url=@t  (build-url endpoint bucket s3-key ~)
  =/  headers=(list [@t @t])  (build-headers 'PUT' payload-hash amz-date authorization)
  =/  body-octs=octs  (as-octs:mimes:html text)
  =/  =request:http
    :*  %'PUT'
        url
        headers
        `body-octs
    ==
  ;<  ~  bind:m  (send-request:io request)
  ;<  =client-response:iris  bind:m  take-client-response:io
  ~&  >  "Uploaded {<ball-path>}/{<filename>} to {<s3-key>}"
  (pure:m ~)
::
::  Upload directory from ball to S3
::
++  s3-upload-directory
  |=  $:  access-key=@t
          secret-key=@t
          region=@t
          endpoint=@t
          bucket=@t
          ball-path=path
          s3-prefix=@t
      ==
  =/  m  (fiber:io ,~)
  ^-  form:m
  ~&  >  "Uploading ball path {<ball-path>} to S3 prefix {<s3-prefix>}..."
  ;<  =ball:tarball  bind:m  get-state:io
  ;<  =bowl:gall  bind:m  get-bowl:io
  ;<  conversions=(map mars:clay tube:clay)  bind:m  (get-mark-conversions:io ball)
  ::  Get all files from ball directory recursively
  =/  files-to-upload=(list [path @ta])
    (collect-files-recursive ball ball-path)
  ~&  >  "Found {<(lent files-to-upload)>} files to upload"
  ::  Upload each file
  |-
  ?~  files-to-upload
    (pure:m ~)
  =/  [file-path=path filename=@ta]  i.files-to-upload
  ::  Construct S3 key from file path and prefix
  =/  relative-path=path
    ?:  =(ball-path ~)  (snoc file-path filename)
    (snoc (slag (lent ball-path) file-path) filename)
  =/  s3-key=@t
    ?:  =(s3-prefix '')
      (path-to-s3-key relative-path)
    (crip "{(trip s3-prefix)}/{(trip (path-to-s3-key relative-path))}")
  ::  Get file content as mime
  =/  content-data=(unit content:tarball)  (~(get ba:tarball ball) file-path filename)
  ?~  content-data
    ~&  >  "Skipping missing file: {<file-path>}/{<filename>}"
    $(files-to-upload t.files-to-upload)
  =/  cag=cage  cage.u.content-data
  ?:  =(%road p.cag)
    ~&  >  "Skipping symlink: {<file-path>}/{<filename>}"
    $(files-to-upload t.files-to-upload)
  ::  Convert cage to mime
  =/  =mime
    ?:  =(%mime p.cag)
      !<(mime q.cag)
    (~(cage-to-mime gen:tarball [bowl conversions]) cag)
  =/  text=@t  ;;(@t q.q.mime)
  ::  Upload to S3
  ;<  now=@da  bind:m  get-time:io
  =/  [amz-date=@t payload-hash=@t authorization=@t]
    %:  build-signature
      'PUT'
      access-key
      secret-key
      region
      endpoint
      bucket
      s3-key
      ''
      `text
      now
    ==
  =/  url=@t  (build-url endpoint bucket s3-key ~)
  =/  headers=(list [@t @t])  (build-headers 'PUT' payload-hash amz-date authorization)
  =/  body-octs=octs  (as-octs:mimes:html text)
  =/  =request:http
    :*  %'PUT'
        url
        headers
        `body-octs
    ==
  ;<  ~  bind:m  (send-request:io request)
  ;<  =client-response:iris  bind:m  take-client-response:io
  ~&  >  "Uploaded {<file-path>}/{<filename>} to {<s3-key>}"
  $(files-to-upload t.files-to-upload)
::
::  Helper: convert path to S3 key (no leading slash)
::
++  path-to-s3-key
  |=  pax=path
  ^-  @t
  ?~  pax  ''
  =/  parts=(list tape)
    %+  turn  pax
    |=(p=@ta (trip p))
  (crip (roll parts |=([a=tape b=tape] ?~(b a "{b}/{a}"))))
::
::  Helper: collect all files from a ball directory recursively
::
++  collect-files-recursive
  |=  [=ball:tarball current-path=path]
  ^-  (list [path @ta])
  ::  Get files at current path
  =/  files=(list @ta)  (~(lis ba:tarball ball) current-path)
  =/  files-with-path=(list [path @ta])
    %+  turn  files
    |=(f=@ta [current-path f])
  ::  Get subdirectories
  =/  current-ball=ball:tarball  (~(dip ba:tarball ball) current-path)
  =/  subdirs=(list @ta)  ~(tap in ~(key by dir.current-ball))
  ::  Recursively collect from subdirectories
  =/  subdir-files=(list [path @ta])
    |-  ^-  (list [path @ta])
    ?~  subdirs  ~
    =/  subdir-path=path  (snoc current-path i.subdirs)
    =/  subdir-results=(list [path @ta])
      (collect-files-recursive ball subdir-path)
    (weld subdir-results $(subdirs t.subdirs))
  (weld files-with-path subdir-files)
::
::  Build S3 URL with optional query string
::  Returns full HTTPS URL for S3 request
::
++  build-url
  |=  [endpoint=@t bucket=@t object-key=@t query=(unit @t)]
  ^-  @t
  =/  base=tape
    %+  weld  "https://"
    %+  weld  (trip endpoint)
    %+  weld  "/"
    %+  weld  (trip bucket)
    "/"
  =/  path=tape
    ?:  =(object-key '')
      ""
    (trip object-key)
  =/  full-path=tape  (weld base path)
  ?~  query
    (crip full-path)
  (crip (weld full-path (weld "?" (trip u.query))))
::
::  Build HTTP headers for S3 request
::  Returns header list based on method
::
++  build-headers
  |=  [method=@t payload-hash=@t amz-date=@t authorization=@t]
  ^-  (list [@t @t])
  =/  base-headers=(list [@t @t])
    :~  ['x-amz-content-sha256' payload-hash]
        ['x-amz-date' amz-date]
        ['authorization' authorization]
    ==
  ?:  =(method 'PUT')
    [[%content-type 'text/plain'] base-headers]
  base-headers
::
::  Build query string for LIST operation
::  URL-encodes prefix parameter
::
++  build-list-query
  |=  prefix=@t
  ^-  @t
  ?:  =(prefix '')
    'list-type=2'
  =/  encoded-prefix=tape  (en-urlt:html (trip prefix))
  (crip "list-type=2&prefix={encoded-prefix}")
::
::  Build AWS Signature V4 authorization
::  Supports GET, PUT, and LIST operations
::
++  build-signature
  |=  $:  method=@t
          access-key=@t
          secret-key=@t
          region=@t
          endpoint=@t
          bucket=@t
          object-key=@t
          query-string=@t
          content=(unit @t)
          now=@da
      ==
  ^-  [amz-date=@t payload-hash=@t authorization=@t]
  ::  Hash request payload (empty for GET)
  =/  payload-hash=@t  (sha256-hash (fall content ''))
  ::  Format ISO8601 timestamp and date stamp
  =/  amz-date=@t  (format-amz-date now)
  =/  date-stamp=@t  (format-date-stamp now)
  ::  Build canonical request
  =/  canonical-uri=@t
    ?:  =(object-key '')
      (crip "/{(trip bucket)}/")
    (crip "/{(trip bucket)}/{(trip object-key)}")
  =/  canonical-querystring=@t  query-string
  ::  Headers vary by method: PUT includes content-type
  =/  [canonical-headers=@t signed-headers=@t]
    ?:  =(method 'PUT')
      :-  %+  rap  3
          :~  'content-type:text/plain'
              '\0a'
              'host:'
              endpoint
              '\0a'
              'x-amz-content-sha256:'
              payload-hash
              '\0a'
              'x-amz-date:'
              amz-date
              '\0a'
          ==
      'content-type;host;x-amz-content-sha256;x-amz-date'
    :-  %+  rap  3
        :~  'host:'
            endpoint
            '\0a'
            'x-amz-content-sha256:'
            payload-hash
            '\0a'
            'x-amz-date:'
            amz-date
            '\0a'
        ==
    'host;x-amz-content-sha256;x-amz-date'
  =/  canonical-request=@t
    %+  rap  3
    :~  method                 '\0a'
        canonical-uri          '\0a'
        canonical-querystring  '\0a'
        canonical-headers      '\0a'
        signed-headers         '\0a'
        payload-hash
    ==
  ::  Create string to sign
  =/  algorithm=@t  'AWS4-HMAC-SHA256'
  =/  credential-scope=@t
    (crip "{(trip date-stamp)}/{(trip region)}/s3/aws4_request")
  =/  canonical-request-hash=@t  (sha256-hash canonical-request)
  =/  string-to-sign=@t
    %+  rap  3
    :~  algorithm               '\0a'
        amz-date                '\0a'
        credential-scope        '\0a'
        canonical-request-hash
    ==
  ::  Calculate signature
  =/  signing-key=@  (get-signature-key secret-key date-stamp region 's3')
  =/  signature-bytes=@  (hmac-sha256 signing-key (swp 3 string-to-sign))
  =/  signature=@t  (hash-to-hex signature-bytes)
  ::  Build authorization header
  =/  authorization=@t
    %+  rap  3
    :~  algorithm
        ' Credential='
        access-key
        '/'
        credential-scope
        ', SignedHeaders='
        signed-headers
        ', Signature='
        signature
    ==
  [amz-date payload-hash authorization]
--
