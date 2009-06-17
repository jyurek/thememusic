require 'test_helper'

class PlayerTest < Test::Unit::TestCase
  context "a new Player" do
    config = {
      'network'          => 2,
      'address'          => 13,
      'password'         => 987654321,
      'connection_speed' => 19200,
      'start_hour'       => 6,
      'end_hour'         => 11,
      'reentry_delay'    => 5,
      'music_repo'       => "songs",
      'music_player'     => "winamp.exe"
    }

    setup do
      WIN32OLE.stubs(:new).with("TalosAPI.Application").returns(FakeDoor.new)
      @player = Player.new(config)
      @fake_door = @player.door
      @player.stubs(:puts)
      @player.stubs(:sleep)
      Player.stubs(:sleep)
      @player.connect
      Dir.stubs(:glob).
          with(File.join("songs", "Moe Syzslak.*")).
          returns(["songs/Moe Syzslak.mp3"])
    end

    should "detect users and play while ensuing a connection when run" do
      @player.last_access_user = OpenStruct.new(:Name => "Moe Syzslak")
      @player.stubs(:ensuring_connection).yields(@player)
      @player.stubs(:detect_user!)
      @player.stubs(:should_play?).returns(true)
      @player.stubs(:play_for)
      Player.stubs(:new).returns(@player)

      Player.run(config)

      assert_received(@player, :ensuring_connection)
      assert_received(@player, :detect_user!)
      assert_received(@player, :should_play?)
      assert_received(@player, :play_for){|p| p.with("Moe Syzslak") }
    end

    context "changing connection possibilities" do
      teardown do
        FakeDoor.card_present          = true
        FakeDoor.find_network          = true
        FakeDoor::Network.connect      = true
        FakeDoor::Network.find_reader  = true
        FakeDoor::Reader.logon         = true
        FakeDoor::Reader.find_hardware = true
      end

      should "not raise if everything works" do
        assert_nothing_raised{ Player.new(config) }
      end

      should "raise if API can't be found" do
        WIN32OLE.stubs(:new).returns(nil)
        assert_raises(Player::NoAPI){ Player.new(config) }
      end

      should "raise if reader can't be found on specified port" do
        FakeDoor.find_network = false
        assert_raises(Player::NoNetwork){ Player.new(config) }
      end

      should "raise if no connection can be made to the network" do
        FakeDoor::Network.connect = false
        assert_raises(Player::NoConnection){ @player.connect }
      end

      should "raise if no reader can be found at the specified address" do
        FakeDoor::Network.find_reader = false
        assert_raises(Player::NoReader){ @player.connect }
      end

      should "raise if we cannot log onto the reader" do
        FakeDoor::Reader.logon = false
        assert_raises(Player::NoLogon){ @player.connect }
      end

      should "raise if we cannot obtain a hardware reference" do
        FakeDoor::Reader.find_hardware = false
        assert_raises(Player::NoHardware){ @player.connect }
      end
    end

    should "find the right song given a username" do
      assert_equal "songs/Moe Syzslak.mp3", @player.song_for("Moe Syzslak")
    end

    should "generate the right music command given a username" do
      assert_equal 'start "Theme Music" "winamp.exe" "songs/Moe Syzslak.mp3"',
                   @player.command_for("Moe Syzslak")
    end

    should "run the right command for a user" do
      @player.stubs(:system)
      @player.play_for("Moe Syzslak")
      assert_received(@player, :system) do |p|
        p.with('start "Theme Music" "winamp.exe" "songs/Moe Syzslak.mp3"')
      end
    end

    context "given a certain set of hours for start/end playing" do
      setup do
        now = Time.now
        now.stubs(:hour).returns(10)
        Time.stubs(:now).returns(now)
        @player.start_hour = 9
        @player.end_hour = 11
      end

      should "tell us we can play" do
        assert @player.should_play?
      end

      should "tell us we cannot play if the end hour is the same" do
        @player.end_hour = 10
        assert ! @player.should_play?
      end

      should "tell us we cannot play if the curret hour is outside the range" do
        @player.start_hour = 12
        @player.end_hour = 14
        assert ! @player.should_play?
      end
    end

    should "loop until card_detected? is true" do
      @player.stubs(:card_detected?).returns(false, true)
      @player.stubs(:sleep).with(0.25)
      @player.detect_card!
      assert_received(@player, :sleep){|p| p.with(0.25) }
    end

    should "return card detected when hardware says its present" do
      FakeDoor.card_present = true
      assert @player.card_detected?
    end

    should "return card not detected when hardware says its not present" do
      FakeDoor.card_present = false
      assert ! @player.card_detected?
    end

    should "every time the block raises, reconnect and start until interrupt" do
      @player.stubs(:raise).raises(Player::NoAPI).then.raises(Interrupt)
      @player.stubs(:connect)

      @player.ensuring_connection{|player| player.raise }

      assert_received(@player, :connect){|c| c.times(2) }
      assert_received(@player, :raise)  {|c| c.times(2) }
    end

    context "checking access triggers" do
      setup do
        @old_user = OpenStruct.new(:CardNumber => "12345")
        @new_user = OpenStruct.new(:CardNumber => "54321")
        @now  = Time.now
        @then = @now - (@player.reentry_delay.to_i * 2)
        Time.stubs(:now).returns(@now)
        @player.last_access_user = @old_user
        @player.last_access_time = @then
      end

      should "trigger access because of different times and users" do
        assert @player.trigger_access?(@new_user)
      end

      should "trigger access even for users if different time" do
        @new_user.CardNumber = "12345"
        assert @player.trigger_access?(@new_user)
      end

      should "trigger access even at same time if different users" do
        Time.stubs(:now).returns(@then)
        assert @player.trigger_access?(@new_user)
      end

      should "not trigger access if same user at same time" do
        @new_user.CardNumber = "12345"
        Time.stubs(:now).returns(@then)
        assert ! @player.trigger_access?(@new_user)
      end
    end

    context "detecting a user" do
      setup do
        @now = Time.now
        Time.stubs(:now).returns(@now)
        @player.stubs(:detect_card!)
        @player.last_access_user = OpenStruct.new(:CardNumber => "12345")
        @player.last_access_time = Time.now - (2 * @player.reentry_delay)
      end

      should "try to detect a card multiple times if trigger_access? fails" do
        @player.stubs(:trigger_access?).returns(false, true)
        @player.detect_user!
        assert_received(@player, :detect_card!){|p| p.times(2) }
      end

      should "set the last user to access the system to last_access_user" do
        FakeDoor::Hardware.card_number = "54321"
        @player.detect_user!
        assert_equal "54321", @player.last_access_user.CardNumber
      end

      should "set the last time the system was accessed to last_access_time" do
        FakeDoor::Hardware.card_number = "54321"
        @player.detect_user!
        assert_equal @now, @player.last_access_time
      end
    end
  end
end
