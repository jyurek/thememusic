require 'yaml'
require 'player'

Player.run( YAML.load_file( ARGV.first || "player.yml" ) )
