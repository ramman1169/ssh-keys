This is the master support authorized_keys file for CornerIT machines...


This file will get pulled from a bash script that re-writes the local authorized_keys file...

Add your keys to authorized_keys, the run the following command to get the checksum

sha256sum authorized_keys | awk '{print $1}' > authorized_keys.sha256
