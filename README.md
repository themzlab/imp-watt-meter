### imp-watt-meter
single-phase energy meter for AC power.  Uses electric imp

The core of this design is the energy metering ic, ADE7953.  This ic does all of the measuring duties.

An electric imp module imp002 is connected with SPI to read the various metrics such as average active power, V*A, instantaneous current and so on.

The electric imp device reads data from the ADE7953 and packages a binary message.
The electric imp agent recieves this data and unpacks it creating a JSON message and http posts this
to a webhost account

A PHP script recieves this message and logs to a file.

Using the electric imp agent, it is possible to redirect the data to one of many
data repository services.

There is a web page using javascript, jquery and highcharts that will allow one to look at current data and also take a snapshot of the current and voltage waveform or else take a 5 second time plot of the power.



**Additional documentation here**

http://themzlab.tumblr.com/wattmeter


Here is a screenshot of the web page

![imp-watt-meter-screenshot-refrigerator](https://cloud.githubusercontent.com/assets/15392670/12759372/5f4b9a68-c9a6-11e5-9635-47214c703a59.jpg)


Here is one of the build options.  The case is a PM2425 from polycase.
![imp-watt-meter-opened-case](https://cloud.githubusercontent.com/assets/15392670/12759455/c819d618-c9a6-11e5-8db5-ead435683a78.jpg)

