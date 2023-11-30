REM sistema.sol test batch script
REM usage: test.bat <nameserver-ip>

@ECHO on

SET nameserver=%1

REM HOSTS
nslookup mercurio.sistema.sol %nameserver%
nslookup venus.sistema.sol %nameserver%
nslookup tierra.sistema.sol %nameserver%
nslookup marte.sistema.sol %nameserver%
REM ALIAS
nslookup ns1.sistema.sol %nameserver%
nslookup ns2.sistema.sol %nameserver%
REM MAIL
nslookup -type=mx sistema.sol %nameserver%
REM NAMESERVERS
nslookup -type=ns sistema.sol %nameserver%
REM REVERSE
nslookup 192.168.57.101 %nameserver%
nslookup 192.168.57.102 %nameserver%
nslookup 192.168.57.103 %nameserver%
nslookup 192.168.57.104 %nameserver%

@ECHO off
