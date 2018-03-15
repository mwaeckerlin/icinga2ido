#!/bin/bash

echo quit | telnet localhost 5665 2> /dev/null | grep -q Connected
