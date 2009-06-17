require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'
require 'player'

desc 'Default: run unit tests.'
task :default => [:test]

desc 'Run the tests.'
Rake::TestTask.new(:test) do |t|
  t.libs << 'lib' << 'profile' << 'test'
  t.pattern = 'test/*_test.rb'
  t.verbose = true
end

namespace :test do
  desc 'Generate test coverage report.'
  task :coverage do
    rm_f "coverage"
    rcov = 'rcov -I test -T -x "rubygems/*,/Library/Ruby/Site/*,gems/*,rcov*"'
    system("#{rcov} --html test/*_test.rb")
    system("open coverage/index.html") if PLATFORM['darwin']
  end
end
