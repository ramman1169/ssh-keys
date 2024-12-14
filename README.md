
## The purpose of this is to keep ssh keys in sync across your network. After running this script, the machines will pull a copy of this authorized_keys file and over-write the local copy.

Add your keys to authorized_keys, then run the following command to put the checksum in the correct file...

## SYNTAX
edit the authorized_keys file
sha256sum authorized_keys | awk '{print $1}' > authorized_keys.sha256
