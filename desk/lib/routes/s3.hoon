/-  *master
/+  io=sailboxio, sailbox, s3, tarball, json-utils
|%
::  Helper to extract S3 creds from json
::
++  extract-s3-creds
  |=  jon=json
  ^-  [access-key=@t secret-key=@t region=@t endpoint=@t bucket=@t]
  :*  (~(dog jo:json-utils jon) /access-key so:dejs:format)
      (~(dog jo:json-utils jon) /secret-key so:dejs:format)
      (~(dog jo:json-utils jon) /region so:dejs:format)
      (~(dog jo:json-utils jon) /endpoint so:dejs:format)
      (~(dog jo:json-utils jon) /bucket so:dejs:format)
  ==
::  Normalize S3 prefix by stripping leading/trailing slashes
::
++  normalize-s3-prefix
  |=  prefix=@t
  ^-  @t
  =/  text=tape  (trip prefix)
  ::  Strip leading slashes
  |-  ^-  @t
  ?~  text  ''
  ?:  =('/' i.text)  $(text t.text)
  ::  Strip trailing slashes by reversing, stripping, then reversing back
  =/  reversed=tape  (flop text)
  =/  stripped=tape
    |-  ^-  tape
    ?~  reversed  reversed
    ?.  =('/' i.reversed)  reversed
    $(reversed t.reversed)
  (crip (flop stripped))
::  POST /master/s3-upload - Upload text to S3
::
++  handle-upload
  |=  [text=@t filename=@t]
  =/  m  (fiber:io ,~)
  ^-  form:m
  ;<  ball=ball:tarball  bind:m  get-state:io
  =/  jon=json
    (~(got-cage-as ba:tarball ball) /config/creds 's3.json' json)
  =/  [access-key=@t secret-key=@t region=@t endpoint=@t bucket=@t]
    (extract-s3-creds jon)
  ;<  now=@da  bind:m  get-time:io
  ::  Build AWS Signature V4 for PUT request
  =/  [amz-date=@t payload-hash=@t authorization=@t]
    %:  build-signature:s3
      'PUT'
      access-key
      secret-key
      region
      endpoint
      bucket
      filename
      ''
      `text
      now
    ==
  ::  Build request URL and headers
  =/  url=@t  (build-url:s3 endpoint bucket filename ~)
  =/  headers=(list [@t @t])  (build-headers:s3 'PUT' payload-hash amz-date authorization)
  ::  Prepare body
  =/  body-octs=octs  (as-octs:mimes:html text)
  ~&  >  "S3 Upload Request:"
  ~&  >  ['URL' url]
  ~&  >  ['Date' amz-date]
  ~&  >  ['Hash' payload-hash]
  =/  =request:http
    :*  %'PUT'
        url
        headers
        `body-octs
    ==
  ;<  ~  bind:m  (send-request:io request)
  ;<  =client-response:iris  bind:m  take-client-response:io
  ~&  >  "S3 Response: {<client-response>}"
  (pure:m ~)
::
::  POST /master/s3-get - Get file from S3
::
++  handle-get
  |=  filename=@t
  =/  m  (fiber:io ,~)
  ^-  form:m
  ;<  ball=ball:tarball  bind:m  get-state:io
  =/  jon=json
    (~(got-cage-as ba:tarball ball) /config/creds 's3.json' json)
  =/  [access-key=@t secret-key=@t region=@t endpoint=@t bucket=@t]
    (extract-s3-creds jon)
  ;<  now=@da  bind:m  get-time:io
  ::  Build AWS Signature V4 for GET request
  =/  [amz-date=@t payload-hash=@t authorization=@t]
    %:  build-signature:s3
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
  =/  url=@t  (build-url:s3 endpoint bucket filename ~)
  =/  headers=(list [@t @t])  (build-headers:s3 'GET' payload-hash amz-date authorization)
  ~&  >  "S3 GET Request:"
  ~&  >  ['URL' url]
  ~&  >  ['Date' amz-date]
  =/  =request:http
    :*  %'GET'
        url
        headers
        ~
    ==
  ;<  ~  bind:m  (send-request:io request)
  ;<  =client-response:iris  bind:m  take-client-response:io
  ~&  >  "S3 GET Response: {<client-response>}"
  (pure:m ~)
::
::  POST /master/s3-delete - Delete file from S3
::
++  handle-delete
  |=  filename=@t
  =/  m  (fiber:io ,~)
  ^-  form:m
  ;<  ball=ball:tarball  bind:m  get-state:io
  =/  jon=json
    (~(got-cage-as ba:tarball ball) /config/creds 's3.json' json)
  =/  [access-key=@t secret-key=@t region=@t endpoint=@t bucket=@t]
    (extract-s3-creds jon)
  ;<  now=@da  bind:m  get-time:io
  ::  Build AWS Signature V4 for DELETE request
  =/  [amz-date=@t payload-hash=@t authorization=@t]
    %:  build-signature:s3
      'DELETE'
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
  =/  url=@t  (build-url:s3 endpoint bucket filename ~)
  =/  headers=(list [@t @t])  (build-headers:s3 'DELETE' payload-hash amz-date authorization)
  ~&  >  "S3 DELETE Request:"
  ~&  >  ['URL' url]
  ~&  >  ['Filename' filename]
  =/  =request:http
    :*  %'DELETE'
        url
        headers
        ~
    ==
  ;<  ~  bind:m  (send-request:io request)
  ;<  =client-response:iris  bind:m  take-client-response:io
  ~&  >  "S3 DELETE Response: {<client-response>}"
  (pure:m ~)
::
::  POST /master/s3-list - List files in S3
::
++  handle-list
  |=  prefix=@t
  =/  m  (fiber:io ,~)
  ^-  form:m
  ;<  ball=ball:tarball  bind:m  get-state:io
  =/  jon=json
    (~(got-cage-as ba:tarball ball) /config/creds 's3.json' json)
  =/  [access-key=@t secret-key=@t region=@t endpoint=@t bucket=@t]
    (extract-s3-creds jon)
  ::  Normalize S3 prefix
  =/  normalized-prefix=@t  (normalize-s3-prefix prefix)
  ~&  >  "S3 LIST Request:"
  ~&  >  ['Prefix' normalized-prefix]
  ;<  file-keys=(list @t)  bind:m
    %:  s3-list:s3
      access-key
      secret-key
      region
      endpoint
      bucket
      normalized-prefix
    ==
  ~&  >  "S3 LIST Response - Found {<(lent file-keys)>} files:"
  ~&  >  file-keys
  (pure:m ~)
::
::  POST /master/s3-get-directory - Get directory from S3
::
++  handle-get-directory
  |=  prefix=@t
  =/  m  (fiber:io ,~)
  ^-  form:m
  ;<  ball=ball:tarball  bind:m  get-state:io
  =/  jon=json
    (~(got-cage-as ba:tarball ball) /config/creds 's3.json' json)
  =/  [access-key=@t secret-key=@t region=@t endpoint=@t bucket=@t]
    (extract-s3-creds jon)
  ::  Normalize S3 prefix
  =/  normalized-prefix=@t  (normalize-s3-prefix prefix)
  ~&  >  "S3 GET DIRECTORY Request:"
  ~&  >  ['Prefix' normalized-prefix]
  ;<  ~  bind:m
    %:  s3-get-directory:s3
      access-key
      secret-key
      region
      endpoint
      bucket
      normalized-prefix
    ==
  (pure:m ~)
::
::  POST /master/s3-upload-file - Upload single ball file to S3
::
++  handle-upload-file
  |=  [ball-path=@t filename=@t s3-key=@t]
  =/  m  (fiber:io ,~)
  ^-  form:m
  ;<  ball=ball:tarball  bind:m  get-state:io
  =/  jon=json
    (~(got-cage-as ba:tarball ball) /config/creds 's3.json' json)
  =/  [access-key=@t secret-key=@t region=@t endpoint=@t bucket=@t]
    (extract-s3-creds jon)
  ::  Convert ball-path to path
  =/  pax=path
    ?:  =(ball-path '/')  ~
    (stab ball-path)
  ::  Convert filename to @ta
  =/  fname=@ta  (rash filename sym)
  ::  Normalize S3 key
  =/  normalized-key=@t  (normalize-s3-prefix s3-key)
  ;<  ~  bind:m
    %:  s3-upload-file-from-ball:s3
      access-key
      secret-key
      region
      endpoint
      bucket
      pax
      fname
      normalized-key
    ==
  (pure:m ~)
::
::  POST /master/s3-upload-directory - Upload ball directory to S3
::
++  handle-upload-directory
  |=  [ball-path=@t s3-prefix=@t]
  =/  m  (fiber:io ,~)
  ^-  form:m
  ;<  ball=ball:tarball  bind:m  get-state:io
  =/  jon=json
    (~(got-cage-as ba:tarball ball) /config/creds 's3.json' json)
  =/  [access-key=@t secret-key=@t region=@t endpoint=@t bucket=@t]
    (extract-s3-creds jon)
  ::  Convert ball-path to path
  =/  pax=path
    ?:  =(ball-path '/')  ~
    (stab ball-path)
  ::  Normalize S3 prefix
  =/  normalized-prefix=@t  (normalize-s3-prefix s3-prefix)
  ;<  ~  bind:m
    %:  s3-upload-directory:s3
      access-key
      secret-key
      region
      endpoint
      bucket
      pax
      normalized-prefix
    ==
  (pure:m ~)
::
::  POST /master/s3-download-directory - Download S3 directory to ball
::
++  handle-download-directory
  |=  [s3-prefix=@t ball-path=@t]
  =/  m  (fiber:io ,~)
  ^-  form:m
  ;<  ball=ball:tarball  bind:m  get-state:io
  =/  jon=json
    (~(got-cage-as ba:tarball ball) /config/creds 's3.json' json)
  =/  [access-key=@t secret-key=@t region=@t endpoint=@t bucket=@t]
    (extract-s3-creds jon)
  ::  Convert ball-path to path
  =/  pax=path
    ?:  =(ball-path '/')  ~
    (stab ball-path)
  ::  Normalize S3 prefix
  =/  normalized-prefix=@t  (normalize-s3-prefix s3-prefix)
  ;<  ~  bind:m
    %:  s3-download-directory-to-ball:s3
      access-key
      secret-key
      region
      endpoint
      bucket
      normalized-prefix
      pax
    ==
  (pure:m ~)
::
::  POST /master/s3-download-file - Download single S3 file to ball
::
++  handle-download-file
  |=  [s3-key=@t ball-path=@t]
  =/  m  (fiber:io ,~)
  ^-  form:m
  ;<  ball=ball:tarball  bind:m  get-state:io
  =/  jon=json
    (~(got-cage-as ba:tarball ball) /config/creds 's3.json' json)
  =/  [access-key=@t secret-key=@t region=@t endpoint=@t bucket=@t]
    (extract-s3-creds jon)
  ::  Convert ball-path to path
  =/  pax=path
    ?:  =(ball-path '/')  ~
    (stab ball-path)
  ::  Normalize S3 key
  =/  normalized-key=@t  (normalize-s3-prefix s3-key)
  ;<  ~  bind:m
    %:  s3-download-file-to-ball:s3
      access-key
      secret-key
      region
      endpoint
      bucket
      normalized-key
      pax
    ==
  (pure:m ~)
::
::  POST /master/update-s3-creds - Update S3 credentials
::
++  handle-update-creds
  |=  [access-key=@t secret-key=@t region=@t bucket=@t endpoint=@t]
  =/  m  (fiber:io ,~)
  ^-  form:m
  ::  Build json directly
  =/  jon=json
    %-  pairs:enjs:format
    :~  ['access-key' s+access-key]
        ['secret-key' s+secret-key]
        ['region' s+region]
        ['bucket' s+bucket]
        ['endpoint' s+endpoint]
    ==
  ::  Put with validation
  ;<  ~  bind:m  (put-cage:io /config/creds 's3.json' [%json !>(jon)])
  (pure:m ~)
--
