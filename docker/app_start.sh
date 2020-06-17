#!/bin/bash

INVENV=$(python -c 'import sys; print ("1" if hasattr(sys, "real_prefix") else "0")')

echo $INVENV

if [ "$ENV"  = "localdev" ]
then
  ls -l bin/
fi
