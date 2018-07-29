# godaddy-ddns-updater
A simple shell script to perform a GoDaddy DDNS update

This script began as the script by Nazar78 at [TeaNazaR.com](http://teanazar.com/2016/05/godaddy-ddns-updater/).
I have modified it to extend it's functionality and to meet my own personal standards.

```
Usage: $0 credentials domain [sub-domain] [ttl] [record_type]
  credentials: GoDaddy developer API in the format 'key:secret' or
               location of file containing that value on the first line
  domain: The domain you're setting. e.g. mydomain.com
  sub-domain: Record name, as seen in the DNS setup page. Default: @ (apex domain)
  ttl: Time To Live in seconds. Default: 600 (10 minutes)
  record_type: Record type, as seen in the DNS setup page. Default: A
```
