require 'libusb'

class MissleLauncherIO
  SETUP_PACKET = {bmRequestType: 0x21, bRequest: 0x9, wValue: 0x2, wIndex: 0x0}
  ID = {idVendor: 0x1941, idProduct: 0x8021}
  INTERFACE = 0
  STATUS_ENDPOINT = {endpoint: 0x81, dataIn: 8}
  module Command
    UP     = 0x01
    DOWN   = 0x02
    CCW    = 0x04
    CW     = 0x08
    CHARGE = 0x10
  end
  module Limit
    DOWN   = 0x0040
    UP     = 0x0080
    CCW    = 0x0400
    CW     = 0x0800
    CHARGE = 0x8000
  end
  def initialize
    usb = LIBUSB::Context.new
    device = usb.devices(**ID).first
    return if !device
    @handle = device.open
    @detached = (@handle.detach_kernel_driver(INTERFACE);true) rescue false
    @handle.claim_interface INTERFACE
  end
  def active?; !!@handle; end
  def read_limits
    status = @handle.interrupt_transfer(**STATUS_ENDPOINT).unpack('S').first
    Limit.constants.select{|l| Limit.const_get(l) & status != 0 }
  end
  def do *cmds
    @handle.control_transfer(**SETUP_PACKET, dataOut: [cmds.map{|c|Command.const_get(c)}.reduce(0){|d,c|d=d|c}].pack('S'))
  end
  def deinit
    return if !active?
    self.do
    @handle.release_interface INTERFACE
    @handle.attach_kernel_driver INTERFACE if @detached
    @handle = nil
  end
end
