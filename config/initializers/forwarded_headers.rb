# Only trust `X-Forwarded-*` headers for the client IP/host/scheme, and ignore
# the RFC 7239 `Forwarded` header.
#
# By default, Rack 3 prefers `Forwarded` over `X-Forwarded-For`. Our nginx
# config appends the real client IP to `X-Forwarded-For`, but historically
# passed any client-supplied `Forwarded` header through untouched, so a client
# could pick their own `request.ip` / `request.remote_ip`. That let them dodge
# the Rack::Attack throttle on `/pets/load`, and spoof the IP we use for
# shadowban checks. See GHSA-2gff-2mmg-m73p.
#
# This matches how Rails 8.0 and earlier resolved the client IP.
Rack::Request.forwarded_priority = [:x_forwarded]
