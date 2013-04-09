#!/bin/bash

# We want Python to find our own modules
export PYTHONPATH=../../Utils:$PYTHONPATH

# Run the scene
optirun morse run scene_init.py &
sleep 15s

# Control the trajectory
python3.3 circle.py

# Run the datalogger
python3.3 data_logger.py out 60 1
