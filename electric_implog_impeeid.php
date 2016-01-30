<?php
/* script to recieve the JSON data from the agent
   agent sends...
 	{ "I": 2.72236, "unixtime": 1385870780, "GMT": "2013-12-01T04:06:21", "V": 122.664, "PF": 0.917173, "W": 306.4, "Ipeak": 2.37886 } 
   php input receives
    { "I": 2.72236, "unixtime": 1385870780, "GMT": "2013-12-01T04:06:21", "V": 122.664, "PF": 0.917173, "W": 306.4, "Ipeak": 2.37886 } 

in the electric imp Agent the table is created like this; the values of this table are modified before sending  each point

{ "meterdata": { "I": 2.72236, "unixtime": 1385870780, "GMT": "2013-12-01T04:06:21", "V": 122.664, "PF": 0.917173, "W": 306.4, "Ipeak": 2.37886 } }

*/
$logfilename = 	"wattmeterlogs/" . "wattmeter.csv"; 

$dArray = json_decode(file_get_contents('php://input'),true);//php function json to php array

$message = $dArray['message'];//message
$HZ = 	$dArray['HZ'];//RMS Voltage
$V = 	$dArray['V'];//RMS Voltage
$I = 	$dArray['I'];//RMS Current
$Ipeak = 	$dArray['Ipeak'];//peak DC level at really high (?.? khz) sample speed
//$time = 		$dArray['GMT'];		//Time and date Agent
$W =  	$dArray['W'];	//The active power in Watts
$VA	 = 	$dArray['VA'];	//The apparant power

// see http://php.net/manual/en/timezones.php for supported timezones
date_default_timezone_set("America/Chicago");  //php handles timezones and daylight savings time
$dateTime = date('Y-m-d H:i:s');  //'Y-m-d H:i:s'

$fa = fopen($logfilename, 'a'); //other is 'w' for write

if(flock($fa, LOCK_EX)) {

  fwrite($fa, $dateTime . "," . ($V) ."," . ($I) . "," . $W .  "," . $VA . "," . $Ipeak . ","  . ($message) ."," . "\n");
  
  fflush($fa);
  flock($fa, LOCK_UN);
}
?>
