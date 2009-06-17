require 'ostruct'

class Player

  attr_accessor :port, :address, :network_speed, :password, :music_player,
                :music_repo, :reentry_delay, :start_hour, :end_hour

  attr_accessor :last_access_time, :last_access_user

  attr_reader   :door, :network, :reader, :hardware

  def initialize config
    config.each do |key, value|
      send("#{key}=", value) if respond_to? "#{key}="
    end
    @last_access_time = Time.mktime(1970, 1, 1, 0, 0, 0)
    @last_access_user = OpenStruct.new
    raise NoAPI unless @door = WIN32OLE.new("TalosAPI.Application")
    raise NoNetwork unless @network = @door.FindReaderNetwork(port)
  end

  def connect
    raise NoConnection unless @network.Connect(network_speed.to_i)
    raise NoReader     unless @reader = @network.FindReader(address.to_i)
    raise NoLogon      unless @reader.Logon(2, password.to_i, true)
    raise NoHardware   unless @hardware = @reader.HardwareControl
  end

  def song_for name
    Dir.glob(File.join(music_repo, "#{name}.*")).first
  end

  def command_for name
    %Q{start "Theme Music" "#{music_player}" "#{song_for(name)}"}
  end

  def play_for name
    command = command_for(name)
    puts "User: #{name}, Command: #{command}"
    system(command)
  end

  def should_play?
    (start_hour.to_i...end_hour.to_i).include?(Time.now.hour)
  end

  def card_detected?
    hardware.IsCarrierInField
  end

  def detect_card!
    sleep 0.25 while not card_detected?
  end

  def detect_user!
    user_detected = false
    while not user_detected
      detect_card!
      user          = hardware.LastUser
      user_detected = trigger_access?(user)
      self.last_access_user = user
      self.last_access_time = Time.now
    end
  end

  def trigger_access? user
    same_user = user.CardNumber == last_access_user.CardNumber
    in_delta  = Time.now - last_access_time <= reentry_delay
    not in_delta && same_user
  end

  def ensuring_connection &block
    running = true
    while running
      begin
        connect
        block.call(self) while true
      rescue WIN32OLERuntimeError, PlayerError
        sleep 1         # There was an error with the connection, most likely.
      rescue Interrupt
        running = false # Ctrl-C hit. Bail.
      end
    end
  end

  def self.run config
    new(config).ensuring_connection do |player|
      player.detect_user!
      sleep 0.5
      player.play_for(player.last_access_user.Name) if player.should_play?
    end
  end

  class PlayerError  < StandardError; end
  class NoAPI        < PlayerError; end
  class NoNetwork    < PlayerError; end
  class NoConnection < PlayerError; end
  class NoReader     < PlayerError; end
  class NoLogon      < PlayerError; end
  class NoHardware   < PlayerError; end
end

# Player.run( YAML.load_file(ARGV[0] || "player.yml") )
