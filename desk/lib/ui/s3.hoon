/-  *master
/+  server, tarball
|%
::  Render S3 management UI
::
++  s3-manager
  |=  [=ball:tarball =bowl:gall]
  ^-  manx
  ;html
    ;head
      ;title: S3 Manager
      ;style
        ; body { font-family: monospace; margin: 20px; }
        ; h1 { font-size: 18px; }
        ; h2 { font-size: 16px; margin-top: 20px; }
        ; .section { margin: 20px 0; padding: 15px; background: #f6f8fa; border-radius: 6px; }
        ; .form-group { margin: 10px 0; }
        ; label { display: block; margin-bottom: 5px; font-weight: bold; }
        ; input[type="text"] { width: 300px; padding: 5px; }
        ; button { padding: 5px 15px; margin-left: 10px; cursor: pointer; }
        ; table { border-collapse: collapse; width: 100%; margin-top: 10px; }
        ; th, td { text-align: left; padding: 8px; }
        ; th { border-bottom: 1px solid #ccc; }
        ; a { color: #0366d6; text-decoration: none; }
        ; a:hover { text-decoration: underline; }
      ==
    ==
    ;body
      ;h1: S3 Manager
      ;div(class "section")
        ;h2: Upload Single Ball File to S3
        ;form(method "POST", action "/master/s3-upload-file")
          ;div(class "form-group")
            ;label(for "ball-path-file-up"): Ball Directory Path (e.g., /docs):
            ;input#ball-path-file-up(type "text", name "ball-path", placeholder "/docs", required "");
          ==
          ;div(class "form-group")
            ;label(for "filename-up"): Filename (e.g., test.json):
            ;input#filename-up(type "text", name "filename", placeholder "test.json", required "");
          ==
          ;div(class "form-group")
            ;label(for "s3-key-up"): S3 Key (full path in bucket, e.g., backup/test.json):
            ;input#s3-key-up(type "text", name "s3-key", placeholder "backup/test.json", required "");
          ==
          ;button(type "submit"): Upload File
        ==
      ==
      ;div(class "section")
        ;h2: Upload Ball Directory to S3
        ;form(method "POST", action "/master/s3-upload-directory")
          ;div(class "form-group")
            ;label(for "ball-path"): Ball Directory Path (e.g., /docs or / for root):
            ;input#ball-path(type "text", name "ball-path", placeholder "/docs", required "");
          ==
          ;div(class "form-group")
            ;label(for "s3-prefix"): S3 Prefix (directory in bucket, e.g., backup/docs):
            ;input#s3-prefix(type "text", name "s3-prefix", placeholder "backup/docs", required "");
          ==
          ;button(type "submit"): Upload Directory
        ==
      ==
      ;div(class "section")
        ;h2: Download S3 Directory to Ball
        ;form(method "POST", action "/master/s3-download-directory")
          ;div(class "form-group")
            ;label(for "s3-prefix-dl"): S3 Prefix (e.g., backup/docs):
            ;input#s3-prefix-dl(type "text", name "s3-prefix", placeholder "backup/docs", required "");
          ==
          ;div(class "form-group")
            ;label(for "ball-path-dl"): Ball Directory Path (e.g., /docs):
            ;input#ball-path-dl(type "text", name "ball-path", placeholder "/docs", required "");
          ==
          ;button(type "submit"): Download to Ball
        ==
      ==
      ;div(class "section")
        ;h2: Download Single S3 File to Ball
        ;form(method "POST", action "/master/s3-download-file")
          ;div(class "form-group")
            ;label(for "s3-key"): S3 File Key (e.g., backup/file.txt):
            ;input#s3-key(type "text", name "s3-key", placeholder "backup/file.txt", required "");
          ==
          ;div(class "form-group")
            ;label(for "ball-path-file"): Ball Directory Path (e.g., /docs):
            ;input#ball-path-file(type "text", name "ball-path", placeholder "/docs", required "");
          ==
          ;button(type "submit"): Download File
        ==
      ==
      ;div(class "section")
        ;h2: List S3 Files
        ;form(method "POST", action "/master/s3-list")
          ;div(class "form-group")
            ;label(for "list-prefix"): S3 Prefix (leave empty for all):
            ;input#list-prefix(type "text", name "prefix", placeholder "backup/");
          ==
          ;button(type "submit"): List Files
        ==
      ==
      ;div(class "section")
        ;h2: Quick Actions
        ;p: ;a/"/master/ball": View Ball Browser
      ==
    ==
  ==
--
