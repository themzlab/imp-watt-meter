# imp-watt-meter
single-phase energy meter for AC power.  Uses electric imp

The core of this design is the energy metering ic, ADE7953.  This ic does all of the measuring duties.

An electric imp module imp002 is connected with SPI to read the various metrics such as average active power, V*A, instantaneous current and so on.

The electric imp device reads data from the ADE7953 and packages a binary message.
The electric imp agent recieves this data and unpacks it creating a JSON message and http posts this
to a webhost account

A PHP script recieves this message and logs to a file.

Using the electric imp agent, it is possible to redirect the data to one of many
data repository services.

