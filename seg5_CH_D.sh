#!/bin/bash
# Delete old logs, to erase stale data.
rm -f /tmp/seg5_CH_D.log
#Note: Switched to custom log name to allow for concurrent running of scripts.
#Note: This script is for populating an NDC card on Seg3.
#+ Includes greps for "General" and "Unknown" errors
#+Reduced retries to 0.
#+Fixed data error detection.

#Initialize "NACK" and "Timeout" counters
NACK_Count=0
TIMEOUT_Count=0
DATAERROR_Count=0
BUSERR_Count=0
TXN_Count=0
#Initialize PHY_ERROR to 0.  PHY_ERROR = 1 is true, = 0 is false.
PHY_ERROR=0

# Write data pattern to FRU to test writes, and so read from EEPROM is easy to validate.
# This command could wear out the ROM, so it isnt used
#libi2ctest -c 10 100 100 3 -a 0xa4 -m 0 17 0x00 0x00 0x11 0x22 0x33 0x44 0x55 0x66 0x77 0x88 0x99 0xaa 0xbb 0xcc 0xdd 0xee 0xff 0 

#checks if user has entered a runtime
if [ "$1" = "" ] 
	then echo "You must enter desired runtime (seconds)."
	echo
	echo "Usage: ./BASHseg5.sh <RUNTIME>"
	echo
	exit 1
fi

startTime=$SECONDS
eTime=$(($SECONDS-$startTime)) 
while [ $eTime -lt $1 ]; do
eTime=$(($SECONDS-$startTime)) 
#echo "$Elapsed Time:$eTime  Requested Time:$1" #loop debug statement

#Check FRU on NDC
# 1st read of FRU
#Reducing retries to 0, to maximize ability to catch errors.
libi2ctest -c 39 100 100 0 -a 0xA0 -m 0 1 0x00 256 >/tmp/bus39sample1
TXN_Count=$(($TXN_Count+1))

#Begin PHY layer error checking
if grep -q NACK /tmp/bus39sample1
	then NACK_Count=$(($NACK_Count+1))
	PHY_ERROR=1
fi
#Timeout
if grep -q "Transaction timeout" /tmp/bus39sample1
	then TIMEOUT_Count=$(($TIMEOUT_Count+1))
	PHY_ERROR=1
fi
if grep -q "Bus Error or device no respond!" /tmp/bus39sample1
	then BUSERR_Count=$(($BUSERR_Count+1))
	PHY_ERROR=1
  cat /tmp/bus39sample1 >> /tmp/seg5_CH_D.log   
fi
#End PHY layer error checking

#Prepare 1st read data for data error checking
# Remove temp file output from read outputs, to avoid erroneous data read errors.
grep -v "Temp file name" /tmp/bus39sample1 > /tmp/bus39sample1Grep
# Remove non essential data from read output.
grep "0x" /tmp/bus39sample1Grep > /tmp/compbus39sample1

# 2nd read of FRU
#Reducing retries to 0, to maximize ability to catch errors.
libi2ctest -c 39 100 100 0 -a 0xA0 -m 0 1 0x00 256 >/tmp/bus39sample2
TXN_Count=$(($TXN_Count+1))

#Begin PHY layer error checking
if grep -q NACK /tmp/bus39sample2
	then NACK_Count=$(($NACK_Count+1))
	PHY_ERROR=1
fi
#Timeout
if grep -q "Transaction timeout" /tmp/bus39sample2
	then TIMEOUT_Count=$(($TIMEOUT_Count+1))
	PHY_ERROR=1
fi
if grep -q "Bus Error or device no respond!" /tmp/bus39sample2
	then BUSERR_Count=$(($BUSERR_Count+1))
	PHY_ERROR=1
  cat /tmp/bus39sample2 >> /tmp/seg5_CH_D.log   
fi
#End PHY layer error checking

#Prepare 2nd read data for data error checking
# Remove temp file output from read outputs, to avoid erroneous data read errors.
grep -v "Temp file name" /tmp/bus39sample2 > /tmp/bus39sample2Grep
# Remove non essential data from read output.
grep "0x" /tmp/bus39sample2Grep > /tmp/compbus39sample2




#Begin data error checking
#Compare 1st read and 2nd read to check for data errors.  Diff should be empty.
#Skip data check if PHY_ERROR is set.
if [ $PHY_ERROR = 0 ]
then
if diff /tmp/compbus39sample1 /tmp/compbus39sample2
#diff returns exit status 0 (true) if files are the same
then echo "Read compare on NDC FRU data: Files are the same."  >/dev/null
else echo "Different data detected on NDC FRU read !!!!" >/dev/null
diff /tmp/compbus39sample1 /tmp/compbus39sample2 >> /tmp/seg5_CH_D.log
echo >> /tmp/seg5_CH_D.log
DATAERROR_Count=$(($DATAERROR_Count+1))
fi
fi
#End data error checking

#Clear PHY_ERROR
PHY_ERROR=0





done #End while loop********************************


echo "Segment 5 Results: Left CP" >> /tmp/seg5_CH_D.log
echo "----------------------------------------" >> /tmp/seg5_CH_D.log
echo "NACK_Count: $NACK_Count">> /tmp/seg5_CH_D.log
echo "Timeout_Count: $TIMEOUT_Count" >> /tmp/seg5_CH_D.log
echo "BusError_Count: $BUSERR_Count" >> /tmp/seg5_CH_D.log
echo "DataError_Count: $DATAERROR_Count" >> /tmp/seg5_CH_D.log
echo "Transactions: $TXN_Count" >> /tmp/seg5_CH_D.log
echo "Elapsed Time: $eTime" >> /tmp/seg5_CH_D.log


echo >> /tmp/seg5_CH_D.log
echo "----------------------------------------" >> /tmp/seg5_CH_D.log

cd /tmp
tftp -p -l seg5_CH_D.log 192.168.0.100