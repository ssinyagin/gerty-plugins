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

# SNMP Action handlers for retrieving the interface status information
# from a Cisco device


package GP_Cisco::SNMP::Mixin::CiscoPort;

use strict;
use warnings;
use JSON ();
use Socket qw(inet_ntoa);


our $action_handlers_registry = {
    'cisco.port_info' => \&get_port_info,
};


our $retrieve_action_handlers = \&retrieve_action_handlers;


sub retrieve_action_handlers
{
    my $ahandler = shift;

    return $action_handlers_registry;
}


my %ifTypeInterested =
    (6 => 1);


my %ifStatusVal =
    (1 => 'up',
     2 => 'down',
     3 => 'testing',
     4 => 'unknown',
     5 => 'dormant',
     6 => 'notPresent',
     7 => 'lowerLayerDown');

my %truthVal =
    (1 => 1,
     2 => 0);

my %ciscoAddrType =
    (1 => 'ipv4',
     20 => 'ipv6');

my %udldOperStatus =
    (1 => 'shutdown',
     2 => 'indeterminant',
     3 => 'biDirectional',
     4 => 'notApplicable');

my %udldMode =
    (1 => 'enable',
     2 => 'disable',
     3 => 'aggressive',
     4 => 'default');



# Collect port status from the following MIBs:
# IF-MIB
# CISCO-CDP-MIB
# CISCO-UDLDP-MIB

sub get_port_info
{
    my $ahandler = shift;
    my $action = shift;

    my $result = {};    
    my $session = $ahandler->session();

    my %name2index;
    my %index2name;
    
    # Get port names, descriptions, op. status
    {
        # IF-MIB::ifDescr
        my $base = '1.3.6.1.2.1.2.2.1.2';
        my $prefixLen = length( $base ) + 1;
        my $table = $session->get_table( -baseoid => $base );
        
        if( defined( $table ) )
        {
            while( my( $oid, $val ) = each %{$table} )
            {
                my $ifIndex = substr( $oid, $prefixLen );
                $name2index{$val} = $ifIndex;
                $index2name{$ifIndex} = $val;
                $result->{'ports'}{$val}{'ifIndex'} = $ifIndex;
            }
        }
        else
        {
            return {'success' => 0,
                    'content' =>
                        'Cannot retrieve ' .
                        'IF-MIB::ifDescr ' .
                        ' from ' . $ahandler->sysname . ': ' .
                        $session->error};
        }
    }

    {
        # IF-MIB::ifType
        my $base = '1.3.6.1.2.1.2.2.1.3';
        my $prefixLen = length( $base ) + 1;
        my $table = $session->get_table( -baseoid => $base );
        
        if( defined( $table ) )
        {
            while( my( $oid, $val ) = each %{$table} )
            {
                my $ifIndex = substr( $oid, $prefixLen );
                my $name = $index2name{$ifIndex};
                $result->{'ports'}{$name}{'ifType'} = $val;
            }
        }
    }

    {
        # IF-MIB::ifName
        my $base = '1.3.6.1.2.1.31.1.1.1.1';
        my $prefixLen = length( $base ) + 1;
        my $table = $session->get_table( -baseoid => $base );
        
        if( defined( $table ) )
        {
            while( my( $oid, $val ) = each %{$table} )
            {
                my $ifIndex = substr( $oid, $prefixLen );
                my $name = $index2name{$ifIndex};
                $result->{'ports'}{$name}{'shortname'} = $val;
            }
        }
    }
    
    {
        # IF-MIB::ifAlias
        my $base = '1.3.6.1.2.1.31.1.1.1.18';
        my $prefixLen = length( $base ) + 1;
        my $table = $session->get_table( -baseoid => $base );
        
        if( defined( $table ) )
        {
            while( my( $oid, $val ) = each %{$table} )
            {
                my $ifIndex = substr( $oid, $prefixLen );
                my $name = $index2name{$ifIndex};
                $result->{'ports'}{$name}{'comment'} = $val;
            }
        }
    }

    {
        # IF-MIB::ifAdminStatus
        my $base = '1.3.6.1.2.1.2.2.1.7';
        my $prefixLen = length( $base ) + 1;
        my $table = $session->get_table( -baseoid => $base );
        
        if( defined( $table ) )
        {
            while( my( $oid, $val ) = each %{$table} )
            {
                my $ifIndex = substr( $oid, $prefixLen );
                my $name = $index2name{$ifIndex};
                $result->{'ports'}{$name}{'admin-status'} = $ifStatusVal{$val};
                $result->{'ports'}{$name}{'admin-up'} = ($val == 1 ? 1:0);
            }
        }
    }

    {
        # IF-MIB::ifOperStatus
        my $base = '1.3.6.1.2.1.2.2.1.8';
        my $prefixLen = length( $base ) + 1;
        my $table = $session->get_table( -baseoid => $base );
        
        if( defined( $table ) )
        {
            while( my( $oid, $val ) = each %{$table} )
            {
                my $ifIndex = substr( $oid, $prefixLen );
                my $name = $index2name{$ifIndex};
                $result->{'ports'}{$name}{'oper-status'} = $ifStatusVal{$val};
                $result->{'ports'}{$name}{'oper-up'} = ($val == 1 ? 1:0);
            }
        }
    }

    # CDP enabled status
    {
        # CISCO-CDP-MIB::cdpInterfaceEnable
        my $base = '1.3.6.1.4.1.9.9.23.1.1.1.1.2';
        my $prefixLen = length( $base ) + 1;
        my $table = $session->get_table( -baseoid => $base );
        
        if( defined( $table ) )
        {
            while( my( $oid, $val ) = each %{$table} )
            {
                my $ifIndex = substr( $oid, $prefixLen );
                my $name = $index2name{$ifIndex};
                $result->{'ports'}{$name}{'cdp-enabled'} = $truthVal{$val};
                $result->{'ports'}{$name}{'cdp-neighbors'} = 0;
            }
        }
    }

    # CDP neigbors information
    my %cdpNeighbors;
    
    {
        # CISCO-CDP-MIB::cdpCacheAddressType
        my $base = '1.3.6.1.4.1.9.9.23.1.2.1.1.3';
        my $prefixLen = length( $base ) + 1;
        my $table = $session->get_table( -baseoid => $base );
        
        if( defined( $table ) )
        {
            while( my( $oid, $val ) = each %{$table} )
            {
                my $neighIdx = substr( $oid, $prefixLen );
                if( not defined($ciscoAddrType{$val}) )
                {
                    $Gerty::log->error
                        ('CISCO-CDP-MIB: unsupported cdpCacheAddressType ' .
                         'value: ' . $val . ' in ' . $ahandler->sysname); 
                }
                else
                {
                    $cdpNeighbors{$neighIdx}{'addrtype'} =
                        $ciscoAddrType{$val};
                }
            }
        }
    }

    if( %cdpNeighbors )
    {
        # CDP neighbor address
        {
            # CISCO-CDP-MIB::cdpCacheAddress
            my $base = '1.3.6.1.4.1.9.9.23.1.2.1.1.4';
            my $prefixLen = length( $base ) + 1;
            my $table = $session->get_table( -baseoid => $base );
            
            if( defined( $table ) )
            {
                while( my( $oid, $val ) = each %{$table} )
                {
                    my $neighIdx = substr( $oid, $prefixLen );
                    if( defined($cdpNeighbors{$neighIdx}{'addrtype'}) )
                    {
                        if( $cdpNeighbors{$neighIdx}{'addrtype'} eq 'ipv4' )
                        {
                            $cdpNeighbors{$neighIdx}{'address'} =
                                inet_ntoa($val);
                        }
                        else
                        {
                            $Gerty::log->error
                                ('IPv6 is not yet supported for CDP MIB');
                        }
                    }                
                }
            }
        }

        # CDP neighbor name
        {
            # CISCO-CDP-MIB::cdpCacheDeviceId
            my $base = '1.3.6.1.4.1.9.9.23.1.2.1.1.6';
            my $prefixLen = length( $base ) + 1;
            my $table = $session->get_table( -baseoid => $base );
            
            if( defined( $table ) )
            {
                while( my( $oid, $val ) = each %{$table} )
                {
                    my $neighIdx = substr( $oid, $prefixLen );
                    $cdpNeighbors{$neighIdx}{'name'} = $val;
                }
            }
        }

        # CDP neighbor port
        {
            # CISCO-CDP-MIB::cdpCacheDevicePort
            my $base = '1.3.6.1.4.1.9.9.23.1.2.1.1.7';
            my $prefixLen = length( $base ) + 1;
            my $table = $session->get_table( -baseoid => $base );
            
            if( defined( $table ) )
            {
                while( my( $oid, $val ) = each %{$table} )
                {
                    my $neighIdx = substr( $oid, $prefixLen );
                    $cdpNeighbors{$neighIdx}{'port'} = $val;
                }
            }
        }
        
        # CDP neighbor platform
        {
            # CISCO-CDP-MIB::cdpCachePlatform            
            my $base = '1.3.6.1.4.1.9.9.23.1.2.1.1.8';
            my $prefixLen = length( $base ) + 1;
            my $table = $session->get_table( -baseoid => $base );
            
            if( defined( $table ) )
            {
                while( my( $oid, $val ) = each %{$table} )
                {
                    my $neighIdx = substr( $oid, $prefixLen );
                    $cdpNeighbors{$neighIdx}{'platform'} = $val;
                }
            }
        }

        foreach my $neighIdx (keys %cdpNeighbors)
        {
            $neighIdx =~ /^(\d+)\./;
            my $ifIndex = $1;
            if( not defined($ifIndex) or not defined($index2name{$ifIndex}) )
            {
                next;
            }
            my $portName = $index2name{$ifIndex};            
            my $neighName = $cdpNeighbors{$neighIdx}{'name'};

            next unless defined($neighName);

            $result->{'ports'}{$portName}{'cdp-neighbors'}++;
            
            foreach my $prop ('address', 'port', 'platform')
            {
                $result->{'cdp-neighbors'}{
                    $portName . '##' . $neighName}{$prop} =
                        $cdpNeighbors{$neighIdx}{$prop};
            }
        }
    }
    
    my $udld_supported = 0;
    
    # UDLD global status
    {
        # CISCO-UDLDP-MIB::cudldpHelloInterval.0
        my $oidHelloIntvl = '1.3.6.1.4.1.9.9.118.1.1.2.0';
        # CISCO-UDLDP-MIB::cudldpGlobalMode.0
        my $oidGlobalMode = '1.3.6.1.4.1.9.9.118.1.1.3.0';

        my $r = $session->get_request
            (-varbindlist => [$oidHelloIntvl, $oidGlobalMode ]);
        if( defined($r) )
        {
            if( $r->{$oidHelloIntvl} )
            {
                $result->{'system'}{'udld'}{'hello-interval'} =
                    $r->{$oidHelloIntvl};
            }

            if( $r->{$oidGlobalMode} )
            {
                $result->{'system'}{'udld'}{'global-mode'} =
                    $udldMode{$r->{$oidGlobalMode}};
                $result->{'system'}{'udld'}{'global-aggressive-enabled'} =
                    ($r->{$oidGlobalMode} == 3 ? 1:0);
                $udld_supported = 1;
            }
        }
    }
    

    # UDLD port status

    if( $udld_supported )
    {
        {
            # CISCO-UDLDP-MIB::cudldpInterfaceOperStatus
            my $base = '1.3.6.1.4.1.9.9.118.1.2.1.1.2';
            my $prefixLen = length( $base ) + 1;
            my $table = $session->get_table( -baseoid => $base );
            
            if( defined( $table ) )
            {
                while( my( $oid, $val ) = each %{$table} )
                {
                    my $ifIndex = substr( $oid, $prefixLen );
                    my $name = $index2name{$ifIndex};                
                    $result->{'ports'}{$name}{'udld-oper-status'} =
                        $udldOperStatus{$val};
                    $result->{'ports'}{$name}{'udld-shutdown'} =
                        ($val == 1 ? 1:0);
                }
            }            
        }
        
        {
            # CISCO-UDLDP-MIB::cudldpInterfaceAdminMode
            my $base = '1.3.6.1.4.1.9.9.118.1.2.1.1.4';
            my $prefixLen = length( $base ) + 1;
            my $table = $session->get_table( -baseoid => $base );
            
            if( defined( $table ) )
            {
                while( my( $oid, $val ) = each %{$table} )
                {
                    my $ifIndex = substr( $oid, $prefixLen );
                    my $name = $index2name{$ifIndex};                
                    $result->{'ports'}{$name}{'udld-admin-mode'} =
                        $udldMode{$val};
                }
            }
        }
        
        {
            # CISCO-UDLDP-MIB::cudldpInterfaceOperMode
            my $base = '1.3.6.1.4.1.9.9.118.1.2.1.1.5';
            my $prefixLen = length( $base ) + 1;
            my $table = $session->get_table( -baseoid => $base );
            
            if( defined( $table ) )
            {
                while( my( $oid, $val ) = each %{$table} )
                {
                    my $ifIndex = substr( $oid, $prefixLen );
                    my $name = $index2name{$ifIndex};                
                    $result->{'ports'}{$name}{'udld-oper-mode'} =
                        $udldMode{$val};
                    $result->{'ports'}{$name}{'udld-aggressive-enabled'} =
                        ($val == 3 ? 1:0);
                }
            }
        }
    }    

    # Exclude virtual and other noninteresting ports
    foreach my $name (keys %{$result->{'ports'}})
    {
        if( not $ifTypeInterested{$result->{'ports'}{$name}{'ifType'}}
            or
            $name =~ /^vlan/io )
        {
            delete $result->{'ports'}{$name};
        }
    }

    # Do not keep the oper. status in the property history
    $result->{'ports'}{'.nohistory'}{'oper-status'} = 1;
    $result->{'ports'}{'.nohistory'}{'oper-up'} = 1;
    $result->{'ports'}{'.nohistory'}{'udld-oper-status'} = 1;
    $result->{'ports'}{'.nohistory'}{'udld-shutdown'} = 1;
    $result->{'ports'}{'.nohistory'}{'cdp-neighbors'} = 1;
    
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
