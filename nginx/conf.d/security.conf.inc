ssl_session_timeout 1d;
ssl_session_cache shared:MozSSL:10m;  # about 40000 sessions
ssl_session_tickets off;


# generated 2021-10-05, Mozilla Guideline v5.6, nginx 1.18, OpenSSL 1.1.1k, modern configuration
# https://ssl-config.mozilla.org/#server=nginx&version=1.18&config=modern&openssl=1.1.1k&guideline=5.6
ssl_protocols TLSv1.3;
ssl_prefer_server_ciphers off;

# HSTS (ngx_http_headers_module is required) (63072000 seconds)
add_header Strict-Transport-Security "max-age=63072000" always;

# Follows the Web Security Directives from the Mozilla Dev Lab and the Mozilla Obervatory + Partners
# https://wiki.mozilla.org/Security/Guidelines/Web_Security
# https://observatory.mozilla.org/
more_set_headers "Content-Security-Policy : upgrade-insecure-requests";
more_set_headers "Content-Security-Policy-Report-Only : default-src https: data: 'unsafe-inline' 'unsafe-eval'  ";
more_set_headers "X-Content-Type-Options : nosniff";
more_set_headers "X-XSS-Protection : 1; mode=block";
more_set_headers "X-Download-Options : noopen";
more_set_headers "X-Permitted-Cross-Domain-Policies : none";
more_set_headers "X-Frame-Options : SAMEORIGIN";

# Disable gzip to protect against BREACH
# Read https://trac.nginx.org/nginx/ticket/1720 (text/html cannot be disabled!)
gzip off;