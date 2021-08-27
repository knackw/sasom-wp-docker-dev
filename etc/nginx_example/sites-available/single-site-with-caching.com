# Define path to cache and memory zone. The memory zone should be unique.
# keys_zone=single-site-with-caching.com:100m creates the memory zone and sets the maximum size in MBs.
# inactive=60m will remove cached items that haven't been accessed for 60 minutes or more.
fastcgi_cache_path /sites/localhost/cache levels=1:2 keys_zone=localhost:100m inactive=60m;

server {
	# Ports to listen on, uncomment one.
	listen 443 ssl http2;
	listen [::]:443 ssl http2;

	# Server name to listen for
	server_name localhost;

	# Path to document root
	root /www;

	# Paths to certificate files.
	ssl_certificate /etc/nginx/certs/self-signed/${SSL_Domain}.crt;
    ssl_certificate_key /etc/nginx/certs/self-signed/${SSL_Domain}.key;

	# File to be used as index
	index index.php;

	# Overrides logs defined in nginx.conf, allows per site logs.
	access_log /var/log/nginx/localhost/access.log;
    error_log  /var/log/nginx/localhost/error.log warn;

	# Default server block rules
	include global/server/defaults.conf;

	# Fastcgi cache rules
	include global/server/fastcgi-cache.conf;

	# SSL rules
	include global/server/ssl.conf;

	location / {
		try_files $uri $uri/ /index.php?$args;
	}

	location ~ \.php$ {
		try_files $uri =404;
		include global/fastcgi-params.conf;

		# Use the php pool defined in the upstream variable.
		# See global/php-pool.conf for definition.
		fastcgi_pass   127.0.0.1:9000;

		# Skip cache based on rules in global/server/fastcgi-cache.conf.
		fastcgi_cache_bypass $skip_cache;
		fastcgi_no_cache $skip_cache;

		# Define memory zone for caching. Should match key_zone in fastcgi_cache_path above.
		fastcgi_cache localhost;

		# Define caching time.
		fastcgi_cache_valid 60m;
	}
}

# Redirect http to https
server {
	listen 80;
	listen [::]:80;
	server_name localhost;

	return 301 https://localhost$request_uri;
}

# Redirect www to non-www
server {
	listen 443;
	listen [::]:443;
	server_name localhost;

	return 301 https://localhost$request_uri;
}