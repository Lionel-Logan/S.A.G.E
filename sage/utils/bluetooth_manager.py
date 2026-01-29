#!/usr/bin/env python3
"""
Bluetooth Manager for SAGE Pi
Handles Bluetooth audio device scanning, pairing, and audio routing
"""

import asyncio
import logging
import subprocess
import re
from typing import AsyncGenerator, Dict, Optional, List
from datetime import datetime, timedelta

logger = logging.getLogger(__name__)


class BluetoothManager:
    """Manages Bluetooth audio device operations"""
    
    def __init__(self):
        self.scanning = False
        self.scan_process = None
        self.output_buffer = []  # Shared buffer for bluetoothctl output lines
        self.buffer_lock = asyncio.Lock()  # Thread-safe buffer access
        self.max_buffer_size = 500  # Keep last 500 lines to prevent memory issues
        
    async def scan_devices(self) -> AsyncGenerator[Dict, None]:
        """
        Scan for Bluetooth devices and stream results in real-time
        Scan will continue until stop_scan() is called
            
        Yields:
            Dict with device information: {name, mac, rssi, device_class, is_audio, timestamp}
        """
        if self.scanning:
            logger.warning("Scan already in progress")
            return
            
        self.scanning = True
        discovered_macs = set()
        
        try:
            logger.info("Starting continuous Bluetooth scan")
            
            # Start bluetoothctl interactively
            process = await asyncio.create_subprocess_exec(
                'bluetoothctl',
                stdin=asyncio.subprocess.PIPE,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            
            self.scan_process = process
            
            # Send scan on command
            process.stdin.write(b'scan on\n')
            await process.stdin.drain()
            
            logger.info("Scan started, monitoring for devices...")
            
            # ANSI escape code pattern
            ansi_escape = re.compile(r'\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])')
            
            # Read output line by line
            while self.scanning:
                try:
                    line_bytes = await asyncio.wait_for(process.stdout.readline(), timeout=1.0)
                    
                    if not line_bytes:
                        break
                    
                    line = line_bytes.decode('utf-8', errors='ignore').strip()
                    if line:
                        logger.debug(f"Scan: {line}")
                    
                    # Strip ANSI codes
                    line = ansi_escape.sub('', line)
                    
                    # Add line to shared buffer for pair_device() to read
                    async with self.buffer_lock:
                        self.output_buffer.append({
                            'line': line,
                            'timestamp': datetime.utcnow()
                        })
                        # Keep buffer size limited
                        if len(self.output_buffer) > self.max_buffer_size:
                            self.output_buffer.pop(0)
                    
                    # Look for device lines
                    if ('[NEW] Device' in line or '[CHG] Device' in line) and ':' in line:
                        logger.info(f"Found device: {line}")
                        
                        # Extract MAC address
                        mac_match = re.search(r'([0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2})', line, re.IGNORECASE)
                        if mac_match:
                            mac = mac_match.group(1)
                            
                            if mac not in discovered_macs:
                                discovered_macs.add(mac)
                                
                                # Get device info
                                device_info = await self._get_device_info(mac)
                                
                                if device_info and device_info.get('is_audio', False):
                                    logger.info(f"Audio device: {device_info['name']} ({mac})")
                                    yield device_info
                
                except asyncio.TimeoutError:
                    continue
                except Exception as e:
                    logger.error(f"Error reading output: {e}")
                    break
            
            logger.info(f"Scan stopped. Found {len(discovered_macs)} devices")
                
        except Exception as e:
            logger.error(f"Scan error: {e}")
            raise
        finally:
            self.scanning = False
            if self.scan_process:
                try:
                    self.scan_process.stdin.write(b'scan off\n')
                    await self.scan_process.stdin.drain()
                    await asyncio.sleep(0.5)
                    self.scan_process.terminate()
                    await asyncio.wait_for(self.scan_process.wait(), timeout=2)
                except:
                    self.scan_process.kill()
                self.scan_process = None
    
    async def stop_scan(self):
        """Stop the current Bluetooth scan"""
        if not self.scanning:
            logger.warning("No scan in progress")
            return False
        
        try:
            logger.info("Stopping scan")
            self.scanning = False  # This will break the loop in scan_devices
            await asyncio.sleep(1)  # Wait for scan loop to exit
            return True
            
        except Exception as e:
            logger.error(f"Error stopping scan: {e}")
            return False
            
    async def _get_device_info(self, mac: str) -> Optional[Dict]:
        """Get detailed device information"""
        try:
            # Run bluetoothctl info command
            process = await asyncio.create_subprocess_exec(
                'bluetoothctl', 'info', mac,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            
            stdout, _ = await asyncio.wait_for(process.communicate(), timeout=2.0)
            info_text = stdout.decode('utf-8')
            
            # Parse device info
            name = 'Unknown Device'
            rssi = None
            device_class = None
            is_audio = False
            
            for line in info_text.split('\n'):
                line = line.strip()
                
                if line.startswith('Name:'):
                    name = line.split('Name:', 1)[1].strip()
                elif line.startswith('RSSI:'):
                    rssi_str = line.split('RSSI:', 1)[1].strip()
                    try:
                        rssi = int(rssi_str)
                    except:
                        pass
                elif line.startswith('Class:'):
                    device_class = line.split('Class:', 1)[1].strip()
                    # Check if audio device (0x24xxxx = Audio/Video)
                    if device_class and '0x24' in device_class:
                        is_audio = True
                elif 'UUID: Audio' in line or 'UUID: A2DP' in line or 'UUID: Headset' in line or 'UUID: AVRemoteControl' in line:
                    is_audio = True
            
            # If name suggests it's an audio device (headphones, speaker, etc.), mark as audio
            audio_keywords = ['headphone', 'headset', 'speaker', 'buds', 'earphone', 'audio', 'jbl', 'bose', 'sony', 'beats']
            if not is_audio and any(keyword in name.lower() for keyword in audio_keywords):
                logger.info(f"Device {name} identified as audio device by name")
                is_audio = True
                    
            return {
                'name': name,
                'mac': mac,
                'rssi': rssi,
                'device_class': device_class,
                'is_audio': is_audio,
                'timestamp': datetime.utcnow().isoformat()
            }
            
        except Exception as e:
            logger.error(f"Error getting device info for {mac}: {e}")
            return None
    
    async def _wait_for_device_in_cache(self, mac: str, timeout: float = 10.0) -> bool:
        """
        Wait for device to appear in bluetoothctl cache (recent output).
        This ensures the device is discoverable before attempting to pair.
        
        Args:
            mac: Device MAC address
            timeout: Maximum time to wait in seconds
            
        Returns:
            True if device seen recently, False if timeout
        """
        start_time = asyncio.get_event_loop().time()
        
        while asyncio.get_event_loop().time() - start_time < timeout:
            async with self.buffer_lock:
                # Check if device appeared in recent output (last 30 seconds)
                cutoff_time = datetime.utcnow() - timedelta(seconds=30)
                for entry in reversed(self.output_buffer):
                    # Stop if entry is too old
                    if entry['timestamp'] < cutoff_time:
                        break
                    
                    line = entry['line']
                    # Look for [NEW] Device or [CHG] Device lines with our MAC
                    if mac.upper() in line.upper() and ('[NEW] Device' in line or '[CHG] Device' in line):
                        logger.info(f"Device {mac} is in cache: {line}")
                        return True
            
            # Wait a bit before checking again
            await asyncio.sleep(0.3)
        
        logger.warning(f"Timeout waiting for device {mac} to appear in cache")
        return False
    
    async def _wait_for_output_pattern(self, mac: str, pattern: str, timeout: float = 15.0) -> bool:
        """
        Wait for a specific pattern in the output buffer for a given MAC address.
        Used by pair_device() to verify command success.
        
        Args:
            mac: Device MAC address
            pattern: Pattern to look for (e.g., "Paired: yes", "Connected: yes")
            timeout: Maximum time to wait in seconds
            
        Returns:
            True if pattern found, False if timeout or error
        """
        start_time = asyncio.get_event_loop().time()
        error_keywords = ['failed', 'not available', 'unavailable', 'error', 'org.bluez.Error']
        
        while asyncio.get_event_loop().time() - start_time < timeout:
            async with self.buffer_lock:
                # Search recent buffer entries for the pattern or errors
                for entry in reversed(self.output_buffer):
                    line = entry['line']
                    
                    # Check for errors related to this MAC
                    if mac.upper() in line.upper():
                        if any(keyword in line.lower() for keyword in error_keywords):
                            logger.error(f"Error detected for {mac}: {line}")
                            return False
                        
                        # Check for success pattern
                        if pattern in line:
                            logger.info(f"Found pattern '{pattern}' for {mac}: {line}")
                            return True
            
            # Wait a bit before checking again
            await asyncio.sleep(0.2)
        
        logger.warning(f"Timeout waiting for pattern '{pattern}' for {mac}")
        return False
            
    async def pair_device(self, mac: str, name: str) -> AsyncGenerator[Dict, None]:
        """
        Pair with a Bluetooth device using the same bluetoothctl process as scan
        This ensures device stays in cache
        
        Args:
            mac: Device MAC address
            name: Device name (for logging)
            
        Yields:
            Status updates: {status, progress, message, timestamp}
        """
        try:
            logger.info(f"Starting pairing with {name} ({mac})")
            
            # Must have scan running (shares bluetoothctl cache)
            if not self.scanning or not self.scan_process:
                logger.error("Scan not running - cannot pair")
                yield {
                    'status': 'failed',
                    'progress': 0,
                    'message': 'Please scan for devices first.',
                    'timestamp': datetime.utcnow().isoformat()
                }
                return
            
            logger.info(f"Using scan's bluetoothctl process for pairing")
            
            # Step 1: Pair immediately (bluetoothctl will handle device availability)
            yield {
                'status': 'pairing',
                'progress': 20,
                'message': f'Pairing with {name}...',
                'timestamp': datetime.utcnow().isoformat()
            }
            
            logger.info(f"Sending: pair {mac}")
            self.scan_process.stdin.write(f'pair {mac}\n'.encode())
            await self.scan_process.stdin.drain()
            
            # Wait for either "Paired: yes" or error message
            paired = await self._wait_for_output_pattern(mac, "Paired: yes", timeout=30.0)
            
            if not paired:
                yield {
                    'status': 'failed',
                    'progress': 0,
                    'message': 'Pairing timed out or failed',
                    'timestamp': datetime.utcnow().isoformat()
                }
                return
            
            yield {
                'status': 'pairing',
                'progress': 50,
                'message': 'Paired successfully',
                'timestamp': datetime.utcnow().isoformat()
            }
            
            # Step 2: Trust
            logger.info(f"Sending: trust {mac}")
            self.scan_process.stdin.write(f'trust {mac}\n'.encode())
            await self.scan_process.stdin.drain()
            
            # Wait for "Trusted: yes" confirmation
            trusted = await self._wait_for_output_pattern(mac, "Trusted: yes", timeout=5.0)
            
            if not trusted:
                logger.warning(f"Trust confirmation not seen, but continuing...")
            
            yield {
                'status': 'trusting',
                'progress': 60,
                'message': 'Trusted',
                'timestamp': datetime.utcnow().isoformat()
            }
            
            # Step 3: Connect
            yield {
                'status': 'connecting',
                'progress': 70,
                'message': 'Connecting...',
                'timestamp': datetime.utcnow().isoformat()
            }
            
            logger.info(f"Sending: connect {mac}")
            self.scan_process.stdin.write(f'connect {mac}\n'.encode())
            await self.scan_process.stdin.drain()
            
            # Wait for "Connected: yes" confirmation
            connected = await self._wait_for_output_pattern(mac, "Connected: yes", timeout=20.0)
            
            if not connected:
                yield {
                    'status': 'failed',
                    'progress': 0,
                    'message': 'Connection timed out or failed',
                    'timestamp': datetime.utcnow().isoformat()
                }
                return
            
            yield {
                'status': 'connecting',
                'progress': 85,
                'message': 'Connected successfully',
                'timestamp': datetime.utcnow().isoformat()
            }
            
            # Additional wait for audio sink to be ready
            await asyncio.sleep(3)
            
            # Step 4: Audio
            yield {
                'status': 'configuring_audio',
                'progress': 90,
                'message': 'Configuring audio...',
                'timestamp': datetime.utcnow().isoformat()
            }
            
            await self._set_default_audio_sink(mac)
            
            yield {
                'status': 'connected',
                'progress': 100,
                'message': f'{name} connected successfully!',
                'timestamp': datetime.utcnow().isoformat()
            }
            
        except Exception as e:
            logger.error(f"Pairing error: {e}")
            yield {
                'status': 'failed',
                'progress': 0,
                'message': f'Error: {str(e)}',
                'timestamp': datetime.utcnow().isoformat()
            }
    
    async def _run_bluetoothctl_command(self, command: str, timeout: int = 10) -> bool:
        """Run a bluetoothctl command and check for success"""
        try:
            process = await asyncio.create_subprocess_exec(
                'bluetoothctl',
                stdin=asyncio.subprocess.PIPE,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            
            # Send command
            process.stdin.write(f'{command}\n'.encode())
            await process.stdin.drain()
            
            # Wait for output with timeout
            try:
                stdout, _ = await asyncio.wait_for(process.communicate(), timeout=timeout)
                output = stdout.decode('utf-8')
                
                # Check for success indicators
                success_keywords = ['successful', 'Pairing successful', 'Connection successful', 'trust succeeded']
                for keyword in success_keywords:
                    if keyword.lower() in output.lower():
                        return True
                        
                # Check for failure indicators
                failure_keywords = ['failed', 'error', 'not available']
                for keyword in failure_keywords:
                    if keyword.lower() in output.lower():
                        logger.error(f"Command '{command}' failed: {output}")
                        return False
                        
                # If no clear success/failure, assume success
                return True
                
            except asyncio.TimeoutError:
                logger.error(f"Command '{command}' timed out")
                process.kill()
                return False
                
        except Exception as e:
            logger.error(f"Error running command '{command}': {e}")
            return False
            
    async def _set_default_audio_sink(self, mac: str) -> bool:
        """
        Set Bluetooth device as default audio sink
        For PipeWire systems, use pactl (PulseAudio compatibility layer)
        """
        try:
            # Try pactl first (works with both PulseAudio and PipeWire)
            logger.info("Using pactl for audio configuration (PulseAudio/PipeWire compatible)")
            return await self._set_pulseaudio_sink(mac)
                
        except Exception as e:
            logger.error(f"Error setting audio sink: {e}")
            return False
    
    async def _set_pipewire_sink(self, mac: str) -> bool:
        """Configure PipeWire/WirePlumber audio sink"""
        try:
            logger.info(f"Waiting for Bluetooth device {mac} to appear in PipeWire...")
            await asyncio.sleep(4)
            
            sink_id = None
            # Wait for Bluetooth device to appear in PipeWire
            for attempt in range(5):
                list_proc = await asyncio.create_subprocess_exec(
                    'wpctl', 'status',
                    stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.PIPE
                )
                stdout, _ = await list_proc.communicate()
                output = stdout.decode()
                
                # Debug: log full wpctl output on first attempt
                if attempt == 0:
                    logger.debug(f"Full wpctl status output:\n{output}")
                
                # Look for Bluetooth device in sinks section
                in_sinks_section = False
                for line in output.split('\n'):
                    if 'Sinks:' in line:
                        in_sinks_section = True
                        continue
                    if in_sinks_section and line and not line[0].isspace() and 'Sources:' in line:
                        break  # End of sinks section
                    
                    if in_sinks_section:
                        # Check if line contains our MAC address (in various formats)
                        mac_formats = [
                            mac.replace(':', '_').lower(),
                            mac.replace(':', '-').lower(),
                            mac.replace(':', '').lower()
                        ]
                        line_lower = line.lower()
                        if any(fmt in line_lower for fmt in mac_formats):
                            # Extract sink ID from line format: "  *   57. Device Name"
                            match = re.search(r'^\s*\*?\s*(\d+)\.', line)
                            if match:
                                sink_id = match.group(1)
                                logger.info(f"Found PipeWire sink ID: {sink_id} - {line.strip()}")
                                break
                
                if sink_id:
                    break
                else:
                    logger.warning(f"Bluetooth sink not found yet (attempt {attempt+1}/5), waiting...")
                    # Check if device is actually connected and has A2DP profile
                    if attempt == 2:  # Check on 3rd attempt
                        info_proc = await asyncio.create_subprocess_shell(
                            f"bluetoothctl info {mac} | grep -E 'Connected|UUID'",
                            stdout=asyncio.subprocess.PIPE,
                            stderr=asyncio.subprocess.PIPE
                        )
                        info_out, _ = await info_proc.communicate()
                        logger.info(f"Device info check: {info_out.decode().strip()}")
                    await asyncio.sleep(3)
            
            if not sink_id:
                logger.error(f"Bluetooth sink for {mac} never appeared in PipeWire")
                # Log available sinks for debugging
                logger.error(f"Available sinks in last check:\n{output}")
                return False
            
            # Set as default sink
            logger.info(f"Setting PipeWire sink {sink_id} as default...")
            process = await asyncio.create_subprocess_exec(
                'wpctl', 'set-default', sink_id,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            
            stdout, stderr = await process.communicate()
            
            if process.returncode == 0:
                logger.info(f"Successfully set PipeWire sink {sink_id} as default")
                return True
            else:
                logger.error(f"Failed to set default PipeWire sink: {stderr.decode()}")
                return False
                
        except Exception as e:
            logger.error(f"Error setting PipeWire sink: {e}")
            return False
    
    async def _set_pulseaudio_sink(self, mac: str) -> bool:
        """Configure PulseAudio/PipeWire sink via pactl"""
        try:
            # Convert MAC to sink format: XX_XX_XX_XX_XX_XX
            sink_mac = mac.replace(':', '_')
            
            # Step 1: Switch to A2DP profile for high-quality audio
            logger.info(f"Switching Bluetooth card to A2DP profile for audio playback...")
            card_name = f"bluez_card.{sink_mac}"
            
            profile_proc = await asyncio.create_subprocess_exec(
                'pactl', 'set-card-profile', card_name, 'a2dp-sink',
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            _, profile_stderr = await profile_proc.communicate()
            
            if profile_proc.returncode == 0:
                logger.info(f"Successfully set {card_name} to A2DP profile")
            else:
                logger.warning(f"Could not set A2DP profile: {profile_stderr.decode()}")
            
            # Wait for A2DP profile to initialize
            logger.info(f"Waiting for A2DP audio sink to initialize...")
            await asyncio.sleep(3)
            
            # Get list of available sinks
            list_proc = await asyncio.create_subprocess_exec(
                'pactl', 'list', 'short', 'sinks',
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            stdout, _ = await list_proc.communicate()
            output = stdout.decode()
            
            logger.info(f"Available sinks:\n{output}")
            
            # Look for sink with our MAC address
            # PipeWire: bluez_output.XX_XX_XX_XX_XX_XX.N
            # PulseAudio: bluez_sink.XX_XX_XX_XX_XX_XX.a2dp_sink
            sink_name = None
            for line in output.split('\n'):
                if sink_mac in line and ('bluez_output' in line or 'bluez_sink' in line):
                    # Extract sink name (column 2)
                    parts = line.split()
                    if parts:
                        sink_name = parts[1]  # Column 2 is the name
                        logger.info(f"Found sink: {sink_name}")
                        break
            
            if not sink_name:
                logger.warning(f"Bluetooth sink not found for {mac}. Audio routing will be skipped.")
                # Don't fail the pairing if sink isn't ready yet
                return True
            
            # Set as default sink
            logger.info(f"Setting {sink_name} as default sink...")
            process = await asyncio.create_subprocess_exec(
                'pactl', 'set-default-sink', sink_name,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            
            stdout, stderr = await process.communicate()
            
            if process.returncode == 0:
                logger.info(f"Successfully set {sink_name} as default audio sink")
                
                # Move all streams to new sink
                move_proc = await asyncio.create_subprocess_shell(
                    f'pactl list short sink-inputs | cut -f1 | xargs -I{{}} pactl move-sink-input {{}} "{sink_name}"',
                    stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.PIPE
                )
                await move_proc.communicate()
                logger.info(f"Moved audio streams to {sink_name}")
                
                return True
            else:
                logger.warning(f"Could not set default sink: {stderr.decode()}")
                return True  # Don't fail pairing if audio routing fails
                
        except Exception as e:
            logger.warning(f"Error setting PulseAudio sink: {e}")
            return True  # Don't fail pairing if audio routing fails
            
    async def disconnect_device(self, mac: str) -> Dict:
        """
        Disconnect and remove a Bluetooth device
        
        Args:
            mac: Device MAC address
            
        Returns:
            Dict with success status and message
        """
        try:
            logger.info(f"Disconnecting device {mac}")
            
            # Disconnect
            disconnect_proc = await asyncio.create_subprocess_exec(
                'bluetoothctl', 'disconnect', mac,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            await disconnect_proc.wait()
            await asyncio.sleep(1)
            
            # Remove
            remove_proc = await asyncio.create_subprocess_exec(
                'bluetoothctl', 'remove', mac,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            await remove_proc.wait()
            
            logger.info(f"Successfully disconnected {mac}")
            return {
                'success': True,
                'message': 'Device disconnected successfully',
                'timestamp': datetime.utcnow().isoformat()
            }
                
        except Exception as e:
            logger.error(f"Disconnect error: {e}")
            return {
                'success': False,
                'message': f'Error: {str(e)}',
                'timestamp': datetime.utcnow().isoformat()
            }
    
    async def get_status(self) -> Dict:
        """
        Get current Bluetooth audio device status
        
        Returns:
            Dict with connected device info or None
        """
        try:
            # Get list of devices
            process = await asyncio.create_subprocess_exec(
                'bluetoothctl', 'devices',
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            
            stdout, _ = await process.communicate()
            devices_text = stdout.decode('utf-8')
            
            # Check each device for connection status
            for line in devices_text.split('\n'):
                if 'Device' in line:
                    mac_match = re.search(r'([0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2})', line, re.IGNORECASE)
                    if mac_match:
                        mac = mac_match.group(1)
                        
                        # Check if connected
                        info_process = await asyncio.create_subprocess_exec(
                            'bluetoothctl', 'info', mac,
                            stdout=asyncio.subprocess.PIPE,
                            stderr=asyncio.subprocess.PIPE
                        )
                        
                        info_stdout, _ = await info_process.communicate()
                        info_text = info_stdout.decode('utf-8')
                        
                        if 'Connected: yes' in info_text:
                            # Check if it's an audio device
                            is_audio = False
                            device_class = None
                            
                            for info_line in info_text.split('\n'):
                                info_line = info_line.strip()
                                if info_line.startswith('Class:'):
                                    device_class = info_line.split('Class:', 1)[1].strip()
                                    # Check if audio device (0x24xxxx = Audio/Video)
                                    if device_class and '0x24' in device_class:
                                        is_audio = True
                                elif 'UUID: Audio' in info_line or 'UUID: A2DP' in info_line or 'UUID: Headset' in info_line:
                                    is_audio = True
                            
                            # Only return if it's an audio device
                            if not is_audio:
                                continue
                            
                            # Extract device name
                            name = 'Unknown Device'
                            for info_line in info_text.split('\n'):
                                if info_line.strip().startswith('Name:'):
                                    name = info_line.split('Name:', 1)[1].strip()
                                    break
                                    
                            return {
                                'is_connected': True,
                                'connected_device': {
                                    'name': name,
                                    'mac': mac
                                },
                                'timestamp': datetime.utcnow().isoformat()
                            }
                            
            # No connected device
            return {
                'is_connected': False,
                'connected_device': None,
                'timestamp': datetime.utcnow().isoformat()
            }
            
        except Exception as e:
            logger.error(f"Error getting status: {e}")
            return {
                'is_connected': False,
                'connected_device': None,
                'error': str(e),
                'timestamp': datetime.utcnow().isoformat()
            }
