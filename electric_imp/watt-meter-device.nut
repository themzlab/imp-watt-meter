//Hugo says put this first

server.setsendtimeoutpolicy(RETURN_ON_ERROR, WAIT_TIL_SENT, 30);

///////////////////////////////////////////////////////////////////////////////=
/*
Code originated from
electric imp [[becky]]
      
Trace: • becky
Electric Imp Developer Wiki
www.analog.com/en/analog-to-digital-converters/energy-measurement/ade7953/products/product.html

  These notes were in the original code that I started with
  becky.txt · Last modified: 2013/02/06 18:34 by hugo
        
  Except where otherwise noted, content on this wiki is licensed under the following license: 
    CC Attribution-Share Alike 3.0 Unported
*/

    debuguart <- hardware.uart57;
     
    debuguart.configure(9600, 8, PARITY_NONE, 1, NO_CTSRTS);//no callback added

//reporting interval to use when you first boot up (faster, for troubleshooting)
fastinterval <- 5.0;//seconds
slowinterval <- 60;//seconds

backtoslow <- 240 + time(); //for 400 seconds after booting up, report quickly

fastmode <- 1;
intervaltime <- fastinterval;


_wifi <- {
    current = -1,
    connections = [
       { ssid = "ssid1", pw = "password1" },
       { ssid = "ssid2", pw = "password2" }
    ]
};

//// BELOW HERE, THERE SHOULD NOT BE ANY PERSONAL INFORMATION ////////////////
function mylog(note){
    if (server.isconnected()){
        server.log(note);
    }
}


// ***********WIFI CODE **************** {

function _debug(note){
    
        debuguart.write(note);
    
}


function ChangeWifi(ssid, pw, callback) {
    
    // if we're connected
    // disconnects from current network (if required)
    // tries connecting with the supplied ssid / pw
    // executes the callback 
    
    
    if (server.isconnected()) {
        // flush wifi and disconnect
        _debug("disconnect, flush 30\n");
        server.flush(30);
        server.disconnect();
    }
    _debug("setwifi\n");
    _debug(ssid);
    _debug(pw);
    _debug("_\n");
    imp.setwificonfiguration(ssid, pw);
    server.connect(callback, 30);
}
 

function ConnectOrFailToNextConnection(result = null) {
    
    // if we're connected, do nothing
     
    // This function doesn't use the result parameter,
    // but it's required since it's the callback from 
    // a server.connect()
    
    if (!server.isconnected()) {
      
      _wifi.current++;
      
      if (_wifi.current >= _wifi.connections.len()) {
        _wifi.current = 0;
        // go to sleep for 5 minutes
        // if we've already tried all the connections
        _debug("end list, sleep 5 min\n");
        
        imp.deepsleepfor(2*60);
      }
      
        // if there are still connections to try
        // grab current ssid and pw, and increment _wifi.current
        // for the next attempt (if connection fails)
        
        local ssid = _wifi.connections[_wifi.current].ssid;
        local pw = _wifi.connections[_wifi.current].pw;
       
        // try connecting
        _debug("changing wifi\n");
        ChangeWifi(ssid, pw, ConnectOrFailToNextConnection);
      
    }
    else
    {   
        _debug("connected," +_wifi.current + "\n");
        mylog("connected " + _wifi.current + " " + imp.getssid());
        
        //Get calibration data from the agent
        //When the data comes back, a function is called
        //that will start the ADE chip and start the reporting of data
        //this is how the _specific_ calibration data gets brought to the device
        
        agent.send("request_cals",{address = hardware.getdeviceid()});
        
        if (nextwakeup==null){
          
          mylog("start reporter from connection routine");
          nextwakeup = imp.wakeup(30,reporter);//kick off reporting again
        }
        else
        //if there is a wakeup - don't have to do anything
        {
        
        }
    }
}


server.onunexpecteddisconnect(function(reason) { 
    
    // called after imp tries to reconnect to current
    // server for 1 minute and fails
    // Loop through connections until we connect
    
    _wifi.current = -1;
    ConnectOrFailToNextConnection();
    
}); 
 

//}//end wifi code



//********* NOTES {

//imp pinout
// pin1 = hold high to do i2c, OR it is SCLK for spi189
// pin2 = no connection
// pin5 = pin5 uart57 (debug)
// pin7 = pin7 uart57 (debug)
// pin8 = MOSI for spi189 or i2c89 clock
// pin9 = ISO for spi189 or i2c89 data
// pinA = Reset ADE chip
// pinB = spi chip select, hold high for i2c
// pinC = no connection
// pinD = no connection
// pinE = ZX ADE7953 Pin1

//ADE7953 pins
// Pin1     ZX - pinE (bodge wire on .c board version)
// Pin20    default is for !REVP, (no connection)
// Pin21    ZX_I    no connection
// Pin22    IRQ     no connection (substitue function to Pin1 if you can)

//ADE7953

//Current channel can reach 250mV peak max to -250mV peak min (+500mV or -500mV differential peak)

//I will allow 30mV common mode

//so really the limit is 220mV peak to -220mV peak  (440mV differential)

//* I want a big crest factor

//if I take a nominal 20A RMS signal this can reach a peak of 28A and -28A but with non-sinusoidal maybe
//it will be 2X that so up to 60A peak in one direction (crest factor 3)

//60A * .0005ohm resistor is 30mV against a peak of 220mV this is a gain of 7 (8 actually used)
//if common mode is zero then we can reach 62.5A as the maximum DC reading

//60A * .002ohm resistor is 120mV against a peak of 220mV, this is a gain of ~2
//if common mode is zero then we can reach 62.5A as the maximum DC reading

//60A * .001ohm resistor is 60mV against a peak of 220mV, this is a gain of ~4
//if common mode is zero then we can reach 62.5A as the maximum DC reading

//PGA of 2 is used for the .002 ohm shunt resistor
//7.45058E-06    mV	per lsb
//0.007450581	uV	per lsb
//7.450580597	nV	per lsb

//PGA of 4 is used for the .001 ohm shunt resistor
//}



// ***********CONSTANTS **************** {
//name the registers to improve readability later on

const Reserved = 0x120;
const ADEread = 0x71;
const ADEwrite = 0x70;

const LCYCMODE = 0x004;
const AWATT = 0x212;
const PGA_V = 0x007;
const PGA_IA = 0x008;
const PGA_IB = 0x009;
const AP_NOLOAD = 0x203;
const PFA = 0x10a;
const AVA = 0x210;
const BIRMSOS =0x292; 
const SAGCYC = 0x000;
const IRQENA = 0x22C;
const SAGLVL = 0x200;
const AIRMSOS = 0x286;
const ACCMODE = 0x201;//accumulatione mode
const DISNOLOAD = 0x001;//No-load detection disable
const CONFIG = 0x102;
const CFMODE = 0x107;//not used
const AWGAIN = 0x282; //not used , 0x400000 default
const AVAGAIN = 0x284; 
const AVGAIN = 0x281;
const AENERGYA = 0x21E; //active energy accumulation - signed
const APENERGYA = 0x222; //apparant energy accumulation - signed 
const RENERGYA = 0x220;//reactive energy
const VRMSOS = 0x288; //complicated RMS offset procedure page 8 AN-118
const VRMS = 0x21C;
const IRMSA = 0x21a;

const VPEAK = 0x226;
const RSTVPEAK = 0x227;
const RSTIAPEAK = 0x229;// - peak with reset

const AWATTOS = 0x289;
const AVAOS = 0x28B;

const RSTIRQSTATA = 0x22E;
const IRQSTATA= 0x22D;
const LAST_RWDATA = 0x2FF;

const Period = 0x10e;
const ALT_OUTPUT = 0x110;
const V = 0x218;
const IA = 0x216;

const waveN = 180;//number of data points to grab for the waveform
const Ntrend = 306;//64 204 306

//}



SETTINGS <- {
    //Things that are your preference for this design as opposed to
    //calibrations for a specific unit of this design.
    //later I could change this so that these are scaled from the calibrations.
    SAGCYC = 254
    ,SAGLVL = 17000
    
    //THREE bytes here control the function of;
        // Pin 1 - default is to have zero crossing; it is what we normally used
        // Pin 21  (not connected)
        // Pin 20  (not connected)
    ,ALT_OUTPUT =  0
    ,AP_NOLOAD = 100//1000//40000//58393
};

//it is only used during the boot sequence and then is not required. (unless ADE is restarted?)
// let's keep it in root table case rebooting the ADE becomes a thing...
CAL <- {};


//  ********* DEFINITIONS ******************** {

TableToAgent <- {}; //to build up the response to be sent to the agent
nextwakeup <- null; //will be a handle so that pending wakeups can be cancelled

infoLog <- {};//for adding to response, sending to browser when required


errorLog <- {note = "",
              time = 0};//for adding to response, sending to browser when required

rawdata <- {
  Vcount = 0,
  Icount = 0,
  Vpeakcount = 0,
  Ipeakcount = 0,
  Wcount = 0,
  VAcount=0,
  AEcount = 0,
  REcount = 0,
  ActiveEnergy = 0, //i.e. Watts by energy
  deltaT = 0,
  unixtime = 0,
  PF = 0
}




    //The reset pin for the ADE
    hardware.pinA.configure(DIGITAL_OUT);
     //configure the zero-crosing detector
    ZX <- hardware.pinE;
    
    ZX.configure(DIGITAL_IN);



//}DEFINITIONS



//  ************ UTILITY FUNCTIONS ******************** {


 
 
function isbitset(mybit,myvalue){
    
    return ((mybit & myvalue) == mybit);
}


function string16bit (integerval){
  //Formats a number into a string that is suitable for I2C
  
  if (integerval <0){
    integerval += 65536;//twos complement, 24 bit
  }
  
  return format("%c%c",((integerval>>8) & 0xFF),(integerval & 0xFF));
  
}



function string24bit(integerval){
  
  //Formats a number into a string that is suitable for 
  //sending with I2C write command
  
  if (integerval <0){
    integerval += 16777216;//twos complement, 24 bit
  }
  
  return format("%c%c%c", (integerval>>16),((integerval>>8) & 0xFF),(integerval & 0xFF));
  
}

//convert to signed number after reading from the communication bus
function readsigned(addr) {
    local r = readbus( addr);
    local length = 1 + (addr>>8);
    local mask = 1<<(length<<3);
    if (r > (mask>>1)) return r-mask;
    return r;
}

//end utility functions
//}



//  ********* READ AND WRITE i2c ******************** {

function readi2c( addr) {
    
    // registers 0-ff are 8 bit, 100-1ff are 16 bit, 200-2ff are 24 bit and
    // 300-3ff are 32 bit
    // a bit of bit-shift and math are used to automatically select the correct
    // number of bytes; (1+(addr>>8))
    
    //ADEread for read (ADEwrite for write)   

    local res=null;
    
   
         res = hardware.i2c89.read(ADEread, format("%c%c", addr>>8, addr&0xff), (1+(addr>>8)));
    
    
    local resv = 0;
 
    if (res != null) {
        
        foreach (b in res) {
            resv = (resv<<8) + b;
        }  
        return resv;
    }
    else
    {
        mylog("i2c read null " + addr);//normal operation does not cause this
    }
 
    return 0;
}




function writei2c(addr, datastring) {
    
    //i2c is the hardware
    //addr is an integer
    //datastring is a string 1 to 3 length
    //the string is a characters, each describes a bit pattern
    //stacked together to create an integer
    
    // registers 0-ff are 8 bit, 100-1ff are 16 bit, 200-2ff are 24 bit and 
    // 300-3ff are 32 bit

        hardware.i2c89.write(ADEwrite, format("%c%c", addr>>8, addr&0xff) + datastring);
    
}

//end Read and Write i2c
//}



//  ********* READ AND WRITE spi ******************** {



function readspi(addr ){
    
    //no of result bytes will be 1 2 or 3 or 4
    local temp=format("%c%c", addr>>8, addr&0xff) + format("%c",128);
    
    local _bytes =  (1+(addr>>8));
    local fill = format("%c",0xaa);
    
    for(local a=0;a<(_bytes);a+=1){
        temp+=fill;
    }
   
    
    _bytes+=3;
    
    chipselect(0); 
     
    local d = hardware.spi189.writeread(temp); //output is string, blob?
     
    chipselect(1); 
    
    local _output = 0;
    
    //16 bit register - 
    //<addr><addr><0><msb><lsb>
    
    //two bytes of address + read/write byte, start at index 3.
    
    for(local a=3;a<(_bytes);a+=1){
         _output = (_output<<8) + d[a];
         
    }
        
	return _output;
    
}


function writespi(addr,value){
    
    
    local temp = format("%c%c", addr>>8, addr&0xff) + format("%c",0) +  value;
    
    chipselect(0);
     
    local d  = hardware.spi189.write(temp); //output is integer no of bytes
    
    chipselect(1);
  
}

//end Read and Write spi
//}



local function setupChip(){
    
    
    //Some required register settings from the datasheet
    writebus(0xFE, "\xAD");//page 11
    writebus(Reserved, "\x30");//page 11 0x120
    
    // configure voltage gain to 1 (500mV P-P swing max) but our nominal signal
    //is 170mV, allowing for waveform errors
    writebus(PGA_V, "\x0");
   
    // configure active energy line accumulation mode
    
    //LCYCMODE  is not used yet, but it would let me describe how many
    //line cycles over which I want the energy registers to be updated and
    //interrupts flagged.  I think it would help with precision or perhaps
    //timing in a trend plot
    
    writebus(LCYCMODE, "\x40");//x40 is the default
    
    
    writebus(SAGCYC,string24bit(SETTINGS.SAGCYC));//set sag to XXX cycles - 
    
    
    writebus(DISNOLOAD, "\x07");//temporarily disable ALL the no-load
    
        //SET here, after temporarily disabling the feature 
        writebus(AP_NOLOAD,string24bit(SETTINGS.AP_NOLOAD));//0x203
    
    
    writebus (DISNOLOAD, "\x00");//re-enable the no-load after changing settings
    
    //==========================================================================
    
    //the 19th bit enables the SAG interrupt
    writebus(IRQENA, string24bit((1<<19) | (1<<20)));
    
    //==========================================================================
    //the SAG level for voltage detection
    
    
    writebus(SAGLVL, string24bit(SETTINGS.SAGLVL));
   
    writebus(ALT_OUTPUT, string16bit(SETTINGS.ALT_OUTPUT));
    
    //==========================================================================

    
    mylog("SAGLVL," + readbus( SAGLVL));
    mylog("ALT_OUTPUT " + readbus( ALT_OUTPUT));
    mylog ("PGA_IA "+ readbus (PGA_IA));
    
    //mylog(readbus( Reserved) + " required register setting");//page 18
    //mylog(readbus( 0xFE) + " required register unlock");//page 18
    //mylog(readbus( 0x008) + " register 8");
    //mylog(readbus( 0x009) + " register 9");
    //mylog(readbus( ADEwrite2) + " silicon number");
    //mylog(readbus( 0x007) + " register 7");
    //mylog(readbus( LCYCMODE) + " register 4");
    //mylog(readbus( SAGCYC) + " SAGCYC Register"); //this line WORKS 
    
    //mylog(readbus( 0x107) + " should be 768");        //      1100000000
    //mylog(readbus( 0x102) + " is the CONFIG register"); //'1000000000000100
    
    //bit-wise configuration, first read as 1048576
    mylog(readbus( IRQENA) + " IRQENA Register"); 

    //Active and Apparant power are so closely releated that they use the same
    //gain calibration constant
    
    
    //=======================================================================================
    
    mylog("CONFIG before" + readbus(CONFIG));
    
    //add bit 5 to this register - REVP mode changed    
    local newconfig = (readbus(CONFIG) | (1<<5)|(1<<12)|(1<<8)); 
   
    
    mylog("new config is ...... "+ newconfig);
    
    local mytemp = string16bit(newconfig);
    
    writebus(CONFIG, string16bit(newconfig));
    
    
    mylog("CONFIG after " + readbus(CONFIG));//37156
    
   
    //======================================================================================
    
   mylog("checksum "+readbus(0x37F) + " : -2077487640"); //+ "=1193481607");
   
    //typically, the next action is either to run the calibration or else start reporting
    
}



local function writecals(){
    
    // configure current gains?   ?(125mV swing max)
    writebus(PGA_IB, CAL.PGA_I);//right now, not using B
    
    writebus(PGA_IA, CAL.PGA_I);
    
    mylog ("PGA_IA "+ readbus (PGA_IA));
    
    //CALIBRATIONS entered into the ADE chip, particularly offsets
    
   
    writebus(AWATTOS,string24bit(CAL.AWATTOS));//same as below

    writebus(AVAOS,string24bit(CAL.AVAOS));//same as above
    
    mylog(readsigned(AWATTOS) + " AWATTOS offset"); 
    mylog(readsigned(AVAOS) + " AVAOS offset"); 
      

    mylog(readbus( AP_NOLOAD) + " AP_NOLOAD Register default reads 58393"); //
    
    mylog(readbus( AVAGAIN) + " AVA GAIN: "); //
    
    
    mylog(readbus( LAST_RWDATA) + " value of the last good 24bit register writei2c"); //
    
    
    
    writebus(VRMSOS, string24bit(CAL.VRMSOS));
    
    //CURRENT offset Channel A calibration: AN-1118
    
    // the AIRMSOS register for offsetting the RMS current reading on channel A  
    writebus(AIRMSOS, string24bit(CAL.AIRMSOS));
    
    //calibrated using a known small value input
    mylog(readsigned(AIRMSOS) + " AIRMSOS offset"); 
    

    
}//Calibrations



lasttime <- hardware.millis();



function getawavespi(){
    
    //credit:
    //peter, electricimp.com
    //for helping with all the awesome speed improvements
    
    local chipSelect = CSpin.write.bindenv(CSpin);
    local myspi = hardware.spi189;
    local myspireader = myspi.writeread.bindenv(myspi);

    //pre-compute the register address string
    //add the read byte and blank bytes to keep the clock going
    //strings are 6 bytes long
    local readVolts= format("%c%c", (V>>8), V&0xff) + format("%c",128) + "\xaa\xaa\xaa";
    
    local readCurrent= format("%c%c", (IA>>8), IA&0xff) + format("%c",128)+ "\xaa\xaa\xaa";
    
    //blobs to hold the data, 6 bytes each X number of data points
  
    
    local _Iblob = blob(waveN*6); //current
    local _Vblob = blob(waveN*6); //volts
    
    local vwriter = _Vblob.writestring.bindenv(_Vblob);
    local iwriter = _Iblob.writestring.bindenv(_Iblob);
    
    local _result = "";
    
    local zerocross = ZX.read.bindenv(ZX);
    
    local endT = 0;
    local start = 0;
    
    
    if (zerocross()==0){
      for(local a=0;a<1200;a+=1){
        if (zerocross()){
          break;
        }
      }
        
    }
    else
    {
      for(local a=0;a<1200;a+=1){
        if (!zerocross()){
          break;
        }
      }
      
    }
    
    imp.sleep(0.0062);//try to line up the trigger..

     start = hardware.micros();
    
    //read really fast
    
    for(local a=0;a<waveN;a+=1){
      
        chipSelect(0);
        
        _result = myspireader(readVolts);
        chipSelect(1);
        
        vwriter(_result);
         
         
        chipSelect(0);
        _result = myspireader(readCurrent);
        chipSelect(1);
        
        iwriter(_result);
        
       
    };//194 microseconds per loop?
    
    endT = hardware.micros();
    
     //Get RMS V and I values so we can normalize the vertical scale
    local ICOUNTA = readbus(IRMSA)
    local PFi = rawdata.PF = readsigned( PFA);
    local VCOUNT = readbus( VRMS);
    
    
    addlog((endT-start)+" ,usec ,");

    local Iblob = blob(waveN*3); //current
    local Vblob = blob(waveN*3); //volts
    
    //pack the blob down, getting rid of waste bytes
    //The agent could also do this, but this way the wifi
    //does not have to send bytes that are not used
    
    for(local a=3;a<(waveN*6);a+=6){
        
        Vblob.writen(_Vblob[a],'b');
        Vblob.writen(_Vblob[a+1],'b');
        Vblob.writen(_Vblob[a+2],'b');
        
        Iblob.writen(_Iblob[a],'b');
        Iblob.writen(_Iblob[a+1],'b');
        Iblob.writen(_Iblob[a+2],'b');
        
    };
    
    //build a table up with tables and values to send to the agent
    
    local sendtable = {};
    sendtable["IAblob"] <- Iblob;
    sendtable["Vblob"] <- Vblob;
    sendtable["span"] <- (endT-start);
    sendtable["PFi"] <- PFi;
    

    //add RMS values to the table so that the agent will get them
    sendtable["ICOUNTA"] <- ICOUNTA;
    sendtable["VCOUNT"] <- VCOUNT;
    
    //Send the raw blobs to the agent where they can be decoded and
    //turned into waveforms
    
    agent.send("wave",sendtable);
  
}



function getatrendspi(){
 
  
    local Iblob = blob(Ntrend*3);//current
    local Vblob = blob(Ntrend*3);  //volts
    local tblob = blob(Ntrend*4);  //time
  
    //pre-compute the  address
    local Vaddr = format("%c%c", (VRMS>>8), VRMS&0xff)
    //local IAaddr = format("%c%c", (IRMSA>>8), IRMSA&0xff)
    local IAaddr = format("%c%c", (AWATT>>8), AWATT&0xff); //IRMSA OR AWATT
  
    Vaddr = Vaddr + format("%c",128) + "\xaa\xaa\xaa";
    IAaddr= IAaddr + format("%c",128)+ "\xaa\xaa\xaa";
    //
    local _result = "";
    local start =  hardware.micros();
  
    local chipSelect = CSpin.write.bindenv(CSpin);
    local myspi = hardware.spi189;
    local myspireader = myspi.writeread.bindenv(myspi);
    
    //read, then delay to create the desired resolution and span
    local _end = 0;
    
    for(local a=0;a<Ntrend;a+=1){
    
    
        chipSelect(0);
        _result = myspireader(Vaddr);
        chipSelect(1);
        
        tblob.writen(hardware.micros(), 'i');
        
        Vblob.writen(_result[3],'b');
        Vblob.writen(_result[4],'b');
        Vblob.writen(_result[5],'b');
        
        
        
        chipSelect(0);
        _result = myspireader(IAaddr);
        chipSelect(1);
        
        Iblob.writen(_result[3],'b');
        Iblob.writen(_result[4],'b');
        Iblob.writen(_result[5],'b');
        
        
        imp.sleep(0.0310);
    
    }
    //it has been measured and the above takes 2.04 seconds
    
    local sendtable = {};
    sendtable["IAblob"] <- Iblob;
    sendtable["Vblob"] <- Vblob;
    sendtable["tblob"] <- tblob;
    sendtable["start"] <- start;
    sendtable["unixtime"] <- (time()-1);
    
    //Send the raw blobs to the agent where they can be decoded and
    //turned into waveforms
    
    agent.send("trend",sendtable);
  
}



function getawavei2c(){
 
    local Iblob = blob(waveN*3); //Amps
    local Vblob = blob(waveN*3);  //volts
    local tblob = blob(waveN*4);  //time

 
    //pre-compute the register address
    local Vaddr = format("%c%c", (V>>8), V&0xff);
    
    local Iaddr = format("%c%c", (AWATT>>8), AWATT&0xff); //IRMSA OR AWATT
    

      local myi2c = hardware.i2c12;
    
    local myi2creader = myi2c.read.bindenv(myi2c);
    
    
    local _result = "";
    
    local _end = 0;
    local start = 0;
    start =  hardware.micros();
    
    local vwriter = Vblob.writestring.bindenv(Vblob);
    local iwriter = Iblob.writestring.bindenv(Iblob);
 
    local endT = 0;
    local start = 0;
    start =  hardware.micros();
  
  //TRY to read as FAST as possible
  
    for(local a=0;a<waveN;a+=1){
    
    try{
        _result = myi2creader(ADEread, Vaddr, 3);
    }
    catch(e){
        _result = "\x00\x00\x00";
    }
    
    vwriter(_result);
    
    
        _result = myi2creader(ADEread, Iaddr, 3);
        
        try{
        iwriter(_result);//bad parameter
        
            
        }
        catch(e){
            //mylog(_result );
            //mylog("error resulted");
            iwriter("\x00\x00\x00");
        }
    
    }
  
    endT =  hardware.micros();
    
    //read these in order of importance
    local ICOUNTA = readbus(IRMSA)
    local PFi = rawdata.PF = readsigned( PFA);
    local VCOUNT = readbus( VRMS);
    
    mylog(endT-start);
    
    local sendtable = {};
    sendtable["IAblob"] <- Iblob;
    sendtable["Vblob"] <- Vblob;
    sendtable["start"] <- start;
    sendtable["span"] <- (endT-start);
    sendtable["PFi"] <- PFi;
     
    
    sendtable["ICOUNTA"] <- ICOUNTA;
    sendtable["VCOUNT"] <- VCOUNT;
    
    //Send the raw blobs to the agent where they can be decoded and
    //turned into waveforms
    
    agent.send("wave",sendtable);
  
 
}



function getatrendi2c(){
 
  
    local Iblob = blob(Ntrend*3); //current RMS
    local Vblob = blob(Ntrend*3);  //volts RMS
    local tblob = blob(Ntrend*4);  //time stamp
  

    //pre-compute the I2C address
    local Vaddr = format("%c%c", (VRMS>>8), VRMS&0xff)
    
    //local IAaddr = format("%c%c", (IRMSA>>8), IRMSA&0xff)
    local IAaddr = format("%c%c", (AWATT>>8), AWATT&0xff)
  
    local twriter = tblob.writen.bindenv(tblob);
    local us = hardware.micros.bindenv(hardware);
    
    //local myi2c = hardware.i2c89;
    local myi2c = hardware.i2c12;
    
    local myi2creader = myi2c.read.bindenv(myi2c);
    
    //
    local _result = "";
    
    
    local _end = 0;
    local start = 0;
   
    
    local vwriter = Vblob.writestring.bindenv(Vblob);
    local iwriter = Iblob.writestring.bindenv(Iblob);
  
    //read, then delay to create the desired resolution and span
  
    start =  hardware.micros();
    for(local a=0;a<Ntrend;a+=1){
    
        try {
           
            _result = myi2creader(ADEread, Vaddr, 3);
            
        }
        catch (e)
        {
            _result = "\x00\x00\x00";
        }
        
         vwriter(_result);
    
         twriter(us(), 'i')
    
        
         
        try {
            
            _result = myi2creader(ADEread, IAaddr, 3);
            
        }
        catch (e)
        {
            _result = "\x00\x00\x00";
        }
        
        iwriter(_result);
        
        imp.sleep(0.0310);
    
    }
    
    _end =  hardware.micros();
    
    mylog(start - _end);
    
    //it has been measured and the above takes 2.04 seconds
    
    
    local sendtable = {};
    sendtable["IAblob"] <- Iblob;
    sendtable["Vblob"] <- Vblob;
    sendtable["tblob"] <- tblob;
    sendtable["start"] <- start;
    sendtable["unixtime"] <- (time()-1);
    
    //Send the raw blobs to the agent where they can be decoded and
    //turned into waveforms
    
    agent.send("trend",sendtable);
  
}



function addlog(_note){
    
    //adds a log message to the table that is going to be passed to the agent
    //Datalogging and messaging is done through the agent.
    
    local n = infoLog.len();
    infoLog[n] <- {time = time(), note = _note};
  
    if (!("infoLog" in TableToAgent)){
        
        TableToAgent["infoLog"]<-infoLog;
        
    } 
    else
    {
        TableToAgent["infoLog"]=infoLog; 
    }
}



function reporter(recursion=true) {
  
    rawdata.unixtime = time();
    
    if (recursion){
    
        if ((fastmode ==1) && ((rawdata.unixtime - backtoslow) > 0)){
          fastmode=0;
          intervaltime = slowinterval;
          
          addlog("long interval set");
          
        }
        
        nextwakeup = imp.wakeup(intervaltime, reporter);  
    }
  
  
    IRQHandler = no_function;//acutally, have not implemented interrupts yet
    
    local presenttime = hardware.millis();
    
    //read peak with reset
    rawdata.Vpeakcount = readbus( RSTVPEAK);
    
    rawdata.Icount = readbus( IRMSA); 
  
  
    rawdata.deltaT = presenttime-lasttime;
    lasttime = presenttime;
    
    rawdata.ActiveEnergy = readsigned(AENERGYA);
    rawdata.AEcount = readsigned(APENERGYA);
    rawdata.REcount = readsigned(RENERGYA);
    
   
    local cyclecount = readbus( Period);
    
    
   
    rawdata.Vcount = readbus( VRMS);
    
    //Power factor, real time - instantanteous
    
    rawdata.PF = readsigned( PFA);
    
    
    rawdata.VAcount = readbus( AVA);
    rawdata.Wcount = readbus( AWATT);
    
    //Reset interrupt status Current Channel A
    readbus(RSTIRQSTATA);//we don't need the results
    
    //read I peak with reset
    
    rawdata.Ipeakcount =  readbus( RSTIAPEAK);
    
    
    local _IRQSTATA = readbus(IRQSTATA);  
  

    if (isbitset((1<<6),_IRQSTATA)){
    //mylog("no active power");
    }
    if (isbitset((1<<7),_IRQSTATA)){
    //mylog("no reactive power");
    }
    if (isbitset((1<<8),_IRQSTATA)){
    //mylog("no apparant power");
    }
  
  
    if (!("rawdata" in TableToAgent)){
        TableToAgent["rawdata"]<-rawdata;
    }  
    

    agent.send("logbyagent",TableToAgent);
    
    TableToAgent = {};
    infoLog = {};//reset it

  
}



// ************************** SPI or i2c ***************** if {
    
    //assign this way so that the read/write can be changed
    //programmatically to be i2c or spi 
    readbus <- readi2c;
    writebus <- writei2c;
    
    
    function setupi2c(){
        
        
            hardware.i2c89.configure(CLOCK_SPEED_400_KHZ);
            hardware.pin1.configure(DIGITAL_OUT);
            hardware.pin1.write(1);    
        
        
        readbus = readi2c;
        writebus = writei2c;
            
    }


    function setupspi(){
        
        CSpin <-  hardware.pinB;
        CSpin.configure(DIGITAL_OUT);

        chipselect <- CSpin.write.bindenv(CSpin);

        readbus = readspi;
        writebus = writespi;
        //speed does not seem to go higher than 3750 actual returned
        chipselect(1);
        local speed = hardware.spi189.configure( CLOCK_2ND_EDGE | MSB_FIRST | CLOCK_IDLE_HIGH, 3750);
        mylog("speed is " + speed);
        
    }


   
      setupspi();
      getawave <- getawavespi;
      getatrend <- getatrendspi;
    
   
//} SPI or i2c


//agent needs the id if it reboots
agent.on("getid", function (_param) {agent.send("id",hardware.getdeviceid())});


local function boot (){
    
    local _result = 0;
    
    //readings tend to be wack when the chip first fires up
    // let us read a few times with this temporary function so that
    //things are steady state when the first messages go out.
    //simplifies filtering and data collection
    
    for(local a=0;a<(3);a+=1){
        imp.sleep(1.0);
        _result = readbus( RSTVPEAK);
        
        _result = readbus( IRMSA); 
        
        lasttime = time();
        
        _result = readsigned(AENERGYA);
        _result = readsigned(APENERGYA);
        _result = readsigned(RENERGYA);
        _result = readbus( Period);
        _result = readbus( VRMS);
        _result = readsigned( PFA);
        _result = readbus( AVA);
        _result = readbus( AWATT);
        readbus(RSTIRQSTATA);//we don't need the results
        _result =  readbus( RSTIAPEAK);
    }
    
    imp.sleep(fastinterval);
    
   
    if (CAL._VOLTSCALE==0){
        mylog("non-working unit");
    }
    else
    {
        if (nextwakeup){
     
      imp.cancelwakeup(nextwakeup);
      reporter();
   }
   else{
    reporter();//begin!
   }
    }
    
    
}


//Perform reset of ADE7953


agent.on("cals_sent",function(_caltable){
    
    //BOOT when the calibration table comes in
    CAL = _caltable;
    
    ///HERE I would like to make a boot sequence where the chip is reset first after waiting 100ms

    //Then 100ms wait again after the reset
    //then run the setup
    //wait 100ms - initiate reset - wait at least 100ms 
    
   
        imp.wakeup(0.200, function (){hardware.pinA.write(0)});
        imp.wakeup(0.250, function (){hardware.pinA.write(1);});
    
    //Do the setup of all else and begin reporting STARTS HERE
    imp.wakeup(0.400,function(){
            setupChip(); //getting it running 
            writecals(); //offsets and gains (specific to each board)
            
            boot();  //makes a few initials and then begins running
           
        }
    ); //and start reporting at the end of setup

});


//when user sends buttons from web app to agent
agent.on("buttonpress",function(iv){
 
 //mylog(imp.getmemoryfree());//66908 after booting
 addlog(imp.getmemoryfree() + " ,mem, ");
 
 if (iv.type == "measurement"){
   
  //this means a descrete reading is being requested starting now
   
   imp.cancelwakeup(nextwakeup);
   
   //call back to the agent indicating succussful communication
   
   agent.send("ack",iv.button);
   
   //get a reading out of the way
   //will cause a state to be send
   //but send false to prevent another wakeup event
   reporter(false);
   
   
  local _interval = iv.time.tointeger();
  
   //send a new watt reading in _interval sec. and then resume normal operation
   if (_interval >1) {
      imp.wakeup(_interval,reporter);
   }
   
   //report which power reading has just been completed
  
  if (!("measurement" in TableToAgent)){
    TableToAgent["measurement"]<-{
      name = iv.button
    }
  }
  
 }
 else
 {
   agent.send("ack","");
 }
 
 //foreach (idx,val in iv) { mylog("index= "+ idx  +" value= " + val );}
 
 if (iv.button == "waveform"){
   
    //first get rid of the next callback
    imp.cancelwakeup(nextwakeup);
   
    TableToAgent = {};
        fastmode = 1;
        intervaltime = fastinterval;
        backtoslow = 300 + time(); //reset time at which fast reporting expires
    
    //indicate that some waveform data will have been seperately sent
    //to the agent prior to the reporter sending summary data
    TableToAgent["chart"] <- 1;
    
    //This will add the various things to the response
    getawave();
    
    //This will add meterdata to the response and send it
    reporter();
 
    //schedule another wakeup as usual
 
 }
 
 if (iv.button == "trend"){
   
    //first get rid of the next callback
    imp.cancelwakeup(nextwakeup);
    
    //temporarily tuck this here: a way to speed up reporting programmatically
        fastmode = 1;
        intervaltime = fastinterval;
        
        backtoslow = 300 + time(); //reset time at which fast reporting expires
   
    TableToAgent = {}; 
   
    TableToAgent["chart"] <- 1;
   
    getatrend();
 
    reporter();
 
    //schedule another wakeup as usual
 
 }
});




//  *** Interrupt handleers NOT IMPLREMENTED YET ********* {

function no_function(){}


function booted(){
    
    //This function is NOT implemented yet
    
    //mylog("interrupt triggered");
    
    //Read the interrupt status register to determine if
    //this is a SAG event
    
    if (isbitset(0x80000,readbus(IRQSTATA))){
        mylog("SAG Detected");
    }
    else
    {
        mylog("General interrupt detect");
    }
   
   IRQHandler = no_function;
}


IRQHandler <- booted;


//}



// On boot, make sure we're connected
// or try connecting
ConnectOrFailToNextConnection();


mylog(server.log(imp.getmacaddress()));
mylog(imp.getssid());

