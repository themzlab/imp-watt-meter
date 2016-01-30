# imp-watt-meter
single-phase energy meter for AC power.  Uses electric imp

The core of this design is the energy metering ic, ADE7953.  This ic does all of the measuring duties.

An electric imp module imp002 is connected with SPI to read the various metrics such as average active power, V*A, instantaneous current and so on.


