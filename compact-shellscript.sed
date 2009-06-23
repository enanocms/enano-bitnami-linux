#!/bin/sed -f
# Remove comments, except for the shebang
s/^ *#[^!#].*$//
# Remove spaces at the beginning of all lines
s/^ *//
# Remove empty lines
/^$/d
