#!/bin/bash

wlfreerdp /v:localhost:3389 \
  /u:usuario \
  /p:usuario \
  /dynamic-resolution \
  /gfx:AVC444 \
  /sound:sys:pulse \
  /microphone:sys:pulse \
  /usb:id,dev:001:074 \
  /clipboard
