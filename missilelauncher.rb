require_relative 'missilelauncherio'
require 'set'

class MissileLauncher
  SAMPLE_DUR_SEC = 0.2
  def initialize
    @thread = nil
    @queue = Queue.new
  end
  def control_loop
    Thread.current.abort_on_exception = true
    io = MissleLauncherIO.new ; raise "Cannot connect to missile launcher" if !io.active?
    commands = Set.new
    req_fire = false
    charge_history = []
    ready_fire = false
    start_time = Time.now.to_f
    begin
      loop do
        limits = io.read_limits
        new = (commands.empty? || !@queue.empty?) ? Set.new(@queue.pop) : commands
        if new == Set.new([:FIRE]) || new == Set.new([:ABORT])
          req_fire = (new == Set.new([:FIRE]))
          new = commands
        end
        new -= limits
        charge_history << {time: Time.now.to_f, charge: limits.include?(:CHARGE)}
        charge_history = charge_history.reject{|c|Time.now.to_f-c[:time]>SAMPLE_DUR_SEC}
        if Time.now.to_f - start_time > SAMPLE_DUR_SEC
          if ready_fire && charge_history.all?{|c|!c[:charge]}
            ready_fire = false
            req_fire = false
          end
          if !ready_fire && charge_history.all?{|c|c[:charge]}
            ready_fire = true
          end
          new += [:CHARGE] if req_fire || !ready_fire
        end
        if new != commands
          io.do *new
          commands = new
        end
      end
    ensure
      io.deinit
    end
  end
  private :control_loop
  def connect
    @thread ||= Thread.new { control_loop }; self
  end
  def disconnect
    (@thread.exit.join; @thread = nil) if @thread; self
  end
  def move(rotation, tilt)
    @queue << [rotation>0 ? :CW : rotation<0 ? :CCW : nil, tilt>0 ? :UP : tilt<0 ? :DOWN : nil].compact
  end
  def stop; move(0,0); end
  def fire; @queue << [:FIRE]; end
  def abort; @queue << [:ABORT]; end
end
