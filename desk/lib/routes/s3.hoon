/-  *master
/+  io=sailboxio, sailbox, s3, tarball
|%
::  Initial S3 credentials
::
++  initial-creds
  ^-  s3-creds
  :*  access-key='your-access-key'
      secret-key='your-secret-key'
      region='nyc3'
      bucket='your-bucket'
      endpoint='nyc3.digitaloceanspaces.com'
  ==
::
::  POST /master/s3-upload - Upload text to S3
::
++  handle-upload
  |=  [text=@t filename=@t]
  =/  m  (fiber:io ,~)
  ^-  form:m
  ;<  state=state-0  bind:m  (get-state-as:io state-0)
  =/  creds=s3-creds
    (~(get-cage-as ba:tarball ball.state) / 's3-creds.json' s3-creds)
  ;<  now=@da  bind:m  get-time:io
  ::  Build AWS Signature V4 for PUT request
  =/  [amz-date=@t payload-hash=@t authorization=@t]
    %:  build-signature:s3
      'PUT'
      access-key.creds
      secret-key.creds
      region.creds
      endpoint.creds
      bucket.creds
      filename
      ''
      `text
      now
    ==
  ::  Build request URL and headers
  =/  url=@t  (build-url:s3 endpoint.creds bucket.creds filename ~)
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
  ;<  state=state-0  bind:m  (get-state-as:io state-0)
  =/  creds=s3-creds
    (~(get-cage-as ba:tarball ball.state) / 's3-creds.json' s3-creds)
  ;<  now=@da  bind:m  get-time:io
  ::  Build AWS Signature V4 for GET request
  =/  [amz-date=@t payload-hash=@t authorization=@t]
    %:  build-signature:s3
      'GET'
      access-key.creds
      secret-key.creds
      region.creds
      endpoint.creds
      bucket.creds
      filename
      ''
      ~
      now
    ==
  ::  Build request URL and headers
  =/  url=@t  (build-url:s3 endpoint.creds bucket.creds filename ~)
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
  ;<  state=state-0  bind:m  (get-state-as:io state-0)
  =/  creds=s3-creds
    (~(get-cage-as ba:tarball ball.state) / 's3-creds.json' s3-creds)
  ;<  now=@da  bind:m  get-time:io
  ::  Build AWS Signature V4 for DELETE request
  =/  [amz-date=@t payload-hash=@t authorization=@t]
    %:  build-signature:s3
      'DELETE'
      access-key.creds
      secret-key.creds
      region.creds
      endpoint.creds
      bucket.creds
      filename
      ''
      ~
      now
    ==
  ::  Build request URL and headers
  =/  url=@t  (build-url:s3 endpoint.creds bucket.creds filename ~)
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
  ;<  state=state-0  bind:m  (get-state-as:io state-0)
  =/  creds=s3-creds
    (~(get-cage-as ba:tarball ball.state) / 's3-creds.json' s3-creds)
  ~&  >  "S3 LIST Request:"
  ~&  >  ['Prefix' prefix]
  ;<  file-keys=(list @t)  bind:m
    %:  s3-list:s3
      access-key.creds
      secret-key.creds
      region.creds
      endpoint.creds
      bucket.creds
      prefix
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
  ;<  state=state-0  bind:m  (get-state-as:io state-0)
  =/  creds=s3-creds
    (~(get-cage-as ba:tarball ball.state) / 's3-creds.json' s3-creds)
  ~&  >  "S3 GET DIRECTORY Request:"
  ~&  >  ['Prefix' prefix]
  ;<  ~  bind:m
    %:  s3-get-directory:s3
      access-key.creds
      secret-key.creds
      region.creds
      endpoint.creds
      bucket.creds
      prefix
    ==
  (pure:m ~)
::
::  POST /master/update-s3-creds - Update S3 credentials
::
++  handle-update-creds
  |=  [access-key=@t secret-key=@t region=@t bucket=@t endpoint=@t]
  =/  m  (fiber:io ,~)
  ^-  form:m
  ;<  state=state-0  bind:m  (get-state-as:io state-0)
  =/  creds=s3-creds  [access-key secret-key region bucket endpoint]
  =/  new-ball=ball:tarball
    (~(put ba:tarball ball.state) / 's3-creds.json' [%cage ~ [%json !>(creds)]])
  =.  ball.state  new-ball
  ;<  ~  bind:m  (replace:io !>(state))
  (pure:m ~)
--
