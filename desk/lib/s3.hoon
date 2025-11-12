/+  io=sailboxio
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
