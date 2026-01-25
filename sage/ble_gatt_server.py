#!/usr/bin/env python3
"""
SAGE Glass BLE GATT Server
Handles BLE pairing and WiFi credential exchange with the mobile app
"""

import json
import logging
import subprocess
import sys
import time
import dbus
import dbus.service
import dbus.mainloop.glib
from gi.repository import GLib

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('SAGE-BLE')

# BLE Configuration
SERVICE_UUID = '12345678-1234-5678-1234-56789abcdef0'
CREDENTIALS_CHAR_UUID = '12345678-1234-5678-1234-56789abcdef1'
STATUS_CHAR_UUID = '12345678-1234-5678-1234-56789abcdef2'
SCAN_CHAR_UUID = '12345678-1234-5678-1234-56789abcdef3'  # WiFi scan
NETWORK_DETAILS_CHAR_UUID = '12345678-1234-5678-1234-56789abcdef4'  # Network details
BLUETOOTH_DETAILS_CHAR_UUID = '12345678-1234-5678-1234-56789abcdef5'  # BT details
DEVICE_INFO_CHAR_UUID = '12345678-1234-5678-1234-56789abcdef6'  # Device info
DEVICE_NAME = 'SAGE Glass X1'

# DBus Paths
BLUEZ_SERVICE = 'org.bluez'
GATT_MANAGER_IFACE = 'org.bluez.GattManager1'
DBUS_OM_IFACE = 'org.freedesktop.DBus.ObjectManager'
DBUS_PROP_IFACE = 'org.freedesktop.DBus.Properties'
GATT_SERVICE_IFACE = 'org.bluez.GattService1'
GATT_CHRC_IFACE = 'org.bluez.GattCharacteristic1'
GATT_DESC_IFACE = 'org.bluez.GattDescriptor1'
LE_ADVERTISING_MANAGER_IFACE = 'org.bluez.LEAdvertisingManager1'
LE_ADVERTISEMENT_IFACE = 'org.bluez.LEAdvertisement1'

class InvalidArgsException(dbus.exceptions.DBusException):
    _dbus_error_name = 'org.freedesktop.DBus.Error.InvalidArgs'

class NotSupportedException(dbus.exceptions.DBusException):
    _dbus_error_name = 'org.bluez.Error.NotSupported'

class NotPermittedException(dbus.exceptions.DBusException):
    _dbus_error_name = 'org.bluez.Error.NotPermitted'

class InvalidValueLengthException(dbus.exceptions.DBusException):
    _dbus_error_name = 'org.bluez.Error.InvalidValueLength'

class FailedException(dbus.exceptions.DBusException):
    _dbus_error_name = 'org.bluez.Error.Failed'


class Application(dbus.service.Object):
    """DBus Application for GATT services"""
    
    def __init__(self, bus):
        self.path = '/'
        self.services = []
        dbus.service.Object.__init__(self, bus, self.path)

    def get_path(self):
        return dbus.ObjectPath(self.path)

    def add_service(self, service):
        self.services.append(service)

    @dbus.service.method(DBUS_OM_IFACE, out_signature='a{oa{sa{sv}}}')
    def GetManagedObjects(self):
        response = {}
        for service in self.services:
            response[service.get_path()] = service.get_properties()
            chrcs = service.get_characteristics()
            for chrc in chrcs:
                response[chrc.get_path()] = chrc.get_properties()
                descs = chrc.get_descriptors()
                for desc in descs:
                    response[desc.get_path()] = desc.get_properties()
        return response


class Service(dbus.service.Object):
    """GATT Service"""
    
    PATH_BASE = '/org/bluez/sage/service'

    def __init__(self, bus, index, uuid, primary):
        self.path = self.PATH_BASE + str(index)
        self.bus = bus
        self.uuid = uuid
        self.primary = primary
        self.characteristics = []
        dbus.service.Object.__init__(self, bus, self.path)

    def get_properties(self):
        return {
            GATT_SERVICE_IFACE: {
                'UUID': self.uuid,
                'Primary': self.primary,
                'Characteristics': dbus.Array(
                    self.get_characteristic_paths(),
                    signature='o')
            }
        }

    def get_path(self):
        return dbus.ObjectPath(self.path)

    def add_characteristic(self, characteristic):
        self.characteristics.append(characteristic)

    def get_characteristic_paths(self):
        result = []
        for chrc in self.characteristics:
            result.append(chrc.get_path())
        return result

    def get_characteristics(self):
        return self.characteristics

    @dbus.service.method(DBUS_PROP_IFACE, in_signature='s', out_signature='a{sv}')
    def GetAll(self, interface):
        if interface != GATT_SERVICE_IFACE:
            raise InvalidArgsException()
        return self.get_properties()[GATT_SERVICE_IFACE]


class Characteristic(dbus.service.Object):
    """GATT Characteristic"""
    
    def __init__(self, bus, index, uuid, flags, service):
        self.path = service.path + '/char' + str(index)
        self.bus = bus
        self.uuid = uuid
        self.service = service
        self.flags = flags
        self.descriptors = []
        dbus.service.Object.__init__(self, bus, self.path)

    def get_properties(self):
        return {
            GATT_CHRC_IFACE: {
                'Service': self.service.get_path(),
                'UUID': self.uuid,
                'Flags': self.flags,
                'Descriptors': dbus.Array(
                    self.get_descriptor_paths(),
                    signature='o')
            }
        }

    def get_path(self):
        return dbus.ObjectPath(self.path)

    def add_descriptor(self, descriptor):
        self.descriptors.append(descriptor)

    def get_descriptor_paths(self):
        result = []
        for desc in self.descriptors:
            result.append(desc.get_path())
        return result

    def get_descriptors(self):
        return self.descriptors

    @dbus.service.method(DBUS_PROP_IFACE, in_signature='s', out_signature='a{sv}')
    def GetAll(self, interface):
        if interface != GATT_CHRC_IFACE:
            raise InvalidArgsException()
        return self.get_properties()[GATT_CHRC_IFACE]

    @dbus.service.method(GATT_CHRC_IFACE, in_signature='a{sv}', out_signature='ay')
    def ReadValue(self, options):
        logger.warning('Default ReadValue called, returning error')
        raise NotSupportedException()

    @dbus.service.method(GATT_CHRC_IFACE, in_signature='aya{sv}')
    def WriteValue(self, value, options):
        logger.warning('Default WriteValue called, returning error')
        raise NotSupportedException()

    @dbus.service.method(GATT_CHRC_IFACE)
    def StartNotify(self):
        logger.warning('Default StartNotify called, returning error')
        raise NotSupportedException()

    @dbus.service.method(GATT_CHRC_IFACE)
    def StopNotify(self):
        logger.warning('Default StopNotify called, returning error')
        raise NotSupportedException()

    @dbus.service.signal(DBUS_PROP_IFACE, signature='sa{sv}as')
    def PropertiesChanged(self, interface, changed, invalidated):
        pass


class CredentialsCharacteristic(Characteristic):
    """Characteristic for receiving WiFi credentials from mobile app"""
    
    def __init__(self, bus, index, service, wifi_manager):
        Characteristic.__init__(
            self, bus, index,
            CREDENTIALS_CHAR_UUID,
            ['write', 'write-without-response'],
            service)
        self.wifi_manager = wifi_manager

    def WriteValue(self, value, options):
        """Called when mobile app writes WiFi credentials"""
        try:
            # Convert DBus bytes to string
            data_bytes = bytes(value)
            data_str = data_bytes.decode('utf-8')
            
            logger.info(f'!!! WriteValue CALLED - Received credentials data: {len(data_str)} bytes')
            
            # Parse JSON
            credentials = json.loads(data_str)
            ssid = credentials.get('ssid')
            password = credentials.get('password')
            
            if not ssid or not password:
                logger.error('Missing SSID or password in credentials')
                raise InvalidArgsException('Missing SSID or password')
            
            logger.info(f'!!! Parsed credentials - SSID: {ssid}, is_connecting: {self.wifi_manager.is_connecting}')
            
            # Check if already connecting - don't queue another request
            if self.wifi_manager.is_connecting:
                logger.warning(f'!!! BLOCKED - Already connecting, ignoring new credentials for {ssid}')
                return
            
            # Also check if already connected to this network
            current_network = self.wifi_manager.get_current_network()
            if current_network == ssid:
                logger.warning(f'!!! BLOCKED - Already connected to {ssid}, ignoring duplicate request')
                return
            
            logger.info(f'!!! QUEUING connection to {ssid} via GLib.idle_add')
            # Connect to WiFi (async)
            GLib.idle_add(self.wifi_manager.connect_to_wifi, ssid, password)
            
        except json.JSONDecodeError as e:
            logger.error(f'Invalid JSON: {e}')
            raise InvalidArgsException(f'Invalid JSON: {e}')
        except Exception as e:
            logger.error(f'Error processing credentials: {e}')
            raise FailedException(str(e))


class StatusCharacteristic(Characteristic):
    """Characteristic for reporting connection status to mobile app"""
    
    def __init__(self, bus, index, service, wifi_manager):
        Characteristic.__init__(
            self, bus, index,
            STATUS_CHAR_UUID,
            ['read', 'notify'],
            service)
        self.wifi_manager = wifi_manager
        self.notifying = False

    def ReadValue(self, options):
        """Return current WiFi connection status and network info"""
        status = self.wifi_manager.get_status()
        current_network = self.wifi_manager.get_current_network()
        
        status_data = {
            'status': status,
            'network': current_network,
            'ssid': self.wifi_manager.ssid
        }
        
        status_json = json.dumps(status_data)
        return dbus.Array([dbus.Byte(c) for c in status_json.encode()])

    def StartNotify(self):
        """Enable notifications"""
        if self.notifying:
            return
        self.notifying = True
        logger.info('Status notifications enabled')

    def StopNotify(self):
        """Disable notifications"""
        if not self.notifying:
            return
        self.notifying = False
        logger.info('Status notifications disabled')

    def send_status_update(self, status):
        """Send status update notification"""
        if not self.notifying:
            return
        
        current_network = self.wifi_manager.get_current_network()
        status_data = {
            'status': status,
            'network': current_network,
            'ssid': self.wifi_manager.ssid
        }
        
        status_json = json.dumps(status_data)
        value = dbus.Array([dbus.Byte(c) for c in status_json.encode()])
        self.PropertiesChanged(GATT_CHRC_IFACE, {'Value': value}, [])
        logger.info(f'Sent status notification: {status}')


class WiFiScanCharacteristic(Characteristic):
    """Characteristic for scanning available WiFi networks"""
    
    def __init__(self, bus, index, service, wifi_manager):
        Characteristic.__init__(
            self, bus, index,
            SCAN_CHAR_UUID,
            ['read'],
            service)
        self.wifi_manager = wifi_manager

    def ReadValue(self, options):
        """Scan and return list of available WiFi networks"""
        logger.info('WiFi scan requested')
        networks = self.wifi_manager.scan_networks()
        
        # Return as JSON array
        networks_json = json.dumps(networks)
        logger.info(f'Returning {len(networks)} networks')
        return dbus.Array([dbus.Byte(c) for c in networks_json.encode()])


class NetworkDetailsCharacteristic(Characteristic):
    """Characteristic for detailed network information"""
    
    def __init__(self, bus, index, service, wifi_manager):
        Characteristic.__init__(
            self, bus, index,
            NETWORK_DETAILS_CHAR_UUID,
            ['read'],
            service)
        self.wifi_manager = wifi_manager

    def ReadValue(self, options):
        """Return detailed network information"""
        try:
            current_network = self.wifi_manager.get_current_network()
            
            if not current_network:
                return dbus.Array([dbus.Byte(c) for c in json.dumps({
                    'rssi': None,
                    'frequency': None,
                    'protocol': None,
                    'ip_address': None,
                    'link_speed': None,
                    'channel': None,
                    'noise': None
                }).encode()])
            
            # Get detailed WiFi info using iw and ip commands
            details = {}
            
            # Get RSSI (signal strength)
            try:
                result = subprocess.run(['iw', 'dev', 'wlan0', 'link'], 
                                      capture_output=True, text=True, timeout=2)
                if result.returncode == 0:
                    for line in result.stdout.split('\n'):
                        if 'signal:' in line:
                            # Extract RSSI value
                            rssi = line.split('signal:')[1].strip().split()[0]
                            details['rssi'] = rssi
                        elif 'freq:' in line:
                            freq = line.split('freq:')[1].strip().split()[0]
                            freq_int = int(freq)
                            details['frequency'] = '5 GHz' if freq_int > 5000 else '2.4 GHz'
            except:
                pass
            
            # Get IP address
            try:
                result = subprocess.run(['ip', '-4', 'addr', 'show', 'wlan0'], 
                                      capture_output=True, text=True, timeout=2)
                if result.returncode == 0:
                    for line in result.stdout.split('\n'):
                        if 'inet ' in line:
                            ip = line.strip().split()[1].split('/')[0]
                            details['ip_address'] = ip
                            break
            except:
                pass
            
            # Get link speed and other info from iwconfig
            try:
                result = subprocess.run(['iwconfig', 'wlan0'], 
                                      capture_output=True, text=True, timeout=2)
                if result.returncode == 0:
                    for line in result.stdout.split('\n'):
                        if 'Bit Rate' in line:
                            try:
                                speed = line.split('Bit Rate=')[1].split()[0]
                                details['link_speed'] = speed
                            except:
                                pass
            except:
                pass
            
            # Get network info from nmcli
            try:
                result = subprocess.run(['nmcli', '-t', '-f', 'CHAN,SECURITY', 'dev', 'wifi', 'list', 'ifname', 'wlan0'], 
                                      capture_output=True, text=True, timeout=2)
                if result.returncode == 0:
                    lines = result.stdout.strip().split('\n')
                    if lines:
                        parts = lines[0].split(':')
                        if len(parts) >= 2:
                            details['channel'] = parts[0]
                            details['protocol'] = parts[1] if parts[1] else 'Open'
            except:
                pass
            
            # Set defaults
            if 'rssi' not in details:
                details['rssi'] = '-50'
            if 'frequency' not in details:
                details['frequency'] = '2.4 GHz'
            if 'protocol' not in details:
                details['protocol'] = 'WPA2-PSK'
            if 'ip_address' not in details:
                details['ip_address'] = 'Unknown'
            if 'link_speed' not in details:
                details['link_speed'] = '65'
            if 'channel' not in details:
                details['channel'] = '6'
            if 'noise' not in details:
                details['noise'] = '-90'
            
            return dbus.Array([dbus.Byte(c) for c in json.dumps(details).encode()])
            
        except Exception as e:
            logger.error(f'Error getting network details: {e}')
            return dbus.Array([dbus.Byte(c) for c in json.dumps({}).encode()])


class BluetoothDetailsCharacteristic(Characteristic):
    """Characteristic for Bluetooth connection details"""
    
    def __init__(self, bus, index, service):
        Characteristic.__init__(
            self, bus, index,
            BLUETOOTH_DETAILS_CHAR_UUID,
            ['read'],
            service)

    def ReadValue(self, options):
        """Return Bluetooth connection details"""
        try:
            # Get connected devices via bluetoothctl
            details = {
                'glass_device': DEVICE_NAME,
                'mobile_device': 'Unknown',
                'rssi': '-45',
                'ble_version': '5.0',
                'connected': True
            }
            
            # Try to get connected device info
            try:
                result = subprocess.run(['bluetoothctl', 'devices', 'Connected'], 
                                      capture_output=True, text=True, timeout=2)
                if result.returncode == 0 and result.stdout.strip():
                    # Parse first connected device
                    for line in result.stdout.split('\n'):
                        if 'Device' in line:
                            parts = line.split()
                            if len(parts) >= 3:
                                details['mobile_device'] = ' '.join(parts[2:])
                                break
            except:
                pass
            
            return dbus.Array([dbus.Byte(c) for c in json.dumps(details).encode()])
            
        except Exception as e:
            logger.error(f'Error getting Bluetooth details: {e}')
            return dbus.Array([dbus.Byte(c) for c in json.dumps({}).encode()])


class DeviceInfoCharacteristic(Characteristic):
    """Characteristic for device information"""
    
    def __init__(self, bus, index, service):
        Characteristic.__init__(
            self, bus, index,
            DEVICE_INFO_CHAR_UUID,
            ['read'],
            service)

    def ReadValue(self, options):
        """Return device information"""
        try:
            import datetime
            import os
            
            details = {
                'paired_timestamp': None,
                'firmware_version': 'v1.0.0',
                'device_type': 'Smart Glasses'
            }
            
            # Try to read pairing timestamp from file
            try:
                pairing_file = '/home/sage/.sage_paired'
                if os.path.exists(pairing_file):
                    with open(pairing_file, 'r') as f:
                        timestamp_str = f.read().strip()
                        details['paired_timestamp'] = timestamp_str
            except:
                # If no file, use current time
                details['paired_timestamp'] = datetime.datetime.now().isoformat()
            
            return dbus.Array([dbus.Byte(c) for c in json.dumps(details).encode()])
            
        except Exception as e:
            logger.error(f'Error getting device info: {e}')
            return dbus.Array([dbus.Byte(c) for c in json.dumps({}).encode()])


class SAGEGattService(Service):
    """Main SAGE GATT Service"""
    
    def __init__(self, bus, index, wifi_manager):
        Service.__init__(self, bus, index, SERVICE_UUID, True)
        
        # Add characteristics
        self.add_characteristic(CredentialsCharacteristic(bus, 0, self, wifi_manager))
        self.status_char = StatusCharacteristic(bus, 1, self, wifi_manager)
        self.add_characteristic(self.status_char)
        self.add_characteristic(WiFiScanCharacteristic(bus, 2, self, wifi_manager))
        self.add_characteristic(NetworkDetailsCharacteristic(bus, 3, self, wifi_manager))
        self.add_characteristic(BluetoothDetailsCharacteristic(bus, 4, self))
        self.add_characteristic(DeviceInfoCharacteristic(bus, 5, self))
        
        # Set wifi manager callback
        wifi_manager.set_status_callback(self.status_char.send_status_update)


class Advertisement(dbus.service.Object):
    """BLE Advertisement"""
    
    PATH_BASE = '/org/bluez/sage/advertisement'

    def __init__(self, bus, index, advertising_type):
        self.path = self.PATH_BASE + str(index)
        self.bus = bus
        self.ad_type = advertising_type
        self.service_uuids = None
        self.manufacturer_data = None
        self.solicit_uuids = None
        self.service_data = None
        self.local_name = DEVICE_NAME
        self.include_tx_power = False
        dbus.service.Object.__init__(self, bus, self.path)

    def get_properties(self):
        properties = dict()
        properties['Type'] = self.ad_type
        if self.service_uuids is not None:
            properties['ServiceUUIDs'] = dbus.Array(self.service_uuids, signature='s')
        if self.solicit_uuids is not None:
            properties['SolicitUUIDs'] = dbus.Array(self.solicit_uuids, signature='s')
        if self.manufacturer_data is not None:
            properties['ManufacturerData'] = dbus.Dictionary(self.manufacturer_data, signature='qv')
        if self.service_data is not None:
            properties['ServiceData'] = dbus.Dictionary(self.service_data, signature='sv')
        if self.local_name is not None:
            properties['LocalName'] = dbus.String(self.local_name)
        if self.include_tx_power:
            properties['IncludeTxPower'] = dbus.Boolean(self.include_tx_power)
        return {LE_ADVERTISEMENT_IFACE: properties}

    def get_path(self):
        return dbus.ObjectPath(self.path)

    def add_service_uuid(self, uuid):
        if not self.service_uuids:
            self.service_uuids = []
        self.service_uuids.append(uuid)

    @dbus.service.method(DBUS_PROP_IFACE, in_signature='s', out_signature='a{sv}')
    def GetAll(self, interface):
        if interface != LE_ADVERTISEMENT_IFACE:
            raise InvalidArgsException()
        return self.get_properties()[LE_ADVERTISEMENT_IFACE]

    @dbus.service.method(LE_ADVERTISEMENT_IFACE, in_signature='', out_signature='')
    def Release(self):
        logger.info('Advertisement released')


class WiFiManager:
    """Manages WiFi connection"""
    
    def __init__(self):
        self.status = 'waiting'
        self.status_callback = None
        self.ssid = None
        self.password = None
        self.is_connecting = False  # Lock to prevent concurrent connections
        self.last_attempt_ssid = None  # Track last connection attempt
        self.last_attempt_time = 0  # Track last connection attempt time
        self.cooldown_seconds = 45  # Cooldown period between connection attempts

    def set_status_callback(self, callback):
        """Set callback for status updates"""
        self.status_callback = callback

    def get_status(self):
        """Get current status"""
        return self.status
    
    def scan_networks(self):
        """Scan for available WiFi networks"""
        try:
            logger.info('Scanning for WiFi networks...')
            
            # Use nmcli to scan for networks
            # First, rescan
            subprocess.run(['sudo', 'nmcli', 'device', 'wifi', 'rescan'], 
                          capture_output=True, timeout=5)
            
            # Wait a bit for scan to complete
            time.sleep(1)
            
            # Get list of networks
            result = subprocess.run(
                ['nmcli', '-t', '-f', 'SSID,SIGNAL,SECURITY', 'device', 'wifi', 'list'],
                capture_output=True, text=True, timeout=5
            )
            
            if result.returncode != 0:
                logger.error('Failed to scan networks')
                return []
            
            networks = []
            seen_ssids = set()
            
            for line in result.stdout.strip().split('\n'):
                if not line:
                    continue
                
                parts = line.split(':')
                if len(parts) >= 3:
                    ssid = parts[0].strip()
                    signal = parts[1].strip()
                    security = parts[2].strip()
                    
                    # Skip empty SSIDs and duplicates
                    if not ssid or ssid in seen_ssids:
                        continue
                    
                    seen_ssids.add(ssid)
                    
                    # Parse signal strength
                    try:
                        signal_int = int(signal) if signal else 0
                    except:
                        signal_int = 0
                    
                    # Determine if secured
                    is_secured = bool(security and security != '--')
                    
                    networks.append({
                        'ssid': ssid,
                        'signal': signal_int,
                        'secured': is_secured
                    })
            
            # Sort by signal strength (strongest first)
            networks.sort(key=lambda x: x['signal'], reverse=True)
            
            logger.info(f'Found {len(networks)} networks')
            return networks
            
        except Exception as e:
            logger.error(f'Error scanning networks: {e}')
            return []
    
    def get_current_network(self):
        """Get currently connected WiFi network SSID"""
        try:
            # Try iwgetid first (most reliable)
            result = subprocess.run(['iwgetid', '-r'], capture_output=True, text=True, timeout=5)
            if result.returncode == 0 and result.stdout.strip():
                return result.stdout.strip()
            
            # Fallback to nmcli
            result = subprocess.run(['nmcli', '-t', '-f', 'active,ssid', 'dev', 'wifi'], 
                                  capture_output=True, text=True, timeout=5)
            for line in result.stdout.split('\n'):
                if line.startswith('yes:'):
                    return line.split(':', 1)[1]
            
            return None
        except Exception as e:
            logger.warning(f'Could not get current network: {e}')
            return None

    def update_status(self, new_status):
        """Update status and notify"""
        self.status = new_status
        logger.info(f'WiFi status: {new_status}')
        if self.status_callback:
            self.status_callback(new_status)

    def connect_to_wifi(self, ssid, password):
        """Connect to WiFi hotspot using bash script for reliable switching"""
        
        # Check cooldown period - prevent rapid successive attempts
        import time
        current_time = time.time()
        time_since_last = current_time - self.last_attempt_time
        
        if self.last_attempt_time > 0 and time_since_last < self.cooldown_seconds:
            remaining = int(self.cooldown_seconds - time_since_last)
            logger.warning(f'COOLDOWN: Must wait {remaining} more seconds before next connection attempt')
            return False
        
        # Prevent concurrent connection attempts
        if self.is_connecting:
            logger.warning(f'Connection already in progress, ignoring duplicate request')
            return False
        
        # Check if this is a duplicate request for the same network we just connected to
        current_network = self.get_current_network()
        
        if current_network == ssid and self.status == 'connected' and self.last_attempt_ssid == ssid:
            # Already connected, no need to log - just return success silently
            return True
        
        # New connection attempt
        logger.info(f'=== Connecting to WiFi: {ssid} ===')
        self.last_attempt_ssid = ssid
        self.last_attempt_time = current_time  # Record attempt time
        
        self.is_connecting = True
        self.ssid = ssid
        self.password = password
        
        self.update_status('connecting')
        
        try:
            # Use the bash script for reliable network switching
            script_path = '/home/sage/sage/scripts/switch_wifi.sh'
            
            logger.info(f'Executing WiFi switch script: {script_path}')
            
            # Run the script with sudo
            result = subprocess.run(
                ['sudo', script_path, ssid, password],
                capture_output=True,
                text=True,
                timeout=30
            )
            
            # Log the output
            if result.stdout:
                for line in result.stdout.split('\n'):
                    if line.strip():
                        logger.info(f'Script: {line}')
            
            if result.stderr:
                for line in result.stderr.split('\n'):
                    if line.strip():
                        logger.warning(f'Script stderr: {line}')
            
            # Check result - but ALSO verify actual connection regardless of exit code
            # (script might exit 1 due to timing but still be connected)
            time.sleep(2)  # Give a moment for network to stabilize
            actual_network = self.get_current_network()
            
            if actual_network == ssid:
                logger.info(f'Successfully connected to WiFi: {ssid} (verified)')
                self.update_status('connected')
                self.is_connecting = False
                return True
            elif result.returncode == 0:
                # Script says success but we're not on the right network
                logger.warning(f'Script succeeded but connected to: {actual_network} instead of {ssid}')
                self.update_status('failed')
                self.is_connecting = False
                return False
            else:
                logger.error(f'WiFi connection failed - exit code: {result.returncode}, current: {actual_network}')
                self.update_status('failed')
                self.is_connecting = False
                return False
                
        except subprocess.TimeoutExpired:
            logger.error('WiFi connection timeout (30 seconds)')
            self.update_status('timeout')
            self.is_connecting = False
            return False
        except Exception as e:
            logger.error(f'WiFi connection error: {e}')
            self.update_status('failed')
            self.is_connecting = False
            return False


def find_adapter(bus):
    """Find Bluetooth adapter"""
    remote_om = dbus.Interface(bus.get_object(BLUEZ_SERVICE, '/'), DBUS_OM_IFACE)
    objects = remote_om.GetManagedObjects()
    
    for o, props in objects.items():
        if GATT_MANAGER_IFACE in props.keys():
            return o
    
    return None


def main():
    """Main function"""
    logger.info('Starting SAGE BLE GATT Server')
    logger.info(f'Device Name: {DEVICE_NAME}')
    logger.info(f'Service UUID: {SERVICE_UUID}')
    
    # Initialize DBus
    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    bus = dbus.SystemBus()
    
    # Find adapter
    adapter_path = find_adapter(bus)
    if not adapter_path:
        logger.error('Bluetooth adapter not found')
        return
    
    logger.info(f'Bluetooth adapter: {adapter_path}')
    
    # Create WiFi manager
    wifi_manager = WiFiManager()
    
    # Create application
    app = Application(bus)
    
    # Create service
    service = SAGEGattService(bus, 0, wifi_manager)
    app.add_service(service)
    
    # Register application
    manager = dbus.Interface(bus.get_object(BLUEZ_SERVICE, adapter_path), GATT_MANAGER_IFACE)
    manager.RegisterApplication(app.get_path(), {}, reply_handler=lambda: logger.info('GATT application registered'),
                                error_handler=lambda e: logger.error(f'Failed to register application: {e}'))
    
    # Create advertisement
    ad = Advertisement(bus, 0, 'peripheral')
    ad.add_service_uuid(SERVICE_UUID)
    
    # Register advertisement
    ad_manager = dbus.Interface(bus.get_object(BLUEZ_SERVICE, adapter_path), LE_ADVERTISING_MANAGER_IFACE)
    ad_manager.RegisterAdvertisement(ad.get_path(), {}, reply_handler=lambda: logger.info('Advertisement registered'),
                                     error_handler=lambda e: logger.error(f'Failed to register advertisement: {e}'))
    
    logger.info('SAGE BLE GATT Server ready')
    logger.info('Waiting for connections...')
    
    # Run main loop
    try:
        mainloop = GLib.MainLoop()
        mainloop.run()
    except KeyboardInterrupt:
        logger.info('Shutting down...')


if __name__ == '__main__':
    main()
