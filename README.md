lua-resty-socks5
================

Lua SOCKS5 client for the `ngx_lua` based on the cosocket API

This module contains the following functions:

 * `socks5.auth(cosocket)` - authenticate to SOCKS5
    server (method "no authentication" is used).
    Cosocket must be connected to SOCKS5 server
 * `socks5.connect(cosocket, host, port)` - tell
    SOCKS5 server to connect to target host:port.
    Host must be domain name
 * `socks5.handle_request(socks5host, socks5port,
    request_changer?, response_changer?)` -
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

 * `socks5.handle_onion2web(onion_replacement,
    torhost='127.0.0.1', torport=9050)` -
    accept request to onion2web site.

How to use this module to forward requests from
`xxx.onion.gq` to `xxx.onion`:

```nginx
server {
    listen 80;
    server_name *.onion.gq;
    location / {
        default_type text/html;
        content_by_lua '
            require("socks5").handle_onion2web(".onion.gq");
        ';
    }
}
```
