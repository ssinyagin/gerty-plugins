#  Copyright (C) 2011  Stanislav Sinyagin
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software

# SNMP Action handlers for retrieving the hardware information
# from a Cisco device


package GP_Cisco::SNMP::Mixin::CiscoHardware;

use strict;
use warnings;
use JSON ();
use Net::SNMP qw(oid_lex_sort);

our $action_handlers_registry = {
    'cisco.chassis_info' => \&get_chassis_info,
};


our $retrieve_action_handlers = \&retrieve_action_handlers;


sub retrieve_action_handlers
{
    my $ahandler = shift;

    return $action_handlers_registry;
}


     
# OID used for hardware info
my %chassisEntityMibOid =
    (
     # ENTITY-MIB::entPhysicalHardwareRev
     '1.3.6.1.2.1.47.1.1.1.1.8' => 'HardwareRev',
     # ENTITY-MIB::entPhysicalSoftwareRev
     '1.3.6.1.2.1.47.1.1.1.1.10' => 'SoftwareRev',
     # ENTITY-MIB::entPhysicalSerialNum
     '1.3.6.1.2.1.47.1.1.1.1.11' => 'SerialNum',
     # ENTITY-MIB::entPhysicalModelName
     '1.3.6.1.2.1.47.1.1.1.1.13' => 'ModelName',
    );



# Collect hardware and firmware information from ENTITY-MIB

sub get_chassis_info
{
    my $ahandler = shift;
    my $action = shift;

    my $result = {};    
    my $session = $ahandler->session();
    my $chassis_phy;
    
    # find the first phy with entPhysicalClass = chassis(3)
    {
        # ENTITY-MIB::entPhysicalClass
        my $base = '1.3.6.1.2.1.47.1.1.1.1.5';
        my $prefixLen = length( $base ) + 1;
        my $table = $session->get_table( -baseoid => $base );
        
        if( defined( $table ) )
        {
            foreach my $oid (oid_lex_sort(keys %{$table}))
            {
                if( $table->{$oid} == 3 )
                {
                    $chassis_phy = substr( $oid, $prefixLen );
                    last;
                }
            }        
        }
        else
        {
            return {'success' => 0,
                    'content' =>
                        'Cannot retrieve ' .
                        'CISCO-WAN-3G-MIB::c3gGsmHistoryRssiPerMinute ' .
                        ' from ' . $ahandler->sysname . ': ' .
                        $session->error};
        }
    }

    if( not defined($chassis_phy) )
    {
        return {'success' => 0,
                'content' =>
                    'Cannot figure out the chassis phy ID' .
                    ' for ' . $ahandler->sysname};
    }

    # get the chassis info in a form suitable for Gerty::PropHistory
    {
        my $oids = [];
        foreach my $base (sort keys %chassisEntityMibOid)
        {
            push(@{$oids}, $base . '.' . $chassis_phy);            
        }
        
        my $snmpresult = $session->get_request( -varbindlist => $oids );
        if( defined($snmpresult) )
        {
            while( my ($oid, $value) = each %{$snmpresult} )
            {
                if( length($value) > 0 )
                {
                    my $prefix = $oid;
                    $prefix =~ s/\.\d+$//o;
                    my $prop = $chassisEntityMibOid{$prefix};
                    if( defined($prop) )
                    {
                        $result->{'hardware'}{'chassis'}{$prop} = $value;
                    }
                }
            }
        }
        else
        {
            return {'success' => 0,
                    'content' =>
                        'Cannot retrieve ENTITY-MIB variables ' .
                        ' from ' . $ahandler->sysname . ': ' .
                        $session->error};
        }
    }
    
    my $json = new JSON;
    $json->pretty(1);

    return {
        'success' => 1,
        'content' => $json->encode($result),
        'rawdata' => $result,
        'has_json' => 1,
        'has_rawdata' => 1,
    };
}


        
             
1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
