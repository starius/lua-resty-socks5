lua-resty-socks5
================

Lua SOCKS5 client for the `ngx_lua` based on the cosocket API

Related project:
[onion2web](https://github.com/starius/onion2web).

[Paper](http://habrahabr.ru/post/243055/) (in Russian).

Installation
------------

```bash
$ sudo luarocks install socks5
```

Reference
---------

This module contains the following functions:

 * `socks5.auth(cosocket)` - authenticate to SOCKS5
    server (method "no authentication" is used).
    Cosocket must be connected to SOCKS5 server
 * `socks5.connect(cosocket, host, port)` - tell
    SOCKS5 server to connect to target host:port.
    Host must be domain name
 * `socks5.handle_request(socks5host, socks5port,
    request_changer?, response_changer?, change_only_html?)` -
    creates cosocket, authenticates to SOCKS5 server
    (defined by socks5host, socks5port),
    connects to target host:port (defined in ngx.req),
    receive request headers and body, send them
    through SOCKS5 server to target,
    then receive response headers and body,
    send them to client.

    Optional function `request_changer` is applied to
    request before sending it to target.
    Optional function `response_changer` is applied to
    response before sending it to client.

    The proxy can operate in two modes:

      * whole-page: read whole HTTP response and then
        send it to the client;
      * streaming: read response in small chunks.

    If `response_changer` is not used, streaming mode
    is used. If `response_changer` is used and
    `change_only_html` is truthy, then whole-page
    is used for HTML pages and streaming is used
    otherwise.

How to use this module to proxy all requests through Tor:

```nginx
server {
    listen 80;
    server_name ip4.me; # must be in request header
    location / {
        default_type text/html;
        content_by_lua '
        require("socks5").handle_request("127.0.0.1", 9050)
        ';
    }
}
```
