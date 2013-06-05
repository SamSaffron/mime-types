require "rake/testtask"

Rake::TestTask.new do |t|
  t.pattern = "test/test_*.rb"
end

task :objects do
  GC.start
  before = ObjectSpace.count_objects
  $:.unshift File.expand_path("../lib", __FILE__)
  require "mime/types"
  GC.start
  after = ObjectSpace.count_objects
  for key, delta in before.keys
                          .grep(/T_/)
                          .map { |key| [key, after[key] - before[key]] }
                          .sort_by { |key, delta| -delta }
    printf "%10s +%6d\n", key, delta
  end
end

task :default => :test
