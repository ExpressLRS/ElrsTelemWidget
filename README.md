### No, you can't use this widget to configure your TX module, don't ask!

A simple widget to display ExpressLRS LinkStats telemetry as well as common Betaflight and iNav flight controller telemetry.

![widget screenshot](docs/images/screen-2-1.png)

# Installing
* Copy the `src/WIDGETS/ELRST` folder to your handset's SD card in the `WIDGETS/` folder such that your SD card will end up with a file called `WIDGETS/ELRST/main.lua`.
* Discover sensors
  * Power up your receiver and flight controller and wait for a connection to be established.
  * Press the MDL (model) key, then PAGE to get to the TELEMETRY page.
  * Use the "Discover new" button to start discovering sensors. Betaflight should have 17, iNav should have 23 with GPS.
* Add the widget to the main screen
  * Press the TELEM button on the handset and navigate to the second page.
  * Tap "Setup widgets".
  * Tap an open space and add the "ELRS Telem" widget.
  * Use the RTN / EXIT button to go back until you're on the main screen again.
  * If you forgot to Discover sensors before adding the widget, discover them and restart the handset entirely.

## Requirements
* Tested on Radiomaster TX16S with EdgeTX 2.5 only
