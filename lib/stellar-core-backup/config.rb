require 'yaml'

module StellarCoreBackup
  class Config
    include Contracts

    class ReadError < StandardError ; end

    Contract String => Any
    def initialize(config)
      if (File.exists?(config)) then
        @config = YAML.load_file(config)
      else
        raise ReadError
      end
    end

    Contract None => Bool
    def configured?()
      unless @config.nil? || @config.empty?
        return true
      else
        return false
      end
    end

    Contract String => Any
    def get(item)
      if self.configured?() then
        @config[item]
      else
        raise ReadError
      end
    end

  end
end
