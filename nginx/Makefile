CF_IPV4_URL=https://www.cloudflare.com/ips-v4
CF_IPV6_URL=https://www.cloudflare.com/ips-v6

cloudflare:
	@echo "# Set client IP from CloudFlare IPs" > cloudflare
	@echo "" >> cloudflare
	@echo "# Traefik" >> cloudflare
	@echo "set_real_ip_from 10.0.0.0/8;" >> cloudflare
	@echo "set_real_ip_from 172.16.0.0/12;" >> cloudflare
	@echo "set_real_ip_from 192.168.0.0/16;" >> cloudflare
	@echo "set_real_ip_from 127.0.0.1;" >> cloudflare
	@echo "" >> cloudflare
	@echo "# CloudFlare" >> cloudflare
	@echo "# - IPv4" >> cloudflare
	@curl -s $(CF_IPV4_URL) | sed 's/^/set_real_ip_from /;s/$$/;/' >> cloudflare
	@echo "" >> cloudflare
	@echo "" >> cloudflare
	@echo "# - IPv6" >> cloudflare
	@curl -s $(CF_IPV6_URL) | sed 's/^/set_real_ip_from /;s/$$/;/' >> cloudflare
	@echo "" >> cloudflare
	@echo "" >> cloudflare
	@echo "" >> cloudflare
	@echo "# Client IP is available from the CF-Connecting-IP header" >> cloudflare
	@echo "real_ip_header CF-Connecting-IP;" >> cloudflare
	@echo "" >> cloudflare
	@echo "# Ensure the correct IP is set, even behind a Traefik ingress" >> cloudflare
	@echo "real_ip_recursive on;" >> cloudflare

clean:
	rm -f cloudflare
