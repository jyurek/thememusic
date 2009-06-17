class FakeDoor
  def self.card_present= val
    @card_present = val
  end
  def self.card_present
    @card_present
  end

  def self.find_network= val
    @find_network = val
  end
  def self.find_network
    @find_network
  end

  self.card_present = true
  self.find_network = true

  def FindReaderNetwork network
    @network ||= Network.new(network) if self.class.find_network
  end

  class Network
    def self.connect= val
      @connect = val
    end
    def self.connect
      @connect
    end

    def self.find_reader= val
      @find_reader = val
    end
    def self.find_reader
      @find_reader
    end

    self.connect = true
    self.find_reader = true

    def initialize port
      @port = port
    end

    def Connect speed
      @speed = speed
      self.class.connect if self.class.connect
    end

    def Disconnect
      raise unless self.class.connect
    end

    def FindReader address
      @reader ||= Reader.new(address) if self.class.find_reader
    end
  end

  class Reader
    def self.logon= val
      @logon = val
    end
    def self.logon
      @logon
    end

    def self.find_hardware= val
      @find_hardware = val
    end
    def self.find_hardware
      @find_hardware
    end

    self.logon = true
    self.find_hardware = true

    def initialize address
      @address = address
    end

    def Logon const, password, sync
      @password = password
      self.class.logon if self.class.logon
    end

    def Logout
      raise unless self.class.logon
    end

    def HardwareControl
      @hardware ||= Hardware.new if self.class.find_hardware
    end
  end

  class Hardware
    def self.user_name= val
      @user_name = val
    end
    def self.user_name
      @user_name
    end

    def self.card_number= val
      @card_number = val
    end
    def self.card_number
      @card_number
    end

    self.user_name   = "Moe Syzslak"
    self.card_number = "12345"

    def IsCarrierInField
      FakeDoor.card_present
    end

    def LastUser
      user = User.new
      user.CardNumber = self.class.card_number
      user.Name = self.class.user_name
      user
    end
  end

  class User
    attr_accessor :CardNumber, :Name
  end
end
